use v6.d;
use MVC::Keayl::Router;

unit module MVC::Keayl::Routing::Resources;

sub scope-path-addition($path --> Str) is export {
  return '' without $path;
  return '(/' ~ $0 ~ ')' if $path ~~ /^ '(' (.*) ')' $/;
  '/' ~ $path
}

# The accumulated path / module / name prefixes, scoped controller, and
# constraint / default state contributed by enclosing `namespace`, `scope`,
# `controller`, `constraints`, and `defaults` blocks.
class RoutingContext is export {
  has Str $.path-prefix = '';
  has Str $.module-prefix = '';
  has Str $.name-prefix = '';
  has Str $.controller;
  has     %.segment-constraints;
  has     %.request-constraints;
  has     @.constraint-callables;
  has     %.defaults;

  method merge(:$path, :$module, :$as, :$controller, :%segment-constraints, :%request-constraints, :@constraint-callables, :%defaults --> RoutingContext) {
    RoutingContext.new(
      path-prefix          => $!path-prefix ~ scope-path-addition($path),
      module-prefix        => $!module-prefix ~ ($module ?? $module ~ '/' !! ''),
      name-prefix          => $!name-prefix ~ ($as ?? $as ~ '-' !! ''),
      controller           => $controller // $!controller,
      segment-constraints  => { %!segment-constraints, %segment-constraints },
      request-constraints  => { %!request-constraints, %request-constraints },
      constraint-callables => [ |@!constraint-callables, |@constraint-callables ],
      defaults             => { %!defaults, %defaults },
    )
  }

  method route-args(:%constraints, :%defaults --> Capture) {
    \(
      constraints          => { %!segment-constraints, %constraints },
      defaults             => { %!defaults, %defaults },
      request-constraints  => %!request-constraints,
      constraint-callables => @!constraint-callables,
    )
  }
}

class ResourceScope {
  has Str  $.collection-path;
  has Str  $.member-base;
  has Str  $.controller;
  has Str  $.param;
  has Str  $.singular;
  has Str  $.plural;
  has Str  $.collection-name-prefix;
  has Str  $.member-name-prefix;
  has Bool $.is-singular = False;
  has Bool $.shallow = False;
  has      $.shallow-path;
  has      $.shallow-prefix;

  method member-path(--> Str) {
    $!is-singular ?? $!member-base !! $!member-base ~ '/:' ~ $!param
  }

  method child-prefix(--> Str) {
    $!is-singular ?? $!member-base !! $!member-base ~ '/:' ~ $!singular ~ '_' ~ $!param
  }

  method child-name-prefix(--> Str) {
    $!member-name-prefix ~ $!singular ~ '-'
  }
}

sub singularize(Str:D $word --> Str) is export {
  return $word.subst(/ies$/, 'y')             if $word ~~ /ies$/;
  return $word.subst(/(s|x|z|ch|sh)es$/, {$0}) if $word ~~ /(s|x|z|ch|sh)es$/;
  return $word.subst(/s$/, '')                if $word ~~ /s$/;
  $word
}

sub pluralize(Str:D $word --> Str) is export {
  return $word.subst(/y$/, 'ies') if $word ~~ /<-[aeiou]>y$/;
  return $word ~ 'es'             if $word ~~ /(s|x|z|ch|sh)$/;
  $word ~ 's'
}

sub resolve-actions(@all, $only, $except --> List) {
  my @actions = @all;

  with $only {
    my %keep;
    %keep{.Str} = True for $only.list;
    @actions = @actions.grep({ %keep{$_} });
  }

  with $except {
    my %drop;
    %drop{.Str} = True for $except.list;
    @actions = @actions.grep({ !%drop{$_} });
  }

  @actions.List
}

sub current-context(--> RoutingContext) {
  $*KEAYL-SCOPE // RoutingContext.new
}

sub run-block-and-rest($router, $scope, $block, @rest, @wanted) {
  with $block {
    my $*KEAYL-RESOURCE = $scope;
    my $*KEAYL-ON;
    $block();
  }

  my $ctx = current-context();
  my %wanted;
  %wanted{$_} = True for @wanted;

  for @rest -> %route {
    next unless %wanted{%route<action>};
    $router.add-route([%route<verb>], %route<path>, $scope.controller ~ '#' ~ %route<action>,
      :name(%route<name>), |$ctx.route-args);
  }
}

