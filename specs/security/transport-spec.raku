use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Endpoint;
use MVC::Keayl::Request;
use MVC::Keayl::Response;
use MVC::Keayl::Middleware::SSL;
use MVC::Keayl::Middleware::HostAuthorization;
use MVC::Keayl::Middleware::SecureHeaders;

class StubApp does MVC::Keayl::Endpoint {
  has @.preset-headers;
  method call(MVC::Keayl::Request:D $request --> MVC::Keayl::Response:D) {
    my $response = MVC::Keayl::Response.new;
    $response.status = 200;
    $response.body('app');
    $response.add-header(.key, .value) for @!preset-headers;
    $response
  }
}

sub request(*%args) { MVC::Keayl::Request.new(|%args) }
sub https-headers(%extra = {}) { %( 'x-forwarded-proto' => 'https', |%extra ) }

describe 'MVC::Keayl::Middleware::SSL redirects', {
  it 'redirects a plain GET with 301', {
    my $ssl = MVC::Keayl::Middleware::SSL.new(app => StubApp.new);
    expect($ssl.call(request(method => 'GET', path => '/dashboard', headers => %( host => 'example.com' ))).status).to.be(301);
  }

  it 'preserves host, path, and query', {
    my $ssl = MVC::Keayl::Middleware::SSL.new(app => StubApp.new);
    expect($ssl.call(request(method => 'GET', path => '/dashboard', query-string => 'a=1', headers => %( host => 'example.com' ))).header('Location')).to.be('https://example.com/dashboard?a=1');
  }

  it 'redirects a plain POST with 307', {
    my $ssl = MVC::Keayl::Middleware::SSL.new(app => StubApp.new);
    expect($ssl.call(request(method => 'POST', path => '/x', headers => %( host => 'example.com' ))).status).to.be(307);
  }
}

describe 'MVC::Keayl::Middleware::SSL HSTS', {
  it 'reaches the app on a secure request', {
    my $ssl = MVC::Keayl::Middleware::SSL.new(app => StubApp.new);
    expect($ssl.call(request(method => 'GET', path => '/', headers => https-headers)).body).to.be('app');
  }

  it 'adds an HSTS header to a secure response', {
    my $ssl = MVC::Keayl::Middleware::SSL.new(app => StubApp.new);
    expect($ssl.call(request(method => 'GET', path => '/', headers => https-headers)).header('Strict-Transport-Security')).to.be('max-age=31536000; includeSubDomains');
  }

  it 'can disable HSTS', {
    my $ssl = MVC::Keayl::Middleware::SSL.new(app => StubApp.new, hsts => False);
    expect($ssl.call(request(method => 'GET', path => '/', headers => https-headers)).has-header('Strict-Transport-Security')).to.be-falsy;
  }
}

describe 'MVC::Keayl::Middleware::HostAuthorization', {
  it 'permits an allowed host', {
    my $guard = MVC::Keayl::Middleware::HostAuthorization.new(app => StubApp.new, allowed => ['example.com']);
    expect($guard.call(request(headers => %( host => 'example.com' ))).status).to.be(200);
  }

  it 'blocks a disallowed host', {
    my $guard = MVC::Keayl::Middleware::HostAuthorization.new(app => StubApp.new, allowed => ['example.com']);
    expect($guard.call(request(headers => %( host => 'evil.com' ))).status).to.be(403);
  }

  it 'matches subdomains with a leading-dot entry', {
    my $guard = MVC::Keayl::Middleware::HostAuthorization.new(app => StubApp.new, allowed => ['.example.com']);
    expect($guard.call(request(headers => %( host => 'api.example.com' ))).status).to.be(200);
  }

  it 'matches hosts with a regex entry', {
    my $guard = MVC::Keayl::Middleware::HostAuthorization.new(app => StubApp.new, allowed => [/example/]);
    expect($guard.call(request(headers => %( host => 'staging.example.com' ))).status).to.be(200);
  }

  it 'permits any host when the allowlist is empty', {
    my $guard = MVC::Keayl::Middleware::HostAuthorization.new(app => StubApp.new);
    expect($guard.call(request(headers => %( host => 'anything.com' ))).status).to.be(200);
  }
}

describe 'MVC::Keayl::Middleware::SecureHeaders', {
  it 'applies the default frame options', {
    my $secure = MVC::Keayl::Middleware::SecureHeaders.new(app => StubApp.new);
    expect($secure.call(request).header('X-Frame-Options')).to.be('SAMEORIGIN');
  }

  it 'applies the nosniff header', {
    my $secure = MVC::Keayl::Middleware::SecureHeaders.new(app => StubApp.new);
    expect($secure.call(request).header('X-Content-Type-Options')).to.be('nosniff');
  }

  it 'does not override an app-set header', {
    my $secure = MVC::Keayl::Middleware::SecureHeaders.new(app => StubApp.new(preset-headers => ['X-Frame-Options' => 'DENY']));
    expect($secure.call(request).header('X-Frame-Options')).to.be('DENY');
  }

  it 'adds an extra header', {
    my $secure = MVC::Keayl::Middleware::SecureHeaders.new(app => StubApp.new, also => %( 'Content-Security-Policy' => "default-src 'self'" ));
    expect($secure.call(request).header('Content-Security-Policy')).to.be("default-src 'self'");
  }

  it 'can remove a default header', {
    my $secure = MVC::Keayl::Middleware::SecureHeaders.new(app => StubApp.new, also => %( 'X-Frame-Options' => Nil ));
    expect($secure.call(request).has-header('X-Frame-Options')).to.be-falsy;
  }
}
