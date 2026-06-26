use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Request;
use MVC::Keayl::Controller;
use MVC::Keayl::Parameters;
use MVC::Keayl::Params;

class X::Boom is Exception { method message(--> Str) { 'boom' } }

class DslTraitController is MVC::Keayl::Controller
  is layout('admin')
  is filter-parameters('secret')
  is add-flash-types('notice')
  is protect-from-forgery
{
  method handle-boom($error) is rescue-from(X::Boom) { self.render(plain => 'rescued', status => 503) }
  method current-user is helper-method { 'gd' }

  method explode { X::Boom.new.throw }
}

class WrapTraitController is MVC::Keayl::Controller is wrap-parameters('person', include => <name email>) {
  method create { self.render(plain => self.params<person><name> // 'none') }
}

class ThrottleTraitController is MVC::Keayl::Controller is rate-limit(to => 1, within => 60, name => 'dsl-trait-spec', by => -> $controller { 'fixed' }) {
  method ping { self.render(plain => 'ok') }
}

class BasicTraitController is MVC::Keayl::Controller is http-basic-authenticate-with(name => 'admin', password => 'secret') {
  method dash { self.render(plain => 'dash') }
}

sub get(Str:D $path) {
  MVC::Keayl::Request.new(:method<GET>, :$path)
}

describe 'class-level DSL declared with the is trait', {
  context 'is rescue-from on the handler method', {
    let(:response, { DslTraitController.new(request => get('/explode')).dispatch('explode') });

    it 'routes the exception to the handler', {
      expect(response.status).to.be(503);
    }

    it 'runs the handler body', {
      expect(response.body).to.be('rescued');
    }
  }

  context 'is filter-parameters on the class', {
    let(:controller, {
      DslTraitController.new(params => MVC::Keayl::Parameters.new({ secret => 'hunter2', name => 'gd' }))
    });

    it 'redacts the configured key', {
      expect(controller.filtered-params<secret>).not.to.be('hunter2');
    }

    it 'passes an unfiltered parameter through', {
      expect(controller.filtered-params<name>).to.be('gd');
    }
  }

  context 'is helper-method on the method', {
    it 'leaves the method callable on the controller', {
      expect(DslTraitController.new.current-user).to.be('gd');
    }
  }

  context 'is protect-from-forgery on the class', {
    it 'rejects an unsafe request without a token', {
      my $request = MVC::Keayl::Request.new(:method<POST>, :path('/explode'), :headers({}));
      expect(DslTraitController.new(:$request).dispatch('explode').status).to.be(422);
    }
  }

  context 'is wrap-parameters with a positional key and named options', {
    it 'nests the json body and keeps the included attributes', {
      my $request = MVC::Keayl::Request.new(:method<POST>, :headers({ 'Content-Type' => 'application/json' }), :body('{"name":"Ada","secret":"x"}'));
      expect(WrapTraitController.new(:$request, :params(build-params({}, $request))).dispatch('create').body).to.be('Ada');
    }
  }

  context 'is rate-limit with named options', {
    it 'allows a request under the limit, then blocks the next', {
      aggregate-failures {
        expect(ThrottleTraitController.new(request => get('/ping')).dispatch('ping').status).to.be(200);
        expect(ThrottleTraitController.new(request => get('/ping')).dispatch('ping').status).to.be(429);
      }
    }
  }

  context 'is http-basic-authenticate-with on the class', {
    it 'challenges a request with no credentials', {
      expect(BasicTraitController.new(request => get('/dash')).dispatch('dash').status).to.be(401);
    }
  }
}
