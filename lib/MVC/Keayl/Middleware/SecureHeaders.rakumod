use v6.d;
use MVC::Keayl::Middleware;
use MVC::Keayl::Request;
use MVC::Keayl::Response;

unit class MVC::Keayl::Middleware::SecureHeaders is MVC::Keayl::Middleware;

sub default-headers(--> Hash) {
  %(
    'X-Frame-Options'                   => 'SAMEORIGIN',
    'X-Content-Type-Options'            => 'nosniff',
    'X-XSS-Protection'                  => '0',
    'X-Permitted-Cross-Domain-Policies' => 'none',
    'Referrer-Policy'                   => 'strict-origin-when-cross-origin',
  )
}

has %.headers = default-headers();
has %.also;

submethod TWEAK {
  %!headers{.key} = .value for %!also;
}

method call(MVC::Keayl::Request:D $request --> MVC::Keayl::Response:D) {
  my $response = self.app.call($request);

  for %!headers.sort(*.key) -> $pair {
    next without $pair.value;
    $response.add-header($pair.key, ~$pair.value) unless $response.has-header($pair.key);
  }

  $response
}
