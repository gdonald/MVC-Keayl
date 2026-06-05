use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Controller;
use ControllerFixtures;

describe 'MVC::Keayl::Controller default rescue mappings', {
  it 'rescues a NotFound error to 404', {
    expect(RescueController.new.dispatch('missing-record').status).to.be(404);
  }

  it 'rescues a missing required param to 400', {
    expect(RescueController.new.dispatch('missing-param').status).to.be(400);
  }
}

describe 'MVC::Keayl::Controller rescue-from', {
  let(:response, { RescueController.new.dispatch('base-error') });

  it 'invokes the registered handler', {
    expect(response.status).to.be(500);
  }

  it 'passes the exception to the handler', {
    expect(response.body).to.be('base:base');
  }
}

describe 'MVC::Keayl::Controller rescue specificity', {
  let(:response, { RescueController.new.dispatch('child-error') });

  it 'prefers the most specific handler', {
    expect(response.status).to.be(422);
  }

  it 'runs the specific handler for the derived exception', {
    expect(response.body).to.be('child:child');
  }
}

describe 'MVC::Keayl::Controller unhandled exceptions', {
  it 'propagates an exception with no rescue handler', {
    expect({ RescueController.new.dispatch('unhandled') }).to.throw;
  }
}

describe 'MVC::Keayl::Controller rescue override', {
  it 'lets a subclass override an inherited default', {
    expect(OverrideRescueController.new.dispatch('missing-record').status).to.be(410);
  }
}
