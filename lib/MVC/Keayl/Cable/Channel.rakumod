use v6.d;

unit class MVC::Keayl::Cable::Channel;

has $.connection is required;
has @.stream-subscriptions;

method subscribed()   { }
method unsubscribed() { }

method stream-from(Str:D $stream --> Int) {
  my $id = $.connection.pubsub.subscribe($stream, -> $message { self.transmit($message) });
  @!stream-subscriptions.push: %( :$stream, :$id );

  $id
}

method transmit($data) {
  $.connection.transmit($data)
}

method broadcast-to(Str:D $stream, $data) {
  $.connection.pubsub.broadcast($stream, $data)
}

method subscribe() {
  self.subscribed;
}

method unsubscribe() {
  $.connection.pubsub.unsubscribe(.<id>) for @!stream-subscriptions;
  @!stream-subscriptions = ();

  self.unsubscribed;
}

method !is-action(Str:D $name --> Bool) {
  state $reserved = MVC::Keayl::Cable::Channel.^methods(:all).map(*.name).Set;
  self.^can($name).so && !$reserved{$name}
}

method perform(Str:D $action, %data = {}) {
  die "unknown action '$action'" unless self!is-action($action);
  self."$action"(%data)
}
