use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Secrets;

describe 'MVC::Keayl::Secrets resolution', {
  it 'reads the secret key base from the environment', {
    expect(MVC::Keayl::Secrets.resolve(%( KEAYL_SECRET_KEY_BASE => 'from-env' )).secret-key-base).to.be('from-env');
  }

  it 'reads a fallback environment variable', {
    expect(MVC::Keayl::Secrets.resolve(%( SECRET_KEY_BASE => 'fallback' )).secret-key-base).to.be('fallback');
  }

  it 'prefers an explicit config value', {
    expect(MVC::Keayl::Secrets.resolve(%(), config => 'from-config').secret-key-base).to.be('from-config');
  }

  it 'dies when no secret is configured', {
    expect({ MVC::Keayl::Secrets.resolve(%()) }).to.throw;
  }
}

describe 'MVC::Keayl::Secrets derivation', {
  it 'derives 32 bytes of hex by default', {
    expect(MVC::Keayl::Secrets.new(secret-key-base => 'base').derive-key('salt').chars).to.be(64);
  }

  it 'is deterministic for the same salt', {
    my $secrets = MVC::Keayl::Secrets.new(secret-key-base => 'base');
    expect($secrets.derive-key('salt')).to.be($secrets.derive-key('salt'));
  }

  it 'derives different keys for different salts', {
    my $secrets = MVC::Keayl::Secrets.new(secret-key-base => 'base');
    expect($secrets.derive-key('a') eq $secrets.derive-key('b')).to.be-falsy;
  }

  it 'derives different keys for different bases', {
    my $a = MVC::Keayl::Secrets.new(secret-key-base => 'one');
    my $b = MVC::Keayl::Secrets.new(secret-key-base => 'two');
    expect($a.derive-key('salt') eq $b.derive-key('salt')).to.be-falsy;
  }

  it 'honours a configurable length', {
    expect(MVC::Keayl::Secrets.new(secret-key-base => 'base').derive-key('salt', length => 16).chars).to.be(32);
  }

  it 'derives distinct signing and encryption keys', {
    my $secrets = MVC::Keayl::Secrets.new(secret-key-base => 'base');
    expect($secrets.signing-key eq $secrets.encryption-key).to.be-falsy;
  }
}
