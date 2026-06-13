use lib 'specs/lib';
use BDD::Behave;
use MIME::Base64;
use MVC::Keayl::HttpAuthentication;

describe 'MVC::Keayl::HttpAuthentication secure-compare', {
  it 'is true for equal strings', {
    expect(secure-compare('abc123', 'abc123')).to.be-truthy;
  }

  it 'is false for different strings of equal length', {
    expect(secure-compare('abc123', 'abc124')).to.be-falsy;
  }

  it 'is false for different lengths', {
    expect(secure-compare('abc', 'abcd')).to.be-falsy;
  }
}

describe 'MVC::Keayl::HttpAuthentication basic credentials', {
  it 'encodes basic credentials', {
    expect(encode-basic-credentials('aladdin', 'opensesame')).to.be('Basic YWxhZGRpbjpvcGVuc2VzYW1l');
  }

  it 'decodes basic credentials', {
    expect(decode-basic-credentials('Basic YWxhZGRpbjpvcGVuc2VzYW1l')).to.be(('aladdin', 'opensesame'));
  }

  it 'keeps a colon in the password', {
    expect(decode-basic-credentials('Basic ' ~ MIME::Base64.encode-str('user:pa:ss'))).to.be(('user', 'pa:ss'));
  }

  it 'decodes nothing without a header', {
    expect(decode-basic-credentials(Str)).to.be(());
  }

  it 'ignores a non-basic header', {
    expect(decode-basic-credentials('Bearer abc')).to.be(());
  }
}

describe 'MVC::Keayl::HttpAuthentication token credentials', {
  it 'parses a quoted token', {
    expect(token-and-options('Token token="abc123"')).to.be(('abc123', {}));
  }

  it 'parses a bare token', {
    expect(token-and-options('Token abc123')).to.be(('abc123', {}));
  }

  it 'parses a bearer token', {
    expect(token-and-options('Bearer xyz.789')).to.be(('xyz.789', {}));
  }

  context 'with additional options', {
    let(:parsed, { my ($token, %options) = token-and-options('Token token="abc", nonce="42"'); %( :$token, :%options ) });

    it 'extracts the token', {
      expect(parsed<token>).to.be('abc');
    }

    it 'extracts the additional options', {
      expect(parsed<options><nonce>).to.be('42');
    }
  }

  it 'parses nothing without a header', {
    expect(token-and-options(Str)).to.be((Str, {}));
  }
}

describe 'MVC::Keayl::HttpAuthentication digest', {
  let(:params, { parse-digest-header('Digest username="bob", realm="App", uri="/", response="deadbeef", qop=auth, nc=00000001') });

  it 'parses a quoted digest field', {
    expect(params<username>).to.be('bob');
  }

  it 'parses an unquoted digest field', {
    expect(params<qop>).to.be('auth');
  }

  it 'parses the nonce count', {
    expect(params<nc>).to.be('00000001');
  }

  it 'validates a fresh nonce', {
    expect(validate-digest-nonce('secret', digest-nonce('secret', 1_000_000), 10_000_000_000)).to.be-truthy;
  }

  it 'rejects a nonce signed with another secret', {
    expect(validate-digest-nonce('other-secret', digest-nonce('secret', 1_000_000), 10_000_000_000)).to.be-falsy;
  }

  it 'rejects an expired nonce', {
    expect(validate-digest-nonce('secret', digest-nonce('secret', 1_000_000), 60)).to.be-falsy;
  }

  it 'rejects a malformed nonce', {
    expect(validate-digest-nonce('secret', 'tampered')).to.be-falsy;
  }

  it 'computes a 32-character digest response', {
    my %digest =
      username => 'bob', realm => 'App', uri => '/secret',
      nonce => 'abc', nc => '00000001', cnonce => 'xyz', qop => 'auth';

    expect(expected-digest-response(%digest, 'GET', 'App', 'bob', 'secret').chars).to.be(32);
  }
}
