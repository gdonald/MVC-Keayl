use BDD::Behave;
use MVC::Keayl::Routing;

describe 'MVC::Keayl routing recognition', {
  let(:router, {
    routes {
      root to => 'home#index';
      get '/users', to => 'users#index';
      post '/users', to => 'users#create';
    }
  });

  it 'collects each declared route', {
    expect(router.routes.elems).to.be(3);
  }

  it 'parses the controller from a target', {
    expect(router.recognize('GET', '/users').controller).to.be('users');
  }

  it 'parses the action from a target', {
    expect(router.recognize('GET', '/users').action).to.be('index');
  }

  it 'returns undefined for an unknown path', {
    expect(router.recognize('GET', '/missing').defined).to.be-falsy;
  }

  it 'discriminates by HTTP method', {
    expect(router.recognize('POST', '/users').action).to.be('create');
  }

  it 'answers HEAD for a GET route', {
    expect(router.recognize('HEAD', '/users').defined).to.be-truthy;
  }
}

describe 'MVC::Keayl routing verb helpers', {
  my %verbs = GET => 'get', POST => 'post', PUT => 'put',
              PATCH => 'patch', DELETE => 'delete', OPTIONS => 'options';

  for %verbs.kv -> $verb, $helper {
    it "the $helper helper registers a $verb route", {
      my $router = routes { ::('&' ~ $helper)('/x', to => 'c#a') };
      expect($router.recognize($verb, '/x').defined).to.be-truthy;
    }
  }
}

describe 'MVC::Keayl routing callable target', {
  let(:route, {
    my $router = routes { get '/inline', to => sub { 'body' } };
    $router.recognize('GET', '/inline')
  });

  it 'stores a callable target as a callable', {
    expect(route.callable.defined).to.be-truthy;
  }

  it 'exposes an invokable callable', {
    expect(route.callable.()).to.be('body');
  }

  context 'with a string target', {
    let(:route, {
      my $router = routes { get '/users', to => 'users#index' };
      $router.recognize('GET', '/users')
    });

    it 'exposes no callable', {
      expect(route.callable.defined).to.be-falsy;
    }
  }
}

describe 'MVC::Keayl routing match with via', {
  context 'a verb list', {
    let(:router, { routes { match '/search', to => 'search#run', via => <get post> } });

    it 'registers the first listed verb', {
      expect(router.recognize('GET', '/search').defined).to.be-truthy;
    }

    it 'registers the second listed verb', {
      expect(router.recognize('POST', '/search').defined).to.be-truthy;
    }

    it 'does not register unlisted verbs', {
      expect(router.recognize('DELETE', '/search').defined).to.be-falsy;
    }
  }

  context 'via all', {
    let(:router, { routes { match '/any', to => 'x#y', via => 'all' } });

    it 'registers every verb', {
      expect(router.recognize('DELETE', '/any').defined).to.be-truthy;
    }
  }

  context 'via Whatever', {
    let(:router, { routes { match '/any', to => 'x#y', via => * } });

    it 'registers every verb', {
      expect(router.recognize('PUT', '/any').defined).to.be-truthy;
    }
  }
}

describe 'MVC::Keayl routing root', {
  let(:router, { routes { root to => 'home#index' } });

  it 'maps GET / to its target', {
    expect(router.recognize('GET', '/').controller).to.be('home');
  }

  it 'registers a route named root', {
    expect(router.route-named('root').path).to.be('/');
  }
}

describe 'MVC::Keayl routing load-routes', {
  let(:router, { load-routes('specs/lib/routes-fixture.raku') });

  it 'evaluates the routes file into a router', {
    expect(router.routes.elems).to.be(4);
  }

  it 'recognizes requests from the loaded routes', {
    expect(router.recognize('GET', '/users').action).to.be('index');
  }
}
