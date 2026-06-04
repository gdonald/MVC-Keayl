use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Request;
use MVC::Keayl::Controller;
use ControllerFixtures;

describe 'MVC::Keayl::Controller redirect-to', {
  it 'defaults to status 302', {
    expect(FlowController.new.dispatch('to-path').status).to.be(302);
  }

  it 'sets the Location to a path', {
    expect(FlowController.new.dispatch('to-path').header('Location')).to.be('/dashboard');
  }

  it 'accepts a full URL', {
    expect(FlowController.new.dispatch('to-url').header('Location')).to.be('https://example.com');
  }

  it 'honours a numeric status', {
    expect(FlowController.new.dispatch('permanent').status).to.be(301);
  }

  it 'accepts a named status', {
    expect(FlowController.new.dispatch('see-other').status).to.be(303);
  }
}

describe 'MVC::Keayl::Controller redirect back', {
  it 'uses the Referer', {
    my $request = MVC::Keayl::Request.new(:headers({ Referer => '/previous' }));
    expect(FlowController.new(:$request).dispatch('go-back').header('Location')).to.be('/previous');
  }

  it 'falls back when there is no Referer', {
    my $request = MVC::Keayl::Request.new;
    expect(FlowController.new(:$request).dispatch('back-default').header('Location')).to.be('/home');
  }
}

describe 'MVC::Keayl::Controller head', {
  let(:response, { FlowController.new.dispatch('gone') });

  it 'sets the status', {
    expect(response.status).to.be(404);
  }

  it 'leaves the body empty', {
    expect(response.body).to.be('');
  }

  it 'accepts a named status', {
    expect(FlowController.new.dispatch('made').status).to.be(201);
  }

  it 'sets named headers', {
    expect(FlowController.new.dispatch('made').header('Location')).to.be('/users/5');
  }

  it 'sets a no-content status', {
    expect(FlowController.new.dispatch('empty').status).to.be(204);
  }
}

describe 'MVC::Keayl::Controller double render after redirect', {
  it 'raises when rendering after a redirect', {
    expect({ FlowController.new.dispatch('redirect-then-render') }).to.throw;
  }
}
