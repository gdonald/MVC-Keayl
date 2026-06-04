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

method implicit-render(Str:D $action, $result --> Nil) {
  return if $!performed;

  if $!view-renderer.defined {
    self.render($action);
  } elsif $result ~~ Str:D && !$!response.body.chars {
    $!response.body($result);
  }
}
