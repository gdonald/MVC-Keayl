use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::I18n;
use I18nFixtures;

describe 'MVC::Keayl::I18n translation backend', {
  let(:backend, { build-backend });

  context 'loading and lookup', {
    it 'loads YAML locale files and looks up a key', {
      expect(backend.translate('hello')).to.be('Hello world');
    }

    it 'loads JSON locale files', {
      expect(backend.translate('hello', locale => 'fr')).to.be('Bonjour le monde');
    }

    it 'looks up a dotted key', {
      expect(backend.translate('messages.welcome', name => 'Greg')).to.be('Welcome, Greg');
    }
  }

  context 'with a configured default locale', {
    let(:backend, { build-backend(default-locale => 'fr') });

    it 'uses the configured default locale', {
      expect(backend.translate('hello')).to.be('Bonjour le monde');
    }
  }

  context 'interpolation', {
    it 'interpolates a named placeholder', {
      expect(backend.translate('greeting', name => 'Ada')).to.be('Hello Ada');
    }

    context 'when raise-on-missing is set', {
      let(:backend, { build-backend(raise-on-missing => True) });

      it 'raises when an interpolation argument is missing', {
        expect({ backend.translate('greeting') }).to.throw(X::MVC::Keayl::I18n::MissingInterpolation);
      }
    }
  }

  context 'pluralization', {
    it 'selects the one category', {
      expect(backend.translate('apples', count => 1)).to.be('one apple');
    }

    it 'selects the other category and interpolates count', {
      expect(backend.translate('apples', count => 5)).to.be('5 apples');
    }

    it 'prefers the zero category at zero', {
      expect(backend.translate('apples', count => 0)).to.be('no apples');
    }

    it 'treats one as singular in French', {
      expect(backend.translate('apples', count => 1, locale => 'fr')).to.be('1 pomme');
    }

    it 'treats zero as singular in French', {
      expect(backend.translate('apples', count => 0, locale => 'fr')).to.be('0 pomme');
    }

    it 'selects the few category in Russian', {
      expect(backend.translate('apples', count => 2, locale => 'ru')).to.be('2 яблока');
    }

    it 'selects the many category in Russian', {
      expect(backend.translate('apples', count => 5, locale => 'ru')).to.be('5 яблок');
    }

    it 'selects the one category in Russian', {
      expect(backend.translate('apples', count => 1, locale => 'ru')).to.be('1 яблоко');
    }
  }

  context 'missing translations', {
    it 'returns a placeholder for a missing translation', {
      expect(backend.translate('does.not.exist')).to.be('translation missing: en.does.not.exist');
    }

    context 'when raise-on-missing is set', {
      let(:backend, { build-backend(raise-on-missing => True) });

      it 'raises for a missing translation', {
        expect({ backend.translate('does.not.exist') }).to.throw(X::MVC::Keayl::I18n::MissingTranslation);
      }
    }
  }

  context 'defaults and fallback chains', {
    it 'uses a literal default when the key is missing', {
      expect(backend.translate('absent', default => 'Fallback text')).to.be('Fallback text');
    }

    it 'walks a default chain to the first translation that resolves', {
      expect(backend.translate('absent', default => ['also.absent', 'hello'])).to.be('Hello world');
    }

    it 'falls through a default chain to a literal', {
      expect(backend.translate('absent', default => ['also.absent', 'Plain text'])).to.be('Plain text');
    }
  }

  context 'locale fallback', {
    it 'resolves a region locale directly', {
      expect(backend.translate('elevator', locale => 'en-CA')).to.be('lift');
    }

    it 'falls back from en-CA to en', {
      expect(backend.translate('hello', locale => 'en-CA')).to.be('Hello world');
    }

    context 'when fallback is disabled', {
      let(:backend, { build-backend(use-fallbacks => False) });

      it 'skips locale fallback', {
        expect(backend.translate('hello', locale => 'en-CA')).to.be('translation missing: en-CA.hello');
      }
    }
  }

  context 'locale state', {
    it 'honours the set locale', {
      backend.set-locale('fr');
      expect(backend.translate('hello')).to.be('Bonjour le monde');
    }

    it 'applies with-locale inside the block', {
      expect(backend.with-locale('fr', { backend.translate('hello') })).to.be('Bonjour le monde');
    }

    it 'resets the locale after the with-locale block', {
      backend.with-locale('fr', { backend.translate('hello') });
      expect(backend.translate('hello')).to.be('Hello world');
    }

    it 'reports the loaded locales', {
      expect(backend.available-locales).to.be(('en', 'en-CA', 'fr', 'ru'));
    }
  }
}
