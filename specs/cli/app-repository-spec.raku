use BDD::Behave;
use MVC::Keayl::CLI;
use MVC::Keayl::Application;
use JSON::Fast;
use CLIFixtures;

sub app-root(Str:D $name --> IO::Path) {
  my $dir = temp-dir($name);
  write-file($dir.add('META6.json'), '{ "name": "Demo", "provides": {} }');
  $dir
}

sub provides(IO::Path:D $dir --> Hash) {
  from-json($dir.add('META6.json').slurp)<provides>
}

describe 'MVC::Keayl::CLI scaffold-app include path', {
  let(:app, {
    my $dir = temp-dir('spec-repo-new');
    scaffold-app('blog', into => $dir);
    $dir.add('blog')
  });

  it 'lists the home controller and the application helper in provides', {
    expect(provides(app)).to.eq(%(
      ApplicationHelper => 'app/helpers/ApplicationHelper.rakumod',
      HomeController    => 'app/controllers/HomeController.rakumod',
    ));
  }

  it 'adds no include path to the application file', {
    expect(app.add('config/application.raku').slurp.contains('use lib')).to.be-falsy;
  }

  it 'loads the app and the spec support directory in the behave config', {
    expect(app.add('.behave').slurp.contains("\$c.lib('.', 'specs/support')")).to.be-truthy;
  }

  it 'keeps the spec support directory', {
    expect(app.add('specs/support/.keep').e).to.be-truthy;
  }

  it 'starts the server script with the app root on the include path', {
    expect(app.add('bin/server').lines[0]).to.be('#!/usr/bin/env -S raku -I.');
  }

  it 'starts the dev script server with the app root on the include path', {
    expect(app.add('bin/dev').slurp.contains('exec raku -I. bin/server')).to.be-truthy;
  }
}

describe 'MVC::Keayl::CLI load-application include path', {
  let(:root, {
    my $dir = temp-dir('spec-repo-load-twice').resolve;
    scaffold-app('blog', into => $dir);
    $dir.add('blog')
  });

  let(:reloaded, {
    my $cwd = $*CWD;
    chdir root;

    load-application('config/application.raku');
    my $app = load-application('config/application.raku');

    chdir $cwd;
    $app
  });

  it 'loads an application again from the same root', {
    expect(reloaded() ~~ MVC::Keayl::Application).to.be-truthy;
  }

  it 'puts the application root on the include path once', {
    reloaded;

    my @matching = $*REPO.repo-chain.grep({
      $_ ~~ CompUnit::Repository::FileSystem && .prefix.resolve.absolute eq root.absolute
    });

    expect(@matching.elems).to.be(1);
  }
}

describe 'MVC::Keayl::CLI model generator include path', {
  let(:dir, { app-root('spec-repo-model') });

  before-each {
    generate-model('widget', ['name:string'], root => dir, timestamp => '20260101000000', out => StringSink.new);
  }

  it 'adds the model to provides', {
    expect(provides(dir)<Widget>).to.be('app/models/Widget.rakumod');
  }

  it 'writes a test that adds no include path', {
    expect(dir.add('t/models/widget.rakutest').slurp.contains('use lib')).to.be-falsy;
  }

  it 'writes a spec that adds no include path', {
    expect(dir.add('specs/models/widget-spec.raku').slurp.contains('use lib')).to.be-falsy;
  }
}

describe 'MVC::Keayl::CLI controller generator include path', {
  let(:dir, { app-root('spec-repo-controller') });

  before-each {
    generate-controller('posts', ['index'], root => dir, out => StringSink.new, err => StringSink.new);
  }

  it 'adds the controller to provides', {
    expect(provides(dir)<PostsController>).to.be('app/controllers/PostsController.rakumod');
  }

  it 'adds its helper to provides', {
    expect(provides(dir)<PostsHelper>).to.be('app/helpers/PostsHelper.rakumod');
  }
}

