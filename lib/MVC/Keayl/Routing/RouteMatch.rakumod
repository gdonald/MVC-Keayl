use v6.d;
use MVC::Keayl::Routing::Route;

unit class MVC::Keayl::Routing::RouteMatch;

has MVC::Keayl::Routing::Route $.route is required;
has %.params;

method controller(--> Str)     { $!route.controller }
method action(--> Str)         { $!route.action }
method callable(--> Callable)  { $!route.callable }
