use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::TestSupport;
use MVC::Keayl::Dispatcher;
use MVC::Keayl::Routing;
use MVC::Keayl::Controller;

# End-to-end regression for a binary file upload through a mounted sub-application.
# A real app mounts the admin engine at /admin; posting an image there rebases the
# request into the sub-app and parses the multipart body. Binary file bytes are
# not valid UTF-8, so decoding them anywhere in that chain corrupted them and
# crashed the VM. This drives the whole chain and asserts the bytes arrive intact.

# Reports the uploaded part's kind (bytes vs string) and its exact byte values.
class MultipartUploadController is MVC::Keayl::Controller {
  method create {
    my $content = self.params<image><content>;
    my $kind    = $content ~~ Blob ?? 'blob' !! 'str';
    self.render(plain => "$kind:" ~ $content.list.join(','));
  }
}

sub mounted-session(--> IntegrationSession) {
  my $inner = MVC::Keayl::Dispatcher.new(
    router             => routes({ post '/imgs', to => 'multipart_upload#create'; }),
    controllers        => [MultipartUploadController],
    controller-options => %( secret => 'upload-secret' ),
  );
  my $outer = MVC::Keayl::Dispatcher.new(
    router             => routes({ mount $inner, at => '/admin'; }),
    controllers        => [],
    controller-options => %( secret => 'outer-secret' ),
  );
  IntegrationSession.new(app => $outer)
}

describe 'a binary multipart upload through a mounted sub-application', {
  # Bytes that are not valid UTF-8 (0xFF 0xD8 is a JPEG start-of-image marker).
  let(:file-bytes, { Buf.new(0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x00) });

  let(:multipart-body, {
    my $head = "--B\r\nContent-Disposition: form-data; name=\"image\"; filename=\"x.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n".encode('latin-1');
    my $tail = "\r\n--B--\r\n".encode('latin-1');
    Buf.new(|$head, |file-bytes, |$tail)
  });

  let(:response, {
    mounted-session.post('/admin/imgs',
      headers => { 'Content-Type' => 'multipart/form-data; boundary=B' },
      body    => multipart-body)
  });

  it 'dispatches without crashing', {
    expect(response.status).to.eq(200);
  }

  it 'delivers the file content to the mounted controller as bytes', {
    expect(response.body.split(':', 2)[0]).to.eq('blob');
  }

  it 'preserves the binary content byte-for-byte across mount and parse', {
    expect(response.body.split(':', 2)[1]).to.eq(file-bytes.list.join(','));
  }
}
