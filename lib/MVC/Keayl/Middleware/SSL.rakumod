use v6.d;
use MVC::Keayl::Middleware;
use MVC::Keayl::Request;
use MVC::Keayl::Response;

unit class MVC::Keayl::Middleware::SSL is MVC::Keayl::Middleware;

has Bool $.hsts               = True;
has Int  $.hsts-max-age       = 31536000;
has Bool $.include-subdomains = True;
has Bool $.preload            = False;

method call(MVC::Keayl::Request:D $request --> MVC::Keayl::Response:D) {
  return self!redirect-to-https($request) unless $request.is-ssl;

  my $response = self.app.call($request);
  $response.add-header('Strict-Transport-Security', self!hsts-value) if $!hsts;

  $response
}

method !redirect-to-https(MVC::Keayl::Request:D $request --> MVC::Keayl::Response:D) {
  my $host  = $request.host // 'localhost';
  my $path  = $request.path // '/';
  my $query = $request.query-string;
  my $url   = 'https://' ~ $host ~ $path ~ ($query ?? '?' ~ $query !! '');

  my $safe     = ($request.method // 'GET').uc (elem) <GET HEAD>;
  my $response = MVC::Keayl::Response.new;

  $response.status = $safe ?? 301 !! 307;
  $response.location($url);

  $response
}

method !hsts-value(--> Str) {
  my @parts = 'max-age=' ~ $!hsts-max-age;

  @parts.push('includeSubDomains') if $!include-subdomains;
  @parts.push('preload')           if $!preload;

  @parts.join('; ')
}
