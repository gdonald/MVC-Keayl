use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::CLI;
use MVC::Keayl::Controller;
use MVC::Keayl::Routing;
use Template::HAML;
use CLIFixtures;

class Row { has $.id }

describe 'MVC::Keayl::CLI inflection', {
  it 'camelizes a single word', {
    expect(camelize('posts')).to.be('Posts');
  }

  it 'camelizes hyphenated words', {
    expect(camelize('blog-posts')).to.be('BlogPosts');
  }

  it 'camelizes underscored words', {
    expect(camelize('blog_posts')).to.be('BlogPosts');
  }

  it 'pluralizes by adding s', {
    expect(pluralize('post')).to.be('posts');
  }

  it 'pluralizes a consonant-y into ies', {
    expect(pluralize('category')).to.be('categories');
  }

  it 'pluralizes by adding es after x', {
    expect(pluralize('box')).to.be('boxes');
  }

  it 'singularizes by stripping a trailing s', {
    expect(singularize('posts')).to.be('post');
  }

  it 'singularizes ies into y', {
    expect(singularize('categories')).to.be('category');
  }

  it 'singularizes by stripping es after x', {
    expect(singularize('boxes')).to.be('box');
  }

  it 'builds a controller class name from the name', {
    expect(controller-class-name('posts')).to.be('PostsController');
  }
}

describe 'MVC::Keayl::CLI controller generator', {
  context 'into an application with a routes file', {
    let(:dir, { temp-dir('spec-gen-controller') });

    before-each {
      base-routes-file(dir);
      generate-controller('posts', ['index', 'show'], root => dir, out => StringSink.new, err => StringSink.new);
    }

    it 'creates the controller file', {
      expect(dir.add('app/controllers/PostsController.rakumod').e).to.be-truthy;
    }

    it 'subclasses the framework controller', {
      expect(dir.add('app/controllers/PostsController.rakumod').slurp.contains('unit class PostsController is MVC::Keayl::Controller')).to.be-truthy;
    }

    it 'defines a method for the first action', {
      expect(dir.add('app/controllers/PostsController.rakumod').slurp.contains('method index')).to.be-truthy;
    }

    it 'defines a method for the second action', {
      expect(dir.add('app/controllers/PostsController.rakumod').slurp.contains('method show')).to.be-truthy;
    }

    it 'creates a view for the first action', {
      expect(dir.add('app/views/posts/index.html.haml').e).to.be-truthy;
    }

    it 'creates a view for the second action', {
      expect(dir.add('app/views/posts/show.html.haml').e).to.be-truthy;
    }

    it 'inserts a route stub for the action', {
      expect(dir.add('config/routes.raku').slurp.contains("get '/posts/index'")).to.be-truthy;
    }
  }

  it 'returns success', {
    my $dir = temp-dir('spec-gen-controller-rc');
    base-routes-file($dir);
    expect(generate-controller('posts', ['index'], root => $dir, out => StringSink.new, err => StringSink.new)).to.be(0);
  }

  it 'inserts a route the router recognizes', {
    my $dir = temp-dir('spec-gen-controller-loadable');
    base-routes-file($dir);
    generate-controller('posts', ['index'], root => $dir, out => StringSink.new, err => StringSink.new);
    my @table = load-routes($dir.add('config/routes.raku')).route-table;
    expect(@table.first(*<path> eq '/posts/index')<target>).to.be('posts#index');
  }

  it 'generates a controller that compiles', {
    my $dir = temp-dir('spec-gen-controller-compiles');
    base-routes-file($dir);
    generate-controller('widgets', ['index', 'edit'], root => $dir, out => StringSink.new, err => StringSink.new);
    expect((EVALFILE $dir.add('app/controllers/WidgetsController.rakumod')).^name.contains('WidgetsController')).to.be-truthy;
  }

  context 'without a routes file', {
    let(:dir, { temp-dir('spec-gen-controller-noroutes') });
    let(:err, { StringSink.new });

    it 'still succeeds', {
      expect(generate-controller('posts', ['index'], root => dir, out => StringSink.new, err => err)).to.be(0);
    }

    it 'still creates the controller', {
      generate-controller('posts', ['index'], root => dir, out => StringSink.new, err => err);
      expect(dir.add('app/controllers/PostsController.rakumod').e).to.be-truthy;
    }
  }

  it 'reports an existing file rather than overwriting it', {
    my $dir = temp-dir('spec-gen-idempotent');
    base-routes-file($dir);
    generate-controller('posts', ['index'], root => $dir, out => StringSink.new, err => StringSink.new);
    my $out = StringSink.new;
    generate-controller('posts', ['index'], root => $dir, :$out, err => StringSink.new);
    expect($out.text.contains('exists')).to.be-truthy;
  }
}

