use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Helpers::Tag;

describe 'MVC::Keayl tag attributes', {
  it 'renders a true attribute as a bare name', {
    expect(tag('input', %( type => 'text', checked => True, name => 'q' )).Str).to.be('<input checked name="q" type="text" />');
  }

  it 'omits a false attribute', {
    expect(tag('input', %( type => 'text', checked => False )).Str).to.be('<input type="text" />');
  }
}

describe 'MVC::Keayl nested attributes', {
  it 'expands a data hash to dasherized data attributes', {
    expect(content-tag('div', 'x', %( data => %( user_id => 5, toggle => 'modal' ) )).Str).to.be('<div data-toggle="modal" data-user-id="5">x</div>');
  }

  it 'expands an aria hash to aria attributes', {
    expect(content-tag('button', 'Go', %( aria => %( label => 'Go', expanded => 'false' ) )).Str).to.be('<button aria-expanded="false" aria-label="Go">Go</button>');
  }

  it 'json encodes a structured data value', {
    expect(content-tag('div', 'x', %( data => %( ids => [1, 2] ) )).Str.contains('data-ids="[1,2]"')).to.be-truthy;
  }
}

describe 'MVC::Keayl class attribute', {
  it 'joins a class array into a class attribute', {
    expect(tag('span', %( class => ['a', 'b'] )).Str).to.be('<span class="a b" />');
  }

  it 'keeps the class keys whose conditions are true', {
    expect(content-tag('div', 'x', %( class => %( active => True, off => False ) )).Str).to.be('<div class="active">x</div>');
  }

  it 'omits an empty class attribute', {
    expect(tag('span', %( class => %( off => False ) )).Str).to.be('<span />');
  }
}

describe 'MVC::Keayl class-names', {
  it 'joins string tokens', {
    expect(class-names('btn', 'btn-primary')).to.be('btn btn-primary');
  }

  it 'applies conditional tokens', {
    expect(class-names('btn', %( active => True, disabled => False ))).to.be('btn active');
  }

  it 'removes duplicates', {
    expect(class-names('a', 'a', 'b')).to.be('a b');
  }

  it 'flattens nested token lists', {
    expect(class-names(['a', 'b'], 'c')).to.be('a b c');
  }
}

describe 'MVC::Keayl data-attributes', {
  it 'builds dasherized data keys', {
    expect(data-attributes(%( user_id => 1 ))).to.be(%( 'data-user-id' => 1 ));
  }
}
