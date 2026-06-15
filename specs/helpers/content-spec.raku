use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Helpers::Text;
use MVC::Keayl::Helpers::Tag;

describe 'MVC::Keayl highlight', {
  it 'wraps a phrase in a mark element', {
    expect(highlight('You searched for rails', 'rails').Str).to.be('You searched for <mark>rails</mark>');
  }

  it 'matches case-insensitively and keeps the original text', {
    expect(highlight('rails RAILS', 'rails').Str).to.be('<mark>rails</mark> <mark>RAILS</mark>');
  }

  it 'honours a custom highlighter', {
    expect(highlight('use rails', 'rails', highlighter => '<em>\1</em>').Str).to.be('use <em>rails</em>');
  }

  it 'escapes the text it wraps', {
    expect(highlight('a < b rails', 'rails').Str).to.be('a &lt; b <mark>rails</mark>');
  }
}

describe 'MVC::Keayl excerpt', {
  it 'extracts text around a phrase with omission markers', {
    expect(excerpt('This is a beautiful morning', 'beautiful', radius => 5)).to.be('...is a beautiful morn...');
  }

  it 'returns empty when the phrase is absent', {
    expect(excerpt('This is a beautiful morning', 'nope')).to.be('');
  }
}

describe 'MVC::Keayl word-wrap', {
  it 'breaks lines at the width', {
    expect(word-wrap('The quick brown fox', line-width => 10)).to.be("The quick\nbrown fox");
  }

  it 'leaves a short line alone', {
    expect(word-wrap('short line', line-width => 40)).to.be('short line');
  }
}

describe 'MVC::Keayl strip-tags and strip-links', {
  it 'removes all tags', {
    expect(strip-tags('<p>Hello <b>world</b></p>')).to.be('Hello world');
  }

  it 'keeps link text but drops the anchor', {
    expect(strip-links('Visit <a href="/x">here</a> now')).to.be('Visit here now');
  }
}

describe 'MVC::Keayl sanitize-css', {
  it 'keeps safe declarations', {
    expect(sanitize-css('color: red; font-size: 10px').Str).to.be('color: red; font-size: 10px');
  }

  it 'drops a declaration with an unsafe value', {
    expect(sanitize-css('color: red; background: url(javascript:alert(1))').Str).to.be('color: red');
  }
}

describe 'MVC::Keayl cycle', {
  it 'rotates through its values', {
    reset-cycle(name => 'rows');
    my @results = (cycle('odd', 'even', name => 'rows'), cycle('odd', 'even', name => 'rows'), cycle('odd', 'even', name => 'rows'));
    expect(@results).to.be(['odd', 'even', 'odd']);
  }

  it 'reports the last returned value', {
    reset-cycle(name => 'stripe');
    cycle('a', 'b', name => 'stripe');
    expect(current-cycle(name => 'stripe')).to.be('a');
  }

  it 'restarts from the first value after a reset', {
    reset-cycle(name => 'reset-me');
    cycle('x', 'y', name => 'reset-me');
    cycle('x', 'y', name => 'reset-me');
    reset-cycle(name => 'reset-me');
    expect(cycle('x', 'y', name => 'reset-me')).to.be('x');
  }
}

describe 'MVC::Keayl capture', {
  it 'returns the block output as a safe string', {
    expect(capture(-> { content-tag('p', 'hi') }).Str).to.be('<p>hi</p>');
  }
}

describe 'MVC::Keayl provide', {
  it 'accumulates content under a name', {
    my $*KEAYL-CONTENT = {};
    provide('head', '<meta>');
    provide('head', '<link>');
    expect($*KEAYL-CONTENT<head>).to.be('<meta><link>');
  }

  it 'returns an empty string outside a render', {
    expect(provide('head', 'x')).to.be('');
  }
}
