use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Request;
use I18nFixtures;

sub dispatch(Str:D $action, *%options) {
  my $controller = LocaleDemoController.new(
    request      => MVC::Keayl::Request.new(|%options),
    i18n         => build-controller-backend,
    i18n-options => { strategies => <param>, available => <en fr> },
  );

  $controller.dispatch($action);
}

describe 'MVC::Keayl::Controller I18n integration', {
  context 'lazy lookup scoped to the controller and action', {
    it 'resolves a lazy key in the default locale', {
      expect(dispatch('greet').body).to.be('Hello there');
    }

    it 'resolves a lazy key in the request locale', {
      expect(dispatch('greet', query-string => 'locale=fr').body).to.be('Bonjour');
    }
  }

  context 'per-request locale', {
    it 'makes the request locale active during the action', {
      expect(dispatch('active-locale', query-string => 'locale=fr').body).to.be('fr');
    }

    it 'resets the locale to the default after the request', {
      my $backend = build-controller-backend;

      my $controller = LocaleDemoController.new(
        request      => MVC::Keayl::Request.new(query-string => 'locale=fr'),
        i18n         => $backend,
        i18n-options => { strategies => <param>, available => <en fr> },
      );

      $controller.dispatch('active-locale');

      expect($backend.locale).to.be('en');
    }
  }

  context 'generated URLs', {
    it 'carries the request locale through default-url-options', {
      expect(dispatch('url-locale', query-string => 'locale=fr').body).to.be('fr');
    }
  }

  context 'plain keys', {
    it 'resolves a plain key in the request locale', {
      expect(dispatch('farewell', query-string => 'locale=fr').body).to.be('Au revoir');
    }
  }
}
