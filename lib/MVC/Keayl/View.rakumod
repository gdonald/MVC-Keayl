use v6.d;
use MONKEY-SEE-NO-EVAL;
use MVC::Keayl::View::Handler::HAML;
use MVC::Keayl::View::Context;
use MVC::Keayl::SafeString;
use MVC::Keayl::Helpers::Tag;
use MVC::Keayl::Helpers::Url;
use MVC::Keayl::Helpers::Asset;
use MVC::Keayl::Assets;
use MVC::Keayl::Helpers::Form;
use MVC::Keayl::Helpers::Options;
use MVC::Keayl::Helpers::Text;
use MVC::Keayl::Helpers::Number;
use MVC::Keayl::Helpers::DateTime;
use MVC::Keayl::Cache;
use MVC::Keayl::Notifications;

unit class MVC::Keayl::View;

has @.paths;
has %.handlers;
has Str  $.default-handler = 'haml';
has Str  $.default-format  = 'html';
has Bool $.cache  = True;
has Bool $.reload = True;
has      &.asset-resolver = &digested-resolver;
has      $.cache-store = MVC::Keayl::Cache::MemoryStore.new;
has      @.helper-paths = ['app/helpers'];
has      &.helper-loader;
has      %!store;
has      %!helper-module-cache;
has Lock $!compile-lock = Lock.new;
has      %!compiling;

submethod TWEAK {
  %!handlers{'haml'} //= MVC::Keayl::View::Handler::HAML.new;
}

sub underscore(Str:D $word --> Str) {
  $word.subst(/<?after .> <:Lu>/, { '_' ~ $/.Str }, :g).lc
}

sub underscore-last(Str:D $name --> Str) {
  my @parts = $name.split('/');
  @parts[*-1] = '_' ~ @parts[*-1];
  @parts.join('/')
}

method register-handler(Str:D $extension, $handler --> ::?CLASS) {
  %!handlers{$extension} = $handler;
  self
}

# Resolve a template name and format to a file by search-path then handler
# precedence: {path}/{name}.{format}+{variant}.{ext}, {path}/{name}.{format}.{ext},
# falling back to {path}/{name}.{ext}.
method resolve(Str:D $name, Str:D $format, :$variant --> IO::Path) {
  for @!paths -> $path {
    if $variant.defined {
      for %!handlers.keys.sort -> $ext {
        my $with-variant = $path.IO.add($name ~ '.' ~ $format ~ '+' ~ $variant ~ '.' ~ $ext);
        return $with-variant if $with-variant.e;
      }
    }
    for %!handlers.keys.sort -> $ext {
      my $with-format = $path.IO.add($name ~ '.' ~ $format ~ '.' ~ $ext);
      return $with-format if $with-format.e;
    }
    for %!handlers.keys.sort -> $ext {
      my $bare = $path.IO.add($name ~ '.' ~ $ext);
      return $bare if $bare.e;
    }
  }

  IO::Path
}

method has-template(Str:D $name, Str:D $format, :$variant, :$controller --> Bool) {
  my $lookup = self!lookup-name($name, $controller);

  for @!paths -> $path {
    if $variant.defined {
      for %!handlers.keys.sort -> $ext {
        return True if $path.IO.add($lookup ~ '.' ~ $format ~ '+' ~ $variant ~ '.' ~ $ext).e;
      }
    }
    for %!handlers.keys.sort -> $ext {
      return True if $path.IO.add($lookup ~ '.' ~ $format ~ '.' ~ $ext).e;
    }
  }

  False
}

method !lookup-name(Str:D $name, $controller --> Str) {
  return $name if $name.contains('/');
  return $name without $controller;
  $controller.controller-path ~ '/' ~ $name
}

