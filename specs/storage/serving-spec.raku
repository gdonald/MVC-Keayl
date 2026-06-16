use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Request;
use MVC::Keayl::Parameters;
use MVC::Keayl::Storage;
use MVC::Keayl::Storage::Service;
use MVC::Keayl::Storage::Attached;
use MVC::Keayl::Storage::Serving;

my $temp-counter = 0;

sub temp-root {
  $*TMPDIR.add('keayl-serving-spec-' ~ $*PID ~ '-' ~ $temp-counter++)
}

sub make-blob($body, $filename, $content-type) {
  my $blob = MVC::Keayl::Storage::Blob.build($body, :$filename, :$content-type);
  storage-repository.create-blob($blob);
  storage-service.upload($blob.key, $body);
  $blob
}

sub params(%data) {
  MVC::Keayl::Parameters.new(%data)
}

describe 'blob serving paths', {
  before-each({
    reset-storage;
    set-storage-service(DiskService.new(root => temp-root));
  });

  let(:blob, { make-blob('content', 'file.txt', 'text/plain') });

  it 'uses the redirect route by default', {
    expect(blob-serving-path(blob).starts-with('/keayl/blobs/redirect/')).to.be-truthy;
  }

  it 'uses the proxy route when asked', {
    expect(blob-serving-path(blob, :proxy).starts-with('/keayl/blobs/proxy/')).to.be-truthy;
  }

  it 'ends with the filename', {
    expect(blob-serving-path(blob).ends-with('/file.txt')).to.be-truthy;
  }
}

describe 'MVC::Keayl::Storage::Serving::RedirectController', {
  before-each({
    reset-storage;
    set-storage-service(DiskService.new(root => temp-root));
  });

  context 'with a valid signed id', {
    let(:blob, { make-blob('redirect-me', 'r.txt', 'text/plain') });
    let(:response, {
      my $signed = storage-verifier.generate(blob.id, purpose => 'blob');
      MVC::Keayl::Storage::Serving::RedirectController.new(params => params({ signed-id => $signed })).dispatch('show')
    });

    it 'issues a redirect', {
      expect(response.status).to.be(302);
    }

    it 'points at the service url', {
      expect(response.header('Location')).to.be(storage-service.url(blob.key));
    }
  }

  context 'with a tampered signed id', {
    it 'is not found', {
      my $response = MVC::Keayl::Storage::Serving::RedirectController.new(params => params({ signed-id => 'tampered--00' })).dispatch('show');
      expect($response.status).to.be(404);
    }
  }
}

describe 'MVC::Keayl::Storage::Serving::ProxyController', {
  before-each({
    reset-storage;
    set-storage-service(DiskService.new(root => temp-root));
  });

  context 'serving an image', {
    let(:blob, { make-blob('proxy-bytes', 'p.png', 'image/png') });
    let(:response, {
      my $signed = storage-verifier.generate(blob.id, purpose => 'blob');
      MVC::Keayl::Storage::Serving::ProxyController.new(params => params({ signed-id => $signed })).dispatch('show')
    });

    it 'streams the blob bytes', {
      expect(response.body).to.be('proxy-bytes');
    }

    it 'sets the blob content type', {
      expect(response.header('content-type')).to.be('image/png');
    }

    it 'defaults to inline disposition', {
      expect(response.header('Content-Disposition')).to.be('inline; filename="p.png"');
    }
  }

  context 'with an attachment disposition', {
    let(:blob, { make-blob('attach-me', 'd.txt', 'text/plain') });

    it 'honours the attachment disposition', {
      my $signed = storage-verifier.generate(blob.id, purpose => 'blob');
      my $response = MVC::Keayl::Storage::Serving::ProxyController.new(params => params({ signed-id => $signed, disposition => 'attachment' })).dispatch('show');
      expect($response.header('Content-Disposition')).to.be('attachment; filename="d.txt"');
    }
  }
}

describe 'expiring signed urls', {
  before-each({
    reset-storage;
    set-storage-service(DiskService.new(root => temp-root));
  });

  it 'verifies before expiry', {
    my $blob     = make-blob('expiring', 'e.txt', 'text/plain');
    my $verifier = MVC::Keayl::Storage::Verifier.new(secret => 'keayl-storage', clock => sub { 1000 });
    my $signed   = $verifier.generate($blob.id, purpose => 'blob', expires-in => 60);
    expect($verifier.verify($signed, purpose => 'blob')).to.be($blob.id);
  }

  it 'stops verifying after expiry', {
    my $blob = make-blob('expiring', 'e.txt', 'text/plain');
    my $time = 1000;
    my $verifier = MVC::Keayl::Storage::Verifier.new(secret => 'keayl-storage', clock => sub { $time });
    my $signed = $verifier.generate($blob.id, purpose => 'blob', expires-in => 60);
    $time = 1100;
    expect($verifier.verify($signed, purpose => 'blob').defined).to.be-falsy;
  }
}
