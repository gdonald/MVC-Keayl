use v6.d;
use MVC::Keayl::Router;
use MVC::Keayl::Routing::Resources;

unit class MVC::Keayl::Routing::UrlHelpers;

has MVC::Keayl::Router $.router is required;
has %.default-url-options;

sub record-persisted($record --> Bool) {
  return ?$record.is-persisted if $record.^can('is-persisted');
  return $record.id.defined    if $record.^can('id');
  False
}

method !route-for(Str:D $name) {
  my $route = $!router.route-named($name);
  die "no route named '$name'" unless $route.defined;
  $route
}

method !build(Str:D $name, @positional, %named, Bool :$url --> Str) {
  my %options = %!default-url-options, %named;

  my $host     = %options<host>:delete;
  my $protocol = %options<protocol>:delete // 'http';
  my $port     = %options<port>:delete;
  my $trailing = %options<trailing-slash>:delete // False;
  my $anchor   = %options<anchor>:delete;

  my $route = self!route-for($name);
  my @required = $route.pattern.required-names;
  for @positional.kv -> $index, $value { %options{@required[$index]} = $value if @required[$index].defined }

  my $path = $route.pattern.generate(%options, :$trailing, :$anchor);
  return $path unless $url;

  my $authority = $host // '';
  $authority ~= ':' ~ $port if $port.defined;

  $protocol ~ '://' ~ $authority ~ $path
}

method path-for(Str:D $name, *@positional, *%named --> Str) {
  self!build($name, @positional, %named)
}

multi method url-for(Str:D $name, *@positional, *%named --> Str) {
  self!build($name, @positional, %named, :url)
}

multi method url-for(Any:D $record, *%named --> Str) {
  self.polymorphic-url($record, |%named)
}

method polymorphic-path($record, *%named --> Str) {
  self!polymorphic($record, %named)
}

method polymorphic-url($record, *%named --> Str) {
  self!polymorphic($record, %named, :url)
}

method !polymorphic($record, %named, Bool :$url --> Str) {
  my $class = $record.^name.split(/<[:.]>+/).tail;

  with $!router.resolvers{$class} -> $resolver {
    my @args = $resolver($record).flat;
    return $url ?? self.url-for(|@args, |%named) !! self.path-for(|@args, |%named);
  }

  my $singular = $class.lc;
  my $plural   = pluralize($singular);

  if record-persisted($record) {
    $url ?? self.url-for($singular, $record.id, |%named) !! self.path-for($singular, $record.id, |%named)
  } else {
    $url ?? self.url-for($plural, |%named) !! self.path-for($plural, |%named)
  }
}

method FALLBACK(Str $name, |args) {
  if $name ~~ /^ (.+) '-' (path|url) $/ {
    my $helper = ~$0;
    my $kind   = ~$1;

    with $!router.directs{$helper} -> &block {
      return block(|args);
    }

    return $kind eq 'path' ?? self.path-for($helper, |args) !! self.url-for($helper, |args);
  }

  die "no URL helper named '$name'";
}
