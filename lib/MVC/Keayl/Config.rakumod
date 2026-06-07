use v6.d;
use JSON::Fast;

unit class MVC::Keayl::Config does Associative;

has Str $.environment = 'development';
has     %.settings;

sub deep-merge(%base, %overrides --> Hash) {
  my %result = %base;

  for %overrides.kv -> $key, $value {
    if %result{$key} ~~ Associative && $value ~~ Associative {
      %result{$key} = deep-merge(%result{$key}, $value);
    } else {
      %result{$key} = $value;
    }
  }

  %result
}

method AT-KEY(Str() $key)              { %!settings{$key} }
method EXISTS-KEY(Str() $key --> Bool) { %!settings{$key}:exists }

method get(Str:D $path) {
  my $node = %!settings;

  for $path.split('.') -> $segment {
    return Nil without $node;
    $node = $node ~~ Associative ?? $node{$segment} !! Nil;
  }

  $node
}

method merge(%overrides --> ::?CLASS) {
  self.new(environment => $!environment, settings => deep-merge(%!settings, %overrides))
}

method environment-from(%env = %*ENV --> Str) {
  %env<KEAYL_ENV> // %env<RAKU_ENV> // 'development'
}

method load(IO() $path, Str :$environment, :%env = %*ENV --> ::?CLASS) {
  my $env  = $environment // self.environment-from(%env);
  my %data = from-json($path.slurp);

  my %shared       = (%data<shared> // %data<default> // {});
  my %environment  = (%data{$env} // {});

  self.new(:environment($env), settings => deep-merge(%shared, %environment))
}
