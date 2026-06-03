use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Adapter::Test;
use MVC::Keayl::MiddlewareStack;
use MVC::Keayl::Request;
use ServerFixtures;
use MiddlewareFixtures;

describe 'MVC::Keayl::Adapter::Test request', {
  let(:adapter, { MVC::Keayl::Adapter::Test.new(:app(EchoEndpoint.new)) });

  it 'dispatches with the given method', {
    expect(adapter.request('POST', '/users?q=1').header('X-Method')).to.be('POST');
  }

  it 'passes the target path to the endpoint', {
    expect(adapter.request('POST', '/users?q=1').header('X-Path')).to.be('/users');
  }

  it 'passes the query string to the endpoint', {
    expect(adapter.request('POST', '/users?q=1').header('X-Query')).to.be('q=1');
  }

  it 'passes the body to the endpoint', {
    expect(adapter.request('POST', '/x', :body('payload')).body).to.be('payload');
  }

  it 'passes request headers to the endpoint', {
    expect(adapter.request('GET', '/x', :headers({ Host => 'ex.com' })).header('X-Host')).to.be('ex.com');
  }

  it 'passes the remote address to the endpoint', {
    expect(adapter.request('GET', '/x', :remote-address('9.9.9.9')).header('X-Remote-IP')).to.be('9.9.9.9');
  }
}

describe 'MVC::Keayl::Adapter::Test verb helpers', {
  let(:adapter, { MVC::Keayl::Adapter::Test.new(:app(EchoEndpoint.new)) });

  my %verbs =
    GET    => 'get',
    POST   => 'post',
    PUT    => 'put',
    PATCH  => 'patch',
    DELETE => 'delete',
    HEAD   => 'head';

  for %verbs.kv -> $verb, $helper {
    it "the $helper helper dispatches a $verb", {
      expect(adapter."$helper"('/x').header('X-Method')).to.be($verb);
    }
  }
}

describe 'MVC::Keayl::Adapter::Test middleware integration', {
  let(:adapter, {
    my $stack = MVC::Keayl::MiddlewareStack.new;
    $stack.use('w', WrapMiddleware, :tag('W'));
    MVC::Keayl::Adapter::Test.new(:app($stack.build(AppEndpoint.new)))
  });

  it 'drives the full middleware stack', {
    expect(adapter.get('/').body).to.be('W(app)');
  }
}

describe 'MVC::Keayl::Adapter::Test handle', {
  let(:adapter, { MVC::Keayl::Adapter::Test.new(:app(AppEndpoint.new)) });

  it 'returns the status', {
    expect(adapter.handle(MVC::Keayl::Request.new(:target('/')))[0]).to.be(200);
  }

  it 'returns the body as a Blob', {
    expect(adapter.handle(MVC::Keayl::Request.new(:target('/')))[2] ~~ Blob).to.be-truthy;
  }

  it 'returns the rendered body', {
    expect(adapter.handle(MVC::Keayl::Request.new(:target('/')))[2].decode('utf-8')).to.be('app');
  }
}
