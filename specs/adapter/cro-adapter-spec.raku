use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Adapter::Cro;
use Cro::HTTP::Request;
use Cro::HTTP::Response;
use Cro::HTTP::Client;
use ServerFixtures;

sub cro-adapter {
  MVC::Keayl::Adapter::Cro.new(:app(EchoEndpoint.new), :port(0))
}

sub cro-request(Str $method, Str $target, *@headers) {
  my $request = Cro::HTTP::Request.new(:$method, :$target);
  $request.append-header(.key, .value) for @headers;
  $request
}

describe 'MVC::Keayl::Adapter::Cro build-request', {
  context 'a GET with a query string', {
    let(:request, { cro-adapter.build-request(cro-request('GET', '/p?a=b'), Blob.new) });

    it 'translates the method', {
      expect(request.method).to.be('GET');
    }

    it 'translates the target path', {
      expect(request.path).to.be('/p');
    }

    it 'translates the query string', {
      expect(request.query-string).to.be('a=b');
    }
  }

  it 'translates headers', {
    expect(cro-adapter.build-request(cro-request('GET', '/', 'Host' => 'h.com'), Blob.new).header('host')).to.be('h.com');
  }

  it 'decodes the body blob into the request', {
    expect(cro-adapter.build-request(cro-request('POST', '/'), 'body-bytes'.encode('utf-8')).body).to.be('body-bytes');
  }
}

describe 'MVC::Keayl::Adapter::Cro fill-response', {
  context 'a POST response with a body', {
    let(:filled, {
        my $cro-req = cro-request('POST', '/echo');
        my $cro-res = Cro::HTTP::Response.new(:request($cro-req));
        cro-adapter.fill-response($cro-req, 'hi'.encode('utf-8'), $cro-res);
        $cro-res
    });

    it 'copies the status onto the Cro response', {
      expect(filled.status).to.be(200);
    }

    it 'copies headers onto the Cro response', {
      expect(filled.header('X-Method')).to.be('POST');
    }

    it 'copies the body onto the Cro response', {
      expect((await filled.body-blob).decode('utf-8')).to.be('hi');
    }
  }

  context 'an empty-body response', {
    let(:filled, {
        my $cro-req = cro-request('GET', '/');
        my $cro-res = Cro::HTTP::Response.new(:request($cro-req));
        cro-adapter.fill-response($cro-req, Blob.new, $cro-res);
        $cro-res
    });

    it 'leaves Content-Length to Cro', {
      expect(filled.header('Content-Length').defined).to.be-falsy;
    }
  }
}

describe 'MVC::Keayl::Adapter::Cro served over a socket', {
  it 'serves a request end to end', {
    my $port    = free-port();
    my $adapter = MVC::Keayl::Adapter::Cro.new(:app(EchoEndpoint.new), :host('127.0.0.1'), :$port);

    $adapter.start;
    my $response = await Cro::HTTP::Client.post("http://127.0.0.1:{$port}/echo?x=9", body => 'payload'.encode('utf-8'));
    my $body = await $response.body-text;
    $adapter.stop;

    aggregate-failures {
      expect($response.status).to.be(200);
      expect($response.header('X-Method')).to.be('POST');
      expect($response.header('X-Path')).to.be('/echo');
      expect($response.header('X-Remote-IP')).to.be('127.0.0.1');
      expect($body).to.be('payload');
    }
  }
}
