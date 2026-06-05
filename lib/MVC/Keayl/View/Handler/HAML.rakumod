use v6.d;
use Template::HAML;
use MVC::Keayl::View::Handler;

unit class MVC::Keayl::View::Handler::HAML does MVC::Keayl::View::Handler;

method compile(Str:D $source) {
  $source
}

method render($source, %locals --> Str) {
  HAML.render(:src($source), :locals(%locals))
}
