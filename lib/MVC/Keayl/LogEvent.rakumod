use v6.d;

unit class MVC::Keayl::LogEvent;

has Str $.method;
has Str $.path;
has Str $.target is rw;
has Str $.request-id is rw;
has Int $.status is rw;
has     %.params;
has     %!timings;
has     &.clock = sub { now };

method set-params(%params --> ::?CLASS) {
  %!params = %params;
  self
}

method time(Str:D $kind, &block) {
  my $start  = &!clock.();
  my $result = block();

  %!timings{$kind} = (%!timings{$kind} // 0) + (&!clock.() - $start);
  $result
}

method timing(Str:D $kind) { %!timings{$kind} }
