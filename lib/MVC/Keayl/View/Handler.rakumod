use v6.d;

unit role MVC::Keayl::View::Handler;

method compile(Str:D $source) { ... }

method render($compiled, %locals, :$context --> Str) { ... }