method !compiled-for(IO::Path:D $file, :@helper-names --> List) {
  my $key     = $file.absolute;
  my $handler = %!handlers{$file.extension} // die "no view handler for .{$file.extension}";

  my $compiled = self!compile-once("template:$key",
    lookup => {
      my $entry = %!store{$key};
      ($entry.defined && (!$!reload || $entry<mtime> == $file.modified.Num)) ?? $entry<compiled> !! Nil
    },
    build => {
      MVC::Keayl::Notifications.instrument('compile.keayl', %( file => $key ), { $handler.compile($file.slurp, :@helper-names) })
    },
    store => -> $value {
      %!store{$key} = { mtime => $file.modified.Num, compiled => $value } if $!cache;
    },
  );

  ($compiled, $handler)
}

method !compile-once(Str:D $key, :&lookup!, :&build!, :&store! --> Mu) {
  my $vow;
  my $pending = $!compile-lock.protect: {
    my $hit = lookup();

    $hit.defined
      ?? Promise.kept($hit)
      !! (%!compiling{$key} //= do { my $promise = Promise.new; $vow = $promise.vow; $promise })
  };

  return await $pending without $vow;

  my $value;
  {
    CATCH {
      default {
        $!compile-lock.protect: { %!compiling{$key}:delete };
        $vow.break($_);
        .rethrow
      }
    }

    $value = build();
  }

  $!compile-lock.protect: {
    store($value);
    %!compiling{$key}:delete;
  };

  $vow.keep($value);
  $value
}

method precompile(--> Nil) {
  my %helper-names = (|self!helper-closures.keys, |self!layout-helpers('').keys).map(* => True);

  unless &!helper-loader.defined {
    for @!helper-paths -> $path {
      for files-under($path.IO).grep(*.extension eq 'rakumod') -> $file {
        my %subs = self!load-helper-module($file.relative($path.IO).IO.extension('').Str.subst('/', '::', :g));
        %helper-names{$_} = True for %subs.keys;
      }
    }
  }

  my @helper-names = %helper-names.keys.map(*.subst('_', '-', :g)).unique.sort;

  for @!paths -> $path {
    for files-under($path.IO).grep({ %!handlers{.extension}:exists }) -> $file {
      self!compiled-for($file, :@helper-names);
    }
  }
}

sub files-under(IO::Path:D $dir --> List) {
  return () unless $dir.d;

  $dir.dir.sort.map({ .d ?? |files-under($_) !! $_ }).List
}

method render-template(Str:D $name, %locals, Str :$format, :$variant, :$controller --> Str) {
  my $lookup = self!lookup-name($name, $controller);
  my $fmt    = $format // $!default-format;
  my $file   = self.resolve($lookup, $fmt, :$variant);

  die 'template not found: ' ~ $lookup ~ '.' ~ $fmt unless $file.defined && $file.e;

  my $*KEAYL-CONTROLLER = $controller;
  my ($compiled, $handler) = self!compiled-for($file);
  $handler.render($compiled, %locals, context => self.build-context(:$controller))
}

method render-inline(Str:D $template, %locals, :$controller --> Str) {
  my $*KEAYL-CONTROLLER = $controller;
  my $handler = %!handlers{$!default-handler} // die "no view handler '$!default-handler'";
  $handler.render($handler.compile($template), %locals, context => self.build-context(:$controller))
}

method render-layout(Str:D $layout, Str:D $content, %locals, :$controller --> Str) {
  my $file = self.resolve('layouts/' ~ $layout, $!default-format);
  return $content unless $file.defined && $file.e;

  my $*KEAYL-CONTROLLER = $controller;
  my ($compiled, $handler) = self!compiled-for($file);
  # Expose the rendered body as a `content` local (so a layout can use `$content`)
  # in addition to the `content()`/`yield()` helpers. An explicit local wins.
  my %layout-locals = content => $content, |%locals;
  $handler.render($compiled, %layout-locals, context => self.build-context(:$controller, extra => self!layout-helpers($content)))
}

method layout-exists(Str:D $name --> Bool) {
  my $file = self.resolve('layouts/' ~ $name, $!default-format);
  $file.defined && $file.e
}

method cache-fragment(@key-parts, &producer, Str :$digest --> Str) {
  ~$!cache-store.fetch(cache-key(|@key-parts, :$digest), &producer)
}

method render-partial(Str:D $name, %locals = {}, :$controller --> Str) {
  my $lookup = self!lookup-name(underscore-last($name), $controller);
  my $file   = self.resolve($lookup, $!default-format);

  die 'partial not found: ' ~ $name unless $file.defined && $file.e;

  my $*KEAYL-CONTROLLER = $controller;
  my ($compiled, $handler) = self!compiled-for($file);
  $handler.render($compiled, %locals, context => self.build-context(:$controller))
}

method render-object($object, %locals = {}, :$controller --> Str) {
  my $path  = self!partial-path-for($object);
  my $local = $path.split('/')[*-1];

  self.render-partial($path, { %locals, $local => $object }, :$controller)
}

method render-collection(Str:D $name, @collection, :$spacer, :$controller, *%locals --> Str) {
  my $local       = $name.split('/')[*-1];
  my $counter-key = $local ~ '_counter';

  my @rendered = @collection.kv.map(-> $index, $item {
    self.render-partial($name, { %locals, $local => $item, $counter-key => $index }, :$controller)
  });

  my $separator = $spacer.defined ?? self.render-partial($spacer, {}, :$controller) !! '';

  @rendered.join($separator)
}

method !partial-path-for($object --> Str) {
  return $object.to-partial-path if $object.^can('to-partial-path');
  underscore($object.^name.subst(/^ .* '::' /, ''))
}

method build-context(:$controller, :%extra --> MVC::Keayl::View::Context) {
  my %helpers;
  for self!helper-closures(:$controller).kv -> $name, $closure {
    %helpers{$name.subst('_', '-', :g)} = $closure;
  }

  if $controller.defined {
    for self!controller-helper-modules($controller) -> $module {
      for self!helper-module-subs($module).kv -> $name, $sub {
        %helpers{$name.subst('_', '-', :g)} = $sub;
      }
    }
  }

  for %extra.kv -> $name, $closure {
    %helpers{$name.subst('_', '-', :g)} = $closure;
  }

  MVC::Keayl::View::Context.new(:%helpers)
}

method !layout-helpers(Str:D $content --> Hash) {
  %(
    yield   => -> $name? { $name.defined ?? ($*KEAYL-CONTENT{$name} // '') !! $content },
    content => -> { $content },
  )
}

my atomicint $helper-eval-counter = 0;

# Helper modules are loaded by evaluating their source under a fresh package name
# each time, rather than `require`, so a changed file reloads in development and
# loading works the same in every harness.
sub eval-helper-subs(IO::Path:D $file --> Hash) {
  # Drop the `unit module ...;` declaration and any `use v6...;` language pragma
  # from the body: the body is re-wrapped in a `module { ... }` block, and a
  # version pragma is only legal as the first statement of a compilation unit.
  # The pragma is then re-emitted as the first statement of the eval'd code, so
  # the wrapped module compiles under the v6 language. Without it the module
  # belongs to "no language" and helper bodies that reference core types
  # (Date, DateTime, ...) fail to resolve them.
  my $body = $file.slurp
    .subst(/^^ \h* 'use' \h+ 'v6' <[.\w]>* \h* ';' \h* $$/, '', :g)
    .subst(/^^ \h* 'unit' \h+ 'module' \h+ <[\w:]>+ \h* ';' \h* $$/, '');
  my $sym  = '__KeaylHelper_' ~ ($helper-eval-counter⚛++);
  my $code = "use v6.d;\nmodule $sym \{\n$body\n}\n"
    ~ $sym ~ '::.pairs.grep({ .key.starts-with("&") }).map({ .key.substr(1) => .value }).hash';

  my $loaded = try EVAL $code;
  ($loaded ~~ Associative) ?? $loaded.hash !! %()
}

method !helper-module-subs(Str:D $module --> Hash) {
  return ((&!helper-loader)($module) // %()) if &!helper-loader.defined;

  self!load-helper-module($module)
}

method !helper-module-file(Str:D $module --> IO::Path) {
  my $relative = $module.subst('::', '/', :g) ~ '.rakumod';

  for @!helper-paths -> $path {
    my $file = $path.IO.add($relative);
    return $file if $file.e;
  }

  IO::Path
}

method !load-helper-module(Str:D $module --> Hash) {
  my $file = self!helper-module-file($module);
  return %() unless $file.defined && $file.e;

  self!compile-once("helper:$module",
    lookup => {
      my $entry = %!helper-module-cache{$module};
      ($entry.defined && (!$!reload || $entry<mtime> == $file.modified.Num)) ?? $entry<subs> !! Nil
    },
    build => {
      MVC::Keayl::Notifications.instrument('compile.keayl', %( file => $file.absolute ), { eval-helper-subs($file) })
    },
    store => -> %subs {
      %!helper-module-cache{$module} = { mtime => $file.modified.Num, :%subs };
    },
  )
}

method !controller-helper-modules($controller --> List) {
  my @modules = 'ApplicationHelper';

  for $controller.^mro.reverse -> $class {
    my $name = $class.^name.subst(/^ 'GLOBAL::' /, '');
    next unless $name.ends-with('Controller');
    next if $name eq 'MVC::Keayl::Controller';

    my $helper = $name.subst(/'Controller' $/, 'Helper');
    @modules.push: $helper unless @modules.first({ $_ eq $helper }).defined;
  }

  @modules.List
}

method !helper-closures(:$controller --> Hash) {
  %(
    content_for  => -> $name, $value     { $*KEAYL-CONTENT{$name} = $value; '' },
    partial      => -> $name, %opts?     { self.render-partial($name, (%opts // {}), :$controller) },
    partial_for  => -> $object, %opts?   { self.render-object($object, (%opts // {}), :$controller) },
    partial_each => -> $name, @items, *%opts { self.render-collection($name, @items, :$controller, |%opts) },
    translate    => -> $key, *%opts      { $controller.defined ?? $controller.translate($key, |%opts) !! $key },
    t            => -> $key, *%opts      { $controller.defined ?? $controller.translate($key, |%opts) !! $key },
    localize     => -> $value, *%opts    { $controller.defined ?? $controller.localize($value, |%opts) !! ~$value },
    l            => -> $value, *%opts    { $controller.defined ?? $controller.localize($value, |%opts) !! ~$value },
    escape       => -> $value            { html-escape(~$value) },
    raw          => -> $value            { ~$value },
    sanitize     => -> $value, *%opts    { ~sanitize(~$value, |%opts) },
    json         => -> $value            { json-escape(~$value) },
    link_to      => -> $body, $url?, %opts?    { ~link-to($body, $url, (%opts // {})) },
    button_to    => -> $body, $url, %opts?     { ~button-to($body, $url, (%opts // {})) },
    url_for      => -> $target                 { url-for($target) },
    tag          => -> $name, %opts?           { ~tag($name, (%opts // {})) },
    content_tag  => -> $name, $inner?, %opts?  { ~content-tag($name, $inner, (%opts // {})) },
    button_tag   => -> $content = 'Button', %opts? { ~button-tag($content, (%opts // {})) },
    javascript_tag => -> $content, %opts?      { ~javascript-tag($content, (%opts // {})) },
    time_tag     => -> $date, $inner?, %opts?  { ~time-tag($date, $inner, (%opts // {})) },
    auto_discovery_link_tag => -> $type = 'rss', $url = '', %opts? { ~auto-discovery-link-tag($type, $url, (%opts // {})) },
    atom_feed    => -> :$url, :&content        { ~atom-feed(:$url, :&content) },
    image_submit_tag => -> $source, %opts?     { ~image-submit-tag($source, (%opts // {}), :resolver(&!asset-resolver)) },
    options_for_select => -> @choices, $selected? { ~options-for-select(@choices, $selected) },
    options_from_collection_for_select => -> @collection, $value-method, $text-method, $selected? { ~options-from-collection-for-select(@collection, $value-method, $text-method, $selected) },
    grouped_options_for_select => -> @grouped, $selected? { ~grouped-options-for-select(@grouped, $selected) },
    select_tag   => -> $name, $option-tags, %opts? { ~select-tag($name, $option-tags, (%opts // {})) },
    time_zone_select => -> $name, $selected?, %opts? { ~time-zone-select($name, $selected, (%opts // {})) },
    select_date  => -> $selected?, *%opts      { ~select-date($selected, |%opts) },
    select_time  => -> $selected?, *%opts      { ~select-time($selected, |%opts) },
    select_year  => -> $selected?, *%opts      { ~select-year($selected, |%opts) },
    select_month => -> $selected?, *%opts      { ~select-month($selected, |%opts) },
    select_day   => -> $selected?, *%opts      { ~select-day($selected, |%opts) },
    select_hour  => -> $selected?, *%opts      { ~select-hour($selected, |%opts) },
    select_minute => -> $selected?, *%opts     { ~select-minute($selected, |%opts) },
    select_second => -> $selected?, *%opts     { ~select-second($selected, |%opts) },
    highlight    => -> $text, $phrases, *%opts { ~highlight($text, $phrases, |%opts) },
    excerpt      => -> $text, $phrase, *%opts  { excerpt($text, $phrase, |%opts) },
    word_wrap    => -> $text, *%opts           { word-wrap($text, |%opts) },
    strip_tags   => -> $html                   { strip-tags($html) },
    strip_links  => -> $html                   { strip-links($html) },
    sanitize_css => -> $style                  { ~sanitize-css($style) },
    cycle        => -> *@values, *%opts        { cycle(|@values, |%opts) },
    current_cycle => -> *%opts                 { current-cycle(|%opts) },
    reset_cycle  => -> *%opts                  { reset-cycle(|%opts) },
    capture      => -> &block                  { ~capture(&block) },
    provide      => -> $name, $content         { provide($name, $content) },
    class_names  => -> *@tokens                { class-names(|@tokens) },
    data_attributes => -> %data                { data-attributes(%data) },
    form_with       => -> *%opts               { ~form-with(i18n => ($controller.defined ?? $controller.i18n !! Nil), |%opts) },
    simple_form_for => -> $model, *%opts       { ~simple-form-for($model, i18n => ($controller.defined ?? $controller.i18n !! Nil), |%opts) },
    image_tag    => -> $source, %opts?         { ~image-tag($source, (%opts // {}), :resolver(&!asset-resolver)) },
    asset_path   => -> $source, %opts?         { asset-path($source, :resolver(&!asset-resolver), |(%opts // {})) },
    stylesheet_link_tag    => -> *@sources, *%opts { ~stylesheet-link-tag(|@sources, :resolver(&!asset-resolver), |%opts) },
    javascript_include_tag => -> *@sources, *%opts { ~javascript-include-tag(|@sources, :resolver(&!asset-resolver), |%opts) },
    truncate        => -> $text, *%opts        { truncate($text, |%opts) },
    pluralize       => -> $count, $singular, *%opts { pluralize($count, $singular, |%opts) },
    simple_format   => -> $text, *%opts        { ~simple-format($text, |%opts) },
    number_with_delimiter => -> $number, *%opts { number-with-delimiter($number, |%opts) },
    number_to_currency    => -> $number, *%opts { number-to-currency($number, |%opts) },
    number_to_percentage  => -> $number, *%opts { number-to-percentage($number, |%opts) },
    number_to_human_size  => -> $number, *%opts { number-to-human-size($number, |%opts) },
    number_to_phone       => -> $number, *%opts { number-to-phone($number, |%opts) },
    number_to_human       => -> $number, *%opts { number-to-human($number, |%opts) },
    time_ago_in_words     => -> $from, *%opts   { time-ago-in-words($from, |%opts) },
    distance_of_time_in_words => -> $from, $to, *%opts { distance-of-time-in-words($from, $to, |%opts) },
  )
}
