use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Application;
use MVC::Keayl::Config;
use MVC::Keayl::Credentials;
use CLIFixtures;

sub app-in(IO::Path $root, Str $environment, *%options --> MVC::Keayl::Application) {
  MVC::Keayl::Application.new(:$root, config => MVC::Keayl::Config.new(:$environment), |%options)
}

sub credentials-root(--> IO::Path) {
  my $root       = temp-dir('secret-key-base-credentials');
  my $master-key = generate-master-key();

  write-file($root.add('config/master.key'), $master-key);
  write-file($root.add('config/credentials.yml.enc'), encrypt-content("secret-key-base: from-credentials\n", $master-key));

  $root
}

describe 'MVC::Keayl::Application secret-key-base', {
  context 'without credentials', {
    let(:root, { temp-dir('secret-key-base-empty') });

    it 'signs development sessions with a fixed development secret', {
      my $app = app-in(root, 'development').boot;
      expect($app.controller-options<secret>).to.be('keayl-development-secret-key-base');
    }

    it 'signs test sessions with a fixed development secret', {
      my $app = app-in(root, 'test').boot;
      expect($app.controller-options<secret>).to.be('keayl-development-secret-key-base');
    }

    it 'refuses to boot in production', {
      my $app = app-in(root, 'production');
      expect({ $app.boot }).to.throw;
    }
  }

  context 'with credentials', {
    let(:root, { credentials-root });

    it 'signs development sessions with the credentials secret', {
      my $app = app-in(root, 'development').boot;
      expect($app.controller-options<secret>).to.be('from-credentials');
    }

    it 'signs production sessions with the credentials secret', {
      my $app = app-in(root, 'production').boot;
      expect($app.controller-options<secret>).to.be('from-credentials');
    }
  }

  context 'with a secret passed in the controller options', {
    it 'keeps that secret', {
      my $app = app-in(credentials-root, 'production', controller-options => %( secret => 'explicit' )).boot;
      expect($app.controller-options<secret>).to.be('explicit');
    }
  }
}
