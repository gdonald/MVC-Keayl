use v6.d;
use MVC::Keayl::Application;
use MVC::Keayl::Routing;
use MVC::Keayl::Adapter::Cro;

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

  @created.List
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
    IGNORE
}
