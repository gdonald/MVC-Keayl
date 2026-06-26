# MVC::Keayl

A Model-View-Controller web framework for Raku.

MVC::Keayl is the web layer. The model layer is delegated to
[ORM::ActiveRecord](https://github.com/gdonald/ORM-ActiveRecord) and default view
rendering to [Template::HAML](https://github.com/gdonald/Template-HAML); both are
pluggable. The HTTP server is reached through an abstract adapter, with the
default adapter built on [Cro](https://cro.raku.org/).

## Installation

```
zef install MVC::Keayl
```

## Getting started

Scaffold a new application, then boot it:

```
keayl new blog
cd blog
bin/dev
```

`keayl new` writes a starter layout: `config/application.json`,
`config/application.raku`, `config/routes.raku` with a `root` route, a
`HomeController` rendering through an `application` layout, an `assets/` directory
served by the static middleware, `bin/server`/`bin/dev`/`bin/test` scripts, a
browser spec for the home page, a `META6.json`, a health-check endpoint at `/up`,
a PWA manifest and service worker, and static exception pages.

`bin/dev` serves the app over HTTP with the Cro adapter, defaulting to
`127.0.0.1:3000`. Other commands include `keayl routes`, `keayl console`, and
`keayl generate`. See the [CLI docs](https://gdonald.github.io/MVC-Keayl/cli/)
for the full command list.

## Features

- Request and Response wrappers over the HTTP server.
- Rack-like middleware stack and endpoint protocol, with built-in middleware for
  static files, host authorization, request logging, request IDs, SSL
  redirection, and secure headers.
- Abstract server adapter contract, with a Cro-based default adapter and an
  in-memory test adapter.
- Routes file DSL with resourceful routes, mounts, redirects, path patterns, and
  URL helpers.
- Base controller with per-request state, action dispatch, and filters.
- View resolution, pluggable view handlers with a HAML handler, and view caching.
- URL, asset, date/time, form, number, options, tag, and text view helpers.
- Cookie jar with signed and encrypted variants.
- Session abstraction with cookie-backed and server-side stores.
- Flash messages that survive one redirect.
- CSRF authenticity tokens and forgery protection.
- Parameter filtering to redact sensitive values from logs.
- Transport and host security: SSL enforcement, host authorization, and secure
  headers.
- Secrets resolution, credentials, and key derivation.
- Content negotiation with MIME types, `respond-to`, and an API controller base.
- Conditional GET, cache headers, fragment caching, and response streaming.
- Application object with configuration loading, boot, and request dispatch.
- Internationalization with locales and pluralization.
- HTTP authentication helpers.
- Logging, instrumentation and notifications, error reporting, and a developer
  exception page.
- Background jobs with async, inline, test, and database queue adapters, plus
  GlobalID serialization.
- Mailer with file, SMTP, and test delivery, previews, and a delivery job.
- Action Mailbox for routing and ingesting inbound mail.
- Action Text for rich text content.
- Active Storage with services, attachments, variants, and blob serving.
- Cable with channels, connections, in-memory and external pub/sub, and
  broadcasting.
- Live streaming responses.
- Asset pipeline with serving and asset helpers.
- Health check and PWA controllers.
- Mountable engines.
- CLI with code generators and test support utilities.

## Documentation

Full documentation lives at
[gdonald.github.io/MVC-Keayl](https://gdonald.github.io/MVC-Keayl/).

## License

Artistic-2.0. See [LICENSE](LICENSE).
