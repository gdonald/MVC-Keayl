use v6.d;
use MVC::Keayl::Middleware;
use MVC::Keayl::Request;
use MVC::Keayl::Response;
use ORM::ActiveRecord::Connection::Registry;

# Give each request its own pooled connection per database it touches. A registry
# is bound for the request; the first model query on a connection checks one out
# of that connection's pool and every later query on the same connection reuses
# it, and they all return to their pools when the request ends (including on an
# exception). The pool verifies a connection on checkout and reconnects a dropped
# one, so a socket that died between requests heals on the next request instead of
# failing every query until the server restarts. Keyed by connection name, so an
# app with a replica or several databases routes each model correctly.
unit class MVC::Keayl::Middleware::Database is MVC::Keayl::Middleware;

method call(MVC::Keayl::Request:D $request --> MVC::Keayl::Response:D) {
  my $*AR-CONNECTION-REGISTRY = ORM::ActiveRecord::Connection::Registry.new;
  LEAVE $*AR-CONNECTION-REGISTRY.release-all;

  self.app.call($request);
}
