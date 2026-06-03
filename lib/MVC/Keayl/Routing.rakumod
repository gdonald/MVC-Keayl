use v6.d;
use MVC::Keayl::Router;
use MVC::Keayl::Routing::Resources;

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

sub register(@verbs, Str:D $path, $to, $as, $on, %constraints, %defaults, $format) {
  with $*KEAYL-RESOURCE {
    add-resource-route($_, @verbs, $path, $to, ($on // $*KEAYL-ON // 'member'), $as);
  } else {
    current-router.add-route(@verbs, $path, $to, :name($as), :%constraints, :%defaults, :$format);
  }
}

sub routes(&block --> MVC::Keayl::Router:D) is export {
  my $router = MVC::Keayl::Router.new;

  {
    my $*KEAYL-ROUTER = $router;
    my $*KEAYL-RESOURCE;
    my $*KEAYL-ON;
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

sub get(Str:D $path, :$to, Str :$as, :$on, :%constraints, :%defaults, Bool :$format) is export {
  register(['GET'], $path, $to, $as, $on, %constraints, %defaults, $format)
}

sub post(Str:D $path, :$to, Str :$as, :$on, :%constraints, :%defaults, Bool :$format) is export {
  register(['POST'], $path, $to, $as, $on, %constraints, %defaults, $format)
}

sub put(Str:D $path, :$to, Str :$as, :$on, :%constraints, :%defaults, Bool :$format) is export {
  register(['PUT'], $path, $to, $as, $on, %constraints, %defaults, $format)
}

sub patch(Str:D $path, :$to, Str :$as, :$on, :%constraints, :%defaults, Bool :$format) is export {
  register(['PATCH'], $path, $to, $as, $on, %constraints, %defaults, $format)
}

sub delete(Str:D $path, :$to, Str :$as, :$on, :%constraints, :%defaults, Bool :$format) is export {
  register(['DELETE'], $path, $to, $as, $on, %constraints, %defaults, $format)
}

sub options(Str:D $path, :$to, Str :$as, :$on, :%constraints, :%defaults, Bool :$format) is export {
  register(['OPTIONS'], $path, $to, $as, $on, %constraints, %defaults, $format)
}

sub match(Str:D $path, :$to, :$via = 'GET', Str :$as, :$on, :%constraints, :%defaults, Bool :$format) is export {
  register(via-verbs($via), $path, $to, $as, $on, %constraints, %defaults, $format)
}

sub root(:$to, Str :$as = 'root') is export {
  current-router.add-route(['GET'], '/', $to, :name($as))
}

sub resources(*@args, :$only, :$except, :$path, :$as, :$controller, :$module, :$param, :%path-names) is export {
  my @names = @args.grep(* ~~ Str);
  my $block = @args.first(* ~~ Callable);

  for @names -> $name {
    add-resource(current-router, $name, :$only, :$except, :$path, :$as, :$controller, :$module, :$param, :%path-names, :$block);
  }
}

sub member(&block) is export {
  my $*KEAYL-ON = 'member';
  block();
}

sub collection(&block) is export {
  my $*KEAYL-ON = 'collection';
  block();
}
