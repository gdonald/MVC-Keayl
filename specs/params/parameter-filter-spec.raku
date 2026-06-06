use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::ParameterFilter;
use MVC::Keayl::Controller;
use MVC::Keayl::Parameters;

describe 'MVC::Keayl::ParameterFilter defaults', {
  it 'filters a password and keeps other values', {
    expect(MVC::Keayl::ParameterFilter.new.filter(%( password => 'secret', name => 'Ada' ))).to.be(%( password => '[FILTERED]', name => 'Ada' ));
  }

  it 'filters a token by substring match', {
    expect(MVC::Keayl::ParameterFilter.new.filter(%( api_token => 'abc' ))<api_token>).to.be('[FILTERED]');
  }

  it 'filters a default-sensitive key', {
    expect(MVC::Keayl::ParameterFilter.new.filter(%( ssn => '123' ))<ssn>).to.be('[FILTERED]');
  }
}

describe 'MVC::Keayl::ParameterFilter nesting', {
  it 'filters a nested sensitive parameter', {
    my %out = MVC::Keayl::ParameterFilter.new.filter(%( user => %( password => 'x', name => 'Ada' ) ));
    expect(%out<user><password>).to.be('[FILTERED]');
  }

  it 'keeps a nested non-sensitive parameter', {
    my %out = MVC::Keayl::ParameterFilter.new.filter(%( user => %( password => 'x', name => 'Ada' ) ));
    expect(%out<user><name>).to.be('Ada');
  }

  it 'filters a sensitive parameter inside an array', {
    my %out = MVC::Keayl::ParameterFilter.new.filter(%( accounts => [ %( secret => 'a' ), %( secret => 'b' ) ] ));
    expect(%out<accounts>[0]<secret>).to.be('[FILTERED]');
  }

  it 'redacts the whole value of a matched key', {
    expect(MVC::Keayl::ParameterFilter.new.filter(%( token => %( nested => 'x' ) ))<token>).to.be('[FILTERED]');
  }
}

describe 'MVC::Keayl::ParameterFilter configuration', {
  it 'honours an additional filter name', {
    expect(MVC::Keayl::ParameterFilter.new(also => ['pin']).filter(%( pin => '1234' ))<pin>).to.be('[FILTERED]');
  }

  it 'replaces the defaults with an explicit list', {
    expect(MVC::Keayl::ParameterFilter.new(filters => ['only-this']).filter(%( password => 'x' ))<password>).to.be('x');
  }

  it 'matches keys with a regex filter', {
    expect(MVC::Keayl::ParameterFilter.new(filters => [/^ card /]).filter(%( card_number => '4111' ))<card_number>).to.be('[FILTERED]');
  }
}

describe 'MVC::Keayl::ParameterFilter purity', {
  it 'does not mutate the original parameters', {
    my %original = %( password => 'secret' );
    MVC::Keayl::ParameterFilter.new.filter(%original);
    expect(%original<password>).to.be('secret');
  }
}

describe 'MVC::Keayl::Controller filtered-params', {
  it 'filters default and configured parameters', {
    my class WidgetController is MVC::Keayl::Controller {
    }
    WidgetController.filter-parameters('pin');

    my $controller = WidgetController.new(params => MVC::Keayl::Parameters.new(%( password => 'p', pin => '9', name => 'Ada' )));
    expect($controller.filtered-params).to.be(%( password => '[FILTERED]', pin => '[FILTERED]', name => 'Ada' ));
  }
}