sub add-resource(
  MVC::Keayl::Router:D $router,
  Str:D $name,
       :$only, :$except, :$path, :$as, :$controller, :$module, :$param, :%path-names,
       :$shallow, :$shallow-path, :$shallow-prefix,
       :$block,
) is export {
  my $parent      = $*KEAYL-RESOURCE;
  my $ctx         = current-context();
  my $path-prefix = $parent.defined ?? $parent.child-prefix      !! $ctx.path-prefix;
  my $name-prefix = $parent.defined ?? $parent.child-name-prefix !! $ctx.name-prefix;

  my $segment   = $path // $name;
  my $ctrl      = $controller // ($ctx.module-prefix ~ ($module ?? $module ~ '/' !! '') ~ $name);
  my $plural    = $as // $name;
  my $singular  = singularize($plural);
  my $id        = $param // 'id';
  my $new-seg   = %path-names<new>  // 'new';
  my $edit-seg  = %path-names<edit> // 'edit';

  my $collection = $path-prefix ~ '/' ~ $segment;
  my $nested     = $path-prefix ne '';

  my $shallow-on     = $shallow        // ($parent.defined ?? $parent.shallow        !! False);
  my $shallow-seg    = $shallow-path   // ($parent.defined ?? $parent.shallow-path   !! Str);
  my $shallow-pre    = $shallow-prefix // ($parent.defined ?? $parent.shallow-prefix !! Str);
  my $shallow-active = $shallow-on && $nested;

  my $member-base        = $shallow-active ?? '/' ~ ($shallow-seg // $segment) !! $collection;
  my $member-name-prefix = $shallow-active ?? ($shallow-pre // '')             !! $name-prefix;
  my $member             = $member-base ~ '/:' ~ $id;

  my @rest =
    { action => 'index',   verb => 'GET',    path => $collection,                  name => $name-prefix ~ $plural },
    { action => 'new',     verb => 'GET',    path => $collection ~ '/' ~ $new-seg, name => 'new-' ~ $name-prefix ~ $singular },
    { action => 'create',  verb => 'POST',   path => $collection,                  name => $name-prefix ~ $plural },
    { action => 'edit',    verb => 'GET',    path => $member ~ '/' ~ $edit-seg,    name => 'edit-' ~ $member-name-prefix ~ $singular },
    { action => 'show',    verb => 'GET',    path => $member,                      name => $member-name-prefix ~ $singular },
    { action => 'update',  verb => 'PATCH',  path => $member,                      name => $member-name-prefix ~ $singular },
    { action => 'update',  verb => 'PUT',    path => $member,                      name => $member-name-prefix ~ $singular },
    { action => 'destroy', verb => 'DELETE', path => $member,                      name => $member-name-prefix ~ $singular };

  my $scope = ResourceScope.new(
    :collection-path($collection),
    :member-base($member-base),
    :controller($ctrl),
    :param($id),
    :$singular,
    :$plural,
    :collection-name-prefix($name-prefix),
    :$member-name-prefix,
    :shallow($shallow-on),
    :shallow-path($shallow-seg),
    :shallow-prefix($shallow-pre),
  );

  run-block-and-rest($router, $scope, $block, @rest,
    resolve-actions(<index create new edit show update destroy>, $only, $except));
}

sub add-singular-resource(
  MVC::Keayl::Router:D $router,
  Str:D $name,
       :$only, :$except, :$path, :$as, :$controller, :$module, :%path-names,
       :$block,
) is export {
  my $parent      = $*KEAYL-RESOURCE;
  my $ctx         = current-context();
  my $path-prefix = $parent.defined ?? $parent.child-prefix      !! $ctx.path-prefix;
  my $name-prefix = $parent.defined ?? $parent.child-name-prefix !! $ctx.name-prefix;

  my $segment   = $path // $name;
  my $singular  = $as // $name;
  my $ctrl      = $controller // ($ctx.module-prefix ~ ($module ?? $module ~ '/' !! '') ~ pluralize($name));
  my $new-seg   = %path-names<new>  // 'new';
  my $edit-seg  = %path-names<edit> // 'edit';

  my $base = $path-prefix ~ '/' ~ $segment;

  my @rest =
    { action => 'new',     verb => 'GET',    path => $base ~ '/' ~ $new-seg,  name => 'new-' ~ $name-prefix ~ $singular },
    { action => 'create',  verb => 'POST',   path => $base,                   name => $name-prefix ~ $singular },
    { action => 'edit',    verb => 'GET',    path => $base ~ '/' ~ $edit-seg, name => 'edit-' ~ $name-prefix ~ $singular },
    { action => 'show',    verb => 'GET',    path => $base,                   name => $name-prefix ~ $singular },
    { action => 'update',  verb => 'PATCH',  path => $base,                   name => $name-prefix ~ $singular },
    { action => 'update',  verb => 'PUT',    path => $base,                   name => $name-prefix ~ $singular },
    { action => 'destroy', verb => 'DELETE', path => $base,                   name => $name-prefix ~ $singular };

  my $scope = ResourceScope.new(
    :collection-path($base),
    :member-base($base),
    :controller($ctrl),
    :param('id'),
    :$singular,
    :plural($singular),
    :collection-name-prefix($name-prefix),
    :member-name-prefix($name-prefix),
    :is-singular,
  );

  run-block-and-rest($router, $scope, $block, @rest,
    resolve-actions(<create new edit show update destroy>, $only, $except));
}

sub add-resource-route(ResourceScope:D $scope, @verbs, Str:D $action, $to, Str:D $on, Str $as?) is export {
  my $route-path = do given $on {
    when 'collection' { $scope.collection-path ~ '/' ~ $action }
    when 'new'        { $scope.collection-path ~ '/new/' ~ $action }
    default           { $scope.member-path ~ '/' ~ $action }
  };

  my $target = $to // ($scope.controller ~ '#' ~ $action);

  my $name = $as // do given $on {
    when 'collection' { $scope.collection-name-prefix ~ $action ~ '-' ~ $scope.plural }
    default           { $scope.member-name-prefix ~ $action ~ '-' ~ $scope.singular }
  };

  $*KEAYL-ROUTER.add-route(@verbs, $route-path, $target, :$name, |current-context().route-args);
}
