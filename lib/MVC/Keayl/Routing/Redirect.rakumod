use v6.d;

unit class MVC::Keayl::Routing::Redirect;

has     $.location is required;
has Int $.status = 301;

method location-for(%params --> Str) {
  $!location ~~ Callable ?? $!location(%params) !! $!location
}
