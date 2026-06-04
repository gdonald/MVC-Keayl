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

class DownloadController is MVC::Keayl::Controller is export {
  method data-csv    { self.send-data("a,b\n1,2", type => 'text/csv', filename => 'report.csv') }
  method data-inline { self.send-data('hi', disposition => 'inline') }
  method data-binary { self.send-data(Blob.new(0, 1, 2, 255), filename => 'x.bin') }

  method file        { self.send-file('specs/lib/fixtures/sample.txt') }
  method file-typed  { self.send-file('specs/lib/fixtures/sample.txt', type => 'text/plain', filename => 'down.txt', disposition => 'inline') }
}


