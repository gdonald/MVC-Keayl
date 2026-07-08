use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Application;
use MVC::Keayl::Config;
use MVC::Keayl::Dispatcher;
use MVC::Keayl::Router;
use MVC::Keayl::Controller;
use MVC::Keayl::Request;
use MVC::Keayl::Response;
use MVC::Keayl::Routing;
use MVC::Keayl::Assets;
use MVC::Keayl::Logger;
use CLIFixtures;

class WidgetsController is MVC::Keayl::Controller {
  method index { self.render(:plain('all widgets')) }
  method show  { self.render(:plain('widget ' ~ self.params<id>)) }
  method boom  { die 'kaboom' }
}

sub request($method, $path, *%args) {
  MVC::Keayl::Request.new(:$method, :$path, |%args)
}

sub dispatcher(&block, *%args) {
  MVC::Keayl::Dispatcher.new(router => routes(&block), controllers => [WidgetsController], |%args)
}

describe 'MVC::Keayl::Dispatcher routing', {
  it 'dispatches a request to a controller action', {
    my $d = dispatcher({ get '/widgets', to => 'widgets#index' });
    expect($d.call(request('GET', '/widgets')).body).to.be('all widgets');
  }

  it 'makes route parameters available to the action', {
    my $d = dispatcher({ get '/widgets/:id', to => 'widgets#show' });
    expect($d.call(request('GET', '/widgets/42')).body).to.be('widget 42');
  }

  it 'returns 404 for an unmatched route', {
    my $d = dispatcher({ get '/widgets', to => 'widgets#index' });
    expect($d.call(request('GET', '/nope')).status).to.be(404);
  }

  it 'returns 405 for a known path with the wrong verb', {
    my $d = dispatcher({ get '/widgets', to => 'widgets#index' });
    expect($d.call(request('POST', '/widgets')).status).to.be(405);
  }

  it 'invokes a callable route', {
    my $d = dispatcher({ get '/ping', to => sub ($req) { MVC::Keayl::Response.new(body => 'pong') } });
    expect($d.call(request('GET', '/ping')).body).to.be('pong');
  }
}

describe 'MVC::Keayl::Dispatcher error handling', {
  it 'turns an unhandled error into a 500', {
    my $d = dispatcher({ get '/boom', to => 'widgets#boom' });
    expect($d.call(request('GET', '/boom')).status).to.be(500);
  }

  it 'includes the message with verbose errors', {
    my $d = dispatcher({ get '/boom', to => 'widgets#boom' }, verbose-errors => True);
    expect($d.call(request('GET', '/boom')).body.contains('kaboom')).to.be-truthy;
  }

  it 'hides the message with terse errors', {
    my $d = dispatcher({ get '/boom', to => 'widgets#boom' }, verbose-errors => False);
    expect($d.call(request('GET', '/boom')).body.contains('kaboom')).to.be-falsy;
  }
}

describe 'MVC::Keayl::Application', {
  it 'dispatches requests through its endpoint', {
    my $app = MVC::Keayl::Application.new(
      controllers => [WidgetsController],
      config      => MVC::Keayl::Config.new(environment => 'test'),
    );
    $app.draw-routes({ get '/widgets', to => 'widgets#index' });
    expect($app.endpoint.call(request('GET', '/widgets')).body).to.be('all widgets');
  }

  it 'runs initializers in registration order at boot', {
    my @ran;
    my $app = MVC::Keayl::Application.new;
    $app.initializer('first',  -> $a { @ran.push('first') });
    $app.initializer('second', -> $a { @ran.push('second') });
    $app.boot;
    expect(@ran).to.be(['first', 'second']);
  }

  it 'runs initializers once across repeated boots', {
    my $count = 0;
    my $app = MVC::Keayl::Application.new;
    $app.initializer('once', -> $a { $count++ });
    $app.boot;
    $app.boot;
    expect($count).to.be(1);
  }

  it 'wires a view renderer through a default initializer', {
    my $app = MVC::Keayl::Application.new;
    $app.boot;
    expect($app.controller-options<view-renderer>.defined).to.be-truthy;
  }
}

