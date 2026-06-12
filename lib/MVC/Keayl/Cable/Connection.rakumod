use v6.d;
use MVC::Keayl::Cable::PubSub;

unit class MVC::Keayl::Cable::Connection;

has MVC::Keayl::Cable::PubSub $.pubsub is required;
has                          &.sink is required;
has                          %.identifiers;
has                          @.subscriptions;

method transmit($data) {
  &!sink.($data)
}

method add-subscription($channel --> ::?CLASS) {
  @!subscriptions.push: $channel;
  $channel.subscribe;
  self
}

method disconnect() {
  .unsubscribe for @!subscriptions;
  @!subscriptions = ();
}
