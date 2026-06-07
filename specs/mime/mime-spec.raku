use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Mime;

describe 'MVC::Keayl::Mime registry', {
  it 'maps a format to its MIME type', {
    expect(mime-type('json')).to.be('application/json');
  }

  it 'maps a MIME type back to its format', {
    expect(mime-format('text/html')).to.be('html');
  }

  it 'maps an aliased MIME type to its format', {
    expect(mime-format('application/javascript')).to.be('js');
  }

  it 'ignores MIME type parameters', {
    expect(mime-format('application/json; charset=utf-8')).to.be('json');
  }

  it 'resolves a registered custom type', {
    register-mime('msgpack', 'application/msgpack');
    expect(mime-format('application/msgpack')).to.be('msgpack');
  }
}

describe 'MVC::Keayl::Mime accept parsing', {
  it 'returns entries in order', {
    expect(parse-accept('text/html, application/json')).to.be(('text/html', 'application/json'));
  }

  it 'orders entries by quality', {
    expect(parse-accept('application/json;q=0.5, text/html;q=0.9')).to.be(('text/html', 'application/json'));
  }

  it 'puts the highest-quality type first', {
    expect(parse-accept('text/html, application/xml;q=0.9, */*;q=0.8')[0]).to.be('text/html');
  }
}

describe 'MVC::Keayl::Mime negotiation', {
  it 'picks the matching format', {
    expect(negotiate(['html', 'json'], 'application/json')).to.be('json');
  }

  it 'respects quality ordering', {
    expect(negotiate(['html', 'json'], 'application/json;q=0.4, text/html;q=0.8')).to.be('html');
  }

  it 'accepts the first available format for a wildcard', {
    expect(negotiate(['json', 'html'], '*/*')).to.be('json');
  }

  it 'matches a type wildcard by MIME prefix', {
    expect(negotiate(['json', 'html'], 'text/*')).to.be('html');
  }

  it 'returns nothing when no format matches', {
    expect(negotiate(['json'], 'text/html')).to.be(Str);
  }

  it 'falls back to the first available format without an accept header', {
    expect(negotiate(['html', 'json'], Str)).to.be('html');
  }
}
