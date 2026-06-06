use v6.d;
use MVC::Keayl::SafeString;

unit module MVC::Keayl::Helpers::Tag;

sub render-attributes(%attributes --> Str) is export {
  my @pairs;

  for %attributes.sort(*.key) -> $pair {
    my $value = $pair.value;

    next unless $value.defined;
    next if $value === False;

    if $value === True {
      @pairs.push: $pair.key;
    } else {
      @pairs.push: $pair.key ~ '="' ~ html-escape(~$value) ~ '"';
    }
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
