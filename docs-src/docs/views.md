# Views

`MVC::Keayl::View` renders templates. It resolves a template by name, format, and
handler, compiles it through a pluggable handler, and caches the result. HAML is
the default handler, backed by [Template::HAML](https://github.com/gdonald/Template-HAML).

```perl6
use MVC::Keayl::View;

my $view = MVC::Keayl::View.new(:paths(['app/views']));

$view.render-template('users/show', { user => $user });
```

## Template resolution

`render-template` resolves a name against each search path in turn, then by
handler extension, preferring a format-qualified file:

```
app/views/users/show.html.haml      # users/show, format html
app/views/users/show.haml           # format-less fallback
```

The default format is `html`, overridable per call with `:format`. When the View
is given a controller, a name with no `/` is resolved relative to the
controller's path (`UsersController` resolves under `users/`).

## Handlers

A handler compiles a template source and renders it with locals. The default
`haml` handler renders HAML. Register others by extension:

```perl6
$view.register-handler('txt', MyTextHandler.new);
```

A handler does the `MVC::Keayl::View::Handler` role: `compile($source)` returns a
compiled template, and `render($compiled, %locals)` produces the output.

## Caching and reloading

Compiled templates are cached by file. `reload` (on by default) re-checks the
file's modification time and recompiles when it changes, which suits development.
Setting `cache => False` disables caching so every render recompiles:

```perl6
my $view = MVC::Keayl::View.new(:paths(['app/views']), :!reload);   # trust the cache
```

## Inline and layouts

`render-inline` renders a template string directly. `render-layout` renders a
layout from `layouts/` with the wrapped content available as the `content` local.
