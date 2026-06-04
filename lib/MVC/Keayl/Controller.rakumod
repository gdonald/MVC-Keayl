use v6.d;
use MVC::Keayl::Request;
use MVC::Keayl::Response;

unit class MVC::Keayl::Controller;

has MVC::Keayl::Request  $.request;
has MVC::Keayl::Response $.response = MVC::Keayl::Response.new;
has      $.params = {};
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

method implicit-render(Str:D $action, $result --> Nil) {
  return unless $result ~~ Str:D;
  return if $!response.body.chars;

  $!response.body($result);
}
