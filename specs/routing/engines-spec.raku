use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Engine;
use MVC::Keayl::Dispatcher;
use MVC::Keayl::Router;
use MVC::Keayl::Routing;
use MVC::Keayl::Controller;
use MVC::Keayl::View;
use MVC::Keayl::Request;

class EngineSpecBlog::PostsController is MVC::Keayl::Controller {
  method index { self.render(plain => 'blog posts') }
  method show  { self.render(plain => 'blog post ' ~ self.params<id>) }
}

class EngineSpecHostController is MVC::Keayl::Controller {
  method controller-path(--> Str) { 'host' }
  method home     { self.render(plain => 'host home') }
  method override { self.render(plain => 'host override') }
}

sub blog-engine {
  MVC::Keayl::Engine.new(
    namespace    => 'EngineSpecBlog',
    controllers  => [EngineSpecBlog::PostsController],
    view-paths   => ['engines/blog/app/views'],
    routes-block => {
      get '/posts',     to => 'posts#index';
      get '/posts/:id', to => 'posts#show';
    },
  )
}

sub request($method, $path) {
  MVC::Keayl::Request.new(:$method, :$path)
}

describe 'isolate-namespace', {
  it 'resolves a short controller name within the namespace', {
    expect(blog-engine.controller-resolver()('posts') === EngineSpecBlog::PostsController).to.be-truthy;
  }

  it 'resolves the full controller path', {
    expect(blog-engine.controller-resolver()('engine_spec_blog/posts') === EngineSpecBlog::PostsController).to.be-truthy;
  }

  it 'resolves an unknown controller to nothing', {
    expect(blog-engine.controller-resolver()('missing') =:= Mu).to.be-truthy;
  }

  it 'can be set after construction', {
    my $engine = MVC::Keayl::Engine.new(controllers => [], routes-block => sub { });
    $engine.isolate-namespace('EngineSpecBlog');
    expect($engine.namespace-path).to.be('engine_spec_blog');
  }
}

describe 'the engine router', {
  it 'recognizes its own routes with params', {
    expect(blog-engine.router.recognize('GET', '/posts/5').params<id>).to.be('5');
  }
}

describe 'the engine endpoint', {
  it 'dispatches to a namespaced controller', {
    expect(blog-engine.endpoint.call(request('GET', '/posts')).body).to.be('blog posts');
  }

  it 'passes route params through', {
    expect(blog-engine.endpoint.call(request('GET', '/posts/7')).body).to.be('blog post 7');
  }
}

describe 'mounting an engine', {
  let(:host, {
    my $engine = blog-engine;
    my $router = routes {
      get '/', to => 'host#home';
      mount $engine.endpoint, at => '/blog';
    };
    MVC::Keayl::Dispatcher.new(:$router, controllers => [EngineSpecHostController])
  });

  it 'serves host routes', {
    expect(host.call(request('GET', '/')).body).to.be('host home');
  }

  it 'reaches the engine below the mount point', {
    expect(host.call(request('GET', '/blog/posts')).body).to.be('blog posts');
  }

  it 'survives the rebase with params', {
    expect(host.call(request('GET', '/blog/posts/3')).body).to.be('blog post 3');
  }
}

describe 'host overrides', {
  let(:host, {
    my $engine = blog-engine;
    my $router = routes {
      get '/blog/posts', to => 'host#override';
      mount $engine.endpoint, at => '/blog';
    };
    MVC::Keayl::Dispatcher.new(:$router, controllers => [EngineSpecHostController])
  });

  it 'lets a host route declared before the mount override the engine', {
    expect(host.call(request('GET', '/blog/posts')).body).to.be('host override');
  }

  it 'still falls through to the engine for unmatched host paths', {
    expect(host.call(request('GET', '/blog/posts/9')).body).to.be('blog post 9');
  }
}

describe 'view path contribution', {
  it 'puts host override paths before the engine paths', {
    my $endpoint = blog-engine.endpoint(view-path-overrides => ['app/views/blog']);
    expect($endpoint.controller-options<view-renderer>.paths).to.be(['app/views/blog', 'engines/blog/app/views']);
  }

  it 'exposes the engine view paths', {
    expect(blog-engine.view-paths).to.be(['engines/blog/app/views']);
  }

  it 'can append view paths', {
    my $engine = blog-engine;
    $engine.append-view-paths('engines/blog/extra/views');
    expect($engine.view-paths.tail).to.be('engines/blog/extra/views');
  }
}

describe 'initializers', {
  it 'run each registered initializer in order', {
    my @ran;
    my $engine = MVC::Keayl::Engine.new(controllers => [], routes-block => sub { });
    $engine.initializer('seed-cache', -> $e { @ran.push('seed-cache') });
    $engine.initializer('warm-pool', -> $e { @ran.push('warm-pool') });
    $engine.run-initializers;
    expect(@ran).to.be(['seed-cache', 'warm-pool']);
  }
}
