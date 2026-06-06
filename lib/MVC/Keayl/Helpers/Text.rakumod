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
