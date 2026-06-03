use v6.d;
use MVC::Keayl::Router;

unit module MVC::Keayl::Routing;

my @ALL-VERBS = <GET POST PUT PATCH DELETE OPTIONS HEAD>;

sub via-verbs($via --> List) {
  return @ALL-VERBS.List if $via ~~ Whatever;
  return @ALL-VERBS.List if $via ~~ Str && $via.lc eq 'all';

  ($via ~~ Str ?? ($via,) !! $via.list).map(*.uc).list
}

sub current-router(--> MVC::Keayl::Router:D) {
  my $router = $*KEAYL-ROUTER;
  die 'routing DSL used outside a `routes` block' without $router;
  $router
}

sub routes(&block --> MVC::Keayl::Router:D) is export {
  my $router = MVC::Keayl::Router.new;

  {
    my $*KEAYL-ROUTER = $router;
    block();
  }

  $router
}

sub draw(&block --> MVC::Keayl::Router:D) is export {
  routes(&block)
}

sub load-routes(IO() $path --> MVC::Keayl::Router:D) is export {
  EVALFILE $path
}

sub get(Str:D $path, :$to, Str :$as, :%constraints, :%defaults, Bool :$format) is export {
  current-router.add-route(['GET'], $path, $to, :name($as), :%constraints, :%defaults, :$format)
}

sub post(Str:D $path, :$to, Str :$as, :%constraints, :%defaults, Bool :$format) is export {
  current-router.add-route(['POST'], $path, $to, :name($as), :%constraints, :%defaults, :$format)
}

sub put(Str:D $path, :$to, Str :$as, :%constraints, :%defaults, Bool :$format) is export {
  current-router.add-route(['PUT'], $path, $to, :name($as), :%constraints, :%defaults, :$format)
}

sub patch(Str:D $path, :$to, Str :$as, :%constraints, :%defaults, Bool :$format) is export {
  current-router.add-route(['PATCH'], $path, $to, :name($as), :%constraints, :%defaults, :$format)
}

sub delete(Str:D $path, :$to, Str :$as, :%constraints, :%defaults, Bool :$format) is export {
  current-router.add-route(['DELETE'], $path, $to, :name($as), :%constraints, :%defaults, :$format)
}

sub options(Str:D $path, :$to, Str :$as, :%constraints, :%defaults, Bool :$format) is export {
  current-router.add-route(['OPTIONS'], $path, $to, :name($as), :%constraints, :%defaults, :$format)
}

sub match(Str:D $path, :$to, :$via = 'GET', Str :$as, :%constraints, :%defaults, Bool :$format) is export {
  current-router.add-route(via-verbs($via), $path, $to, :name($as), :%constraints, :%defaults, :$format)
}

sub root(:$to, Str :$as = 'root') is export {
  current-router.add-route(['GET'], '/', $to, :name($as))
}
