use v6.d;
use MVC::Keayl::Routing::Route;
use MVC::Keayl::Routing::RouteMatch;
use MVC::Keayl::Routing::PathPattern;

unit class MVC::Keayl::Router;

has MVC::Keayl::Routing::Route @.routes;

method add-route(
  @verbs,
  Str:D $path,
  $target,
  Str :$name,
      :%constraints,
      :%defaults,
  Bool :$format,
  --> ::?CLASS:D
) {
  my @normalized = @verbs.map(*.uc).unique;
  @normalized.push('HEAD') if @normalized.first(* eq 'GET') && !@normalized.first(* eq 'HEAD');

  my $pattern = MVC::Keayl::Routing::PathPattern.new(:source($path), :%constraints, :%defaults, :$format);

  @!routes.push: MVC::Keayl::Routing::Route.new(:verbs(@normalized), :$pattern, :$target, :$name);

  self
}

method recognize(Str:D $method, Str:D $path --> MVC::Keayl::Routing::RouteMatch) {
  for @!routes -> $route {
    next unless $route.handles($method);

    my $params = $route.match-path($path);
    next without $params;

    return MVC::Keayl::Routing::RouteMatch.new(:$route, :params($params));
  }

  MVC::Keayl::Routing::RouteMatch
}

method route-named(Str:D $name --> MVC::Keayl::Routing::Route) {
  @!routes.first({ .name.defined && .name eq $name }) // MVC::Keayl::Routing::Route
}
