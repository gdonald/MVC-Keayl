use v6.d;

unit class MVC::Keayl::Routing::Route;

has Str @.verbs;
has Str $.path;
has     $.target;
has Str $.name;

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

method matches(Str:D $method, Str:D $path --> Bool) {
  $path eq $!path && self.handles($method)
}
