use v6.d;
use JSON::Fast;
use MVC::Keayl::Request;
use MVC::Keayl::Response;
use MVC::Keayl::Parameters;
use MVC::Keayl::Errors;
use MVC::Keayl::Cookies;
use MVC::Keayl::Session;
use MVC::Keayl::Flash;
use MVC::Keayl::CSRF;
use MVC::Keayl::ParameterFilter;
use MVC::Keayl::Notifications;
use MVC::Keayl::Mime;
use MVC::Keayl::Caching;
use MVC::Keayl::Cache;
use MVC::Keayl::I18n::Locale;
use MVC::Keayl::HttpAuthentication;
use MVC::Keayl::Live;

unit class MVC::Keayl::Controller;

has MVC::Keayl::Request  $.request;
has MVC::Keayl::Response $.response = MVC::Keayl::Response.new;
has      $.params = MVC::Keayl::Parameters.new({});
has      $.view-renderer;
has Str  $.secret = '';
has      $.session-store = MVC::Keayl::Session::CookieStore.new;
has      $.i18n;
has      %.i18n-options;
has Str  $.current-action is rw;
has      %!assigns;
has      $!cookies;
has      $!session;
has      $!flash;
has Bool $!performed = False;

my %STATUS-CODES =
  ok => 200, created => 201, accepted => 202, 'no-content' => 204,
  'moved-permanently' => 301, found => 302, 'see-other' => 303,
  'not-modified' => 304, 'temporary-redirect' => 307,
  'bad-request' => 400, unauthorized => 401, forbidden => 403,
  'not-found' => 404, 'unprocessable-entity' => 422,
  'too-many-requests' => 429, 'internal-server-error' => 500;

sub status-code($status --> Int) {
  return $status if $status ~~ Int;
  %STATUS-CODES{$status} // die "unknown status '$status'"
}

sub header-name(Str:D $key --> Str) {
  $key.split(/<[-_]>/).map(*.tc).join('-')
}

sub singularize(Str:D $word --> Str) {
  return $word.subst(/ 'ies' $/, 'y') if $word.ends-with('ies');
  return $word.subst(/ 'ses' $/, 's') if $word.ends-with('ses');
  return $word.substr(0, *- 1)         if $word.ends-with('s');
  $word
}

my %MIME-TYPES =
  html => 'text/html', htm => 'text/html', txt => 'text/plain',
  css => 'text/css', js => 'application/javascript', json => 'application/json',
  csv => 'text/csv', xml => 'application/xml',
  png => 'image/png', jpg => 'image/jpeg', jpeg => 'image/jpeg',
  gif => 'image/gif', svg => 'image/svg+xml',
  pdf => 'application/pdf', zip => 'application/zip';

