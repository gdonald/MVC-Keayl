use v6.d;
use MVC::Keayl::Middleware;
use MVC::Keayl::Request;
use MVC::Keayl::Response;
use Crypt::Random;

unit class MVC::Keayl::Middleware::RequestId is MVC::Keayl::Middleware;

sub default-request-id(--> Str) {
  crypt_random_buf(16).list.map(*.fmt('%02x')).join
}

has Str $.header    = 'X-Request-Id';
has     &.generator = &default-request-id;

method call(MVC::Keayl::Request:D $request --> MVC::Keayl::Response:D) {
  my $id = self!incoming($request) // &!generator();

  my $response;
  {
    my $*KEAYL-REQUEST-ID = $id;
    $response = self.app.call($request);
  }

  $response.set-header($!header, $id) without $response.header($!header);
  $response
}

method !incoming(MVC::Keayl::Request:D $request --> Str) {
  my $incoming = $request.header($!header);
  return Str without $incoming;
  return Str unless $incoming ~~ / ^ <[ \w \- ]> ** 1..255 $ /;

  ~$incoming
}
