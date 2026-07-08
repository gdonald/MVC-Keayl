use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Logger;
use MVC::Keayl::LogEvent;
use MVC::Keayl::Middleware::Logger;
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

class LogWidgetsController is MVC::Keayl::Controller {
  method index { self.render(:plain('ok')) }
  method form  { self.render(:inline('%p hello')) }
}

sub logged-call($action-path, $request, :$view-renderer) {
  my $sink   = StringSink.new;
  my $logger = MVC::Keayl::Logger.new(level => 'info', out => $sink);

  my $router = routes { match $action-path, to => 'log_widgets#' ~ $action-path.subst('/', ''), via => <get post> };

  my %options = $view-renderer.defined ?? (view-renderer => $view-renderer) !! ();
  my $dispatcher = MVC::Keayl::Dispatcher.new(:$router, controllers => [LogWidgetsController], controller-options => %options);

  my $stack = MVC::Keayl::Middleware::Logger.new(app => $dispatcher, :$logger, clock => step-clock());
  $stack.call($request);

  $sink.text
}

describe 'MVC::Keayl::Logger threshold', {
  context 'at the info level', {
    let(:logger, { MVC::Keayl::Logger.new(level => 'info') });

    it 'enables its own level', {
      expect(logger.enabled('info')).to.be-truthy;
    }

    it 'enables a higher level', {
      expect(logger.enabled('error')).to.be-truthy;
    }

    it 'disables a lower level', {
      expect(logger.enabled('debug')).to.be-falsy;
    }
  }

  it 'disables everything at the silent level', {
    expect(MVC::Keayl::Logger.new(level => 'silent').enabled('error')).to.be-falsy;
  }
}

describe 'MVC::Keayl::Logger output', {
  it 'writes an enabled message to the output', {
    my $sink = StringSink.new;
    MVC::Keayl::Logger.new(level => 'info', out => $sink).info('hello');
    expect($sink.text).to.be("hello\n");
  }

  it 'returns true when a message is logged', {
    expect(MVC::Keayl::Logger.new(level => 'info', out => StringSink.new).info('hello')).to.be-truthy;
  }

  it 'writes nothing for a disabled level', {
    my $sink = StringSink.new;
    MVC::Keayl::Logger.new(level => 'warn', out => $sink).info('skipped');
    expect($sink.text).to.be('');
  }

  it 'returns false for a disabled level', {
    expect(MVC::Keayl::Logger.new(level => 'warn', out => StringSink.new).info('skipped')).to.be-falsy;
  }

  it 'writes through the error convenience method', {
    my $sink = StringSink.new;
    MVC::Keayl::Logger.new(level => 'debug', out => $sink).error('boom');
    expect($sink.text.contains('boom')).to.be-truthy;
  }
}

describe 'MVC::Keayl::LogEvent', {
  it 'accumulates timing across calls for a kind', {
    my $event = MVC::Keayl::LogEvent.new(clock => step-clock());
    $event.time('view', -> { });
    $event.time('view', -> { });
    expect($event.timing('view')).to.be(0.002);
  }

  it 'returns the timed block result', {
    expect(MVC::Keayl::LogEvent.new(clock => step-clock()).time('action', { 42 })).to.be(42);
  }

  it 'records parameters', {
    my $event = MVC::Keayl::LogEvent.new;
    $event.set-params(%( name => 'Ada' ));
    expect($event.params<name>).to.be('Ada');
  }
}

describe 'MVC::Keayl::Middleware::Logger', {
  it 'records method, path, status, and duration', {
    my $sink   = StringSink.new;
    my $logger = MVC::Keayl::Logger.new(level => 'info', out => $sink);
    my $stack  = MVC::Keayl::Middleware::Logger.new(app => StatusEndpoint.new(status => 201), :$logger, clock => step-clock());
    $stack.call(request('POST', '/widgets'));
    expect($sink.text.contains('POST /widgets 201 in 1.00ms')).to.be-truthy;
  }

  context 'with a disabled logger', {
    let(:sink, { StringSink.new });
    let(:stack, {
      MVC::Keayl::Middleware::Logger.new(
        app    => StatusEndpoint.new,
        logger => MVC::Keayl::Logger.new(level => 'silent', out => sink),
      )
    });

    it 'still serves the request', {
      expect(stack.call(request('GET', '/widgets')).status).to.be(200);
    }

    it 'writes no request line', {
      stack.call(request('GET', '/widgets'));
      expect(sink.text).to.be('');
    }
  }

  context 'when logging is produced while the request runs', {
    let(:sink, { StringSink.new });
    let(:lines, {
      my $logger = MVC::Keayl::Logger.new(level => 'info', out => sink);
      my $stack  = MVC::Keayl::Middleware::Logger.new(app => LoggingEndpoint.new(:$logger), :$logger, clock => step-clock());
      $stack.call(request('GET', '/widgets'));
      sink.text.lines
    });

    it 'emits the in-request logging first', {
      expect(lines[0]).to.be('during-request');
    }

    it 'writes the request summary line last', {
      expect(lines[1]).to.match(/'GET /widgets'/);
    }
  }
}

describe 'request logging through a controller', {
  it 'names the controller action', {
    expect(logged-call('/index', request('GET', '/index')).contains('log_widgets#index')).to.be-truthy;
  }

  it 'records controller action timing', {
    expect(logged-call('/index', request('GET', '/index')).contains('action=')).to.be-truthy;
  }

  it 'records view-render timing', {
    my $renderer = MVC::Keayl::View.new(paths => ['specs/lib/views']);
    expect(logged-call('/form', request('GET', '/form'), view-renderer => $renderer).contains('view=')).to.be-truthy;
  }

  context 'with filtered parameters', {
    let(:text, {
      logged-call('/index', request('POST', '/index',
        body    => 'password=secret&name=Ada',
        headers => { 'Content-Type' => 'application/x-www-form-urlencoded' },
      ))
    });

    it 'logs an unfiltered parameter', {
      expect(text.contains('name=Ada')).to.be-truthy;
    }

    it 'redacts a filtered parameter', {
      expect(text.contains('[FILTERED]')).to.be-truthy;
    }

    it 'never leaks the filtered value', {
      expect(text.contains('secret')).to.be-falsy;
    }
  }
}
