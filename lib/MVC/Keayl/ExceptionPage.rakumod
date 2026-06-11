use v6.d;

unit module MVC::Keayl::ExceptionPage;

sub escape($text --> Str) {
  ($text // '').Str.trans(['&', '<', '>', '"', "'"] => ['&amp;', '&lt;', '&gt;', '&quot;', '&#39;'])
}

sub definition-row(Str:D $term, $value --> Str) {
  "<tr><th>{escape($term)}</th><td>{escape(~($value // ''))}</td></tr>"
}

sub params-table(%params --> Str) {
  return '<p>None</p>' unless %params;

  my @rows = %params.sort(*.key).map({ definition-row(.key, .value.gist) });
  "<table>{@rows.join}</table>"
}

sub routes-table(@routes --> Str) {
  return '<p>None</p>' unless @routes;

  my @rows = @routes.map(-> %route {
    my $verbs  = (%route<verbs> // ()).join(', ');
    my $target = %route<target> ~~ Str ?? %route<target> !! %route<target>.^name;

    "<tr><td>{escape(%route<name> // '')}</td><td>{escape($verbs)}</td><td>{escape(%route<path>)}</td><td>{escape($target)}</td></tr>";
  });

  "<table><tr><th>Name</th><th>Verbs</th><th>Path</th><th>Target</th></tr>{@rows.join}</table>"
}

sub developer-exception-page(Exception:D $error, %context, @routes = () --> Str) is export {
  my $title = $error.^name ~ ': ' ~ $error.message;
  my $trace = (try ~$error.backtrace) // '';

  my $request-rows = [
    definition-row('Method', %context<method>),
    definition-row('Path', %context<path>),
    definition-row('Controller', %context<controller>),
    definition-row('Action', %context<action>),
    definition-row('Request ID', %context<request-id>),
  ].join;

  qq:to/HTML/;
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>{escape($title)}</title>
    </head>
    <body>
      <h1>{escape($error.^name)}</h1>
      <p class="message">{escape($error.message)}</p>

      <h2>Backtrace</h2>
      <pre class="backtrace">{escape($trace)}</pre>

      <h2>Request</h2>
      <table class="request">{$request-rows}</table>

      <h2>Parameters</h2>
      {params-table(%context<params> // %())}

      <h2>Routes</h2>
      {routes-table(@routes)}
    </body>
    </html>
    HTML
}
