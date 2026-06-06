use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Helpers::Tag;
use MVC::Keayl::Helpers::Url;
use MVC::Keayl::Helpers::Asset;
use MVC::Keayl::View;

sub view { MVC::Keayl::View.new(:paths(['specs/lib/views'])) }

describe 'MVC::Keayl tag building', {
  it 'builds an element with attributes', {
    expect(content-tag('p', 'hi', %( class => 'lead' )).Str).to.be('<p class="lead">hi</p>');
  }

  it 'escapes string content', {
    expect(content-tag('span', '<b>x</b>').Str).to.be('<span>&lt;b&gt;x&lt;/b&gt;</span>');
  }

  it 'renders a boolean attribute as a bare name and self-closes', {
    expect(tag('input', %( type => 'text', disabled => True, name => 'q' )).Str).to.be('<input disabled name="q" type="text" />');
  }

  it 'omits a false attribute', {
    expect(tag('input', %( type => 'text', disabled => False )).Str).to.be('<input type="text" />');
  }
}

describe 'MVC::Keayl url-for', {
  it 'passes a string path through', {
    expect(url-for('/posts')).to.be('/posts');
  }

  it 'reads a path from a hash', {
    expect(url-for({ path => '/x' })).to.be('/x');
  }
}

describe 'MVC::Keayl link-to', {
  it 'builds an anchor', {
    expect(link-to('Posts', '/posts').Str).to.be('<a href="/posts">Posts</a>');
  }

  it 'merges html options', {
    expect(link-to('Posts', '/posts', %( class => 'nav' )).Str).to.be('<a class="nav" href="/posts">Posts</a>');
  }

  it 'uses the body as the url when none is given', {
    expect(link-to('/only').Str).to.be('<a href="/only">/only</a>');
  }
}

describe 'MVC::Keayl button-to', {
  it 'adds a hidden method override for non-post verbs', {
    expect(button-to('Delete', '/posts/1', %( method => 'delete' )).Str.contains('name="_method" type="hidden" value="delete"')).to.be-truthy;
  }

  it 'posts to the url by default', {
    expect(button-to('Save', '/posts').Str.contains('<form action="/posts" method="post">')).to.be-truthy;
  }
}

describe 'MVC::Keayl asset-path', {
  it 'prefixes a bare source', {
    expect(asset-path('logo.png')).to.be('/assets/logo.png');
  }

  it 'leaves an absolute path alone', {
    expect(asset-path('/already/absolute.png')).to.be('/already/absolute.png');
  }

  it 'leaves an external url alone', {
    expect(asset-path('https://cdn/x.png')).to.be('https://cdn/x.png');
  }

  it 'adds a type extension when missing', {
    expect(asset-path('app', :type('css'))).to.be('/assets/app.css');
  }

  it 'honours a custom resolver', {
    my &resolver = -> $source, $type { 'https://cdn.example/' ~ $source };
    expect(asset-path('logo.png', :&resolver)).to.be('https://cdn.example/logo.png');
  }
}

describe 'MVC::Keayl asset tags', {
  it 'builds an img with a resolved src', {
    expect(image-tag('logo.png', %( alt => 'Logo' )).Str).to.be('<img alt="Logo" src="/assets/logo.png" />');
  }

  it 'derives a default alt from the filename', {
    expect(image-tag('my_logo.png').Str).to.be('<img alt="My Logo" src="/assets/my_logo.png" />');
  }

  it 'links a css asset', {
    expect(stylesheet-link-tag('app').Str).to.be('<link href="/assets/app.css" rel="stylesheet" />');
  }

  it 'includes a js asset', {
    expect(javascript-include-tag('app').Str).to.be('<script src="/assets/app.js"></script>');
  }
}

describe 'MVC::Keayl helper template integration', {
  it 'emits a link through the link_to helper', {
    expect(view.render-template('greetings/helpers', {}).contains('<a href="/">Home</a>')).to.be-truthy;
  }

  it 'emits an image through the image_tag helper', {
    expect(view.render-template('greetings/helpers', {}).contains('<img alt="Logo" src="/assets/logo.png" />')).to.be-truthy;
  }
}
