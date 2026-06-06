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
