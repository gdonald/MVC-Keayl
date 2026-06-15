use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Params;
use MVC::Keayl::Request;
use MVC::Keayl::Controller;
use ControllerFixtures;

sub json-request($body, :$content-type = 'application/json') {
  MVC::Keayl::Request.new(
    :method<POST>,
    :headers({ 'Content-Type' => $content-type }),
    :body($body),
  )
}

sub dispatch($controller-class, $request) {
  $controller-class.new(:request($request), :params(build-params({}, $request))).dispatch('create')
}

describe 'MVC::Keayl::Controller wrap-parameters', {
  it 'wraps a top-level JSON body under the controller key', {
    expect(dispatch(WidgetsController, json-request('{"name":"Gear","color":"red"}')).body).to.be('Gear:red');
  }

  it 'leaves an existing root key untouched', {
    expect(dispatch(WidgetsController, json-request('{"widget":{"name":"Set"},"name":"Loose"}')).body).to.be('Set:none');
  }

  it 'does not wrap a non-JSON request', {
    expect(dispatch(WidgetsController, json-request('name=Gear', content-type => 'application/x-www-form-urlencoded')).body).to.be('none:none');
  }

  it 'wraps under an explicit key', {
    expect(dispatch(ParcelsController, json-request('{"name":"Crate"}')).body).to.be('Crate');
  }
}

describe 'MVC::Keayl::Controller wrap-parameters attribute selection', {
  it 'keeps only the included attributes', {
    expect(dispatch(GadgetsController, json-request('{"name":"Phone","secret":"hush"}')).body).to.be('Phone:none');
  }

  it 'drops the excluded attributes', {
    expect(dispatch(TrinketsController, json-request('{"name":"Bead","secret":"hush"}')).body).to.be('Bead:none');
  }
}
