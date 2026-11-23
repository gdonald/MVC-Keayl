use v6.d;
use Template::HAML;
use Template::HAML::Config;
use Template::HAML::Context;
use Template::HAML::DirectCodegen;
use Template::HAML::Eval;
use Template::HAML::ViewContext;
use MVC::Keayl::View::Handler;

unit class MVC::Keayl::View::Handler::HAML does MVC::Keayl::View::Handler;

my class Compiled {
  has $.tree;
  has @!callables;
  has Lock $!lock = Lock.new;

  method callable-for(@helper-names, Template::HAML::Config:D $config --> Code) {
    my $wanted = @helper-names.Set;

    $!lock.protect: {
      my $covering = @!callables.first({ $wanted (<=) .<names> });

      $covering.defined ?? $covering<callable> !! do {
        my &callable = compile-direct-fn($!tree, $config, helper-names => @helper-names.sort.Array);

        @!callables.push: %( names => $wanted, :&callable );
        &callable
      }
    }
  }
}

has Template::HAML::Config $.config = Template::HAML::Config.new;
has %!compiled;
has Lock $!compiled-lock = Lock.new;

method compile(Str:D $source, :@helper-names) {
  return $source unless $!config.emit eq 'direct';

  my $compiled = $!compiled-lock.protect: {
    %!compiled{$source} //= Compiled.new(tree => HAML.parse-source(:src($source), :$!config))
  };
  $compiled.callable-for(@helper-names, $!config) if @helper-names;

  $compiled
}

multi method render(Str:D $source, %locals, :$context --> Str) {
  $context.defined
    ?? HAML.render(:src($source), :locals(%locals), :$!config, :$context)
    !! HAML.render(:src($source), :locals(%locals), :$!config)
}

multi method render(Compiled:D $compiled, %locals, :$context --> Str) {
  my &callable = $compiled.callable-for(context-helper-names($context), $!config);
  my $haml-context = Template::HAML::Context.new(:haml(HAML), :user-context($context // Template::HAML::ViewContext.new));

  callable(%locals, :_haml_config($!config), :_haml_ctx($haml-context))
}
