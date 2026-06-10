use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Notifications;
use MVC::Keayl::Application;
use MVC::Keayl::Middleware::RequestId;
use MVC::Keayl::Middleware::Logger;
use MVC::Keayl::Logger;
use MVC::Keayl::Dispatcher;
use MVC::Keayl::Router;
use MVC::Keayl::Controller;
use MVC::Keayl::Request;
use MVC::Keayl::Response;
use MVC::Keayl::View;
use MVC::Keayl::Routing;
use CLIFixtures;
use LoggingFixtures;

sub request($method, $path, *%args) {
  MVC::Keayl::Request.new(:$method, :$path, |%args)
}

class InstrController is MVC::Keayl::Controller {
  method show { self.render(:plain('ok')) }
  method page { self.render(:inline('%p hi')) }
}

class FakeBus {
  has @.subs;

  method subscribe(Str:D $event, &callback --> Int) {
    @!subs.push: %( :$event, :&callback );
    @!subs.elems - 1
  }

  method emit(Str:D $event, %payload) {
    .<callback>(%payload) for @!subs.grep(*.<event> eq $event);
  }
}

sub dispatcher(:$view-renderer) {
  my $router = routes {
    get '/show', to => 'instr#show';
    get '/page', to => 'instr#page';
  };

  my %options = $view-renderer.defined ?? (view-renderer => $view-renderer) !! ();
  MVC::Keayl::Dispatcher.new(:$router, controllers => [InstrController], controller-options => %options)
}

describe 'MVC::Keayl::Notifications subscriptions', {
  before-each { MVC::Keayl::Notifications.reset }

  it 'delivers a notified payload to a subscriber', {
    my @seen;
    MVC::Keayl::Notifications.subscribe('thing.happened', -> %payload { @seen.push: %payload<value> });
    MVC::Keayl::Notifications.notify('thing.happened', %( value => 7 ));
    expect(@seen).to.be([7]);
  }

  it 'reports no subscribers for an unsubscribed event', {
    expect(MVC::Keayl::Notifications.has-subscribers('nobody')).to.be-falsy;
  }

  it 'reports a subscriber once registered', {
    MVC::Keayl::Notifications.subscribe('somebody', -> %p { });
    expect(MVC::Keayl::Notifications.has-subscribers('somebody')).to.be-truthy;
  }

  it 'returns true when unsubscribing a known id', {
    my $id = MVC::Keayl::Notifications.subscribe('e', -> %p { });
    expect(MVC::Keayl::Notifications.unsubscribe($id)).to.be-truthy;
  }

  it 'stops delivering to an unsubscribed callback', {
    my @seen;
    my $id = MVC::Keayl::Notifications.subscribe('e', -> %p { @seen.push: 1 });
    MVC::Keayl::Notifications.unsubscribe($id);
    MVC::Keayl::Notifications.notify('e', %());
    expect(@seen.elems).to.be(0);
  }

  it 'returns false when unsubscribing an unknown id', {
    expect(MVC::Keayl::Notifications.unsubscribe(999)).to.be-falsy;
  }
}

describe 'MVC::Keayl::Notifications instrument', {
  before-each { MVC::Keayl::Notifications.reset }

  it 'returns the block result', {
    expect(MVC::Keayl::Notifications.instrument('work', %(), { 99 })).to.be(99);
  }

  it 'adds a duration to the payload', {
    my %captured;
    MVC::Keayl::Notifications.subscribe('work', -> %payload { %captured = %payload });
    MVC::Keayl::Notifications.instrument('work', %( label => 'job' ), { 1 });
    expect(%captured<duration>.defined).to.be-truthy;
  }

  it 'delivers the payload to a subscriber', {
    my %captured;
    MVC::Keayl::Notifications.subscribe('work', -> %payload { %captured = %payload });
    MVC::Keayl::Notifications.instrument('work', %( label => 'job' ), { 1 });
    expect(%captured<label>).to.be('job');
  }

  it 'runs the block even with no subscribers', {
    expect(MVC::Keayl::Notifications.instrument('nobody', %(), { 5 })).to.be(5);
  }

  it 'rethrows a block error', {
    expect({ MVC::Keayl::Notifications.instrument('boom', %(), { die 'kaboom' }) }).to.throw;
  }

  it 'reports the exception to a subscriber', {
    my %captured;
    MVC::Keayl::Notifications.subscribe('boom', -> %payload { %captured = %payload });
    try MVC::Keayl::Notifications.instrument('boom', %(), { die 'kaboom' });
    expect(%captured<exception>.defined).to.be-truthy;
  }
}

