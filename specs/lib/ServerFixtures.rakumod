use v6.d;
use MVC::Keayl::Endpoint;
use MVC::Keayl::Request;
use MVC::Keayl::Response;

unit module ServerFixtures;

# An endpoint that reflects the request back through the response, so a test can
# assert how a request was translated by inspecting the response.
class EchoEndpoint does MVC::Keayl::Endpoint is export {
  method call(MVC::Keayl::Request:D $request --> MVC::Keayl::Response:D) {
    my $response = MVC::Keayl::Response.new;

    $response.set-header('X-Method', $request.method);
    $response.set-header('X-Path', $request.path);
    $response.set-header('X-Query', $request.query-string);
    $response.set-header('X-Host', $request.header('host') // '');
    $response.set-header('X-Remote-IP', $request.remote-ip // '');
    $response.body($request.body);

    $response
  }
}

# Bind an ephemeral listener to discover a free localhost port for an
# integration server.
sub free-port(--> Int) is export {
  my $tap  = IO::Socket::Async.listen('127.0.0.1', 0).tap(-> $c { $c.close });
  my $port = await $tap.socket-port;

  $tap.close;
  $port
}
