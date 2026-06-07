use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Controller;
use MVC::Keayl::Response;
use MVC::Keayl::Cache;
use MVC::Keayl::View;

describe 'MVC::Keayl::Controller cache headers', {
  it 'sets a private max-age with expires-in', {
    my class TtlController is MVC::Keayl::Controller {
      method show { self.expires-in(3600); self.render(:plain('x')) }
    }
    expect(TtlController.new.dispatch('show').header('Cache-Control')).to.be('private, max-age=3600');
  }

  it 'honours public and extra directives', {
    my class PublicTtlController is MVC::Keayl::Controller {
      method show { self.expires-in(60, public => True, must-revalidate => True); self.render(:plain('x')) }
    }
    expect(PublicTtlController.new.dispatch('show').header('Cache-Control')).to.be('public, max-age=60, must-revalidate');
  }

  it 'sets no-cache with expires-now', {
    my class NoCacheController is MVC::Keayl::Controller {
      method show { self.expires-now; self.render(:plain('x')) }
    }
    expect(NoCacheController.new.dispatch('show').header('Cache-Control')).to.be('no-cache');
  }

  it 'can set no-store', {
    my class NoStoreController is MVC::Keayl::Controller {
      method show { self.expires-now(no-store => True); self.render(:plain('x')) }
    }
    expect(NoStoreController.new.dispatch('show').header('Cache-Control')).to.be('no-store');
  }
}

describe 'MVC::Keayl::Cache key derivation', {
  it 'joins parts under views', {
    expect(cache-key('home', 'sidebar')).to.be('views/home/sidebar');
  }

  it 'appends a digest', {
    expect(cache-key('home', digest => 'abc123')).to.be('views/home/abc123');
  }

  it 'uses an object cache key', {
    my class CacheModel { method cache-key { 'posts/1-2021' } }
    expect(cache-key(CacheModel.new)).to.be('views/posts/1-2021');
  }
}

describe 'MVC::Keayl::Cache::MemoryStore', {
  it 'computes once and caches the result', {
    my $store = MVC::Keayl::Cache::MemoryStore.new;
    my $calls = 0;
    $store.fetch('k', { $calls++; 'value' });
    $store.fetch('k', { $calls++; 'value' });
    expect($calls).to.be(1);
  }

  it 'returns the produced value', {
    expect(MVC::Keayl::Cache::MemoryStore.new.fetch('k', { 'computed' })).to.be('computed');
  }
}

describe 'MVC::Keayl::View fragment caching', {
  it 'produces a fragment once', {
    my $view  = MVC::Keayl::View.new(:paths(['specs/lib/views']));
    my $calls = 0;
    $view.cache-fragment(['home'], { $calls++; 'fragment' });
    $view.cache-fragment(['home'], { $calls++; 'fragment' });
    expect($calls).to.be(1);
  }

  it 'returns the produced content', {
    my $view = MVC::Keayl::View.new(:paths(['specs/lib/views']));
    expect($view.cache-fragment(['home'], { 'fragment' })).to.be('fragment');
  }
}

describe 'MVC::Keayl::Response streaming', {
  it 'reports streaming when a stream source is set', {
    my $response = MVC::Keayl::Response.new;
    $response.stream(('a', 'b', 'c'));
    expect($response.is-streaming).to.be-truthy;
  }

  it 'materializes stream chunks into the body', {
    my $response = MVC::Keayl::Response.new;
    $response.stream(('a', 'b', 'c'));
    expect($response.stream-chunks.map(*.decode('utf-8')).join).to.be('abc');
  }

  it 'yields each chunk of a streamed sequence', {
    my $response = MVC::Keayl::Response.new;
    $response.stream((1, 2, 3).map(* x 2));
    expect($response.stream-chunks.elems).to.be(3);
  }
}
