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

## Path patterns

A path can carry dynamic segments, a glob, optional groups, a format, and
per-segment constraints. The matched values become params on recognition.

```perl6
get '/users/:id',          to => 'users#show';     # :id captures one segment
get '/files/*path',        to => 'files#serve';    # *path captures the rest, slashes included
get '/users(/:id)',        to => 'users#index';    # (...) is an optional group
get '/users/:id(.:format)', to => 'users#show';    # (.:format) peels off an extension
```

A `:segment` matches a single path segment, stopping at a `/` or a `.`. A
`*glob` matches everything that remains, including slashes. Anything inside
`(...)` is optional.

`format => True` appends an optional `(.:format)` segment without writing it out:

```perl6
get '/users/:id', to => 'users#show', format => True;
```

`defaults` supplies values for params that are absent from the path, and
`constraints` restricts a segment to a pattern. A request whose segment fails the
constraint falls through to the next route:

```perl6
get '/users/:id', to => 'users#show',
  constraints => { id => /^\d+$/ },
  defaults    => { format => 'html' };
```

## Resources

`resources` declares the seven REST routes for a resource in one call:

```perl6
resources 'users';
```

| Verb           | Path              | Action  | Name        |
| -------------- | ----------------- | ------- | ----------- |
| GET            | `/users`          | index   | `users`     |
| POST           | `/users`          | create  | `users`     |
| GET            | `/users/new`      | new     | `new-user`  |
| GET            | `/users/:id`      | show    | `user`      |
| GET            | `/users/:id/edit` | edit    | `edit-user` |
| PATCH / PUT    | `/users/:id`      | update  | `user`      |
| DELETE         | `/users/:id`      | destroy | `user`      |

Pass several names to declare more than one resource at once:

```perl6
resources 'users', 'posts';
```

### Limiting actions

`only` and `except` choose which of the seven actions to generate:

```perl6
resources 'users', :only<index show>;
resources 'photos', :except<destroy>;
```

### Member and collection routes

A block adds extra routes. `member` routes act on a single record (`/:id`),
`collection` routes act on the set:

```perl6
resources 'photos', {
  member {
    get 'preview', to => 'photos#preview';      # GET /photos/:id/preview
  }
  collection {
    get 'search', to => 'photos#search';        # GET /photos/search
  }
}
```

`on` does the same for a single route without a block:

```perl6
resources 'photos', {
  get 'stats', to => 'photos#stats', on => 'collection';
}
```

Member route names are suffixed with the singular (`preview-photo`), collection
routes with the plural (`search-photos`).

### Resource options

| Option        | Effect                                                            |
| ------------- | ---------------------------------------------------------------- |
| `path`        | Override the URL segment (`/team` instead of `/people`).         |
| `as`          | Override the helper name base.                                   |
| `controller`  | Override the target controller.                                  |
| `module`      | Prefix the controller (`admin/posts`).                          |
| `param`       | Rename the member key (`:slug` instead of `:id`).               |
| `path-names`  | Rename the `new` and `edit` URL segments.                       |

```perl6
resources 'people',
  path        => 'team',
  controller  => 'staff',
  param       => 'slug',
  path-names  => { new => 'neu', edit => 'bearbeiten' };
```

## Recognition

The router answers `recognize($method, $path)`, returning a match or an
undefined match when nothing fits:

```perl6
my $match = $router.recognize('GET', '/users/42');

$match.controller;   # 'users'
$match.action;       # 'show'
$match.params;       # { id => '42' }
$match.callable;     # the inline handler, or an undefined Callable
$match.route;        # the matched route
```

`route-named($name)` looks a route up by its name.
