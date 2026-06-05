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

## Inline rendering

`render-inline` renders a template string directly, without resolving a file.

## Layouts

When an action renders a template, the rendered body is wrapped in a layout from
`layouts/`. With no layout chosen, the `application` layout is used if it exists;
otherwise the template renders on its own. Inside the layout, the wrapped body is
available as the `content` local and through `yield`:

```haml
%html
  %body
    != $yield()
```

Choose a layout per action with the `:layout` option, or for every action of a
controller with the class-level `layout` declaration:

```perl6
self.render('show', :layout('print'));   # this action only

class AdminController is MVC::Keayl::Controller { }
AdminController.layout('admin');          # every action

self.render('show', :layout(False));      # no layout
```

An action-level `:layout` overrides a controller declaration, which overrides the
`application` default.

## content-for and yield

A template captures named content with `content_for`, and the layout places it
with `yield`:

```haml
-# in the template
= $content_for('title', 'Dashboard')

-# in the layout
%title= $yield('title')
%body
  != $yield()
```

`$yield()` returns the main body; `$yield(name)` returns the matching
`content_for` capture, or an empty string when none was set.
