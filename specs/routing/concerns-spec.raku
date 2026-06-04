use BDD::Behave;
use MVC::Keayl::Routing;

describe 'MVC::Keayl routing concerns option', {
  let(:router, {
    routes {
      concern 'commentable', { resources 'comments' };
      resources 'posts', concerns => 'commentable';
    }
  });

  it 'adds the concern routes to the resource', {
    expect(router.recognize('GET', '/posts/5/comments').action).to.be('index');
  }

  it 'nests the concern routes under the resource', {
    expect(router.recognize('GET', '/posts/5/comments').params<post_id>).to.be('5');
  }
}

describe 'MVC::Keayl routing concerns invocation', {
  it 'can be invoked inside a resource block', {
    my $router = routes {
      concern 'commentable', { resources 'comments' };
      resources 'photos', { concerns 'commentable' };
    };
    expect($router.recognize('GET', '/photos/9/comments').action).to.be('index');
  }
}

describe 'MVC::Keayl routing multiple concerns', {
  let(:router, {
    routes {
      concern 'commentable', { resources 'comments' };
      concern 'taggable', { resources 'tags' };
      resources 'posts', concerns => <commentable taggable>;
    }
  });

  it 'applies the first concern', {
    expect(router.recognize('GET', '/posts/5/comments').defined).to.be-truthy;
  }

  it 'applies the second concern', {
    expect(router.recognize('GET', '/posts/5/tags').defined).to.be-truthy;
  }
}

describe 'MVC::Keayl routing unknown concern', {
  it 'raises for an unknown concern', {
    expect({ routes { resources 'posts', concerns => 'missing' } }).to.throw;
  }
}
