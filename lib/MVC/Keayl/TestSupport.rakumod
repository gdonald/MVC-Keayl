use v6.d;
use MVC::Keayl::Request;
use MVC::Keayl::Response;
use MVC::Keayl::Router;
use MVC::Keayl::Routing::UrlHelpers;
use MVC::Keayl::Mailer::Delivery::Test;
use MVC::Keayl::Job;
use MVC::Keayl::Adapter::Cro;

unit module MVC::Keayl::TestSupport;

class X::MVC::Keayl::Test::AssertionFailed is Exception is export {
  has Str $.reason;
  method message { $!reason }
}

sub fail-assertion(Str:D $reason) {
  X::MVC::Keayl::Test::AssertionFailed.new(:$reason).throw
}

my %status-codes =
  ok => 200, created => 201, accepted => 202, 'no-content' => 204,
  'moved-permanently' => 301, found => 302, 'see-other' => 303,
  'not-modified' => 304, 'temporary-redirect' => 307,
  'bad-request' => 400, unauthorized => 401, forbidden => 403,
  'not-found' => 404, 'unprocessable-entity' => 422,
  'too-many-requests' => 429, 'internal-server-error' => 500,
  redirect => 302, success => 200;

sub status-code($status --> Int) {
  return $status if $status ~~ Int;
  %status-codes{$status} // fail-assertion("unknown status '$status'")
}

