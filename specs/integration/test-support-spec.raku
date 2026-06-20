use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::TestSupport;
use MVC::Keayl::Dispatcher;
use MVC::Keayl::Router;
use MVC::Keayl::Routing;
use MVC::Keayl::Controller;
use MVC::Keayl::Mailer;
use MVC::Keayl::Mailer::Delivery::Test;
use MVC::Keayl::Job;
use MVC::Keayl::Job::QueueAdapter::Test;
use MVC::Keayl::Cable::PubSub::InMemory;
use MVC::Keayl::Cable::Connection;
use MVC::Keayl::Cable::Channel;

class TestSupportCounterController is MVC::Keayl::Controller {
  method bump {
    self.session<count> = (self.session<count> // 0) + 1;
    self.render(plain => 'count=' ~ self.session<count>);
  }
  method go { self.redirect-to('/landing') }
  method landing { self.render(plain => 'you have landed') }
  method widgets { self.render(html => '<ul><li>Gizmo</li></ul>') }
}

class TestSupportShowController is MVC::Keayl::Controller {
  method show {
    self.assign('widget', 'gizmo');
    self.render('show');
  }
}

class TestSupportPingMailer is MVC::Keayl::Mailer {
  method ping { self.mail(to => 'a@x.com', subject => 'Ping') }
}

class TestSupportRecordJob is MVC::Keayl::Job {
  method perform($sink, $value) { $sink.push: $value }
}

class TestSupportRoomChannel is MVC::Keayl::Cable::Channel {
  method subscribed { self.stream-from('room:1') }
}

sub build-session {
  my $router = routes {
    get '/bump',    to => 'test_support_counter#bump';
    get '/go',      to => 'test_support_counter#go';
    get '/landing', to => 'test_support_counter#landing';
    get '/widgets', to => 'test_support_counter#widgets';
  };
  my $dispatcher = MVC::Keayl::Dispatcher.new(
    :$router,
    controllers => [TestSupportCounterController],
    controller-options => %( secret => 'integration-secret' ),
  );
  IntegrationSession.new(app => $dispatcher)
}

describe 'in-process requests', {
  let(:session, { build-session });

  it 'drives the dispatch stack', {
    session.get('/widgets');
    expect(session.response.status).to.be(200);
  }

  it 'exposes the response body', {
    expect(session.get('/widgets').body.contains('Gizmo')).to.be-truthy;
  }
}

describe 'session persistence', {
  it 'carries the session across requests through the cookie jar', {
    my $session = build-session;
    $session.get('/bump');
    $session.get('/bump');
    expect($session.get('/bump').body).to.be('count=3');
  }
}

describe 'follow-redirect', {
  it 'issues the redirected request', {
    my $session = build-session;
    $session.get('/go');
    $session.follow-redirect;
    expect($session.response.body).to.be('you have landed');
  }
}

describe 'response assertions', {
  let(:session, {
    my $s = build-session;
    $s.get('/widgets');
    $s
  });

  it 'pass for a matching status', {
    expect({ session.assert-response(200) }).not.to.throw;
  }

  it 'fail for a mismatched status', {
    expect({ session.assert-response(404) }).to.throw;
  }

  it 'pass when the body matches a selector', {
    expect({ session.assert-select('Gizmo') }).not.to.throw;
  }

  it 'fail when the body does not match', {
    expect({ session.assert-select('Missing') }).to.throw;
  }

  context 'for a redirect', {
    let(:redirected, {
      my $s = build-session;
      $s.get('/go');
      $s
    });

    it 'pass for the right location', {
      expect({ redirected.assert-redirected-to('/landing') }).not.to.throw;
    }

    it 'fail for the wrong location', {
      expect({ redirected.assert-redirected-to('/elsewhere') }).to.throw;
    }
  }
}

describe 'routing assertions', {
  let(:router, {
    routes {
      get  '/widgets/:id', to => 'widgets#show', as => 'widget';
      post '/widgets',     to => 'widgets#create';
    }
  });

  it 'recognize a route, action, and params', {
    expect({ assert-recognizes(router, 'GET', '/widgets/5', matching => %( controller => 'widgets', action => 'show', id => '5' )) }).not.to.throw;
  }

  it 'fail for an unrecognized path', {
    expect({ assert-recognizes(router, 'GET', '/nope') }).to.throw;
  }

  it 'generate the expected path', {
    expect({ assert-generates(router, 'widget', '/widgets/5', 5) }).not.to.throw;
  }

  it 'check recognition and generation together', {
    expect({ assert-routing(router, 'widget', 'GET', '/widgets/5', matching => %( action => 'show' ), 5) }).not.to.throw;
  }
}

describe 'controller and view introspection', {
  let(:renderer, { RecordingRenderer.new });
  let(:controller, {
    my $c = TestSupportShowController.new(view-renderer => renderer());
    $c.dispatch('show');
    $c
  });

  it 'find the rendered template', {
    controller();
    expect({ assert-rendered(renderer(), 'show') }).not.to.throw;
  }

  it 'read an assigned value', {
    expect({ assert-assigned(controller(), 'widget', 'gizmo') }).not.to.throw;
  }
}

describe 'mailer helpers', {
  before-each({ MVC::Keayl::Mailer::Delivery::Test.clear });

  it 'count a delivered email', {
    my $mailer = TestSupportPingMailer.new(delivery => MVC::Keayl::Mailer::Delivery::Test.new);
    expect({ assert-emails(1, { $mailer.deliver('ping') }) }).not.to.throw;
  }

  it 'fail on the wrong count', {
    my $mailer = TestSupportPingMailer.new(delivery => MVC::Keayl::Mailer::Delivery::Test.new);
    expect({ assert-emails(2, { $mailer.deliver('ping') }) }).to.throw;
  }
}

describe 'job helpers', {
  before-each({ MVC::Keayl::Job.reset-queue-adapter });

  it 'count enqueued jobs and perform them', {
    my $adapter = MVC::Keayl::Job::QueueAdapter::Test.new;
    MVC::Keayl::Job.queue-adapter($adapter);

    my @ran;
    assert-enqueued-jobs(2, $adapter, { TestSupportRecordJob.perform-later(@ran, 1); TestSupportRecordJob.perform-later(@ran, 2) });
    perform-enqueued-jobs($adapter);

    expect(@ran).to.be([1, 2]);
    MVC::Keayl::Job.reset-queue-adapter;
  }
}

describe 'cable helpers', {
  it 'count broadcasts on a stream', {
    my $pubsub = MVC::Keayl::Cable::PubSub::InMemory.new;
    expect({ assert-broadcasts($pubsub, 'room:1', 2, { $pubsub.broadcast('room:1', 'a'); $pubsub.broadcast('room:1', 'b') }) }).not.to.throw;
  }

  it 'assert a channel streams from a name', {
    my $pubsub = MVC::Keayl::Cable::PubSub::InMemory.new;
    my $conn = MVC::Keayl::Cable::Connection.new(:$pubsub, sink => -> $m { });
    my $channel = TestSupportRoomChannel.new(connection => $conn);
    $conn.add-subscription($channel);

    expect({ assert-stream-subscribed($channel, 'room:1') }).not.to.throw;
  }
}
