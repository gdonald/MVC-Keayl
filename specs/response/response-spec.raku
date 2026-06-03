use BDD::Behave;
use MVC::Keayl::Response;

sub pairs-named(@pairs, Str $name) {
  @pairs.grep(*.key.lc eq $name.lc)
}

describe 'MVC::Keayl::Response status', {
  let(:res, { MVC::Keayl::Response.new });

  it 'defaults to 200', {
    expect(res.status).to.be(200);
  }

  it 'is writable', {
    res.status = 404;
    expect(res.status).to.be(404);
  }

  context 'with a status set at construction', {
    let(:res, { MVC::Keayl::Response.new(:status(201)) });

    it 'can be set at construction', {
      expect(res.status).to.be(201);
    }
  }
}

describe 'MVC::Keayl::Response construction', {
  let(:res, { MVC::Keayl::Response.new(:headers({ 'X-Foo' => 'bar' }), :body('hello')) });

  it 'stores constructor headers', {
    expect(res.header('x-foo')).to.be('bar');
  }

  it 'stores the constructor body', {
    expect(res.body).to.be('hello');
  }
}

describe 'MVC::Keayl::Response headers', {
  let(:res, { MVC::Keayl::Response.new });

  it 'looks up headers case-insensitively', {
    res.set-header('Content-Type', 'text/plain');
    expect(res.header('CONTENT-TYPE')).to.be('text/plain');
  }

  it 'reports a present header', {
    res.set-header('X-A', '1');
    expect(res.has-header('x-a')).to.be-truthy;
  }

  it 'reports an absent header as missing', {
    expect(res.has-header('x-missing')).to.be-falsy;
  }

  it 'removes a header with delete-header', {
    res.set-header('X-A', '1');
    res.delete-header('X-A');
    expect(res.has-header('x-a')).to.be-falsy;
  }

  it 'replaces an existing value with set-header', {
    res.set-header('X-A', 'first');
    res.set-header('X-A', 'second');
    expect(res.header('x-a')).to.be('second');
  }

  it 'accumulates values with add-header', {
    res.add-header('Set-Cookie', 'a=1');
    res.add-header('Set-Cookie', 'b=2');
    expect(res.header('set-cookie')).to.be('a=1, b=2');
  }

  it 'returns display names from headers', {
    res.set-header('X-One', '1');
    expect(res.headers<X-One>).to.be('1');
  }
}

describe 'MVC::Keayl::Response convenience accessors', {
  let(:res, { MVC::Keayl::Response.new });

  it 'has an undefined content-type until set', {
    expect(res.content-type.defined).to.be-falsy;
  }

  it 'reflects the content-type setter', {
    res.content-type('application/json');
    expect(res.content-type).to.be('application/json');
  }

  it 'writes the Content-Type header through content-type', {
    res.content-type('application/json');
    expect(res.header('content-type')).to.be('application/json');
  }

  it 'reflects the location setter', {
    res.location('/users/1');
    expect(res.location).to.be('/users/1');
  }
}

describe 'MVC::Keayl::Response content-length', {
  let(:res, { MVC::Keayl::Response.new(:body('héllo')) });

  it 'counts utf-8 bytes, not characters', {
    expect(res.content-length).to.be(6);
  }
}

describe 'MVC::Keayl::Response body buffering', {
  let(:res, { MVC::Keayl::Response.new });

  it 'appends to the buffer with write', {
    res.write('foo');
    res.write('bar');
    expect(res.body).to.be('foobar');
  }

  it 'replaces the buffer with the body setter', {
    res.write('foo');
    res.body('replaced');
    expect(res.body).to.be('replaced');
  }
}

describe 'MVC::Keayl::Response finish', {
  context 'with a status and body', {
    let(:res, { MVC::Keayl::Response.new(:status(201), :body('hi')) });

    it 'returns the status as the first element', {
      expect(res.finish[0]).to.be(201);
    }
  }

  context 'with a simple body', {
    let(:res, { MVC::Keayl::Response.new(:body('hi')) });

    it 'returns the body as a Blob', {
      expect(res.finish[2] ~~ Blob).to.be-truthy;
    }

    it 'holds the buffered content in the finished body', {
      expect(res.finish[2].decode('utf-8')).to.be('hi');
    }

    it 'supplies a default Content-Type', {
      expect(pairs-named(res.finish[1].list, 'Content-Type').head.value).to.be('text/html; charset=utf-8');
    }
  }

  context 'with a multibyte body', {
    let(:res, { MVC::Keayl::Response.new(:body('héllo')) });

    it 'sets Content-Length to the body byte count', {
      expect(pairs-named(res.finish[1].list, 'Content-Length').head.value).to.be('6');
    }
  }

  context 'with an explicit Content-Type', {
    let(:res, {
      my $r = MVC::Keayl::Response.new(:body('{}'));
      $r.content-type('application/json');
      $r
    });

    it 'preserves an explicit Content-Type', {
      expect(pairs-named(res.finish[1].list, 'Content-Type').head.value).to.be('application/json');
    }
  }

  context 'with multi-value headers', {
    let(:res, {
      my $r = MVC::Keayl::Response.new;
      $r.add-header('Set-Cookie', 'a=1');
      $r.add-header('Set-Cookie', 'b=2');
      $r
    });

    it 'emits one pair per value for multi-value headers', {
      expect(pairs-named(res.finish[1].list, 'Set-Cookie').elems).to.be(2);
    }
  }
}
