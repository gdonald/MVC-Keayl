use v6.d;

unit role MVC::Keayl::Cable::PubSub;

method subscribe(Str:D $stream, &callback --> Int) { ... }
method unsubscribe(Int:D $id --> Bool) { ... }
method broadcast(Str:D $stream, $message) { ... }
