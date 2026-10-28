use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Controller;
use MVC::Keayl::Dispatcher;
use MVC::Keayl::Routing;
use MVC::Keayl::TestSupport;

class MountSecretController is MVC::Keayl::Controller {
  method show { self.render(plain => self.secret) }
}

sub engine-dispatcher(*%controller-options --> MVC::Keayl::Dispatcher) {
  my $router = routes { get '/secret', to => 'mount_secret#show' };
  MVC::Keayl::Dispatcher.new(:$router, controllers => [MountSecretController], :%controller-options)
}

sub host-session($engine, *%controller-options --> IntegrationSession) {
  my $router = routes { mount $engine, at => '/engine' };
  IntegrationSession.new(app => MVC::Keayl::Dispatcher.new(:$router, :%controller-options))
}

describe 'mounting a dispatcher', {
  context 'built without a secret', {
    it 'signs with the host secret', {
      expect(host-session(engine-dispatcher(), secret => 'host-secret').get('/engine/secret').body).to.be('host-secret');
    }
  }

  context 'built with its own secret', {
    it 'keeps its own secret', {
      expect(host-session(engine-dispatcher(secret => 'engine-secret'), secret => 'host-secret').get('/engine/secret').body).to.be('engine-secret');
    }
  }

  context 'into a host without a secret', {
    it 'leaves the mounted secret empty', {
      expect(host-session(engine-dispatcher()).get('/engine/secret').body).to.be('');
    }
  }
}
