use v6.d;
use MVC::Keayl::Routing::Route;
use MVC::Keayl::Routing::RouteMatch;
use MVC::Keayl::Routing::PathPattern;

unit class MVC::Keayl::Router;

has MVC::Keayl::Routing::Route @.routes;
has %.directs;
has %.resolvers;

method add-route(
  @verbs,
  Str:D $path,
  $target,
  Str :$name,
      :%constraints,
      :%defaults,
  Bool :$format,
      :%request-constraints,
      :@constraint-callables,
  --> ::?CLASS:D
) {
  my @normalized = @verbs.map(*.uc).unique;
  @normalized.push('HEAD') if @normalized.first(* eq 'GET') && !@normalized.first(* eq 'HEAD');

  my $pattern = MVC::Keayl::Routing::PathPattern.new(:source($path), :%constraints, :%defaults, :$format);

  @!routes.push: MVC::Keayl::Routing::Route.new(
    :verbs(@normalized),
    :$pattern,
    :$target,
    :$name,
    :%request-constraints,
    :@constraint-callables,
  );

  self
}

method add-direct(Str:D $name, &block --> ::?CLASS:D) {
  %!directs{$name} = &block;
  self
}

method add-resolver(Str:D $class, &block --> ::?CLASS:D) {
  %!resolvers{$class} = &block;
  self
}

method recognize(Str:D $method, Str:D $path, :%context --> MVC::Keayl::Routing::RouteMatch) {
  for @!routes -> $route {
    next unless $route.handles($method);

    my $params = $route.match-path($path);
    next without $params;

    next unless $route.matches-request(%context);

    return MVC::Keayl::Routing::RouteMatch.new(:$route, :params($params));
  }

  MVC::Keayl::Routing::RouteMatch
}

method allowed-methods(Str:D $path, :%context --> List) {
  my @verbs;

  for @!routes -> $route {
    next without $route.match-path($path);
    next unless $route.matches-request(%context);
    @verbs.append($route.verbs);
  }

  @verbs.unique.List
}

method recognition-status(Str:D $method, Str:D $path, :%context --> Str) {
  return 'found' if self.recognize($method, $path, :%context).defined;
  return 'method-not-allowed' if self.allowed-methods($path, :%context);
  'not-found'
}

method route-named(Str:D $name --> MVC::Keayl::Routing::Route) {
  @!routes.first({ .name.defined && .name eq $name }) // MVC::Keayl::Routing::Route
}

method route-table(--> List) {
  @!routes.map(-> $route {
    %(
      name   => $route.name,
      verbs  => $route.verbs.grep(* ne 'HEAD').List,
      path   => $route.path,
      target => $route.target,
    )
  }).List
}
