use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::I18n;
use I18nFixtures;

sub a-date     { Date.new(2020, 2, 5) }
sub a-datetime { DateTime.new(:2020year, :2month, :5day, :14hour, :30minute, :0second) }

describe 'MVC::Keayl::I18n localization', {
  let(:backend, { build-backend });

  context 'dates and times', {
    it 'localizes a date with the default format', {
      expect(backend.localize(a-date)).to.be('2020-02-05');
    }

    it 'localizes a date with month names', {
      expect(backend.localize(a-date, format => 'long')).to.be('February 05, 2020');
    }

    it 'localizes a date against another locale format', {
      expect(backend.localize(a-date, locale => 'ru')).to.be('05.02.2020');
    }

    it 'localizes a time with the default format', {
      expect(backend.localize(a-datetime)).to.be('14:30:00');
    }

    it 'localizes a time with the meridian', {
      expect(backend.localize(a-datetime, format => 'short')).to.be('02:30 pm');
    }

    it 'aliases localize as l', {
      expect(backend.l(a-date)).to.be('2020-02-05');
    }
  }

  context 'numbers driven by the store', {
    it 'delimits a number using locale defaults', {
      expect(backend.number-to-delimited(1234567.5)).to.be('1,234,567.5');
    }

    it 'uses the locale delimiter', {
      expect(backend.number-to-delimited(1234567, locale => 'ru')).to.be('1 234 567');
    }

    it 'formats currency using locale defaults', {
      expect(backend.number-to-currency(1234.5)).to.be('$1,234.50');
    }

    it 'formats currency for another locale', {
      expect(backend.number-to-currency(1234.5, locale => 'ru')).to.be('1 234,50 ₽');
    }

    it 'formats a percentage using locale precision', {
      expect(backend.number-to-percentage(66.666)).to.be('66.7%');
    }

    it 'formats a human-readable size', {
      expect(backend.number-to-human-size(1536)).to.be('1.5 KB');
    }

    it 'localizes a bare number', {
      expect(backend.localize(1234.5, locale => 'ru')).to.be('1 234,5');
    }
  }
}
