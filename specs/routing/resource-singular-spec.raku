use BDD::Behave;
use MVC::Keayl::Routing;

describe 'MVC::Keayl resource singular actions', {
  let(:router, { routes { resource 'profile' } });

  it 'maps GET new to new', {
    expect(router.recognize('GET', '/profile/new').action).to.be('new');
  }

  it 'maps POST to create', {
    expect(router.recognize('POST', '/profile').action).to.be('create');
  }

  it 'maps GET to show', {
    expect(router.recognize('GET', '/profile').action).to.be('show');
  }

  it 'maps GET edit to edit', {
    expect(router.recognize('GET', '/profile/edit').action).to.be('edit');
  }

  it 'maps PATCH to update', {
    expect(router.recognize('PATCH', '/profile').action).to.be('update');
  }

  it 'maps DELETE to destroy', {
    expect(router.recognize('DELETE', '/profile').action).to.be('destroy');
  }

  it 'has no index', {
    expect(router.routes.first(*.action eq 'index').defined).to.be-falsy;
  }

  it 'has no :id member', {
    expect(router.recognize('GET', '/profile/1').defined).to.be-falsy;
  }

  it 'targets the plural controller', {
    expect(router.recognize('GET', '/profile').target).to.be('profiles#show');
  }
}

describe 'MVC::Keayl resource singular named helpers', {
  let(:router, { routes { resource 'profile' } });

  it 'names show by the singular', {
    expect(router.route-named('profile').path).to.be('/profile');
  }

  it 'names new with a new- prefix', {
    expect(router.route-named('new-profile').path).to.be('/profile/new');
  }

  it 'names edit with an edit- prefix', {
    expect(router.route-named('edit-profile').path).to.be('/profile/edit');
  }
}

describe 'MVC::Keayl resource singular options', {
  it 'only filters the actions', {
    my $router = routes { resource 'profile', :only<show edit> };
    expect($router.routes.map(*.action).unique.sort.join(',')).to.be('edit,show');
  }

  it 'except drops an action', {
    my $router = routes { resource 'profile', :except<destroy> };
    expect($router.recognize('DELETE', '/profile').defined).to.be-falsy;
  }

  it 'overrides the URL segment with path', {
    my $router = routes { resource 'profile', :path<me> };
    expect($router.recognize('GET', '/me').action).to.be('show');
  }

  it 'overrides the controller', {
    my $router = routes { resource 'profile', :controller<accounts> };
    expect($router.recognize('GET', '/profile').target).to.be('accounts#show');
  }

  it 'prefixes the pluralized controller with module', {
    my $router = routes { resource 'profile', :module<admin> };
    expect($router.recognize('GET', '/profile').target).to.be('admin/profiles#show');
  }

  it 'renames the edit segment with path-names', {
    my $router = routes { resource 'profile', :path-names({ edit => 'change' }) };
    expect($router.recognize('GET', '/profile/change').action).to.be('edit');
  }

  it 'adds a member route without an id', {
    my $router = routes {
      resource 'profile', {
        member { get 'avatar', to => 'profiles#avatar' }
      }
    };
    expect($router.recognize('GET', '/profile/avatar').action).to.be('avatar');
  }
}
