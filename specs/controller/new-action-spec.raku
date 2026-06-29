use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Dispatcher;
use MVC::Keayl::Request;
use MVC::Keayl::Routing;
use MVC::Keayl::Controller;

# A RESTful controller may expose a `new` action (GET /resource/new renders the
# blank form). The action method named `new` shadows the `.new` constructor, so
# the dispatcher must construct the controller without going through `.new` and
# must accept `new` as a dispatchable action.

class SprocketsController is MVC::Keayl::Controller {
  method new   { self.render(plain => 'new sprocket form') }
  method index { self.render(plain => 'all sprockets') }
}

sub dispatch(Str:D $method, Str:D $path) {
  my $router = routes {
    get '/sprockets',     to => 'sprockets#index';
    get '/sprockets/new', to => 'sprockets#new';
  };
  my $dispatcher = MVC::Keayl::Dispatcher.new(:$router, controllers => [SprocketsController]);
  $dispatcher.call(MVC::Keayl::Request.new(:$method, :$path));
}

describe 'a controller with a RESTful new action', {
  let(:new-response, { dispatch('GET', '/sprockets/new') });

  it 'constructs and dispatches without a server error', {
    expect(new-response.status).to.be(200);
  }

  it 'runs the new action and renders its form', {
    expect(new-response.body).to.eq('new sprocket form');
  }

  it 'still dispatches the other actions on the same controller', {
    expect(dispatch('GET', '/sprockets').body).to.eq('all sprockets');
  }
}
