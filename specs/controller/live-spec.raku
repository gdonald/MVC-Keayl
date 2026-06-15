use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Controller;
use ControllerFixtures;

sub body($response) {
  await $response.live-promise;
  $response.stream-chunks.map(*.decode('utf-8')).join
}

describe 'MVC::Keayl::Controller live', {
  let(:response, { StreamController.new.dispatch('numbers') });

  it 'marks the response as live', {
    expect(response.is-live).to.be-truthy;
  }

  it 'reports the response as streaming', {
    expect(response.is-streaming).to.be-truthy;
  }

  it 'streams each written chunk', {
    expect(body(response)).to.be('onetwothree');
  }
}

describe 'MVC::Keayl::Controller sse', {
  let(:response, { StreamController.new.dispatch('events') });

  it 'sets the event-stream content type', {
    expect(response.content-type).to.be('text/event-stream');
  }

  it 'sets a no-cache directive', {
    expect(response.header('Cache-Control')).to.be('no-cache');
  }

  it 'streams SSE frames', {
    expect(body(response)).to.be("event: greeting\ndata: hello\n\ndata: world\n\n");
  }

  it 'carries a default retry across frames', {
    expect(body(StreamController.new.dispatch('retrying'))).to.be(": keep-alive\n\nretry: 5000\ndata: tick\n\n");
  }
}

describe 'MVC::Keayl::Controller live teardown', {
  it 'streams the chunks written before a disconnect', {
    expect(body(StreamController.new.dispatch('teardown'))).to.be('first');
  }

  it 'tears down on a client disconnect', {
    my $controller = StreamController.new;
    await $controller.dispatch('teardown').live-promise;
    expect($controller.torn-down.join).to.be('disconnected');
  }
}
