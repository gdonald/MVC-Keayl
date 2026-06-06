# View helpers

View helpers build HTML. They return `SafeString` values, so their markup is not
re-escaped when emitted with `!=`. In templates they are available as closure
locals (`$link_to`, `$image_tag`, and so on).

## Tag building

`content-tag` builds an element with content; `tag` builds a self-closing
element. Attribute values are escaped, a `True` value becomes a bare boolean
attribute, and a `False` or undefined value is omitted:

```perl6
content-tag('p', 'hi', %( class => 'lead' ));        # <p class="lead">hi</p>
tag('input', %( type => 'text', disabled => True )); # <input disabled type="text" />
```

String content is escaped; a `SafeString` is emitted as-is.

### Nested data and aria attributes

A `data` or `aria` value that is a hash expands to dasherized attributes, and a
structured value is JSON encoded:

```perl6
content-tag('div', 'x', %( data => %( user_id => 5, toggle => 'modal' ) ));
# <div data-toggle="modal" data-user-id="5">x</div>

content-tag('div', 'x', %( data => %( ids => [1, 2] ) ));
# <div data-ids="[1,2]">x</div>
```

`data-attributes` builds the same dasherized keys as a hash for merging into
other attributes.

### Class helper

A `class` attribute accepts an array of tokens or a hash of conditional tokens,
and `class-names` builds the same token list on its own:

```perl6
tag('span', %( class => ['a', 'b'] ));                       # class="a b"
content-tag('div', 'x', %( class => %( active => $on ) ));   # class="active" when $on

class-names('btn', %( active => True, disabled => False ));  # "btn active"
class-names(['a', 'b'], 'a', 'c');                           # "a b c"
```

Falsy and duplicate tokens are dropped, and an empty class attribute is omitted.

## URL helpers

`url-for` turns a target into a URL string. It passes a string through and reads
`path` from a hash. `link-to` builds an anchor, and `button-to` builds a small
form that posts to a URL, adding a `_method` override for other verbs:

```perl6
link-to('Posts', '/posts', %( class => 'nav' ));   # <a class="nav" href="/posts">Posts</a>
link-to('/only');                                   # <a href="/only">/only</a>
button-to('Delete', '/posts/1', %( method => 'delete' ));
```

## Asset helpers

`asset-path` resolves a source to a URL. A bare source is prefixed with
`/assets/`; an absolute path or external URL is left alone; a `:type` adds an
extension when the source has none:

```perl6
asset-path('logo.png');           # /assets/logo.png
asset-path('app', :type('css'));  # /assets/app.css
```

`image-tag`, `stylesheet-link-tag`, and `javascript-include-tag` build the
matching elements, resolving their sources through `asset-path`. `image-tag`
derives a default `alt` from the filename, and the link and script helpers accept
multiple sources:

```perl6
image-tag('logo.png');                       # <img alt="Logo" src="/assets/logo.png" />
stylesheet-link-tag('app', 'admin');
javascript-include-tag('app');
```

### Pluggable resolver

`asset-path` and the asset tags accept a `resolver`, a routine of
`($source, $type)` that returns the final URL. It is the seam for fingerprinting
or a CDN host. A `MVC::Keayl::View` carries an `asset-resolver` that its asset
helpers use:

```perl6
my $view = MVC::Keayl::View.new(
  :paths(['app/views']),
  asset-resolver => -> $source, $type { 'https://cdn.example/' ~ $source },
);
```
