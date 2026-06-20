use v6.d;
use MVC::Keayl::Controller;

unit class MVC::Keayl::HealthController is MVC::Keayl::Controller;

method controller-path(--> Str) { 'health' }

method show {
  self.render(
    html   => '<!DOCTYPE html><html><head><title>Keayl</title></head><body style="background-color: green"></body></html>',
    status => 200,
  );
}
