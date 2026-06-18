use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Credentials;
use MVC::Keayl::CLI;
use CLIFixtures;

sub write-credentials(IO() $root, Str $master-key, %data, Str :$path = 'config/credentials.yml.enc') {
  my $writer = MVC::Keayl::Credentials.new(:$master-key, path => $root.add($path));
  $writer.write(%data);
  $writer
}

describe 'content encryption', {
  let(:master-key, { generate-master-key });
  let(:encrypted, { encrypt-content("secret-key-base: abc123\n", master-key()) });

  it 'encrypts the content at rest', {
    expect(encrypted() ne "secret-key-base: abc123\n").to.be-truthy;
  }

  it 'recovers the content with the master key', {
    expect(decrypt-content(encrypted(), master-key())).to.be("secret-key-base: abc123\n");
  }

  it 'does not decrypt with a wrong master key', {
    expect(decrypt-content(encrypted(), generate-master-key()).defined).to.be-falsy;
  }
}

describe 'master key generation', {
  it 'produces 32 hex characters', {
    expect(so generate-master-key() ~~ /^ <[0..9a..f]> ** 32 $/).to.be-truthy;
  }

  it 'produces a unique key each time', {
    expect(generate-master-key() ne generate-master-key()).to.be-truthy;
  }
}

describe 'the vault', {
  it 'reads a top-level credential', {
    my $root = temp-dir('spec-creds-top');
    my $key  = generate-master-key();
    $root.add('config').mkdir;
    $root.add('config/master.key').spurt($key);
    write-credentials($root, $key, %( secret-key-base => 'topsecret' ));

    expect(MVC::Keayl::Credentials.resolve(:$root)<secret-key-base>).to.be('topsecret');
  }

  it 'reads a nested credential', {
    my $root = temp-dir('spec-creds-nested');
    my $key  = generate-master-key();
    $root.add('config').mkdir;
    $root.add('config/master.key').spurt($key);
    write-credentials($root, $key, %( aws => %( access-key-id => 'AKIA' ) ));

    expect(MVC::Keayl::Credentials.resolve(:$root).read('aws', 'access-key-id')).to.be('AKIA');
  }

  it 'reads the master key from the environment', {
    my $root = temp-dir('spec-creds-env');
    my $key  = generate-master-key();
    write-credentials($root, $key, %( api-token => 'xyz' ));

    expect(MVC::Keayl::Credentials.resolve(:$root, env-vars => %( KEAYL_MASTER_KEY => $key ))<api-token>).to.be('xyz');
  }

  it 'raises without a master key', {
    my $root = temp-dir('spec-creds-nokey');
    expect({ MVC::Keayl::Credentials.resolve(:$root, env-vars => %()) }).to.throw;
  }

  it 'decrypts a per-environment file with its own key', {
    my $root = temp-dir('spec-creds-env-file');
    my $key  = generate-master-key();
    $root.add('config/credentials').mkdir;
    $root.add('config/credentials/production.key').spurt($key);
    write-credentials($root, $key, %( host => 'prod.example.com' ), path => 'config/credentials/production.yml.enc');

    expect(MVC::Keayl::Credentials.resolve(:$root, env => 'production')<host>).to.be('prod.example.com');
  }
}

describe 'credentials-edit', {
  it 're-encrypts the edited content', {
    my $root = temp-dir('spec-edit');
    my $key  = generate-master-key();
    $root.add('config').mkdir;
    $root.add('config/master.key').spurt($key);
    write-credentials($root, $key, %( secret-key-base => 'original' ));

    credentials-edit(:$root, edit => -> $current { "secret-key-base: edited\n" }, out => StringSink.new);

    expect(MVC::Keayl::Credentials.resolve(:$root)<secret-key-base>).to.be('edited');
  }

  it 'decrypts the current content for editing', {
    my $root = temp-dir('spec-edit-current');
    my $key  = generate-master-key();
    $root.add('config').mkdir;
    $root.add('config/master.key').spurt($key);
    write-credentials($root, $key, %( secret-key-base => 'original' ));

    my $captured;
    credentials-edit(:$root, edit => -> $current { $captured = $current; $current }, out => StringSink.new);

    expect($captured.contains('original')).to.be-truthy;
  }

  it 'fails without a master key', {
    my $root = temp-dir('spec-edit-nokey');
    expect(credentials-edit(:$root, env-vars => %(), edit => -> $current { $current }, err => StringSink.new)).to.be(1);
  }
}

describe 'a new application', {
  let(:root, { temp-dir('spec-new-creds') });

  it 'writes a master key file', {
    scaffold-app('blog', into => root());
    expect(root().add('blog/config/master.key').e).to.be-truthy;
  }

  it 'writes an encrypted credentials file with a secret key base', {
    scaffold-app('shop', into => root());
    expect(MVC::Keayl::Credentials.resolve(root => root().add('shop'))<secret-key-base>.defined).to.be-truthy;
  }

  it 'gitignores the master key', {
    scaffold-app('store', into => root());
    expect(root().add('store/.gitignore').slurp.contains('config/master.key')).to.be-truthy;
  }
}
