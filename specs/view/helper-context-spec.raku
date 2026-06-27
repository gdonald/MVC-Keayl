use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::View;
use MVC::Keayl::View::Context;
use CLIFixtures;

describe 'helpers as bare view-context calls', {
  let(:view, {
    my $dir = temp-dir('spec-helper-context');
    write-file($dir.add('pages/show.html.haml'), "%p\n  != link-to('Home', '/')\n");
    write-file($dir.add('pages/dashed.html.haml'), "%span\n  = truncate('hello world', length => 5)\n");
    MVC::Keayl::View.new(paths => [$dir.Str])
  });

  it 'calls a built-in helper bare with arguments', {
    expect(view.render-template('pages/show', {}).contains('<a href="/">Home</a>')).to.be-truthy;
  }

  it 'resolves a dashed helper name with named arguments', {
    expect(view.render-template('pages/dashed', {}).contains('he...')).to.be-truthy;
  }
}

describe 'the view context', {
  it 'delegates a dashed method to its underscored helper closure', {
    my %helpers = greet => -> $name { "hi $name" };
    my $context = MVC::Keayl::View::Context.new(:%helpers);
    expect($context.greet('gd')).to.be('hi gd');
  }

  it 'reports its helper names for discovery', {
    my %helpers = 'link-to' => -> {}, 'number-to-currency' => -> {};
    my $context = MVC::Keayl::View::Context.new(:%helpers);
    expect($context.haml-helper-names.first('link-to').defined).to.be-truthy;
  }
}
