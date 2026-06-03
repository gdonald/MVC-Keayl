# Request

`MVC::Keayl::Request` is a read-only wrapper around a single incoming HTTP
request. The server adapter builds one per request from the raw method, target,
headers, body, connection scheme, and peer address; controllers and middleware
then read from it through a small, stable accessor surface.

```perl6
use MVC::Keayl::Request;

my $request = MVC::Keayl::Request.new(
  :method<POST>,
  :target('/users?role=admin'),
  :headers({ Host => 'example.com:3000', 'Content-Type' => 'application/json' }),
  :scheme<https>,
  :remote-address('203.0.113.5'),
  :body('{"name":"Ada"}'),
);
```

## Construction

| Named argument    | Meaning                                                                  |
| ----------------- | ------------------------------------------------------------------------ |
| `:method`         | HTTP verb; normalized to uppercase. Defaults to `GET`.                   |
| `:target`         | Raw request target (`path?query`); split into `path` and `query-string`. |
| `:path`           | Path, when not supplying `:target`. Defaults to `/`.                     |
| `:query-string`   | Query string, when not supplying `:target`. Defaults to empty.           |
| `:headers`        | A hash of header names to values; names are matched case-insensitively.  |
| `:scheme`         | Connection scheme (`http` / `https`); normalized to lowercase.           |
| `:remote-address` | The peer address reported by the connection.                             |
| `:body`           | The request body: a `Str`, a `Blob`, or a `Callable` read lazily.        |

Supplying `:target` takes precedence over `:path` / `:query-string`.

## Method and verb predicates

`method` returns the normalized verb. Each predicate is an exact match:

```perl6
$request.method;      # 'POST'

$request.is-get;      # False
$request.is-post;     # True
$request.is-put;
$request.is-patch;
$request.is-delete;
$request.is-head;
```

## Path and query string

```perl6
$request.path;          # '/users'
$request.query-string;  # 'role=admin'
```

`query-params` parses the query string on first access (and memoizes it).
Values are percent- and plus-decoded, and repeated keys collect into an ordered
array:

```perl6
# /search?q=a%20b&tag=x&tag=y
$request.query-params;     # { q => 'a b', tag => ['x', 'y'] }
```

## Headers

Header lookups are case-insensitive, and multi-value headers are joined with
`, `:

```perl6
$request.header('content-type');   # 'application/json'
$request.has-header('Host');       # True
$request.has-header('x-missing');  # False
```

`is-xhr` reports an AJAX request (`X-Requested-With: XMLHttpRequest`):

```perl6
$request.is-xhr;   # True when the header is present
```

## Scheme, host, port, and SSL

These derive from the connection and from proxy headers, so they are correct
behind a reverse proxy:

```perl6
$request.scheme;     # 'https'  (X-Forwarded-Proto overrides the connection scheme)
$request.is-ssl;     # True when the scheme is https

$request.host;       # 'example.com'  (X-Forwarded-Host overrides Host; port stripped)
$request.port;       # 3000
```

`port` is resolved in order: an explicit port on the host header, then
`X-Forwarded-Port`, then the scheme default (`443` for https, `80` for http).

## Remote IP

`remote-ip` prefers the first entry of `X-Forwarded-For` (the originating
client) and falls back to the connection's peer address:

```perl6
# X-Forwarded-For: 203.0.113.5, 10.0.0.1
$request.remote-ip;   # '203.0.113.5'
```

## Body

The body is read lazily. A `Callable` source is invoked only on the first call
to `body`, and the result is memoized. A `Blob` is decoded as UTF-8, and a
missing body reads as the empty string:

```perl6
$request.body;   # '{"name":"Ada"}'
```

Reading the raw body never consumes or parses it; structured parameter parsing
(form bodies, JSON, multipart) is layered on top by the controller.