describe 'MVC::Keayl::Notifications bridge', {
  before-each { MVC::Keayl::Notifications.reset }

  it 'forwards a bridged source event onto the framework bus', {
    my $source = FakeBus.new;
    MVC::Keayl::Notifications.bridge($source);

    my @seen;
    MVC::Keayl::Notifications.subscribe('sql.active_record', -> %payload { @seen.push: %payload<sql> });
    $source.emit('sql.active_record', %( sql => 'SELECT 1' ));

    expect(@seen).to.be(['SELECT 1']);
  }
}

describe 'dispatch and render hooks', {
  before-each { MVC::Keayl::Notifications.reset }

  it 'instruments dispatch with the controller', {
    my %captured;
    MVC::Keayl::Notifications.subscribe('dispatch.keayl', -> %payload { %captured = %payload });
    dispatcher.call(request('GET', '/show'));
    expect(%captured<controller>).to.be('instr');
  }

  it 'instruments dispatch with the action', {
    my %captured;
    MVC::Keayl::Notifications.subscribe('dispatch.keayl', -> %payload { %captured = %payload });
    dispatcher.call(request('GET', '/show'));
    expect(%captured<action>).to.be('show');
  }

  it 'instruments render with the kind of render', {
    my @kinds;
    MVC::Keayl::Notifications.subscribe('render.keayl', -> %payload { @kinds.push: %payload<kind> });
    dispatcher(view-renderer => MVC::Keayl::View.new(paths => ['specs/lib/views'])).call(request('GET', '/page'));
    expect(@kinds).to.be(['inline']);
  }
}

describe 'MVC::Keayl::Middleware::RequestId', {
  it 'generates and sets a request id', {
    my $stack = MVC::Keayl::Middleware::RequestId.new(app => StatusEndpoint.new, generator => sub { 'fixed-id' });
    expect($stack.call(request('GET', '/')).header('X-Request-Id')).to.be('fixed-id');
  }

  it 'propagates a valid incoming request id', {
    my $stack = MVC::Keayl::Middleware::RequestId.new(app => StatusEndpoint.new, generator => sub { 'generated' });
    expect($stack.call(request('GET', '/', headers => { 'X-Request-Id' => 'incoming-123' })).header('X-Request-Id')).to.be('incoming-123');
  }

  it 'replaces an invalid incoming request id', {
    my $stack = MVC::Keayl::Middleware::RequestId.new(app => StatusEndpoint.new, generator => sub { 'generated' });
    expect($stack.call(request('GET', '/', headers => { 'X-Request-Id' => 'bad id with spaces' })).header('X-Request-Id')).to.be('generated');
  }

  it 'exposes the request id to downstream instrumentation', {
    MVC::Keayl::Notifications.reset;
    my %captured;
    MVC::Keayl::Notifications.subscribe('dispatch.keayl', -> %payload { %captured = %payload });
    my $stack = MVC::Keayl::Middleware::RequestId.new(app => dispatcher, generator => sub { 'trace-9' });
    $stack.call(request('GET', '/show'));
    expect(%captured<request-id>).to.be('trace-9');
  }

  it 'prefixes the log line with the request id', {
    my $sink   = StringSink.new;
    my $logger = MVC::Keayl::Logger.new(level => 'info', out => $sink);
    my $logged = MVC::Keayl::Middleware::Logger.new(app => StatusEndpoint.new, :$logger, clock => step-clock());
    my $stack  = MVC::Keayl::Middleware::RequestId.new(app => $logged, generator => sub { 'req-7' });
    $stack.call(request('GET', '/show'));
    expect($sink.text.contains('[req-7]')).to.be-truthy;
  }
}

describe 'observability application wiring', {
  it 'sets a request id on the response', {
    my $app = MVC::Keayl::Application.new(controllers => [InstrController]);
    $app.draw-routes({ get '/show', to => 'instr#show' });
    expect($app.endpoint.call(request('GET', '/show')).header('X-Request-Id').defined).to.be-truthy;
  }

  it 'wires the request-id middleware by default', {
    my $app = MVC::Keayl::Application.new;
    $app.boot;
    expect($app.middleware.contains('request-id')).to.be-truthy;
  }

  it 'wires the request logger by default', {
    my $app = MVC::Keayl::Application.new;
    $app.boot;
    expect($app.middleware.contains('request-logger')).to.be-truthy;
  }
}