sub cookie-name-value(Str:D $set-cookie --> List) {
  my $pair = $set-cookie.split(';')[0].trim;
  my ($name, $value) = $pair.split('=', 2);
  ($name, $value // '')
}

sub is-deletion(Str:D $set-cookie --> Bool) {
  so $set-cookie ~~ / :i 'max-age=0' / || cookie-name-value($set-cookie)[1] eq ''
}

class IntegrationSession is export {
  has $.app is required;
  has $.response is rw;
  has %.cookies;

  method !cookie-header(--> Str) {
    %!cookies.sort(*.key).map({ .key ~ '=' ~ .value }).join('; ')
  }

  method !capture-cookies() {
    for $!response.header-values('Set-Cookie') -> $set-cookie {
      my ($name, $value) = cookie-name-value($set-cookie);
      next without $name;

      if is-deletion($set-cookie) {
        %!cookies{$name}:delete;
      } else {
        %!cookies{$name} = $value;
      }
    }
  }

  method request(Str:D $method, Str:D $target, :%headers, :$body --> MVC::Keayl::Response) {
    my %request-headers = %headers // {};
    %request-headers<Cookie> = self!cookie-header if %!cookies;

    my $request = MVC::Keayl::Request.new(:$method, :$target, headers => %request-headers, :$body);

    $!response = $!app.call($request);
    self!capture-cookies;

    $!response
  }

  method get(Str:D $target, |c)    { self.request('GET', $target, |c) }
  method post(Str:D $target, |c)   { self.request('POST', $target, |c) }
  method put(Str:D $target, |c)    { self.request('PUT', $target, |c) }
  method patch(Str:D $target, |c)  { self.request('PATCH', $target, |c) }
  method delete(Str:D $target, |c) { self.request('DELETE', $target, |c) }

  method is-redirect(--> Bool) {
    300 <= $!response.status < 400
  }

  method follow-redirect(--> IntegrationSession) {
    fail-assertion("expected a redirect but got {$!response.status}") unless self.is-redirect;
    self.get($!response.location);
    self
  }

  method assert-response($expected --> IntegrationSession) {
    my $code = status-code($expected);
    $!response.status == $code
      or fail-assertion("expected response status $code but got {$!response.status}");
    self
  }

  method assert-redirected-to(Str:D $location --> IntegrationSession) {
    self.is-redirect or fail-assertion("expected a redirect but got {$!response.status}");
    $!response.location eq $location
      or fail-assertion("expected a redirect to '$location' but got '{$!response.location}'");
    self
  }

  method assert-select($matcher, :$text --> IntegrationSession) {
    my $body = $!response.body;

    my $matched = $matcher ~~ Regex ?? so $body ~~ $matcher !! $body.contains(~$matcher);
    $matched or fail-assertion("expected the response body to match {$matcher.gist}");

    with $text {
      $body.contains(~$text) or fail-assertion("expected the response body to contain '$text'");
    }

    self
  }
}

sub free-port(--> Int) {
  my $tap  = IO::Socket::Async.listen('127.0.0.1', 0).tap(-> $connection { $connection.close });
  my $port = await $tap.socket-port;

  $tap.close;

  $port
}

class LiveServer is export {
  has     $.app is required;
  has Str $.host   = '127.0.0.1';
  has Int $.port   = free-port();
  has Str $.scheme = 'http';
  has     $!adapter;

  method base-url(--> Str) {
    "$!scheme://$!host:$!port"
  }

  method url(Str:D $path = '' --> Str) {
    self.base-url ~ $path
  }

  method start(--> ::?CLASS) {
    return self if $!adapter.defined;

    $!adapter = MVC::Keayl::Adapter::Cro.new(:$!app, :$!host, :$!port, :$!scheme);
    $!adapter.start;

    self
  }

  method stop(--> Nil) {
    .stop with $!adapter;
    $!adapter = Nil;
  }
}

# Routing assertions

sub assert-recognizes(MVC::Keayl::Router:D $router, Str:D $method, Str:D $path, :%matching --> Bool) is export {
  my $match = $router.recognize($method, $path);
  fail-assertion("no route recognizes $method $path") without $match;

  for %matching.kv -> $key, $value {
    given $key {
      when 'controller' { $match.controller eq $value or fail-assertion("expected controller '$value' but got '{$match.controller}'") }
      when 'action'     { $match.action eq $value     or fail-assertion("expected action '$value' but got '{$match.action}'") }
      default {
        ($match.params{$key} // '') eq ~$value
          or fail-assertion("expected param $key='$value' but got '{$match.params{$key} // ''}'");
      }
    }
  }

  True
}

sub assert-generates(MVC::Keayl::Router:D $router, Str:D $name, Str:D $expected, *@positional, *%named --> Bool) is export {
  my $helpers   = MVC::Keayl::Routing::UrlHelpers.new(:$router);
  my $generated = $helpers.path-for($name, |@positional, |%named);

  $generated eq $expected
    or fail-assertion("expected '$name' to generate '$expected' but got '$generated'");

  True
}

sub assert-routing(MVC::Keayl::Router:D $router, Str:D $name, Str:D $method, Str:D $path, :%matching, *@positional, *%named --> Bool) is export {
  assert-generates($router, $name, $path, |@positional, |%named);
  assert-recognizes($router, $method, $path, :%matching);
  True
}

# Controller and view introspection

class RecordingRenderer is export {
  has @.rendered-templates;
  has @.rendered-partials;

  method render-template(Str:D $name, %locals, *%) {
    @!rendered-templates.push: $name;
    "[template:$name]"
  }

  method render-partial(Str:D $name, %locals, *%) {
    @!rendered-partials.push: $name;
    "[partial:$name]"
  }

  method render-inline(Str:D $template, %locals, *%) { $template }

  method layout-exists(Str:D $name --> Bool) { False }

  method last-rendered-template(--> Str) {
    @!rendered-templates.tail
  }
}

sub assert-rendered($renderer, Str:D $template --> Bool) is export {
  $renderer.rendered-templates.first($template)
    or fail-assertion("expected the '$template' template to be rendered, rendered: {$renderer.rendered-templates.join(', ')}");
  True
}

sub assert-assigned($controller, Str:D $name, $expected --> Bool) is export {
  my $actual = $controller.assigns{$name};
  ($actual // '') eq ~$expected
    or fail-assertion("expected assign '$name' to be '$expected' but got '{$actual // ''}'");
  True
}

# Mailer helpers

sub delivered-emails(--> List) is export {
  MVC::Keayl::Mailer::Delivery::Test.deliveries
}

sub assert-emails(Int:D $expected, &block --> Bool) is export {
  my $before = MVC::Keayl::Mailer::Delivery::Test.deliveries.elems;
  block();
  my $delivered = MVC::Keayl::Mailer::Delivery::Test.deliveries.elems - $before;

  $delivered == $expected
    or fail-assertion("expected $expected emails to be delivered but $delivered were");
  True
}

sub assert-no-emails(&block --> Bool) is export {
  assert-emails(0, &block)
}

# Job helpers

sub assert-enqueued-jobs(Int:D $expected, $adapter, &block --> Bool) is export {
  my $before = $adapter.enqueued.elems;
  block();
  my $enqueued = $adapter.enqueued.elems - $before;

  $enqueued == $expected
    or fail-assertion("expected $expected jobs to be enqueued but $enqueued were");
  True
}

sub perform-enqueued-jobs($adapter, &block? --> Bool) is export {
  block() if &block;
  $adapter.perform-all;
  True
}

# Cable helpers

sub assert-broadcasts($pubsub, Str:D $stream, Int:D $expected, &block --> Bool) is export {
  my @received;
  my $id = $pubsub.subscribe($stream, -> $message { @received.push: $message });

  block();
  $pubsub.unsubscribe($id);

  @received.elems == $expected
    or fail-assertion("expected $expected broadcasts on '$stream' but got {@received.elems}");
  True
}

sub assert-stream-subscribed($channel, Str:D $stream --> Bool) is export {
  $channel.stream-subscriptions.first({ .<stream> eq $stream })
    or fail-assertion("expected the channel to stream from '$stream'");
  True
}
