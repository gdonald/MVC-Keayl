use v6.d;
use Cro;
use Cro::HTTP::Server;
use Cro::HTTP::Request;
use Cro::HTTP::Response;
use MVC::Keayl::Adapter;
use MVC::Keayl::Request;

unit class MVC::Keayl::Adapter::Cro does MVC::Keayl::Adapter;

has Str $.host = '127.0.0.1';
has Int $.port is required;
has Str $.scheme = 'http';
has     $.request-log-dir = %*ENV<KEAYL_REQUEST_LOG>;
has     $!server;

my class Bridge does Cro::Transform {
  has $.adapter is required;

  method consumes() { Cro::HTTP::Request }
  method produces() { Cro::HTTP::Response }

  method transformer(Supply:D $in --> Supply:D) {
    supply {
      whenever $in -> $request {
        $!adapter.log-request-event($request, "received {$request.method} {$request.target}");

        my $response = Cro::HTTP::Response.new(:$request);

        whenever $request.body-blob -> $blob {
          $!adapter.log-request-event($request, 'body');
          $!adapter.fill-response($request, $blob, $response);

          emit $response;
          $!adapter.log-request-event($request, 'emitted');
        }
      }
    }
  }
}

method log-request-event(Cro::HTTP::Request:D $request, Str:D $event --> Nil) {
  return without $!request-log-dir;

  my $time = DateTime.now.utc;
  my $peer = $request.connection.?peer-port // '-';

  my $line = sprintf "%04d-%02d-%02dT%02d:%02d:%06.3fZ port=%s peer=%s %s\n",
    $time.year, $time.month, $time.day, $time.hour, $time.minute, $time.second,
    $!port, $peer, $event;

  $!request-log-dir.IO.add("requests-{$*PID}.log").spurt($line, :append);
}

method build-request(Cro::HTTP::Request:D $cro, Blob:D $body --> MVC::Keayl::Request) {
  my %headers;

  for $cro.headers -> $header {
    %headers{$header.name} = %headers{$header.name}:exists
      ?? [ |%headers{$header.name}.list, $header.value ]
      !! $header.value;
  }

  MVC::Keayl::Request.new(
    :method($cro.method),
    :target($cro.target),
    :%headers,
    :body($body),
    :scheme($!scheme),
    :remote-address($cro.connection.?peer-host // Str),
  )
}

method !apply-headers(Cro::HTTP::Response:D $cro-response, $headers --> Nil) {
  for $headers.list -> $pair {
    # Cro derives Content-Length from the body it serializes.
    next if $pair.key.lc eq 'content-length';
    $cro-response.append-header($pair.key, $pair.value);
  }
}

method fill-response(
  Cro::HTTP::Request:D $cro-request,
  Blob:D $body,
  Cro::HTTP::Response:D $cro-response,
  --> Cro::HTTP::Response
) {
  my $request  = self.build-request($cro-request, $body);
  my $response = self.app.call($request);

  self.log-request-event($cro-request, "called {$response.status}");

  if $response.is-streaming {
    my ($status, $headers) = $response.streaming-finish;
    $cro-response.status = $status;
    self!apply-headers($cro-response, $headers);
    $cro-response.set-body-byte-stream($response.stream-supply);
  } else {
    my ($status, $headers, $blob) = $response.finish;
    $cro-response.status = $status;
    self!apply-headers($cro-response, $headers);
    $cro-response.set-body($blob);
  }

  $cro-response
}

method start(--> Nil) {
  $!server = Cro::HTTP::Server.new(
    :$!host,
    :$!port,
    application => Bridge.new(:adapter(self)),
  );

  $!server.start;
}

method stop(--> Nil) {
  .stop with $!server;
  $!server = Nil;
}
