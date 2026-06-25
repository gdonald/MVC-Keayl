use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::TestSupport;
use Cro::HTTP::Client;
use ServerFixtures;

describe 'MVC::Keayl::TestSupport LiveServer URLs', {
  let(:server, { LiveServer.new(app => EchoEndpoint.new) });

  it 'builds a base URL from the scheme, host, and port', {
    expect(server.base-url).to.match(/^ 'http://127.0.0.1:' \d+ $/);
  }

  it 'joins a path onto the base URL', {
    expect(server.url('/widgets')).to.be(server.base-url ~ '/widgets');
  }

  it 'chooses a different port for each server', {
    expect(server.port).not.to.be(LiveServer.new(app => EchoEndpoint.new).port);
  }
}

describe 'MVC::Keayl::TestSupport LiveServer serving', {
  it 'serves the wrapped app over a real socket', {
    my $server = LiveServer.new(app => EchoEndpoint.new).start;

    LEAVE $server.stop;

    my $response = await Cro::HTTP::Client.get($server.url('/ping'));

    expect($response.header('X-Path')).to.be('/ping');
  }
}