sub mime-for(Str $extension --> Str) {
  %MIME-TYPES{($extension // '').lc} // 'application/octet-stream'
}

sub content-disposition(Str:D $disposition, $filename --> Str) {
  $filename.defined ?? "$disposition; filename=\"$filename\"" !! $disposition
}

# Parse a single-range `Range: bytes=...` header into a (start, end) pair, or
# (Nil, Nil) when it is absent or unsatisfiable.
sub parse-range($range, Int:D $total --> List) {
  return (Nil, Nil) without $range;
  return (Nil, Nil) unless $range ~~ /^ 'bytes=' (\d*) '-' (\d*) $/;

  my $from = ~$0;
  my $to   = ~$1;
  my ($start, $end);

  if $from ne '' && $to ne '' {
    $start = +$from;
    $end   = +$to;
  } elsif $from ne '' {
    $start = +$from;
    $end   = $total - 1;
  } elsif $to ne '' {
    $start = $total - +$to;
    $end   = $total - 1;
  } else {
    return (Nil, Nil);
  }

  $end = $total - 1 if $end > $total - 1;
  return (Nil, Nil) if $start > $end || $start < 0;

  ($start, $end)
}

my %before-actions{Mu};
my %after-actions{Mu};
my %around-actions{Mu};
my %skip-before{Mu};
my %skip-after{Mu};
my %skip-around{Mu};
my %rescues{Mu};
my %renderers;

# Per-class configuration declared through an `is` trait or a class-method call
# (`is layout`, `.protect-from-forgery`, `.filter-parameters`, ...). A `my %{Mu}`
# registry keyed by the class is populated in the precompiling process and is
# empty once the controller loads from its precompiled form, so a declaration on
# a separately compiled controller would silently be lost. Storing the value in
# a method added to the class serializes it with the class instead, mirroring how
# method-level callback traits ride along on the method.
sub config-cell(Mu:U $class, Str $slot --> Array) {
  my $name = '!keayl-config-' ~ $slot;

  unless $class.^method_table{$name}:exists {
    my @cell;

    $class.^add_method($name, method (--> Array) { @cell });
    $class.^invalidate_method_caches;
  }

  $class.^method_table{$name}.($class)
}

sub config-cell-local(Mu:U $class, Str $slot --> Array) {
  my $name = '!keayl-config-' ~ $slot;

  $class.^method_table{$name}:exists
    ?? $class.^method_table{$name}.($class)
    !! []
}

# Method-level callback declarations (`is before-action`, `is helper-method`,
# `is rescue-from`, ...) are marked on the method through a parametric role
# rather than recorded in a class-keyed registry. A `my %` registry is mutated
# at class-composition time and is empty once the controller loads from its
# precompiled form, so an inherited callback declared on a separately compiled
# base controller would silently never run. A role mixed into a method is
# serialized with the class and recovered by introspection, so it survives
# precompilation.
role ActionCallbackTrait[Str $kind, %options] {
  method callback-kind(--> Str)     { $kind }
  method callback-options(--> Hash) { %options }
}

role RescueFromTrait[$types] {
  method rescue-types(--> List) { $types.list }
}

role HelperMethodTrait { }

method helper-method(*@names --> ::?CLASS) {
  config-cell(self, 'helper-methods').append(@names.map(*.Str));
  self
}

method add-renderer(Str:D $name, &block --> ::?CLASS) {
  %renderers{$name} = &block;
  self
}

method add-flash-types(*@types --> ::?CLASS) {
  register-flash-type($_.Str) for @types;
  self
}

method variant(--> Str) {
  $!request.defined ?? $!request.variant !! Str
}

method assign(Str:D $name, $value --> ::?CLASS) {
  %!assigns{$name} = $value;
  self
}

method assigns(--> Hash) {
  %!assigns
}

method !lazy-scope(--> Str) {
  (self.controller-path.subst('/', '.', :g) ~ '.' ~ ($!current-action // '')).chomp('.')
}

method translate($key, *%options --> Str) {
  die 'no i18n backend configured' without $!i18n;

  return $!i18n.translate($key.substr(1), scope => self!lazy-scope, |%options)
    if $key ~~ Str && $key.starts-with('.');

  $!i18n.translate($key, |%options)
}

method t($key, *%options --> Str) { self.translate($key, |%options) }

method localize($object, *%options --> Str) {
  die 'no i18n backend configured' without $!i18n;
  $!i18n.localize($object, |%options)
}

method l($object, *%options --> Str) { self.localize($object, |%options) }

method current-locale(--> Str) {
  return 'en' without $!i18n;

  resolve-locale(
    $!request,
    strategies => (%!i18n-options<strategies> // <param header>),
    available  => (%!i18n-options<available>  // $!i18n.available-locales),
    default    => (%!i18n-options<default>    // $!i18n.default-locale),
    param      => (%!i18n-options<param>      // 'locale'),
  )
}

method default-url-options(--> Hash) {
  return %() without $!i18n;
  locale-url-options($!i18n.locale, param => (%!i18n-options<param> // 'locale'))
}

method !helper-method-names(--> List) {
  my @names;
  for self.^mro.reverse -> $class {
    @names.append(|config-cell-local($class, 'helper-methods'));
    @names.append($class.^methods(:local).grep({ $_ ~~ HelperMethodTrait }).map(*.name));
  }
  @names.unique.List
}

method !view-locals(%explicit --> Hash) {
  my %locals;
  %locals{$_} = self."$_"() for self!helper-method-names;
  %locals{.key} = .value for %!assigns;
  %locals<flash> = self.flash.to-hash if self.flash.keys;
  %locals{.key} = .value for %explicit;
  %locals
}

my @DEFAULT-RESCUES =
  %( type => X::MVC::Keayl::ParameterMissing,      handler => sub ($controller, $error) { $controller.head(400) } ),
  %( type => X::MVC::Keayl::UnpermittedParameters, handler => sub ($controller, $error) { $controller.head(400) } ),
  %( type => X::MVC::Keayl::NotFound,              handler => sub ($controller, $error) { $controller.head(404) } ),
  %( type => X::MVC::Keayl::InvalidAuthenticityToken, handler => sub ($controller, $error) { $controller.head(422) } );

method rescue-from($type, $handler --> ::?CLASS) {
  (%rescues{self} //= []).push: %( :$type, :$handler );
  self
}

sub action-set($value) {
  return Nil without $value;
  ($value ~~ Str ?? ($value,) !! $value.list).map(*.Str).Set
}

sub callback-spec($callback, $only, $except, $if, $unless) {
  { :$callback, only => action-set($only), except => action-set($except), :$if, :$unless }
}

method before-action($callback, :$only, :$except, :$if, :$unless) {
  (%before-actions{self} //= []).push: callback-spec($callback, $only, $except, $if, $unless);
  self
}

method after-action($callback, :$only, :$except, :$if, :$unless) {
  (%after-actions{self} //= []).push: callback-spec($callback, $only, $except, $if, $unless);
  self
}

method around-action($callback, :$only, :$except, :$if, :$unless) {
  (%around-actions{self} //= []).push: callback-spec($callback, $only, $except, $if, $unless);
  self
}

method skip-before-action($callback, :$only, :$except) {
  (%skip-before{self} //= []).push: { :$callback, only => action-set($only), except => action-set($except) };
  self
}

method skip-after-action($callback, :$only, :$except) {
  (%skip-after{self} //= []).push: { :$callback, only => action-set($only), except => action-set($except) };
  self
}

method skip-around-action($callback, :$only, :$except) {
  (%skip-around{self} //= []).push: { :$callback, only => action-set($only), except => action-set($except) };
  self
}

sub trait-callback-options($value --> Hash) {
  return {} if $value ~~ Bool;

  my @pairs = $value ~~ Pair ?? ($value,) !! $value.list;
  %( @pairs.map({ .key => .value }) )
}

multi sub trait_mod:<is>(Method:D $method, :$before-action!) is export {
  $method does ActionCallbackTrait['before-action', trait-callback-options($before-action)];
}

multi sub trait_mod:<is>(Method:D $method, :$after-action!) is export {
  $method does ActionCallbackTrait['after-action', trait-callback-options($after-action)];
}

multi sub trait_mod:<is>(Method:D $method, :$around-action!) is export {
  $method does ActionCallbackTrait['around-action', trait-callback-options($around-action)];
}

multi sub trait_mod:<is>(Method:D $method, :$rescue-from!) is export {
  my @types = $rescue-from ~~ Positional ?? $rescue-from.list !! ($rescue-from,);
  $method does RescueFromTrait[@types.List];
}

multi sub trait_mod:<is>(Method:D $method, :$helper-method!) is export {
  $method does HelperMethodTrait;
}

sub trait-call-args($value --> Capture) {
  return \() if $value ~~ Bool;

  my @items = $value ~~ Positional ?? $value.list !! ($value,);
  Capture.new(
    list => @items.grep({ $_ !~~ Pair }).List,
    hash => %( @items.grep({ $_ ~~ Pair }).map({ .key => .value }) ),
  )
}

multi sub trait_mod:<is>(::?CLASS:U $type, :$layout!) is export {
  $type.layout(|trait-call-args($layout));
}

multi sub trait_mod:<is>(::?CLASS:U $type, :$protect-from-forgery!) is export {
  $type.protect-from-forgery(|trait-call-args($protect-from-forgery));
}

multi sub trait_mod:<is>(::?CLASS:U $type, :$rate-limit!) is export {
  $type.rate-limit(|trait-call-args($rate-limit));
}

multi sub trait_mod:<is>(::?CLASS:U $type, :$wrap-parameters!) is export {
  $type.wrap-parameters(|trait-call-args($wrap-parameters));
}

multi sub trait_mod:<is>(::?CLASS:U $type, :$filter-parameters!) is export {
  $type.filter-parameters(|trait-call-args($filter-parameters));
}

multi sub trait_mod:<is>(::?CLASS:U $type, :$add-flash-types!) is export {
  $type.add-flash-types(|trait-call-args($add-flash-types));
}

multi sub trait_mod:<is>(::?CLASS:U $type, :$http-basic-authenticate-with!) is export {
  $type.http-basic-authenticate-with(|trait-call-args($http-basic-authenticate-with));
}

method !collect(%registry --> List) {
  my @result;
  @result.append(|(%registry{$_} // [])) for self.^mro.reverse;
  @result
}

# Callbacks declared with the `is before-action`/`after`/`around` traits, read
# back from the role mixed into each method. Base-to-derived so an inherited
# callback runs before the subclass's.
method !method-trait-callbacks(Str:D $kind --> List) {
  my @result;
  for self.^mro.reverse -> $class {
    for $class.^methods(:local).grep({ $_ ~~ ActionCallbackTrait && .callback-kind eq $kind }) -> $method {
      my %options = $method.callback-options;
      @result.push: callback-spec($method.name, %options<only>, %options<except>, %options<if>, %options<unless>);
    }
  }
  @result
}

method !applies-to($spec, $action --> Bool) {
  with $spec<only>   { return False unless $_{$action} }
  with $spec<except> { return False if $_{$action} }
  True
}

method !is-skipped($spec, @skips, $action --> Bool) {
  return False unless $spec<callback> ~~ Str;

  for @skips -> $skip {
    next unless $skip<callback> ~~ Str && $skip<callback> eq $spec<callback>;
    return True if self!applies-to($skip, $action);
  }

  False
}

method !condition-passes($spec --> Bool) {
  with $spec<if>     { return False unless self!eval-condition($_) }
  with $spec<unless> { return False if self!eval-condition($_) }
  True
}

method !eval-condition($condition) {
  $condition ~~ Callable ?? ?$condition(self) !! ?self."$condition"()
}

method !active-callbacks(%registry, %skip-registry, $action, Str:D $kind --> List) {
  my @skips = self!collect(%skip-registry);

  (|self!collect(%registry), |self!method-trait-callbacks($kind)).grep({
    self!applies-to($_, $action) && !self!is-skipped($_, @skips, $action) && self!condition-passes($_)
  }).List
}

method !invoke-callback($spec) {
  my $callback = $spec<callback>;
  $callback ~~ Callable ?? $callback(self) !! self."$callback"()
}

method !invoke-around($spec, $next) {
  my $callback = $spec<callback>;
  $callback ~~ Callable ?? $callback(self, $next) !! self."$callback"($next)
}

method !run-with-callbacks(Str:D $action) {
  for self!active-callbacks(%before-actions, %skip-before, $action, 'before-action') -> $callback {
    self!invoke-callback($callback);
    return if $!performed;
  }

  my $core = sub {
    return if $!performed;
    my $result = self!timed('action', { self."$action"() });
    self.implicit-render($action, $result) unless $!performed;
  };

  my $chain = $core;
  for self!active-callbacks(%around-actions, %skip-around, $action, 'around-action').reverse -> $callback {
    my $next = $chain;
    $chain = sub { self!invoke-around($callback, $next) };
  }
  $chain();

  for self!active-callbacks(%after-actions, %skip-after, $action, 'after-action').reverse -> $callback {
    self!invoke-callback($callback);
  }
}

sub underscore(Str:D $word --> Str) {
  $word.subst(/<?after .> <:Lu>/, { '_' ~ $/.Str }, :g).lc
}

method controller-path(--> Str) {
  self.^name.subst(/^ 'GLOBAL::' /, '').subst(/'Controller'$/, '').split('::').map(&underscore).join('/')
}

method is-performed(--> Bool) {
  $!performed
}

method !is-action(Str:D $name --> Bool) {
  # An action is a public method introduced by a controller subclass. A name
  # resolving to the framework base (or to Mu/Any) is framework surface, not an
  # action -- unless a subclass deliberately overrides it, as a RESTful `new` or
  # `edit` action does when it shadows a built-in name. In that case the resolved
  # method is owned by the subclass, so it is a valid action.
  with self.^can($name).first -> $method {
    return $method.package !=== MVC::Keayl::Controller
        && $method.package ~~ MVC::Keayl::Controller;
  }
  False
}

method !collect-rescues(--> List) {
  my @entries;
  @entries.push($_) for @DEFAULT-RESCUES;

  for self.^mro.reverse -> $class {
    @entries.push($_) for (%rescues{$class} // []).list;
    for $class.^methods(:local).grep({ $_ ~~ RescueFromTrait }) -> $method {
      @entries.push(%( type => $_, handler => $method.name )) for $method.rescue-types;
    }
  }

  @entries
}

method !rescue-handler-for($exception) {
  my @mro = $exception.^mro.map(*.^name);
  my %rank;
  %rank{@mro[$_]} //= $_ for ^@mro;

  my @matching = self!collect-rescues().grep({ %rank{$_<type>.^name}:exists });
  return Nil unless @matching;

  my $best = @matching.shift;
  $best = $_ if %rank{$_<type>.^name} <= %rank{$best<type>.^name} for @matching;

  $best<handler>
}

method !invoke-rescue($handler, $exception) {
  $!performed = False;
  $handler ~~ Callable ?? $handler(self, $exception) !! self."$handler"($exception);
}

method dispatch(Str:D $action --> MVC::Keayl::Response) {
  die "unknown action '$action'" unless self!is-action($action);

  $!current-action = $action;

  self!apply-parameter-wrapping;

  with $*KEAYL-LOG-EVENT -> $event {
    $event.target = self.controller-path ~ '#' ~ $action;
    $event.set-params(self.filtered-params);
  }

  my &run = {
    CATCH {
      default {
        my $exception = $_;
        my $handler = self!rescue-handler-for($exception);
        $exception.rethrow without $handler;
        self!invoke-rescue($handler, $exception);
      }
    }

    self!run-with-callbacks($action);
  }

  with $!i18n {
    $!i18n.with-locale(self.current-locale, &run);
  } else {
    run();
  }

  self!commit-flash;
  self!commit-session;
  self!flush-cookies;

  $!response
}

method cookies(--> MVC::Keayl::Cookies) {
  $!cookies //= MVC::Keayl::Cookies.parse(
    ($!request.defined ?? $!request.header('cookie') !! Str),
    secret => $!secret,
  )
}

method session(--> MVC::Keayl::Session) {
  $!session //= MVC::Keayl::Session.new(data => $!session-store.load(self.cookies))
}

method reset-session {
  self.session.reset;
}

method flash(--> MVC::Keayl::Flash) {
  $!flash //= MVC::Keayl::Flash.from-session(self.session<_flash> // {})
}

method !commit-flash {
  return without $!flash;

  my %value = $!flash.to-session-value;

  if %value {
    self.session<_flash> = %value;
  } elsif self.session<_flash>:exists {
    self.session<_flash>:delete;
  }
}

method !commit-session {
  return without $!session;
  $!session-store.commit(self.cookies, $!session);
}

method protect-from-forgery(:$with = 'exception' --> ::?CLASS) {
  config-cell(self, 'forgery-strategy')[0] = $with;
  self.before-action('verify-authenticity-token');
  self
}

method skip-forgery-protection(:$only, :$except --> ::?CLASS) {
  self.skip-before-action('verify-authenticity-token', :$only, :$except);
  self
}

my $default-rate-store = MVC::Keayl::Cache::MemoryStore.new;

method rate-limit(Int :$to!, :$within!, :$by, :$with, :$store, Str :$name = 'default', :$only, :$except --> ::?CLASS) {
  my $cache   = $store // $default-rate-store;
  my $seconds = $within;

  self.before-action(-> $controller {
    my $discriminator = $by.defined
      ?? $by($controller)
      !! ($controller.request.defined ?? $controller.request.remote-ip !! Str);

    my $key = 'rate-limit/' ~ $controller.controller-path ~ '/' ~ $name ~ '/' ~ ($discriminator // '');

    if $cache.increment($key, 1, expires-in => $seconds) > $to {
      $with.defined
        ?? $with($controller)
        !! $controller.head(429, retry-after => $seconds.Int);
    }
  }, :$only, :$except);

  self
}

method !forgery-strategy(--> Str) {
  for self.^mro -> $class {
    my @cell = config-cell-local($class, 'forgery-strategy');
    return @cell[0] if @cell;
  }

  'exception'
}

method csrf-token(--> Str) {
  my $real = self.session<_csrf_token>;

  without $real {
    $real = generate-token();
    self.session<_csrf_token> = $real;
  }

  mask-token($real)
}

method verify-authenticity-token {
  return if self!request-safe;
  return if self!valid-authenticity-token;
  self!handle-unverified-request;
}

method !request-safe(--> Bool) {
  return True without $!request;
  ($!request.method // 'GET').uc (elem) <GET HEAD OPTIONS TRACE>
}

method !valid-authenticity-token(--> Bool) {
  my $real = self.session<_csrf_token>;
  return False without $real;

  my $submitted = self.params<authenticity_token>
    // ($!request.defined ?? $!request.header('X-CSRF-Token') !! Str);

  valid-token($submitted, $real)
}

method !handle-unverified-request {
  given self!forgery-strategy {
    when 'null-session' | 'reset-session' { self.reset-session }
    default                               { die X::MVC::Keayl::InvalidAuthenticityToken.new }
  }
}

method !authorization-header(--> Str) {
  $!request.defined ?? $!request.header('authorization') !! Str
}

method authenticate-with-http-basic(&block) {
  my @credentials = decode-basic-credentials(self!authorization-header);
  return Nil unless @credentials;

  block(@credentials[0], @credentials[1])
}

method request-http-basic-authentication(Str:D $realm = 'Application' --> Bool) {
  $!response.set-header('WWW-Authenticate', qq{Basic realm="$realm"});
  self.head(401);
  False
}

method authenticate-or-request-with-http-basic(Str:D $realm, &block) {
  self.authenticate-with-http-basic(&block) || self.request-http-basic-authentication($realm)
}

method http-basic-authenticate-with(Str:D :$name!, Str:D :$password!, Str:D :$realm = 'Application', :$only, :$except --> ::?CLASS) {
  self.before-action(-> $controller {
    my $authenticated = $controller.authenticate-with-http-basic(-> $user, $pass {
      secure-compare($user, $name) && secure-compare($pass, $password)
    });

    $controller.request-http-basic-authentication($realm) unless $authenticated;
  }, :$only, :$except);

  self
}

method authenticate-with-http-token(&block) {
  my ($token, %options) = token-and-options(self!authorization-header);
  return Nil without $token;

  block($token, %options)
}

method request-http-token-authentication(Str:D $realm = 'Application' --> Bool) {
  $!response.set-header('WWW-Authenticate', qq{Token realm="$realm"});
  self.head(401);
  False
}

method authenticate-or-request-with-http-token(Str:D $realm, &block) {
  self.authenticate-with-http-token(&block) || self.request-http-token-authentication($realm)
}

method authenticate-with-http-digest(Str:D $realm, &password-block) {
  my %params = parse-digest-header(self!authorization-header);
  return Nil unless %params;

  my $username = %params<username>;
  return Nil without $username;
  return Nil unless validate-digest-nonce($!secret, %params<nonce>);

  my $password = password-block($username);
  return Nil without $password;

  my $method   = $!request.defined ?? $!request.method !! 'GET';
  my $expected = expected-digest-response(%params, $method, $realm, $username, $password);

  return Nil unless secure-compare($expected, %params<response> // '');

  $username
}

method request-http-digest-authentication(Str:D $realm = 'Application' --> Bool) {
  $!response.set-header('WWW-Authenticate', digest-challenge($realm, $!secret, time));
  self.head(401);
  False
}

method authenticate-or-request-with-http-digest(Str:D $realm, &password-block) {
  self.authenticate-with-http-digest($realm, &password-block)
    || self.request-http-digest-authentication($realm)
}

method wrap-parameters($key?, :$format, :$include, :$exclude --> ::?CLASS) {
  config-cell(self, 'wrap-config')[0] = {
    key     => ($key.defined ?? $key.Str !! Str),
    formats => action-set($format // <json>),
    include => ($include.defined ?? $include.list.map(*.Str).List !! Nil),
    exclude => ($exclude.defined ?? $exclude.list.map(*.Str).List !! Nil),
  };
  self
}

method !wrap-config {
  for self.^mro -> $class {
    my @cell = config-cell-local($class, 'wrap-config');
    return @cell[0] if @cell;
  }

  Nil
}

method !default-wrap-key(--> Str) {
  singularize(self.controller-path.split('/')[*-1])
}

method !request-content-format(--> Str) {
  return Str without $!request;

  my $content-type = ($!request.header('content-type') // '').split(';')[0].trim;
  return Str if $content-type eq '';

  mime-format($content-type)
}

method !wrap-attributes($config --> Hash) {
  my %source = self.params.Hash;
  my %result;

  with $config<include> {
    %result{$_} = %source{$_} for $_.list.grep({ %source{$_}:exists });
  } orwith $config<exclude> {
    my %excluded = $_.list.map(* => True);
    %result{.key} = .value for %source.grep({ !%excluded{.key} });
  } else {
    %result = %source;
  }

  %result
}

method !apply-parameter-wrapping {
  my $config = self!wrap-config;
  return without $config;

  my $format = self!request-content-format;
  return without $format;
  return unless $config<formats>{$format};

  my $key = $config<key> // self!default-wrap-key;
  return if self.params{$key}:exists;

  my %wrapped = self!wrap-attributes($config);
  return unless %wrapped;

  my %merged = self.params.Hash;
  %merged{$key} = %wrapped;

  $!params = MVC::Keayl::Parameters.new(%merged);
}

method filter-parameters(*@names --> ::?CLASS) {
  config-cell(self, 'param-filters').append(@names);
  self
}

method !configured-param-filters(--> List) {
  my @filters;
  @filters.append(|config-cell-local($_, 'param-filters')) for self.^mro.reverse;
  @filters.List
}

method filtered-params(--> Hash) {
  MVC::Keayl::ParameterFilter.new(also => self!configured-param-filters).filter(self.params.Hash)
}

method respond-to(@formats --> MVC::Keayl::Response) {
  my @available = @formats.map(*.key.Str);
  my $format    = self!negotiate-format(@available);

  return self.head(406) without $format;

  self!invoke-format-handler(@formats.first(*.key.Str eq $format).value);

  $!response
}

method !invoke-format-handler($handler) {
  unless $handler ~~ Associative {
    $handler();
    return;
  }

  my $variant = self.variant;
  my $block   = ($variant.defined ?? $handler{$variant} !! Nil) // $handler<any> // $handler{''};

  $block() if $block.defined;
}

method request-format(--> Str) {
  return Str without $!request;

  my $path = $!request.path // '';
  $path ~~ / '.' (\w+) $/ ?? ~$0 !! Str
}

method !negotiate-format(@available --> Str) {
  with self.request-format -> $extension {
    return @available.first(* eq $extension) // Str;
  }

  my $accept = $!request.defined ?? $!request.header('accept') !! Str;

  negotiate(@available, $accept)
}

method fresh-when(:$etag, :$last-modified, Bool :$weak = True, :$cache-control --> Bool) {
  with $etag {
    my $value = ($_ ~~ Str && ($_.starts-with('"') || $_.starts-with('W/'))) ?? $_ !! etag-for($_, :$weak);
    $!response.set-header('ETag', $value);
  }

  with $last-modified {
    $!response.set-header('Last-Modified', $_ ~~ DateTime ?? http-date($_) !! ~$_);
  }

  $!response.set-header('Cache-Control', $cache-control) with $cache-control;

  my $fresh = self!request-fresh;

  if $fresh {
    $!response.status = 304;
    $!response.body('');
    $!performed = True;
  }

  $fresh
}

method is-stale(*%args --> Bool) {
  !self.fresh-when(|%args)
}

method expires-in($seconds, Bool :$public, *%directives --> ::?CLASS) {
  my @parts = $public ?? 'public' !! 'private';
  @parts.push('max-age=' ~ $seconds.Int);

  for %directives.sort(*.key) -> $directive {
    next unless $directive.value;
    @parts.push($directive.key.subst('_', '-', :g) ~ ($directive.value === True ?? '' !! '=' ~ $directive.value));
  }

  $!response.set-header('Cache-Control', @parts.join(', '));
  self
}

method expires-now(Bool :$no-store --> ::?CLASS) {
  $!response.set-header('Cache-Control', $no-store ?? 'no-store' !! 'no-cache');
  self
}

method !request-fresh(--> Bool) {
  return False without $!request;
  return False unless ($!request.method // 'GET').uc eq 'GET' | 'HEAD';

  my $if-none-match     = $!request.header('if-none-match');
  my $if-modified-since = $!request.header('if-modified-since');

  return False unless $if-none-match.defined || $if-modified-since.defined;

  my $result = True;
  $result = $result && self!etag-matches($!response.header('ETag'), $if-none-match) if $if-none-match.defined;
  $result = $result && self!not-modified-since($!response.header('Last-Modified'), $if-modified-since) if $if-modified-since.defined;
  $result
}

method !etag-matches($etag, Str:D $if-none-match --> Bool) {
  return False without $etag;

  my @client = $if-none-match.split(',').map(*.trim);
  return True if @client.first(* eq '*');

  my $normalized = $etag.subst(/^ 'W/'/, '');
  so @client.first({ .subst(/^ 'W/'/, '') eq $normalized })
}

method !not-modified-since($last-modified, Str:D $if-modified-since --> Bool) {
  return False without $last-modified;

  my $modified = parse-http-date($last-modified);
  my $since    = parse-http-date($if-modified-since);

  return False without $modified;
  return False without $since;

  $modified.Instant <= $since.Instant
}

method !flush-cookies {
  return without $!cookies;
  $!response.add-header('Set-Cookie', $_) for self.cookies.set-cookie-headers;
}

method !timed(Str:D $kind, &block) {
  my $event = $*KEAYL-LOG-EVENT;
  return block() without $event;

  $event.time($kind, &block)
}

method !render-traced(Str:D $kind, Str:D $name, &block) {
  self!timed('view', {
    MVC::Keayl::Notifications.instrument('render.keayl', %( :$kind, :$name ), &block)
  })
}

method render-template(Str:D $name, %locals, Str :$format --> Str) {
  die 'no view renderer configured' without $!view-renderer;
  self!render-traced('template', $name, { $!view-renderer.render-template($name, %locals, :$format, controller => self, variant => self.variant) })
}

method render-inline(Str:D $template, %locals --> Str) {
  die 'no view renderer configured' without $!view-renderer;
  self!render-traced('inline', 'inline', { $!view-renderer.render-inline($template, %locals, controller => self) })
}

method render-partial(Str:D $name, %locals --> Str) {
  die 'no view renderer configured' without $!view-renderer;
  self!render-traced('partial', $name, { $!view-renderer.render-partial($name, %locals, controller => self) })
}

method render-object($object, %locals --> Str) {
  die 'no view renderer configured' without $!view-renderer;
  self!render-traced('object', $object.^name, { $!view-renderer.render-object($object, %locals, controller => self) })
}

method render-collection(Str:D $name, @collection, $spacer, %locals --> Str) {
  die 'no view renderer configured' without $!view-renderer;
  $!view-renderer.render-collection($name, @collection, spacer => $spacer, controller => self, |%locals)
}

method render-layout(Str:D $layout, Str:D $content, %locals --> Str) {
  die 'no view renderer configured' without $!view-renderer;
  $!view-renderer.render-layout($layout, $content, %locals, controller => self)
}

method layout($name --> ::?CLASS) {
  config-cell(self, 'layout')[0] = $name;
  self
}

method !controller-layout {
  for self.^mro -> $class {
    my @cell = config-cell-local($class, 'layout');
    return @cell[0] if @cell;
  }

  Nil
}

method !default-layout-applies(--> Bool) {
  $!view-renderer.defined
    && $!view-renderer.^can('layout-exists')
    && ?$!view-renderer.layout-exists('application')
}

method !effective-layout(Bool $has-layout, $layout) {
  return $layout if $has-layout;

  my $declared = self!controller-layout;
  return $declared if $declared.defined;

  self!default-layout-applies ?? 'application' !! False
}

method !wrap(Str:D $content, $layout, %locals --> Str) {
  return $content unless $layout ~~ Str:D;
  self.render-layout($layout, $content, %locals)
}

method render(*@positional, *%options --> MVC::Keayl::Response) {
  die 'double render: a response was already rendered or redirected' if $!performed;
  $!performed = True;

  my $status      = %options<status>:delete;
  my $explicit-ct = %options<content-type>:delete;
  my $format          = (%options<format>:delete) // Str;
  my $has-layout      = %options<layout>:exists;
  my $layout          = %options<layout>:delete;
  my %explicit-locals = (%options<locals>:delete) // {};

  my $effective-layout = self!effective-layout($has-layout, $layout);

  my $*KEAYL-CONTENT = {};

  my $renderer-key = %renderers.keys.sort.first({ %options{$_}:exists });

  my $default-ct;
  my $body;

  if $renderer-key.defined {
    my $value = %options{$renderer-key}:delete;
    $body = %renderers{$renderer-key}(self, $value, %options);
  } elsif %options<json>:exists {
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
    my %locals = self!view-locals(%explicit-locals);
    $default-ct = 'text/html; charset=utf-8';
    $body = self!wrap(self.render-inline(~%options<inline>, %locals), $effective-layout, %locals);
  } elsif %options<partial>:exists {
    my %locals = self!view-locals(%explicit-locals);
    $default-ct = 'text/html; charset=utf-8';

    if %options<collection>:exists {
      $body = self.render-collection(~%options<partial>, (%options<collection>:delete).list, %options<spacer>:delete, %locals);
    } else {
      $body = self.render-partial(~%options<partial>, %locals);
    }
  } elsif @positional[0].defined && @positional[0] !~~ Str {
    my %locals = self!view-locals(%explicit-locals);
    $default-ct = 'text/html; charset=utf-8';
    $body = self.render-object(@positional[0], %locals);
  } else {
    my $name = @positional[0] // %options<template> // %options<action>;
    with $name {
      my %locals = self!view-locals(%explicit-locals);
      $default-ct = self!format-content-type($format);

      my $non-html = $format.defined && $format ne 'html';
      my $template-layout = ($non-html && !$has-layout) ?? False !! $effective-layout;

      $body = self!wrap(self.render-template(~$name, %locals, :$format), $template-layout, %locals);
    }
  }

  $!response.body($body) if $body.defined;

  my $content-type = $explicit-ct // $default-ct;
  $!response.content-type($content-type) if $content-type.defined;

  $!response.status = $status if $status.defined;

  $!response
}

method redirect-to($location?, Bool :$back, Str :$fallback = '/', :$status = 302 --> MVC::Keayl::Response) {
  die 'double render: a response was already rendered or redirected' if $!performed;
  $!performed = True;

  my $target = $back ?? (self.request.header('Referer') // $fallback) !! $location;

  $!response.status = status-code($status);
  $!response.location($target);

  $!response
}

method head($status, *%headers --> MVC::Keayl::Response) {
  die 'double render: a response was already rendered or redirected' if $!performed;
  $!performed = True;

  $!response.status = status-code($status);
  $!response.set-header(header-name(.key), ~.value) for %headers;

  $!response
}

method send-data($data, :$type, :$filename, Str :$disposition = 'attachment', :$status --> MVC::Keayl::Response) {
  die 'double render: a response was already rendered or redirected' if $!performed;
  $!performed = True;

  $!response.content-type($type // 'application/octet-stream');
  $!response.set-header('Content-Disposition', content-disposition($disposition, $filename));
  $!response.body($data ~~ Blob ?? $data !! ~$data);
  $!response.status = $status if $status.defined;

  $!response
}

method send-file($path, :$type, :$filename, Str :$disposition = 'attachment', :$status --> MVC::Keayl::Response) {
  die 'double render: a response was already rendered or redirected' if $!performed;
  $!performed = True;

  my $io    = $path.IO;
  my $bytes = $io.slurp(:bin);
  my $name  = $filename // $io.basename;

  $!response.content-type($type // mime-for($io.extension));
  $!response.set-header('Content-Disposition', content-disposition($disposition, $name));
  $!response.set-header('Accept-Ranges', 'bytes');

  with $!request {
    my ($start, $end) = parse-range($!request.header('Range'), $bytes.bytes);

    if $start.defined {
      $!response.status = 206;
      $!response.set-header('Content-Range', "bytes $start-$end/{$bytes.bytes}");
      $!response.body($bytes.subbuf($start, $end - $start + 1));
      return $!response;
    }
  }

  $!response.body($bytes);
  $!response.status = $status if $status.defined;

  $!response
}

method live(&block --> MVC::Keayl::Response) {
  die 'double render: a response was already rendered or redirected' if $!performed;
  $!performed = True;

  my $stream = $!response.live-stream;

  $!response.content-type('text/html; charset=utf-8') unless $!response.has-header('content-type');

  $!response.live-promise = start {
    LEAVE $stream.close;
    CATCH { default {} }
    block(self, $stream);
  }

  $!response
}

method sse(&block, *%defaults --> MVC::Keayl::Response) {
  $!response.content-type('text/event-stream') unless $!response.has-header('content-type');
  $!response.set-header('Cache-Control', 'no-cache') unless $!response.has-header('cache-control');

  self.live(-> $controller, $stream {
    block($controller, MVC::Keayl::Live::SSE.new(:$stream, :%defaults));
  })
}

method !format-content-type($format --> Str) {
  return 'text/html; charset=utf-8' without $format;
  return 'text/html; charset=utf-8' if $format eq 'html';

  mime-type($format) // 'text/html; charset=utf-8'
}

method !implicit-format($action --> Str) {
  my $format = self.request-format;

  return Str without $format;
  return Str if $format eq $!view-renderer.default-format;
  return Str unless $!view-renderer.^can('has-template')
    && $!view-renderer.has-template($action, $format, variant => self.variant, controller => self);

  $format
}

method implicit-render(Str:D $action, $result --> Nil) {
  return if $!performed;

  if $!view-renderer.defined {
    self.render($action, format => self!implicit-format($action));
  } elsif $result ~~ Str:D && !$!response.body.chars {
    $!response.body($result);
  }
}
