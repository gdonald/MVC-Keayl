use v6.d;
use MVC::Keayl::Endpoint;
use MVC::Keayl::Middleware;
use MVC::Keayl::Request;
use MVC::Keayl::Response;

unit module MiddlewareFixtures;

# A terminal endpoint: returns a response whose body is its tag (default 'app').
class AppEndpoint does MVC::Keayl::Endpoint is export {
  has Str $.tag = 'app';

  method call(MVC::Keayl::Request:D $request --> MVC::Keayl::Response:D) {
    MVC::Keayl::Response.new(:body($!tag))
  }
}

# Wraps the downstream body in `tag(...)`, so a built chain renders its nesting:
# the outermost middleware appears outermost in the body.
class WrapMiddleware is MVC::Keayl::Middleware is export {
  has Str $.tag is required;

  method call(MVC::Keayl::Request:D $request --> MVC::Keayl::Response:D) {
    my $response = self.app.call($request);
    $response.body($!tag ~ '(' ~ $response.body ~ ')');
    $response
  }
}

# Short-circuits: returns its own response without calling the downstream app.
class HaltMiddleware is MVC::Keayl::Middleware is export {
  has Int $.status = 503;

  method call(MVC::Keayl::Request:D $request --> MVC::Keayl::Response:D) {
    MVC::Keayl::Response.new(:status($!status), :body('halted'))
  }
}
