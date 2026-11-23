use v6.d;
use MVC::Keayl::View::Handler;
use MVC::Keayl::Controller;
use MVC::Keayl::Notifications;
use CLIFixtures;

unit module ViewFixtures;

constant COMPILE-DELAY = 0.2;

class CompileController is MVC::Keayl::Controller is export { }

class SlowCountingHandler does MVC::Keayl::View::Handler is export {
  has atomicint $.compiles = 0;

  method compile(Str:D $source) {
    $!compiles⚛++;
    sleep COMPILE-DELAY;

    $source
  }

  method render($compiled, %locals --> Str) { $compiled.trim }
}

class FailOnceHandler does MVC::Keayl::View::Handler is export {
  has $.attempts = 0;

  method compile(Str:D $source) {
    die 'unexpected end of template' if $!attempts++ == 0;
    $source
  }

  method render($compiled, %locals --> Str) { $compiled.trim }
}

sub compile-fixture(Str:D $label --> List) is export {
  my $root    = temp-dir($label);
  my $views   = $root.add('views');
  my $helpers = $root.add('helpers');

  write-file($views.add('compile/show.html.haml'), "%p= shout('hi')\n");
  write-file($views.add('layouts/application.html.haml'), "%main\n  != content\n");
  write-file($views.add('compile/report.html.count'), "REPORT\n");
  write-file($helpers.add('ApplicationHelper.rakumod'), "unit module ApplicationHelper;\nour sub shout(\$s) \{ \$s.uc }\n");
  write-file($helpers.add('Reports/ChartHelper.rakumod'), "unit module Reports::ChartHelper;\nour sub bar(\$s) \{ \"bar:\$s\" }\n");

  ($views, $helpers)
}

sub compiled-files(&block --> List) is export {
  my @files;
  my $id = MVC::Keayl::Notifications.subscribe('compile.keayl', -> %payload { @files.push: %payload<file>.IO.basename });

  block();
  MVC::Keayl::Notifications.unsubscribe($id);

  @files.List
}
