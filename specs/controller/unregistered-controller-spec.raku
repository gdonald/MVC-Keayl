use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Dispatcher;
use MVC::Keayl::Request;
use MVC::Keayl::Routing;
use MVC::Keayl::Controller;

class LampsController is MVC::Keayl::Controller {
  method index { self.render(plain => 'all lamps') }
}

sub dispatch(Str:D $path) {
  my $router = routes {
    get '/lamps',   to => 'lamps#index';
    get '/widgets', to => 'widgets#index';
  };
  my $dispatcher = MVC::Keayl::Dispatcher.new(:$router, controllers => [LampsController]);
  $dispatcher.call(MVC::Keayl::Request.new(method => 'GET', :$path));
}

describe 'a route whose controller is not registered', {
  let(:widgets-response, { dispatch('/widgets') });

  it 'answers not found', {
    expect(widgets-response.status).to.be(404);
  }

  it 'carries the not found body', {
    expect(widgets-response.body).to.eq('Not Found');
  }

  it 'still dispatches a registered controller', {
    expect(dispatch('/lamps').body).to.eq('all lamps');
  }
}
