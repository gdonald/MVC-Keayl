use v6.d;
use MVC::Keayl::Endpoint;
use MVC::Keayl::Request;
use MVC::Keayl::Response;
use MVC::Keayl::Router;
use MVC::Keayl::Params;

unit class MVC::Keayl::Dispatcher does MVC::Keayl::Endpoint;

has $.router is required;
has @.controllers;
has %.controller-options;
has &.controller-resolver;
has Bool $.verbose-errors = False;
has %!registry;

submethod TWEAK {
  %!registry{.controller-path} = $_ for @!controllers;
}

method !resolve(Str:D $controller) {
  return &!controller-resolver($controller) if &!controller-resolver.defined;
  %!registry{$controller}:exists ?? %!registry{$controller} !! Mu
}

method call(MVC::Keayl::Request:D $request --> MVC::Keayl::Response:D) {
  my $match = $!router.recognize($request.method, $request.path);
  return self!not-found($request) without $match;

  with $match.callable -> &block {
    my $result = block($request);
    return $result ~~ MVC::Keayl::Response ?? $result !! MVC::Keayl::Response.new(body => ~$result);
  }

  my $class = self!resolve($match.controller);
  return self!not-found($request) if $class =:= Mu;

  self!invoke($class, $match, $request)
}

method !invoke($class, $match, MVC::Keayl::Request:D $request --> MVC::Keayl::Response:D) {
  my $controller = $class.new(
    request => $request,
    params  => build-params($match.params, $request),
    |%!controller-options,
  );

  return $controller.dispatch($match.action);

  CATCH {
    default { return self!server-error($_) }
  }
}

method !not-found(MVC::Keayl::Request:D $request --> MVC::Keayl::Response:D) {
  given $!router.recognition-status($request.method, $request.path) {
    when 'method-not-allowed' { MVC::Keayl::Response.new(status => 405, body => 'Method Not Allowed') }
    default                   { MVC::Keayl::Response.new(status => 404, body => 'Not Found') }
  }
}

method !server-error($error --> MVC::Keayl::Response:D) {
  my $body = $!verbose-errors
    ?? "Internal Server Error\n\n{$error.message}\n{$error.backtrace}"
    !! 'Internal Server Error';

  MVC::Keayl::Response.new(status => 500, body => $body)
}
