use v6.d;
use Template::HAML;
use MVC::Keayl::View::Handler;

unit class MVC::Keayl::View::Handler::HAML does MVC::Keayl::View::Handler;

method compile(Str:D $source) {
  $source
}

method render($source, %locals, :$context --> Str) {
  $context.defined
    ?? HAML.render(:src($source), :locals(%locals), :$context)
    !! HAML.render(:src($source), :locals(%locals))
}
