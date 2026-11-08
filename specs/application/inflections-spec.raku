use BDD::Behave;
use MVC::Keayl::Application;
use Text::Inflector;

my $app = MVC::Keayl::Application.new;
$app.initializer('inflections', -> $a { Text::Inflector.inflections: { .irregular('cow', 'kine') } });
$app.boot;

describe 'MVC::Keayl::Application inflection rules', {
  it 'applies the rules an initializer registers', {
    expect(Text::Inflector.pluralize('cow')).to.be('kine');
  }

  it 'freezes the rules at boot', {
    expect(Text::Inflector.is-frozen).to.be(True);
  }

  it 'refuses new rules after boot', {
    expect({ Text::Inflector.inflections: { .uncountable('aircraft') } }).to.raise-error(/'frozen'/);
  }
}
