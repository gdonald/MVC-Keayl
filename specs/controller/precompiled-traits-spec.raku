use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Request;
use MVC::Keayl::Controller;
use MVC::Keayl::Parameters;
use MVC::Keayl::Params;
use MVC::Keayl::View;
use ControllerFixtures;

sub layout-body($controller) {
  $controller.new(:view-renderer(MVC::Keayl::View.new(:paths(['specs/lib/views'])))).dispatch('show').body
}

describe 'class-level configuration traits on a precompiled controller', {
  context 'is layout', {
    it 'selects the declared layout', {
      expect(layout-body(PrecompLayoutController)).to.match(/"class='special'"/);
    }

    it 'inherits the layout declared on a precompiled base controller', {
      expect(layout-body(PrecompLayoutChildController)).to.match(/"class='special'"/);
    }

    it 'lets a subclass override the layout declared on a precompiled base controller', {
      expect(layout-body(PrecompLayoutOverrideController)).to.match(/'<body'/);
    }
  }

  context 'is filter-parameters', {
    let(:controller, {
      PrecompFilterController.new(params => MVC::Keayl::Parameters.new({ secret => 'hunter2', name => 'gd' }))
    });

    it 'redacts the configured key', {
      expect(controller.filtered-params<secret>).not.to.be('hunter2');
    }

    it 'passes an unfiltered parameter through', {
      expect(controller.filtered-params<name>).to.be('gd');
    }
  }

  context 'is filter-parameters accumulating across an inheritance chain', {
    let(:controller, {
      PrecompFilterChildController.new(params => MVC::Keayl::Parameters.new({ secret => 'hunter2', token => 'abc123', name => 'gd' }))
    });

    it 'redacts the key filtered by the precompiled base controller', {
      expect(controller.filtered-params<secret>).not.to.be('hunter2');
    }

    it 'redacts its own filtered key on top of the base controller', {
      expect(controller.filtered-params<token>).not.to.be('abc123');
    }
  }

  context 'is protect-from-forgery with a non-default strategy', {
    it 'survives precompilation and skips the exception path', {
      my $request = MVC::Keayl::Request.new(:method<POST>, :path('/create'), :headers({}));
      expect(PrecompForgeryController.new(:$request).dispatch('create').status).to.be(200);
    }
  }

  context 'is wrap-parameters', {
    it 'nests the body under the declared key', {
      my $request = MVC::Keayl::Request.new(:method<POST>, :headers({ 'Content-Type' => 'application/json' }), :body('{"name":"Ada","color":"blue"}'));
      expect(PrecompWrapController.new(:$request, :params(build-params({}, $request))).dispatch('create').body).to.be('Ada');
    }
  }

  context 'class-level helper-method declaration', {
    it 'exposes the helper to the template', {
      my $body = PrecompHelperController.new(:view-renderer(StubRenderer.new)).dispatch('show').body;
      expect($body).to.match(/'site-name=Keayl'/);
    }
  }
}
