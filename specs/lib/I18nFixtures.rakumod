use v6.d;
use MVC::Keayl::I18n;
use MVC::Keayl::Controller;

unit module I18nFixtures;

sub locales-dir(--> IO::Path) is export {
  'specs/lib/fixtures/locales'.IO
}

sub build-backend(*%options --> MVC::Keayl::I18n) is export {
  my $backend = MVC::Keayl::I18n.new(|%options);
  $backend.load-locales(locales-dir);
  $backend
}

sub build-controller-backend(--> MVC::Keayl::I18n) is export {
  my $backend = MVC::Keayl::I18n.new(default-locale => 'en', available-locales => <en fr>);

  $backend.store-translations('en', {
    i18n_fixtures => { locale_demo => { greet => { greeting => 'Hello there' } } },
    farewell      => 'Goodbye',
  });

  $backend.store-translations('fr', {
    i18n_fixtures => { locale_demo => { greet => { greeting => 'Bonjour' } } },
    farewell      => 'Au revoir',
  });

  $backend
}

class LocaleDemoController is MVC::Keayl::Controller is export {
  method greet {
    self.render(plain => self.t('.greeting'));
  }

  method farewell {
    self.render(plain => self.t('farewell'));
  }

  method active-locale {
    self.render(plain => self.i18n.locale);
  }

  method url-locale {
    self.render(plain => self.default-url-options<locale> // 'none');
  }
}
