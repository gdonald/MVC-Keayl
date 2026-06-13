use v6.d;
use MVC::Keayl::Router;
use MVC::Keayl::MiddlewareStack;
use MVC::Keayl::Config;
use MVC::Keayl::Dispatcher;
use MVC::Keayl::Endpoint;
use MVC::Keayl::View;
use MVC::Keayl::Routing;
use MVC::Keayl::Logger;
use MVC::Keayl::Middleware::Logger;
use MVC::Keayl::Middleware::RequestId;
use MVC::Keayl::ErrorReporting;
use MVC::Keayl::ErrorReporter;
use MVC::Keayl::I18n;

unit class MVC::Keayl::Application;

has $.router      = MVC::Keayl::Router.new;
has $.middleware  = MVC::Keayl::MiddlewareStack.new;
has $.config      = MVC::Keayl::Config.new;
has $.logger is rw;
has @.error-reporters;
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

  self.initializer('i18n', -> $app {
    with $app.config<i18n> -> %i18n {
      my $backend = MVC::Keayl::I18n.new(
        default-locale    => (%i18n<default-locale> // 'en'),
        available-locales => (%i18n<available-locales> // []).Array,
        use-fallbacks     => (%i18n<fallbacks> // True),
        raise-on-missing  => (%i18n<raise-on-missing> // False),
      );

      $backend.load-locales((%i18n<load-path> // 'config/locales').IO);

      $app.controller-options<i18n>         //= $backend;
      $app.controller-options<i18n-options> //= %(
        strategies => (%i18n<strategies> // <param header>),
        param      => (%i18n<param> // 'locale'),
      );
    }
  });

  self.initializer('request-logging', -> $app {
    $app.logger //= MVC::Keayl::Logger.new(level => $app.config<log-level> // 'silent');

    $app.middleware.prepend('request-logger', MVC::Keayl::Middleware::Logger, logger => $app.logger);
  });

  self.initializer('request-id', -> $app {
    $app.middleware.prepend('request-id', MVC::Keayl::Middleware::RequestId);
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

method report-errors-with(MVC::Keayl::ErrorReporter:D $reporter --> ::?CLASS) {
  @!error-reporters.push: $reporter;
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
    error-reporting    => MVC::Keayl::ErrorReporting.new(reporters => @!error-reporters),
  )
}

method endpoint(--> MVC::Keayl::Endpoint) {
  self.boot;
  $!middleware.build(self.dispatcher)
}
