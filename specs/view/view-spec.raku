use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::View;
use MVC::Keayl::View::Handler;
use MVC::Keayl::Controller;
use ControllerFixtures;

class CountingHandler does MVC::Keayl::View::Handler {
  has $.compiles = 0;
  method compile(Str:D $source) { $!compiles++; $source }
  method render($compiled, %locals --> Str) { 'rendered:' ~ $compiled.trim }
}

class BlogPostsController is MVC::Keayl::Controller { }

class GreetingsController is MVC::Keayl::Controller {
  method show {
    self.assign('name', 'Ada');
    self.render('show');
  }
}

sub view(*%opts) {
  MVC::Keayl::View.new(:paths(['specs/lib/views']), |%opts)
}

describe 'MVC::Keayl::View resolution', {
  it 'finds a template by name, format, and handler extension', {
    expect(view.resolve('greetings/show', 'html').basename).to.be('show.html.haml');
  }

  it 'returns an undefined path when nothing matches', {
    expect(view.resolve('greetings/missing', 'html').defined).to.be-falsy;
  }

  it 'prefers a variant template when the variant is set', {
    expect(view.resolve('greetings/show', 'html', variant => 'phone').basename).to.be('show.html+phone.haml');
  }

  it 'falls back to the plain template when no variant template exists', {
    expect(view.resolve('greetings/show', 'html', variant => 'tablet').basename).to.be('show.html.haml');
  }
}

describe 'MVC::Keayl::View rendering', {
  it 'renders a HAML template with locals', {
    expect(view.render-template('greetings/show', { name => 'Ada' }).contains('Hello, Ada')).to.be-truthy;
  }

  it 'resolves a different template for a different format', {
    expect(view.render-template('greetings/show', { name => 'Ada' }, :format('txt')).contains('Plain greeting')).to.be-truthy;
  }

  it 'renders a variant template when the variant is set', {
    expect(view.render-template('greetings/show', { name => 'Ada' }, :variant('phone')).contains('Hi Ada (phone)')).to.be-truthy;
  }

  it 'renders an inline template', {
    expect(view.render-inline('%em Inline', {}).contains('<em>Inline</em>')).to.be-truthy;
  }

  it 'injects content into a layout', {
    expect(view.render-layout('main', '<h1>body</h1>', {}).contains('<h1>body</h1>')).to.be-truthy;
  }
}

describe 'MVC::Keayl::View handler registry', {
  it 'renders templates with a registered custom handler', {
    my $view = view;
    $view.register-handler('count', CountingHandler.new);
    expect($view.render-template('cached/widget', {})).to.be('rendered:WIDGET');
  }
}

describe 'MVC::Keayl::View caching', {
  it 'compiles a cached template once across renders', {
    my $handler = CountingHandler.new;
    my $view = view;
    $view.register-handler('count', $handler);
    $view.render-template('cached/widget', {});
    $view.render-template('cached/widget', {});
    expect($handler.compiles).to.be(1);
  }

  it 'compiles on each render with caching off', {
    my $handler = CountingHandler.new;
    my $view = view(:cache(False));
    $view.register-handler('count', $handler);
    $view.render-template('cached/widget', {});
    $view.render-template('cached/widget', {});
    expect($handler.compiles).to.be(2);
  }
}

describe 'MVC::Keayl::View missing templates', {
  it 'raises when a template is missing', {
    expect({ view.render-template('greetings/missing', {}) }).to.throw;
  }
}

describe 'MVC::Keayl::Controller view path', {
  it 'derives a controller path from the class name', {
    expect(GreetingsController.new.controller-path).to.be('greetings');
  }

  it 'underscores a multi-word controller path', {
    expect(BlogPostsController.new.controller-path).to.be('blog_posts');
  }

  it 'renders a template resolved from the controller path', {
    my $controller = GreetingsController.new(:view-renderer(view));
    expect($controller.dispatch('show').body.contains('Hello, Ada')).to.be-truthy;
  }
}
