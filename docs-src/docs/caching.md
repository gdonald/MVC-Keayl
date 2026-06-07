# Caching and streaming

## Conditional GET

`fresh-when` sets validators on the response and renders a `304 Not Modified`
when the request's `If-None-Match`/`If-Modified-Since` show the client already
has the current version. `is-stale` is its inverse: it returns true when you
should render.

```perl6
method show {
  self.render('show') if self.is-stale(etag => $post, last-modified => $post.updated-at);
}
```

`etag-for` computes an ETag from a value, using its `cache-key` or `to-hash` when
available. ETags are weak by default (`W/"..."`); pass `weak => False` for a
strong ETag. Matching uses a weak comparison, so `W/` prefixes are ignored, and
`*` matches anything.

## Cache headers

`expires-in` sets `Cache-Control` with a max-age, `private` by default or
`public`, plus any extra directives. `expires-now` marks the response
uncacheable:

```perl6
self.expires-in(3600, public => True, must-revalidate => True);
# Cache-Control: public, max-age=3600, must-revalidate

self.expires-now;                  # Cache-Control: no-cache
self.expires-now(no-store => True); # Cache-Control: no-store
```

## Fragment caching

`MVC::Keayl::Cache` provides a `Store` role and an in-process `MemoryStore`. A
store's `fetch` returns a cached value or computes and stores it. `cache-key`
derives a key from parts (an object contributes its own `cache-key`), under a
`views/` namespace, with an optional template `digest`:

```perl6
cache-key($post, digest => template-digest($source));   # views/posts/1-2021/<digest>
```

A view caches a fragment with `cache-fragment`, which computes the content once
per key:

```perl6
$view.cache-fragment([$post], { render-the-fragment() });
```

## Streaming

A response body can be streamed instead of buffered. `stream` takes an iterable
of chunks (strings or blobs); `stream-chunks` yields them encoded, and
`is-streaming` reports whether a stream is set, for an adapter to write chunked:

```perl6
$response.stream(gather { for @rows { take row-html($_) } });
```

## Range requests

`send-file` honours a `Range` request header, responding `206 Partial Content`
with a `Content-Range` header and the requested byte slice, and advertises
`Accept-Ranges: bytes`.