describe 'MVC::Keayl::Application environment behavior', {
  it 'does not reload templates in production', {
    my $app = MVC::Keayl::Application.new(config => MVC::Keayl::Config.new(environment => 'production'));
    $app.boot;
    expect($app.controller-options<view-renderer>.reload).to.be-falsy;
  }

  it 'reloads templates in development', {
    my $app = MVC::Keayl::Application.new(config => MVC::Keayl::Config.new(environment => 'development'));
    $app.boot;
    expect($app.controller-options<view-renderer>.reload).to.be-truthy;
  }

  it 'defaults development to a log level that shows request logging', {
    my $app = MVC::Keayl::Application.new(config => MVC::Keayl::Config.new(environment => 'development'));
    $app.boot;
    expect($app.logger.enabled('info')).to.be-truthy;
  }

  it 'keeps non-development environments silent by default', {
    my $app = MVC::Keayl::Application.new(config => MVC::Keayl::Config.new(environment => 'test'));
    $app.boot;
    expect($app.logger.enabled('info')).to.be-falsy;
  }

  it 'lets a configured log level override the development default', {
    my $app = MVC::Keayl::Application.new(config => MVC::Keayl::Config.new(settings => %( 'log-level' => 'warn' ), environment => 'development'));
    $app.boot;
    expect($app.logger.level).to.be('warn');
  }

  it 'logs the request through the built endpoint in development', {
    my $sink = StringSink.new;
    my $app  = MVC::Keayl::Application.new(
      controllers => [WidgetsController],
      config      => MVC::Keayl::Config.new(environment => 'development'),
      logger      => MVC::Keayl::Logger.new(level => 'debug', out => $sink),
    );
    $app.draw-routes({ get '/widgets', to => 'widgets#index' });

    $app.endpoint.call(request('GET', '/widgets'));

    expect($sink.text).to.match(/ 'GET /widgets' /);
  }
}

describe 'MVC::Keayl::Application assets initializer', {
  before-each({ reset-asset-manifest });

  it 'loads the asset manifest at boot when one is present', {
    my $root = temp-dir('app-assets');
    $root.add('public/assets').mkdir;
    $root.add('public/assets/manifest.json').spurt('{"assets":{"app.css":"app-abc.css"}}');

    MVC::Keayl::Application.new(
      config => MVC::Keayl::Config.new(settings => %( assets => %( public-root => $root.add('public/assets').Str ) )),
    ).boot;

    expect(asset-manifest.lookup('app.css')).to.be('app-abc.css');

    reset-asset-manifest;
  }

  it 'leaves the manifest unset without a precompiled manifest', {
    MVC::Keayl::Application.new(
      config => MVC::Keayl::Config.new(settings => %( assets => %( public-root => temp-dir('app-assets-empty').Str ) )),
    ).boot;

    expect(asset-manifest.defined).to.be-falsy;
  }
}

describe 'MVC::Keayl::Application active-record initializer', {
  it 'connects when a database is configured', {
    my %connected;
    my $app = MVC::Keayl::Application.new(
      config             => MVC::Keayl::Config.new(settings => %( database => %( adapter => 'sqlite' ) )),
      database-connector => -> %db { %connected = %db },
    );
    $app.boot;
    expect(%connected<adapter>).to.be('sqlite');
  }

  it 'is a no-op without a database config', {
    my $called = 0;
    my $app = MVC::Keayl::Application.new(database-connector => -> %db { $called++ });
    $app.boot;
    expect($called).to.be(0);
  }
}

describe 'MVC::Keayl::Application per-request connection checkout', {
  use ORM::ActiveRecord::DB;

  it 'wires the connection middleware when a database is configured', {
    temp %*ENV<DATABASE_URL> = 'sqlite::memory:';
    my $app = MVC::Keayl::Application.new;
    $app.boot;
    expect($app.middleware.contains('db-connection')).to.be-truthy;
  }

  it 'leaves the connection middleware off without a configured database', {
    my $app = MVC::Keayl::Application.new;
    $app.boot;
    expect($app.middleware.contains('db-connection')).to.be-falsy;
  }
}
