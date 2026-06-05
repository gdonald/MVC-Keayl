use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Controller;
use ControllerFixtures;

sub render-show {
  HelperController.new(:view-renderer(StubRenderer.new)).dispatch('show').body
}

describe 'MVC::Keayl::Controller view locals', {
  it 'passes a helper-method value to the template', {
    expect(render-show.contains('current-user=Ada')).to.be-truthy;
  }

  it 'passes an assigned value to the template', {
    expect(render-show.contains('title=Hello')).to.be-truthy;
  }

  it 'exposes a helper inherited from a base controller', {
    expect(render-show.contains('site-name=Keayl')).to.be-truthy;
  }

  it 'does not expose a method that is not a helper', {
    expect(render-show.contains('show=')).to.be-falsy;
  }
}

describe 'MVC::Keayl::Controller local precedence', {
  it 'lets an explicit local override an assigned value', {
    my $body = HelperController.new(:view-renderer(StubRenderer.new)).dispatch('override-local').body;
    expect($body.contains('title=from-locals')).to.be-truthy;
  }
}

describe 'MVC::Keayl::Controller assigns', {
  it 'records assigned values on the controller', {
    my $controller = HelperController.new(:view-renderer(StubRenderer.new));
    $controller.dispatch('show');
    expect($controller.assigns<title>).to.be('Hello');
  }
}
