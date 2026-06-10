use v6.d;
use MVC::Keayl::Middleware;
use MVC::Keayl::Request;
use MVC::Keayl::Response;
use MVC::Keayl::Logger;
use MVC::Keayl::LogEvent;

unit class MVC::Keayl::Middleware::Logger is MVC::Keayl::Middleware;

has MVC::Keayl::Logger $.logger = MVC::Keayl::Logger.new;
has                    &.clock  = sub { now };

method call(MVC::Keayl::Request:D $request --> MVC::Keayl::Response:D) {
  return self.app.call($request) unless $!logger.enabled('info');

  my $event = MVC::Keayl::LogEvent.new(
    method     => $request.method,
    path       => $request.path,
    request-id => ($*KEAYL-REQUEST-ID // Str),
    clock      => &!clock,
  );

  my $start = &!clock.();

  my $response;
  {
    my $*KEAYL-LOG-EVENT = $event;
    $response = self.app.call($request);
  }

  $event.status = $response.status;
  $!logger.info(format-line($event, &!clock.() - $start));

  $response
}

sub milliseconds($seconds --> Str) {
  sprintf '%.2fms', $seconds * 1000
}

sub format-params(%params --> Str) {
  '{' ~ %params.sort(*.key).map({ "{.key}={.value.gist}" }).join(', ') ~ '}'
}

sub format-line(MVC::Keayl::LogEvent:D $event, $total --> Str) {
  my $head = $event.target.defined
    ?? "{$event.method} {$event.path} → {$event.target}"
    !! "{$event.method} {$event.path}";

  my @parts = "$head {$event.status} in {milliseconds($total)}";

  @parts.push("action={milliseconds($_)}") with $event.timing('action');
  @parts.push("view={milliseconds($_)}")   with $event.timing('view');

  my $line = @parts.join(' ');
  $line ~= " params={format-params($event.params)}" if $event.params;
  $line = "[{$event.request-id}] $line" with $event.request-id;

  $line
}
