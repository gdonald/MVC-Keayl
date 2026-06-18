use v6.d;
use JSON::Fast;
use MVC::Keayl::Cable::PubSub;

unit module MVC::Keayl::Cable::Broadcasting;

my MVC::Keayl::Cable::PubSub $default-pubsub;

sub set-cable-pubsub(MVC::Keayl::Cable::PubSub:D $pubsub) is export {
  $default-pubsub = $pubsub;
}

sub cable-pubsub(--> MVC::Keayl::Cable::PubSub) is export {
  $default-pubsub
}

sub reset-cable-pubsub() is export {
  $default-pubsub = MVC::Keayl::Cable::PubSub;
}

class JsonCoder is export {
  method encode($message --> Str) {
    to-json($message, :!pretty)
  }

  method decode($encoded) {
    $encoded ~~ Str ?? from-json($encoded) !! $encoded
  }
}

sub stream-key($target --> Str) is export {
  return $target if $target ~~ Str;
  return $target.^name.subst(/^ 'GLOBAL::' /, '') ~ ':' ~ $target.id if $target.^can('id');
  ~$target
}

sub broadcasting-for(*@parts --> Str) is export {
  @parts.map({ stream-key($_) }).join(':')
}

role Broadcastable is export {
  method broadcast-to($stream, %payload) {
    with cable-pubsub() -> $pubsub {
      $pubsub.broadcast(stream-key($stream), %payload);
    }
  }

  method broadcast-append-to($stream, :$target, :$content) {
    self.broadcast-to($stream, %( action => 'append', :$target, :$content ));
  }

  method broadcast-replace-to($stream, :$target, :$content) {
    self.broadcast-to($stream, %( action => 'replace', :$target, :$content ));
  }

  method broadcast-remove-to($stream, :$target) {
    self.broadcast-to($stream, %( action => 'remove', :$target ));
  }
}
