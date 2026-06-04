use v6.d;
use JSON::Fast;
use MVC::Keayl::Request;
use MVC::Keayl::Response;

unit class MVC::Keayl::Controller;

has MVC::Keayl::Request  $.request;
has MVC::Keayl::Response $.response = MVC::Keayl::Response.new;
has      $.params = {};
has      $.view-renderer;
has Bool $!performed = False;

my %STATUS-CODES =
  ok => 200, created => 201, accepted => 202, 'no-content' => 204,
  'moved-permanently' => 301, found => 302, 'see-other' => 303,
  'not-modified' => 304, 'temporary-redirect' => 307,
  'bad-request' => 400, unauthorized => 401, forbidden => 403,
  'not-found' => 404, 'unprocessable-entity' => 422,
  'internal-server-error' => 500;

sub status-code($status --> Int) {
  return $status if $status ~~ Int;
  %STATUS-CODES{$status} // die "unknown status '$status'"
}

sub header-name(Str:D $key --> Str) {
  $key.split(/<[-_]>/).map(*.tc).join('-')
}

my %MIME-TYPES =
  html => 'text/html', htm => 'text/html', txt => 'text/plain',
  css => 'text/css', js => 'application/javascript', json => 'application/json',
  csv => 'text/csv', xml => 'application/xml',
  png => 'image/png', jpg => 'image/jpeg', jpeg => 'image/jpeg',
  gif => 'image/gif', svg => 'image/svg+xml',
  pdf => 'application/pdf', zip => 'application/zip';

