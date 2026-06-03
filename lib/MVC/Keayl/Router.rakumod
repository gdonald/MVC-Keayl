use v6.d;
use MVC::Keayl::Routing::Route;

unit class MVC::Keayl::Router;

has MVC::Keayl::Routing::Route @.routes;

method add-route(@verbs, Str:D $path, $target, Str :$name --> ::?CLASS:D) {
  my @normalized = @verbs.map(*.uc).unique;
  @normalized.push('HEAD') if @normalized.first(* eq 'GET') && !@normalized.first(* eq 'HEAD');

  @!routes.push: MVC::Keayl::Routing::Route.new(:verbs(@normalized), :$path, :$target, :$name);

  self
}

method recognize(Str:D $method, Str:D $path --> MVC::Keayl::Routing::Route) {
  @!routes.first({ .matches($method, $path) }) // MVC::Keayl::Routing::Route
}

method route-named(Str:D $name --> MVC::Keayl::Routing::Route) {
  @!routes.first({ .name.defined && .name eq $name }) // MVC::Keayl::Routing::Route
}
