use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::View;
use MVC::Keayl::Controller;
use CLIFixtures;

class AdminController is MVC::Keayl::Controller { }
class GadgetsController is AdminController {
  method widget-count { 42 }
}

my %modules =
  ApplicationHelper => %( shout => -> $s { $s.uc } ),
  AdminHelper       => %( badge => -> $n { "[$n]" } ),
  GadgetsHelper     => %(
    gizmo         => -> $x { "g:$x" },
    'count-label' => -> { 'count:' ~ $*KEAYL-CONTROLLER.widget-count },
  );

my $cached;

sub rendered() {
  $cached //= do {
    my $views = temp-dir('spec-helper-modules');
    write-file($views.add('gadgets/show.html.haml'),
      "%ul\n  %li= shout('hi')\n  %li= badge(7)\n  %li= gizmo('z')\n  %li= count-label\n");

    my $view = MVC::Keayl::View.new(
      paths         => [$views.Str],
      helper-loader => -> $module { %modules{$module} // %() },
    );
    $view.render-template('gadgets/show', {}, controller => GadgetsController.new)
  }
}

describe 'helper modules in views', {
  it 'exposes a global ApplicationHelper sub as a bare call', {
    expect(rendered().contains('<li>HI</li>')).to.be-truthy;
  }

  it 'exposes an inherited parent-controller helper', {
    expect(rendered().contains('<li>[7]</li>')).to.be-truthy;
  }

  it "exposes the controller's own helper", {
    expect(rendered().contains('<li>g:z</li>')).to.be-truthy;
  }

  it 'lets a helper reach controller state through the dynamic variable', {
    expect(rendered().contains('<li>count:42</li>')).to.be-truthy;
  }
}
