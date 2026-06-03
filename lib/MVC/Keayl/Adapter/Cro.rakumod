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
has     $!server;

my class Bridge does Cro::Transform {
  has $.adapter is required;

  method consumes() { Cro::HTTP::Request }
  method produces() { Cro::HTTP::Response }

  method transformer(Supply:D $in --> Supply:D) {
    supply {
      whenever $in -> $request {
        my $response = Cro::HTTP::Response.new(:$request);

        whenever $request.body-blob -> $blob {
          $!adapter.fill-response($request, $blob, $response);
          emit $response;
        }
      }
    }
  }
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

method fill-response(
  Cro::HTTP::Request:D $cro-request,
  Blob:D $body,
  Cro::HTTP::Response:D $cro-response,
  --> Cro::HTTP::Response
) {
  my $request = self.build-request($cro-request, $body);
  my ($status, $headers, $blob) = self.handle($request);

  $cro-response.status = $status;

  for $headers.list -> $pair {
    # Cro derives Content-Length from the body it serializes.
    next if $pair.key.lc eq 'content-length';
    $cro-response.append-header($pair.key, $pair.value);
  }

  $cro-response.set-body($blob);

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