describe 'MVC::Keayl::CLI component generators include path', {
  let(:dir, { app-root('spec-repo-components') });

  before-each {
    generate-mailer('user', ['welcome'], root => dir, out => StringSink.new);
    generate-job('cleanup', root => dir, out => StringSink.new);
    generate-channel('chat', root => dir, out => StringSink.new);
    generate-helper('tags', root => dir, out => StringSink.new);
  }

  it 'adds the mailer to provides', {
    expect(provides(dir)<UserMailer>).to.be('app/mailers/UserMailer.rakumod');
  }

  it 'adds the job to provides', {
    expect(provides(dir)<CleanupJob>).to.be('app/jobs/CleanupJob.rakumod');
  }

  it 'adds the channel to provides', {
    expect(provides(dir)<ChatChannel>).to.be('app/channels/ChatChannel.rakumod');
  }

  it 'adds the helper to provides', {
    expect(provides(dir)<TagsHelper>).to.be('app/helpers/TagsHelper.rakumod');
  }
}

describe 'MVC::Keayl::CLI resource generator include path', {
  let(:dir, { app-root('spec-repo-resource') });

  before-each {
    base-routes-file(dir);
    generate-resource('post', ['title:string'], root => dir, out => StringSink.new, err => StringSink.new);
  }

  it 'adds the model to provides', {
    expect(provides(dir)<Post>).to.be('app/models/Post.rakumod');
  }

  it 'adds the controller to provides', {
    expect(provides(dir)<PostsController>).to.be('app/controllers/PostsController.rakumod');
  }
}

describe 'MVC::Keayl::CLI scaffold generator include path', {
  let(:dir, { app-root('spec-repo-scaffold') });

  before-each {
    base-routes-file(dir);
    generate-scaffold('post', root => dir, out => StringSink.new, err => StringSink.new);
  }

  it 'adds the model to provides', {
    expect(provides(dir)<Post>).to.be('app/models/Post.rakumod');
  }

  it 'adds the controller to provides', {
    expect(provides(dir)<PostsController>).to.be('app/controllers/PostsController.rakumod');
  }

  it 'adds the helper to provides', {
    expect(provides(dir)<PostsHelper>).to.be('app/helpers/PostsHelper.rakumod');
  }
}

describe 'MVC::Keayl::CLI add-provides', {
  context 'with a META6 that has provides', {
    let(:dir, { app-root('spec-repo-add') });
    let(:out, { StringSink.new });

    it 'reports a new entry', {
      expect(add-provides(dir, 'Widget', 'app/models/Widget.rakumod', out => out)).to.be-truthy;
    }

    it 'prints the module it adds', {
      add-provides(dir, 'Widget', 'app/models/Widget.rakumod', out => out);
      expect(out.text.contains('provide Widget')).to.be-truthy;
    }

    context 'when the entry is already present', {
      before-each {
        add-provides(dir, 'Widget', 'app/models/Widget.rakumod', out => StringSink.new);
      }

      it 'skips the entry', {
        expect(add-provides(dir, 'Widget', 'app/models/Widget.rakumod', out => out)).to.be-falsy;
      }

      it 'keeps one entry per module', {
        add-provides(dir, 'Widget', 'app/models/Widget.rakumod', out => out);
        expect(provides(dir).elems).to.be(1);
      }
    }
  }

  context 'with a META6 that has no provides', {
    let(:dir, {
      my $dir = temp-dir('spec-repo-no-provides');
      write-file($dir.add('META6.json'), '{ "name": "Demo" }');
      $dir
    });

    it 'creates provides', {
      add-provides(dir, 'Widget', 'app/models/Widget.rakumod', out => StringSink.new);
      expect(provides(dir)<Widget>).to.be('app/models/Widget.rakumod');
    }
  }

  context 'without a META6', {
    let(:dir, { temp-dir('spec-repo-no-meta') });

    it 'does nothing', {
      expect(add-provides(dir, 'Widget', 'app/models/Widget.rakumod', out => StringSink.new)).to.be-falsy;
    }

    it 'writes no META6', {
      add-provides(dir, 'Widget', 'app/models/Widget.rakumod', out => StringSink.new);
      expect(dir.add('META6.json').e).to.be-falsy;
    }
  }
}
