use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Cable::PubSub::InMemory;
use MVC::Keayl::Cable::Connection;
use MVC::Keayl::Cable::Channel;

class ChatChannel is MVC::Keayl::Cable::Channel {
  method subscribed   { self.stream-from('room:' ~ self.connection.identifiers<room>) }
  method speak(%data) { self.broadcast-to('room:' ~ self.connection.identifiers<room>, %data<message>) }
}

sub connection(:@received!, :%identifiers, :$pubsub!) {
  MVC::Keayl::Cable::Connection.new(
    :$pubsub,
    sink        => -> $message { @received.push: $message },
    identifiers => %identifiers,
  )
}

describe 'MVC::Keayl::Cable::PubSub::InMemory', {
  it 'delivers a broadcast to a stream subscriber', {
    my $pubsub = MVC::Keayl::Cable::PubSub::InMemory.new;
    my @got;
    $pubsub.subscribe('room:1', -> $message { @got.push: $message });
    $pubsub.broadcast('room:1', 'hello');
    expect(@got).to.be(['hello']);
  }

  it 'stops delivering after unsubscribe', {
    my $pubsub = MVC::Keayl::Cable::PubSub::InMemory.new;
    my @got;
    my $id = $pubsub.subscribe('room:1', -> $message { @got.push: $message });
    $pubsub.unsubscribe($id);
    $pubsub.broadcast('room:1', 'hello');
    expect(@got).to.be([]);
  }

  it 'tracks subscribers per stream', {
    my $pubsub = MVC::Keayl::Cable::PubSub::InMemory.new;
    $pubsub.subscribe('room:1', -> $m { });
    $pubsub.subscribe('room:1', -> $m { });
    expect($pubsub.subscriber-count('room:1')).to.be(2);
  }

  it 'is a no-op broadcasting to an empty stream', {
    my $pubsub = MVC::Keayl::Cable::PubSub::InMemory.new;
    expect({ $pubsub.broadcast('empty', 'x') }).not.to.throw;
  }
}

describe 'MVC::Keayl::Cable::Channel streaming', {
  it 'transmits stream messages to the connection', {
    my @received;
    my $pubsub = MVC::Keayl::Cable::PubSub::InMemory.new;
    my $conn   = connection(:@received, identifiers => %( room => '1' ), :$pubsub);
    $conn.add-subscription(ChatChannel.new(connection => $conn));
    $pubsub.broadcast('room:1', 'hi');
    expect(@received).to.be(['hi']);
  }

  it 'broadcasts back to the stream from an action', {
    my @received;
    my $pubsub = MVC::Keayl::Cable::PubSub::InMemory.new;
    my $conn   = connection(:@received, identifiers => %( room => '1' ), :$pubsub);
    my $channel = ChatChannel.new(connection => $conn);
    $conn.add-subscription($channel);
    $channel.perform('speak', %( message => 'yo' ));
    expect(@received).to.be(['yo']);
  }

  it 'rejects a framework method as an action', {
    my @received;
    my $pubsub = MVC::Keayl::Cable::PubSub::InMemory.new;
    my $conn   = connection(:@received, identifiers => %( room => '1' ), :$pubsub);
    my $channel = ChatChannel.new(connection => $conn);
    $conn.add-subscription($channel);
    expect({ $channel.perform('stream-from', %()) }).to.throw;
  }
}

describe 'MVC::Keayl::Cable::Connection disconnect', {
  it 'stops transmitting after disconnect', {
    my @received;
    my $pubsub = MVC::Keayl::Cable::PubSub::InMemory.new;
    my $conn   = connection(:@received, identifiers => %( room => '1' ), :$pubsub);
    $conn.add-subscription(ChatChannel.new(connection => $conn));
    $conn.disconnect;
    $pubsub.broadcast('room:1', 'after');
    expect(@received).to.be([]);
  }

  it 'leaves no subscribers on the backend', {
    my @received;
    my $pubsub = MVC::Keayl::Cable::PubSub::InMemory.new;
    my $conn   = connection(:@received, identifiers => %( room => '1' ), :$pubsub);
    $conn.add-subscription(ChatChannel.new(connection => $conn));
    $conn.disconnect;
    expect($pubsub.subscriber-count('room:1')).to.be(0);
  }
}

describe 'MVC::Keayl::Cable fan-out', {
  it 'delivers a broadcast to every connection on the stream', {
    my (@a, @b);
    my $pubsub = MVC::Keayl::Cable::PubSub::InMemory.new;
    my $conn-a = connection(received => @a, identifiers => %( room => '1' ), :$pubsub);
    my $conn-b = connection(received => @b, identifiers => %( room => '1' ), :$pubsub);
    $conn-a.add-subscription(ChatChannel.new(connection => $conn-a));
    $conn-b.add-subscription(ChatChannel.new(connection => $conn-b));
    $pubsub.broadcast('room:1', 'broadcast');
    expect((@a, @b)).to.be((['broadcast'], ['broadcast']));
  }
}
