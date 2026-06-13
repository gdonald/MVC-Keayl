use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Request;
use MVC::Keayl::I18n::Locale;
use MVC::Keayl::Routing;
use MVC::Keayl::Routing::UrlHelpers;

sub request(*%options) { MVC::Keayl::Request.new(|%options) }

describe 'MVC::Keayl::I18n::Locale Accept-Language parsing', {
  it 'parses and orders by quality', {
    expect(parse-accept-language('fr-CA,fr;q=0.9,en;q=0.8')).to.be(('fr-CA', 'fr', 'en'));
  }

  it 'sorts a lower-quality leading entry behind a higher one', {
    expect(parse-accept-language('en;q=0.5,de;q=0.9')).to.be(('de', 'en'));
  }

  it 'returns nothing for an absent header', {
    expect(parse-accept-language(Str)).to.be(());
  }
}

describe 'MVC::Keayl::I18n::Locale resolution from a param', {
  it 'resolves the locale from a query parameter', {
    expect(resolve-locale(request(query-string => 'locale=fr&page=2'), strategies => <param>, available => <en fr>)).to.be('fr');
  }

  it 'falls back to the default when the param locale is unavailable', {
    expect(resolve-locale(request(query-string => 'locale=de'), strategies => <param>, available => <en fr>, default => 'en')).to.be('en');
  }
}

describe 'MVC::Keayl::I18n::Locale resolution from a header', {
  it 'matches an Accept-Language tag to its base locale', {
    expect(resolve-locale(request(headers => { 'Accept-Language' => 'fr-CA,fr;q=0.9,en;q=0.8' }), strategies => <header>, available => <en fr>)).to.be('fr');
  }

  it 'skips an unavailable tag and matches the next', {
    expect(resolve-locale(request(headers => { 'Accept-Language' => 'es,en;q=0.7' }), strategies => <header>, available => <en fr>)).to.be('en');
  }
}

describe 'MVC::Keayl::I18n::Locale resolution from the host', {
  it 'resolves the locale from a subdomain', {
    expect(resolve-locale(request(headers => { Host => 'fr.example.com' }), strategies => <subdomain>, available => <en fr>)).to.be('fr');
  }

  it 'resolves the locale from a domain suffix', {
    expect(resolve-locale(request(headers => { Host => 'example.fr' }), strategies => <domain>, available => <en fr>)).to.be('fr');
  }
}

describe 'MVC::Keayl::I18n::Locale strategy ordering', {
  it 'prefers an earlier strategy that resolves', {
    expect(resolve-locale(request(query-string => 'locale=fr', headers => { 'Accept-Language' => 'en' }), strategies => <param header>, available => <en fr>)).to.be('fr');
  }

  it 'falls through to a later strategy', {
    expect(resolve-locale(request(headers => { 'Accept-Language' => 'fr' }), strategies => <param header>, available => <en fr>)).to.be('fr');
  }
}

describe 'MVC::Keayl::I18n::Locale default-url-options', {
  let(:helpers, {
    my $router = routes { get '/about', to => 'pages#about', as => 'about'; };
    MVC::Keayl::Routing::UrlHelpers.new(:$router, default-url-options => locale-url-options('fr'));
  });

  it 'builds url options carrying the locale', {
    expect(locale-url-options('fr')).to.be({ locale => 'fr' });
  }

  it 'carries the locale into generated paths', {
    expect(helpers.path-for('about')).to.be('/about?locale=fr');
  }
}
