use v6.d;
use MVC::Keayl::Controller;
use MVC::Keayl::Response;

unit class MVC::Keayl::APIController is MVC::Keayl::Controller;

has &.serializer;

method serialize($value) {
  return &!serializer($value) if &!serializer.defined;
  self!default-serialize($value)
}

method !default-serialize($value) {
  return $value.map({ self.serialize($_) }).Array if $value ~~ Positional;
  return $value.to-hash                           if $value.^can('to-hash');
  return $value.Hash                              if $value ~~ Associative;
  $value
}

method render-json($data, *%options --> MVC::Keayl::Response) {
  self.MVC::Keayl::Controller::render(:json(self.serialize($data)), |%options)
}

method render(*@positional, *%options --> MVC::Keayl::Response) {
  if @positional.elems && @positional[0].defined && @positional[0] !~~ Str {
    my $data = @positional.elems == 1 ?? @positional[0] !! @positional.Array;
    return self.MVC::Keayl::Controller::render(:json(self.serialize($data)), |%options);
  }

  self.MVC::Keayl::Controller::render(|@positional, |%options)
}
