use v6.d;
use MVC::Keayl::Application;
use MVC::Keayl::Routing;
use MVC::Keayl::Adapter::Cro;
use MVC::Keayl::Credentials;
use MVC::Keayl::Assets;

unit module MVC::Keayl::CLI;

constant NAME = 'keayl';

sub program-name(--> Str) is export { NAME }

sub version(IO() $base --> Str) is export {
  my $meta = $base.add('META6.json');
  return 'unknown' unless $meta.e;

  with $meta.slurp ~~ / '"version"' \s* ':' \s* '"' (<-["]>+) '"' / {
    return ~$0;
  }

  'unknown'
}

sub framework-version(--> Str) is export {
  with try ($?DISTRIBUTION.meta<version> // $?DISTRIBUTION.meta<ver>) {
    return .Str unless .Str eq '*';
  }

  my $dir = $?FILE.IO.parent;

  loop {
    return version($dir) if $dir.add('META6.json').e;

    last if $dir.parent === $dir;
    $dir = $dir.parent;
  }

  'unknown'
}

sub usage(--> Str) is export {
  qq:to/USAGE/.chomp;
    Usage: {NAME} <command> [options]

    Commands:
      new <name>              create a new application skeleton
                              (--database=sqlite|postgres|mysql, default sqlite)
      server                  boot the application (alias: s)
      routes                  print the route table
      console                 open a REPL with the app loaded (alias: c)
      generate <type> <name>  run a generator (alias: g)
                                types: controller, scaffold, mailer, job,
                                       channel, helper, model, migration,
                                       resource
      credentials-edit        decrypt, edit, and re-encrypt the credentials
      assets-precompile       fingerprint assets and build the manifest
      version                 print the {NAME} version
      help                    show this message

    Run `{NAME} <command> --help` for command-specific options.
    USAGE
}

sub routes-table(@table --> Str) is export {
  return '' unless @table;

  my @rows = @table.map(-> %row {
    %(
      name   => (%row<name> // '').Str,
      verbs  => (%row<verbs> // ()).join(','),
      path   => (%row<path> // '').Str,
      target => (%row<target> ~~ Str ?? %row<target> !! %row<target>.^name),
    )
  });

  my $name-width = max 4, |@rows.map(*<name>.chars);
  my $verb-width = max 4, |@rows.map(*<verbs>.chars);
  my $path-width = max 4, |@rows.map(*<path>.chars);

  @rows.map(-> %row {
    sprintf "%-*s  %-*s  %-*s  %s",
      $name-width, %row<name>,
      $verb-width, %row<verbs>,
      $path-width, %row<path>,
      %row<target>;
  }).join("\n")
}

sub print-routes(IO() $path = 'config/routes.raku', :$out = $*OUT, :$err = $*ERR --> Int) is export {
  unless $path.e {
    $err.note: "{NAME}: no $path found";
    return 1;
  }

  my @table = load-routes($path).route-table;
  $out.say: routes-table(@table) if @table;

  0
}

sub load-application(IO() $path = 'config/application.raku', :$err = $*ERR --> MVC::Keayl::Application) is export {
  unless $path.e {
    $err.note: "{NAME}: no $path found";
    return MVC::Keayl::Application;
  }

  EVALFILE $path
}

sub build-server(
  MVC::Keayl::Application:D $app,
  Str:D :$host = '127.0.0.1',
  Int:D :$port = 3000,
  Str:D :$scheme = 'http',
  --> MVC::Keayl::Adapter::Cro
) is export {
  MVC::Keayl::Adapter::Cro.new(:app($app.endpoint), :$host, :$port, :$scheme)
}

sub console(
  IO() $path = 'config/application.raku',
  :$in  = $*IN,
  :$out = $*OUT,
  :$err = $*ERR,
  --> Int
) is export {
  my $app = load-application($path, :$err);
  return 1 unless $app.defined;

  $app.boot;

  my $*KEAYL-APP = $app;

  $out.say: "{NAME} console ({$app.environment})";
  $out.print: 'keayl> ';

  for $in.lines -> $line {
    if $line.trim {
      {
        use MONKEY-SEE-NO-EVAL;
        $out.say: EVAL($line).gist;

        CATCH {
          default { $err.say: .message }
        }
      }
    }

    $out.print: 'keayl> ';
  }

  $out.say: '';
  0
}

sub scaffold-app(Str:D $name, IO() :$into = '.'.IO, Str:D :$database = 'sqlite' --> List) is export {
  normalize-database($database); # validate before writing any files

  my $root = $into.add($name);

  my %files =
    'META6.json'                             => app-meta($name),
    'config/application.json'                => application-json($name, :$database),
    'config/application.raku'                => application-raku(),
    'config/routes.raku'                     => routes-raku(),
    'app/controllers/HomeController.rakumod' => home-controller($name),
    'app/helpers/ApplicationHelper.rakumod'  => application-helper(),
    'app/models/.keep'                       => '',
    'app/views/layouts/application.html.haml' => application-layout(),
    'app/views/home/index.html.haml'         => home-view($name),
    'assets/favicon.svg'                     => favicon-svg(),
    'assets/css/style.css'                   => stylesheet(),
    'public/404.html'                        => exception-page('404', 'Not Found', 'The page you were looking for does not exist.'),
    'public/422.html'                        => exception-page('422', 'Unprocessable Entity', 'The change you wanted was rejected.'),
    'public/500.html'                        => exception-page('500', 'Internal Server Error', 'We are sorry, but something went wrong.'),
    'specs/home-spec.raku'                   => home-spec(),
    'tmp/.keep'                              => '',
    'README.md'                              => readme($name),
    '.gitignore'                             => gitignore();

  my %executables =
    'bin/server' => server-script(),
    'bin/dev'    => dev-script(),
    'bin/test'   => test-script();

  my @created;

  for %files.keys.sort -> $relative {
    my $file = $root.add($relative);
    $file.parent.mkdir;
    $file.spurt: %files{$relative};
    @created.push: $relative;
  }

  for %executables.keys.sort -> $relative {
    my $file = $root.add($relative);
    $file.parent.mkdir;
    $file.spurt: %executables{$relative};
    $file.chmod(0o755);
    @created.push: $relative;
  }

  my $master-key = generate-master-key();

  my $key-file = $root.add('config/master.key');
  $key-file.parent.mkdir;
  $key-file.spurt: $master-key;
  @created.push: 'config/master.key';

  my $credentials-file = $root.add('config/credentials.yml.enc');
  $credentials-file.spurt: encrypt-content(initial-credentials(), $master-key);
  @created.push: 'config/credentials.yml.enc';

  @created.List
}

sub initial-credentials(--> Str) {
  "secret-key-base: " ~ generate-master-key() ~ generate-master-key() ~ "\n"
}

sub launch-editor(Str:D $current --> Str) {
  my $tmp    = $*TMPDIR.add('keayl-credentials-' ~ $*PID ~ '.yml');
  my $editor = %*ENV<EDITOR> // %*ENV<VISUAL> // 'vi';

  $tmp.spurt: $current;
  run $editor, $tmp.Str;

  my $edited = $tmp.slurp;
  $tmp.unlink;

  $edited
}

sub assets-precompile(IO() :$root = '.'.IO, IO() :$source = $root.add('app/assets'), IO() :$output = $root.add('public/assets'), :$out = $*OUT, :$err = $*ERR --> Int) is export {
  unless $source.e {
    $err.say: "{NAME}: no asset source directory at {$source}";
    return 1;
  }

  $output.mkdir;

  my $manifest = MVC::Keayl::Assets::Manifest.build($source, :$output);
  $output.add('manifest.json').spurt: $manifest.to-json;

  $out.say: "{NAME}: precompiled {$manifest.assets.elems} assets to {$output}";

  0
}

sub credentials-edit(IO() :$root = '.'.IO, Str :$env, :&edit, :%env-vars = %*ENV, :$out = $*OUT, :$err = $*ERR --> Int) is export {
  my $credentials = try MVC::Keayl::Credentials.resolve(:$root, :$env, :%env-vars);

  without $credentials {
    $err.say: "{NAME}: no master key configured (set KEAYL_MASTER_KEY or create config/master.key)";
    return 1;
  }

  my $current = $credentials.content;
  $current = initial-credentials() if $current eq '';

  my $updated = (&edit // &launch-editor)($current);

  $credentials.save-content($updated);
  $out.say: "{NAME}: credentials updated";

  0
}

sub camelize(Str:D $name --> Str) is export {
  $name.split(/ <[-_]>+ /).grep(*.chars).map(*.tc).join
}

sub pluralize(Str:D $word --> Str) is export {
  return $word.subst(/ 'y' $/, 'ies') if $word ~~ / <-[aeiou]> 'y' $/;
  return $word ~ 'es' if $word ~~ / [ 's' | 'x' | 'z' | 'ch' | 'sh' ] $/;
  $word ~ 's'
}

sub singularize(Str:D $word --> Str) is export {
  return $word.subst(/ 'ies' $/, 'y') if $word ~~ / 'ies' $/;
  return $word.subst(/ 'es' $/, '') if $word ~~ / [ 's' | 'x' | 'z' | 'ch' | 'sh' ] 'es' $/;
  return $word.subst(/ 's' $/, '') if $word ~~ / <-[s]> 's' $/;
  $word
}

sub controller-class-name(Str:D $name --> Str) is export {
  camelize($name) ~ 'Controller'
}

sub emit-file(IO() $file, Str:D $content, :$out = $*OUT --> Bool) {
  if $file.e {
    $out.say: "  exists  $file";
    return False;
  }

  $file.parent.mkdir;
  $file.spurt: $content;

  $out.say: "  create  $file";
  True
}

sub insert-routes(IO() $path, @stubs, :$out = $*OUT, :$err = $*ERR --> Bool) is export {
  unless $path.e {
    $err.note: "{NAME}: no $path to add routes to";
    return False;
  }

  my @lines    = $path.lines;
  my $index    = @lines.first(:k, * ~~ / 'routes' \s* '{' | 'draw' \s* '{' /);

  without $index {
    $err.note: "{NAME}: no routes block found in $path";
    return False;
  }

  my @existing = @lines.map(*.trim);
  my @new      = @stubs.grep(-> $stub { !@existing.first(* eq $stub.trim) });

  return True unless @new;

  my @updated = |@lines[0 .. $index], |@new.map('  ' ~ *), |@lines[$index ^.. *];
  $path.spurt: @updated.join("\n") ~ "\n";

  $out.say: "  route   $path";
  True
}

sub generate-controller(Str:D $name, @actions, IO() :$root = '.'.IO, :$out = $*OUT, :$err = $*ERR --> Int) is export {
  my $class = controller-class-name($name);
  my $path  = $name.lc;

  emit-file($root.add("app/controllers/$class.rakumod"), controller-source($class, @actions), :$out);

  my $helper = helper-module-name($name);
  emit-file($root.add("app/helpers/$helper.rakumod"), helper-source($helper, $name), :$out);

  for @actions -> $action {
    emit-file($root.add("app/views/$path/$action.html.haml"), controller-view($path, $action), :$out);
  }

  insert-routes(
    $root.add('config/routes.raku'),
    @actions.map({ "get '/$path/$_', to => '$path#$_';" }),
    :$out, :$err,
  );

  0
}

sub mailer-class-name(Str:D $name --> Str)  { camelize($name) ~ 'Mailer' }
sub job-class-name(Str:D $name --> Str)     { camelize($name) ~ 'Job' }
sub channel-class-name(Str:D $name --> Str) { camelize($name) ~ 'Channel' }
sub helper-module-name(Str:D $name --> Str) { camelize($name) ~ 'Helper' }
sub model-class-name(Str:D $name --> Str)   { camelize(singularize($name)) }

sub parse-fields(@fields --> List) {
  @fields.map(-> $field {
    my ($field-name, $type) = $field.split(':', 2);
    %( name => $field-name, type => ($type // 'string') )
  }).List
}

sub component-test(IO() $root, Str:D $relative, Str:D $class, Str:D $use, :$out = $*OUT) {
  emit-file($root.add("t/{$relative}.rakutest"), test-stub($class, $use), :$out);
  emit-file($root.add("specs/{$relative}-spec.raku"), spec-stub($class, $use), :$out);
}

sub test-stub(Str:D $class, Str:D $use --> Str) {
  fill(q:to/RAKU/, %( '__CLASS__' => $class, '__USE__' => $use ));
    use v6.d;
    use lib 'lib';
    use Test;
    use __USE__;

    # TODO: test __CLASS__

    done-testing;
    RAKU
}

sub spec-stub(Str:D $class, Str:D $use --> Str) {
  fill(q:to/RAKU/, %( '__CLASS__' => $class, '__USE__' => $use ));
    use lib 'lib';
    use BDD::Behave;
    use __USE__;

    describe '__CLASS__', {
      # TODO: describe __CLASS__
    }
    RAKU
}

sub generate-mailer(Str:D $name, @actions, IO() :$root = '.'.IO, :$out = $*OUT --> Int) is export {
  my $class = mailer-class-name($name);
  my $path  = $name.lc ~ '_mailer';

  emit-file($root.add("app/mailers/$class.rakumod"), mailer-source($class, @actions), :$out);

  for @actions -> $action {
    emit-file($root.add("app/views/$path/$action.html.haml"), "%p $class\#$action", :$out);
    emit-file($root.add("app/views/$path/$action.text.haml"), "$class\#$action", :$out);
  }

  component-test($root, "mailers/$name", $class, $class, :$out);

  0
}

sub generate-job(Str:D $name, IO() :$root = '.'.IO, :$out = $*OUT --> Int) is export {
  my $class = job-class-name($name);

  emit-file($root.add("app/jobs/$class.rakumod"), job-source($class), :$out);
  component-test($root, "jobs/$name", $class, $class, :$out);

  0
}

sub generate-channel(Str:D $name, IO() :$root = '.'.IO, :$out = $*OUT --> Int) is export {
  my $class = channel-class-name($name);

  emit-file($root.add("app/channels/$class.rakumod"), channel-source($class), :$out);
  component-test($root, "channels/$name", $class, $class, :$out);

  0
}

sub generate-helper(Str:D $name, IO() :$root = '.'.IO, :$out = $*OUT --> Int) is export {
  my $module = helper-module-name($name);

  emit-file($root.add("app/helpers/$module.rakumod"), helper-source($module, $name), :$out);
  component-test($root, "helpers/$name", $module, $module, :$out);

  0
}

sub generate-migration(Str:D $name, @fields, IO() :$root = '.'.IO, Str :$timestamp, :$out = $*OUT --> Int) is export {
  my $stamp = $timestamp // migration-timestamp();
  my $table = $name.subst(/^ ['create' <[-_]>] /, '');

  emit-file(
    $root.add("db/migrate/$stamp-$name.raku"),
    migration-source(camelize($name), $table, parse-fields(@fields)),
    :$out,
  );

  0
}

sub generate-model(Str:D $name, @fields, IO() :$root = '.'.IO, Str :$timestamp, :$out = $*OUT --> Int) is export {
  my $class = model-class-name($name);
  my $table = pluralize($class.lc);

  emit-file($root.add("app/models/$class.rakumod"), model-source($class), :$out);
  generate-migration("create-$table", @fields, :$root, :$timestamp, :$out);
  component-test($root, "models/$name", $class, $class, :$out);

  0
}

sub generate-resource(Str:D $name, @fields, IO() :$root = '.'.IO, :$out = $*OUT, :$err = $*ERR --> Int) is export {
  my $singular = singularize($name).lc;
  my $plural   = pluralize($singular);
  my $class    = controller-class-name($plural);

  generate-model($singular, @fields, :$root, :$out);

  emit-file($root.add("app/controllers/$class.rakumod"), controller-source($class, []), :$out);
  insert-routes($root.add('config/routes.raku'), ["resources '$plural';"], :$out, :$err);

  0
}

sub migration-timestamp(--> Str) {
  my $now = DateTime.now;
  sprintf '%04d%02d%02d%02d%02d%02d', $now.year, $now.month, $now.day, $now.hour, $now.minute, $now.second.Int
}

sub mailer-source(Str:D $class, @actions --> Str) {
  my $methods = @actions.map(-> $action {
    "method $action \{\n  self.mail(to => 'to\@example.com', subject => '{$action.tc}');\n}"
  }).join("\n\n");

  fill(q:to/RAKU/, %( '__CLASS__' => $class, '__METHODS__' => $methods ));
    use v6.d;
    use MVC::Keayl::Mailer;

    unit class __CLASS__ is MVC::Keayl::Mailer;

    __METHODS__
    RAKU
}

sub job-source(Str:D $class --> Str) {
  fill(q:to/RAKU/, %( '__CLASS__' => $class ));
    use v6.d;
    use MVC::Keayl::Job;

    unit class __CLASS__ is MVC::Keayl::Job;

    method perform() {
    }
    RAKU
}

sub channel-source(Str:D $class --> Str) {
  fill(q:to/RAKU/, %( '__CLASS__' => $class ));
    use v6.d;
    use MVC::Keayl::Cable::Channel;

    unit class __CLASS__ is MVC::Keayl::Cable::Channel;

    method subscribed {
    }

    method unsubscribed {
    }
    RAKU
}

sub helper-source(Str:D $module, Str:D $name --> Str) {
  fill(q:to/RAKU/, %( '__MODULE__' => $module ));
    use v6.d;

    unit module __MODULE__;

    # View helpers for this controller, callable bare in its templates. Each
    # `our sub` becomes a helper:
    #
    #   our sub badge($text) { qq[<span class="badge">{$text}</span>] }
    #
    # In a template:  != badge('new')
    RAKU
}

sub application-helper(--> Str) {
  q:to/RAKU/;
    use v6.d;

    unit module ApplicationHelper;

    # Global view helpers, callable bare in every template with arguments and no
    # sigil. A helper may read request state through $*KEAYL-CONTROLLER.

    our sub nav-link($label, $href) {
      qq[<a href="$href">{$label}</a>]
    }
    RAKU
}

sub migration-source(Str:D $class, Str:D $table, @fields --> Str) {
  my $columns = @fields.map(-> %field { "      {%field<name>} => \{ :{%field<type>} }" }).join(",\n");

  fill(q:to/RAKU/, %( '__CLASS__' => $class, '__TABLE__' => $table, '__COLUMNS__' => $columns ));
    use ORM::ActiveRecord::Schema::Migration;

    class __CLASS__ is Migration {
      method up {
        self.create-table: '__TABLE__', [
    __COLUMNS__
        ]
      }

      method down {
        self.drop-table: '__TABLE__';
      }
    }
    RAKU
}

sub generate-scaffold(Str:D $name, IO() :$root = '.'.IO, :$out = $*OUT, :$err = $*ERR --> Int) is export {
  my $singular = singularize($name.lc);
  my $plural   = pluralize($singular);
  my $model    = camelize($singular);
  my $class    = camelize($plural) ~ 'Controller';

  emit-file($root.add("app/models/$model.rakumod"), model-source($model), :$out);
  emit-file($root.add("app/controllers/$class.rakumod"), scaffold-controller-source($class, $model, $singular, $plural), :$out);

  my $helper = helper-module-name($plural);
  emit-file($root.add("app/helpers/$helper.rakumod"), helper-source($helper, $plural), :$out);

  emit-file($root.add("app/views/$plural/index.html.haml"), scaffold-index-view($singular, $plural), :$out);
  emit-file($root.add("app/views/$plural/show.html.haml"),  scaffold-show-view($singular, $plural), :$out);
  emit-file($root.add("app/views/$plural/new.html.haml"),   scaffold-new-view($singular, $plural), :$out);
  emit-file($root.add("app/views/$plural/edit.html.haml"),  scaffold-edit-view($singular, $plural), :$out);
  emit-file($root.add("app/views/$plural/_form.html.haml"), scaffold-form-view($singular, $plural), :$out);

  insert-routes($root.add('config/routes.raku'), [ "resources '$plural';" ], :$out, :$err);

  0
}

sub controller-source(Str:D $class, @actions --> Str) {
  my @lines =
    'use v6.d;',
    'use MVC::Keayl::Controller;',
    '',
    "unit class $class is MVC::Keayl::Controller;";

  for @actions -> $action {
    @lines.push: '';
    @lines.push: "method $action \{ }";
  }

  @lines.join("\n") ~ "\n"
}

sub fill(Str:D $template, %subs --> Str) {
  my $result = $template;
  $result = $result.subst(.key, .value, :g) for %subs.pairs;
  $result
}

sub controller-view(Str:D $path, Str:D $action --> Str) {
  fill(q:to/HAML/, %( '__PATHTITLE__' => $path.tc, '__PATH__' => $path, '__ACTION__' => $action ));
    %h1 __PATHTITLE__ #__ACTION__
    %p Find me in app/views/__PATH__/__ACTION__.html.haml
    HAML
}

sub model-source(Str:D $model --> Str) {
  fill(q:to/RAKU/, %( '__MODEL__' => $model ));
    use ORM::ActiveRecord::Model;

    unit class __MODEL__ is Model;
    RAKU
}

sub scaffold-controller-source(Str:D $class, Str:D $model, Str:D $singular, Str:D $plural --> Str) {
  fill(q:to/RAKU/, %( '__CLASS__' => $class, '__MODEL__' => $model, '__SINGULAR__' => $singular, '__PLURAL__' => $plural ));
    use v6.d;
    use MVC::Keayl::Controller;
    use __MODEL__;

    unit class __CLASS__ is MVC::Keayl::Controller;

    method index {
      self.render('index', locals => %( __PLURAL__ => __MODEL__.all ));
    }

    method show {
      self.render('show', locals => %( __SINGULAR__ => __MODEL__.find(self.params<id>) ));
    }

    method new {
      self.render('new', locals => %( __SINGULAR__ => __MODEL__.new ));
    }

    method create {
      my $record = __MODEL__.create(self.params<__SINGULAR__>);
      self.redirect-to("/__PLURAL__/{$record.id}");
    }

    method edit {
      self.render('edit', locals => %( __SINGULAR__ => __MODEL__.find(self.params<id>) ));
    }

    method update {
      my $record = __MODEL__.find(self.params<id>);
      $record.update(self.params<__SINGULAR__>);
      self.redirect-to("/__PLURAL__/{$record.id}");
    }

    method destroy {
      __MODEL__.find(self.params<id>).destroy;
      self.redirect-to('/__PLURAL__');
    }
    RAKU
}

sub scaffold-index-view(Str:D $singular, Str:D $plural --> Str) {
  fill(q:to/HAML/, %( '__PLURALTITLE__' => $plural.tc, '__SINGULAR__' => $singular, '__PLURAL__' => $plural ));
    %h1 __PLURALTITLE__

    %ul
      - for $__PLURAL__ -> $__SINGULAR__
        %li
          %a(href="/__PLURAL__/#{$__SINGULAR__.id}")= $__SINGULAR__.id

    %a(href="/__PLURAL__/new") New __SINGULAR__
    HAML
}

sub scaffold-show-view(Str:D $singular, Str:D $plural --> Str) {
  fill(q:to/HAML/, %( '__SINGULARTITLE__' => $singular.tc, '__SINGULAR__' => $singular, '__PLURAL__' => $plural ));
    %h1 __SINGULARTITLE__

    %p= $__SINGULAR__.id

    %a(href="/__PLURAL__/#{$__SINGULAR__.id}/edit") Edit
    %a(href="/__PLURAL__") Back
    HAML
}

sub scaffold-new-view(Str:D $singular, Str:D $plural --> Str) {
  fill(q:to/HAML/, %( '__SINGULARTITLE__' => $singular.tc, '__SINGULAR__' => $singular, '__PLURAL__' => $plural ));
    %h1 New __SINGULARTITLE__

    != partial("__PLURAL__/form", %( __SINGULAR__ => $__SINGULAR__ ))

    %a(href="/__PLURAL__") Back
    HAML
}

sub scaffold-edit-view(Str:D $singular, Str:D $plural --> Str) {
  fill(q:to/HAML/, %( '__SINGULARTITLE__' => $singular.tc, '__SINGULAR__' => $singular, '__PLURAL__' => $plural ));
    %h1 Edit __SINGULARTITLE__

    != partial("__PLURAL__/form", %( __SINGULAR__ => $__SINGULAR__ ))

    %a(href="/__PLURAL__") Back
    HAML
}

sub scaffold-form-view(Str:D $singular, Str:D $plural --> Str) {
  fill(q:to/HAML/, %( '__SINGULAR__' => $singular, '__PLURAL__' => $plural ));
    %form(action="/__PLURAL__" method="post")
      %label Name
      %input(type="text" name="__SINGULAR__[name]")
      %button(type="submit") Save
    HAML
}

# Map a user-facing --database value onto the adapter token ORM::ActiveRecord
# reads from config (its DB.adapter-class-for accepts these), or die on an
# unsupported value so `keayl new --database=foo` fails loudly.
sub normalize-database(Str:D $database --> Str) is export {
  given $database.lc {
    when 'sqlite' | 'sqlite3'                     { 'sqlite' }
    when 'pg' | 'postgres' | 'postgresql'         { 'pg' }
    when 'mysql' | 'mysql2' | 'mariadb'           { 'mysql' }
    default {
      die "keayl new: unsupported --database '$database' (sqlite, postgres, mysql)";
    }
  }
}

# The per-environment database name for a given adapter. SQLite is a file under
# db/; the server adapters get a conventional <app>_<env> database name.
sub database-name(Str:D $adapter, Str:D $app, Str:D $env --> Str) {
  return "db/$env.sqlite3" if $adapter eq 'sqlite';
  my $slug = $app.lc.subst(/<-[a..z0..9]>+/, '_', :g).subst(/^_+ | _+$/, '', :g);
  "{$slug}_$env";
}

# Emit a config that ORM::ActiveRecord's `ar`/`DB.shared` can read: each
# environment carries a `primary` connection block, and `test` declares the
# parallel worker count for behave isolated mode.
sub application-json(Str:D $name, Str:D :$database = 'sqlite' --> Str) {
  my $adapter = normalize-database($database);
  my $dev     = database-name($adapter, $name, 'development');
  my $test    = database-name($adapter, $name, 'test');
  my $prod    = database-name($adapter, $name, 'production');

  qq:to/JSON/;
    \{
      "shared":      \{ "app-name": "$name" },
      "development": \{ "primary": \{ "adapter": "$adapter", "name": "$dev" } },
      "test":        \{ "parallel": 16, "primary": \{ "adapter": "$adapter", "name": "$test" } },
      "production":  \{ "log-level": "error", "primary": \{ "adapter": "$adapter", "name": "$prod" } }
    }
    JSON
}

sub application-raku(--> Str) {
  q:to/RAKU/;
    use MVC::Keayl::Application;
    use MVC::Keayl::Config;
    use MVC::Keayl::Routing;
    use MVC::Keayl::HealthController;
    use MVC::Keayl::PWAController;
    use MVC::Keayl::Middleware::Static;
    use lib 'app/controllers';
    use HomeController;

    my $app = MVC::Keayl::Application.new(
      config      => MVC::Keayl::Config.load('config/application.json'),
      router      => load-routes('config/routes.raku'),
      controllers => [HomeController, MVC::Keayl::HealthController, MVC::Keayl::PWAController],
    );

    $app.middleware.prepend('static', MVC::Keayl::Middleware::Static,
      root       => 'assets'.IO,
      url-prefix => '/assets');

    $app;
    RAKU
}

sub exception-page(Str:D $code, Str:D $title, Str:D $message --> Str) {
  fill(q:to/HTML/, %( '__CODE__' => $code, '__TITLE__' => $title, '__MESSAGE__' => $message ));
    <!DOCTYPE html>
    <html>
      <head>
        <title>__CODE__ __TITLE__</title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
      </head>
      <body>
        <h1>__CODE__ __TITLE__</h1>
        <p>__MESSAGE__</p>
      </body>
    </html>
    HTML
}

sub routes-raku(--> Str) {
  q:to/RAKU/;
    use MVC::Keayl::Routing;

    routes {
      root to => 'home#index';

      get '/up', to => 'health#show';

      get '/manifest.json',     to => 'pwa#manifest';
      get '/service-worker.js', to => 'pwa#service-worker';
    }
    RAKU
}

sub home-controller(Str:D $name --> Str) {
  qq:to/RAKU/;
    use v6.d;
    use MVC::Keayl::Controller;

    unit class HomeController is MVC::Keayl::Controller;

    method index \{
      self.assign('page-title', '$name');
    }
    RAKU
}

sub home-view(Str:D $name --> Str) {
  qq:to/HAML/;
    %section.welcome
      %h1 Welcome to $name
      %p Edit app/views/home/index.html.haml to change this page.
      %p
        %a\{href: '/up'} Health check
    HAML
}

sub application-layout(--> Str) {
  q:to/HAML/;
    !!! 5
    %html{lang: 'en'}
      %head
        %meta{charset: 'utf-8'}
        %meta{name: 'viewport', content: 'width=device-width, initial-scale=1'}
        %title= $page-title
        %link{rel: 'icon', type: 'image/svg+xml', href: '/assets/favicon.svg'}
        %link{rel: 'stylesheet', href: '/assets/css/style.css'}
      %body
        %main
          != yield()
    HAML
}

sub readme(Str:D $name --> Str) {
  qq:to/MD/;
    # $name

    A Keayl application.

    ## Running

    ```
    bin/dev
    ```

    `bin/dev` runs the app locally on http://127.0.0.1:3000. It is a thin wrapper
    over `bin/server`, which boots the application with the Cro adapter.

    ## Tests

    ```
    bin/test
    ```

    `bin/test` runs the specs in `specs/` with behave. Set `SHOW_CHROME` to run the
    browser specs in a visible window.

    ## Routes

    ```
    keayl routes
    ```
    MD
}

sub gitignore(--> Str) {
  q:to/IGNORE/;
    /db/*.sqlite3
    .precomp/
    /tmp/*
    !/tmp/.keep
    .behave-failures
    .DS_Store
    /config/master.key
    /config/credentials/*.key
    IGNORE
}

sub app-meta(Str:D $name --> Str) {
  q:to/JSON/.subst('__NAME__', camelize($name));
    {
      "name": "__NAME__",
      "description": "A Keayl application",
      "version": "0.0.1",
      "api": "1",
      "perl": "6.d",
      "authors": [],
      "license": "Artistic-2.0",
      "depends": [
        "MVC::Keayl:auth<zef:gdonald>",
        "ORM::ActiveRecord:auth<zef:gdonald>"
      ],
      "test-depends": [
        "BDD::Behave:auth<zef:gdonald>",
        "BDD::Behave::Playwright:auth<zef:gdonald>",
        "WWW::Playwright:auth<zef:gdonald>",
        "ORM::Factory:auth<zef:gdonald>"
      ],
      "provides": {}
    }
    JSON
}

sub server-script(--> Str) {
  q:to/RAKU/;
    #!/usr/bin/env raku
    use MVC::Keayl::CLI;

    my Str $host = %*ENV<KEAYL_HOST> // '127.0.0.1';
    my Int $port = (%*ENV<KEAYL_PORT> // '3000').Int;

    my $app    = load-application('config/application.raku');
    my $server = build-server($app, :$host, :$port);

    $server.start;
    say "listening on http://$host:$port ({$app.environment})";

    react whenever signal(SIGINT, SIGTERM) {
      $server.stop;
      done;
    }
    RAKU
}

sub dev-script(--> Str) {
  q:to/SH/;
    #!/usr/bin/env bash
    set -euo pipefail

    cd "$(dirname "$0")/.."

    export KEAYL_ENV="${KEAYL_ENV:-development}"
    export KEAYL_HOST="${KEAYL_HOST:-127.0.0.1}"
    export KEAYL_PORT="${KEAYL_PORT:-3000}"

    exec raku bin/server
    SH
}

sub test-script(--> Str) {
  q:to/RAKU/;
    #!/usr/bin/env raku
    use v6.d;

    chdir $*PROGRAM.absolute.IO.parent.parent;

    %*ENV<KEAYL_ENV> //= 'test';

    my $jobs = max(2, ($*KERNEL.cpu-cores // 2) - 2);

    my @cmd = %*ENV<SHOW_CHROME>:exists
      ?? <behave>
      !! ('behave', '--parallel', $jobs.Str);

    # Cro prints benign teardown noise when a browser drops a connection mid-write.
    my @benign =
      'Cannot write to a closed socket',
      'connection reset by peer';

    my $proc    = Proc::Async.new(|@cmd, :err);
    my $drained = Promise.new;

    $proc.stderr.lines.tap(
      -> $line { $*ERR.say($line) unless @benign.first({ $line.contains($_) }) },
      done => { $drained.keep },
      quit => { $drained.keep },
    );

    my $exit = (await $proc.start).exitcode;
    await $drained;

    exit $exit;
    RAKU
}

sub home-spec(--> Str) {
  q:to/RAKU/;
    use BDD::Behave;
    use BDD::Behave::Playwright;
    use MVC::Keayl::TestSupport;
    use MVC::Keayl::CLI;

    my $server = LiveServer.new(
      app => load-application('config/application.raku').endpoint,
    ).start;

    END { $server.stop }

    describe 'the home page in a browser', {
      playwright-page(:artifacts<tmp>, base-url => { $server.base-url });

      before-each { visit('/') }

      it 'shows the welcome heading', -> $_ {
        expect(.page.locator('h1')).to.be-visible;
      }
    }
    RAKU
}

sub favicon-svg(--> Str) {
  q:to/SVG/;
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
      <rect width="64" height="64" rx="12" fill="#1f2933"/>
      <text x="32" y="44" font-family="sans-serif" font-size="34" font-weight="700" fill="#ffffff" text-anchor="middle">K</text>
    </svg>
    SVG
}

sub stylesheet(--> Str) {
  q:to/CSS/;
    :root { color-scheme: light dark; }

    * { box-sizing: border-box; }

    body {
      margin: 0;
      font-family: system-ui, sans-serif;
      line-height: 1.5;
    }

    main {
      max-width: 48rem;
      margin: 0 auto;
      padding: 3rem 1.5rem;
    }

    h1 { font-size: 2rem; }

    a { color: #2563eb; }
    CSS
}
