use BDD::Behave;
use MVC::Keayl::View;
use MVC::Keayl::Controller;
use ViewFixtures;

class Reports::ChartController is MVC::Keayl::Controller { }

describe 'MVC::Keayl::View compile events', {
  let(:fixture, { compile-fixture('spec-compile-events') });
  let(:view, { MVC::Keayl::View.new(paths => [fixture()[0].Str], helper-paths => [fixture()[1].Str]) });
  let(:controller, { CompileController.new });

  it 'publishes a compile event for the template, its helper module, and the layout on the first render', {
    my @files = compiled-files({
      view.render-template('compile/show', {}, :controller(controller));
      view.render-layout('application', '<p>HI</p>', {}, :controller(controller));
    });

    expect(@files.List).to.be(<show.html.haml ApplicationHelper.rakumod application.html.haml>);
  }

  it 'publishes no compile event on a second render', {
    view.render-template('compile/show', {}, :controller(controller));

    expect(compiled-files({ view.render-template('compile/show', {}, :controller(controller)) }).elems).to.be(0);
  }
}

describe 'MVC::Keayl::View precompile', {
  let(:fixture, { compile-fixture('spec-precompile') });
  let(:view, { MVC::Keayl::View.new(paths => [fixture()[0].Str], helper-paths => [fixture()[1].Str]) });

  it 'compiles each template, layout, and helper module under its paths', {
    expect(compiled-files({ view.precompile }).sort.List).to.be(<ApplicationHelper.rakumod ChartHelper.rakumod application.html.haml show.html.haml>);
  }

  context 'after precompiling', {
    let(:controller, { CompileController.new });
    let(:chart-controller, { Reports::ChartController.new });

    before-each { view.precompile }

    it 'renders a template and its layout without compiling', {
      my @files = compiled-files({
        view.render-template('compile/show', {}, :controller(controller));
        view.render-layout('application', '<p>HI</p>', {}, :controller(controller));
      });

      expect(@files.elems).to.be(0);
    }

    it 'loads a helper module in a subdirectory under its namespaced name', {
      expect(compiled-files({ view.build-context(:controller(chart-controller)) }).elems).to.be(0);
    }
  }

  context 'with a registered handler', {
    let(:handler, { SlowCountingHandler.new });

    it 'compiles the templates that handler renders', {
      view.register-handler('count', handler);
      view.precompile;

      expect(handler.compiles).to.be(1);
    }
  }

  context 'with a helper loader', {
    let(:loader-view, { MVC::Keayl::View.new(paths => [fixture()[0].Str], helper-paths => [fixture()[1].Str], helper-loader => -> $module { %() }) });

    it 'compiles the templates and leaves helper modules to the loader', {
      expect(compiled-files({ loader-view.precompile }).sort.List).to.be(<application.html.haml show.html.haml>);
    }
  }
}

describe 'MVC::Keayl::View concurrent compiles', {
  let(:fixture, { compile-fixture('spec-concurrent-compile') });
  let(:view, { MVC::Keayl::View.new(paths => [fixture()[0].Str]) });

  context 'two renders that miss the cache at the same time', {
    let(:handler, { SlowCountingHandler.new });

    it 'compiles the template once', {
      view.register-handler('count', handler);
      await (start { view.render-template('compile/report', {}) }) xx 2;

      expect(handler.compiles).to.be(1);
    }
  }

  context 'a compile that fails', {
    let(:handler, { FailOnceHandler.new });

    before-each { view.register-handler('count', handler) }

    it 'raises the compile error from the render', {
      expect({ view.render-template('compile/report', {}) }).to.throw;
    }

    it 'compiles again on the next render', {
      try view.render-template('compile/report', {});

      expect(view.render-template('compile/report', {})).to.be('REPORT');
    }
  }
}
