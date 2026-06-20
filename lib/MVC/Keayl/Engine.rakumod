use v6.d;
use MVC::Keayl::Router;
use MVC::Keayl::Dispatcher;
use MVC::Keayl::Routing;
use MVC::Keayl::View;

unit class MVC::Keayl::Engine;

sub underscore(Str:D $word --> Str) {
  $word.subst(/<?after .> <:Lu>/, { '_' ~ $/.Str }, :g).lc.subst('::', '/', :g)
}

has Str  $.namespace is rw = '';
has      @.controllers;
has      &.routes-block;
has      @.view-paths;
has      @.helper-paths;
has      @.asset-paths;
has      @!initializers;
has      $!router;

method isolate-namespace(Str:D $namespace --> ::?CLASS) {
  $!namespace = $namespace;
  self
}

method namespace-path(--> Str) {
  $!namespace eq '' ?? '' !! underscore($!namespace)
}

method initializer(Str:D $name, &block --> ::?CLASS) {
  @!initializers.push: %( :$name, :&block );
  self
}

method initializer-names(--> List) {
  @!initializers.map(*<name>).List
}

method run-initializers(--> ::?CLASS) {
  .<block>(self) for @!initializers;
  self
}

method append-view-paths(*@paths --> ::?CLASS)   { @!view-paths.append(@paths); self }
method append-helper-paths(*@paths --> ::?CLASS)  { @!helper-paths.append(@paths); self }
method append-asset-paths(*@paths --> ::?CLASS)   { @!asset-paths.append(@paths); self }

method router(--> MVC::Keayl::Router) {
  $!router //= routes(&!routes-block)
}

method controller-resolver(--> Callable) {
  my %by-name;
  my $prefix = self.namespace-path;

  for @!controllers -> $controller {
    my $full = $controller.controller-path;
    %by-name{$full} = $controller;

    my $short = $prefix ne '' ?? $full.subst(/^ "$prefix/" /, '') !! $full;
    %by-name{$short} = $controller;
  }

  -> $name {
    my $namespaced = "$prefix/$name";
    my $direct     = %by-name{$name}:exists;
    my $ns-exists  = %by-name{$namespaced}:exists;

    if $direct {
      %by-name{$name};
    } elsif $prefix ne '' && $ns-exists {
      %by-name{$namespaced};
    } else {
      Mu
    }
  }
}

method endpoint(:@view-path-overrides, :%controller-options --> MVC::Keayl::Dispatcher) {
  my @paths   = (|@view-path-overrides, |@!view-paths);
  my %options = %controller-options;

  %options<view-renderer> //= MVC::Keayl::View.new(paths => @paths.Array, reload => False) if @paths;

  MVC::Keayl::Dispatcher.new(
    router              => self.router,
    controllers         => @!controllers,
    controller-resolver => self.controller-resolver,
    controller-options  => %options,
  )
}
