# Changelog

All notable changes to MVC::Keayl are recorded here. The format groups entries
under Added, Changed, Fixed, and Removed.

## v0.9.1 (2026-07-11)

### Added

- Multipart form parsing: a `multipart/form-data` request body parses text fields
  and file fields, each file becoming a `{ filename, content, type }` hash whose
  `content` is the raw upload as a `Blob`, so binary uploads reach controller
  parameters byte-for-byte.
- Model and form translation on the i18n backend: `human-attribute-name`,
  `human-model-name`, `translate-error`, `form-label`, `form-placeholder`, and
  `submit-default`, each accepting the model as a class or an instance.

### Changed

- Development defaults to a log level that shows request logging, so a locally
  booted app logs each request without extra configuration. Other environments
  stay silent unless `log-level` is set.

### Fixed

- Class-level controller traits (`is layout`, `is protect-from-forgery`,
  `is filter-parameters`, `is wrap-parameters`, and a class-level `helper-method`
  declaration) were silently dropped when the controller was precompiled in its
  own module. They are now stored on the class itself and survive precompilation.

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
