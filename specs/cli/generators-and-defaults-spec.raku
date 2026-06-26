use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::CLI;
use MVC::Keayl::HealthController;
use MVC::Keayl::PWAController;
use MVC::Keayl::Dispatcher;
use MVC::Keayl::Routing;
use MVC::Keayl::Request;
use MVC::Keayl::TestSupport;
use JSON::Fast;
use CLIFixtures;

sub silent { StringSink.new }

describe 'the mailer generator', {
  let(:root, {
    my $dir = temp-dir('spec-gen-mailer');
    generate-mailer('user', ['welcome'], root => $dir, out => silent);
    $dir
  });

  it 'subclasses the framework mailer with the action', {
    my $source = root().add('app/mailers/UserMailer.rakumod').slurp;
    expect($source.contains('unit class UserMailer is MVC::Keayl::Mailer') && $source.contains('method welcome')).to.be-truthy;
  }

  it 'generates the html and text views', {
    expect(root().add('app/views/user_mailer/welcome.html.haml').e && root().add('app/views/user_mailer/welcome.text.haml').e).to.be-truthy;
  }

  it 'generates a test and a spec file', {
    expect(root().add('t/mailers/user.rakutest').e && root().add('specs/mailers/user-spec.raku').e).to.be-truthy;
  }
}

describe 'the job generator', {
  it 'subclasses the framework job', {
    my $dir = temp-dir('spec-gen-job');
    generate-job('cleanup', root => $dir, out => silent);
    expect($dir.add('app/jobs/CleanupJob.rakumod').slurp.contains('unit class CleanupJob is MVC::Keayl::Job')).to.be-truthy;
  }
}

describe 'the channel generator', {
  it 'subclasses the framework channel', {
    my $dir = temp-dir('spec-gen-channel');
    generate-channel('chat', root => $dir, out => silent);
    expect($dir.add('app/channels/ChatChannel.rakumod').slurp.contains('unit class ChatChannel is MVC::Keayl::Cable::Channel')).to.be-truthy;
  }
}

describe 'the helper generator', {
  it 'creates a helper module', {
    my $dir = temp-dir('spec-gen-helper');
    generate-helper('posts', root => $dir, out => silent);
    expect($dir.add('app/helpers/PostsHelper.rakumod').slurp.contains('unit module PostsHelper')).to.be-truthy;
  }
}

describe 'the model generator', {
  let(:root, {
    my $dir = temp-dir('spec-gen-model');
    generate-model('post', ['title:string', 'body:text'], root => $dir, timestamp => '20260101000000', out => silent);
    $dir
  });

  it 'delegates the model to ORM::ActiveRecord', {
    expect(root().add('app/models/Post.rakumod').slurp.contains('unit class Post is Model')).to.be-truthy;
  }

  it 'generates an ORM migration with typed columns', {
    my $migration = root().add('db/migrate/20260101000000-create-posts.raku').slurp;
    expect($migration.contains('class CreatePosts is Migration') && $migration.contains('title => { :string }') && $migration.contains('body => { :text }')).to.be-truthy;
  }
}

describe 'the resource generator', {
  let(:root, {
    my $dir = temp-dir('spec-gen-resource');
    base-routes-file($dir);
    generate-resource('post', ['title:string'], root => $dir, out => silent, err => silent);
    $dir
  });

  it 'generates a model and a controller', {
    expect(root().add('app/models/Post.rakumod').e && root().add('app/controllers/PostsController.rakumod').e).to.be-truthy;
  }

  it 'adds a resources route', {
    expect(root().add('config/routes.raku').slurp.contains("resources 'posts'")).to.be-truthy;
  }
}

describe 'the health-check endpoint', {
  it 'returns a green 200 page', {
    my $response = MVC::Keayl::HealthController.new.dispatch('show');
    expect($response.status == 200 && $response.body.contains('background-color: green')).to.be-truthy;
  }
}

