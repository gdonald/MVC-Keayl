use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Cache;

my $temp-counter = 0;

sub temp-root {
  $*TMPDIR.add('keayl-cache-spec-' ~ $*PID ~ '-' ~ $temp-counter++)
}

describe 'MVC::Keayl::Cache::Store read and write', {
  let(:store, { MVC::Keayl::Cache::MemoryStore.new });

  it 'reads back a written value', {
    store.write('a', 'x');
    expect(store.read('a')).to.be('x');
  }

  it 'reports a written key as existing', {
    store.write('a', 'x');
    expect(store.exist('a')).to.be-truthy;
  }

  it 'reads a missing key as undefined', {
    expect(store.read('missing').defined).to.be-falsy;
  }

  it 'deletes a key', {
    store.write('a', 'x');
    store.delete('a');
    expect(store.exist('a')).to.be-falsy;
  }
}

describe 'MVC::Keayl::Cache::Store namespace', {
  let(:store, { MVC::Keayl::Cache::MemoryStore.new(namespace => 'app') });

  it 'reads its own keys', {
    store.write('k', 'v');
    expect(store.read('k')).to.be('v');
  }

  it 'prefixes stored keys with the namespace', {
    store.write('k', 'v');
    expect(store.entry-keys.head).to.be('app:k');
  }
}

describe 'MVC::Keayl::Cache::Store fetch', {
  it 'computes the value once', {
    my $store = MVC::Keayl::Cache::MemoryStore.new;
    my $calls = 0;

    store-fetch($store, $calls);
    store-fetch($store, $calls);

    expect($calls).to.be(1);
  }

  it 'returns the cached value', {
    my $store = MVC::Keayl::Cache::MemoryStore.new;
    $store.fetch('k', { 'value' });
    expect($store.fetch('k', { 'other' })).to.be('value');
  }

  it 'recomputes when forced', {
    my $store = MVC::Keayl::Cache::MemoryStore.new;
    $store.write('k', 'old');
    expect($store.fetch('k', { 'new' }, force => True)).to.be('new');
  }

  it 'does not store a nil result with skip-nil', {
    my $store = MVC::Keayl::Cache::MemoryStore.new;
    $store.fetch('k', { Nil }, skip-nil => True);
    expect($store.exist('k')).to.be-falsy;
  }
}

sub store-fetch($store, $calls is rw) {
  $store.fetch('k', { $calls++; 'value' });
}

describe 'MVC::Keayl::Cache::Store expiry', {
  it 'reads a value before expiry', {
    my $t = 1000;
    my $store = MVC::Keayl::Cache::MemoryStore.new(clock => sub { $t });
    $store.write('k', 'v', expires-in => 10);
    expect($store.read('k')).to.be('v');
  }

  it 'drops a value after expiry', {
    my $t = 1000;
    my $store = MVC::Keayl::Cache::MemoryStore.new(clock => sub { $t });
    $store.write('k', 'v', expires-in => 10);
    $t = 1011;
    expect($store.read('k').defined).to.be-falsy;
  }

  it 'applies a default expiry', {
    my $t = 2000;
    my $store = MVC::Keayl::Cache::MemoryStore.new(clock => sub { $t }, default-expires-in => 5);
    $store.write('k', 'v');
    $t = 2006;
    expect($store.read('k').defined).to.be-falsy;
  }
}

describe 'MVC::Keayl::Cache::Store versioning', {
  let(:store, {
    my $s = MVC::Keayl::Cache::MemoryStore.new;
    $s.write('k', 'v', version => 'v1');
    $s
  });

  it 'reads a value on a matching version', {
    expect(store.read('k', version => 'v1')).to.be('v');
  }

  it 'misses on a mismatched version', {
    expect(store.read('k', version => 'v2').defined).to.be-falsy;
  }
}

describe 'MVC::Keayl::Cache::Store race-condition ttl', {
  it 'serves the stale value to a concurrent reader while recomputing', {
    my $t = 3000;
    my $store = MVC::Keayl::Cache::MemoryStore.new(clock => sub { $t });
    $store.write('k', 'old', expires-in => 10);

    $t = 3011;
    my $seen;
    $store.fetch('k', { $seen = $store.read('k'); 'new' }, race-condition-ttl => 5);

    expect($seen).to.be('old');
  }
}

describe 'MVC::Keayl::Cache::Store counters', {
  it 'starts a fresh counter at the amount', {
    expect(MVC::Keayl::Cache::MemoryStore.new.increment('n')).to.be(1);
  }

  it 'adds on increment', {
    my $store = MVC::Keayl::Cache::MemoryStore.new;
    $store.increment('n', 4);
    expect($store.increment('n', 1)).to.be(5);
  }

  it 'subtracts on decrement', {
    my $store = MVC::Keayl::Cache::MemoryStore.new;
    $store.increment('n', 5);
    expect($store.decrement('n', 2)).to.be(3);
  }

  it 'preserves the window across increments', {
    my $t = 4000;
    my $store = MVC::Keayl::Cache::MemoryStore.new(clock => sub { $t });
    $store.increment('n', 1, expires-in => 5);
    expect($store.increment('n', 1)).to.be(2);
  }

  it 'resets the counter after the window', {
    my $t = 4000;
    my $store = MVC::Keayl::Cache::MemoryStore.new(clock => sub { $t });
    $store.increment('n', 1, expires-in => 5);
    $t = 4006;
    expect($store.increment('n', 1, expires-in => 5)).to.be(1);
  }
}

