use v6.d;

class X::MVC::Keayl::ParameterMissing is Exception {
  has $.key;
  method message(--> Str) { "param is missing or the value is empty: $!key" }
}

class X::MVC::Keayl::UnpermittedParameters is Exception {
  has @.keys;
  method message(--> Str) {
    'found unpermitted parameter' ~ (@!keys > 1 ?? 's' !! '') ~ ': ' ~ @!keys.join(', ')
  }
}

my $unpermitted-action = 'log';

sub present($value --> Bool) {
  return False without $value;
  return False if $value ~~ Str         && $value.trim eq '';
  return False if $value ~~ Positional  && !$value.elems;
  return False if $value ~~ Associative && !$value.elems;
  True
}

sub permitted-scalar($value --> Bool) {
  $value !~~ Associative && $value !~~ Positional
}

class MVC::Keayl::Parameters does Associative {
  has %.store;
  has Bool $.permitted = False;

  method new(%store, Bool :$permitted = False --> ::?CLASS:D) {
    self.bless(:%store, :$permitted)
  }

  method AT-KEY($key)     { %!store{$key.Str} }
  method EXISTS-KEY($key) { %!store{$key.Str}:exists }
  method keys            { %!store.keys }
  method values          { %!store.values }
  method kv              { %!store.kv }
  method pairs           { %!store.pairs }
  method elems(--> Int)  { %!store.elems }
  method Hash(--> Hash)  { %!store }
  method gist           { %!store.gist }
  method Str            { %!store.gist }

  method is-permitted(--> Bool) {
    $!permitted
  }

  method unpermitted-action($action?) {
    $unpermitted-action = $action.Str if $action.defined;
    $unpermitted-action
  }

  method require($key) {
    my $value = %!store{$key.Str};
    X::MVC::Keayl::ParameterMissing.new(:$key).throw unless present($value);

    $value ~~ Associative ?? ::?CLASS.new($value.hash) !! $value
  }

  method permit(*@scalars, Str :$on-unpermitted, *%nested --> ::?CLASS:D) {
    my %permitted;
    my %allowed;

    for @scalars -> $key {
      my $name = $key.Str;
      %allowed{$name} = True;
      next unless %!store{$name}:exists;
      %permitted{$name} = %!store{$name} if permitted-scalar(%!store{$name});
    }

    for %nested.kv -> $key, $spec {
      %allowed{$key} = True;
      next unless %!store{$key}:exists;

      my $value = %!store{$key};

      if $spec ~~ Positional && $spec.elems == 0 {
        %permitted{$key} = $value.grep(&permitted-scalar).Array if $value ~~ Positional;
      } elsif $value ~~ Positional {
        %permitted{$key} = $value.grep(* ~~ Associative).map({ ::?CLASS.new(.hash).permit(|$spec.list).Hash }).Array;
      } elsif $value ~~ Associative {
        %permitted{$key} = ::?CLASS.new($value.hash).permit(|$spec.list).Hash;
      }
    }

    my @unpermitted = %!store.keys.grep({ !%allowed{$_} }).sort;
    X::MVC::Keayl::UnpermittedParameters.new(keys => @unpermitted.List).throw
      if @unpermitted && ($on-unpermitted // $unpermitted-action) eq 'raise';

    ::?CLASS.new(%permitted, :permitted)
  }

  method permit-all(--> ::?CLASS:D) {
    $!permitted = True;
    self
  }
}
