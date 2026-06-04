use BDD::Behave;
use MVC::Keayl::Routing;
use MVC::Keayl::Routing::UrlHelpers;

sub build-router {
  routes {
    resources 'users';
    get '/about', to => 'pages#about', as => 'about';
  }
}

describe 'MVC::Keayl routing merged recognition', {
  let(:match, { build-router.recognize('GET', '/users/5') });

  it 'exposes the controller', {
    expect(match.controller).to.be('users');
  }

  it 'exposes the action', {
    expect(match.action).to.be('show');
  }

  it 'exposes the path params', {
    expect(match.params<id>).to.be('5');
  }
}

describe 'MVC::Keayl routing recognition status', {
  let(:router, { build-router });

  it 'reports a match as found', {
    expect(router.recognition-status('GET', '/about')).to.be('found');
  }

  it 'reports a wrong method as method-not-allowed', {
    expect(router.recognition-status('POST', '/about')).to.be('method-not-allowed');
  }

  it 'reports an unknown path as not-found', {
    expect(router.recognition-status('GET', '/missing')).to.be('not-found');
  }

  it 'lists the verbs a path answers', {
    expect(router.allowed-methods('/about').grep(* ne 'HEAD').sort.join(',')).to.be('GET');
  }
}

describe 'MVC::Keayl routing route table', {
  let(:about, { build-router.route-table.first({ .<name> eq 'about' }) });

  it 'exposes each pattern', {
    expect(about<path>).to.be('/about');
  }

  it 'exposes each target', {
    expect(about<target>).to.be('pages#about');
  }

  it 'omits HEAD from the verb list', {
    expect(about<verbs>.join(',')).to.be('GET');
  }
}

describe 'MVC::Keayl routing round-trip', {
  let(:router, { build-router });

  it 'recognizes a generated path back to its action', {
    my $helpers = MVC::Keayl::Routing::UrlHelpers.new(:router(router));
    expect(router.recognize('GET', $helpers.path-for('user', 42)).action).to.be('show');
  }

  it 'round-trips the params of a generated path', {
    my $helpers = MVC::Keayl::Routing::UrlHelpers.new(:router(router));
    expect(router.recognize('GET', $helpers.path-for('user', 42)).params<id>).to.be('42');
  }
}
