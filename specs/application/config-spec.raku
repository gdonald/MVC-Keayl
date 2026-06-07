use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Config;

describe 'MVC::Keayl::Config environment', {
  it 'comes from KEAYL_ENV', {
    expect(MVC::Keayl::Config.environment-from(%( KEAYL_ENV => 'production' ))).to.be('production');
  }

  it 'falls back to RAKU_ENV', {
    expect(MVC::Keayl::Config.environment-from(%( RAKU_ENV => 'staging' ))).to.be('staging');
  }

  it 'defaults to development', {
    expect(MVC::Keayl::Config.environment-from(%())).to.be('development');
  }
}

describe 'MVC::Keayl::Config loading', {
  it 'records the loaded environment', {
    expect(MVC::Keayl::Config.load('specs/lib/config/application.json', environment => 'test').environment).to.be('test');
  }

  it 'keeps a shared setting in every environment', {
    expect(MVC::Keayl::Config.load('specs/lib/config/application.json', environment => 'test')<app-name>).to.be('Keayl');
  }

  it 'overrides a shared setting from the environment layer', {
    expect(MVC::Keayl::Config.load('specs/lib/config/application.json', environment => 'test')<log-level>).to.be('warn');
  }

  it 'reads a nested setting by dotted path', {
    expect(MVC::Keayl::Config.load('specs/lib/config/application.json', environment => 'development').get('database.adapter')).to.be('sqlite');
  }

  it 'leaves a setting absent from an environment undefined', {
    expect(MVC::Keayl::Config.load('specs/lib/config/application.json', environment => 'production')<database>.defined).to.be-falsy;
  }
}

describe 'MVC::Keayl::Config merging', {
  it 'replaces a scalar setting', {
    my $config = MVC::Keayl::Config.new(settings => %( a => 1, nested => %( x => 1 ) ));
    expect($config.merge(%( a => 2 ))<a>).to.be(2);
  }

  it 'keeps untouched nested keys in a deep merge', {
    my $config = MVC::Keayl::Config.new(settings => %( nested => %( x => 1 ) ));
    expect($config.merge(%( nested => %( y => 2 ) )).get('nested.x')).to.be(1);
  }
}
