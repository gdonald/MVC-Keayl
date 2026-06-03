# Routing

Routes are declared in `config/routes.raku` with a DSL that mirrors Rails'
`config/routes.rb`. A `routes` block builds a router that maps an incoming method
and path to a controller action or an inline handler.

```perl6
use MVC::Keayl::Routing;

routes {
  root to => 'home#index';

  get  '/users', to => 'users#index';
  post '/users', to => 'users#create';

  match '/search', to => 'search#run', via => <get post>;
}
```

## The draw block

`routes` (and its alias `draw`) takes a block and returns a
`MVC::Keayl::Router`. Inside the block the verb helpers register routes on that
router.

At boot the application loads the routes file with `load-routes`:

```perl6
my $router = load-routes('config/routes.raku');
```

`load-routes` evaluates the file and returns the router its `routes` block built.

## Verb helpers

`get`, `post`, `put`, `patch`, `delete`, and `options` each declare a route for
that method. The target is given with `to`:

```perl6
get '/users', to => 'users#index';   # controller#action
get '/ping',  to => sub { 'pong' };  # inline callable
```

A `'controller#action'` string target is split into a controller and an action.
A `Callable` target is kept as an inline handler. A `GET` route also answers
`HEAD`.

## match and via

`match` registers one path for several verbs. `via` accepts a single verb, a
list of verbs, the string `'all'`, or `*` for every verb:

```perl6
match '/search', to => 'search#run', via => <get post>;
match '/health', to => 'health#show', via => 'all';
match '/any',    to => 'catch#all',   via => *;
```

## root

`root` maps `GET /` to a target and names the route `root`:

```perl6
root to => 'home#index';
```

## Recognition

The router answers `recognize($method, $path)`, returning the matching route or
an undefined route when nothing matches:

```perl6
my $route = $router.recognize('GET', '/users');

$route.controller;   # 'users'
$route.action;       # 'index'
$route.verbs;        # ['GET', 'HEAD']
$route.callable;     # the inline handler, or an undefined Callable
```

`route-named($name)` looks a route up by its name.
