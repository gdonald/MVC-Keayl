use v6.d;
use MVC::Keayl::Cable::PubSub;

unit class MVC::Keayl::Cable::PubSub::InMemory does MVC::Keayl::Cable::PubSub;

has     %!subscribers;
has Int $!next-id = 0;

method subscribe(Str:D $stream, &callback --> Int) {
  my $id = $!next-id++;

  %!subscribers{$stream} //= [];
  %!subscribers{$stream}.push: %( :$id, :&callback );

  $id
}

method unsubscribe(Int:D $id --> Bool) {
  my $removed = False;

  for %!subscribers.keys -> $stream {
    my $before = %!subscribers{$stream}.elems;
    %!subscribers{$stream} = %!subscribers{$stream}.grep({ $_<id> != $id }).Array;
    $removed = True if %!subscribers{$stream}.elems != $before;
  }

  $removed
}

method broadcast(Str:D $stream, $message) {
  return unless %!subscribers{$stream};
  .<callback>($message) for %!subscribers{$stream}.list;
}

method subscriber-count(Str:D $stream --> Int) {
  (%!subscribers{$stream} // []).elems
}
