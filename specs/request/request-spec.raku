use BDD::Behave;
use MVC::Keayl::Request;

describe 'MVC::Keayl::Request method', {
  it 'normalizes the method to uppercase', {
    my $req = MVC::Keayl::Request.new(:method<post>);
    expect($req.method).to.be('POST');
  }
}

describe 'MVC::Keayl::Request verb predicates', {
  my %verbs =
    GET    => 'is-get',
    POST   => 'is-post',
    PUT    => 'is-put',
    PATCH  => 'is-patch',
    DELETE => 'is-delete',
    HEAD   => 'is-head';

  for %verbs.kv -> $verb, $predicate {
    it "$predicate is true for $verb", {
      my $req = MVC::Keayl::Request.new(:method($verb));
      expect($req."$predicate"()).to.be-truthy;
    }
  }

  it 'is-post is false for GET', {
    my $req = MVC::Keayl::Request.new(:method<GET>);
    expect($req.is-post).to.be-falsy;
  }
}

describe 'MVC::Keayl::Request path and query string', {
  it 'splits the path from the target', {
    my $req = MVC::Keayl::Request.new(:target('/users?q=hi'));
    expect($req.path).to.be('/users');
  }

  it 'splits the query string from the target', {
    my $req = MVC::Keayl::Request.new(:target('/users?q=hi'));
    expect($req.query-string).to.be('q=hi');
  }

  it 'has an empty query string without a question mark', {
    my $req = MVC::Keayl::Request.new(:target('/users'));
    expect($req.query-string).to.be('');
  }

  it 'honors an explicit path', {
    my $req = MVC::Keayl::Request.new(:path('/explicit'), :query-string('a=1'));
    expect($req.path).to.be('/explicit');
  }

  it 'honors an explicit query string', {
    my $req = MVC::Keayl::Request.new(:path('/explicit'), :query-string('a=1'));
    expect($req.query-string).to.be('a=1');
  }

  it 'defaults the path to /', {
    my $req = MVC::Keayl::Request.new;
    expect($req.path).to.be('/');
  }
}

describe 'MVC::Keayl::Request headers', {
  it 'looks up headers case-insensitively', {
    my $req = MVC::Keayl::Request.new(:headers({ 'Content-Type' => 'text/html' }));
    expect($req.header('content-type')).to.be('text/html');
  }

  it 'joins multi-value headers', {
    my $req = MVC::Keayl::Request.new(:headers({ Accept => <text/html application/json> }));
    expect($req.header('accept')).to.be('text/html, application/json');
  }

  it 'reports a present header regardless of case', {
    my $req = MVC::Keayl::Request.new(:headers({ Host => 'ex.com' }));
    expect($req.has-header('HOST')).to.be-truthy;
  }

  it 'reports an absent header as missing', {
    my $req = MVC::Keayl::Request.new(:headers({ Host => 'ex.com' }));
    expect($req.has-header('x-missing')).to.be-falsy;
  }
}

describe 'MVC::Keayl::Request is-xhr', {
  it 'is true for an XMLHttpRequest header', {
    my $req = MVC::Keayl::Request.new(:headers({ 'X-Requested-With' => 'XMLHttpRequest' }));
    expect($req.is-xhr).to.be-truthy;
  }

  it 'is false without the header', {
    my $req = MVC::Keayl::Request.new;
    expect($req.is-xhr).to.be-falsy;
  }
}

describe 'MVC::Keayl::Request scheme and ssl', {
  it 'defaults the scheme to http', {
    my $req = MVC::Keayl::Request.new;
    expect($req.scheme).to.be('http');
  }

  it 'is not ssl for http', {
    my $req = MVC::Keayl::Request.new;
    expect($req.is-ssl).to.be-falsy;
  }

  it 'normalizes the connection scheme to lowercase', {
    my $req = MVC::Keayl::Request.new(:scheme<HTTPS>);
    expect($req.scheme).to.be('https');
  }

  it 'is ssl for https', {
    my $req = MVC::Keayl::Request.new(:scheme<https>);
    expect($req.is-ssl).to.be-truthy;
  }

  it 'lets X-Forwarded-Proto override the connection scheme', {
    my $req = MVC::Keayl::Request.new(:scheme<http>, :headers({ 'X-Forwarded-Proto' => 'https' }));
    expect($req.scheme).to.be('https');
  }
}

describe 'MVC::Keayl::Request host and port', {
  it 'strips the port from the host', {
    my $req = MVC::Keayl::Request.new(:headers({ Host => 'example.com:3000' }));
    expect($req.host).to.be('example.com');
  }

  it 'reads the port from the Host header', {
    my $req = MVC::Keayl::Request.new(:headers({ Host => 'example.com:3000' }));
    expect($req.port).to.be(3000);
  }

  it 'defaults the port to 80 for http', {
    my $req = MVC::Keayl::Request.new(:headers({ Host => 'example.com' }));
    expect($req.port).to.be(80);
  }

  it 'defaults the port to 443 for https', {
    my $req = MVC::Keayl::Request.new(:scheme<https>, :headers({ Host => 'example.com' }));
    expect($req.port).to.be(443);
  }

  it 'uses X-Forwarded-Port when the Host header has no port', {
    my $req = MVC::Keayl::Request.new(:headers({ Host => 'example.com', 'X-Forwarded-Port' => '8443' }));
    expect($req.port).to.be(8443);
  }

  it 'prefers X-Forwarded-Host over Host', {
    my $req = MVC::Keayl::Request.new(:headers({ Host => 'origin.com', 'X-Forwarded-Host' => 'proxy.com' }));
    expect($req.host).to.be('proxy.com');
  }

  it 'has an undefined host without a Host header', {
    my $req = MVC::Keayl::Request.new;
    expect($req.host.defined).to.be-falsy;
  }
}

