use v6.d;

class X::MVC::Keayl::Live::ClientDisconnected is Exception {
  method message(--> Str) { 'client disconnected' }
}

class X::MVC::Keayl::Live::StreamClosed is Exception {
  method message(--> Str) { 'write to a closed stream' }
}

# A push-based response body. The action writes chunks from its own thread while
# the adapter pulls them through the channel, so neither side blocks the other.
class MVC::Keayl::Live::Stream {
  has Channel $!channel = Channel.new;
  has Bool $.closed = False;
  has Bool $.disconnected = False;

  method write($chunk --> ::?CLASS) {
    X::MVC::Keayl::Live::ClientDisconnected.new.throw if $!disconnected;
    X::MVC::Keayl::Live::StreamClosed.new.throw if $!closed;

    $!channel.send($chunk ~~ Blob ?? $chunk !! $chunk.Str.encode('utf-8'));
    self
  }

  method close(--> ::?CLASS) {
    return self if $!closed;

    $!closed = True;
    $!channel.close;
    self
  }

  method disconnect(--> ::?CLASS) {
    $!disconnected = True;
    self.close;
  }

  method is-closed(--> Bool)       { $!closed }
  method is-disconnected(--> Bool) { $!disconnected }

  method chunks {
    $!channel.list
  }
}

class MVC::Keayl::Live::SSE {
  has $.stream is required;
  has %.defaults;

  method write($data, :$event, :$id, :$retry --> ::?CLASS) {
    $!stream.write(self.frame($data, :$event, :$id, :$retry));
    self
  }

  method frame($data, :$event, :$id, :$retry --> Str) {
    my $out = '';

    my $retry-value = $retry // %!defaults<retry>;
    my $event-value = $event // %!defaults<event>;
    my $id-value    = $id    // %!defaults<id>;

    $out ~= "retry: $retry-value\n" if $retry-value.defined;
    $out ~= "event: $event-value\n" if $event-value.defined;
    $out ~= "id: $id-value\n"       if $id-value.defined;

    my $message = ($data // '').Str.subst("\n", "\ndata: ", :g);
    $out ~= "data: $message\n\n";

    $out
  }

  method comment(Str:D $text = '' --> ::?CLASS) {
    $!stream.write(": $text\n\n");
    self
  }

  method close(--> ::?CLASS) {
    $!stream.close;
    self
  }
}
