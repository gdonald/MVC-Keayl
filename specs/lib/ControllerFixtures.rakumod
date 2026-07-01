use v6.d;
use MVC::Keayl::Controller;
use MVC::Keayl::Errors;
use MVC::Keayl::Live;

unit module ControllerFixtures;

class X::Demo::Base is Exception { method message(--> Str) { 'base' } }
class X::Demo::Child is X::Demo::Base { method message(--> Str) { 'child' } }
class X::Demo::Unhandled is Exception { method message(--> Str) { 'unhandled' } }

class RescueController is MVC::Keayl::Controller is export {
  method missing-record { X::MVC::Keayl::NotFound.new.throw }
  method missing-param  { self.params.require('user') }
  method base-error     { X::Demo::Base.new.throw }
  method child-error    { X::Demo::Child.new.throw }
  method unhandled      { X::Demo::Unhandled.new.throw }

  method on-base($error)  { self.render(plain => 'base:' ~ $error.message, status => 500) }
  method on-child($error) { self.render(plain => 'child:' ~ $error.message, status => 422) }
}
RescueController.rescue-from(X::Demo::Base, 'on-base');
RescueController.rescue-from(X::Demo::Child, 'on-child');

class OverrideRescueController is RescueController is export {
  method on-missing($error) { self.head(410) }
}
OverrideRescueController.rescue-from(X::MVC::Keayl::NotFound, 'on-missing');

class GreetController is MVC::Keayl::Controller is export {
  method index {
    'all greetings'
  }

  method show {
    'greeting ' ~ self.params<id>
  }

  method create {
    self.response.status = 201;
    self.response.body('created');
  }

  method ping {
    self.response.set-header('X-Ping', 'pong');
    'pong'
  }

  method profile {
    'name ' ~ self.params<user><name>
  }
}

class StubRenderer is export {
  has Str $.default-format = 'html';
  has @.formats;

  method has-template(Str $name, Str $format, :$variant, :$controller) {
    @!formats.first($format).defined
  }

  method render-template(Str $name, %locals, :$controller, :$variant, :$format) {
    my $locals = %locals ?? ' ' ~ %locals.sort(*.key).map({ .key ~ '=' ~ .value }).join(',') !! '';
    'template:' ~ $name ~ $locals
      ~ ($variant.defined ?? '+' ~ $variant !! '')
      ~ ($format.defined ?? '.' ~ $format !! '')
  }

  method render-inline(Str $template, %locals, :$controller) {
    'inline:' ~ $template
  }

  method render-layout(Str $layout, Str $content, %locals, :$controller) {
    'layout(' ~ $layout ~ '){' ~ $content ~ '}'
  }

  method layout-exists($name) {
    False
  }

  method render-partial(Str $name, %locals, :$controller) {
    my $locals = %locals ?? ' ' ~ %locals.sort(*.key).map({ .key ~ '=' ~ .value }).join(',') !! '';
    'partial:' ~ $name ~ $locals
  }

  method render-object($object, %locals, :$controller) {
    'object:' ~ $object.^name
  }

  method render-collection(Str $name, @collection, :$spacer, :$controller, *%locals) {
    'collection:' ~ $name ~ '[' ~ @collection.elems ~ ']' ~ ($spacer.defined ?? ' spacer=' ~ $spacer !! '')
  }
}

class RenderController is MVC::Keayl::Controller is export {
  method as-json    { self.render(:json({ ok => True })) }
  method as-plain   { self.render(:plain('hello')) }
  method as-html    { self.render(:html('<b>hi</b>')) }
  method as-body    { self.render(:body('id,name'), :content-type('text/csv')) }
  method made       { self.render(:plain('created'), :status(201)) }
  method only-status { self.render(:status(204)) }

  method by-name    { self.render('show') }
  method by-action  { self.render(:action('edit')) }
  method with-locals { self.render('show', :locals({ id => 7 })) }
  method inline-render { self.render(:inline('<p>x</p>')) }
  method layered    { self.render('show', :layout('admin')) }
  method no-layout  { self.render('show', :layout(False)) }
  method implicit-show { 'ignored return value' }

