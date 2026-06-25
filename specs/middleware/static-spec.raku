use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Endpoint;
use MVC::Keayl::Request;
use MVC::Keayl::Response;
use MVC::Keayl::Middleware::Static;

class StaticStubApp does MVC::Keayl::Endpoint {
  method call(MVC::Keayl::Request:D $request --> MVC::Keayl::Response:D) {
    my $response = MVC::Keayl::Response.new;
    $response.status = 200;
    $response.body('app');
    $response
  }
}

sub static(*%args) {
  MVC::Keayl::Middleware::Static.new(app => StaticStubApp.new, root => 'specs/fixtures/static'.IO, |%args)
}

sub request(*%args) {
  MVC::Keayl::Request.new(method => 'GET', |%args)
}

describe 'MVC::Keayl::Middleware::Static serving files', {
  it 'serves a file with a 200', {
    expect(static().call(request(path => '/app.css')).status).to.be(200);
  }

  it 'serves the file contents as the body', {
    expect(static().call(request(path => '/app.css')).body).to.be("body \{ color: red; }\n");
  }

  it 'sets the content type from the extension', {
    expect(static().call(request(path => '/app.css')).content-type).to.be('text/css; charset=utf-8');
  }

  it 'serves a nested path', {
    expect(static().call(request(path => '/nested/deep.txt')).body).to.be("deep\n");
  }

  it 'maps a JavaScript file to a script content type', {
    expect(static().call(request(path => '/app.js')).content-type).to.be('text/javascript; charset=utf-8');
  }

  it 'maps an SVG file to an image content type', {
    expect(static().call(request(path => '/icon.svg')).content-type).to.be('image/svg+xml');
  }

  it 'serves an unknown extension as octet-stream', {
    expect(static().call(request(path => '/data.bin')).content-type).to.be('application/octet-stream');
  }
}

describe 'MVC::Keayl::Middleware::Static passing through to the app', {
  it 'passes through when the file does not exist', {
    expect(static().call(request(path => '/missing.css')).body).to.be('app');
  }

  it 'passes through a non-GET request', {
    expect(static().call(request(method => 'POST', path => '/app.css')).body).to.be('app');
  }

  it 'passes through a directory path', {
    expect(static().call(request(path => '/nested')).body).to.be('app');
  }
}

describe 'MVC::Keayl::Middleware::Static guarding the root', {
  it 'refuses to escape the root with a parent segment', {
    expect(static().call(request(path => '/../secret.txt')).body).to.be('app');
  }
}

describe 'MVC::Keayl::Middleware::Static under a url prefix', {
  it 'serves a file beneath the prefix', {
    expect(static(url-prefix => '/assets').call(request(path => '/assets/app.css')).body).to.be("body \{ color: red; }\n");
  }

  it 'passes through a path outside the prefix', {
    expect(static(url-prefix => '/assets').call(request(path => '/app.css')).body).to.be('app');
  }

  it 'does not treat a lookalike prefix as a match', {
    expect(static(url-prefix => '/assets').call(request(path => '/assetsx/app.css')).body).to.be('app');
  }
}

describe 'MVC::Keayl::Middleware::Static answering HEAD', {
  it 'answers HEAD with a 200', {
    expect(static().call(request(method => 'HEAD', path => '/app.css')).status).to.be(200);
  }

  it 'answers HEAD with no body', {
    expect(static().call(request(method => 'HEAD', path => '/app.css')).body).to.be('');
  }
}
