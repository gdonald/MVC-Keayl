use BDD::Behave;
use MVC::Keayl::Routing;

describe 'MVC::Keayl nested resources', {
  let(:router, { routes { resources 'magazines', { resources 'ads' } } });

  it 'indexes a nested resource under the parent member', {
    expect(router.recognize('GET', '/magazines/3/ads').action).to.be('index');
  }

  it 'captures the parent key', {
    expect(router.recognize('GET', '/magazines/3/ads').params<magazine_id>).to.be('3');
  }

  it 'captures the nested member id', {
    expect(router.recognize('GET', '/magazines/3/ads/7').params<id>).to.be('7');
  }

  it 'maps the nested member to show', {
    expect(router.recognize('GET', '/magazines/3/ads/7').action).to.be('show');
  }

  it 'prefixes the nested collection helper', {
    expect(router.route-named('magazine-ads').path).to.be('/magazines/:magazine_id/ads');
  }

  it 'prefixes the nested member helper', {
    expect(router.route-named('magazine-ad').path).to.be('/magazines/:magazine_id/ads/:id');
  }
}

describe 'MVC::Keayl nested resource shapes', {
  it 'nests a singular resource under a plural parent', {
    my $router = routes { resources 'users', { resource 'profile' } };
    expect($router.recognize('GET', '/users/5/profile').action).to.be('show');
  }

  it 'nests a plural resource under a singular parent', {
    my $router = routes { resource 'account', { resources 'transactions' } };
    expect($router.recognize('GET', '/account/transactions').action).to.be('index');
  }
}

describe 'MVC::Keayl deeply nested resources', {
  let(:router, { routes { resources 'publishers', { resources 'magazines', { resources 'ads' } } } });

  it 'nests more than one level deep', {
    expect(router.recognize('GET', '/publishers/1/magazines/2/ads/3').action).to.be('show');
  }

  it 'accumulates the helper prefix', {
    expect(router.recognize('GET', '/publishers/1/magazines/2/ads/3').route.name).to.be('publisher-magazine-ad');
  }
}

describe 'MVC::Keayl shallow nesting', {
  let(:router, { routes { resources 'magazines', :shallow, { resources 'ads' } } });

  it 'keeps the collection nested', {
    expect(router.recognize('GET', '/magazines/3/ads').action).to.be('index');
  }

  it 'keeps new nested', {
    expect(router.recognize('GET', '/magazines/3/ads/new').action).to.be('new');
  }

  it 'drops the parent for the member', {
    expect(router.recognize('GET', '/ads/7').action).to.be('show');
  }

  it 'drops the parent for edit', {
    expect(router.recognize('GET', '/ads/7/edit').action).to.be('edit');
  }

  it 'drops the parent prefix from the member helper', {
    expect(router.recognize('GET', '/ads/7').route.name).to.be('ad');
  }

  it 'keeps the prefix on the collection helper', {
    expect(router.recognize('GET', '/magazines/3/ads').route.name).to.be('magazine-ads');
  }
}

describe 'MVC::Keayl shallow path and prefix overrides', {
  let(:router, { routes { resources 'magazines', { resources 'ads', :shallow, :shallow-path<a>, :shallow-prefix<x> } } });

  it 'overrides the shallow member segment', {
    expect(router.recognize('GET', '/a/7').action).to.be('show');
  }

  it 'overrides the shallow member name prefix', {
    expect(router.recognize('GET', '/a/7').route.name).to.be('xad');
  }
}
