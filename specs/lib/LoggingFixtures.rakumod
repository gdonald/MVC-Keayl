use v6.d;
use MVC::Keayl::Endpoint;
use MVC::Keayl::Request;
use MVC::Keayl::Response;

unit module LoggingFixtures;

# A deterministic clock: successive calls return 0, step, 2*step, ... so a test
# can assert exact durations instead of wall-clock time.
sub step-clock(Numeric :$step = 0.001 --> Sub) is export {
  my $count = 0;
  sub { my $value = $count * $step; $count++; $value }
}

# An endpoint that answers with a fixed status, for exercising middleware
# without a controller.
class StatusEndpoint does MVC::Keayl::Endpoint is export {
  has Int $.status = 200;

  method call(MVC::Keayl::Request:D $request --> MVC::Keayl::Response:D) {
    MVC::Keayl::Response.new(status => $!status, body => 'ok')
  }
}
