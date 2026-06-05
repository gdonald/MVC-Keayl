use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::SafeString;
use MVC::Keayl::View;

sub view { MVC::Keayl::View.new(:paths(['specs/lib/views'])) }

describe 'MVC::Keayl html-escape', {
  it 'replaces the markup-significant characters', {
    expect(html-escape(q{<a href="x">Tom & Jerry</a>})).to.be('&lt;a href=&quot;x&quot;&gt;Tom &amp; Jerry&lt;/a&gt;');
  }

  it 'encodes single quotes', {
    expect(html-escape(q{it's})).to.be('it&#39;s');
  }
}

describe 'MVC::Keayl safe strings', {
  it 'marks a string as safe', {
    expect(html-safe('<b>ok</b>').is-html-safe).to.be-truthy;
  }

  it 'stringifies to its raw content', {
    expect(html-safe('<b>ok</b>').Str).to.be('<b>ok</b>');
  }

  it 'returns a safe string from raw', {
    expect(raw('<i>x</i>').Str).to.be('<i>x</i>');
  }
}

describe 'MVC::Keayl safe concatenation', {
  it 'keeps safe parts raw and escapes unsafe parts', {
    expect(safe-join([html-safe('<b>a</b>'), '<script>']).Str).to.be('<b>a</b>&lt;script&gt;');
  }

  it 'escapes a value appended onto a safe string', {
    expect(html-safe('<x>').concat('<y>').Str).to.be('<x>&lt;y&gt;');
  }
}

describe 'MVC::Keayl sanitize', {
  it 'removes script elements and their content', {
    expect(sanitize('<script>alert(1)</script>hello').Str).to.be('hello');
  }

  it 'keeps allowed tags and strips disallowed ones', {
    expect(sanitize('<b>bold</b> <blink>no</blink>').Str).to.be('<b>bold</b> no');
  }

  it 'drops event-handler attributes', {
    expect(sanitize('<a href="/ok" onclick="evil()">link</a>').Str).to.be('<a href="/ok">link</a>');
  }

  it 'strips a javascript URL', {
    expect(sanitize('<a href="javascript:evil()">x</a>').Str).to.be('<a>x</a>');
  }
}

describe 'MVC::Keayl json-escape', {
  it 'escapes angle brackets for a script context', {
    expect(json-escape('</script>')).to.be('\\u003c/script\\u003e');
  }

  it 'escapes ampersands', {
    expect(json-escape('a & b')).to.be('a \\u0026 b');
  }
}

describe 'MVC::Keayl template output safety', {
  it 'escapes interpolated values by default', {
    my $out = view.render-template('greetings/safety', { danger => '<i>x</i>', markup => '<b>ok</b>' });
    expect($out.contains('&lt;i&gt;x&lt;/i&gt;')).to.be-truthy;
  }

  it 'keeps allowed markup through the sanitize helper', {
    my $out = view.render-template('greetings/safety', { danger => 'x', markup => '<b>ok</b><script>bad()</script>' });
    expect($out.contains('<b>ok</b>')).to.be-truthy;
  }

  it 'removes script content through the sanitize helper', {
    my $out = view.render-template('greetings/safety', { danger => 'x', markup => '<b>ok</b><script>bad()</script>' });
    expect($out.contains('bad()')).to.be-falsy;
  }
}
