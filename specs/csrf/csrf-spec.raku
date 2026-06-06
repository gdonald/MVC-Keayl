use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::CSRF;
use MVC::Keayl::Controller;
use MVC::Keayl::Request;
use MVC::Keayl::Parameters;

my class ProtectedController is MVC::Keayl::Controller {
  method create { self.render(:plain('created')) }
  method index  { self.render(:plain('listed')) }
}
ProtectedController.protect-from-forgery;

my class ResetController is MVC::Keayl::Controller {
  method create { self.render(:plain('proceeded')) }
}
ResetController.protect-from-forgery(with => 'reset-session');

my class ApiController is MVC::Keayl::Controller {
  method create { self.render(:plain('api ok')) }
}
ApiController.protect-from-forgery;
ApiController.skip-forgery-protection(only => ['create']);

sub posting($class, %params, *%request) {
  $class.new(
    secret  => 'k',
    request => MVC::Keayl::Request.new(method => 'POST', |%request),
    params  => MVC::Keayl::Parameters.new(%params),
  )
}

describe 'MVC::Keayl::CSRF tokens', {
  it 'masks a token differently each time', {
    my $real = generate-token();
    expect(mask-token($real) eq mask-token($real)).to.be-falsy;
  }

  it 'validates a masked token against its real token', {
    my $real = generate-token();
    expect(valid-token(mask-token($real), $real)).to.be-truthy;
  }

  it 'validates an unmasked token against itself', {
    my $real = generate-token();
    expect(valid-token($real, $real)).to.be-truthy;
  }

  it 'rejects a masked token from another real token', {
    my $real  = generate-token();
    my $other = generate-token();
    expect(valid-token(mask-token($other), $real)).to.be-falsy;
  }

  it 'rejects a malformed token', {
    expect(valid-token('garbage', generate-token())).to.be-falsy;
  }
}

describe 'MVC::Keayl::Controller forgery protection', {
  it 'runs the action on a POST with a valid token', {
    my $real = generate-token();
    my $controller = posting(ProtectedController, %( authenticity_token => mask-token($real) ));
    $controller.session<_csrf_token> = $real;
    expect($controller.dispatch('create').body).to.be('created');
  }

  it 'rejects a POST with an invalid token', {
    my $real = generate-token();
    my $controller = posting(ProtectedController, %( authenticity_token => mask-token(generate-token()) ));
    $controller.session<_csrf_token> = $real;
    expect($controller.dispatch('create').status).to.be(422);
  }

  it 'accepts a token from the X-CSRF-Token header', {
    my $real = generate-token();
    my $controller = ProtectedController.new(
      secret  => 'k',
      request => MVC::Keayl::Request.new(method => 'POST', headers => %( 'x-csrf-token' => mask-token($real) )),
    );
    $controller.session<_csrf_token> = $real;
    expect($controller.dispatch('create').body).to.be('created');
  }

  it 'does not check a safe verb', {
    my $controller = ProtectedController.new(
      secret  => 'k',
      request => MVC::Keayl::Request.new(method => 'GET'),
    );
    expect($controller.dispatch('index').body).to.be('listed');
  }
}

describe 'MVC::Keayl::Controller forgery strategies', {
  it 'lets the request proceed under the reset-session strategy', {
    my $real = generate-token();
    my $controller = posting(ResetController, %( authenticity_token => 'bad' ));
    $controller.session<_csrf_token> = $real;
    expect($controller.dispatch('create').body).to.be('proceeded');
  }

  it 'runs a skipped action without a token', {
    expect(posting(ApiController, %()).dispatch('create').body).to.be('api ok');
  }
}

describe 'MVC::Keayl::Controller csrf-token', {
  it 'returns a masked token for the session real token', {
    my $controller = ProtectedController.new(secret => 'k');
    my $masked = $controller.csrf-token;
    expect(valid-token($masked, $controller.session<_csrf_token>)).to.be-truthy;
  }
}
