use v6.d;
use MVC::Keayl::View::Handler::HAML;
use MVC::Keayl::SafeString;
use MVC::Keayl::Helpers::Tag;
use MVC::Keayl::Helpers::Url;
use MVC::Keayl::Helpers::Asset;

unit class MVC::Keayl::View;

has @.paths;
has %.handlers;
has Str  $.default-handler = 'haml';
has Str  $.default-format  = 'html';
has Bool $.cache  = True;
has Bool $.reload = True;
has      &.asset-resolver = &default-asset-path;
has      %!store;

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
# precedence: {path}/{name}.{format}.{ext}, falling back to {path}/{name}.{ext}.
method resolve(Str:D $name, Str:D $format --> IO::Path) {
  for @!paths -> $path {
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

method !lookup-name(Str:D $name, $controller --> Str) {
  return $name if $name.contains('/');
  return $name without $controller;
  $controller.controller-path ~ '/' ~ $name
}

method !compiled-for(IO::Path:D $file --> List) {
  my $key     = $file.absolute;
  my $handler = %!handlers{$file.extension} // die "no view handler for .{$file.extension}";

  with %!store{$key} -> $entry {
    return ($entry<compiled>, $handler) if !$!reload || $entry<mtime> == $file.modified.Num;
  }

  my $compiled = $handler.compile($file.slurp);
  %!store{$key} = { mtime => $file.modified.Num, :$compiled } if $!cache;

  ($compiled, $handler)
}

method render-template(Str:D $name, %locals, Str :$format, :$controller --> Str) {
  my $lookup = self!lookup-name($name, $controller);
  my $fmt    = $format // $!default-format;
  my $file   = self.resolve($lookup, $fmt);

  die 'template not found: ' ~ $lookup ~ '.' ~ $fmt unless $file.defined && $file.e;

  my ($compiled, $handler) = self!compiled-for($file);
  $handler.render($compiled, self!template-locals(%locals, :$controller))
}

method render-inline(Str:D $template, %locals, :$controller --> Str) {
  my $handler = %!handlers{$!default-handler} // die "no view handler '$!default-handler'";
  $handler.render($handler.compile($template), self!template-locals(%locals, :$controller))
}

method render-layout(Str:D $layout, Str:D $content, %locals, :$controller --> Str) {
  my $file = self.resolve('layouts/' ~ $layout, $!default-format);
  return $content unless $file.defined && $file.e;

  my ($compiled, $handler) = self!compiled-for($file);
  $handler.render($compiled, self!layout-locals(%locals, $content, :$controller))
}

method layout-exists(Str:D $name --> Bool) {
  my $file = self.resolve('layouts/' ~ $name, $!default-format);
  $file.defined && $file.e
}

method render-partial(Str:D $name, %locals = {}, :$controller --> Str) {
  my $lookup = self!lookup-name(underscore-last($name), $controller);
  my $file   = self.resolve($lookup, $!default-format);

  die 'partial not found: ' ~ $name unless $file.defined && $file.e;

  my ($compiled, $handler) = self!compiled-for($file);
  $handler.render($compiled, self!template-locals(%locals, :$controller))
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

method !template-locals(%locals, :$controller --> Hash) {
  self!view-helpers(%locals, :$controller)
}

method !layout-locals(%locals, Str:D $content, :$controller --> Hash) {
  %(
    self!view-helpers(%locals, :$controller),
    content => $content,
    yield   => -> $name? { $name.defined ?? ($*KEAYL-CONTENT{$name} // '') !! $content },
  )
}

method !view-helpers(%locals, :$controller --> Hash) {
  %(
    %locals,
    content_for  => -> $name, $value     { $*KEAYL-CONTENT{$name} = $value; '' },
    partial      => -> $name, %opts?     { self.render-partial($name, (%opts // {}), :$controller) },
    partial_for  => -> $object, %opts?   { self.render-object($object, (%opts // {}), :$controller) },
    partial_each => -> $name, @items, *%opts { self.render-collection($name, @items, :$controller, |%opts) },
    escape       => -> $value            { html-escape(~$value) },
    raw          => -> $value            { ~$value },
    sanitize     => -> $value, *%opts    { ~sanitize(~$value, |%opts) },
    json         => -> $value            { json-escape(~$value) },
    link_to      => -> $body, $url?, %opts?    { ~link-to($body, $url, (%opts // {})) },
    button_to    => -> $body, $url, %opts?     { ~button-to($body, $url, (%opts // {})) },
    url_for      => -> $target                 { url-for($target) },
    tag          => -> $name, %opts?           { ~tag($name, (%opts // {})) },
    content_tag  => -> $name, $inner?, %opts?  { ~content-tag($name, $inner, (%opts // {})) },
    image_tag    => -> $source, %opts?         { ~image-tag($source, (%opts // {}), :resolver(&!asset-resolver)) },
    asset_path   => -> $source, %opts?         { asset-path($source, :resolver(&!asset-resolver), |(%opts // {})) },
    stylesheet_link_tag    => -> *@sources, *%opts { ~stylesheet-link-tag(|@sources, :resolver(&!asset-resolver), |%opts) },
    javascript_include_tag => -> *@sources, *%opts { ~javascript-include-tag(|@sources, :resolver(&!asset-resolver), |%opts) },
  )
}
