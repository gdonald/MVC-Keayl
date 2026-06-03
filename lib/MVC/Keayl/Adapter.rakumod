use v6.d;
use MVC::Keayl::Endpoint;
use MVC::Keayl::Request;
use MVC::Keayl::Response;

unit role MVC::Keayl::Adapter;

has MVC::Keayl::Endpoint $.app is required;

method handle(MVC::Keayl::Request:D $request --> List) {
  $!app.call($request).finish
}
