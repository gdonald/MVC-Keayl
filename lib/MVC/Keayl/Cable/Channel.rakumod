use v6.d;
use MVC::Keayl::Cable::Broadcasting;

unit class MVC::Keayl::Cable::Channel;

has $.connection is required;
has @.stream-subscriptions;
has Bool $!rejected = False;

my %timers{Mu};

sub underscore(Str:D $word --> Str) {
  $word.subst(/<?after .> <:Lu>/, { '_' ~ $/.Str }, :g).lc
}

method subscribed()   { }
method unsubscribed() { }

method channel-name(--> Str) {
  underscore(self.^name.subst(/^ 'GLOBAL::' /, '').subst(/ 'Channel' $/, ''))
}

method broadcasting-for($target --> Str) {
  self.channel-name ~ ':' ~ stream-key($target)
}

method stream-from(Str:D $stream, :$coder --> Int) {
  my $id = $.connection.pubsub.subscribe($stream, -> $message {
    self.transmit($coder.defined ?? $coder.decode($message) !! $message);
  });

  @!stream-subscriptions.push: %( :$stream, :$id );

  $id
}

method stream-for($target, :$coder --> Int) {
  self.stream-from(self.broadcasting-for($target), :$coder)
}

method transmit($data) {
  $.connection.transmit($data)
}

method broadcast-to(Str:D $stream, $data, :$coder) {
  my $message = $coder.defined ?? $coder.encode($data) !! $data;
  $.connection.pubsub.broadcast($stream, $message);
}

method broadcast-to-target($target, $data, :$coder) {
  my $message = $coder.defined ?? $coder.encode($data) !! $data;

  with cable-pubsub() -> $pubsub {
    $pubsub.broadcast(self.broadcasting-for($target), $message);
  }
}

method reject() {
  $!rejected = True;
}

method is-rejected(--> Bool) { $!rejected }

method !teardown-streams() {
  $.connection.pubsub.unsubscribe(.<id>) for @!stream-subscriptions;
  @!stream-subscriptions = ();
}

method subscribe(--> Bool) {
  self.subscribed;

  if $!rejected {
    self!teardown-streams;
    return False;
  }

  True
}

method unsubscribe() {
  self!teardown-streams;
  self.unsubscribed;
}

method periodically($callback, :$every --> ::?CLASS) {
  (%timers{self} //= []).push: %( :$callback, :$every );
  self
}

method periodic-timers(--> List) {
  my @collected;
  @collected.append(|(%timers{$_} // [])) for self.^mro.reverse;
  @collected.List
}

method run-periodic-timers() {
  for self.periodic-timers -> %timer {
    my $callback = %timer<callback>;
    $callback ~~ Callable ?? $callback(self) !! self."$callback"();
  }
}

method !is-action(Str:D $name --> Bool) {
  state $reserved = MVC::Keayl::Cable::Channel.^methods(:all).map(*.name).Set;
  self.^can($name).so && !$reserved{$name}
}

method perform(Str:D $action, %data = {}) {
  die "unknown action '$action'" unless self!is-action($action);
  self."$action"(%data)
}
