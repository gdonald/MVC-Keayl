use BDD::Behave;
use Template::HAML::Config;
use MVC::Keayl::View::Context;
use MVC::Keayl::View::Handler::HAML;
use ViewFixtures;

constant HELPER-TEMPLATE = "%p= shout('hi')\n";

describe 'MVC::Keayl::View::Handler::HAML', {
  let(:handler, { MVC::Keayl::View::Handler::HAML.new });
  let(:helpers, { %( shout => -> $text { $text.uc } ) });
  let(:helper-context, { MVC::Keayl::View::Context.new(helpers => helpers) });

  it 'renders a compiled template', {
    expect(handler.render(handler.compile("%p hi\n"), {})).to.be("<p>hi</p>\n");
  }

  it 'renders a compiled template that calls a helper from the context', {
    expect(handler.render(handler.compile(HELPER-TEMPLATE), {}, context => helper-context)).to.be("<p>HI</p>\n");
  }

  context 'compiling with the helper names a render will use', {
    let(:compiled, { handler.compile(HELPER-TEMPLATE, helper-names => ["shout", "whisper"]) });

    before-each { compiled }

    it 'evaluates no code when rendering with a context whose helpers those names cover', {
      expect(evaluations({ handler.render(compiled, {}, context => helper-context) })).to.be(0);
    }
  }

  context 'compiling without helper names', {
    let(:compiled, { handler.compile(HELPER-TEMPLATE) });

    it 'evaluates no code while compiling', {
      expect(evaluations({ compiled })).to.be(0);
    }

    context 'after the first render', {
      before-each { handler.render(compiled, {}, context => helper-context) }

      it 'evaluates no code on a second render with the same helpers', {
        expect(evaluations({ handler.render(compiled, {}, context => helper-context) })).to.be(0);
      }
    }
  }

  context 'compiling the same source twice', {
    it 'evaluates the template once', {
      expect(evaluations({
        handler.compile(HELPER-TEMPLATE, helper-names => ["shout"]);
        handler.compile(HELPER-TEMPLATE, helper-names => ["shout"]);
      })).to.be(1);
    }
  }

  context 'with a config that emits an abstract syntax tree', {
    let(:config, { Template::HAML::Config.new(emit => 'ast') });
    let(:ast-handler, { MVC::Keayl::View::Handler::HAML.new(config => config) });

    it 'compiles a template to its source', {
      expect(ast-handler.compile("%p hi\n")).to.be("%p hi\n");
    }

    it 'renders a template without a context', {
      expect(ast-handler.render(ast-handler.compile("%p hi\n"), {})).to.be("<p>hi</p>\n");
    }

    it 'renders a template that calls a helper from the context', {
      expect(ast-handler.render(ast-handler.compile(HELPER-TEMPLATE), {}, context => helper-context)).to.be("<p>HI</p>\n");
    }
  }
}
