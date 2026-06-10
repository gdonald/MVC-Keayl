# Logging

The framework writes one line per request: the method, path, controller action,
status, total duration, action and view timings, and the request parameters with
the [parameter filter](parameter-filtering.md) applied.

## Enabling it

Logging is wired by an application initializer and driven by the `log-level`
config key. With no `log-level` set, the logger is `silent` and writes nothing,
so logging is opt-in: set a level in `config/application.json` to turn it on.

```json
{
  "development": { "log-level": "debug" },
  "production":  { "log-level": "info" }
}
```

Levels, from most to least verbose, are `debug`, `info`, `warn`, `error`, and
`silent`. A logger emits a message when the message's level is at or above its
threshold, so a logger at `info` shows `info`, `warn`, and `error`, and a logger
at `silent` shows nothing. Per-request lines are logged at `info`.

## The request line

```
[a1b2c3…] GET /posts/42 → posts#show 200 in 12.30ms action=8.10ms view=4.00ms params={id=42}
```

The leading `[…]` is the [request id](instrumentation.md), present when the
request-id middleware ran ahead of the logger.

- `action` is the time spent in the controller action.
- `view` is the time spent rendering templates, partials, and objects. When a
  view renders inside the action, its time is a subset of the action time.
- `params` are the controller's merged parameters after filtering. A key matching
  the filter list (`password`, `secret`, `token`, and the rest) is shown as
  `[FILTERED]`, so a secret never reaches the log.

A request that does not reach a controller (a 404 or a callable route) logs the
method, path, status, and duration without an action name or timings.

## MVC::Keayl::Logger

`MVC::Keayl::Logger` is the sink. It holds a `level` threshold and an `out`
handle (standard error by default), and exposes `debug`, `info`, `warn`, and
`error`. `Application` builds one from `log-level` and exposes it as `app.logger`;
pass your own to write elsewhere.

```perl6
my $logger = MVC::Keayl::Logger.new(level => 'info', out => $*OUT);
$logger.info('booting');
```

## MVC::Keayl::Middleware::Logger

The request logger is a middleware prepended to the stack so it wraps the whole
request. It times the request with an injectable clock, installs a per-request
`MVC::Keayl::LogEvent` that the controller records timings and parameters into,
and writes the formatted line through the logger once the response is ready. When
the logger is disabled it serves the request without recording anything.
