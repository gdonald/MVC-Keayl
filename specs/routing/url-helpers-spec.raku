use BDD::Behave;
use MVC::Keayl::Routing;
use MVC::Keayl::Routing::UrlHelpers;

class Widget { has $.id; method is-persisted { $!id.defined } }
class Basket { }

sub build-router {
  routes {
    resources 'widgets';
    get '/about', to => 'pages#about', as => 'about';
    direct 'homepage', -> { 'https://example.com' };
    resolve 'Basket', -> $b { ('cart',) };
    get '/cart', to => 'carts#show', as => 'cart';
  }
}

sub helpers(%options = {}) {
  MVC::Keayl::Routing::UrlHelpers.new(:router(build-router), :default-url-options(%options))
}

describe 'MVC::Keayl URL helpers path generation', {
  let(:h, { helpers });

  it 'generates a named collection path', {
    expect(h.path-for('widgets')).to.be('/widgets');
  }

  it 'fills a segment from a positional param', {
    expect(h.path-for('widget', 5)).to.be('/widgets/5');
  }

  it 'appends a sorted query string for extra params', {
    expect(h.path-for('widget', 5, page => 2, sort => 'name')).to.be('/widgets/5?page=2&sort=name');
  }

  it 'turns anchor into a fragment', {
    expect(h.path-for('widget', 5, anchor => 'top')).to.be('/widgets/5#top');
  }

  it 'percent-encodes query values', {
    expect(h.path-for('widget', 5, q => 'a b')).to.be('/widgets/5?q=a%20b');
  }

  it 'appends a trailing slash on request', {
    expect(h.path-for('about', trailing-slash => True)).to.be('/about/');
  }
}

describe 'MVC::Keayl URL helpers url generation', {
  it 'builds an absolute URL from default-url-options', {
    expect(helpers({ host => 'ex.com', protocol => 'https' }).url-for('widget', 5)).to.be('https://ex.com/widgets/5');
  }

  it 'includes a non-default port', {
    expect(helpers({ host => 'ex.com', port => 3000 }).url-for('about')).to.be('http://ex.com:3000/about');
  }

  it 'lets a per-call option override the default', {
    expect(helpers({ host => 'ex.com' }).url-for('about', host => 'other.com')).to.be('http://other.com/about');
  }
}

describe 'MVC::Keayl URL helpers injection', {
  it 'resolves a *-path helper through FALLBACK', {
    expect(helpers.widget-path(5)).to.be('/widgets/5');
  }

  it 'resolves a *-url helper through FALLBACK', {
    expect(helpers({ host => 'ex.com' }).widgets-url).to.be('http://ex.com/widgets');
  }

  it 'returns a direct helper block result', {
    expect(helpers.homepage-url).to.be('https://example.com');
  }
}

describe 'MVC::Keayl URL helpers polymorphic', {
  let(:h, { helpers });

  it 'maps a persisted record to its member path', {
    expect(h.polymorphic-path(Widget.new(:id(7)))).to.be('/widgets/7');
  }

  it 'maps a new record to the collection path', {
    expect(h.polymorphic-path(Widget.new)).to.be('/widgets');
  }

  it 'dispatches a record through url-for', {
    expect(h.url-for(Widget.new(:id(3)))).to.be('http:///widgets/3');
  }

  it 'routes a record through a resolve mapping', {
    expect(h.polymorphic-path(Basket.new)).to.be('/cart');
  }
}