describe 'MVC::Keayl::Cache::Store multi', {
  let(:store, {
    my $s = MVC::Keayl::Cache::MemoryStore.new;
    $s.write-multi({ a => 1, b => 2 });
    $s
  });

  it 'reads only present keys', {
    expect(store.read-multi('a', 'b', 'c').keys.sort.join(',')).to.be('a,b');
  }

  it 'returns the stored values', {
    expect(store.read-multi('a', 'b')<a>).to.be(1);
  }
}

describe 'MVC::Keayl::Cache::Store delete-matched', {
  it 'removes the matching keys', {
    my $store = MVC::Keayl::Cache::MemoryStore.new;
    $store.write('rate/a', 1);
    $store.write('rate/b', 2);
    $store.write('other', 3);
    expect($store.delete-matched('rate*')).to.be(2);
  }

  it 'leaves the non-matching keys', {
    my $store = MVC::Keayl::Cache::MemoryStore.new;
    $store.write('rate/a', 1);
    $store.write('other', 3);
    $store.delete-matched('rate*');
    expect($store.entry-keys.join(',')).to.be('other');
  }

  it 'accepts a regex matcher', {
    my $store = MVC::Keayl::Cache::MemoryStore.new;
    $store.write('post/1', 'a');
    $store.write('post/2', 'b');
    $store.delete-matched(/^ 'post/'/);
    expect($store.entry-keys.elems).to.be(0);
  }
}

describe 'MVC::Keayl::Cache::MemoryStore bounds', {
  let(:store, {
    my $s = MVC::Keayl::Cache::MemoryStore.new(max-entries => 2);
    $s.write('a', 1);
    $s.write('b', 2);
    $s.read('a');
    $s.write('c', 3);
    $s
  });

  it 'evicts the least recently used entry', {
    expect(store.exist('b')).to.be-falsy;
  }

  it 'keeps a recently read entry', {
    expect(store.exist('a')).to.be-truthy;
  }

  it 'keeps the newest entry', {
    expect(store.exist('c')).to.be-truthy;
  }
}

describe 'MVC::Keayl::Cache::NullStore', {
  it 'never caches a fetched value', {
    my $store = MVC::Keayl::Cache::NullStore.new;
    my $calls = 0;
    $store.fetch('k', { $calls++; 'v' });
    $store.fetch('k', { $calls++; 'v' });
    expect($calls).to.be(2);
  }

  it 'reports nothing stored', {
    my $store = MVC::Keayl::Cache::NullStore.new;
    $store.write('k', 'v');
    expect($store.exist('k')).to.be-falsy;
  }
}

describe 'MVC::Keayl::Cache::FileStore', {
  it 'reads a written value', {
    my $root = temp-root;
    my $store = MVC::Keayl::Cache::FileStore.new(:$root);
    $store.write('frag/home', 'HELLO');
    my $read = $store.read('frag/home');
    .unlink for $root.dir;
    $root.rmdir;
    expect($read).to.be('HELLO');
  }

  it 'persists across instances', {
    my $root = temp-root;
    MVC::Keayl::Cache::FileStore.new(:$root).write('frag/home', 'HELLO');
    my $read = MVC::Keayl::Cache::FileStore.new(:$root).read('frag/home');
    .unlink for $root.dir;
    $root.rmdir;
    expect($read).to.be('HELLO');
  }

  it 'honours expiry', {
    my $root = temp-root;
    my $t = 5000;
    my $store = MVC::Keayl::Cache::FileStore.new(:$root, clock => sub { $t });
    $store.write('k', 'v', expires-in => 100);
    $t = 5200;
    my $read = $store.read('k');
    .unlink for $root.dir;
    $root.rmdir;
    expect($read.defined).to.be-falsy;
  }

  it 'deletes matching keys', {
    my $root = temp-root;
    my $store = MVC::Keayl::Cache::FileStore.new(:$root);
    $store.write('a/1', 'one');
    $store.write('a/2', 'two');
    $store.write('b/1', 'three');
    my $deleted = $store.delete-matched('a*');
    .unlink for $root.dir;
    $root.rmdir;
    expect($deleted).to.be(2);
  }
}

class FakeCacheClient {
  has %.data;
  method get($key)                { %!data{$key}:exists ?? %!data{$key}<value> !! Nil }
  method set($key, $value, :$ttl) { %!data{$key} = { :$value, :$ttl } }
  method del($key)                { %!data{$key}:delete }
  method keys()                   { %!data.keys }
}

describe 'MVC::Keayl::Cache::ExternalStore', {
  it 'round-trips through the client', {
    my $store = MVC::Keayl::Cache::ExternalStore.new(client => FakeCacheClient.new);
    $store.write('x', 'X');
    expect($store.read('x')).to.be('X');
  }

  it 'passes a ttl to the client', {
    my $client = FakeCacheClient.new;
    my $store = MVC::Keayl::Cache::ExternalStore.new(:$client, clock => sub { 6000 });
    $store.write('x', 'X', expires-in => 30);
    expect($client.data<x><ttl>).to.be(30);
  }

  it 'increments through the client', {
    my $store = MVC::Keayl::Cache::ExternalStore.new(client => FakeCacheClient.new);
    expect($store.increment('n', 1)).to.be(1);
  }
}
