use v6.d;
use Cro;
use Cro::HTTP::Server;
use Cro::HTTP::Request;
use Cro::HTTP::Response;
use ORM::ActiveRecord::Instrumentation::Notifications;
use MVC::Keayl::Adapter;
use MVC::Keayl::Notifications;
use MVC::Keayl::Request;

unit class MVC::Keayl::Adapter::Cro does MVC::Keayl::Adapter;

constant ActiveRecordNotifications = Notifications;
constant SQL-EXCERPT-LENGTH        = 80;

has Str $.host = '127.0.0.1';
has Int $.port is required;
has Str $.scheme = 'http';
has     $.request-log-dir = %*ENV<KEAYL_REQUEST_LOG>;
has     $!server;
has     @!keayl-subscriptions;
has     @!active-record-subscriptions;

my class Bridge does Cro::Transform {
  has $.adapter is required;

  method consumes() { Cro::HTTP::Request }
  method produces() { Cro::HTTP::Response }

  method transformer(Supply:D $in --> Supply:D) {
    supply {
      whenever $in -> $request {
        $!adapter.log-request-event($request, "received {$request.method} {$request.target}");

        my $response = Cro::HTTP::Response.new(:$request);

        whenever $request.body-blob -> $blob {
          $!adapter.log-request-event($request, 'body');
          $!adapter.fill-response($request, $blob, $response);

          emit $response;
          $!adapter.log-request-event($request, 'emitted');
        }
      }
    }
  }
}

method log-request-event(Cro::HTTP::Request:D $request, Str:D $event --> Nil) {
  return without $!request-log-dir;

  my $time = DateTime.now.utc;
  my $peer = $request.connection.?peer-port // '-';

  my $line = sprintf "%04d-%02d-%02dT%02d:%02d:%06.3fZ port=%s peer=%s %s\n",
    $time.year, $time.month, $time.day, $time.hour, $time.minute, $time.second,
    $!port, $peer, $event;

  $!request-log-dir.IO.add("requests-{$*PID}.log").spurt($line, :append);
}

method subscribe-request-log(--> Nil) {
  return without $!request-log-dir;
  return if @!keayl-subscriptions;

  for <dispatch.keayl dispatch.keayl.start render.keayl render.keayl.start compile.keayl compile.keayl.start> -> $event {
    @!keayl-subscriptions.push: MVC::Keayl::Notifications.subscribe($event, -> %payload { self!log-notification($event, %payload) });
  }

  for <sql.active_record sql.active_record.start> -> $event {
    @!active-record-subscriptions.push: ActiveRecordNotifications.subscribe($event, -> %payload { self!log-notification($event, %payload) });
  }
}

method unsubscribe-request-log(--> Nil) {
  MVC::Keayl::Notifications.unsubscribe($_) for @!keayl-subscriptions;
  ActiveRecordNotifications.unsubscribe($_) for @!active-record-subscriptions;

  @!keayl-subscriptions         = ();
  @!active-record-subscriptions = ();
}

method !log-notification(Str:D $event, %payload --> Nil) {
  my $context = $*KEAYL-REQUEST-LOG;
  return without $context;
  return unless $context.key === self;

  my @fields = do given $event {
    when /^ 'dispatch.keayl' / { "controller={%payload<controller> // ''}", "action={%payload<action> // ''}" }
    when /^ 'render.keayl' /   { "kind={%payload<kind> // ''}", "name={%payload<name> // ''}" }
    when /^ 'compile.keayl' /  { "file={%payload<file> // ''}" }
    default                    { "name={%payload<name> // ''}" }
  }

  @fields.push: sprintf('duration=%.3f', %payload<duration>) with %payload<duration>;
  @fields.push: "exception={%payload<exception>.^name}" with %payload<exception>;
  @fields.push: 'sql=' ~ %payload<sql>.subst(/\s+/, ' ', :g).substr(0, SQL-EXCERPT-LENGTH) with %payload<sql>;

  self.log-request-event($context.value, "$event {@fields.join(' ')}");
}

method build-request(Cro::HTTP::Request:D $cro, Blob:D $body --> MVC::Keayl::Request) {
  my %headers;

  for $cro.headers -> $header {
    %headers{$header.name} = %headers{$header.name}:exists
      ?? [ |%headers{$header.name}.list, $header.value ]
      !! $header.value;
  }

  MVC::Keayl::Request.new(
    :method($cro.method),
    :target($cro.target),
    :%headers,
    :body($body),
    :scheme($!scheme),
    :remote-address($cro.connection.?peer-host // Str),
  )
}

method !apply-headers(Cro::HTTP::Response:D $cro-response, $headers --> Nil) {
  for $headers.list -> $pair {
    # Cro derives Content-Length from the body it serializes.
    next if $pair.key.lc eq 'content-length';
    $cro-response.append-header($pair.key, $pair.value);
  }
}

method fill-response(
  Cro::HTTP::Request:D $cro-request,
  Blob:D $body,
  Cro::HTTP::Response:D $cro-response,
  --> Cro::HTTP::Response
) {
  my $request  = self.build-request($cro-request, $body);
  my $*KEAYL-REQUEST-LOG = Pair.new(self, $cro-request);
  my $response = self.app.call($request);

  self.log-request-event($cro-request, "called {$response.status}");

  if $response.is-streaming {
    my ($status, $headers) = $response.streaming-finish;
    $cro-response.status = $status;
    self!apply-headers($cro-response, $headers);
    $cro-response.set-body-byte-stream($response.stream-supply);
  } else {
    my ($status, $headers, $blob) = $response.finish;
    $cro-response.status = $status;
    self!apply-headers($cro-response, $headers);
    $cro-response.set-body($blob);
  }

  $cro-response
}

method !ensure-port-available(--> Nil) {
  my $refused = Promise.new;
  my $refusal = $refused.vow;

  my $tap = IO::Socket::Async.listen($!host, $!port).tap(
    -> $connection { $connection.close },
    quit => -> $error { $refusal.break($error) },
  );

  await Promise.anyof($tap.socket-port, $refused);
  await $refused if $refused;

  $tap.close;
}

method start(--> Nil) {
  self!ensure-port-available;

  $!server = Cro::HTTP::Server.new(
    :$!host,
    :$!port,
    application => Bridge.new(:adapter(self)),
  );

  $!server.start;
  self.subscribe-request-log;
}

method stop(--> Nil) {
  self.unsubscribe-request-log;
  .stop with $!server;
  $!server = Nil;
}
