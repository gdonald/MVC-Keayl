use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Controller;
use ControllerFixtures;

sub rendered($action, *%options) {
  RenderController.new(|%options).dispatch($action)
}

sub renderer-options {
  view-renderer => StubRenderer.new
}

describe 'MVC::Keayl::Controller render json', {
  let(:response, { rendered('as-json') });

  it 'sets the JSON content type', {
    expect(response.header('content-type')).to.be('application/json');
  }

  it 'serializes its value', {
    expect(response.body).to.be('{"ok":true}');
  }
}

describe 'MVC::Keayl::Controller render plain', {
  let(:response, { rendered('as-plain') });

  it 'sets the plain content type', {
    expect(response.header('content-type')).to.be('text/plain; charset=utf-8');
  }

  it 'writes the text', {
    expect(response.body).to.be('hello');
  }
}

describe 'MVC::Keayl::Controller render html', {
  let(:response, { rendered('as-html') });

  it 'sets the html content type', {
    expect(response.header('content-type')).to.be('text/html; charset=utf-8');
  }

  it 'writes the markup', {
    expect(response.body).to.be('<b>hi</b>');
  }
}

describe 'MVC::Keayl::Controller render body', {
  let(:response, { rendered('as-body') });

  it 'writes the raw body', {
    expect(response.body).to.be('id,name');
  }

  it 'honours an explicit content-type', {
    expect(response.header('content-type')).to.be('text/csv');
  }
}

describe 'MVC::Keayl::Controller render status', {
  it 'sets the status alongside content', {
    expect(rendered('made').status).to.be(201);
  }

  it 'keeps the content when a status is given', {
    expect(rendered('made').body).to.be('created');
  }

  it 'sets the status on its own', {
    expect(rendered('only-status').status).to.be(204);
  }

  it 'leaves the body empty for a status-only render', {
    expect(rendered('only-status').body).to.be('');
  }
}

describe 'MVC::Keayl::Controller render templates', {
  it 'renders a template by name', {
    expect(rendered('by-name', |renderer-options).body).to.be('template:show');
  }

  it 'renders another action template', {
    expect(rendered('by-action', |renderer-options).body).to.be('template:edit');
  }

  it 'passes locals to the template', {
    expect(rendered('with-locals', |renderer-options).body).to.be('template:show id=7');
  }

  it 'renders an inline template', {
    expect(rendered('inline-render', |renderer-options).body).to.be('inline:<p>x</p>');
  }
}

describe 'MVC::Keayl::Controller render layouts', {
  it 'wraps the template in a layout', {
    expect(rendered('layered', |renderer-options).body).to.be('layout(admin){template:show}');
  }

  it 'renders without a layout when layout is false', {
    expect(rendered('no-layout', |renderer-options).body).to.be('template:show');
  }
}

describe 'MVC::Keayl::Controller implicit template render', {
  it 'uses the action template when a renderer is configured', {
    expect(rendered('implicit-show', |renderer-options).body).to.be('template:implicit-show');
  }
}

describe 'MVC::Keayl::Controller double render', {
  it 'raises when rendering twice', {
    expect({ RenderController.new.dispatch('double') }).to.throw;
  }
}
