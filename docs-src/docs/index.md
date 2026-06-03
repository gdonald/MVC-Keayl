# MVC::Keayl

The latest version of this documentation lives at [https://gdonald.github.io/MVC-Keayl/](https://gdonald.github.io/MVC-Keayl/).

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

- [Request](request.md) — the incoming HTTP request wrapper.
- [Response](response.md) — the outgoing HTTP response builder.
- [Middleware](middleware.md) — the Rack-like middleware stack and endpoint protocol.
