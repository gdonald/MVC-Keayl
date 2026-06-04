use BDD::Behave;
use MVC::Keayl::Routing;

class HostConstraint {
  method matches(%context) {
    (%context<host> // '').ends-with('.io')
  }
}

describe 'MVC::Keayl routing block segment constraints', {
  let(:router, { routes { constraints(:id(/^\d+$/), { get '/items/:id', to => 'items#show' }) } });

  it 'accepts a valid segment', {
    expect(router.recognize('GET', '/items/42').defined).to.be-truthy;
  }

  it 'rejects an invalid segment', {
    expect(router.recognize('GET', '/items/abc').defined).to.be-falsy;
  }
}

describe 'MVC::Keayl routing request attribute constraints', {
  let(:router, { routes { constraints(:subdomain<api>, { get '/data', to => 'data#index' }) } });

  it 'matches the right attribute', {
    expect(router.recognize('GET', '/data', context => { subdomain => 'api' }).defined).to.be-truthy;
  }

  it 'rejects the wrong attribute', {
    expect(router.recognize('GET', '/data', context => { subdomain => 'www' }).defined).to.be-falsy;
  }

  it 'fails when the attribute is absent', {
    expect(router.recognize('GET', '/data').defined).to.be-falsy;
  }
}

describe 'MVC::Keayl routing regex request constraints', {
  let(:router, { routes { constraints(:host(/^api\./), { get '/data', to => 'data#index' }) } });

  it 'matches a host pattern', {
    expect(router.recognize('GET', '/data', context => { host => 'api.example.com' }).defined).to.be-truthy;
  }

  it 'rejects a non-matching host', {
    expect(router.recognize('GET', '/data', context => { host => 'www.example.com' }).defined).to.be-falsy;
  }
}

describe 'MVC::Keayl routing custom callable constraints', {
  let(:router, { routes { constraints(-> %c { (%c<host> // '').ends-with('.io') }, { get '/x', to => 'x#y' }) } });

  it 'accepts when the callable returns true', {
    expect(router.recognize('GET', '/x', context => { host => 'a.io' }).defined).to.be-truthy;
  }

  it 'rejects when the callable returns false', {
    expect(router.recognize('GET', '/x', context => { host => 'a.com' }).defined).to.be-falsy;
  }
}

describe 'MVC::Keayl routing custom object constraints', {
  let(:router, { routes { constraints(HostConstraint.new, { get '/z', to => 'z#y' }) } });

  it 'accepts via the matches method', {
    expect(router.recognize('GET', '/z', context => { host => 'a.io' }).defined).to.be-truthy;
  }

  it 'rejects via the matches method', {
    expect(router.recognize('GET', '/z', context => { host => 'a.com' }).defined).to.be-falsy;
  }
}

describe 'MVC::Keayl routing block defaults', {
  it 'supplies a default param', {
    my $router = routes { defaults(format => 'json', { get '/api/users', to => 'users#index' }) };
    expect($router.recognize('GET', '/api/users').params<format>).to.be('json');
  }
}
