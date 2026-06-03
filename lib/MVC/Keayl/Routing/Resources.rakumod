use v6.d;
use MVC::Keayl::Router;

unit module MVC::Keayl::Routing::Resources;

class ResourceScope {
  has Str $.path;
  has Str $.controller;
  has Str $.param;
  has Str $.singular;
  has Str $.plural;
}

sub singularize(Str:D $word --> Str) is export {
  return $word.subst(/ies$/, 'y')            if $word ~~ /ies$/;
  return $word.subst(/(s|x|z|ch|sh)es$/, {$0}) if $word ~~ /(s|x|z|ch|sh)es$/;
  return $word.subst(/s$/, '')               if $word ~~ /s$/;
  $word
}

sub resolve-actions($only, $except --> List) {
  my @actions = <index create new edit show update destroy>;

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

sub add-resource(
  MVC::Keayl::Router:D $router,
  Str:D $name,
       :$only,
       :$except,
       :$path,
       :$as,
       :$controller,
       :$module,
       :$param,
       :%path-names,
       :$block,
) is export {
  my $segment    = $path // $name;
  my $ctrl       = $controller // ($module ?? "$module/$name" !! $name);
  my $plural     = $as // $name;
  my $singular   = singularize($plural);
  my $id         = $param // 'id';
  my $new-seg    = %path-names<new>  // 'new';
  my $edit-seg   = %path-names<edit> // 'edit';

  my $collection = '/' ~ $segment;
  my $member     = '/' ~ $segment ~ '/:' ~ $id;

  my @rest =
    { action => 'index',   verb => 'GET',    path => $collection,                name => $plural },
    { action => 'new',     verb => 'GET',    path => $collection ~ '/' ~ $new-seg, name => 'new-' ~ $singular },
    { action => 'create',  verb => 'POST',   path => $collection,                name => $plural },
    { action => 'edit',    verb => 'GET',    path => $member ~ '/' ~ $edit-seg,   name => 'edit-' ~ $singular },
    { action => 'show',    verb => 'GET',    path => $member,                    name => $singular },
    { action => 'update',  verb => 'PATCH',  path => $member,                    name => $singular },
    { action => 'update',  verb => 'PUT',    path => $member,                    name => $singular },
    { action => 'destroy', verb => 'DELETE', path => $member,                    name => $singular };

  # Custom member/collection routes are registered before the REST routes so a
  # collection route like `/photos/search` is matched ahead of `show`
  # (`/photos/:id`).
  with $block {
    my $scope = ResourceScope.new(:path($segment), :controller($ctrl), :param($id), :singular($singular), :plural($plural));

    my $*KEAYL-RESOURCE = $scope;
    my $*KEAYL-ON;

    $block();
  }

  my %wanted;
  %wanted{$_} = True for resolve-actions($only, $except);

  for @rest -> %route {
    next unless %wanted{%route<action>};
    $router.add-route([%route<verb>], %route<path>, $ctrl ~ '#' ~ %route<action>, :name(%route<name>));
  }
}

sub add-resource-route(ResourceScope:D $scope, @verbs, Str:D $action, $to, Str:D $on, Str $as?) is export {
  my $route-path = do given $on {
    when 'collection' { '/' ~ $scope.path ~ '/' ~ $action }
    when 'new'        { '/' ~ $scope.path ~ '/new/' ~ $action }
    default           { '/' ~ $scope.path ~ '/:' ~ $scope.param ~ '/' ~ $action }
  };

  my $target = $to // ($scope.controller ~ '#' ~ $action);

  my $name = $as // do given $on {
    when 'collection' { $action ~ '-' ~ $scope.plural }
    default           { $action ~ '-' ~ $scope.singular }
  };

  $*KEAYL-ROUTER.add-route(@verbs, $route-path, $target, :$name);
}