  method double {
    self.render(:plain('a'));
    self.render(:plain('b'));
  }
}

class ImplicitController is MVC::Keayl::Controller is export {
  method index { }
  method as-json { self.render('index', :format<json>) }
}

class FlowController is MVC::Keayl::Controller is export {
  method to-path      { self.redirect-to('/dashboard') }
  method to-url       { self.redirect-to('https://example.com') }
  method permanent    { self.redirect-to('/new', status => 301) }
  method see-other    { self.redirect-to('/x', status => 'see-other') }
  method go-back      { self.redirect-to(:back) }
  method back-default { self.redirect-to(:back, fallback => '/home') }

  method gone         { self.head(404) }
  method made         { self.head('created', location => '/users/5') }
  method empty        { self.head(204) }

  method redirect-then-render {
    self.redirect-to('/x');
    self.render(plain => 'unreachable');
  }
}

class AppController is MVC::Keayl::Controller is export {
  method site-name { 'Keayl' }
}
AppController.helper-method('site-name');

class HelperController is AppController is export {
  method current-user { 'Ada' }

  method show {
    self.assign('title', 'Hello');
    self.render('page');
  }

  method override-local {
    self.assign('title', 'from-assign');
    self.render('page', locals => { title => 'from-locals' });
  }
}
HelperController.helper-method('current-user');

