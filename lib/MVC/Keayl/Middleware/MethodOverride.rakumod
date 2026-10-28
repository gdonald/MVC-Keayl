use v6.d;
use MVC::Keayl::Middleware;
use MVC::Keayl::Request;
use MVC::Keayl::Response;
use MVC::Keayl::Params;

unit class MVC::Keayl::Middleware::MethodOverride is MVC::Keayl::Middleware;

my constant OVERRIDABLE-METHODS = <PATCH PUT DELETE>;
my constant FORM-CONTENT-TYPES  = <application/x-www-form-urlencoded multipart/form-data>;

method call(MVC::Keayl::Request:D $request --> MVC::Keayl::Response:D) {
  my $override = self!override-for($request);

  self.app.call($override.defined ?? $request.with-method($override) !! $request)
}

method !override-for(MVC::Keayl::Request:D $request --> Str) {
  return Str unless $request.is-post;

  my $requested = $request.header('X-HTTP-Method-Override') // self!form-method($request);
  return Str without $requested;

  my $method = $requested.uc;
  OVERRIDABLE-METHODS.first($method) // Str
}

method !form-method(MVC::Keayl::Request:D $request --> Str) {
  my $content-type = $request.header('content-type') // '';
  return Str unless FORM-CONTENT-TYPES.first({ $content-type.contains($_) });

  my $method = parse-body($request)<_method>;
  $method ~~ Str ?? $method !! Str
}
