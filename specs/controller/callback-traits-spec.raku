use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Request;
use MVC::Keayl::Controller;

class TraitController is MVC::Keayl::Controller {
  has @.trail;

  method authenticate is before-action(except => <public>) { @!trail.push('auth') }
  method timer($next) is around-action { @!trail.push('around-in'); $next(); @!trail.push('around-out') }
  method audit is after-action { @!trail.push('audit') }

  method show   { @!trail.push('show') }
  method public { @!trail.push('public') }
}

sub trail(Str:D $action) {
  my $controller = TraitController.new(request => MVC::Keayl::Request.new(:method<GET>, :path("/$action")));
  $controller.dispatch($action);
  $controller.trail.join(',')
}

describe 'callback traits on method declarations', {
  it 'runs before, around, and after callbacks attached with traits in order', {
    expect(trail('show')).to.be('auth,around-in,show,around-out,audit');
  }

  it 'honors the except option on a before-action trait', {
    expect(trail('public')).to.be('around-in,public,around-out,audit');
  }
}
