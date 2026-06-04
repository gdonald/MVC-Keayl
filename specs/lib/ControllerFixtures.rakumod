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
}
