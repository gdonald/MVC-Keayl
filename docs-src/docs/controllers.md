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
