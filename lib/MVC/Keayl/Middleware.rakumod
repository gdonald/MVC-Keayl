use v6.d;
use MVC::Keayl::Endpoint;
use MVC::Keayl::Request;
use MVC::Keayl::Response;

unit class MVC::Keayl::Middleware does MVC::Keayl::Endpoint;

has MVC::Keayl::Endpoint $.app is required;

method call(MVC::Keayl::Request:D $request --> MVC::Keayl::Response:D) {
  $!app.call($request)
}
