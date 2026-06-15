use v6.d;
use MVC::Keayl::SafeString;

unit module MVC::Keayl::Helpers::Text;

my %irregular = (
  person => 'people', child => 'children', man => 'men', woman => 'women',
  foot   => 'feet',   tooth => 'teeth',    mouse => 'mice', goose => 'geese',
  ox     => 'oxen',   leaf  => 'leaves',   life  => 'lives', knife => 'knives',
);

my %uncountable = <equipment information rice money species series fish sheep deer>.map(* => True).hash;

sub pluralize-word(Str() $word --> Str) is export {
  my $lower = $word.lc;

  return $word if %uncountable{$lower};
  return %irregular{$lower} if %irregular{$lower}:exists;

  given $word {
    when /:i <[bcdfghjklmnpqrstvwxz]> 'y' $/ { return $word.subst(/'y' $/, 'ies') }
    when /:i [ s | x | z | ch | sh ] $/      { return $word ~ 'es' }
    default                                  { return $word ~ 's' }
  }
}

sub pluralize($count, Str() $singular, Str :$plural --> Str) is export {
  my $word = $count == 1 ?? $singular !! ($plural // pluralize-word($singular));
  $count ~ ' ' ~ $word
}

sub truncate(Str() $text, Int :$length = 30, Str :$omission = '...', Str :$separator --> Str) is export {
  return $text if $text.chars <= $length;

  my $stop = max($length - $omission.chars, 0);
  my $truncated = $text.substr(0, $stop);

  if $separator.defined && $separator ne '' {
    my $index = $truncated.rindex($separator);
    $truncated = $truncated.substr(0, $index) with $index;
  }

  $truncated ~ $omission
}

sub simple-format(Str() $text, Str :$wrapper = 'p' --> SafeString) is export {
  my @paragraphs = $text.split(/\n \s* \n/);

  html-safe(
    @paragraphs.map(-> $paragraph {
      '<' ~ $wrapper ~ '>' ~ html-escape($paragraph.trim).subst(/\n/, '<br />', :g) ~ '</' ~ $wrapper ~ '>'
    }).join("\n")
  )
}

sub highlight(Str() $text, $phrases, Str :$highlighter = '<mark>\1</mark>' --> SafeString) is export {
  my @terms = ($phrases ~~ Positional ?? $phrases.list !! ($phrases,)).grep({ ~$_ ne '' });

  my $escaped = html-escape($text);

  for @terms -> $term {
    my $needle = html-escape(~$term);
    $escaped = $escaped.subst(/:i "$needle"/, { $highlighter.subst('\1', ~$/) }, :g);
  }

  html-safe($escaped)
}

sub excerpt(Str() $text, Str() $phrase, Int :$radius = 100, Str :$omission = '...' --> Str) is export {
  my $index = $text.index($phrase);
  return '' without $index;

  my $start = max($index - $radius, 0);
  my $stop  = min($index + $phrase.chars + $radius, $text.chars);

  my $excerpt = $text.substr($start, $stop - $start);
  $excerpt = $omission ~ $excerpt if $start > 0;
  $excerpt ~= $omission if $stop < $text.chars;

  $excerpt
}

sub word-wrap(Str() $text, Int :$line-width = 80, Str :$break-sequence = "\n" --> Str) is export {
  $text.split("\n").map(-> $line {
    my @wrapped;
    my $current = '';

    for $line.words -> $word {
      if $current eq '' {
        $current = $word;
      } elsif ($current ~ ' ' ~ $word).chars <= $line-width {
        $current ~= ' ' ~ $word;
      } else {
        @wrapped.push($current);
        $current = $word;
      }
    }

    @wrapped.push($current) if $current ne '' || $line eq '';
    @wrapped.join($break-sequence)
  }).join("\n")
}

sub strip-tags(Str() $html --> Str) is export {
  $html.subst(/'<' <-[>]>* '>'/, '', :g)
}

sub strip-links(Str() $html --> Str) is export {
  $html.subst(/:i '<a' <-[>]>* '>' (.*?) '</a>'/, { ~$0 }, :g)
}

my @unsafe-css = <javascript: expression @import behavior -moz-binding>;

sub sanitize-css(Str() $style --> SafeString) is export {
  my @safe = $style.split(';').map(*.trim).grep({ $_ ne '' }).grep({
    my $lower = .lc;
    !@unsafe-css.first({ $lower.contains($_) })
  });

  html-safe(@safe.join('; '))
}

my %cycle-registry;

sub cycle(*@values, Str :$name = 'default' --> Str) is export {
  my $signature = @values.join("\0");

  unless (%cycle-registry{$name}:exists) && %cycle-registry{$name}<signature> eq $signature {
    %cycle-registry{$name} = { values => @values.Array, :$signature, index => 0 };
  }

  my $entry = %cycle-registry{$name};
  my $value = $entry<values>[$entry<index> % $entry<values>.elems];
  $entry<index>++;

  ~$value
}

sub current-cycle(Str :$name = 'default') is export {
  return Str without %cycle-registry{$name};

  my $entry = %cycle-registry{$name};
  ~$entry<values>[($entry<index> - 1) % $entry<values>.elems]
}

sub reset-cycle(Str :$name = 'default' --> Str) is export {
  %cycle-registry{$name}<index> = 0 if %cycle-registry{$name}:exists;
  ''
}

sub capture(&block --> SafeString) is export {
  my $result = block();
  $result ~~ SafeString ?? $result !! html-safe(~($result // ''))
}

sub provide(Str:D $name, $content --> Str) is export {
  my $store = (try $*KEAYL-CONTENT) // Nil;
  return '' without $store;

  my $text = $content ~~ SafeString ?? $content.Str !! ~$content;
  $store{$name} = ($store{$name} // '') ~ $text;

  ''
}
