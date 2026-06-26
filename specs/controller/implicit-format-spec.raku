use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Request;
use MVC::Keayl::Controller;
use MVC::Keayl::View;
use ControllerFixtures;
use CLIFixtures;

sub request(Str:D $path) {
  MVC::Keayl::Request.new(:method<GET>, :$path)
}

describe 'implicit render and the request format', {
  context 'a json request with a json template', {
    let(:response, {
      my $renderer = StubRenderer.new(formats => ['json']);
      ImplicitController.new(request => request('/implicit.json'), view-renderer => $renderer).dispatch('index')
    });

    it 'renders the json template', {
      expect(response.body).to.be('template:index.json');
    }

    it 'types the response as json', {
      expect(response.header('content-type')).to.be('application/json');
    }
  }

  context 'a request without a format', {
    let(:response, {
      my $renderer = StubRenderer.new(formats => ['json']);
      ImplicitController.new(request => request('/implicit'), view-renderer => $renderer).dispatch('index')
    });

    it 'renders the html template', {
      expect(response.body).to.be('template:index');
    }

    it 'types the response as html', {
      expect(response.header('content-type')).to.be('text/html; charset=utf-8');
    }
  }

  context 'a json request without a json template', {
    let(:response, {
      my $renderer = StubRenderer.new(formats => []);
      ImplicitController.new(request => request('/implicit.json'), view-renderer => $renderer).dispatch('index')
    });

    it 'falls back to the html template', {
      expect(response.body).to.be('template:index');
    }

    it 'keeps the html content type', {
      expect(response.header('content-type')).to.be('text/html; charset=utf-8');
    }
  }

  context 'an explicit format option', {
    let(:response, {
      my $renderer = StubRenderer.new(formats => ['json']);
      ImplicitController.new(view-renderer => $renderer).dispatch('as-json')
    });

    it 'renders that format', {
      expect(response.body).to.be('template:index.json');
    }

    it 'sets the matching content type', {
      expect(response.header('content-type')).to.be('application/json');
    }
  }
}

describe 'implicit render through a real view', {
  let(:views, { ImplicitController.new.controller-path });

  context 'an xml template is present', {
    let(:response, {
      my $dir = temp-dir('spec-implicit-format-xml');
      write-file($dir.add(views() ~ '/index.html.haml'), "%p html view\n");
      write-file($dir.add(views() ~ '/index.xml.haml'), "%note xml view\n");

      my $view = MVC::Keayl::View.new(paths => [$dir.Str]);
      ImplicitController.new(request => request('/implicit.xml'), view-renderer => $view).dispatch('index')
    });

    it 'renders the xml template body', {
      expect(response.body.contains('<note>xml view</note>')).to.be-truthy;
    }

    it 'types the response as xml', {
      expect(response.header('content-type')).to.be('application/xml');
    }
  }

  context 'only an html template is present', {
    let(:response, {
      my $dir = temp-dir('spec-implicit-format-html-only');
      write-file($dir.add(views() ~ '/index.html.haml'), "%p html view\n");

      my $view = MVC::Keayl::View.new(paths => [$dir.Str]);
      ImplicitController.new(request => request('/implicit.xml'), view-renderer => $view).dispatch('index')
    });

    it 'renders the html template body', {
      expect(response.body.contains('html view')).to.be-truthy;
    }

    it 'types the response as html', {
      expect(response.header('content-type')).to.be('text/html; charset=utf-8');
    }
  }
}
