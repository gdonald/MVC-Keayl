use v6.d;
use MVC::Keayl::Endpoint;

unit class MVC::Keayl::MiddlewareStack;

my class Entry {
  has Str $.name is required;
  has MVC::Keayl::Endpoint:U $.class is required;
  has Capture $.args is required;
}

has Entry @!entries;

method !index-of(Str:D $name --> Int) {
  @!entries.first({ .name eq $name }, :k)
}

method use(Str:D $name, MVC::Keayl::Endpoint:U $class, |args) {
  @!entries.push: Entry.new(:$name, :$class, :args(args));
  self
}

method insert-before(Str:D $before, Str:D $name, MVC::Keayl::Endpoint:U $class, |args) {
  my $i = self!index-of($before);
  die "unknown middleware '$before'" without $i;

  @!entries.splice($i, 0, Entry.new(:$name, :$class, :args(args)));
  self
}

method insert-after(Str:D $after, Str:D $name, MVC::Keayl::Endpoint:U $class, |args) {
  my $i = self!index-of($after);
  die "unknown middleware '$after'" without $i;

  @!entries.splice($i + 1, 0, Entry.new(:$name, :$class, :args(args)));
  self
}

method delete(Str:D $name) {
  @!entries = @!entries.grep({ .name ne $name });
  self
}

method names(--> List) {
  @!entries.map(*.name).list
}

method elems(--> Int) {
  @!entries.elems
}

method contains(Str:D $name --> Bool) {
  self!index-of($name).defined
}

method build(MVC::Keayl::Endpoint:D $endpoint --> MVC::Keayl::Endpoint:D) {
  my $app = $endpoint;

  for @!entries.reverse -> $entry {
    $app = $entry.class.new(:$app, |$entry.args);
  }

  $app
}
