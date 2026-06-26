use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Request;
use MVC::Keayl::Controller;

class InlineController is MVC::Keayl::Controller {
  has @.trail;

  $?CLASS.before-action('record-before');
  $?CLASS.around-action('record-around');

  method record-before { @!trail.push('before') }
  method record-around($next) { @!trail.push('around-in'); $next(); @!trail.push('around-out') }

  method show { @!trail.push('action') }
}

describe 'callbacks declared inside the class body', {
  let(:controller, {
    my $instance = InlineController.new(request => MVC::Keayl::Request.new(:method<GET>, :path('/show')));
    $instance.dispatch('show');
    $instance
  });

  it 'registers and runs them in order when declared with the class handle', {
    expect(controller.trail.join(',')).to.be('before,around-in,action,around-out');
  }
}
