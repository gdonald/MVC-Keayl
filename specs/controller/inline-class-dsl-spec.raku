use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Request;
use MVC::Keayl::Controller;
use MVC::Keayl::Parameters;

class X::Boom is Exception { method message(--> Str) { 'boom' } }

class InlineDslController is MVC::Keayl::Controller {
  $?CLASS.rescue-from(X::Boom, 'handle-boom');
  $?CLASS.helper-method('current-user');
  $?CLASS.filter-parameters('secret');
  $?CLASS.add-flash-types('notice');
  $?CLASS.wrap-parameters('widget');
  $?CLASS.layout('admin');
  $?CLASS.protect-from-forgery;
  $?CLASS.rate-limit(to => 100, within => 60);

  method handle-boom($error) { self.render(plain => 'rescued', status => 503) }
  method current-user { 'gd' }
  method explode { X::Boom.new.throw }
}

describe 'class-level DSL declared inside the class body with the class handle', {
  context 'rescue-from', {
    let(:response, {
      InlineDslController.new(request => MVC::Keayl::Request.new(:method<GET>, :path('/explode'))).dispatch('explode')
    });

    it 'handles the exception with the registered method', {
      expect(response.status).to.be(503);
    }

    it 'runs the rescue handler body', {
      expect(response.body).to.be('rescued');
    }
  }

  context 'filter-parameters', {
    let(:controller, {
      InlineDslController.new(params => MVC::Keayl::Parameters.new({ secret => 'hunter2', name => 'gd' }))
    });

    it 'redacts the configured key', {
      expect(controller.filtered-params<secret>).not.to.be('hunter2');
    }

    it 'passes an unfiltered parameter through', {
      expect(controller.filtered-params<name>).to.be('gd');
    }
  }
}
