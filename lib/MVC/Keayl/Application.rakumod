use v6.d;
use MVC::Keayl::Router;
use MVC::Keayl::MiddlewareStack;
use MVC::Keayl::Config;
use MVC::Keayl::Dispatcher;
use MVC::Keayl::Endpoint;
use MVC::Keayl::View;
use MVC::Keayl::Routing;

unit class MVC::Keayl::Application;

has $.router     = MVC::Keayl::Router.new;
has $.middleware = MVC::Keayl::MiddlewareStack.new;
has $.config     = MVC::Keayl::Config.new;
has @.controllers;
has %.controller-options;
has &.database-connector = -> %db { };
has @!initializers;
has Bool $.booted = False;

submethod TWEAK {
  self.initializer('active-record', -> $app {
    with $app.config<database> -> %db { $app.database-connector.(%db) }
  });

  self.initializer('template-haml', -> $app {
    $app.controller-options<view-renderer> //= MVC::Keayl::View.new(
      paths  => ($app.config<view-paths> // ['app/views']).Array,
      reload => !$app.is-production,
    );
  });
}

method initializer(Str:D $name, &block --> ::?CLASS) {
  @!initializers.push: %( :$name, :&block );
  self
}

method initializer-names(--> List) {
  @!initializers.map(*<name>).List
}

method draw-routes(&block --> ::?CLASS) {
  $!router = routes(&block);
  self
}

method environment(--> Str)    { $!config.environment }
method is-development(--> Bool) { $!config.environment eq 'development' }
method is-test(--> Bool)        { $!config.environment eq 'test' }
method is-production(--> Bool)   { $!config.environment eq 'production' }

method boot(--> ::?CLASS) {
  return self if $!booted;

  for @!initializers -> $initializer {
    $initializer<block>(self);
  }

  $!booted = True;
  self
}

method dispatcher(--> MVC::Keayl::Dispatcher) {
  MVC::Keayl::Dispatcher.new(
    router             => $!router,
    controllers        => @!controllers,
    controller-options => %!controller-options,
    verbose-errors     => self.is-development,
  )
}

method endpoint(--> MVC::Keayl::Endpoint) {
  self.boot;
  $!middleware.build(self.dispatcher)
}
