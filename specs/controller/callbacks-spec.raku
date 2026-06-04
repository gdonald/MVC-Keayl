use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Controller;
use ControllerFixtures;

describe 'MVC::Keayl::Controller callback order', {
  it 'runs before, around, action, and after callbacks in order', {
    my $controller = CallbackController.new;
    $controller.dispatch('show');
    expect($controller.trail.join(',')).to.be('before-1,before-2,around-pre,action,around-post,after-1');
  }
}

describe 'MVC::Keayl::Controller callback halting', {
  let(:controller, { GuardController.new });

  it 'halts the chain when a before callback renders', {
    controller.dispatch('show');
    expect(controller.trail.join(',')).to.be('guard');
  }

  it 'renders the response from the halting callback', {
    expect(controller.dispatch('show').body).to.be('denied');
  }
}

describe 'MVC::Keayl::Controller callback scoping', {
  it 'does not run a only-scoped callback for other actions', {
    my $controller = ScopedController.new;
    $controller.dispatch('index');
    expect($controller.trail.join(',')).to.be('index');
  }

  it 'runs a only-scoped callback for the listed action', {
    my $controller = ScopedController.new;
    $controller.dispatch('edit');
    expect($controller.trail.join(',')).to.be('admin,edit');
  }
}

describe 'MVC::Keayl::Controller conditional callbacks', {
  it 'runs an if callback when the condition holds', {
    my $controller = ConditionalController.new(:logged-in(False));
    $controller.dispatch('show');
    expect($controller.trail.join(',')).to.be('auth,action');
  }

  it 'skips an if callback when the condition fails', {
    my $controller = ConditionalController.new(:logged-in(True));
    $controller.dispatch('show');
    expect($controller.trail.join(',')).to.be('action');
  }
}

describe 'MVC::Keayl::Controller callback inheritance', {
  it 'runs an inherited before callback in a subclass', {
    my $controller = BaseAuthController.new;
    $controller.dispatch('show');
    expect($controller.trail.join(',')).to.be('auth,action');
  }

  it 'removes an inherited callback with skip-before-action', {
    my $controller = PublicController.new;
    $controller.dispatch('show');
    expect($controller.trail.join(',')).to.be('action');
  }
}
