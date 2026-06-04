use v6.d;
use MVC::Keayl::Router;
use MVC::Keayl::Routing::Resources;
use MVC::Keayl::Routing::Redirect;
use MVC::Keayl::Routing::Mount;

unit module MVC::Keayl::Routing;

my @ALL-VERBS     = <GET POST PUT PATCH DELETE OPTIONS HEAD>;
my @REQUEST-ATTRS = <subdomain host format protocol port method>;

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

sub current-context(--> RoutingContext) {
  $*KEAYL-SCOPE // RoutingContext.new
}

sub with-context(RoutingContext $context, $block) {
  my $*KEAYL-SCOPE = $context;
  $block() with $block;
}

sub path-to-action(Str $path --> Str) {
  $path.subst(/^ '/' /, '').split('/').grep(*.chars).tail // $path
}

sub apply-module-prefix($target, Str $module-prefix) {
  return $target unless $target ~~ Str && $module-prefix ne '' && $target.contains('#');
  my ($ctrl, $action) = $target.split('#', 2);
  $module-prefix ~ $ctrl ~ '#' ~ $action
}

sub resolve-target($to, Str $path, RoutingContext $context) {
  return $to if $to ~~ Callable;

  my $target;
  if $to ~~ Str && $to.contains('#') {
    $target = $to;
  } elsif $context.controller.defined {
    my $action = ($to ~~ Str && $to.chars) ?? $to !! path-to-action($path);
    $target = $context.controller ~ '#' ~ $action;
  } else {
    $target = $to;
  }

  apply-module-prefix($target, $context.module-prefix)
}

sub register(@verbs, Str:D $path, $to, $as, $on, %constraints, %defaults, $format) {
  with $*KEAYL-RESOURCE {
    add-resource-route($_, @verbs, $path, $to, ($on // $*KEAYL-ON // 'member'), $as);
  } else {
    my $context = current-context();
    my $full-path = $context.path-prefix ~ $path;
    my $target = resolve-target($to, $path, $context);
    my $name = $as.defined ?? $context.name-prefix ~ $as !! $as;

    current-router.add-route(@verbs, $full-path, $target, :name($name), :$format,
      |$context.route-args(:%constraints, :%defaults));
  }
}

sub routes(&block --> MVC::Keayl::Router:D) is export {
  my $router = MVC::Keayl::Router.new;

  {
    my $*KEAYL-ROUTER = $router;
    my $*KEAYL-RESOURCE;
    my $*KEAYL-ON;
    my $*KEAYL-SCOPE = RoutingContext.new;
    my $*KEAYL-CONCERNS = {};
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
  my $context = current-context();
  current-router.add-route(['GET'], $context.path-prefix ~ '/', resolve-target($to, '/', $context),
    :name($context.name-prefix ~ $as), |$context.route-args);
}

sub resource-block($user-block, $concerns) {
  return $user-block without $concerns;

  sub {
    $user-block() with $user-block;
    concerns(|$concerns.list);
  }
}

sub resources(*@args, :$only, :$except, :$path, :$as, :$controller, :$module, :$param, :%path-names, :$shallow, :$shallow-path, :$shallow-prefix, :$concerns) is export {
  my @names = @args.grep(* ~~ Str);
  my $block = resource-block(@args.first(* ~~ Callable), $concerns);

  for @names -> $name {
    add-resource(current-router, $name, :$only, :$except, :$path, :$as, :$controller, :$module, :$param, :%path-names, :$shallow, :$shallow-path, :$shallow-prefix, :$block);
  }
}

sub resource(*@args, :$only, :$except, :$path, :$as, :$controller, :$module, :%path-names, :$concerns) is export {
  my @names = @args.grep(* ~~ Str);
  my $block = resource-block(@args.first(* ~~ Callable), $concerns);

  for @names -> $name {
    add-singular-resource(current-router, $name, :$only, :$except, :$path, :$as, :$controller, :$module, :%path-names, :$block);
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

sub namespace(Str:D $name, *@args) is export {
  my $block = @args.first(* ~~ Callable);
  with-context(current-context().merge(:path($name), :module($name), :as($name)), $block);
}

sub scope(*@args, :$path, :$module, :$as) is export {
  my $positional = @args.first(* ~~ Str);
  my $block = @args.first(* ~~ Callable);
  with-context(current-context().merge(:path($path // $positional), :$module, :$as), $block);
}

sub controller(Str:D $name, *@args) is export {
  my $block = @args.first(* ~~ Callable);
  with-context(current-context().merge(:controller($name)), $block);
}

sub concern(Str:D $name, &block) is export {
  $*KEAYL-CONCERNS{$name} = &block;
}

sub concerns(*@names) is export {
  for @names.flat -> $name {
    my $block = $*KEAYL-CONCERNS{$name} // die "unknown concern '$name'";
    $block();
  }
}

sub constraints(*@args, *%spec) is export {
  my @positional = @args;
  my $block = @positional.pop;
  my @custom = @positional;

  my %segment;
  my %request;
  for %spec.kv -> $key, $value {
    if @REQUEST-ATTRS.first(* eq $key) { %request{$key} = $value } else { %segment{$key} = $value }
  }

  with-context(
    current-context().merge(:segment-constraints(%segment), :request-constraints(%request), :constraint-callables(@custom)),
    $block,
  );
}

sub defaults(*@args, *%values) is export {
  my $block = @args.first(* ~~ Callable);
  with-context(current-context().merge(:defaults(%values)), $block);
}

sub redirect($location, Int :$status = 301) is export {
  MVC::Keayl::Routing::Redirect.new(:$location, :$status)
}

sub mount($app, Str:D :$at!) is export {
  current-router.add-route(<GET POST PUT PATCH DELETE OPTIONS HEAD>, $at ~ '(/*mounted_path)',
    MVC::Keayl::Routing::Mount.new(:$app, :$at))
}

sub direct(Str:D $name, &block) is export {
  current-router.add-direct($name, &block)
}

sub resolve(Str:D $class, &block) is export {
  current-router.add-resolver($class, &block)
}
