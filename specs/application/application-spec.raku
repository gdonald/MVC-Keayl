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
    my $app = MVC::Keayl::Application.new(controllers => [WidgetsController]);
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
