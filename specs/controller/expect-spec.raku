use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Parameters;
use MVC::Keayl::Params;
use MVC::Keayl::Request;
use MVC::Keayl::Controller;
use ControllerFixtures;

sub params(%store) {
  MVC::Keayl::Parameters.new(%store)
}

describe 'MVC::Keayl::Parameters expect of a hash', {
  it 'returns the permitted nested keys', {
    expect(params({ user => { name => 'Ada', email => 'a@b', admin => True } }).expect(user => <name email>).Hash.keys.sort.join(',')).to.be('email,name');
  }

  it 'raises when the key is missing', {
    expect({ params({}).expect(user => <name email>) }).to.throw;
  }

  it 'raises when the value is the wrong shape', {
    expect({ params({ user => 'scalar' }).expect(user => <name email>) }).to.throw;
  }
}

describe 'MVC::Keayl::Parameters expect of an array', {
  it 'returns an array of scalars', {
    expect(params({ ids => ['1', '2'] }).expect(ids => []).join(',')).to.be('1,2');
  }

  it 'raises when an array is expected but a scalar is given', {
    expect({ params({ ids => 'one' }).expect(ids => []) }).to.throw;
  }

  it 'returns an array of permitted hashes', {
    my $permitted = MVC::Keayl::Parameters.new(parse-urlencoded('rows[][id]=1&rows[][secret]=x')).expect(rows => <id>);
    expect($permitted[0].keys.join(',')).to.be('id');
  }
}

describe 'MVC::Keayl::Parameters expect of a scalar', {
  it 'returns the scalar value', {
    expect(params({ id => '7' }).expect('id')).to.be('7');
  }

  it 'raises when the scalar is missing', {
    expect({ params({}).expect('id') }).to.throw;
  }
}

describe 'MVC::Keayl::Controller expect', {
  it 'returns 400 for a malformed payload', {
    my $request = MVC::Keayl::Request.new(
      :method<POST>,
      :headers({ 'Content-Type' => 'application/x-www-form-urlencoded' }),
      :body('user=scalar'),
    );
    my $controller = ExpectController.new(:params(build-params({}, $request)));
    expect($controller.dispatch('create').status).to.be(400);
  }

  it 'permits the expected keys on a valid payload', {
    my $request = MVC::Keayl::Request.new(
      :method<POST>,
      :headers({ 'Content-Type' => 'application/x-www-form-urlencoded' }),
      :body('user[name]=Ada&user[admin]=1'),
    );
    my $controller = ExpectController.new(:params(build-params({}, $request)));
    expect($controller.dispatch('create').body).to.be('Ada:no-admin');
  }
}
