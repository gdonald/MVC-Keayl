use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Live;

sub drain($stream, &producer) {
  start { producer($stream) };
  $stream.chunks.map(*.decode('utf-8')).join
}

describe 'MVC::Keayl::Live::Stream', {
  it 'collects written chunks in order', {
    expect(drain(MVC::Keayl::Live::Stream.new, -> $stream {
      $stream.write('a');
      $stream.write('b');
      $stream.close;
    })).to.be('ab');
  }

  it 'encodes a string chunk as UTF-8', {
    my $stream = MVC::Keayl::Live::Stream.new;
    start { $stream.write('é'); $stream.close };
    expect($stream.chunks.head.elems).to.be(2);
  }

  it 'passes a blob chunk through unchanged', {
    my $stream = MVC::Keayl::Live::Stream.new;
    start { $stream.write(Blob.new(1, 2, 3)); $stream.close };
    expect($stream.chunks.head.list.join(',')).to.be('1,2,3');
  }

  it 'reports closed after close', {
    my $stream = MVC::Keayl::Live::Stream.new;
    $stream.close;
    expect($stream.is-closed).to.be-truthy;
  }

  it 'raises when writing to a closed stream', {
    my $stream = MVC::Keayl::Live::Stream.new;
    $stream.close;
    expect({ $stream.write('x') }).to.throw;
  }
}

describe 'MVC::Keayl::Live::Stream disconnect', {
  it 'marks the stream disconnected', {
    my $stream = MVC::Keayl::Live::Stream.new;
    $stream.disconnect;
    expect($stream.is-disconnected).to.be-truthy;
  }

  it 'raises a client-disconnected error on a later write', {
    my $stream = MVC::Keayl::Live::Stream.new;
    $stream.disconnect;
    expect({ $stream.write('x') }).to.throw(X::MVC::Keayl::Live::ClientDisconnected);
  }
}

describe 'MVC::Keayl::Live::SSE framing', {
  let(:sse, { MVC::Keayl::Live::SSE.new(stream => MVC::Keayl::Live::Stream.new) });

  it 'frames a bare data field', {
    expect(sse.frame('hi')).to.be("data: hi\n\n");
  }

  it 'frames event, id, and retry before the data', {
    expect(sse.frame('hi', event => 'ping', id => '7', retry => 3000)).to.be("retry: 3000\nevent: ping\nid: 7\ndata: hi\n\n");
  }

  it 'splits multiline data across data fields', {
    expect(sse.frame("one\ntwo")).to.be("data: one\ndata: two\n\n");
  }

  it 'frames a comment line', {
    my $stream = MVC::Keayl::Live::Stream.new;
    my $writer = MVC::Keayl::Live::SSE.new(:$stream);
    start { $writer.comment('keep-alive'); $stream.close };
    expect($stream.chunks.head.decode('utf-8')).to.be(": keep-alive\n\n");
  }
}

describe 'MVC::Keayl::Live::SSE defaults', {
  it 'applies a default event when none is given', {
    my $sse = MVC::Keayl::Live::SSE.new(stream => MVC::Keayl::Live::Stream.new, defaults => { event => 'message' });
    expect($sse.frame('hi')).to.be("event: message\ndata: hi\n\n");
  }

  it 'lets a per-write option override the default', {
    my $sse = MVC::Keayl::Live::SSE.new(stream => MVC::Keayl::Live::Stream.new, defaults => { event => 'message' });
    expect($sse.frame('hi', event => 'ping')).to.be("event: ping\ndata: hi\n\n");
  }
}
