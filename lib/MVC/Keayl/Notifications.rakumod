use v6.d;

unit class MVC::Keayl::Notifications;

my %subscribers;
my Int $next-id = 0;

method subscribe(Str:D $event, &callback --> Int) {
  my $id = $next-id++;

  %subscribers{$event} //= [];
  %subscribers{$event}.push: %( :$id, :&callback );

  $id
}

method unsubscribe(Int:D $id --> Bool) {
  my $removed = False;

  for %subscribers.keys -> $event {
    my $before = %subscribers{$event}.elems;
    %subscribers{$event} = %subscribers{$event}.grep({ $_<id> != $id }).Array;
    $removed = True if %subscribers{$event}.elems != $before;
  }

  $removed
}

method has-subscribers(Str:D $event --> Bool) {
  so %subscribers{$event} && %subscribers{$event}.elems
}

method notify(Str:D $event, %payload) {
  return unless self.has-subscribers($event);

  .<callback>(%payload) for %subscribers{$event}.list;
}

method instrument(Str:D $event, %payload is copy, &block) {
  return block() unless self.has-subscribers($event);

  my $start = now;
  my $result;
  my $error;

  {
    CATCH { default { $error = $_ } }
    $result = block();
  }

  %payload<duration>  = (now - $start).Num;
  %payload<exception> = $error if $error;

  self.notify($event, %payload);

  $error.rethrow if $error;
  $result
}

method bridge($source, Str:D $event = 'sql.active_record' --> Int) {
  $source.subscribe($event, -> %payload { self.notify($event, %payload) })
}

method reset {
  %subscribers = ();
  $next-id = 0;
}
