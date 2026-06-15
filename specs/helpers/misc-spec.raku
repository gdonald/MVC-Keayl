use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Helpers::Tag;
use MVC::Keayl::Helpers::Number;

describe 'MVC::Keayl javascript-tag', {
  it 'wraps script content', {
    expect(javascript-tag('alert(1)').Str).to.be('<script>alert(1)</script>');
  }

  it 'emits its content unescaped', {
    expect(javascript-tag('x < y').Str).to.be('<script>x < y</script>');
  }

  it 'carries attributes', {
    expect(javascript-tag('go()', %( defer => True )).Str).to.be('<script defer>go()</script>');
  }
}

describe 'MVC::Keayl time-tag', {
  it 'sets a datetime attribute and content', {
    expect(time-tag(Date.new(2020, 1, 1), 'New Year').Str).to.be('<time datetime="2020-01-01">New Year</time>');
  }

  it 'defaults its content to the formatted date', {
    expect(time-tag(Date.new(2020, 1, 1)).Str).to.be('<time datetime="2020-01-01">2020-01-01</time>');
  }
}

describe 'MVC::Keayl auto-discovery-link-tag', {
  it 'builds an atom feed link', {
    expect(auto-discovery-link-tag('atom', '/feed.atom').Str).to.be('<link href="/feed.atom" rel="alternate" title="ATOM" type="application/atom+xml" />');
  }

  it 'selects the rss content type', {
    expect(auto-discovery-link-tag('rss', '/feed.rss').Str.contains('type="application/rss+xml"')).to.be-truthy;
  }
}

describe 'MVC::Keayl atom-feed', {
  it 'opens an Atom feed element', {
    my $feed = atom-feed(url => 'http://example.com', content => -> $feed {
      $feed.title('Posts');
      $feed.entry(Nil, id => 'tag:1', block => -> $entry {
        $entry.title('First');
        $entry.content('Body', type => 'html');
      });
    }).Str;

    expect($feed.contains('<feed xmlns="http://www.w3.org/2005/Atom">')).to.be-truthy;
  }

  it 'renders an entry with its content', {
    my $feed = atom-feed(content => -> $feed {
      $feed.title('Posts');
      $feed.entry(Nil, id => 'tag:1', block => -> $entry { $entry.title('First') });
    }).Str;

    expect($feed.contains('<entry>') && $feed.contains('<title>First</title>')).to.be-truthy;
  }
}

describe 'MVC::Keayl number-to-phone', {
  it 'groups a ten-digit number', {
    expect(number-to-phone(1235551234)).to.be('123-555-1234');
  }

  it 'groups a seven-digit number', {
    expect(number-to-phone(5551234)).to.be('555-1234');
  }

  it 'wraps the area code', {
    expect(number-to-phone(1235551234, area-code => True)).to.be('(123) 555-1234');
  }

  it 'prefixes a country code', {
    expect(number-to-phone(1235551234, country-code => 1)).to.be('+1-123-555-1234');
  }

  it 'appends an extension', {
    expect(number-to-phone(1235551234, extension => 555)).to.be('123-555-1234 x 555');
  }

  it 'honours a delimiter', {
    expect(number-to-phone(1235551234, delimiter => '.')).to.be('123.555.1234');
  }
}

describe 'MVC::Keayl number-to-human', {
  it 'leaves small numbers alone', {
    expect(number-to-human(123)).to.be('123');
  }

  it 'scales to thousands', {
    expect(number-to-human(1234)).to.be('1.23 Thousand');
  }

  it 'scales to millions', {
    expect(number-to-human(12345678)).to.be('12.3 Million');
  }

  it 'scales to trillions', {
    expect(number-to-human(1234567890123)).to.be('1.23 Trillion');
  }

  it 'rounds to the precision', {
    expect(number-to-human(489939, precision => 2)).to.be('490 Thousand');
  }
}
