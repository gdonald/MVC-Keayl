use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Request;
use MVC::Keayl::Controller;
use ControllerFixtures;

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

  it 'runs before, around, after, and helper-method traits inherited from a precompiled base controller', {
    my class InheritsCallbacks is CallbackBaseController {
      method show { self.trail.push('show ' ~ self.base-label) }
    }

    my $controller = InheritsCallbacks.new(request => MVC::Keayl::Request.new(:method<GET>, :path</show>));
    $controller.dispatch('show');

    expect($controller.trail.join(',')).to.eq('base-before,base-around-in,show from-base,base-around-out,base-after');
  }

  it 'routes an exception to a rescue-from handler inherited from a precompiled base controller', {
    my class InheritsRescue is CallbackBaseController {
      method boom { X::CallbackBaseBoom.new.throw }
    }

    my $response = InheritsRescue.new(request => MVC::Keayl::Request.new(:method<GET>, :path</boom>)).dispatch('boom');

    expect($response.status).to.eq(503);
  }
}
