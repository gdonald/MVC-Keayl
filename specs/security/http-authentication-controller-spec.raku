use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Request;
use MVC::Keayl::HttpAuthentication;
use AuthFixtures;

sub dispatch($class, Str:D $action, :$authorization, :$secret = 'test-secret') {
  my %headers = $authorization.defined ?? (Authorization => $authorization) !! ();
  $class.new(request => MVC::Keayl::Request.new(:%headers), :$secret).dispatch($action);
}

sub digest-header(%overrides, :$secret = 'test-secret', :$realm = 'Test', :$username = 'bob', :$password = 'secret') {
  my %params =
    username => $username, realm => $realm, uri => '/', qop => 'auth',
    nc => '00000001', cnonce => 'clientnonce',
    nonce => digest-nonce($secret, time),
    |%overrides;

  %params<response> //= expected-digest-response(%params, 'GET', $realm, $username, $password);

  ('Digest ' ~ <username realm uri qop nc cnonce nonce response>.map({ qq{$_="%params{$_}"} }).join(', '))
}

describe 'MVC::Keayl::Controller basic authentication', {
  it 'admits valid credentials', {
    expect(dispatch(BasicController, 'show', authorization => encode-basic-credentials('admin', 'secret')).body).to.be('welcome admin');
  }

  it 'rejects bad credentials with 401', {
    expect(dispatch(BasicController, 'show', authorization => encode-basic-credentials('admin', 'wrong')).status).to.be(401);
  }

  it 'issues a challenge for bad credentials', {
    expect(dispatch(BasicController, 'show', authorization => encode-basic-credentials('admin', 'wrong')).header('WWW-Authenticate')).to.be('Basic realm="Test"');
  }

  it 'challenges a missing header', {
    expect(dispatch(BasicController, 'show').status).to.be(401);
  }
}

describe 'MVC::Keayl::Controller basic authentication shortcut', {
  it 'skips excepted actions', {
    expect(dispatch(BasicShortcutController, 'index').body).to.be('listing');
  }

  it 'admits valid credentials', {
    expect(dispatch(BasicShortcutController, 'restricted', authorization => encode-basic-credentials('admin', 'secret')).body).to.be('classified');
  }

  it 'challenges bad credentials', {
    expect(dispatch(BasicShortcutController, 'restricted', authorization => encode-basic-credentials('admin', 'nope')).status).to.be(401);
  }
}

describe 'MVC::Keayl::Controller token authentication', {
  it 'admits a valid token', {
    expect(dispatch(TokenController, 'show', authorization => 'Token token="good-token"').body).to.be('token accepted');
  }

  it 'rejects a bad token', {
    expect(dispatch(TokenController, 'show', authorization => 'Bearer bad-token').status).to.be(401);
  }

  it 'issues a challenge', {
    expect(dispatch(TokenController, 'show', authorization => 'Bearer bad-token').header('WWW-Authenticate')).to.be('Token realm="Test"');
  }
}

describe 'MVC::Keayl::Controller digest authentication', {
  it 'admits a valid response', {
    expect(dispatch(DigestController, 'show', authorization => digest-header({})).body).to.be('hello bob');
  }

  it 'rejects a wrong response', {
    expect(dispatch(DigestController, 'show', authorization => digest-header({ response => 'deadbeef' })).status).to.be(401);
  }

  it 'rejects an invalid nonce', {
    expect(dispatch(DigestController, 'show', authorization => digest-header({ nonce => 'tampered' })).status).to.be(401);
  }

  it 'issues a digest challenge', {
    expect(dispatch(DigestController, 'show').header('WWW-Authenticate').starts-with('Digest realm="Test"')).to.be-truthy;
  }
}
