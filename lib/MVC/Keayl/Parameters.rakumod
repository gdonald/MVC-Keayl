use v6.d;

unit class MVC::Keayl::Parameters does Associative;

has %.store;

method new(%store --> ::?CLASS:D) {
  self.bless(:%store)
}

method AT-KEY($key)     { %!store{$key.Str} }
method EXISTS-KEY($key) { %!store{$key.Str}:exists }
method keys             { %!store.keys }
method values           { %!store.values }
method kv               { %!store.kv }
method pairs            { %!store.pairs }
method elems(--> Int)   { %!store.elems }
method Hash(--> Hash)   { %!store }
method gist             { %!store.gist }
method Str              { %!store.gist }
