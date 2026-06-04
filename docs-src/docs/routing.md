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

| Verb        | Path              | Action  | Name        |
| ----------- | ----------------- | ------- | ----------- |
| GET         | `/users`          | index   | `users`     |
| POST        | `/users`          | create  | `users`     |
| GET         | `/users/new`      | new     | `new-user`  |
| GET         | `/users/:id`      | show    | `user`      |
| GET         | `/users/:id/edit` | edit    | `edit-user` |
| PATCH / PUT | `/users/:id`      | update  | `user`      |
| DELETE      | `/users/:id`      | destroy | `user`      |

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

| Option       | Effect                                                   |
| ------------ | -------------------------------------------------------- |
| `path`       | Override the URL segment (`/team` instead of `/people`). |
| `as`         | Override the helper name base.                           |
| `controller` | Override the target controller.                          |
| `module`     | Prefix the controller (`admin/posts`).                   |
| `param`      | Rename the member key (`:slug` instead of `:id`).        |
| `path-names` | Rename the `new` and `edit` URL segments.                |

```perl6
resources 'people',
  path        => 'team',
  controller  => 'staff',
  param       => 'slug',
  path-names  => { new => 'neu', edit => 'bearbeiten' };
```

## Singular resources

`resource` declares a resource with no index and no `:id`, for a thing there is
only one of per request (a profile, an account):

```perl6
resource 'profile';
```

| Verb        | Path            | Action  | Name           |
| ----------- | --------------- | ------- | -------------- |
| GET         | `/profile/new`  | new     | `new-profile`  |
| POST        | `/profile`      | create  | `profile`      |
| GET         | `/profile`      | show    | `profile`      |
| GET         | `/profile/edit` | edit    | `edit-profile` |
| PATCH / PUT | `/profile`      | update  | `profile`      |
| DELETE      | `/profile`      | destroy | `profile`      |

The controller defaults to the plural (`profiles`). `resource` takes the same
options as `resources` (`only`, `except`, `path`, `as`, `controller`, `module`,
`path-names`, and `member`/`collection` blocks).

## Nesting

Resources nest inside a resource block. A nested resource is scoped under the
parent member, and its key is named after the parent:

```perl6
resources 'magazines', {
  resources 'ads';
}
```

This produces `/magazines/:magazine_id/ads`, `/magazines/:magazine_id/ads/:id`,
and so on, with helper names prefixed by the parent singular (`magazine-ads`,
`magazine-ad`, `new-magazine-ad`, `edit-magazine-ad`). Plural and singular
resources nest either way, and nesting can go more than one level deep, though
nesting more than one level deep is usually a sign the routes want flattening.

### Shallow nesting

`shallow` keeps the collection routes (index, new, create) nested but lifts the
member routes (show, edit, update, destroy) to the top level, so member URLs stay
short:

```perl6
resources 'magazines', :shallow, {
  resources 'ads';
}
```

Collection routes stay at `/magazines/:magazine_id/ads`, while member routes move
to `/ads/:id`. The member helpers drop the parent prefix (`ad` rather than
`magazine-ad`). `shallow-path` overrides the shallow member segment and
`shallow-prefix` overrides the shallow member name prefix:

```perl6
resources 'ads', :shallow, :shallow-path<a>, :shallow-prefix<x>;
```

## Namespaces and scopes

`namespace` prefixes the path, the controller module, and the helper name all at
once:

```perl6
namespace 'admin', {
  resources 'users';        # /admin/users => admin/users, named admin-users
}
```

`scope` controls each of those independently:

```perl6
scope(path => 'api', module => 'v1', as => 'api', {
  get '/ping', to => 'ping#show', as => 'ping';   # /api/ping => v1/ping#show, named api-ping
});
```

`controller` sets the controller for the routes inside, so a target can be just
an action and a bare path defaults its action:

```perl6
controller 'photos', {
  get '/preview', to => 'show';   # photos#show
  get '/list';                    # photos#list
}
```

An optional scope segment is written with parentheses, which suits an i18n locale
prefix that may or may not be present:

```perl6
scope('(:locale)', {
  get '/about', to => 'pages#about';   # matches /about and /en/about
});
```

Scopes nest and compose their prefixes.

## Concerns

A concern is a reusable block of routes. Define it once with `concern`, then mix
it into resources with the `concerns` option or a `concerns` call inside a block:

```perl6
concern 'commentable', { resources 'comments' };

resources 'posts', concerns => 'commentable';
resources 'photos', { concerns 'commentable' };
```

Concern routes nest under the resource that mixes them in, so
`/posts/:post_id/comments` and `/photos/:photo_id/comments` both appear.

## Constraints and defaults

A `constraints` block restricts the routes inside it. Segment keys constrain path
params, while `subdomain`, `host`, `format`, `protocol`, `port`, and `method`
constrain request attributes:

```perl6
constraints(:id(/^\d+$/), {
  get '/items/:id', to => 'items#show';        # /items/42 matches, /items/abc does not
});

constraints(:subdomain<api>, {
  get '/data', to => 'data#index';             # only when the request subdomain is api
});
```

A custom constraint is a callable that receives the request context, or an object
with a `matches` method:

```perl6
constraints(-> %context { %context<host>.ends-with('.internal') }, {
  get '/admin', to => 'admin#index';
});
```

Request constraints are checked during recognition against a context hash:

```perl6
$router.recognize('GET', '/data', context => { subdomain => 'api' });
```

A `defaults` block supplies default params for the routes inside it:

```perl6
defaults(format => 'json', {
  get '/api/users', to => 'users#index';       # params include format => 'json'
});
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
