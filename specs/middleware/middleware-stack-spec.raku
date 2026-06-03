use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::MiddlewareStack;
use MVC::Keayl::Request;
use MiddlewareFixtures;

sub call-body($stack) {
  $stack.build(AppEndpoint.new).call(MVC::Keayl::Request.new).body
}

describe 'MVC::Keayl::Middleware protocol', {
  it 'wraps the downstream app and post-processes its response', {
    my $app = WrapMiddleware.new(:app(AppEndpoint.new), :tag('A'));
    expect($app.call(MVC::Keayl::Request.new).body).to.be('A(app)');
  }

  it 'may short-circuit without calling the downstream app', {
    my $app = HaltMiddleware.new(:app(AppEndpoint.new), :status(418));
    expect($app.call(MVC::Keayl::Request.new).status).to.be(418);
  }
}

describe 'MVC::Keayl::MiddlewareStack building', {
  context 'with two middlewares', {
    let(:stack, {
      my $s = MVC::Keayl::MiddlewareStack.new;
      $s.use('a', WrapMiddleware, :tag('A'));
      $s.use('b', WrapMiddleware, :tag('B'));
      $s
    });

    it 'makes the first middleware added the outermost', {
      expect(call-body(stack)).to.be('A(B(app))');
    }
  }

  context 'with an empty stack', {
    let(:stack, { MVC::Keayl::MiddlewareStack.new });

    it 'returns the endpoint unwrapped', {
      expect(call-body(stack)).to.be('app');
    }
  }
}

describe 'MVC::Keayl::MiddlewareStack introspection', {
  let(:stack, {
    my $s = MVC::Keayl::MiddlewareStack.new;
    $s.use('a', WrapMiddleware, :tag('A'));
    $s.use('b', WrapMiddleware, :tag('B'));
    $s
  });

  it 'lists entries in order', {
    expect(stack.names.join(',')).to.be('a,b');
  }

  it 'counts the entries', {
    expect(stack.elems).to.be(2);
  }

  it 'is true for a present entry', {
    expect(stack.contains('a')).to.be-truthy;
  }

  it 'is false for an absent entry', {
    expect(stack.contains('missing')).to.be-falsy;
  }
}

describe 'MVC::Keayl::MiddlewareStack insert-before', {
  let(:stack, {
    my $s = MVC::Keayl::MiddlewareStack.new;
    $s.use('a', WrapMiddleware, :tag('A'));
    $s.use('b', WrapMiddleware, :tag('B'));
    $s
  });

  it 'places the entry ahead of the target', {
    stack.insert-before('b', 'x', WrapMiddleware, :tag('X'));
    expect(stack.names.join(',')).to.be('a,x,b');
  }

  it 'nests the new middleware in order', {
    stack.insert-before('b', 'x', WrapMiddleware, :tag('X'));
    expect(call-body(stack)).to.be('A(X(B(app)))');
  }

  it 'raises for an unknown target', {
    expect({ stack.insert-before('missing', 'x', WrapMiddleware, :tag('X')) }).to.throw;
  }
}

describe 'MVC::Keayl::MiddlewareStack insert-after', {
  let(:stack, {
    my $s = MVC::Keayl::MiddlewareStack.new;
    $s.use('a', WrapMiddleware, :tag('A'));
    $s.use('b', WrapMiddleware, :tag('B'));
    $s
  });

  it 'places the entry behind the target', {
    stack.insert-after('a', 'x', WrapMiddleware, :tag('X'));
    expect(stack.names.join(',')).to.be('a,x,b');
  }

  it 'raises for an unknown target', {
    expect({ stack.insert-after('missing', 'x', WrapMiddleware, :tag('X')) }).to.throw;
  }
}

describe 'MVC::Keayl::MiddlewareStack delete', {
  let(:stack, {
    my $s = MVC::Keayl::MiddlewareStack.new;
    $s.use('a', WrapMiddleware, :tag('A'));
    $s.use('b', WrapMiddleware, :tag('B'));
    $s
  });

  it 'removes the named entry', {
    stack.delete('a');
    expect(stack.names.join(',')).to.be('b');
  }

  it 'drops the middleware from the built chain', {
    stack.delete('a');
    expect(call-body(stack)).to.be('B(app)');
  }
}
