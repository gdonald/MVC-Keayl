use v6.d;
use MVC::Keayl::Routing::PathPattern;

unit class MVC::Keayl::Routing::Route;

has Str @.verbs;
has MVC::Keayl::Routing::PathPattern $.pattern;
has     $.target;
has Str $.name;
has     %.request-constraints;
has     @.constraint-callables;

method path(--> Str) {
  $!pattern.source
}

method controller(--> Str) {
  return Str unless $!target ~~ Str;
  $!target.split('#', 2)[0]
}

method action(--> Str) {
  return Str unless $!target ~~ Str;
  $!target.split('#', 2)[1]
}

method callable(--> Callable) {
  $!target ~~ Callable ?? $!target !! Callable
}

method handles(Str:D $method --> Bool) {
  @!verbs.first(* eq $method.uc).defined
}

method match-path(Str:D $path --> Hash) {
  $!pattern.match($path)
}

method matches-request(%context --> Bool) {
  for %!request-constraints.kv -> $attr, $expected {
    my $actual = %context{$attr};
    return False without $actual;

    if $expected ~~ Regex {
      return False unless $actual ~~ $expected;
    } else {
      return False unless $actual eq $expected;
    }
  }

  for @!constraint-callables -> $constraint {
    my $ok = $constraint ~~ Callable ?? $constraint(%context) !! $constraint.matches(%context);
    return False unless $ok;
  }

  True
}
