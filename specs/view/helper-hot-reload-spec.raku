use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::View;
use MVC::Keayl::Controller;
use CLIFixtures;

class ReloadController is MVC::Keayl::Controller { }

sub setup($label) {
  my $root    = temp-dir($label);
  my $helpers = $root.add('helpers');
  my $views   = $root.add('views');
  write-file($views.add('reload/show.html.haml'), "%p= label('x')\n");
  ($helpers, $views, $helpers.add('ReloadHelper.rakumod'))
}

sub write-helper($file, $version, $stamp) {
  write-file($file, "unit module ReloadHelper;\nour sub label(\$s) \{ \"$version:\$s\" }\n");
  run 'touch', '-m', '-t', $stamp, $file.Str;
}

sub render($view) { $view.render-template('reload/show', {}, controller => ReloadController.new) }

describe 'helper module hot reload', {
  it 'reloads a changed helper module when reload is on', {
    my ($helpers, $views, $file) = setup('spec-hot-reload-on');
    write-helper($file, 'v1', '202001010000');
    my $view = MVC::Keayl::View.new(paths => [$views.Str], helper-paths => [$helpers.Str], reload => True);

    aggregate-failures {
      expect(render($view).contains('v1:x')).to.be-truthy;
      write-helper($file, 'v2', '202501010000');
      expect(render($view).contains('v2:x')).to.be-truthy;
    }
  }

  it 'keeps the cached helper when reload is off', {
    my ($helpers, $views, $file) = setup('spec-hot-reload-off');
    write-helper($file, 'v3', '202001010000');
    my $view = MVC::Keayl::View.new(paths => [$views.Str], helper-paths => [$helpers.Str], reload => False);

    aggregate-failures {
      expect(render($view).contains('v3:x')).to.be-truthy;
      write-helper($file, 'v4', '203012312359');
      expect(render($view).contains('v3:x')).to.be-truthy;
    }
  }
}
