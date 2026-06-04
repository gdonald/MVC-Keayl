use BDD::Behave;
use MVC::Keayl::Routing;

describe 'MVC::Keayl routing namespace', {
  let(:router, { routes { namespace 'admin', { resources 'users' } } });

  it 'prefixes the path and module', {
    expect(router.recognize('GET', '/admin/users').target).to.be('admin/users#index');
  }

  it 'prefixes the helper name', {
    expect(router.recognize('GET', '/admin/users').route.name).to.be('admin-users');
  }

  it 'prefixes a plain route', {
    my $r = routes { namespace 'admin', { get '/dashboard', to => 'dashboard#show' } };
    expect($r.recognize('GET', '/admin/dashboard').target).to.be('admin/dashboard#show');
  }
}

describe 'MVC::Keayl routing scope', {
  it 'applies path and module independently', {
    my $router = routes { scope(path => 'api', module => 'v1', { get '/ping', to => 'ping#show' }) };
    expect($router.recognize('GET', '/api/ping').target).to.be('v1/ping#show');
  }

  it 'applies the name prefix', {
    my $router = routes { scope(as => 'api', { get '/ping', to => 'ping#show', as => 'ping' }) };
    expect($router.route-named('api-ping').defined).to.be-truthy;
  }

  it 'leaves the module unchanged for a path-only scope', {
    my $router = routes { scope(path => 'api', { get '/ping', to => 'ping#show' }) };
    expect($router.recognize('GET', '/api/ping').target).to.be('ping#show');
  }

  it 'composes nested scopes', {
    my $router = routes {
      namespace 'admin', {
        scope(path => 'reports', { get '/daily', to => 'reports#daily' });
      }
    };
    expect($router.recognize('GET', '/admin/reports/daily').target).to.be('admin/reports#daily');
  }
}

describe 'MVC::Keayl routing controller block', {
  it 'supplies the controller for an action target', {
    my $router = routes { controller 'photos', { get '/preview', to => 'show' } };
    expect($router.recognize('GET', '/preview').target).to.be('photos#show');
  }

  it 'defaults the action to the path', {
    my $router = routes { controller 'photos', { get '/list' } };
    expect($router.recognize('GET', '/list').target).to.be('photos#list');
  }
}

describe 'MVC::Keayl routing optional scope', {
  let(:router, { routes { scope('(:locale)', { get '/about', to => 'pages#about' }) } });

  it 'matches without the optional segment', {
    expect(router.recognize('GET', '/about').action).to.be('about');
  }

  it 'captures the optional segment when present', {
    expect(router.recognize('GET', '/en/about').params<locale>).to.be('en');
  }
}
