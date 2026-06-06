use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Helpers::Text;
use MVC::Keayl::Helpers::Number;
use MVC::Keayl::Helpers::DateTime;

sub fixed-time { DateTime.new(:2020year, :1month, :1day, :12hour, :0minute, :0second) }

describe 'MVC::Keayl truncate', {
  it 'cuts to the length including the omission', {
    expect(truncate('This is a long sentence that needs trimming', length => 20)).to.be('This is a long se...');
  }

  it 'leaves a short string alone', {
    expect(truncate('short')).to.be('short');
  }

  it 'breaks at a separator', {
    expect(truncate('one two three four', length => 12, separator => ' ')).to.be('one two...');
  }
}

describe 'MVC::Keayl pluralize', {
  it 'keeps the singular for one', {
    expect(pluralize(1, 'person')).to.be('1 person');
  }

  it 'uses an irregular plural', {
    expect(pluralize(2, 'person')).to.be('2 people');
  }

  it 'applies the consonant-y rule', {
    expect(pluralize(0, 'category')).to.be('0 categories');
  }

  it 'applies the -es rule', {
    expect(pluralize(3, 'box')).to.be('3 boxes');
  }

  it 'honours an explicit plural', {
    expect(pluralize(5, 'octopus', plural => 'octopi')).to.be('5 octopi');
  }
}

describe 'MVC::Keayl simple-format', {
  it 'wraps text in a paragraph', {
    expect(simple-format('Hello world').Str).to.be('<p>Hello world</p>');
  }

  it 'turns single newlines into breaks', {
    expect(simple-format("Line one\nLine two").Str).to.be('<p>Line one<br />Line two</p>');
  }

  it 'splits paragraphs on blank lines', {
    expect(simple-format("Para one\n\nPara two").Str).to.be("<p>Para one</p>\n<p>Para two</p>");
  }

  it 'escapes its content', {
    expect(simple-format('<script>x</script>').Str.contains('&lt;script&gt;')).to.be-truthy;
  }
}

describe 'MVC::Keayl number-with-delimiter', {
  it 'groups thousands', {
    expect(number-with-delimiter(1234567)).to.be('1,234,567');
  }

  it 'keeps the sign and decimals', {
    expect(number-with-delimiter(-1234.56)).to.be('-1,234.56');
  }
}

describe 'MVC::Keayl number-to-currency', {
  it 'formats with a unit and delimiter', {
    expect(number-to-currency(1234.5)).to.be('$1,234.50');
  }

  it 'handles negatives', {
    expect(number-to-currency(-9.99)).to.be('-$9.99');
  }

  it 'honours unit and format', {
    expect(number-to-currency(1000, unit => '€', format => '%n%u', precision => 0)).to.be('1,000€');
  }
}

describe 'MVC::Keayl number-to-percentage', {
  it 'appends a percent sign', {
    expect(number-to-percentage(100)).to.be('100.00%');
  }

  it 'rounds to the precision', {
    expect(number-to-percentage(66.666, precision => 1)).to.be('66.7%');
  }
}

describe 'MVC::Keayl number-to-human-size', {
  it 'reports bytes below a kilobyte', {
    expect(number-to-human-size(512)).to.be('512 Bytes');
  }

  it 'uses a singular byte', {
    expect(number-to-human-size(1)).to.be('1 Byte');
  }

  it 'scales to kilobytes', {
    expect(number-to-human-size(1024)).to.be('1 KB');
  }

  it 'keeps a fractional part', {
    expect(number-to-human-size(1536)).to.be('1.5 KB');
  }

  it 'scales to megabytes', {
    expect(number-to-human-size(1048576)).to.be('1 MB');
  }
}

describe 'MVC::Keayl distance-of-time-in-words', {
  it 'reports a short gap as less than a minute', {
    expect(distance-of-time-in-words(fixed-time, fixed-time.later(seconds => 20))).to.be('less than a minute');
  }

  it 'reports a few minutes', {
    expect(distance-of-time-in-words(fixed-time, fixed-time.later(minutes => 5))).to.be('5 minutes');
  }

  it 'reports an hour as about 1 hour', {
    expect(distance-of-time-in-words(fixed-time, fixed-time.later(minutes => 60))).to.be('about 1 hour');
  }

  it 'reports several hours', {
    expect(distance-of-time-in-words(fixed-time, fixed-time.later(hours => 5))).to.be('about 5 hours');
  }

  it 'reports several days', {
    expect(distance-of-time-in-words(fixed-time, fixed-time.later(days => 3))).to.be('3 days');
  }

  it 'reports finer detail with seconds enabled', {
    expect(distance-of-time-in-words(fixed-time, fixed-time.later(seconds => 3), include-seconds => True)).to.be('less than 5 seconds');
  }
}

describe 'MVC::Keayl time-ago-in-words', {
  it 'measures against a reference time', {
    expect(time-ago-in-words(fixed-time, fixed-time.later(minutes => 10))).to.be('10 minutes');
  }
}
