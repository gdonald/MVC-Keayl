use v6.d;

unit class MVC::Keayl::View::Context;

has %!helpers;

submethod BUILD(:%helpers) {
  %!helpers = %helpers;
}

# Helpers are keyed by their dashed template name (link-to, format-price).
# Template::HAML discovers them through haml-helper-names and dispatches each as a
# bare call routed by FALLBACK, so a template invokes a helper as a plain
# function with arguments.
method haml-helper-names(--> List) {
  %!helpers.keys.sort.List
}

method FALLBACK(Str $name, |args) {
  die "undefined view helper '$name'" unless %!helpers{$name}:exists;
  %!helpers{$name}(|args)
}
