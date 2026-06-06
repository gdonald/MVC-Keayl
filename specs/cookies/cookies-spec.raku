use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Cookies;
use MVC::Keayl::Controller;
use MVC::Keayl::Request;

sub value-of($header) { $header.split('=', 2)[1] }

describe 'MVC::Keayl::Cookies reading', {
  it 'reads an incoming cookie by name', {
    expect(MVC::Keayl::Cookies.parse('session=abc; theme=dark')<theme>).to.be('dark');
  }

  it 'reads a missing cookie as undefined', {
    expect(MVC::Keayl::Cookies.parse('a=1')<missing>.defined).to.be-falsy;
  }

  it 'url-decodes an incoming value', {
    expect(MVC::Keayl::Cookies.parse('greeting=hello%20world')<greeting>).to.be('hello world');
  }
}

describe 'MVC::Keayl::Cookies writing', {
  it 'reads a written cookie back within the request', {
    my $cookies = MVC::Keayl::Cookies.new;
    $cookies<theme> = 'dark';
    expect($cookies<theme>).to.be('dark');
  }

  it 'produces a Set-Cookie header for a written cookie', {
    my $cookies = MVC::Keayl::Cookies.new;
    $cookies<theme> = 'dark';
    expect($cookies.set-cookie-headers).to.be(('theme=dark',));
  }

  it 'url-encodes a written value', {
    my $cookies = MVC::Keayl::Cookies.new;
    $cookies.set('q', 'a b&c');
    expect($cookies.set-cookie-headers[0]).to.be('q=a%20b%26c');
  }
}

describe 'MVC::Keayl::Cookies attributes', {
  it 'emits cookie attributes in the Set-Cookie header', {
    my $cookies = MVC::Keayl::Cookies.new;
    $cookies.set('session', 'abc', path => '/', http-only => True, same-site => 'Lax', secure => True);
    expect($cookies.set-cookie-headers[0]).to.be('session=abc; Path=/; SameSite=Lax; Secure; HttpOnly');
  }

  it 'emits a max-age attribute', {
    my $cookies = MVC::Keayl::Cookies.new;
    $cookies.set('n', 'v', max-age => 3600);
    expect($cookies.set-cookie-headers[0].contains('Max-Age=3600')).to.be-truthy;
  }

  it 'formats an expires DateTime as an HTTP date', {
    my $cookies = MVC::Keayl::Cookies.new;
    $cookies.set('n', 'v', expires => DateTime.new(:2021year, :6month, :9day, :10hour, :18minute, :14second));
    expect($cookies.set-cookie-headers[0].contains('Expires=Wed, 09 Jun 2021 10:18:14 GMT')).to.be-truthy;
  }

  it 'sets value and options from an assigned hash', {
    my $cookies = MVC::Keayl::Cookies.new;
    $cookies<session> = { value => 'abc', path => '/admin' };
    expect($cookies.set-cookie-headers[0]).to.be('session=abc; Path=/admin');
  }

  it 'emits an expiry when deleting a cookie', {
    my $cookies = MVC::Keayl::Cookies.parse('theme=dark');
    $cookies.delete('theme');
    expect($cookies.set-cookie-headers[0].contains('Max-Age=0')).to.be-truthy;
  }
}

describe 'MVC::Keayl::Cookies signed', {
  it 'round-trips a signed value', {
    my $cookies = MVC::Keayl::Cookies.new(secret => 's3cret');
    $cookies.signed.set('user-id', '42');
    my $value = value-of($cookies.set-cookie-headers[0]);

    my $back = MVC::Keayl::Cookies.new(incoming => %( 'user-id' => $value ), secret => 's3cret');
    expect($back.signed<user-id>).to.be('42');
  }

  it 'rejects a tampered signed cookie', {
    my $cookies = MVC::Keayl::Cookies.new(secret => 's3cret');
    $cookies.signed.set('user-id', '42');
    my $value = value-of($cookies.set-cookie-headers[0]);

    my $tampered = MVC::Keayl::Cookies.new(incoming => %( 'user-id' => 'X' ~ $value ), secret => 's3cret');
    expect($tampered.signed<user-id>.defined).to.be-falsy;
  }

  it 'rejects a signed cookie under a different secret', {
    my $cookies = MVC::Keayl::Cookies.new(secret => 's3cret');
    $cookies.signed.set('user-id', '42');
    my $value = value-of($cookies.set-cookie-headers[0]);

    my $wrong = MVC::Keayl::Cookies.new(incoming => %( 'user-id' => $value ), secret => 'different');
    expect($wrong.signed<user-id>.defined).to.be-falsy;
  }
}

describe 'MVC::Keayl::Cookies encrypted', {
  it 'does not expose the plaintext', {
    my $cookies = MVC::Keayl::Cookies.new(secret => 's3cret');
    $cookies.encrypted.set('card', '4111-1111');
    expect($cookies.set-cookie-headers[0].contains('4111')).to.be-falsy;
  }

  it 'round-trips an encrypted value', {
    my $cookies = MVC::Keayl::Cookies.new(secret => 's3cret');
    $cookies.encrypted.set('card', '4111-1111');
    my $value = value-of($cookies.set-cookie-headers[0]);

    my $back = MVC::Keayl::Cookies.new(incoming => %( card => $value ), secret => 's3cret');
    expect($back.encrypted<card>).to.be('4111-1111');
  }

  it 'does not decrypt under a different secret', {
    my $cookies = MVC::Keayl::Cookies.new(secret => 's3cret');
    $cookies.encrypted.set('card', 'secret-data');
    my $value = value-of($cookies.set-cookie-headers[0]);

    my $wrong = MVC::Keayl::Cookies.new(incoming => %( card => $value ), secret => 'different');
    expect($wrong.encrypted<card>.defined).to.be-falsy;
  }
}

describe 'MVC::Keayl::Controller cookies', {
  it 'flushes its cookies to the response', {
    my class CookieController is MVC::Keayl::Controller {
      method show {
        self.cookies<seen> = 'yes';
        self.render(:plain('ok'));
      }
    }

    my $request  = MVC::Keayl::Request.new(headers => %( cookie => 'theme=dark' ));
    my $response = CookieController.new(:$request).dispatch('show');

    expect($response.header('Set-Cookie')).to.be('seen=yes');
  }

  it 'reads incoming request cookies', {
    my class ReadCookieController is MVC::Keayl::Controller {
      method show {
        self.render(:plain(self.cookies<theme> // 'none'));
      }
    }

    my $request  = MVC::Keayl::Request.new(headers => %( cookie => 'theme=dark' ));
    my $response = ReadCookieController.new(:$request).dispatch('show');

    expect($response.body).to.be('dark');
  }
}
