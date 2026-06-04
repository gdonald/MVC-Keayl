use v6.d;
use MVC::Keayl::Controller;

unit module ControllerFixtures;

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
  method render-template(Str $name, %locals, :$controller) {
    my $locals = %locals ?? ' ' ~ %locals.sort(*.key).map({ .key ~ '=' ~ .value }).join(',') !! '';
    'template:' ~ $name ~ $locals
  }

  method render-inline(Str $template, %locals, :$controller) {
    'inline:' ~ $template
  }

  method render-layout(Str $layout, Str $content, %locals, :$controller) {
    'layout(' ~ $layout ~ '){' ~ $content ~ '}'
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

