# Controllers

A controller is a subclass of `MVC::Keayl::Controller`. Each public method is an
action. The framework builds one controller instance per request, dispatches the
named action on it, and returns the [response](response.md).

```perl6
use MVC::Keayl::Controller;

class UsersController is MVC::Keayl::Controller {
  method index {
    'all users';
  }

  method show {
    'user ' ~ self.params<id>;
  }
}
```

## Per-request state

A controller instance carries the request, a fresh response, and the merged
params for that request:

```perl6
self.request;    # the incoming Request
self.response;   # the outgoing Response
self.params;     # path, query, and body params
```

Each instance gets its own response, so actions never share state across
requests.

## Params

`self.params` merges the path params (from routing), the query string, and the
request body into one `MVC::Keayl::Parameters` collection. Path params win over
the body, which wins over the query. Access is indifferent: a key is coerced to a
string, so `params<id>` and `params{5}` reach the same value.

Bracketed names build nested structures, the same way Rack does:

```
user[name]=Ada&user[email]=a@b.com   # params<user><name>, params<user><email>
ids[]=1&ids[]=2                      # params<ids> is ['1', '2']
user[roles][]=admin                  # params<user><roles> is ['admin']
users[][name]=A&users[][age]=1       # params<users>[0] is { name => 'A', age => '1' }
```

The body is parsed by its `Content-Type`:

- `application/x-www-form-urlencoded` parses like a query string.
- `application/json` parses the JSON object into params.
- `multipart/form-data` parses text fields, and file fields into a
  `{ filename, content, type }` hash.

`build-params(%path-params, $request)` produces the merged `Parameters` for a
request, which the dispatcher passes to the controller.

## Dispatch and implicit render

`dispatch($action)` runs the named action and returns the response. An action
interacts with the response directly:

```perl6
method create {
  self.response.status = 201;
  self.response.body('created');
}
```

When an action does not write to the response, its return value is rendered
implicitly. An action whose body is still empty has its string return value
written to the response:

```perl6
method show {
  'user ' ~ self.params<id>;   # becomes the response body
}
```

Only actions defined on the controller are dispatchable. Dispatching an unknown
action, or one of the base controller's own methods, raises.
