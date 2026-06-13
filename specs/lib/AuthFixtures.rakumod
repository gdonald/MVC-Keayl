use v6.d;
use MVC::Keayl::Controller;
use MVC::Keayl::HttpAuthentication;

unit module AuthFixtures;

class BasicController is MVC::Keayl::Controller is export {
  method show {
    my $ok = self.authenticate-or-request-with-http-basic('Test', -> $user, $pass {
      secure-compare($user, 'admin') && secure-compare($pass, 'secret')
    });

    self.render(plain => 'welcome admin') if $ok;
  }
}

class BasicShortcutController is MVC::Keayl::Controller is export {
  method index { self.render(plain => 'listing') }
  method restricted { self.render(plain => 'classified') }
}
BasicShortcutController.http-basic-authenticate-with(
  name => 'admin', password => 'secret', realm => 'Test', except => <index>,
);

class TokenController is MVC::Keayl::Controller is export {
  method show {
    my $ok = self.authenticate-or-request-with-http-token('Test', -> $token, %options {
      secure-compare($token, 'good-token')
    });

    self.render(plain => 'token accepted') if $ok;
  }
}

class DigestController is MVC::Keayl::Controller is export {
  method show {
    my $ok = self.authenticate-or-request-with-http-digest('Test', -> $username {
      %( bob => 'secret' ){$username}
    });

    self.render(plain => "hello $ok") if $ok;
  }
}
