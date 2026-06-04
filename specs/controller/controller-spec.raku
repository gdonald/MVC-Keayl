use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Request;
use MVC::Keayl::Response;
use MVC::Keayl::Controller;
use ControllerFixtures;

describe 'MVC::Keayl::Controller dispatch', {
  it 'runs the action and implicitly renders its return value', {
    expect(GreetController.new.dispatch('index').body).to.be('all greetings');
  }

  it 'reads request params in an action', {
    expect(GreetController.new(:params({ id => 5 })).dispatch('show').body).to.be('greeting 5');
  }

  context 'an action that sets the response directly', {
    let(:response, { GreetController.new.dispatch('create') });

    it 'keeps the status it set', {
      expect(response.status).to.be(201);
    }

    it 'keeps the body it set', {
      expect(response.body).to.be('created');
    }
  }

  context 'an action that sets a header and returns a value', {
    let(:response, { GreetController.new.dispatch('ping') });

    it 'implicitly renders the return value', {
      expect(response.body).to.be('pong');
    }

    it 'keeps the header it set', {
      expect(response.header('X-Ping')).to.be('pong');
    }
  }
}

describe 'MVC::Keayl::Controller per-request state', {
  let(:controller, {
    my $request = MVC::Keayl::Request.new(:method<GET>);
    GreetController.new(:$request, :params({ id => 9 }))
  });

  it 'exposes its request', {
    expect(controller.request.method).to.be('GET');
  }

  it 'exposes its params', {
    expect(controller.params<id>).to.be(9);
  }

  it 'has a response', {
    expect(controller.response ~~ MVC::Keayl::Response).to.be-truthy;
  }

  it 'gives each instance its own response', {
    expect(GreetController.new.response === GreetController.new.response).to.be-falsy;
  }
}

describe 'MVC::Keayl::Controller dispatch guards', {
  it 'raises for an unknown action', {
    expect({ GreetController.new.dispatch('missing') }).to.throw;
  }

  it 'does not dispatch a base controller method', {
    expect({ GreetController.new.dispatch('request') }).to.throw;
  }
}
