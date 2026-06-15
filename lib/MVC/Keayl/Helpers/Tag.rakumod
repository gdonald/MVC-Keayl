use v6.d;
use JSON::Fast;
use MVC::Keayl::SafeString;

unit module MVC::Keayl::Helpers::Tag;

sub dasherize(Str:D $name --> Str) {
  $name.subst('_', '-', :g)
}

sub class-names(*@tokens --> Str) is export {
  my @classes;

  for @tokens -> $token {
    next without $token;

    given $token {
      when Associative {
        for .sort(*.key) -> $pair { @classes.push(~$pair.key) if $pair.value }
      }
      when Positional {
        @classes.append: class-names(|$token).words;
      }
      when Bool { }
      default {
        my $text = ~$token;
        @classes.push($text) if $text ne '';
      }
    }
  }

  @classes.unique.join(' ')
}

sub data-attributes(%data --> Hash) is export {
  my %result;
  %result{'data-' ~ dasherize(~.key)} = .value for %data;
  %result
}

sub attribute-value($value --> Str) {
  return to-json($value, :!pretty) if $value ~~ Positional || $value ~~ Associative;
  ~$value
}

sub format-attribute(Str:D $name, $value) {
  return Nil if !$value.defined || $value === False;
  return $name if $value === True;

  my $text;

  if $name eq 'class' && $value ~~ Positional {
    $text = class-names(|$value);
  } elsif $name eq 'class' && $value ~~ Associative {
    $text = class-names($value);
  } else {
    $text = attribute-value($value);
  }

  return Nil if $name eq 'class' && $text eq '';

  $name ~ '="' ~ html-escape($text) ~ '"'
}

sub expand-attributes(%attributes --> List) {
  my @expanded;

  for %attributes.sort(*.key) -> $pair {
    if ($pair.key eq 'data' || $pair.key eq 'aria') && $pair.value ~~ Associative {
      for $pair.value.sort(*.key) -> $sub {
        @expanded.push: ($pair.key ~ '-' ~ dasherize(~$sub.key)) => $sub.value;
      }
    } else {
      @expanded.push: $pair;
    }
  }

  @expanded
}

sub render-attributes(%attributes --> Str) is export {
  my @pairs;

  for expand-attributes(%attributes) -> $pair {
    my $rendered = format-attribute(~$pair.key, $pair.value);
    @pairs.push($rendered) with $rendered;
  }

  @pairs ?? ' ' ~ @pairs.join(' ') !! ''
}

sub content-tag(Str:D $name, $content?, %attributes? --> SafeString) is export {
  my $inner = do given $content {
    when SafeString { .Str }
    when .defined   { html-escape(~$content) }
    default         { '' }
  };

  html-safe('<' ~ $name ~ render-attributes(%attributes // {}) ~ '>' ~ $inner ~ '</' ~ $name ~ '>')
}

sub tag(Str:D $name, %attributes? --> SafeString) is export {
  html-safe('<' ~ $name ~ render-attributes(%attributes // {}) ~ ' />')
}

sub button-tag($content = 'Button', %options? --> SafeString) is export {
  my %attrs = %options // {};
  %attrs<type> //= 'submit';

  content-tag('button', $content, %attrs)
}

sub javascript-tag($content, %options? --> SafeString) is export {
  my $body = $content ~~ SafeString ?? $content.Str !! ~$content;

  html-safe('<script' ~ render-attributes(%options // {}) ~ '>' ~ $body ~ '</script>')
}

sub iso8601($value --> Str) {
  return $value.Str if $value ~~ Dateish;
  ~$value
}

sub time-tag($date, $content?, %options? --> SafeString) is export {
  my %attrs = %options // {};
  %attrs<datetime> //= iso8601($date);

  content-tag('time', $content // iso8601($date), %attrs)
}

my %feed-types = atom => 'application/atom+xml', rss => 'application/rss+xml', json => 'application/json';

sub auto-discovery-link-tag($type = 'rss', $url = '', %options? --> SafeString) is export {
  my %attrs = %options // {};
  my $kind  = ~$type;

  %attrs<rel>   //= 'alternate';
  %attrs<type>  //= %feed-types{$kind} // 'application/' ~ $kind ~ '+xml';
  %attrs<title> //= $kind.uc;
  %attrs<href>    = ~$url;

  tag('link', %attrs)
}

sub xml-escape(Str() $text --> Str) {
  $text.trans(['&', '<', '>', '"', "'"] => ['&amp;', '&lt;', '&gt;', '&quot;', '&apos;'])
}

class AtomEntryBuilder {
  has Str @.parts;

  method title(Str() $text) { @!parts.push('<title>' ~ xml-escape($text) ~ '</title>'); '' }

  method content(Str() $text, Str :$type = 'html') {
    @!parts.push('<content type="' ~ xml-escape($type) ~ '">' ~ xml-escape($text) ~ '</content>'); ''
  }

  method updated($value) { @!parts.push('<updated>' ~ xml-escape(~$value) ~ '</updated>'); '' }

  method id(Str() $value) { @!parts.push('<id>' ~ xml-escape($value) ~ '</id>'); '' }

  method author(Str:D :$name, Str :$email) {
    my $inner = '<name>' ~ xml-escape($name) ~ '</name>';
    $inner ~= '<email>' ~ xml-escape($email) ~ '</email>' if $email.defined;
    @!parts.push('<author>' ~ $inner ~ '</author>'); ''
  }

  method link(Str:D :$href, Str :$rel = 'alternate') {
    @!parts.push('<link href="' ~ xml-escape($href) ~ '" rel="' ~ xml-escape($rel) ~ '" />'); ''
  }

  method render(--> Str) { '<entry>' ~ @!parts.join ~ '</entry>' }
}

class AtomFeedBuilder {
  has Str $.root-url;
  has Str @.parts;
  has AtomEntryBuilder @.entries;

  method title(Str() $text) { @!parts.push('<title>' ~ xml-escape($text) ~ '</title>'); '' }

  method updated($value) { @!parts.push('<updated>' ~ xml-escape(~$value) ~ '</updated>'); '' }

  method id(Str() $value) { @!parts.push('<id>' ~ xml-escape($value) ~ '</id>'); '' }

  method entry($record, Str :$url, Str :$id, :&block --> Str) {
    my $entry    = AtomEntryBuilder.new;
    my $entry-id = $id // (($record.defined && $record.^can('id')) ?? ($!root-url // '') ~ '/' ~ $record.id !! '');

    $entry.id($entry-id) if $entry-id;
    $entry.link(href => $url) if $url.defined;
    block($entry) if &block;

    @!entries.push($entry);
    ''
  }

  method render(--> Str) {
    '<?xml version="1.0" encoding="UTF-8"?>' ~ "\n" ~
    '<feed xmlns="http://www.w3.org/2005/Atom">' ~
    @!parts.join ~
    @!entries.map(*.render).join ~
    '</feed>'
  }
}

sub atom-feed(Str :$url, :&content --> SafeString) is export {
  my $feed = AtomFeedBuilder.new(root-url => $url // '');
  content($feed) if &content;

  html-safe($feed.render)
}
