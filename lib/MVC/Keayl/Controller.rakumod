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

unit class MVC::Keayl::Controller;

has MVC::Keayl::Request  $.request;
has MVC::Keayl::Response $.response = MVC::Keayl::Response.new;
has      $.params = MVC::Keayl::Parameters.new({});
has      $.view-renderer;
has Str  $.secret = '';
has      $.session-store = MVC::Keayl::Session::CookieStore.new;
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
  'internal-server-error' => 500;

sub status-code($status --> Int) {
  return $status if $status ~~ Int;
  %STATUS-CODES{$status} // die "unknown status '$status'"
}

sub header-name(Str:D $key --> Str) {
  $key.split(/<[-_]>/).map(*.tc).join('-')
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
my %helper-methods{Mu};
my %controller-layouts{Mu};
my %forgery-strategy{Mu};
my %param-filters{Mu};

method helper-method(*@names --> ::?CLASS) {
  (%helper-methods{self} //= []).append(@names.map(*.Str));
  self
}

method assign(Str:D $name, $value --> ::?CLASS) {
  %!assigns{$name} = $value;
  self
}

method assigns(--> Hash) {
  %!assigns
}

method !helper-method-names(--> List) {
  my @names;
  @names.append(|(%helper-methods{$_} // [])) for self.^mro.reverse;
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

method !collect(%registry --> List) {
  my @result;
  @result.append(|(%registry{$_} // [])) for self.^mro.reverse;
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

method !active-callbacks(%registry, %skip-registry, $action --> List) {
  my @skips = self!collect(%skip-registry);

  self!collect(%registry).grep({
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
  for self!active-callbacks(%before-actions, %skip-before, $action) -> $callback {
    self!invoke-callback($callback);
    return if $!performed;
  }

  my $core = sub {
    return if $!performed;
    my $result = self."$action"();
    self.implicit-render($action, $result) unless $!performed;
  };

  my $chain = $core;
  for self!active-callbacks(%around-actions, %skip-around, $action).reverse -> $callback {
    my $next = $chain;
    $chain = sub { self!invoke-around($callback, $next) };
  }
  $chain();

  for self!active-callbacks(%after-actions, %skip-after, $action).reverse -> $callback {
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
  state $reserved = MVC::Keayl::Controller.^methods(:all).map(*.name).Set;
  self.^can($name).so && !$reserved{$name}
}

method !collect-rescues(--> List) {
  my @entries;
  @entries.push($_) for @DEFAULT-RESCUES;

  for self.^mro.reverse -> $class {
    @entries.push($_) for (%rescues{$class} // []).list;
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

  {
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
  %forgery-strategy{self} = $with;
  self.before-action('verify-authenticity-token');
  self
}

method skip-forgery-protection(:$only, :$except --> ::?CLASS) {
  self.skip-before-action('verify-authenticity-token', :$only, :$except);
  self
}

method !forgery-strategy(--> Str) {
  for self.^mro -> $class {
    return %forgery-strategy{$class} if %forgery-strategy{$class}:exists;
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

method filter-parameters(*@names --> ::?CLASS) {
  (%param-filters{self} //= []).append(@names);
  self
}

method !configured-param-filters(--> List) {
  my @filters;
  @filters.append(|(%param-filters{$_} // [])) for self.^mro.reverse;
  @filters.List
}

method filtered-params(--> Hash) {
  MVC::Keayl::ParameterFilter.new(also => self!configured-param-filters).filter(self.params.Hash)
}

method !flush-cookies {
  return without $!cookies;
  $!response.add-header('Set-Cookie', $_) for self.cookies.set-cookie-headers;
}

method render-template(Str:D $name, %locals --> Str) {
  die 'no view renderer configured' without $!view-renderer;
  $!view-renderer.render-template($name, %locals, controller => self)
}

method render-inline(Str:D $template, %locals --> Str) {
  die 'no view renderer configured' without $!view-renderer;
  $!view-renderer.render-inline($template, %locals, controller => self)
}

method render-partial(Str:D $name, %locals --> Str) {
  die 'no view renderer configured' without $!view-renderer;
  $!view-renderer.render-partial($name, %locals, controller => self)
}

method render-object($object, %locals --> Str) {
  die 'no view renderer configured' without $!view-renderer;
  $!view-renderer.render-object($object, %locals, controller => self)
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
  %controller-layouts{self} = $name;
  self
}

method !controller-layout {
  for self.^mro -> $class {
    return %controller-layouts{$class} if %controller-layouts{$class}:exists;
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
  my $has-layout      = %options<layout>:exists;
  my $layout          = %options<layout>:delete;
  my %explicit-locals = (%options<locals>:delete) // {};

  my $effective-layout = self!effective-layout($has-layout, $layout);

  my $*KEAYL-CONTENT = {};

  my $default-ct;
  my $body;

  if %options<json>:exists {
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
      $default-ct = 'text/html; charset=utf-8';
      $body = self!wrap(self.render-template(~$name, %locals), $effective-layout, %locals);
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

method implicit-render(Str:D $action, $result --> Nil) {
  return if $!performed;

  if $!view-renderer.defined {
    self.render($action);
  } elsif $result ~~ Str:D && !$!response.body.chars {
    $!response.body($result);
  }
}
