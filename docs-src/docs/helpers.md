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

## Forms

`form-with` builds a form around a `FormBuilder`. The builder is passed to a
`content` callback and scopes field names to the model (or an explicit `scope`),
prefills values, and annotates errors. The form posts by default, adding a
`_method` override for other verbs and an `authenticity_token` field when a
`csrf-token` is given:

```perl6
form-with(
  model      => $post,
  url        => '/posts/1',
  method     => 'patch',
  csrf-token => $token,
  content    => -> $f {
    $f.text-field('title') ~ $f.submit('Save')
  },
);
```

### Field helpers

The builder provides `text-field`, `password-field`, `hidden-field`,
`text-area`, `check-box`, `radio-button`, `select`, `label`, `submit`, and
`button`. Field names are scoped (`post[title]`) and ids derived
(`post_title`). A `check-box` renders a hidden companion for its unchecked
value, a `select` marks the option matching the model value, and a
`password-field` never emits a value. `fields-for` builds a nested builder whose
names are scoped under the parent:

```perl6
$form.fields-for('author', block => -> $author {
  $author.text-field('name')   # name="post[author][name]"
});
```

### Model awareness

When the builder has a model, fields prefill from it (calling the
attribute-named method), an explicit `value` overrides the model, and a field
whose attribute reports errors gets a `field-with-errors` class. The builder
reads errors through the model's `errors-on($attribute)` method, and
`errors-for` renders the messages.

## simple_form-style inputs

`SimpleFormBuilder` adds an `input` method that assembles a label, control, hint,
and error into a wrapper, inferring the control type. `simple-form-for` wraps it
in a form like `form-with`:

```perl6
simple-form-for($post, url => '/posts', required => ['title'], content => -> $f {
  $f.input('title', hint => 'Keep it short')
    ~ $f.input('body')          # textarea, inferred
    ~ $f.input('published')     # checkbox, inferred from a boolean value
    ~ $f.input('state', as => 'select', collection => ['draft', 'live'])
});
```

The type is taken from `as`, then the attribute name (`password`, `email`, the
long-text names `body`/`content`/`description`/`notes`), then a boolean model
value, defaulting to a string input. A required attribute marks the wrapper and
adds a `*` to the label, and an attribute with errors marks the wrapper and
appends the messages.

## Formatting helpers

### Text

`truncate` cuts a string to a length (counting the omission) and can break at a
separator. `pluralize` pairs a count with a singular or pluralized word, using a
small inflector with irregulars and an explicit `plural` override.
`simple-format` wraps text in paragraphs, turning blank lines into new paragraphs
and single newlines into `<br />`, escaping the content:

```perl6
truncate('This is a long sentence', length => 12);   # This is a...
pluralize(2, 'person');                               # 2 people
simple-format("Para one\n\nPara two");                # <p>Para one</p>\n<p>Para two</p>
```

### Numbers

```perl6
number-with-delimiter(1234567);     # 1,234,567
number-to-currency(1234.5);         # $1,234.50
number-to-percentage(66.666, precision => 1);   # 66.7%
number-to-human-size(1536);         # 1.5 KB
```

`number-to-currency` accepts `unit`, `precision`, `delimiter`, `separator`, and a
`format` string (`%u` for the unit, `%n` for the number).

### Date and time

`distance-of-time-in-words` describes the gap between two times in words, with an
optional `include-seconds` for finer detail under a minute. `time-ago-in-words`
is the same measured against the current time (or an explicit reference):

```perl6
distance-of-time-in-words($from, $to);                 # about 5 hours
distance-of-time-in-words($from, $to, include-seconds => True);   # less than 5 seconds
time-ago-in-words($posted-at);
```
