# Middleware

MVC::Keayl processes a request through a stack of middleware wrapped around a
single innermost **endpoint**. The model mirrors Rack: each middleware receives
the downstream app, can act before and after delegating to it, and may
short-circuit by returning its own response.

## The endpoint protocol

An endpoint is anything that does the `MVC::Keayl::Endpoint` role: a single
`call` method that takes a [`Request`](request.md) and returns a
[`Response`](response.md):

```perl6
use MVC::Keayl::Endpoint;
use MVC::Keayl::Request;
use MVC::Keayl::Response;

class Hello does MVC::Keayl::Endpoint {
  method call(MVC::Keayl::Request:D $request --> MVC::Keayl::Response:D) {
    MVC::Keayl::Response.new(:body('Hello'));
  }
}
```

The router (see Routing) is the endpoint that sits innermost in the stack.

## Writing middleware

A middleware subclasses `MVC::Keayl::Middleware`. The base class holds the
downstream app in `app` and, by default, passes the request straight through.
Override `call` to wrap that delegation:

```perl6
use MVC::Keayl::Middleware;

class Timing is MVC::Keayl::Middleware {
  method call(MVC::Keayl::Request:D $request --> MVC::Keayl::Response:D) {
    # ... before ...
    my $response = self.app.call($request);
    # ... after ...
    $response;
  }
}
```

A middleware that returns a response **without** calling `self.app` short-circuits
the rest of the stack, useful for authentication gates, caching, and the like.

## The stack

`MVC::Keayl::MiddlewareStack` is an ordered, named collection of middleware. The
first entry added is the **outermost** (it sees the request first and the
response last).

```perl6
use MVC::Keayl::MiddlewareStack;

my $stack = MVC::Keayl::MiddlewareStack.new;

$stack.use('logger', Logging);
$stack.use('timing', Timing);
```

Construction arguments after the class are forwarded to the middleware's `new`
alongside `app`:

```perl6
$stack.use('host-guard', HostAuthorization, :allowed<example.com>);
```

### Reordering

Entries are addressed by name:

```perl6
$stack.insert-before('timing', 'request-id', RequestId);
$stack.insert-after('logger', 'ssl', ForceSSL);
$stack.delete('timing');
```

`insert-before` and `insert-after` raise if the named target is not in the stack.

### Introspection

```perl6
$stack.names;            # ('logger', 'timing'), in order
$stack.elems;            # 2
$stack.contains('ssl');  # False
```

### Building the app

`build` wraps an endpoint with the whole stack and returns the resulting app,
itself an endpoint you `call`:

```perl6
my $app = $stack.build($router);

my $response = $app.call($request);
```

An empty stack returns the endpoint unwrapped.

## Serving static files

`MVC::Keayl::Middleware::Static` serves files from a directory and passes every
other request through to the app. It suits development and small deployments; in
production a front-end server such as Apache or nginx usually serves the files
directly.

```perl6
use MVC::Keayl::Middleware::Static;

$stack.prepend('static', MVC::Keayl::Middleware::Static, root => 'public'.IO);
```

A request maps to a file beneath `root`, so `GET /css/app.css` serves
`public/css/app.css`. Only `GET` and `HEAD` are handled; any other method, a
missing file, or a directory passes through to the app. The content type is
derived from the file extension, falling back to `application/octet-stream`.
Parent-directory segments are refused, so a request cannot escape `root`.

`url-prefix` serves a directory beneath a path prefix, stripping it before the
lookup. With the settings below, `GET /assets/css/app.css` serves
`assets/css/app.css`, while a path outside the prefix passes through:

```perl6
$stack.prepend('static', MVC::Keayl::Middleware::Static,
  root       => 'assets'.IO,
  url-prefix => '/assets');
```

Prepending keeps it outermost, so a matched file short-circuits before routing.
