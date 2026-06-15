use v6.d;

my %flash-types;

sub register-flash-type(Str:D $name --> Nil) is export {
  %flash-types{$name} = True;
}

sub flash-types(--> List) is export {
  %flash-types.keys.sort.List
}

class MVC::Keayl::Flash::Now does Associative {
  has $.flash is required;

  method AT-KEY(Str() $key)              { $!flash{$key} }
  method EXISTS-KEY(Str() $key --> Bool) { $!flash{$key}:exists }

  method ASSIGN-KEY(Str() $key, $value) {
    $!flash{$key} = $value;
    $!flash.mark-discard($key);
  }
}

class MVC::Keayl::Flash does Associative {
  has %.flashes;
  has %.discard;
  has $!now;

  method from-session(%saved --> MVC::Keayl::Flash) {
    self.new(flashes => %saved.clone, discard => %saved.keys.map(* => True).hash)
  }

  method AT-KEY(Str() $key)              { %!flashes{$key} }
  method EXISTS-KEY(Str() $key --> Bool) { %!flashes{$key}:exists }

  method ASSIGN-KEY(Str() $key, $value) {
    %!flashes{$key} = $value;
    %!discard{$key}:delete;
  }

  method DELETE-KEY(Str() $key) {
    %!flashes{$key}:delete;
    %!discard{$key}:delete;
  }

  method mark-discard(Str() $key) { %!discard{$key} = True }

  method now { $!now //= MVC::Keayl::Flash::Now.new(flash => self) }

  method keep($key?) {
    with $key { %!discard{~$key}:delete } else { %!discard = () }
    self
  }

  method discard($key?) {
    with $key { %!discard{~$key} = True } else { %!discard = %!flashes.keys.map(* => True).hash }
    self
  }

  method keys    { %!flashes.keys }
  method to-hash { %!flashes.clone }

  method FALLBACK(Str $name, |args) {
    X::Method::NotFound.new(method => $name, typename => self.^name).throw
      unless %flash-types{$name};

    %!flashes{$name} = args[0] if args.elems;
    %!flashes{$name}
  }

  method to-session-value(--> Hash) {
    %!flashes.grep({ !%!discard{.key} }).hash
  }
}