describe 'MVC::Keayl::CLI scaffold generator', {
  context 'a scaffolded resource', {
    let(:dir, { temp-dir('spec-gen-scaffold') });

    before-each {
      base-routes-file(dir);
      generate-scaffold('post', root => dir, out => StringSink.new, err => StringSink.new);
    }

    it 'generates an ActiveRecord model', {
      expect(dir.add('app/models/Post.rakumod').slurp.contains('unit class Post is Model')).to.be-truthy;
    }

    it 'generates a controller with an index action', {
      expect(dir.add('app/controllers/PostsController.rakumod').slurp.contains('method index')).to.be-truthy;
    }

    it 'generates a controller with a destroy action', {
      expect(dir.add('app/controllers/PostsController.rakumod').slurp.contains('method destroy')).to.be-truthy;
    }

    it 'creates the index view', {
      expect(dir.add('app/views/posts/index.html.haml').e).to.be-truthy;
    }

    it 'creates the show view', {
      expect(dir.add('app/views/posts/show.html.haml').e).to.be-truthy;
    }

    it 'creates the new view', {
      expect(dir.add('app/views/posts/new.html.haml').e).to.be-truthy;
    }

    it 'creates the edit view', {
      expect(dir.add('app/views/posts/edit.html.haml').e).to.be-truthy;
    }

    it 'creates the form partial', {
      expect(dir.add('app/views/posts/_form.html.haml').e).to.be-truthy;
    }

    it 'inserts a resource route', {
      expect(dir.add('config/routes.raku').slurp.contains("resources 'posts'")).to.be-truthy;
    }

    it 'expands the resource route to the index action', {
      my @table = load-routes(dir.add('config/routes.raku')).route-table;
      expect(@table.grep(*<target> eq 'posts#index').elems > 0).to.be-truthy;
    }
  }

  context 'with a singular argument that pluralizes', {
    let(:dir, { temp-dir('spec-gen-scaffold-plural') });

    before-each {
      base-routes-file(dir);
      generate-scaffold('category', root => dir, out => StringSink.new, err => StringSink.new);
    }

    it 'pluralizes the controller name', {
      expect(dir.add('app/controllers/CategoriesController.rakumod').e).to.be-truthy;
    }

    it 'pluralizes the resource route', {
      expect(dir.add('config/routes.raku').slurp.contains("resources 'categories'")).to.be-truthy;
    }
  }
}

describe 'MVC::Keayl::CLI generated views', {
  it 'renders a controller view to HTML', {
    my $dir = temp-dir('spec-gen-view-render');
    base-routes-file($dir);
    generate-controller('posts', ['index'], root => $dir, out => StringSink.new, err => StringSink.new);
    expect(HAML.render(:src($dir.add('app/views/posts/index.html.haml').slurp)).contains('<h1>')).to.be-truthy;
  }

  it 'renders a scaffold index view with its collection', {
    my $dir = temp-dir('spec-gen-scaffold-render');
    base-routes-file($dir);
    generate-scaffold('post', root => $dir, out => StringSink.new, err => StringSink.new);
    my $html = HAML.render(:src($dir.add('app/views/posts/index.html.haml').slurp), :locals(%( posts => [Row.new(id => 7)] )));
    expect($html.contains('7')).to.be-truthy;
  }

  it 'renders a scaffold form partial to HTML', {
    my $dir = temp-dir('spec-gen-form-render');
    base-routes-file($dir);
    generate-scaffold('post', root => $dir, out => StringSink.new, err => StringSink.new);
    expect(HAML.render(:src($dir.add('app/views/posts/_form.html.haml').slurp)).contains('<form')).to.be-truthy;
  }
}
