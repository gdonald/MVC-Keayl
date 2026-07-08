use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::ErrorReporter;
use MVC::Keayl::ErrorReporting;
use MVC::Keayl::ExceptionPage;
use MVC::Keayl::Application;
use MVC::Keayl::Config;
use MVC::Keayl::Dispatcher;
use MVC::Keayl::Router;
use MVC::Keayl::Controller;
use MVC::Keayl::Request;
use MVC::Keayl::Response;
use MVC::Keayl::Routing;

sub request($method, $path, *%args) {
  MVC::Keayl::Request.new(:$method, :$path, |%args)
}

class FailController is MVC::Keayl::Controller {
  method boom { die 'kaboom' }
}

class RecordingReporter does MVC::Keayl::ErrorReporter {
  has @.errors;
  has @.contexts;

  method report(Exception:D $error, %context) {
    @!errors.push: $error;
    @!contexts.push: %context;
  }
}

class FailingReporter does MVC::Keayl::ErrorReporter {
  method report(Exception:D $error, %context) { die 'reporter exploded' }
}

sub failing-dispatcher(:$verbose-errors = False, :$error-reporting) {
  my $router = routes { match '/boom', to => 'fail#boom', via => <get post> };
  my %opts = $error-reporting.defined ?? (:$error-reporting) !! ();
  MVC::Keayl::Dispatcher.new(:$router, controllers => [FailController], :$verbose-errors, |%opts)
}

sub caught-error(--> Exception:D) {
  try { die '<script>alert(1)</script>' };
  $!
}

describe 'MVC::Keayl::ExceptionPage', {
  it 'shows a backtrace section', {
    expect(developer-exception-page(caught-error(), %( method => 'GET', path => '/posts' ), []).contains('<h2>Backtrace</h2>')).to.be-truthy;
  }

  it 'shows the request path', {
    expect(developer-exception-page(caught-error(), %( method => 'GET', path => '/posts' ), []).contains('/posts')).to.be-truthy;
  }

  it 'HTML-escapes the exception message', {
    expect(developer-exception-page(caught-error(), %(), []).contains('&lt;script&gt;')).to.be-truthy;
  }

  it 'never emits the raw message', {
    expect(developer-exception-page(caught-error(), %(), []).contains('<script>alert')).to.be-falsy;
  }

  it 'renders a filtered parameter', {
    expect(developer-exception-page(caught-error(), %( params => %( password => '[FILTERED]' ) ), []).contains('[FILTERED]')).to.be-truthy;
  }

  it 'renders the route table', {
    my @routes = [ %( name => 'posts', verbs => ['GET'], path => '/posts', target => 'posts#index' ) ];
    expect(developer-exception-page(caught-error(), %(), @routes).contains('posts#index')).to.be-truthy;
  }
}

describe 'MVC::Keayl::ErrorReporting', {
  it 'delivers the error to a subscribed reporter', {
    my $reporter  = RecordingReporter.new;
    my $reporting = MVC::Keayl::ErrorReporting.new;
    $reporting.subscribe($reporter);
    $reporting.report(caught-error(), %( action => 'show' ));
    expect($reporter.errors.elems).to.be(1);
  }

  it 'delivers the context to a subscribed reporter', {
    my $reporter  = RecordingReporter.new;
    my $reporting = MVC::Keayl::ErrorReporting.new(reporters => [$reporter]);
    $reporting.report(caught-error(), %( action => 'show' ));
    expect($reporter.contexts[0]<action>).to.be('show');
  }

  it 'keeps running later reporters after one fails', {
    my $reporter  = RecordingReporter.new;
    my $reporting = MVC::Keayl::ErrorReporting.new(reporters => [FailingReporter.new, $reporter]);
    $reporting.report(caught-error(), %());
    expect($reporter.errors.elems).to.be(1);
  }

  it 'is a no-op with no reporters', {
    expect({ MVC::Keayl::ErrorReporting.new.report(caught-error(), %()) }).not.to.throw;
  }
}

describe 'MVC::Keayl::Dispatcher error handling', {
  context 'in verbose mode', {
    let(:response, { failing-dispatcher(verbose-errors => True).call(request('GET', '/boom')) });

    it 'returns a 500', {
      expect(response.status).to.be(500);
    }

    it 'returns the developer page', {
      expect(response.body.contains('<h1>')).to.be-truthy;
    }

    it 'shows the error message', {
      expect(response.body.contains('kaboom')).to.be-truthy;
    }

    it 'serves the page as HTML', {
      expect(response.header('content-type')).to.be('text/html; charset=utf-8');
    }
  }

  context 'in terse mode', {
    let(:response, { failing-dispatcher(verbose-errors => False).call(request('GET', '/boom')) });

    it 'returns a 500', {
      expect(response.status).to.be(500);
    }

    it 'hides the details', {
      expect(response.body).to.be('Internal Server Error');
    }
  }

  context 'with error reporters', {
    it 'notifies the reporter of the dispatch error', {
      my $reporter = RecordingReporter.new;
      failing-dispatcher(error-reporting => MVC::Keayl::ErrorReporting.new(reporters => [$reporter])).call(request('GET', '/boom'));
      expect($reporter.contexts[0]<action>).to.be('boom');
    }

    it 'filters the reported parameters', {
      my $reporter = RecordingReporter.new;
      failing-dispatcher(error-reporting => MVC::Keayl::ErrorReporting.new(reporters => [$reporter])).call(request('POST', '/boom',
        body    => 'password=secret',
        headers => { 'Content-Type' => 'application/x-www-form-urlencoded' },
      ));
      expect($reporter.contexts[0]<params><password>).to.be('[FILTERED]');
    }
  }
}

describe 'error reporting application wiring', {
  it 'reports errors through a registered reporter', {
    my $reporter = RecordingReporter.new;
    my $app = MVC::Keayl::Application.new(
      controllers => [FailController],
      config      => MVC::Keayl::Config.new(environment => 'test'),
    );
    $app.draw-routes({ get '/boom', to => 'fail#boom' });
    $app.report-errors-with($reporter);
    $app.endpoint.call(request('GET', '/boom'));
    expect($reporter.errors.elems).to.be(1);
  }
}
