use BDD::Behave;
use MVC::Keayl::Routing;

describe 'MVC::Keayl resources REST actions', {
  let(:router, { routes { resources 'users' } });

  it 'maps GET collection to index', {
    expect(router.recognize('GET', '/users').action).to.be('index');
  }

  it 'maps POST collection to create', {
    expect(router.recognize('POST', '/users').action).to.be('create');
  }

  it 'maps GET new to new', {
    expect(router.recognize('GET', '/users/new').action).to.be('new');
  }

  it 'maps GET member to show', {
    expect(router.recognize('GET', '/users/5').action).to.be('show');
  }

  it 'maps GET member edit to edit', {
    expect(router.recognize('GET', '/users/5/edit').action).to.be('edit');
  }

  it 'maps PATCH member to update', {
    expect(router.recognize('PATCH', '/users/5').action).to.be('update');
  }

  it 'maps PUT member to update', {
    expect(router.recognize('PUT', '/users/5').action).to.be('update');
  }

  it 'maps DELETE member to destroy', {
    expect(router.recognize('DELETE', '/users/5').action).to.be('destroy');
  }

  it 'captures the id param on member routes', {
    expect(router.recognize('GET', '/users/5').params<id>).to.be('5');
  }

  it 'targets the named controller', {
    expect(router.recognize('GET', '/users/5').controller).to.be('users');
  }
}

describe 'MVC::Keayl resources named helpers', {
  let(:router, { routes { resources 'users' } });

  it 'names the collection by the plural', {
    expect(router.route-named('users').path).to.be('/users');
  }

  it 'names the member by the singular', {
    expect(router.route-named('user').path).to.be('/users/:id');
  }

  it 'names new with a new- prefix', {
    expect(router.route-named('new-user').path).to.be('/users/new');
  }

  it 'names edit with an edit- prefix', {
    expect(router.route-named('edit-user').path).to.be('/users/:id/edit');
  }
}

describe 'MVC::Keayl resources action filtering', {
  it 'only keeps the listed actions', {
    my $router = routes { resources 'users', :only<index show> };
    expect($router.routes.map(*.action).unique.sort.join(',')).to.be('index,show');
  }

  it 'except drops the listed action', {
    my $router = routes { resources 'users', :except<destroy> };
    expect($router.recognize('DELETE', '/users/5').defined).to.be-falsy;
  }
}

describe 'MVC::Keayl resources member routes', {
  let(:router, {
    routes {
      resources 'photos', {
        member { get 'preview', to => 'photos#preview' }
      }
    }
  });

  it 'adds the member route', {
    expect(router.recognize('GET', '/photos/9/preview').action).to.be('preview');
  }

  it 'names the member route per the singular', {
    expect(router.recognize('GET', '/photos/9/preview').route.name).to.be('preview-photo');
  }
}

describe 'MVC::Keayl resources collection routes', {
  let(:router, {
    routes {
      resources 'photos', {
        collection { get 'search', to => 'photos#search' }
      }
    }
  });

  it 'adds the collection route', {
    expect(router.recognize('GET', '/photos/search').action).to.be('search');
  }

  it 'names the collection route per the plural', {
    expect(router.recognize('GET', '/photos/search').route.name).to.be('search-photos');
  }

  it 'does not shadow show', {
    expect(router.recognize('GET', '/photos/9').action).to.be('show');
  }
}

describe 'MVC::Keayl resources on option', {
  it 'adds a collection route with on collection', {
    my $router = routes {
      resources 'photos', {
        get 'stats', to => 'photos#stats', on => 'collection';
      }
    };
    expect($router.recognize('GET', '/photos/stats').action).to.be('stats');
  }
}

describe 'MVC::Keayl resources path and as', {
  it 'overrides the URL segment with path', {
    my $router = routes { resources 'people', :path<team> };
    expect($router.recognize('GET', '/team').defined).to.be-truthy;
  }

  it 'does not register the original segment when path is given', {
    my $router = routes { resources 'people', :path<team> };
    expect($router.recognize('GET', '/people').defined).to.be-falsy;
  }

  it 'overrides the helper name with as', {
    my $router = routes { resources 'people', :as<member> };
    expect($router.route-named('member').defined).to.be-truthy;
  }
}

describe 'MVC::Keayl resources controller and module', {
  it 'overrides the target controller', {
    my $router = routes { resources 'users', :controller<accounts> };
    expect($router.recognize('GET', '/users').target).to.be('accounts#index');
  }

  it 'prefixes the controller with module', {
    my $router = routes { resources 'posts', :module<admin> };
    expect($router.recognize('GET', '/posts').target).to.be('admin/posts#index');
  }
}

describe 'MVC::Keayl resources param', {
  it 'renames the member key', {
    my $router = routes { resources 'users', :param<slug> };
    expect($router.recognize('GET', '/users/abc').params<slug>).to.be('abc');
  }
}

describe 'MVC::Keayl resources path-names', {
  let(:router, { routes { resources 'users', :path-names({ new => 'neu', edit => 'bearbeiten' }) } });

  it 'renames the new segment', {
    expect(router.recognize('GET', '/users/neu').action).to.be('new');
  }

  it 'renames the edit segment', {
    expect(router.recognize('GET', '/users/5/bearbeiten').action).to.be('edit');
  }
}

describe 'MVC::Keayl resources multiple names', {
  let(:router, { routes { resources 'users', 'posts' } });

  it 'registers the first resource', {
    expect(router.recognize('GET', '/users').defined).to.be-truthy;
  }

  it 'registers the second resource', {
    expect(router.recognize('GET', '/posts').defined).to.be-truthy;
  }
}
