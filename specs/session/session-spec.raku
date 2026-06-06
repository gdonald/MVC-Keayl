use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Session;
use MVC::Keayl::Cookies;
use MVC::Keayl::Controller;
use MVC::Keayl::Request;

describe 'MVC::Keayl::Session indifferent access', {
  it 'reads a value back with an equivalent key', {
    my $session = MVC::Keayl::Session.new;
    $session<user-id> = 7;
    expect($session{'user-id'}).to.be(7);
  }

  it 'coerces keys to strings', {
    my $session = MVC::Keayl::Session.new;
    $session{42} = 'x';
    expect($session<42>).to.be('x');
  }
}

describe 'MVC::Keayl::Session dirty tracking', {
  it 'is not dirty when fresh', {
    expect(MVC::Keayl::Session.new.dirty).to.be-falsy;
  }

  it 'becomes dirty when written', {
    my $session = MVC::Keayl::Session.new;
    $session<a> = 1;
    expect($session.dirty).to.be-truthy;
  }
}

describe 'MVC::Keayl::Session::CookieStore', {
  it 'round-trips a session through a signed cookie', {
    my $store   = MVC::Keayl::Session::CookieStore.new;
    my $cookies = MVC::Keayl::Cookies.new(secret => 'k');
    my $session = MVC::Keayl::Session.new(data => $store.load($cookies));

    $session<user-id> = 99;
    $store.commit($cookies, $session);

    my $next = MVC::Keayl::Cookies.parse($cookies.set-cookie-headers[0], secret => 'k');
    expect(MVC::Keayl::Session.new(data => $store.load($next))<user-id>).to.be(99);
  }

  it 'writes no cookie for an untouched session', {
    my $store   = MVC::Keayl::Session::CookieStore.new;
    my $cookies = MVC::Keayl::Cookies.new(secret => 'k');
    $store.commit($cookies, MVC::Keayl::Session.new);
    expect($cookies.set-cookie-headers.elems).to.be(0);
  }

  it 'deletes the cookie when reset to empty', {
    my $store   = MVC::Keayl::Session::CookieStore.new;
    my $cookies = MVC::Keayl::Cookies.new(secret => 'k');
    my $session = MVC::Keayl::Session.new(data => %( a => 1 ));
    $session.reset;
    $store.commit($cookies, $session);
    expect($cookies.set-cookie-headers[0].contains('Max-Age=0')).to.be-truthy;
  }

  it 'keeps an encrypted session confidential', {
    my $store   = MVC::Keayl::Session::CookieStore.new(serializer => 'encrypted');
    my $cookies = MVC::Keayl::Cookies.new(secret => 'k');
    my $session = MVC::Keayl::Session.new;
    $session<token> = 'super-secret';
    $store.commit($cookies, $session);
    expect($cookies.set-cookie-headers[0].contains('super-secret')).to.be-falsy;
  }
}

describe 'MVC::Keayl::Session::ServerSideStore', {
  it 'writes the data to a pluggable backend', {
    my $backend = MVC::Keayl::Session::MemoryBackend.new;
    my $store   = MVC::Keayl::Session::ServerSideStore.new(:$backend);
    my $cookies = MVC::Keayl::Cookies.new(secret => 'k');

    my $session = MVC::Keayl::Session.new(data => $store.load($cookies));
    $session<role> = 'admin';
    $store.commit($cookies, $session);

    expect($backend.sessions.values.elems).to.be(1);
  }

  it 'keeps the data out of the cookie', {
    my $backend = MVC::Keayl::Session::MemoryBackend.new;
    my $store   = MVC::Keayl::Session::ServerSideStore.new(:$backend);
    my $cookies = MVC::Keayl::Cookies.new(secret => 'k');

    my $session = MVC::Keayl::Session.new(data => $store.load($cookies));
    $session<role> = 'admin';
    $store.commit($cookies, $session);

    expect($cookies.set-cookie-headers[0].contains('admin')).to.be-falsy;
  }

  it 'reloads a session by its id', {
    my $backend = MVC::Keayl::Session::MemoryBackend.new;
    my $store   = MVC::Keayl::Session::ServerSideStore.new(:$backend);
    my $cookies = MVC::Keayl::Cookies.new(secret => 'k');

    my $session = MVC::Keayl::Session.new(data => $store.load($cookies));
    $session<role> = 'admin';
    $store.commit($cookies, $session);

    my $next = MVC::Keayl::Cookies.parse($cookies.set-cookie-headers[0], secret => 'k');
    expect($store.load($next)<role>).to.be('admin');
  }
}

describe 'MVC::Keayl::Controller sessions', {
  it 'persists the session as a cookie', {
    my class LoginController is MVC::Keayl::Controller {
      method create {
        self.session<user-id> = 7;
        self.render(:plain('in'));
      }
    }

    my $response = LoginController.new.dispatch('create');
    expect($response.header('Set-Cookie').contains('_session=')).to.be-truthy;
  }

  it 'clears the session cookie on reset-session', {
    my class ResetController is MVC::Keayl::Controller {
      method logout {
        self.session<user-id> = 7;
        self.reset-session;
        self.render(:plain('out'));
      }
    }

    my $response = ResetController.new.dispatch('logout');
    expect($response.header('Set-Cookie').contains('Max-Age=0')).to.be-truthy;
  }
}
