use v6.d;

unit module CLIFixtures;

# A stand-in for an output or error handle that collects everything written to
# it, so a test can assert on what a CLI command printed.
class StringSink is export {
  has Str $.text is rw = '';

  method print(*@args) { $!text ~= @args.join;        Nil }
  method say(*@args)   { $!text ~= @args.join ~ "\n"; Nil }
  method note(*@args)  { $!text ~= @args.join ~ "\n"; Nil }
}

# A stand-in for an input handle that yields a fixed list of lines, so the
# console REPL can be driven without a terminal.
class LineSource is export {
  has @.input;

  method lines() { @!input }
}

sub temp-dir(Str:D $label --> IO::Path) is export {
  my $dir = $*TMPDIR.add("keayl-cli-$label-$*PID");
  $dir.mkdir;
  $dir
}

sub write-file(IO() $path, Str:D $content --> IO::Path) is export {
  $path.parent.mkdir;
  $path.spurt: $content;
  $path
}

sub minimal-app-file(IO() $dir --> IO::Path) is export {
  write-file($dir.add('application.raku'), q:to/RAKU/);
    use MVC::Keayl::Application;
    MVC::Keayl::Application.new;
    RAKU
}

sub base-routes-file(IO() $root --> IO::Path) is export {
  write-file($root.add('config/routes.raku'), q:to/RAKU/);
    use MVC::Keayl::Routing;

    routes {
      root to => 'home#index';
    }
    RAKU
}
