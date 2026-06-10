# Command-line interface

`bin/keayl` drives an application from the shell. It is a thin dispatcher over
`MVC::Keayl::CLI`, where each command is a plain function, so the same behavior is
available to call directly and to test.

```
keayl <command> [options]
```

Run `keayl help` for the command list and `keayl version` for the installed
version.

## new

Scaffold a new application skeleton in a subdirectory named after the app:

```
keayl new blog
```

This writes a starter layout: `config/application.json`, `config/application.raku`
(which loads the config and routes and returns an `MVC::Keayl::Application`),
`config/routes.raku` with a `root` route, a `HomeController`, a HAML view for its
`index` action, a `README.md`, and a `.gitignore`.

`scaffold-app($name, :$into)` returns the list of files it created, relative to
the new application directory. `:into` defaults to the current directory.

## server

Boot the application and serve it over HTTP with the Cro adapter:

```
keayl server
keayl s --host 0.0.0.0 --port 8080
```

`server` loads `config/application.raku`, builds the endpoint, and listens until
interrupted. The host defaults to `127.0.0.1` and the port to `3000`.

`build-server($app, :$host, :$port, :$scheme)` constructs the
[`Adapter::Cro`](adapters.md) around the application's endpoint without binding a
socket, so the wiring can be inspected on its own.

## routes

Print the route table for `config/routes.raku`:

```
keayl routes
```

Each row lists the route name, its verbs (joined with a comma), the path, and the
target. `routes-table(@table)` renders the table that
[route introspection](routing.md) produces; an unnamed route renders with a blank
name column.

## console

Open a REPL with the application booted and available:

```
keayl console
keayl c
```

`console` loads and boots `config/application.raku`, binds it to the
`$*KEAYL-APP` dynamic variable, then reads lines and evaluates each in turn,
printing the result. An evaluation error is reported without ending the session.

```
keayl> $*KEAYL-APP.environment
development
```
