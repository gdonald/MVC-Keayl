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

describe 'MVC::Keayl::Parameters require', {
  it 'returns a Parameters for a nested value', {
    expect(params({ user => { name => 'Ada' } }).require('user') ~~ MVC::Keayl::Parameters).to.be-truthy;
  }

  it 'exposes the nested value', {
    expect(params({ user => { name => 'Ada' } }).require('user')<name>).to.be('Ada');
  }

  it 'returns a scalar value directly', {
    expect(params({ id => '5' }).require('id')).to.be('5');
  }

  it 'raises when the key is absent', {
    expect({ params({}).require('user') }).to.throw;
  }

  it 'raises when the value is empty', {
    expect({ params({ user => '' }).require('user') }).to.throw;
  }
}

describe 'MVC::Keayl::Parameters permit', {
  it 'keeps only the listed scalar keys', {
    expect(params({ name => 'Ada', email => 'a@b', admin => True }).permit('name', 'email').Hash.keys.sort.join(',')).to.be('email,name');
  }

  it 'drops a hash value listed as a scalar', {
    expect(params({ name => 'Ada', role => { admin => True } }).permit('name', 'role')<role>.defined).to.be-falsy;
  }

  it 'allows an array of scalars with an empty-array spec', {
    expect(params({ roles => ['a', 'b'] }).permit(roles => [])<roles>.join(',')).to.be('a,b');
  }

  it 'allows a nested hash with the listed keys', {
    expect(params({ address => { street => '1 Main', secret => 'z' } }).permit(address => <street>)<address>.keys.join(',')).to.be('street');
  }

  it 'allows an array of hashes', {
    my $permitted = MVC::Keayl::Parameters.new(parse-urlencoded('items[][name]=a&items[][qty]=1')).permit(items => <name>);
    expect($permitted<items>[0].keys.join(',')).to.be('name');
  }

  it 'reports a permitted Parameters as permitted', {
    expect(params({ name => 'Ada' }).permit('name').is-permitted).to.be-truthy;
  }
}

describe 'MVC::Keayl::Parameters permit-all', {
  let(:everything, { params({ a => 1, b => 2 }).permit-all });

  it 'marks the parameters permitted', {
    expect(everything.is-permitted).to.be-truthy;
  }

  it 'keeps every key', {
    expect(everything.keys.sort.join(',')).to.be('a,b');
  }
}

describe 'MVC::Keayl::Parameters unpermitted handling', {
  it 'drops unpermitted keys silently in log mode', {
    expect(params({ name => 'x', danger => 'y' }).permit('name', :on-unpermitted<log>).Hash.keys.join(',')).to.be('name');
  }

  it 'raises an unpermitted key in raise mode', {
    expect({ params({ name => 'x', danger => 'y' }).permit('name', :on-unpermitted<raise>) }).to.throw;
  }

  it 'defaults the unpermitted action to log', {
    expect(MVC::Keayl::Parameters.unpermitted-action).to.be('log');
  }
}

describe 'MVC::Keayl::Controller strong params', {
  it 'permits the request params and drops the rest', {
    my $request = MVC::Keayl::Request.new(
      :method<POST>,
      :headers({ 'Content-Type' => 'application/x-www-form-urlencoded' }),
      :body('user[name]=Ada&user[admin]=1'),
    );
    my $controller = StrongController.new(:params(build-params({}, $request)));
    expect($controller.dispatch('create').body).to.be('Ada:no-admin');
  }
}
