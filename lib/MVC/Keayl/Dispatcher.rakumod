use v6.d;
use MVC::Keayl::Endpoint;
use MVC::Keayl::Request;
use MVC::Keayl::Response;
use MVC::Keayl::Router;
use MVC::Keayl::Params;
use MVC::Keayl::Notifications;
use MVC::Keayl::ParameterFilter;
use MVC::Keayl::ErrorReporting;
use MVC::Keayl::ExceptionPage;

unit class MVC::Keayl::Dispatcher does MVC::Keayl::Endpoint;

has $.router is required;
has @.controllers;
has %.controller-options;
has &.controller-resolver;
has Bool $.verbose-errors = False;
has MVC::Keayl::ErrorReporting $.error-reporting = MVC::Keayl::ErrorReporting.new;
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

  with $match.target -> $target {
    if $target.^can('app') {
      my $app         = $target.app;
      my $sub-request = $request.rebase('/' ~ ($match.params<mounted_path> // ''));
      my $result      = $app ~~ Callable ?? $app($sub-request) !! $app.call($sub-request);

      return $result ~~ MVC::Keayl::Response ?? $result !! MVC::Keayl::Response.new(body => ~$result);
    }
  }

  my $class = self!resolve($match.controller);
  return self!not-found($request) if $class =:= Mu;

  MVC::Keayl::Notifications.instrument(
    'dispatch.keayl',
    %(
      controller => $match.controller,
      action     => $match.action,
      method     => $request.method,
      path       => $request.path,
      request-id => ($*KEAYL-REQUEST-ID // Str),
    ),
    { self!invoke($class, $match, $request) },
  )
}

method !invoke($class, $match, MVC::Keayl::Request:D $request --> MVC::Keayl::Response:D) {
  my %context = self!error-context($match, $request);

  # Construct with `.bless`, not `.new`: a RESTful controller may define a `new`
  # action (GET /resource/new), which would otherwise shadow the `.new`
  # constructor and be invoked on the type object during instantiation.
  my $controller = $class.bless(
    request => $request,
    params  => build-params($match.params, $request),
    |%!controller-options,
  );

  return $controller.dispatch($match.action);

  CATCH {
    default { return self!server-error($_, %context) }
  }
}

method !error-context($match, MVC::Keayl::Request:D $request --> Hash) {
  my %params = (try MVC::Keayl::ParameterFilter.new.filter(build-params($match.params, $request))) // %();

  %(
    request    => $request,
    method     => $request.method,
    path       => $request.path,
    controller => $match.controller,
    action     => $match.action,
    params     => %params,
    request-id => ($*KEAYL-REQUEST-ID // Str),
  )
}

method !not-found(MVC::Keayl::Request:D $request --> MVC::Keayl::Response:D) {
  given $!router.recognition-status($request.method, $request.path) {
    when 'method-not-allowed' { MVC::Keayl::Response.new(status => 405, body => 'Method Not Allowed') }
    default                   { MVC::Keayl::Response.new(status => 404, body => 'Not Found') }
  }
}

method !server-error($error, %context --> MVC::Keayl::Response:D) {
  $!error-reporting.report($error, %context);

  return self!developer-error($error, %context) if $!verbose-errors;

  MVC::Keayl::Response.new(status => 500, body => 'Internal Server Error')
}

method !developer-error($error, %context --> MVC::Keayl::Response:D) {
  my $page     = developer-exception-page($error, %context, $!router.route-table);
  my $response = MVC::Keayl::Response.new(status => 500, body => $page);

  $response.content-type('text/html; charset=utf-8');
  $response
}
