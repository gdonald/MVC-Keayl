use v6.d;
use MVC::Keayl::Controller;
use MVC::Keayl::Storage;
use MVC::Keayl::Storage::Attached;

unit module MVC::Keayl::Storage::Serving;

sub upload-path(Str:D $key, :$expires-in = 300 --> Str) is export {
  '/keayl/disk/' ~ storage-verifier.generate($key, purpose => 'upload', :$expires-in)
}

class RedirectController is MVC::Keayl::Controller {
  method show {
    my $id = storage-verifier.verify(self.params<signed-id>, purpose => 'blob');
    return self.head(404) without $id;

    my $blob = storage-repository.find-blob($id);
    return self.head(404) without $blob;

    self.redirect-to(storage-service.url($blob.key), status => 302)
  }
}

class ProxyController is MVC::Keayl::Controller {
  method show {
    my $id = storage-verifier.verify(self.params<signed-id>, purpose => 'blob');
    return self.head(404) without $id;

    my $blob = storage-repository.find-blob($id);
    return self.head(404) without $blob;

    my $bytes = storage-service.download($blob.key);
    return self.head(404) without $bytes;

    my $disposition = self.params<disposition> // 'inline';

    self.send-data(
      $bytes,
      type        => $blob.content-type,
      filename    => $blob.filename,
      disposition => $disposition,
    )
  }
}

class DirectUploadsController is MVC::Keayl::Controller {
  method create {
    my %attributes = self.params<blob> // self.params.Hash;

    my $blob = MVC::Keayl::Storage::Blob.new(
      key          => generate-key(),
      filename     => %attributes<filename>,
      content-type => %attributes<content-type> // %attributes<content_type> // 'application/octet-stream',
      byte-size    => (%attributes<byte-size> // %attributes<byte_size> // 0).Int,
      checksum     => %attributes<checksum>,
    );

    storage-repository.create-blob($blob);

    self.render(json => {
      signed-id     => storage-verifier.generate($blob.id, purpose => 'blob'),
      key           => $blob.key,
      direct-upload => {
        url     => upload-path($blob.key),
        headers => { 'Content-Type' => $blob.content-type },
      },
    }, status => 201)
  }
}

class DiskController is MVC::Keayl::Controller {
  method update {
    my $key = storage-verifier.verify(self.params<token>, purpose => 'upload');
    return self.head(404) without $key;

    storage-service.upload($key, self.request.body);

    self.head(204)
  }
}
