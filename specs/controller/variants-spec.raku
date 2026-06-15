use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Request;
use MVC::Keayl::Controller;
use ControllerFixtures;

sub html-request(:$variant) {
  my $request = MVC::Keayl::Request.new(:method<GET>, :path('/show'), :headers({ accept => 'text/html' }));
  $request.set-variant($variant) if $variant.defined;
  $request
}

describe 'MVC::Keayl::Controller respond-to variant branching', {
  it 'dispatches to the matching variant block', {
    expect(VariantController.new(request => html-request(variant => 'phone')).dispatch('show').body).to.be('phone view');
  }

  it 'falls back to the any block for an unmatched variant', {
    expect(VariantController.new(request => html-request(variant => 'tablet')).dispatch('show').body).to.be('default view');
  }

  it 'falls back to the any block when no variant is set', {
    expect(VariantController.new(request => html-request).dispatch('show').body).to.be('default view');
  }
}

describe 'MVC::Keayl::Controller variant-aware template lookup', {
  it 'passes the request variant through to the renderer', {
    my $controller = VariantTemplateController.new(
      request       => html-request(variant => 'phone'),
      view-renderer => StubRenderer.new,
    );
    expect($controller.dispatch('show').body).to.be('template:show+phone');
  }

  it 'renders without a variant suffix when none is set', {
    my $controller = VariantTemplateController.new(
      request       => html-request,
      view-renderer => StubRenderer.new,
    );
    expect($controller.dispatch('show').body).to.be('template:show');
  }
}