describe 'MVC::Keayl::Request remote-ip', {
  it 'falls back to the connection address', {
    my $req = MVC::Keayl::Request.new(:remote-address('10.0.0.1'));
    expect($req.remote-ip).to.be('10.0.0.1');
  }

  it 'prefers the first X-Forwarded-For entry', {
    my $req = MVC::Keayl::Request.new(
      :remote-address('10.0.0.1'),
      :headers({ 'X-Forwarded-For' => '203.0.113.5, 10.0.0.1' }),
    );
    expect($req.remote-ip).to.be('203.0.113.5');
  }
}

describe 'MVC::Keayl::Request query params', {
  it 'parses a key into the hash', {
    my $req = MVC::Keayl::Request.new(:query-string('a=1&b=two'));
    expect($req.query-params<a>).to.be('1');
  }

  it 'parses a second key into the hash', {
    my $req = MVC::Keayl::Request.new(:query-string('a=1&b=two'));
    expect($req.query-params<b>).to.be('two');
  }

  it 'percent- and plus-decodes values', {
    my $req = MVC::Keayl::Request.new(:query-string('q=a%20b+c'));
    expect($req.query-params<q>).to.be('a b c');
  }

  it 'collects repeated keys into an ordered array', {
    my $req = MVC::Keayl::Request.new(:query-string('t=1&t=2&t=3'));
    expect($req.query-params<t>.join(',')).to.be('1,2,3');
  }

  it 'is empty without a query string', {
    my $req = MVC::Keayl::Request.new;
    expect($req.query-params.elems).to.be(0);
  }
}

describe 'MVC::Keayl::Request body', {
  it 'returns a string body as-is', {
    my $req = MVC::Keayl::Request.new(:body('plain'));
    expect($req.body).to.be('plain');
  }

  it 'decodes a Blob body as utf-8', {
    my $req = MVC::Keayl::Request.new(:body('héllo'.encode('utf-8')));
    expect($req.body).to.be('héllo');
  }

  it 'reads a missing body as the empty string', {
    my $req = MVC::Keayl::Request.new;
    expect($req.body).to.be('');
  }

  it 'returns the raw body bytes undecoded from body-blob', {
    my $bytes = Buf.new(0xFF, 0xD8, 0xFF, 0x00, 0x89, 0x50);
    my $req   = MVC::Keayl::Request.new(:body($bytes));
    expect($req.body-blob.list).to.eq($bytes.list);
  }

  it 'encodes a string body as utf-8 bytes from body-blob', {
    my $req = MVC::Keayl::Request.new(:body('héllo'));
    expect($req.body-blob.list).to.eq('héllo'.encode('utf-8').list);
  }

  it 'returns an empty buffer from body-blob for a missing body', {
    my $req = MVC::Keayl::Request.new;
    expect($req.body-blob.elems).to.eq(0);
  }

  it 'invokes a callable source from body-blob', {
    my $req = MVC::Keayl::Request.new(:body(-> { 'lazy' }));
    expect($req.body-blob.decode('utf-8')).to.eq('lazy');
  }
}

describe 'MVC::Keayl::Request rebase', {
  # Mounting a sub-application rebases the request. A binary multipart upload
  # must pass through as raw bytes, never UTF-8-decoded (which corrupts it and
  # can crash the VM before the body is parsed).
  it 'preserves the raw body bytes across a rebase', {
    my $bytes   = Buf.new(0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10);
    my $req     = MVC::Keayl::Request.new(:method<POST>, :target('/admin/imgs'), :body($bytes));
    my $rebased = $req.rebase('/imgs');

    aggregate-failures {
      expect($rebased.path).to.eq('/imgs');
      expect($rebased.body-blob.list).to.eq($bytes.list);
    }
  }
}

describe 'MVC::Keayl::Request lazy body', {
  it 'does not read the source until the body is accessed', {
    my $calls = 0;
    MVC::Keayl::Request.new(:body(-> { $calls++; 'lazy' }));
    expect($calls).to.be(0);
  }

  it 'returns the body on first access', {
    my $req = MVC::Keayl::Request.new(:body(-> { 'lazy' }));
    expect($req.body).to.be('lazy');
  }

  it 'reads the source exactly once across repeated access', {
    my $calls = 0;
    my $req = MVC::Keayl::Request.new(:body(-> { $calls++; 'lazy' }));

    $req.body;
    $req.body;

    expect($calls).to.be(1);
  }
}

describe 'MVC::Keayl::Request variant', {
  it 'is undefined by default', {
    expect(MVC::Keayl::Request.new.variant.defined).to.be-falsy;
  }

  it 'returns a variant set explicitly', {
    expect(MVC::Keayl::Request.new.set-variant('phone').variant).to.be('phone');
  }

  it 'detects a phone from a mobile user agent', {
    expect(MVC::Keayl::Request.new(:headers({ 'User-Agent' => 'iPhone Mobile Safari' })).detect-variant).to.be('phone');
  }

  it 'detects a tablet from an iPad user agent', {
    expect(MVC::Keayl::Request.new(:headers({ 'User-Agent' => 'iPad Safari' })).detect-variant).to.be('tablet');
  }

  it 'detects no variant for a desktop user agent', {
    expect(MVC::Keayl::Request.new(:headers({ 'User-Agent' => 'Mozilla Macintosh' })).detect-variant.defined).to.be-falsy;
  }
}
