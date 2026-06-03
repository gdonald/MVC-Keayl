use BDD::Behave;
use MVC::Keayl::Routing::PathPattern;

sub pattern(Str $source, *%opts) {
  MVC::Keayl::Routing::PathPattern.new(:$source, |%opts)
}

describe 'MVC::Keayl path pattern static paths', {
  let(:p, { pattern('/users') });

  it 'matches with no params', {
    expect(p.match('/users').elems).to.be(0);
  }

  it 'does not match a longer path', {
    expect(p.match('/users/1').defined).to.be-falsy;
  }
}

describe 'MVC::Keayl path pattern dynamic segments', {
  it 'captures a segment value', {
    expect(pattern('/users/:id').match('/users/42')<id>).to.be('42');
  }

  it 'fails when a dynamic segment is missing', {
    expect(pattern('/users/:id').match('/users').defined).to.be-falsy;
  }

  it 'captures a segment between static parts', {
    expect(pattern('/users/:id/edit').match('/users/7/edit')<id>).to.be('7');
  }

  it 'does not span a slash', {
    expect(pattern('/users/:id').match('/users/1/2').defined).to.be-falsy;
  }

  context 'with multiple segments', {
    let(:params, { pattern('/:controller/:action').match('/posts/show') });

    it 'captures the first segment', {
      expect(params<controller>).to.be('posts');
    }

    it 'captures the second segment', {
      expect(params<action>).to.be('show');
    }
  }
}

describe 'MVC::Keayl path pattern glob segments', {
  it 'captures the rest of the path including slashes', {
    expect(pattern('/files/*path').match('/files/a/b/c.txt')<path>).to.be('a/b/c.txt');
  }
}

describe 'MVC::Keayl path pattern optional segments', {
  let(:p, { pattern('/users(/:id)') });

  it 'captures an optional segment when present', {
    expect(p.match('/users/9')<id>).to.be('9');
  }

  it 'is empty when the optional segment is omitted', {
    expect(p.match('/users').elems).to.be(0);
  }
}

describe 'MVC::Keayl path pattern format segment', {
  let(:p, { pattern('/users/:id(.:format)') });

  it 'captures the id ahead of the format', {
    expect(p.match('/users/3.json')<id>).to.be('3');
  }

  it 'captures the format extension', {
    expect(p.match('/users/3.json')<format>).to.be('json');
  }

  it 'leaves the format optional', {
    expect(p.match('/users/3')<id>).to.be('3');
  }

  it 'has no format without an extension', {
    expect(p.match('/users/3')<format>.defined).to.be-falsy;
  }

  context 'with format true', {
    let(:p, { pattern('/users/:id', :format) });

    it 'appends an optional format segment', {
      expect(p.match('/users/3.xml')<format>).to.be('xml');
    }
  }
}

describe 'MVC::Keayl path pattern defaults', {
  let(:p, { pattern('/users/:id(.:format)', :defaults({ format => 'html' })) });

  it 'fills an absent optional segment from the default', {
    expect(p.match('/users/3')<format>).to.be('html');
  }

  it 'lets a present segment override the default', {
    expect(p.match('/users/3.json')<format>).to.be('json');
  }
}

describe 'MVC::Keayl path pattern constraints', {
  let(:p, { pattern('/users/:id', :constraints({ id => /^\d+$/ })) });

  it 'captures a segment matching its constraint', {
    expect(p.match('/users/42')<id>).to.be('42');
  }

  it 'fails a segment that breaks its constraint', {
    expect(p.match('/users/abc').defined).to.be-falsy;
  }
}
