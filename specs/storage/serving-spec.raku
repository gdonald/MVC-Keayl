use lib 'specs/lib';
use BDD::Behave;
use JSON::Fast;
use MIME::Base64;
use Digest::HMAC;
use Digest::SHA1::Native;
use MVC::Keayl::Request;
use MVC::Keayl::Parameters;
use MVC::Keayl::Routing;
use MVC::Keayl::Dispatcher;
use MVC::Keayl::TestSupport;
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

class ServingFakeClient {
  has %.store;
  method upload($key, $data, *%) { %!store{$key} = $data }
  method download($key)          { %!store{$key} }
  method delete($key)            { %!store{$key}:delete }
  method exist($key)             { %!store{$key}:exists }
  method url($key, *%)           { "https://cdn.test/$key" }
}

sub storage-session {
  my $router = routes { storage-routes };
  IntegrationSession.new(app => MVC::Keayl::Dispatcher.new(:$router, controllers => storage-controllers.Array))
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
  context 'with a service that has public urls', {
    before-each({
      reset-storage;
      set-storage-service(ExternalService.new(client => ServingFakeClient.new));
    });

    let(:blob, { make-blob('redirect-me', 'r.txt', 'text/plain') });
    let(:response, {
      my $signed = storage-verifier.generate(blob.id, purpose => 'blob');
      MVC::Keayl::Storage::Serving::RedirectController.new(params => params({ signed_id => $signed })).dispatch('show')
    });

    it 'issues a redirect', {
      expect(response.status).to.be(302);
    }

    it 'points at the service url', {
      expect(response.header('Location')).to.be('https://cdn.test/' ~ blob.key);
    }
  }

  context 'with a disk service', {
    before-each({
      reset-storage;
      set-storage-service(DiskService.new(root => temp-root));
    });

    let(:blob, { make-blob('served-from-disk', 'r.txt', 'text/plain') });
    let(:response, {
      my $signed = storage-verifier.generate(blob.id, purpose => 'blob');
      MVC::Keayl::Storage::Serving::RedirectController.new(params => params({ signed_id => $signed })).dispatch('show')
    });

    it 'streams the blob instead of redirecting', {
      expect(response.status).to.be(200);
    }

    it 'responds with the blob bytes', {
      expect(response.body).to.be('served-from-disk');
    }
  }

  context 'with the signed id under its hyphenated name', {
    before-each({
      reset-storage;
      set-storage-service(DiskService.new(root => temp-root));
    });

    it 'still finds the blob', {
      my $blob   = make-blob('hyphenated', 'h.txt', 'text/plain');
      my $signed = storage-verifier.generate($blob.id, purpose => 'blob');
      my $response = MVC::Keayl::Storage::Serving::RedirectController.new(params => params({ signed-id => $signed })).dispatch('show');
      expect($response.body).to.be('hyphenated');
    }
  }

  context 'with a tampered signed id', {
    before-each({
      reset-storage;
      set-storage-service(DiskService.new(root => temp-root));
    });

    it 'is not found', {
      my $response = MVC::Keayl::Storage::Serving::RedirectController.new(params => params({ signed_id => 'tampered--00' })).dispatch('show');
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
      MVC::Keayl::Storage::Serving::ProxyController.new(params => params({ signed_id => $signed })).dispatch('show')
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

    it 'honors the attachment disposition', {
      my $signed = storage-verifier.generate(blob.id, purpose => 'blob');
      my $response = MVC::Keayl::Storage::Serving::ProxyController.new(params => params({ signed_id => $signed, disposition => 'attachment' })).dispatch('show');
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

describe 'signed ids', {
  before-each({ reset-storage });

  let(:data, { '??????~~~~~~' });
  let(:signed, { storage-verifier.generate(data, purpose => 'blob') });

  it 'leave out the characters that would split or alter a path segment', {
    expect(signed.contains(any('/', '+', '='))).to.be-falsy;
  }

  it 'verify back to their data', {
    expect(storage-verifier.verify(signed, purpose => 'blob')).to.be(data);
  }

  context 'issued with standard Base64', {
    let(:legacy, {
      my $payload = MIME::Base64.encode-str(to-json({ data => data, purpose => 'blob' }, :!pretty), :oneline);
      $payload ~ '--' ~ hmac-hex('keayl-storage', $payload, &sha1)
    });

    it 'still verify', {
      expect(storage-verifier.verify(legacy, purpose => 'blob')).to.be(data);
    }
  }
}

describe 'storage-routes', {
  before-each({
    reset-storage;
    set-storage-service(DiskService.new(root => temp-root));
  });

  let(:session, { storage-session });
  let(:blob, { make-blob('routed-bytes', 'avatar.png', 'image/png') });

  it 'serves a proxy path built by blob-serving-path', {
    expect(session.get(blob-serving-path(blob, :proxy)).body).to.be('routed-bytes');
  }

  it 'serves a redirect path built by blob-serving-path', {
    expect(session.get(blob-serving-path(blob)).body).to.be('routed-bytes');
  }

  it 'creates a blob for a direct upload', {
    expect(session.post('/keayl/direct-uploads', body => 'filename=a.txt&byte_size=3&checksum=abc', headers => %( 'Content-Type' => 'application/x-www-form-urlencoded' )).status).to.be(201);
  }

  context 'uploading bytes to a direct upload url', {
    let(:key, { generate-key });

    before-each({
      session.put(upload-path(key), body => 'uploaded');
    });

    it 'stores the bytes under the blob key', {
      expect(storage-service.download(key).decode).to.be('uploaded');
    }
  }
}
