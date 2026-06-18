use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Cable::PubSub::InMemory;
use MVC::Keayl::Cable::PubSub::External;
use MVC::Keayl::Cable::Connection;
use MVC::Keayl::Cable::Channel;
use MVC::Keayl::Cable::Broadcasting;

class CableAuthConnection is MVC::Keayl::Cable::Connection {
  method connect {
    if self.identifiers<token> eq 'good' {
      self.set-identifier('current-user', 'ada');
    } else {
      self.reject-unauthorized-connection;
    }
  }
}
CableAuthConnection.identified-by('current-user');

class CableGuardedChannel is MVC::Keayl::Cable::Channel {
  method subscribed { self.stream-from('room:1'); self.reject }
}

class CableLifecycleChannel is MVC::Keayl::Cable::Channel {
  has @.events;
  method subscribed   { @.events.push('subscribed') }
  method unsubscribed { @.events.push('unsubscribed') }
}

class CableHeartbeatChannel is MVC::Keayl::Cable::Channel {
  has $.beats is rw = 0;
  method beat { $!beats++ }
}
CableHeartbeatChannel.periodically('beat', every => 3);

class CableRoomChannel is MVC::Keayl::Cable::Channel {
  method subscribed { self.stream-for('lobby', coder => JsonCoder.new) }
}

class CableBroadcastChannel is MVC::Keayl::Cable::Channel { }

class CableBroadcastPost does Broadcastable {
  has $.id;
}

sub sink-connection(@received, %identifiers, $pubsub, $class = MVC::Keayl::Cable::Connection) {
  $class.new(:$pubsub, sink => -> $message { @received.push: $message }, identifiers => %identifiers)
}

describe 'identified-by and authentication', {
  it 'accepts a valid connection and reads its identifier', {
    my @received;
    my $conn = sink-connection(@received, %( token => 'good' ), MVC::Keayl::Cable::PubSub::InMemory.new, CableAuthConnection);
    $conn.open;
    expect(!$conn.is-rejected && $conn.current-user eq 'ada').to.be-truthy;
  }

  it 'rejects an invalid connection', {
    my @received;
    my $conn = sink-connection(@received, %( token => 'bad' ), MVC::Keayl::Cable::PubSub::InMemory.new, CableAuthConnection);
    $conn.open;
    expect($conn.is-rejected).to.be-truthy;
  }
}

describe 'subscription reject', {
  let(:pubsub, { MVC::Keayl::Cable::PubSub::InMemory.new });

  it 'does not add a rejected channel and tears down its streams', {
    my @received;
    my $conn = sink-connection(@received, %( room => '1' ), pubsub);
    my $channel = CableGuardedChannel.new(connection => $conn);
    $conn.add-subscription($channel);

    expect($channel.is-rejected && $conn.subscriptions.elems == 0 && pubsub.subscriber-count('room:1') == 0).to.be-truthy;
  }
}

describe 'lifecycle callbacks', {
  it 'run subscribed then unsubscribed', {
    my @received;
    my $conn = sink-connection(@received, %(), MVC::Keayl::Cable::PubSub::InMemory.new);
    my $channel = CableLifecycleChannel.new(connection => $conn);
    $conn.add-subscription($channel);
    $conn.disconnect;
    expect($channel.events.join(',')).to.be('subscribed,unsubscribed');
  }
}

describe 'periodic timers', {
  let(:channel, {
    my @received;
    CableHeartbeatChannel.new(connection => sink-connection(@received, %(), MVC::Keayl::Cable::PubSub::InMemory.new))
  });

  it 'registers a timer with its interval', {
    expect(channel.periodic-timers.elems == 1 && channel.periodic-timers[0]<every> == 3).to.be-truthy;
  }

  it 'fires the registered method when run', {
    channel.run-periodic-timers;
    expect(channel.beats).to.be(1);
  }
}

describe 'stream-for with a coder', {
  it 'decodes a broadcast back into data', {
    my @received;
    my $pubsub = MVC::Keayl::Cable::PubSub::InMemory.new;
    my $conn = sink-connection(@received, %(), $pubsub);
    my $channel = CableRoomChannel.new(connection => $conn);
    $conn.add-subscription($channel);

    $channel.broadcast-to($channel.broadcasting-for('lobby'), %( text => 'hi' ), coder => JsonCoder.new);
    expect(@received[0]<text>).to.be('hi');
  }
}

describe 'broadcast-to-target', {
  it 'publishes to the broadcasting stream', {
    reset-cable-pubsub;
    my $pubsub = MVC::Keayl::Cable::PubSub::InMemory.new;
    set-cable-pubsub($pubsub);

    my @got;
    $pubsub.subscribe(CableBroadcastChannel.broadcasting-for('lobby'), -> $message { @got.push: $message });
    CableBroadcastChannel.broadcast-to-target('lobby', 'hello');

    expect(@got).to.be(['hello']);
    reset-cable-pubsub;
  }
}

describe 'the model broadcasts helper', {
  it 'sends an append action with the rendered content', {
    reset-cable-pubsub;
    my $pubsub = MVC::Keayl::Cable::PubSub::InMemory.new;
    set-cable-pubsub($pubsub);

    my $post = CableBroadcastPost.new(id => 7);
    my @got;
    $pubsub.subscribe(stream-key($post), -> $message { @got.push: $message });
    $post.broadcast-append-to($post, target => 'posts', content => '<li>new</li>');

    expect(@got[0]<action> eq 'append' && @got[0]<content> eq '<li>new</li>').to.be-truthy;
    reset-cable-pubsub;
  }
}

describe 'the external pub/sub backend', {
  let(:pubsub, {
    my class FakeRedis {
      has %.streams;
      has Int $.next-id is rw = 0;
      method subscribe($stream, &callback) {
        my $id = $!next-id++;
        (%!streams{$stream} //= []).push: %( :$id, :&callback );
        $id
      }
      method unsubscribe($id) {
        for %!streams.keys -> $stream { %!streams{$stream} = %!streams{$stream}.grep({ .<id> != $id }).Array }
        True
      }
      method publish($stream, $message) { .<callback>($message) for (%!streams{$stream} // []).list }
      method subscriber-count($stream) { (%!streams{$stream} // []).elems }
    }
    MVC::Keayl::Cable::PubSub::External.new(client => FakeRedis.new)
  });

  it 'delivers a broadcast through its client', {
    my @got;
    pubsub.subscribe('room:1', -> $message { @got.push: $message });
    pubsub.broadcast('room:1', 'networked');
    expect(@got).to.be(['networked']);
  }

  it 'reports subscriber counts', {
    pubsub.subscribe('room:1', -> $message { });
    expect(pubsub.subscriber-count('room:1')).to.be(1);
  }

  it 'stops delivery after unsubscribing', {
    my @got;
    my $id = pubsub.subscribe('room:1', -> $message { @got.push: $message });
    pubsub.unsubscribe($id);
    pubsub.broadcast('room:1', 'gone');
    expect(@got).to.be([]);
  }
}
