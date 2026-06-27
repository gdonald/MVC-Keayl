# MVC::Keayl

The latest version of this documentation lives at [https://docs.keayl.dev/](https://docs.keayl.dev/).

The homepage for MVC::Keayl is [https://github.com/gdonald/MVC-Keayl](https://github.com/gdonald/MVC-Keayl).

## Synopsis

MVC::Keayl is a [Model-View-Controller](https://en.wikipedia.org/wiki/Model%E2%80%93view%E2%80%93controller)
web framework for Raku.

It is the web layer only. The model layer is delegated to
[ORM::ActiveRecord](https://github.com/gdonald/ORM-ActiveRecord) and default view
rendering to [Template::HAML](https://github.com/gdonald/Template-HAML); both are
pluggable. The HTTP server is reached through an abstract adapter, with the
default adapter built on [Cro](https://cro.raku.org/).

## Pages

- [Request](request.md): the incoming HTTP request wrapper.
- [Response](response.md): the outgoing HTTP response builder.
- [Middleware](middleware.md): the Rack-like middleware stack and endpoint protocol.
- [Server adapters](adapters.md): the abstract adapter contract, plus the Cro and in-memory test adapters.
- [Routing](routing.md): the routes file DSL and request recognition.
- [Controllers](controllers.md): the base controller, per-request state, and action dispatch.
- [Views](views.md): template resolution, handlers, and caching.
- [View helpers](helpers.md): URL, asset, and tag-building helpers.
- [Cookies](cookies.md): the cookie jar with signed and encrypted variants.
- [Sessions](sessions.md): the session abstraction with cookie and server-side stores.
- [Flash](flash.md): short messages that survive one redirect.
- [CSRF protection](csrf.md): authenticity tokens and forgery protection.
- [Parameter filtering](parameter-filtering.md): redacting sensitive parameters for logs.
- [Transport & host security](transport-security.md): SSL, host authorization, and secure headers.
- [Secrets](secrets.md): secret resolution and key derivation.
- [Content negotiation](content-negotiation.md): MIME types, `respond-to`, and API controllers.
- [Caching & streaming](caching.md): conditional GET, cache headers, fragment caching, and streaming.
- [Application & configuration](application.md): the application object, config, boot, and dispatch.
