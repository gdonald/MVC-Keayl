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

sub usage(--> Str) is export {
  qq:to/USAGE/.chomp;
    Usage: {NAME} <command> [options]

    Commands:
      new <name>              create a new application skeleton
      server                  boot the application (alias: s)
      routes                  print the route table
      console                 open a REPL with the app loaded (alias: c)
      generate <type> <name>  run a generator (alias: g)
                                types: controller, scaffold
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

sub scaffold-app(Str:D $name, IO() :$into = '.'.IO --> List) is export {
  my $root = $into.add($name);

  my %files =
    'config/application.json'             => application-json($name),
    'config/application.raku'             => application-raku(),
    'config/routes.raku'                  => routes-raku(),
    'app/controllers/HomeController.rakumod' => home-controller(),
    'app/views/home/index.haml'           => home-view($name),
    'README.md'                           => readme($name),
    '.gitignore'                          => gitignore();

  my @created;

  for %files.keys.sort -> $relative {
    my $file = $root.add($relative);
    $file.parent.mkdir;
    $file.spurt: %files{$relative};
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

sub generate-scaffold(Str:D $name, IO() :$root = '.'.IO, :$out = $*OUT, :$err = $*ERR --> Int) is export {
  my $singular = singularize($name.lc);
  my $plural   = pluralize($singular);
  my $model    = camelize($singular);
  my $class    = camelize($plural) ~ 'Controller';

  emit-file($root.add("app/models/$model.rakumod"), model-source($model), :$out);
  emit-file($root.add("app/controllers/$class.rakumod"), scaffold-controller-source($class, $model, $singular, $plural), :$out);

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

    != $partial("__PLURAL__/form", %( __SINGULAR__ => $__SINGULAR__ ))

    %a(href="/__PLURAL__") Back
    HAML
}

sub scaffold-edit-view(Str:D $singular, Str:D $plural --> Str) {
  fill(q:to/HAML/, %( '__SINGULARTITLE__' => $singular.tc, '__SINGULAR__' => $singular, '__PLURAL__' => $plural ));
    %h1 Edit __SINGULARTITLE__

    != $partial("__PLURAL__/form", %( __SINGULAR__ => $__SINGULAR__ ))

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

sub application-json(Str:D $name --> Str) {
  qq:to/JSON/;
    \{
      "shared":      \{ "app-name": "$name" },
      "development": \{ "database": \{ "adapter": "sqlite", "database": "db/development.sqlite3" } },
      "test":        \{ "database": \{ "adapter": "sqlite", "database": "db/test.sqlite3" } },
      "production":  \{ "log-level": "error" }
    }
    JSON
}

sub application-raku(--> Str) {
  q:to/RAKU/;
    use MVC::Keayl::Application;
    use MVC::Keayl::Config;
    use MVC::Keayl::Routing;
    use lib 'app/controllers';
    use HomeController;

    MVC::Keayl::Application.new(
      config      => MVC::Keayl::Config.load('config/application.json'),
      router      => load-routes('config/routes.raku'),
      controllers => [HomeController],
    );
    RAKU
}

sub routes-raku(--> Str) {
  q:to/RAKU/;
    use MVC::Keayl::Routing;

    routes {
      root to => 'home#index';
    }
    RAKU
}

sub home-controller(--> Str) {
  q:to/RAKU/;
    use v6.d;
    use MVC::Keayl::Controller;

    unit class HomeController is MVC::Keayl::Controller;

    method index {
      self.render(:plain('Welcome to Keayl'));
    }
    RAKU
}

sub home-view(Str:D $name --> Str) {
  qq:to/HAML/;
    %h1 Welcome to $name
    %p Edit app/views/home/index.haml to change this page.
    HAML
}

sub readme(Str:D $name --> Str) {
  qq:to/MD/;
    # $name

    A Keayl application.

    ## Running

    ```
    keayl server
    ```

    ## Routes

    ```
    keayl routes
    ```
    MD
}

sub gitignore(--> Str) {
  q:to/IGNORE/;
    /db/*.sqlite3
    /.precomp
    /tmp
    /config/master.key
    /config/credentials/*.key
    IGNORE
}
