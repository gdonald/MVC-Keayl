use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::View;
use MVC::Keayl::Controller;
use ControllerFixtures;

class Post {
  has $.title;
  method to-partial-path { 'posts/post' }
}

class PartialController is MVC::Keayl::Controller {
  method just-partial { self.render(:partial('form'), :locals({ id => 1 })) }
  method object-render { self.render(Post.new(title => 'Hi')) }
  method collection-render { self.render(:partial('post'), :collection([1, 2, 3])) }
  method spaced-collection { self.render(:partial('post'), :collection([1, 2]), :spacer('divider')) }
}

sub view { MVC::Keayl::View.new(:paths(['specs/lib/views'])) }

sub stubbed($action) {
  PartialController.new(:view-renderer(StubRenderer.new)).dispatch($action).body
}

describe 'MVC::Keayl::View named partials', {
  it 'resolves a leading-underscore file and renders it with locals', {
    expect(view.render-partial('greetings/item', { label => 'Hi' }).trim).to.be('<li>Hi</li>');
  }

  it 'resolves a partial with a path segment outside the controller path', {
    expect(view.render-partial('shared/menu', {}).contains('Menu')).to.be-truthy;
  }

  it 'embeds a partial in a template through the partial helper', {
    expect(view.render-template('greetings/embeds', {}).contains('<li>Embedded</li>')).to.be-truthy;
  }
}

describe 'MVC::Keayl::View object partials', {
  it 'derives the partial path and local from the object', {
    expect(view.render-object(Post.new(title => 'Hello')).contains('<h2>Hello</h2>')).to.be-truthy;
  }
}

describe 'MVC::Keayl::View collection partials', {
  it 'exposes a zero-based counter for the first item', {
    expect(view.render-collection('greetings/line', ['a', 'b']).contains('a-0')).to.be-truthy;
  }

  it 'increments the counter across the collection', {
    expect(view.render-collection('greetings/line', ['a', 'b']).contains('b-1')).to.be-truthy;
  }

  it 'renders a spacer template between items', {
    expect(view.render-collection('greetings/line', ['a', 'b'], spacer => 'greetings/divider').contains('<hr')).to.be-truthy;
  }
}

describe 'MVC::Keayl::Controller partial responses', {
  it 'renders a partial as the response with locals', {
    expect(stubbed('just-partial')).to.be('partial:form id=1');
  }

  it 'renders a bare object as an object partial', {
    expect(stubbed('object-render').starts-with('object:')).to.be-truthy;
  }

  it 'renders a partial over a collection', {
    expect(stubbed('collection-render')).to.be('collection:post[3]');
  }

  it 'passes a spacer template to a collection render', {
    expect(stubbed('spaced-collection')).to.be('collection:post[2] spacer=divider');
  }
}
