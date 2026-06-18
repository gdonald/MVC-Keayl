use v6.d;
use MVC::Keayl::Cable::PubSub;

unit class MVC::Keayl::Cable::Connection;

class X::MVC::Keayl::Cable::Rejected is Exception is export {
  method message { 'connection rejected' }
}

has MVC::Keayl::Cable::PubSub $.pubsub is required;
has                          &.sink is required;
has                          %.identifiers;
has                          @.subscriptions;
has Bool                     $!rejected = False;

my %declared-identifiers{Mu};

method identified-by(*@names --> ::?CLASS) {
  (%declared-identifiers{self} //= []).append(@names.map(*.Str));
  self
}

method !declared-identifiers(--> List) {
  my @names;
  @names.append(|(%declared-identifiers{$_} // [])) for self.^mro.reverse;
  @names.unique.List
}

method set-identifier(Str:D $name, $value --> ::?CLASS) {
  %!identifiers{$name} = $value;
  self
}

method connect() { }

method reject-unauthorized-connection() {
  $!rejected = True;
  X::MVC::Keayl::Cable::Rejected.new.throw;
}

method is-rejected(--> Bool) { $!rejected }

method open(--> ::?CLASS) {
  {
    CATCH { when X::MVC::Keayl::Cable::Rejected { } }
    self.connect;
  }

  self
}

method transmit($data) {
  &!sink.($data)
}

method add-subscription($channel --> ::?CLASS) {
  @!subscriptions.push: $channel if $channel.subscribe;
  self
}

method disconnect() {
  .unsubscribe for @!subscriptions;
  @!subscriptions = ();
}

method FALLBACK(Str $name, |args) {
  X::Method::NotFound.new(method => $name, typename => self.^name).throw
    unless self!declared-identifiers.first($name);

  %!identifiers{$name}
}