describe 'the pwa controller', {
  it 'serves a manifest document', {
    my $response = MVC::Keayl::PWAController.new.dispatch('manifest');
    expect($response.header('content-type') eq 'application/manifest+json' && from-json($response.body)<start_url> eq '/').to.be-truthy;
  }

  it 'serves a javascript service worker', {
    my $response = MVC::Keayl::PWAController.new.dispatch('service-worker');
    expect($response.header('content-type') eq 'text/javascript' && $response.body.contains('addEventListener')).to.be-truthy;
  }
}

describe 'the default routes', {
  let(:dispatcher, {
    my $router = routes {
      get '/up', to => 'health#show';
      get '/manifest.json', to => 'pwa#manifest';
    };
    MVC::Keayl::Dispatcher.new(:$router, controllers => [MVC::Keayl::HealthController, MVC::Keayl::PWAController])
  });

  it 'route /up to the health controller', {
    expect(dispatcher().call(MVC::Keayl::Request.new(method => 'GET', path => '/up')).status).to.be(200);
  }

  it 'route /manifest.json to the pwa controller', {
    expect(dispatcher().call(MVC::Keayl::Request.new(method => 'GET', path => '/manifest.json')).header('content-type')).to.be('application/manifest+json');
  }
}

describe 'a new application', {
  let(:root, {
    my $dir = temp-dir('spec-new-defaults');
    scaffold-app('blog', into => $dir);
    $dir
  });

  it 'ships public exception pages', {
    expect(root().add('blog/public/404.html').e && root().add('blog/public/422.html').e && root().add('blog/public/500.html').e).to.be-truthy;
  }

  it 'wires the health-check and service-worker routes', {
    my $routes = root().add('blog/config/routes.raku').slurp;
    expect($routes.contains("get '/up'") && $routes.contains('service-worker')).to.be-truthy;
  }

  it 'ships executable server, dev, and test scripts', {
    aggregate-failures {
      expect(root().add('blog/bin/server').mode.substr(*-3)).to.be('755');
      expect(root().add('blog/bin/dev').mode.substr(*-3)).to.be('755');
      expect(root().add('blog/bin/test').mode.substr(*-3)).to.be('755');
    }
  }

  it 'ships an application layout', {
    expect(root().add('blog/app/views/layouts/application.html.haml').e).to.be-truthy;
  }

  it 'ships starter assets and keeps the tmp directory', {
    expect(root().add('blog/assets/favicon.svg').e && root().add('blog/assets/css/style.css').e && root().add('blog/tmp/.keep').e).to.be-truthy;
  }

  it 'keeps the models directory', {
    expect(root().add('blog/app/models/.keep').e).to.be-truthy;
  }

  it 'wires static asset serving into the application', {
    expect(root().add('blog/config/application.raku').slurp.contains('MVC::Keayl::Middleware::Static')).to.be-truthy;
  }

  it 'names the camelized app in a META6 that depends on the framework', {
    my $meta = root().add('blog/META6.json').slurp;
    expect($meta.contains('"name": "Blog"') && $meta.contains('MVC::Keayl') && $meta.contains('ORM::ActiveRecord')).to.be-truthy;
  }

  it 'test-depends on the browser harness', {
    expect(root().add('blog/META6.json').slurp.contains('BDD::Behave::Playwright')).to.be-truthy;
  }

  it 'ships a browser spec for the home page', {
    expect(root().add('blog/specs/home-spec.raku').slurp.contains('playwright-page')).to.be-truthy;
  }
}

describe 'a scaffolded home page rendered through the stack', {
  let(:response, {
    my $dir = temp-dir('spec-new-renders').resolve;
    scaffold-app('blog', into => $dir);

    my $cwd = $*CWD;
    chdir $dir.add('blog');

    my $session = IntegrationSession.new(app => load-application('config/application.raku').endpoint);
    $session.get('/');

    chdir $cwd;
    $session.response
  });

  it 'responds with a 200', {
    expect(response.status).to.be(200);
  }

  it 'renders through the application layout', {
    expect(response.body.contains('<!DOCTYPE html>')).to.be-truthy;
  }

  it 'shows the welcome heading', {
    expect(response.body.contains('Welcome to blog')).to.be-truthy;
  }

  it 'uses the assigned page title', {
    expect(response.body.contains('<title>blog</title>')).to.be-truthy;
  }
}
