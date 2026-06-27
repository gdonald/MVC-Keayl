use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::CLI;
use MVC::Keayl::Application;
use MVC::Keayl::Routing;
use JSON::Fast;
use CLIFixtures;

describe 'MVC::Keayl::CLI program-name', {
  it 'is keayl', {
    expect(program-name()).to.be('keayl');
  }
}

describe 'MVC::Keayl::CLI version', {
  it 'reads the version from META6.json', {
    my $dir = temp-dir('spec-version');
    write-file($dir.add('META6.json'), '{ "version": "9.8.7" }');
    expect(version($dir)).to.be('9.8.7');
  }

  it 'is unknown without a META6.json', {
    expect(version(temp-dir('spec-version-missing'))).to.be('unknown');
  }

  it 'is unknown when the version field is absent', {
    my $dir = temp-dir('spec-version-no-field');
    write-file($dir.add('META6.json'), '{ "name": "X" }');
    expect(version($dir)).to.be('unknown');
  }
}

describe 'MVC::Keayl::CLI framework-version', {
  it 'reports the distribution version as a dotted release', {
    expect(framework-version() ~~ /^ \d+ '.' \d+ '.' \d+ $/).to.be-truthy;
  }
}

describe 'MVC::Keayl::CLI usage', {
  it 'shows the program invocation', {
    expect(usage().contains('Usage: keayl')).to.be-truthy;
  }

  it 'lists the server command', {
    expect(usage().contains('server')).to.be-truthy;
  }

  it 'lists the console command', {
    expect(usage().contains('console')).to.be-truthy;
  }
}

describe 'MVC::Keayl::CLI routes-table', {
  it 'renders an empty string for an empty table', {
    expect(routes-table([])).to.be('');
  }

  context 'a table with named and unnamed routes', {
    let(:table, {
      [
        %( name => 'root', verbs => ['GET'],         path => '/',      target => 'home#index' ),
        %( name => Str,    verbs => ['GET', 'POST'], path => '/users', target => 'users#index' ),
      ]
    });

    it 'renders a string target', {
      expect(routes-table(table).contains('home#index')).to.be-truthy;
    }

    it 'joins verbs with a comma', {
      expect(routes-table(table).contains('GET,POST')).to.be-truthy;
    }

    it 'renders the path', {
      expect(routes-table(table).contains('/users')).to.be-truthy;
    }
  }

  it 'renders a non-string target as its type name', {
    my @table = %( name => Str, verbs => ['GET'], path => '/', target => MVC::Keayl::Application );
    expect(routes-table(@table).contains('MVC::Keayl::Application')).to.be-truthy;
  }
}

describe 'MVC::Keayl::CLI print-routes', {
  it 'succeeds for an existing routes file', {
    expect(print-routes('specs/lib/routes-fixture.raku', out => StringSink.new, err => StringSink.new)).to.be(0);
  }

  it 'prints the route table', {
    my $out = StringSink.new;
    print-routes('specs/lib/routes-fixture.raku', :$out, err => StringSink.new);
    expect($out.text.contains('users#index')).to.be-truthy;
  }

  it 'fails when the routes file is missing', {
    expect(print-routes('does/not/exist.raku', out => StringSink.new, err => StringSink.new)).to.be(1);
  }

  it 'reports the missing file', {
    my $err = StringSink.new;
    print-routes('does/not/exist.raku', out => StringSink.new, :$err);
    expect($err.text.contains('no does/not/exist.raku')).to.be-truthy;
  }
}

describe 'MVC::Keayl::CLI load-application', {
  it 'returns an undefined application when the file is missing', {
    expect(load-application('does/not/exist.raku', err => StringSink.new).defined).to.be-falsy;
  }

  it 'reports the missing file', {
    my $err = StringSink.new;
    load-application('does/not/exist.raku', :$err);
    expect($err.text.contains('no does')).to.be-truthy;
  }

  it 'evaluates the file into an application', {
    my $file = minimal-app-file(temp-dir('spec-load-app'));
    expect(load-application($file) ~~ MVC::Keayl::Application).to.be-truthy;
  }
}

describe 'MVC::Keayl::CLI build-server', {
  context 'with the defaults', {
    let(:adapter, { build-server(MVC::Keayl::Application.new) });

    it 'defaults the host to localhost', {
      expect(adapter.host).to.be('127.0.0.1');
    }

    it 'defaults the port to 3000', {
      expect(adapter.port).to.be(3000);
    }
  }

  context 'with overrides', {
    let(:adapter, { build-server(MVC::Keayl::Application.new, host => '0.0.0.0', port => 8080, scheme => 'https') });

    it 'honors a custom host', {
      expect(adapter.host).to.be('0.0.0.0');
    }

    it 'honors a custom port', {
      expect(adapter.port).to.be(8080);
    }

    it 'honors a custom scheme', {
      expect(adapter.scheme).to.be('https');
    }
  }
}

