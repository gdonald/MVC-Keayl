use BDD::Behave;
use MVC::Keayl::Routing;
use MVC::Keayl::Routing::Redirect;
use MVC::Keayl::Routing::Mount;

describe 'MVC::Keayl routing string redirect', {
  let(:target, {
    my $router = routes { get '/stories', to => redirect('/articles') };
    $router.recognize('GET', '/stories').target
  });

  it 'is a Redirect', {
    expect(target() ~~ MVC::Keayl::Routing::Redirect).to.be-truthy;
  }

  it 'carries its location', {
    expect(target.location-for({})).to.be('/articles');
  }

  it 'defaults to status 301', {
    expect(target.status).to.be(301);
  }
}

describe 'MVC::Keayl routing block redirect', {
  let(:target, {
    my $router = routes { get '/stories/:id', to => redirect(-> %p { '/articles/' ~ %p<id> }, status => 302) };
    $router.recognize('GET', '/stories/9').target
  });

  it 'computes its location from params', {
    expect(target.location-for({ id => 9 })).to.be('/articles/9');
  }

  it 'honours an overridden status', {
    expect(target.status).to.be(302);
  }
}

describe 'MVC::Keayl routing mount', {
  let(:router, {
    my $app = sub { 'mounted' };
    routes { mount $app, at => '/legacy' }
  });

  it 'matches its mount point', {
    expect(router.recognize('GET', '/legacy').defined).to.be-truthy;
  }

  it 'has a Mount target', {
    expect(router.recognize('GET', '/legacy').target ~~ MVC::Keayl::Routing::Mount).to.be-truthy;
  }

  it 'matches paths below the mount point', {
    expect(router.recognize('GET', '/legacy/users/5').defined).to.be-truthy;
  }

  it 'captures the sub-path', {
    expect(router.recognize('GET', '/legacy/users/5').params<mounted_path>).to.be('users/5');
  }
}
