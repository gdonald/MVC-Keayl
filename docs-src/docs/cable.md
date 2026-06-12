# WebSockets

`MVC::Keayl::Cable` is an ActionCable-style abstraction for real-time messaging: a
connection holds a client, channels group its subscriptions, and a pub/sub
backend fans broadcasts out to everyone on a stream.

## Connections

`MVC::Keayl::Cable::Connection` represents one client. It carries the pub/sub
backend, a `sink` (the transport's function for sending a message to that client),
and `identifiers` (whatever you use to identify the client, such as the current
user or room):

```perl6
my $conn = MVC::Keayl::Cable::Connection.new(
  pubsub      => $pubsub,
  sink        => -> $message { $websocket.send($message) },
  identifiers => %( user-id => 7 ),
);
```

`add-subscription($channel)` registers a channel and subscribes it; `disconnect`
tears every subscription down.

## Channels

Subclass `MVC::Keayl::Cable::Channel`. Override `subscribed` to start streaming,
`unsubscribed` to clean up, and add a method per action a client can invoke:

```perl6
class ChatChannel is MVC::Keayl::Cable::Channel {
  method subscribed {
    self.stream-from('room:' ~ self.connection.identifiers<room>);
  }

  method speak(%data) {
    self.broadcast-to('room:' ~ self.connection.identifiers<room>, %data<message>);
  }
}
```

- `stream-from($stream)` subscribes the channel to a broadcasting; messages on
  that stream are transmitted to this connection's client.
- `transmit($data)` sends data straight to this client.
- `broadcast-to($stream, $data)` publishes to a stream, reaching every connection
  subscribed to it.
- `perform($action, %data)` dispatches a client message to an action method. Only
  methods you define on the channel are callable, so framework methods like
  `stream-from` cannot be invoked from the wire.

`unsubscribe` (run for you on `disconnect`) drops the channel's stream
subscriptions and calls `unsubscribed`.

## Pub/sub backends

A backend is any `MVC::Keayl::Cable::PubSub`, a role with `subscribe($stream,
&callback)`, `unsubscribe($id)`, and `broadcast($stream, $message)`.
`MVC::Keayl::Cable::PubSub::InMemory` is the built-in, single-process backend; it
tracks subscribers per stream and fans a broadcast out to each one. Swap in a
Redis- or message-queue-backed implementation of the same role to share
broadcasts across processes.