class StrongController is MVC::Keayl::Controller is export {
  method create {
    my $user = self.params.require('user').permit('name', 'email');
    self.render(plain => $user<name> ~ ':' ~ ($user<admin> // 'no-admin'));
  }
}

class CallbackController is MVC::Keayl::Controller is export {
  has @.trail;

  method trace(Str $label) { @!trail.push($label) }

  method one-before     { self.trace('before-1') }
  method two-before     { self.trace('before-2') }
  method one-after      { self.trace('after-1') }
  method timer($next)   { self.trace('around-pre'); $next(); self.trace('around-post') }

  method show { self.trace('action'); 'ok' }
}
CallbackController.before-action('one-before');
CallbackController.before-action('two-before');
CallbackController.around-action('timer');
CallbackController.after-action('one-after');

class GuardController is MVC::Keayl::Controller is export {
  has @.trail;

  method trace(Str $label) { @!trail.push($label) }
  method block { self.trace('guard'); self.render(plain => 'denied') }
  method show  { self.trace('action'); 'shown' }
}
GuardController.before-action('block');

class ScopedController is MVC::Keayl::Controller is export {
  has @.trail;

  method trace(Str $label) { @!trail.push($label) }
  method admin-only { self.trace('admin') }
  method index { self.trace('index'); 'i' }
  method edit  { self.trace('edit'); 'e' }
}
ScopedController.before-action('admin-only', only => <edit>);

class ConditionalController is MVC::Keayl::Controller is export {
  has @.trail;
  has Bool $.logged-in = False;

  method trace(Str $label) { @!trail.push($label) }
  method note-auth { self.trace('auth') }
  method is-guest  { !$!logged-in }
  method show { self.trace('action'); 's' }
}
ConditionalController.before-action('note-auth', if => 'is-guest');

class BaseAuthController is MVC::Keayl::Controller is export {
  has @.trail;

  method trace(Str $label) { @!trail.push($label) }
  method authenticate { self.trace('auth') }
  method show { self.trace('action'); 's' }
}
BaseAuthController.before-action('authenticate');

class PublicController is BaseAuthController is export {
}
PublicController.skip-before-action('authenticate');

class DownloadController is MVC::Keayl::Controller is export {
  method data-csv    { self.send-data("a,b\n1,2", type => 'text/csv', filename => 'report.csv') }
  method data-inline { self.send-data('hi', disposition => 'inline') }
  method data-binary { self.send-data(Blob.new(0, 1, 2, 255), filename => 'x.bin') }

  method file        { self.send-file('specs/lib/fixtures/sample.txt') }
  method file-typed  { self.send-file('specs/lib/fixtures/sample.txt', type => 'text/plain', filename => 'down.txt', disposition => 'inline') }
}

class WidgetsController is MVC::Keayl::Controller is export {
  method create { self.render(plain => (self.params<widget><name> // 'none') ~ ':' ~ (self.params<widget><color> // 'none')) }
}
WidgetsController.wrap-parameters;

class GadgetsController is MVC::Keayl::Controller is export {
  method create { self.render(plain => (self.params<gadget><name> // 'none') ~ ':' ~ (self.params<gadget><secret> // 'none')) }
}
GadgetsController.wrap-parameters(include => <name>);

class TrinketsController is MVC::Keayl::Controller is export {
  method create { self.render(plain => (self.params<trinket><name> // 'none') ~ ':' ~ (self.params<trinket><secret> // 'none')) }
}
TrinketsController.wrap-parameters(exclude => <secret>);

class ParcelsController is MVC::Keayl::Controller is export {
  method create { self.render(plain => (self.params<box><name> // 'none')) }
}
ParcelsController.wrap-parameters('box');

class ExpectController is MVC::Keayl::Controller is export {
  method create {
    my $user = self.params.expect(user => <name email>);
    self.render(plain => $user<name> ~ ':' ~ ($user<admin> // 'no-admin'));
  }
}

class ReportsController is MVC::Keayl::Controller is export {
  method export { self.render(csv => [[1, 2], [3, 4]]) }
}

MVC::Keayl::Controller.add-renderer('csv', -> $controller, $value, %options {
  $controller.response.content-type('text/csv');
  $value.map(*.join(',')).join("\n")
});

class NoticeController is MVC::Keayl::Controller is export {
  method create {
    self.flash<success> = 'saved';
    self.render(plain => self.flash.success);
  }
}
MVC::Keayl::Controller.add-flash-types('success', 'alert');

class VariantController is MVC::Keayl::Controller is export {
  method show {
    self.respond-to([
      html => {
        phone => { self.render(plain => 'phone view') },
        any   => { self.render(plain => 'default view') },
      },
    ])
  }
}

class VariantTemplateController is MVC::Keayl::Controller is export {
  method show { self.render('show') }
}

class StreamController is MVC::Keayl::Controller is export {
  has @.torn-down;

  method numbers {
    self.live(-> $controller, $stream {
      $stream.write('one');
      $stream.write('two');
      $stream.write('three');
    });
  }

  method events {
    self.sse(-> $controller, $sse {
      $sse.write('hello', event => 'greeting');
      $sse.write('world');
    });
  }

  method retrying {
    self.sse(-> $controller, $sse {
      $sse.comment('keep-alive');
      $sse.write('tick');
    }, retry => 5000);
  }

  method teardown {
    self.live(-> $controller, $stream {
      CATCH { when X::MVC::Keayl::Live::ClientDisconnected { $controller.torn-down.push('disconnected') } }

      $stream.write('first');
      $stream.disconnect;
      $stream.write('second');
    });
  }
}

class X::CallbackBaseBoom is Exception is export { method message(--> Str) { 'callback base boom' } }

# A base controller carrying callback, around, rescue-from, and helper-method
# traits. Living in this separately compiled fixture module, it exercises the
# precompilation path: the trait declarations must survive into a subclass
# defined elsewhere.
class CallbackBaseController is MVC::Keayl::Controller is export {
  has @.trail;

  method base-before is before-action { @!trail.push('base-before') }
  method base-around($next) is around-action { @!trail.push('base-around-in'); $next(); @!trail.push('base-around-out') }
  method base-after is after-action { @!trail.push('base-after') }
  method base-label is helper-method { 'from-base' }

  method base-rescue($error) is rescue-from(X::CallbackBaseBoom) { self.render(plain => 'rescued by base', status => 503) }
}


