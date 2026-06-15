use v6.d;
use JSON::Fast;
use Digest::SHA1::Native;

unit module MVC::Keayl::Cache;

class Entry is export {
  has $.value;
  has $.expires-at;
  has $.version;

  method is-expired(Real:D $now --> Bool) {
    $!expires-at.defined && $now >= $!expires-at
  }

  method is-mismatched($version --> Bool) {
    $!version.defined && $version.defined && $!version ne $version
  }
}

sub matcher-regex($matcher) {
  return $matcher if $matcher ~~ Regex;

  my $pattern = $matcher.Str.split('*').map({ "'" ~ $_.subst("'", "\\'", :g) ~ "'" }).join('.*');
  / <$pattern> /
}

role Store is export {
  has &.clock = sub { now };
  has Str $.namespace;
  has $.default-expires-in;

  method read-entry($key)              { ... }
  method write-entry($key, $entry)     { ... }
  method delete-entry($key)            { ... }
  method entry-keys(--> List)          { ... }

  method !now(--> Real) { &!clock().Numeric }

  method !normalize($key --> Str) {
    $!namespace.defined ?? $!namespace ~ ':' ~ $key !! ~$key
  }

  method !expiry(%options) {
    my $seconds = %options<expires-in> // $!default-expires-in;
    $seconds.defined ?? self!now + $seconds !! Nil
  }

  method !live-entry($key, %options) {
    my $entry = self.read-entry($key);
    return Nil without $entry;

    if $entry.is-expired(self!now) {
      self.delete-entry($key);
      return Nil;
    }

    return Nil if $entry.is-mismatched(%options<version>);
    $entry
  }

  method read($key, *%options) {
    my $entry = self!live-entry(self!normalize($key), %options);
    $entry.defined ?? $entry.value !! Nil
  }

  method write($key, $value, *%options) {
    self.write-entry(self!normalize($key), Entry.new(
      :$value,
      expires-at => self!expiry(%options),
      version    => %options<version>,
    ));
    $value
  }

  method delete($key) {
    self.delete-entry(self!normalize($key))
  }

  method exist($key, *%options --> Bool) {
    self!live-entry(self!normalize($key), %options).defined
  }

  method exists($key, *%options --> Bool) {
    self.exist($key, |%options)
  }

  method fetch($key, &producer, *%options) {
    my $normalized = self!normalize($key);
    my $now        = self!now;

    unless %options<force> {
      my $entry = self.read-entry($normalized);

      if $entry.defined && !$entry.is-mismatched(%options<version>) {
        return $entry.value unless $entry.is-expired($now);

        with %options<race-condition-ttl> -> $ttl {
          self.write-entry($normalized, Entry.new(
            value      => $entry.value,
            expires-at => $now + $ttl,
            version    => $entry.version,
          ));
        }
      }
    }

    my $value = producer();
    return $value if !$value.defined && %options<skip-nil>;

    self.write($key, $value, |%options);
    $value
  }

  method increment($key, Int $amount = 1, *%options) {
    my $normalized = self!normalize($key);
    my $now        = self!now;

    my $entry = self.read-entry($normalized);
    $entry = Nil if $entry.defined && $entry.is-expired($now);

    my $value      = ($entry.defined ?? $entry.value !! 0) + $amount;
    my $expires-at = $entry.defined ?? $entry.expires-at !! self!expiry(%options);

    self.write-entry($normalized, Entry.new(:$value, :$expires-at, version => %options<version>));
    $value
  }

  method decrement($key, Int $amount = 1, *%options) {
    self.increment($key, -$amount, |%options)
  }

  method read-multi(*@keys, *%options) {
    my %out;

    for @keys -> $key {
      my $value = self.read($key, |%options);
      %out{$key} = $value if $value.defined;
    }

    %out
  }

  method write-multi(%entries, *%options) {
    self.write(.key, .value, |%options) for %entries.pairs;
    %entries
  }

  method fetch-multi(@keys, &producer, *%options) {
    my %out;

    for @keys -> $key {
      %out{$key} = self.fetch($key, { producer($key) }, |%options);
    }

    %out
  }

  method delete-matched($matcher) {
    my $regex = matcher-regex($matcher);
    my $count = 0;

    for self.entry-keys.grep(* ~~ $regex) -> $key {
      self.delete-entry($key);
      $count++;
    }

    $count
  }

  method clear {
    self.delete-entry($_) for self.entry-keys;
    self
  }
}

class MemoryStore does Store is export {
  has %!entries;
  has @!order;
  has Int $.max-entries;

  method read-entry($key) {
    return Nil unless %!entries{$key}:exists;
    self!touch($key);
    %!entries{$key}
  }

  method write-entry($key, $entry) {
    %!entries{$key} = $entry;
    self!touch($key);
    self!evict;
    $entry
  }

  method delete-entry($key) {
    @!order = @!order.grep(* ne $key);
    %!entries{$key}:delete
  }

  method entry-keys(--> List) {
    %!entries.keys.List
  }

  method !touch($key) {
    @!order = @!order.grep(* ne $key);
    @!order.push($key);
  }

  method !evict {
    return without $!max-entries;

    while @!order.elems > $!max-entries {
      my $oldest = @!order.shift;
      %!entries{$oldest}:delete;
    }
  }
}

class NullStore does Store is export {
  method read-entry($key)          { Nil }
  method write-entry($key, $entry) { $entry }
  method delete-entry($key)        { Nil }
  method entry-keys(--> List)      { () }
}

sub encode-entry($entry --> Str) {
  to-json({
    value      => $entry.value,
    expires-at => $entry.expires-at,
    version    => $entry.version,
  }, :!pretty)
}

sub decode-entry(Str $json --> Entry) {
  my %data = from-json($json);
  Entry.new(value => %data<value>, expires-at => %data<expires-at>, version => %data<version>)
}

class FileStore does Store is export {
  has IO::Path() $.root is required;

  method !path($key --> IO::Path) {
    $!root.add(sha1-hex($key))
  }

  method read-entry($key) {
    my $path = self!path($key);
    return Nil unless $path.e;
    decode-entry($path.slurp.split("\n", 2)[0])
  }

  method write-entry($key, $entry) {
    $!root.mkdir unless $!root.e;

    my $path = self!path($key);
    $path.spurt(encode-entry($entry) ~ "\n" ~ $key);
    $entry
  }

  method delete-entry($key) {
    my $path = self!path($key);
    $path.unlink if $path.e;
    Nil
  }

  method entry-keys(--> List) {
    return () unless $!root.e;

    $!root.dir.grep(*.f).map({ .slurp.split("\n", 2)[1] }).grep(*.defined).List
  }
}

class ExternalStore does Store is export {
  has $.client is required;

  method read-entry($key) {
    my $raw = $!client.get($key);
    $raw.defined ?? decode-entry($raw) !! Nil
  }

  method write-entry($key, $entry) {
    my $ttl = $entry.expires-at.defined ?? $entry.expires-at - self!now !! Nil;
    $!client.set($key, encode-entry($entry), :$ttl);
    $entry
  }

  method delete-entry($key) {
    $!client.del($key)
  }

  method entry-keys(--> List) {
    $!client.keys.List
  }
}

sub part-key($part --> Str) {
  return $part.cache-key                            if $part.^can('cache-key');
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
