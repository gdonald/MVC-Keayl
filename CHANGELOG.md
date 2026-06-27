# Changelog

All notable changes to MVC::Keayl are recorded here. The format groups entries
under Added, Changed, Fixed, and Removed.

## v0.9.0 (2026-06-25)

First public release. MVC::Keayl is the web layer of a Rails-style stack for
Raku, pairing with ORM::ActiveRecord for models and Template::HAML for views.

### Added

- Request and Response wrappers over the underlying HTTP server.
- Rack-like middleware stack and endpoint protocol, with built-in middleware for
  static file serving, host authorization, request logging, request IDs, SSL
  redirection, and secure headers.
- Abstract server adapter contract, with a Cro-based default adapter and an
  in-memory test adapter.
- Routes file DSL with resourceful routes, mounts, redirects, path patterns, and
  URL helpers.
- Base controller with per-request state, action dispatch, and filters.
- Inline controller DSL through method and class traits: `is before-action`,
  `is after-action`, `is around-action`, `is rescue-from`, `is helper-method`,
  `is layout`, `is protect-from-forgery`, `is rate-limit`, `is wrap-parameters`,
  `is filter-parameters`, `is add-flash-types`, and
  `is http-basic-authenticate-with`.
- View resolution, pluggable view handlers with a HAML handler, and view caching.
- URL, asset, date/time, form, number, options, tag, and text view helpers.
- Custom view helper modules from `app/helpers`, with an `ApplicationHelper` and
  per-controller `<Name>Helper` loaded into the view context and reloaded on
  change in development.
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
