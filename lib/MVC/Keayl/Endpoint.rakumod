use v6.d;
use MVC::Keayl::Request;
use MVC::Keayl::Response;

unit role MVC::Keayl::Endpoint;

method call(MVC::Keayl::Request:D $request --> MVC::Keayl::Response:D) { ... }
