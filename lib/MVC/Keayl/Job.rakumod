use v6.d;
use MVC::Keayl::Job::QueueAdapter;

unit class MVC::Keayl::Job;

my MVC::Keayl::Job::QueueAdapter $current-adapter;
my &clock = sub { now };
my Int $registration-seq = 0;

my %handlers{Mu};
my %before-perform{Mu};
my %after-perform{Mu};
my %around-perform{Mu};
my %before-enqueue{Mu};
my %after-enqueue{Mu};
my %around-enqueue{Mu};

has Capture $.arguments = \();
has Str     $.queue-name = 'default';
has         $.priority;
has         $.scheduled-at;
has Int     $.executions is rw = 1;
has         $.wait;
has         $.wait-until;

sub current-time() { &clock().Numeric }

sub compute-wait($wait, $executions) {
  return 0 without $wait;
  return $wait($executions) if $wait ~~ Callable;
  $wait
}

method queue-adapter(::?CLASS: MVC::Keayl::Job::QueueAdapter $adapter?) {
  $current-adapter = $adapter with $adapter;
  $current-adapter
}

method reset-queue-adapter(::?CLASS:) {
  $current-adapter = MVC::Keayl::Job::QueueAdapter;
}

method clock(::?CLASS: &new-clock?) {
  &clock = &new-clock with &new-clock;
  &clock
}

method reset-clock(::?CLASS:) {
  &clock = sub { now };
}

method retry-on($type, :$wait = 3, Int :$attempts = 5, :&with --> ::?CLASS) {
  (%handlers{self} //= []).push: %( kind => 'retry', :$type, :$wait, :$attempts, :&with, seq => $registration-seq++ );
  self
}

method discard-on($type, :&with --> ::?CLASS) {
  (%handlers{self} //= []).push: %( kind => 'discard', :$type, :&with, seq => $registration-seq++ );
  self
}

method rescue-from($type, $handler --> ::?CLASS) {
  (%handlers{self} //= []).push: %( kind => 'rescue', :$type, :$handler, seq => $registration-seq++ );
  self
}

method before-perform(&callback --> ::?CLASS) { (%before-perform{self} //= []).push(&callback); self }
method after-perform(&callback --> ::?CLASS)  { (%after-perform{self} //= []).push(&callback); self }
method around-perform(&callback --> ::?CLASS) { (%around-perform{self} //= []).push(&callback); self }
method before-enqueue(&callback --> ::?CLASS) { (%before-enqueue{self} //= []).push(&callback); self }
method after-enqueue(&callback --> ::?CLASS)  { (%after-enqueue{self} //= []).push(&callback); self }
method around-enqueue(&callback --> ::?CLASS) { (%around-enqueue{self} //= []).push(&callback); self }

method !collect(%registry --> List) {
  my @result;
  @result.append(|(%registry{$_} // [])) for self.^mro.reverse;
  @result
}

method !run-around(%before, %around, %after, &core) {
  .(self) for self!collect(%before);

  my &chain = &core;
  for self!collect(%around).reverse -> &callback {
    my &next = &chain;
    &chain = { callback(self, &next) };
  }
  &chain();

  .(self) for self!collect(%after);
}

method !error-handler($exception) {
  my @names = $exception.^mro.map(*.^name);
  my %rank;
  %rank{@names[$_]} //= $_ for ^@names;

  my @matching = self!collect(%handlers).grep({ %rank{.<type>.^name}:exists });
  return Nil unless @matching;

  @matching.sort({ %rank{$^a<type>.^name} <=> %rank{$^b<type>.^name} || $^b<seq> <=> $^a<seq> }).head
}

method !retry-or-exhaust(%handler, $exception) {
  if $!executions < %handler<attempts> {
    my $wait = compute-wait(%handler<wait>, $!executions);

    my $retried = self.WHAT.new(
      arguments    => $!arguments,
      queue-name   => $!queue-name,
      priority     => $!priority,
      executions   => $!executions + 1,
      scheduled-at => current-time() + $wait,
    );

    with self.queue-adapter -> $adapter { $adapter.enqueue($retried) } else { $retried.execute }
  } else {
    with %handler<with> -> &block { block(self, $exception) } else { $exception.rethrow }
  }
}

method !apply-handler(%handler, $exception) {
  given %handler<kind> {
    when 'retry'   { self!retry-or-exhaust(%handler, $exception) }
    when 'discard' { with %handler<with> -> &block { block(self, $exception) } }
    when 'rescue'  {
      my $handler = %handler<handler>;
      $handler ~~ Callable ?? $handler(self, $exception) !! self."$handler"($exception);
    }
  }
}

method perform(|args) {
  die "{self.^name} must implement perform"
}

method execute() {
  CATCH {
    default {
      my $exception = $_;
      my $handler   = self!error-handler($exception);
      $exception.rethrow without $handler;
      self!apply-handler($handler, $exception);
    }
  }

  self!run-around(%before-perform, %around-perform, %after-perform, { self.perform(|$!arguments) });
}

method enqueue-self() {
  self!run-around(%before-enqueue, %around-enqueue, %after-enqueue, {
    with self.queue-adapter -> $adapter { $adapter.enqueue(self) } else { self.execute }
  });

  self
}

method perform-now(::?CLASS:U: |args) {
  self.new(arguments => args).execute
}

multi method perform-later(::?CLASS:U: |args) {
  self.new(arguments => args).enqueue-self
}

multi method perform-later(::?CLASS:D: |args) {
  my $scheduled-at = do {
    if    $!wait-until.defined { $!wait-until.Numeric }
    elsif $!wait.defined       { current-time() + $!wait }
    else                       { $!scheduled-at }
  };

  self.WHAT.new(
    arguments  => args,
    queue-name => $!queue-name,
    priority   => $!priority,
    :$scheduled-at,
  ).enqueue-self
}

method set(::?CLASS:U: :$wait, :$wait-until, :$queue, :$priority) {
  self.new(
    queue-name => ($queue // 'default'),
    :$priority, :$wait, :$wait-until,
  )
}
