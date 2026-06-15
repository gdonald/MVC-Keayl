use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Controller;
use MVC::Keayl::Parameters;
use MVC::Keayl::Cache;

my $clock-time = 0;
my $rate-store = MVC::Keayl::Cache::MemoryStore.new(clock => sub { $clock-time });

class ThrottledController is MVC::Keayl::Controller {
  method show { self.render(plain => 'ok') }
}
ThrottledController.rate-limit(to => 2, within => 60, store => $rate-store, by => -> $controller { 'fixed' });

class ByUserController is MVC::Keayl::Controller {
  method show { self.render(plain => 'ok') }
}
ByUserController.rate-limit(to => 1, within => 60, store => $rate-store, by => -> $controller { $controller.params<user> });

class CustomHandlerController is MVC::Keayl::Controller {
  method show     { self.render(plain => 'ok') }
  method over-limit { self.render(plain => 'slow down', status => 503) }
}
CustomHandlerController.rate-limit(to => 1, within => 60, store => $rate-store, with => -> $controller { $controller.over-limit });

sub throttled {
  ThrottledController.new.dispatch('show')
}

sub by-user(Str $user) {
  ByUserController.new(params => MVC::Keayl::Parameters.new({ user => $user })).dispatch('show')
}

describe 'MVC::Keayl::Controller rate-limit', {
  before-each({ $clock-time = 0; $rate-store.clear });

  it 'allows requests up to the limit', {
    throttled;
    expect(throttled.status).to.be(200);
  }

  it 'blocks a request past the limit with 429', {
    throttled; throttled;
    expect(throttled.status).to.be(429);
  }

  it 'sets a Retry-After header on a blocked request', {
    throttled; throttled;
    expect(throttled.header('Retry-After')).to.be('60');
  }

  it 'allows requests again after the window passes', {
    throttled; throttled; throttled;
    $clock-time = 61;
    expect(throttled.status).to.be(200);
  }
}

describe 'MVC::Keayl::Controller rate-limit discriminator', {
  before-each({ $clock-time = 0; $rate-store.clear });

  it 'tracks each discriminator separately', {
    by-user('alice');
    expect(by-user('bob').status).to.be(200);
  }

  it 'blocks the same discriminator past its limit', {
    by-user('alice');
    expect(by-user('alice').status).to.be(429);
  }
}

describe 'MVC::Keayl::Controller rate-limit handler', {
  before-each({ $clock-time = 0; $rate-store.clear });

  it 'invokes a custom over-limit handler', {
    CustomHandlerController.new.dispatch('show');
    expect(CustomHandlerController.new.dispatch('show').status).to.be(503);
  }

  it 'runs the custom handler body', {
    CustomHandlerController.new.dispatch('show');
    expect(CustomHandlerController.new.dispatch('show').body).to.be('slow down');
  }
}
