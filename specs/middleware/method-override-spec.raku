use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Application;
use MVC::Keayl::Config;
use MVC::Keayl::Controller;
use MVC::Keayl::Routing;
use MVC::Keayl::TestSupport;
use MVC::Keayl::Helpers::Url;
use MVC::Keayl::Helpers::Form;

class OverrideCompaniesController is MVC::Keayl::Controller {
  method create  { self.render(plain => 'create') }
  method update  { self.render(plain => 'update') }
  method replace { self.render(plain => 'replace') }
  method destroy { self.render(plain => 'destroy') }
}

sub override-session(--> IntegrationSession) {
  my $app = MVC::Keayl::Application.new(
    config      => MVC::Keayl::Config.new(environment => 'test'),
    controllers => [OverrideCompaniesController],
  );

  $app.draw-routes({
    post   '/companies/:id', to => 'override_companies#create';
    patch  '/companies/:id', to => 'override_companies#update';
    put    '/companies/:id', to => 'override_companies#replace';
    delete '/companies/:id', to => 'override_companies#destroy';
  });

  IntegrationSession.new(app => $app.endpoint)
}

sub post-form(Str:D $body --> Str) {
  override-session.post('/companies/5',
    headers => %( 'Content-Type' => 'application/x-www-form-urlencoded' ),
    :$body).body
}

sub hidden-fields($html --> Str) {
  $html.Str.match(/ 'name="' (<-["]>+) '" type="hidden" value="' (<-["]>+) '"' /, :g).map({ "$_[0]=$_[1]" }).join('&')
}

describe 'MVC::Keayl::Middleware::MethodOverride', {
  it 'is part of the default application middleware', {
    my $app = MVC::Keayl::Application.new(config => MVC::Keayl::Config.new(environment => 'test'));
    $app.boot;
    expect($app.middleware.contains('method-override')).to.be-truthy;
  }

  context 'a POST form naming _method', {
    it 'routes delete to the DELETE route', {
      expect(post-form('_method=delete')).to.be('destroy');
    }

    it 'routes patch to the PATCH route', {
      expect(post-form('_method=patch')).to.be('update');
    }

    it 'routes put to the PUT route', {
      expect(post-form('_method=put')).to.be('replace');
    }

    it 'accepts an uppercase method name', {
      expect(post-form('_method=DELETE')).to.be('destroy');
    }

    it 'ignores a method other than PATCH, PUT, or DELETE', {
      expect(post-form('_method=get')).to.be('create');
    }
  }

  context 'a POST multipart form naming _method', {
    it 'routes to the named method', {
      my $body = "--B\r\nContent-Disposition: form-data; name=\"_method\"\r\n\r\ndelete\r\n--B--\r\n";
      my $response = override-session.post('/companies/5',
        headers => %( 'Content-Type' => 'multipart/form-data; boundary=B' ),
        :$body);
      expect($response.body).to.be('destroy');
    }
  }

  context 'a POST with an X-HTTP-Method-Override header', {
    it 'routes to the named method', {
      expect(override-session.post('/companies/5', headers => %( 'X-HTTP-Method-Override' => 'patch' )).body).to.be('update');
    }
  }

  context 'a POST without an override', {
    it 'stays a POST', {
      expect(post-form('name=Acme')).to.be('create');
    }
  }

  context 'a GET naming _method', {
    it 'is not overridden', {
      expect(override-session.get('/companies/5?_method=delete').status).to.be(405);
    }
  }

  context 'the fields button-to renders', {
    it 'reach the DELETE route', {
      expect(post-form(hidden-fields(button-to('Delete', '/companies/5', %( method => 'delete' ))))).to.be('destroy');
    }
  }

  context 'the fields form-with renders', {
    it 'reach the PATCH route', {
      expect(post-form(hidden-fields(form-with(url => '/companies/5', method => 'patch')))).to.be('update');
    }
  }
}
