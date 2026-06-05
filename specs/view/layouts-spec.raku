use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::View;
use MVC::Keayl::Controller;
use ControllerFixtures;

class LayoutController is MVC::Keayl::Controller {
  method default-layout { self.assign('name', 'Ada'); self.render('greetings/show') }
  method no-layout      { self.assign('name', 'Ada'); self.render('greetings/show', :layout(False)) }
  method action-layout  { self.assign('name', 'Ada'); self.render('greetings/show', :layout('special')) }
  method yielded        { self.render('greetings/with_content', :layout('yielding')) }
}

class DeclaredLayoutController is MVC::Keayl::Controller {
  method show { self.assign('name', 'Ada'); self.render('greetings/show') }
}
DeclaredLayoutController.layout('special');

sub body($controller, $action) {
  $controller.new(:view-renderer(MVC::Keayl::View.new(:paths(['specs/lib/views'])))).dispatch($action).body
}

describe 'MVC::Keayl::Controller default layout', {
  it 'wraps a template in the application layout', {
    expect(body(LayoutController, 'default-layout').contains(Q{class='app'})).to.be-truthy;
  }

  it 'still renders the action template inside the layout', {
    expect(body(LayoutController, 'default-layout').contains('Hello, Ada')).to.be-truthy;
  }
}

describe 'MVC::Keayl::Controller layout false', {
  it 'renders without the default layout', {
    expect(body(LayoutController, 'no-layout').contains(Q{class='app'})).to.be-falsy;
  }

  it 'still renders the template', {
    expect(body(LayoutController, 'no-layout').contains('Hello, Ada')).to.be-truthy;
  }
}

describe 'MVC::Keayl::Controller layout selection', {
  it 'overrides the default with a per-action layout', {
    expect(body(LayoutController, 'action-layout').contains(Q{class='special'})).to.be-truthy;
  }

  it 'wraps actions in a controller-declared layout', {
    expect(body(DeclaredLayoutController, 'show').contains(Q{class='special'})).to.be-truthy;
  }
}

describe 'MVC::Keayl::Controller content for and yield', {
  it 'yields a named content-for block into the layout', {
    expect(body(LayoutController, 'yielded').contains('Page Title')).to.be-truthy;
  }

  it 'yields the main content into the layout', {
    expect(body(LayoutController, 'yielded').contains('Body content')).to.be-truthy;
  }
}