describe 'MVC::Keayl::CLI console', {
  context 'driven with a line of input', {
    let(:app-file, { minimal-app-file(temp-dir('spec-console-eval')) });

    it 'returns success after reading input', {
      expect(console(app-file, in => LineSource.new(input => ['1 + 1']), out => StringSink.new, err => StringSink.new)).to.be(0);
    }

    it 'announces the environment', {
      my $out = StringSink.new;
      console(app-file, in => LineSource.new(input => ['1 + 1']), :$out, err => StringSink.new);
      expect($out.text.contains('console (development)')).to.be-truthy;
    }

    it 'evaluates and prints a result', {
      my $out = StringSink.new;
      console(app-file, in => LineSource.new(input => ['1 + 1']), :$out, err => StringSink.new);
      expect($out.text.contains('2')).to.be-truthy;
    }
  }

  it 'exposes the booted app as a dynamic variable', {
    my $out = StringSink.new;
    console(minimal-app-file(temp-dir('spec-console-app')), in => LineSource.new(input => ['$*KEAYL-APP.environment']), :$out, err => StringSink.new);
    expect($out.text.contains('development')).to.be-truthy;
  }

  it 'reports an evaluation error without stopping', {
    my $err = StringSink.new;
    console(minimal-app-file(temp-dir('spec-console-error')), in => LineSource.new(input => ['die "boom"']), out => StringSink.new, :$err);
    expect($err.text.contains('boom')).to.be-truthy;
  }

  it 'skips blank input lines', {
    expect(console(minimal-app-file(temp-dir('spec-console-blank')), in => LineSource.new(input => ['', '   ']), out => StringSink.new, err => StringSink.new)).to.be(0);
  }

  it 'fails when the application file is missing', {
    expect(console('does/not/exist.raku', in => LineSource.new, out => StringSink.new, err => StringSink.new)).to.be(1);
  }
}

describe 'MVC::Keayl::CLI scaffold-app', {
  context 'a scaffolded application', {
    let(:root, { temp-dir('spec-scaffold') });

    before-each {
      scaffold-app('blog', into => root);
    }

    it 'writes the routes file', {
      expect(root.add('blog/config/routes.raku').e).to.be-truthy;
    }

    it 'writes the home controller', {
      expect(root.add('blog/app/controllers/HomeController.rakumod').e).to.be-truthy;
    }

    it 'names the app in the README', {
      expect(root.add('blog/README.md').slurp.contains('blog')).to.be-truthy;
    }
  }

  it 'reports the files it created', {
    expect(scaffold-app('blog', into => temp-dir('spec-scaffold-created')).elems > 0).to.be-truthy;
  }

  it 'writes a loadable routes file that defines a root', {
    my $root = temp-dir('spec-scaffold-routes');
    scaffold-app('shop', into => $root);
    my @table = load-routes($root.add('shop/config/routes.raku')).route-table;
    expect(@table.first(*<name> eq 'root')<target>).to.be('home#index');
  }
}

describe 'MVC::Keayl::CLI normalize-database', {
  it 'keeps sqlite', {
    expect(normalize-database('sqlite')).to.be('sqlite');
  }

  it 'maps postgres and postgresql onto pg', {
    expect(normalize-database('postgres')).to.be('pg');
    expect(normalize-database('postgresql')).to.be('pg');
  }

  it 'maps mariadb onto mysql', {
    expect(normalize-database('mariadb')).to.be('mysql');
  }

  it 'is case-insensitive', {
    expect(normalize-database('Postgres')).to.be('pg');
  }

  it 'dies on an unsupported database', {
    expect({ normalize-database('mongo') }).to.raise-error(Exception, /mongo/);
  }
}

describe 'MVC::Keayl::CLI scaffold-app database option', {
  sub config-for(Str:D $database) {
    my $root = temp-dir('spec-scaffold-db');
    scaffold-app('blog', into => $root, :$database);
    from-json($root.add('blog/config/application.json').slurp);
  }

  it 'defaults to a sqlite primary connection under each environment', {
    my %config = config-for('sqlite');
    expect(%config<development><primary><adapter>).to.be('sqlite');
    expect(%config<development><primary><name>).to.be('db/development.sqlite3');
  }

  it 'declares the test parallel worker count for behave isolated mode', {
    my %config = config-for('sqlite');
    expect(%config<test><parallel>).to.be(16);
  }

  it 'writes a postgres primary with conventional per-environment database names', {
    my %config = config-for('postgres');
    expect(%config<development><primary><adapter>).to.be('pg');
    expect(%config<development><primary><name>).to.be('blog_development');
    expect(%config<test><primary><name>).to.be('blog_test');
    expect(%config<production><primary><name>).to.be('blog_production');
  }

  it 'writes a mysql primary when asked for mysql', {
    my %config = config-for('mysql');
    expect(%config<production><primary><adapter>).to.be('mysql');
  }

  it 'refuses to scaffold for an unsupported database', {
    expect({ scaffold-app('blog', into => temp-dir('spec-scaffold-bad'), database => 'mongo') })
      .to.raise-error(Exception, /mongo/);
  }
}
