use v6.d;
use MVC::Keayl::Middleware;
use MVC::Keayl::Request;
use MVC::Keayl::Response;

unit class MVC::Keayl::Middleware::HostAuthorization is MVC::Keayl::Middleware;

has @.allowed;

method call(MVC::Keayl::Request:D $request --> MVC::Keayl::Response:D) {
  return self!blocked unless self!permitted($request.host);
  self.app.call($request)
}

method !permitted($host --> Bool) {
  return False without $host;
  return True unless @!allowed;

  for @!allowed -> $allowed {
    return True if $allowed ~~ Regex && $host ~~ $allowed;

    next unless $allowed ~~ Str;

    if $allowed.starts-with('.') {
      return True if $host eq $allowed.substr(1) || $host.ends-with($allowed);
    } elsif $host eq $allowed {
      return True;
    }
  }

  False
}

method !blocked(--> MVC::Keayl::Response:D) {
  my $response = MVC::Keayl::Response.new;

  $response.status = 403;
  $response.content-type('text/plain; charset=utf-8');
  $response.body('Blocked host');

  $response
}
