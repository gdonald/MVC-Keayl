use v6.d;

unit module MVC::Keayl::SafeString;

class SafeString is export {
  has Str $.string is required;

  method Str(--> Str)          { $!string }
  method gist(--> Str)         { $!string }
  method Bool(--> Bool)        { ?$!string }
  method is-html-safe(--> Bool) { True }

  method concat($other --> SafeString) {
    SafeString.new(string => $!string ~ coerce-safe($other))
  }
}

sub html-escape(Str() $text --> Str) is export {
  $text.trans(
    ['&', '<', '>', '"', "'"]
    =>
    ['&amp;', '&lt;', '&gt;', '&quot;', '&#39;']
  )
}

sub coerce-safe($value --> Str) is export {
  $value ~~ SafeString ?? $value.Str !! html-escape($value.Str)
}

sub html-safe(Str() $text --> SafeString) is export {
  SafeString.new(string => $text)
}

sub raw(Str() $text --> SafeString) is export {
  SafeString.new(string => $text)
}

sub safe-join(@parts, Str() $separator = '' --> SafeString) is export {
  SafeString.new(string => @parts.map(&coerce-safe).join($separator))
}

sub json-escape(Str() $text --> Str) is export {
  my $line-separator      = chr(0x2028);
  my $paragraph-separator = chr(0x2029);

  $text.subst(
    / '<' | '>' | '&' | $line-separator | $paragraph-separator /,
    { chr(0x5C) ~ 'u' ~ sprintf('%04x', .Str.ord) },
    :g
  )
}

my @default-tags       = <a abbr b blockquote br code em h1 h2 h3 h4 h5 h6 i li ol p pre span strong ul>;
my @default-attributes = <href title alt>;

sub sanitize(Str() $html, :@tags = @default-tags, :@attributes = @default-attributes --> SafeString) is export {
  my $clean = $html;

  $clean ~~ s:g:i[ '<' (script | style) <-[>]>* '>' .*? '</' \s* $0 \s* '>' ] = '';

  $clean ~~ s:g[ '<' ('/'?) (<[A..Za..z]> \w*) (<-[>]>*) '>' ] = sanitize-element(~$0, ~$1, ~$2, @tags, @attributes);

  SafeString.new(string => $clean)
}

sub sanitize-element(Str $slash, Str $name, Str $attrs, @tags, @attributes --> Str) {
  return '' unless @tags.first({ .fc eq $name.fc });
  return '<' ~ $slash ~ $name.lc ~ '>' if $slash;

  my @kept;

  for $attrs.match(/ (\w+) \s* '=' \s* (<['"]>) (.*?) $1 /, :g) -> $match {
    my $attribute = $match[0].Str.lc;
    my $value     = $match[2].Str;

    next unless @attributes.first({ .fc eq $attribute.fc });
    next if $value.subst(/\s/, '', :g).lc.starts-with('javascript:');

    @kept.push: $attribute ~ '="' ~ html-escape($value) ~ '"';
  }

  '<' ~ $name.lc ~ (@kept ?? ' ' ~ @kept.join(' ') !! '') ~ '>'
}
