use v6.d;
use MVC::Keayl::Cable::PubSub;

unit class MVC::Keayl::Cable::PubSub::External does MVC::Keayl::Cable::PubSub;

has $.client is required;

method subscribe(Str:D $stream, &callback --> Int) {
  $!client.subscribe($stream, &callback)
}

method unsubscribe(Int:D $id --> Bool) {
  so $!client.unsubscribe($id)
}

method broadcast(Str:D $stream, $message) {
  $!client.publish($stream, $message)
}

method subscriber-count(Str:D $stream --> Int) {
  $!client.subscriber-count($stream)
}
