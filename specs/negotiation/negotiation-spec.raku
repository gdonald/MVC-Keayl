use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Controller;
use MVC::Keayl::APIController;
use MVC::Keayl::Request;

class Article {
  has $.title;
  method to-hash { %( title => $!title ) }
}

class NegotiatingController is MVC::Keayl::Controller {
  method show {
    self.respond-to([
      html => { self.render(:html('<h1>Post</h1>')) },
      json => { self.render(:json({ ok => True })) },
    ])
  }
}

class PostsAPIController is MVC::Keayl::APIController {
  method show      { self.render(Article.new(title => 'Hi')) }
  method index     { self.render([ Article.new(title => 'A'), Article.new(title => 'B') ]) }
  method made      { self.render(Article.new(title => 'New'), :status(201)) }
  method plain-ish { self.render(:plain('still text')) }
}

sub negotiating(*%request) {
  NegotiatingController.new(request => MVC::Keayl::Request.new(|%request)).dispatch('show')
}

describe 'MVC::Keayl::Controller respond-to', {
  it 'dispatches to the JSON block for a JSON Accept header', {
    expect(negotiating(method => 'GET', path => '/posts', headers => %( accept => 'application/json' )).body).to.be('{"ok":true}');
  }

  it 'dispatches to the HTML block for an HTML Accept header', {
    expect(negotiating(method => 'GET', path => '/posts', headers => %( accept => 'text/html' )).body).to.be('<h1>Post</h1>');
  }

  it 'lets a path extension override the Accept header', {
    expect(negotiating(method => 'GET', path => '/posts.json', headers => %( accept => 'text/html' )).body).to.be('{"ok":true}');
  }

  it 'uses the first declared format as the default', {
    expect(negotiating(method => 'GET', path => '/posts').body).to.be('<h1>Post</h1>');
  }

  it 'returns 406 for an unsupported Accept header', {
    expect(negotiating(method => 'GET', path => '/posts', headers => %( accept => 'application/xml' )).status).to.be(406);
  }

  it 'returns 406 for an unsupported path extension', {
    expect(negotiating(method => 'GET', path => '/posts.csv').status).to.be(406);
  }
}

describe 'MVC::Keayl::APIController rendering', {
  it 'renders a bare object as JSON', {
    expect(PostsAPIController.new.dispatch('show').body).to.be('{"title":"Hi"}');
  }

  it 'sets a JSON content type', {
    expect(PostsAPIController.new.dispatch('show').content-type).to.be('application/json');
  }

  it 'serializes a collection of objects', {
    expect(PostsAPIController.new.dispatch('index').body).to.be('[{"title":"A"},{"title":"B"}]');
  }

  it 'passes render options through', {
    expect(PostsAPIController.new.dispatch('made').status).to.be(201);
  }

  it 'does not coerce an explicit render option to JSON', {
    expect(PostsAPIController.new.dispatch('plain-ish').body).to.be('still text');
  }

  it 'uses a serializer hook to shape the JSON', {
    my class CustomController is MVC::Keayl::APIController {
      method show { self.render(Article.new(title => 'x')) }
    }
    my $response = CustomController.new(serializer => -> $value { %( custom => $value.title ) }).dispatch('show');
    expect($response.body).to.be('{"custom":"x"}');
  }
}
