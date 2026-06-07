use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Caching;
use MVC::Keayl::Controller;
use MVC::Keayl::Request;

class CachedRecord {
  has $.cache-key;
}

class ConditionalController is MVC::Keayl::Controller {
  has $.tag = 'abc';
  method show {
    self.render(:plain('rendered')) if self.is-stale(etag => $!tag);
  }
}

sub showing(*%request) {
  ConditionalController.new(request => MVC::Keayl::Request.new(method => 'GET', |%request))
}

describe 'MVC::Keayl etag-for', {
  it 'prefixes a weak etag with W/', {
    expect(etag-for('x').starts-with('W/"')).to.be-truthy;
  }

  it 'omits the prefix for a strong etag', {
    expect(etag-for('x', weak => False).starts-with('"')).to.be-truthy;
  }

  it 'produces the same etag for the same cache key', {
    expect(etag-for(CachedRecord.new(cache-key => 'rec/1'))).to.be(etag-for(CachedRecord.new(cache-key => 'rec/1')));
  }

  it 'produces different etags for different values', {
    expect(etag-for('a') eq etag-for('b')).to.be-falsy;
  }
}

describe 'MVC::Keayl HTTP dates', {
  it 'formats a DateTime as an HTTP date', {
    my $when = DateTime.new(:2021year, :6month, :9day, :10hour, :18minute, :14second, :timezone(0));
    expect(http-date($when)).to.be('Wed, 09 Jun 2021 10:18:14 GMT');
  }

  it 'parses an HTTP date back to a DateTime', {
    expect(parse-http-date('Wed, 09 Jun 2021 10:18:14 GMT').year).to.be(2021);
  }
}

describe 'MVC::Keayl::Controller conditional GET', {
  it 'sets an ETag header from fresh-when', {
    my $controller = showing();
    $controller.fresh-when(etag => 'abc');
    expect($controller.response.header('ETag').defined).to.be-truthy;
  }

  it 'yields 304 for a matching If-None-Match', {
    expect(showing(headers => %( 'if-none-match' => etag-for('abc') )).dispatch('show').status).to.be(304);
  }

  it 'leaves an empty body on a 304', {
    expect(showing(headers => %( 'if-none-match' => etag-for('abc') )).dispatch('show').body).to.be('');
  }

  it 'renders the body for a non-matching etag', {
    expect(showing(headers => %( 'if-none-match' => etag-for('different') )).dispatch('show').body).to.be('rendered');
  }

  it 'yields 304 for a wildcard If-None-Match', {
    expect(showing(headers => %( 'if-none-match' => '*' )).dispatch('show').status).to.be(304);
  }
}

describe 'MVC::Keayl::Controller last-modified', {
  it 'is fresh when not modified since the request', {
    my $controller = showing(headers => %( 'if-modified-since' => 'Wed, 09 Jun 2021 10:18:14 GMT' ));
    expect($controller.fresh-when(last-modified => DateTime.new(:2021year, :6month, :9day, :10hour, :0minute, :0second, :timezone(0)))).to.be-truthy;
  }

  it 'is stale when modified after the request', {
    my $controller = showing(headers => %( 'if-modified-since' => 'Wed, 09 Jun 2021 10:18:14 GMT' ));
    expect($controller.fresh-when(last-modified => DateTime.new(:2021year, :6month, :9day, :11hour, :0minute, :0second, :timezone(0)))).to.be-falsy;
  }

  it 'is not fresh without conditional request headers', {
    expect(showing().fresh-when(etag => 'abc')).to.be-falsy;
  }
}
