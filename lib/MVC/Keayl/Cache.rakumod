use v6.d;
use Digest::SHA1::Native;

unit module MVC::Keayl::Cache;

role Store is export {
  method read($key)             { ... }
  method write($key, $value)    { ... }
  method exists($key --> Bool)  { ... }
  method delete($key)           { ... }

  method fetch($key, &producer) {
    return self.read($key) if self.exists($key);

    my $value = producer();
    self.write($key, $value);
    $value
  }
}

class MemoryStore does Store is export {
  has %.entries;

  method read($key)            { %!entries{$key} }
  method write($key, $value)   { %!entries{$key} = $value }
  method exists($key --> Bool) { %!entries{$key}:exists }
  method delete($key)          { %!entries{$key}:delete }
}

sub part-key($part --> Str) {
  return $part.cache-key                          if $part.^can('cache-key');
  return $part.id ~ '-' ~ ($part.?updated-at // '') if $part.^can('id');
  ~$part
}

sub cache-key(*@parts, Str :$digest --> Str) is export {
  my @segments = @parts.map(&part-key);
  @segments.unshift('views');
  @segments.push($digest) if $digest;
  @segments.join('/')
}

sub template-digest(Str:D $source --> Str) is export {
  sha1-hex($source)
}