sub mime-for(Str $extension --> Str) {
  %MIME-TYPES{($extension // '').lc} // 'application/octet-stream'
}

sub content-disposition(Str:D $disposition, $filename --> Str) {
  $filename.defined ?? "$disposition; filename=\"$filename\"" !! $disposition
}

# Parse a single-range `Range: bytes=...` header into a (start, end) pair, or
# (Nil, Nil) when it is absent or unsatisfiable.
sub parse-range($range, Int:D $total --> List) {
  return (Nil, Nil) without $range;
  return (Nil, Nil) unless $range ~~ /^ 'bytes=' (\d*) '-' (\d*) $/;

  my $from = ~$0;
  my $to   = ~$1;
  my ($start, $end);

  if $from ne '' && $to ne '' {
    $start = +$from;
    $end   = +$to;
  } elsif $from ne '' {
    $start = +$from;
    $end   = $total - 1;
  } elsif $to ne '' {
    $start = $total - +$to;
    $end   = $total - 1;
  } else {
    return (Nil, Nil);
  }

  $end = $total - 1 if $end > $total - 1;
  return (Nil, Nil) if $start > $end || $start < 0;

  ($start, $end)
}

method is-performed(--> Bool) {
  $!performed
}

method !is-action(Str:D $name --> Bool) {
  state $reserved = MVC::Keayl::Controller.^methods(:all).map(*.name).Set;
  self.^can($name).so && !$reserved{$name}
}

method dispatch(Str:D $action --> MVC::Keayl::Response) {
  die "unknown action '$action'" unless self!is-action($action);

  my $result = self."$action"();
  self.implicit-render($action, $result) unless $!performed;

  $!response
}

method render-template(Str:D $name, %locals --> Str) {
  die 'no view renderer configured' without $!view-renderer;
  $!view-renderer.render-template($name, %locals, controller => self)
}

method render-inline(Str:D $template, %locals --> Str) {
  die 'no view renderer configured' without $!view-renderer;
  $!view-renderer.render-inline($template, %locals, controller => self)
}

method render-layout(Str:D $layout, Str:D $content, %locals --> Str) {
  die 'no view renderer configured' without $!view-renderer;
  $!view-renderer.render-layout($layout, $content, %locals, controller => self)
}

method !wrap(Str:D $content, Bool $has-layout, $layout, %locals --> Str) {
  return $content unless $has-layout && $layout ~~ Str:D;
  self.render-layout($layout, $content, %locals)
}

method render(*@positional, *%options --> MVC::Keayl::Response) {
  die 'double render: a response was already rendered or redirected' if $!performed;
  $!performed = True;

  my $status      = %options<status>:delete;
  my $explicit-ct = %options<content-type>:delete;
  my $has-layout  = %options<layout>:exists;
  my $layout      = %options<layout>:delete;
  my %locals      = (%options<locals>:delete) // {};

  my $default-ct;
  my $body;

  if %options<json>:exists {
    $default-ct = 'application/json';
    $body = to-json(%options<json>, :!pretty);
  } elsif %options<plain>:exists {
    $default-ct = 'text/plain; charset=utf-8';
    $body = ~%options<plain>;
  } elsif %options<html>:exists {
    $default-ct = 'text/html; charset=utf-8';
    $body = ~%options<html>;
  } elsif %options<body>:exists {
    $body = ~%options<body>;
  } elsif %options<inline>:exists {
    $default-ct = 'text/html; charset=utf-8';
    $body = self!wrap(self.render-inline(~%options<inline>, %locals), $has-layout, $layout, %locals);
  } else {
    my $name = @positional[0] // %options<template> // %options<action>;
    with $name {
      $default-ct = 'text/html; charset=utf-8';
      $body = self!wrap(self.render-template(~$name, %locals), $has-layout, $layout, %locals);
    }
  }

  $!response.body($body) if $body.defined;

  my $content-type = $explicit-ct // $default-ct;
  $!response.content-type($content-type) if $content-type.defined;

  $!response.status = $status if $status.defined;

  $!response
}

method redirect-to($location?, Bool :$back, Str :$fallback = '/', :$status = 302 --> MVC::Keayl::Response) {
  die 'double render: a response was already rendered or redirected' if $!performed;
  $!performed = True;

  my $target = $back ?? (self.request.header('Referer') // $fallback) !! $location;

  $!response.status = status-code($status);
  $!response.location($target);

  $!response
}

method head($status, *%headers --> MVC::Keayl::Response) {
  die 'double render: a response was already rendered or redirected' if $!performed;
  $!performed = True;

  $!response.status = status-code($status);
  $!response.set-header(header-name(.key), ~.value) for %headers;

  $!response
}

method send-data($data, :$type, :$filename, Str :$disposition = 'attachment', :$status --> MVC::Keayl::Response) {
  die 'double render: a response was already rendered or redirected' if $!performed;
  $!performed = True;

  $!response.content-type($type // 'application/octet-stream');
  $!response.set-header('Content-Disposition', content-disposition($disposition, $filename));
  $!response.body($data ~~ Blob ?? $data !! ~$data);
  $!response.status = $status if $status.defined;

  $!response
}

method send-file($path, :$type, :$filename, Str :$disposition = 'attachment', :$status --> MVC::Keayl::Response) {
  die 'double render: a response was already rendered or redirected' if $!performed;
  $!performed = True;

  my $io    = $path.IO;
  my $bytes = $io.slurp(:bin);
  my $name  = $filename // $io.basename;

  $!response.content-type($type // mime-for($io.extension));
  $!response.set-header('Content-Disposition', content-disposition($disposition, $name));
  $!response.set-header('Accept-Ranges', 'bytes');

  with $!request {
    my ($start, $end) = parse-range($!request.header('Range'), $bytes.bytes);

    if $start.defined {
      $!response.status = 206;
      $!response.set-header('Content-Range', "bytes $start-$end/{$bytes.bytes}");
      $!response.body($bytes.subbuf($start, $end - $start + 1));
      return $!response;
    }
  }

  $!response.body($bytes);
  $!response.status = $status if $status.defined;

  $!response
}

method implicit-render(Str:D $action, $result --> Nil) {
  return if $!performed;

  if $!view-renderer.defined {
    self.render($action);
  } elsif $result ~~ Str:D && !$!response.body.chars {
    $!response.body($result);
  }
}
