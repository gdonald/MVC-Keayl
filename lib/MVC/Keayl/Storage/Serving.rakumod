use v6.d;
use MVC::Keayl::Controller;
use MVC::Keayl::Routing;
use MVC::Keayl::Storage;
use MVC::Keayl::Storage::Attached;

unit module MVC::Keayl::Storage::Serving;

sub upload-path(Str:D $key, :$expires-in = 300 --> Str) is export {
  '/keayl/disk/' ~ storage-verifier.generate($key, purpose => 'upload', :$expires-in)
}

sub signed-blob($controller) {
  my $signed-id = $controller.params<signed_id> // $controller.params<signed-id>;

  my $id = storage-verifier.verify($signed-id, purpose => 'blob');
  return Nil without $id;

  storage-repository.find-blob($id)
}

sub send-blob($controller, $blob) {
  my $bytes = storage-service.download($blob.key);
  return $controller.head(404) without $bytes;

  my $disposition = $controller.params<disposition> // 'inline';

  $controller.send-data(
    $bytes,
    type        => $blob.content-type,
    filename    => $blob.filename,
    disposition => $disposition,
  )
}

class RedirectController is MVC::Keayl::Controller {
  method controller-path(--> Str) { 'keayl/blobs/redirect' }

  method show {
    my $blob = signed-blob(self);
    return self.head(404) without $blob;

    return send-blob(self, $blob) unless storage-service.has-public-url;

    self.redirect-to(storage-service.url($blob.key), status => 302)
  }
}

class ProxyController is MVC::Keayl::Controller {
  method controller-path(--> Str) { 'keayl/blobs/proxy' }

  method show {
    my $blob = signed-blob(self);
    return self.head(404) without $blob;

    send-blob(self, $blob)
  }
}

class DirectUploadsController is MVC::Keayl::Controller {
  method controller-path(--> Str) { 'keayl/direct-uploads' }

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
  method controller-path(--> Str) { 'keayl/disk' }

  method update {
    my $key = storage-verifier.verify(self.params<token>, purpose => 'upload');
    return self.head(404) without $key;

    storage-service.upload($key, self.request.body);

    self.head(204)
  }
}

sub storage-controllers(--> List) is export {
  (RedirectController, ProxyController, DirectUploadsController, DiskController)
}

sub storage-routes() is export {
  get  '/keayl/blobs/redirect/:signed_id/*filename', to => 'keayl/blobs/redirect#show';
  get  '/keayl/blobs/proxy/:signed_id/*filename',    to => 'keayl/blobs/proxy#show';
  post '/keayl/direct-uploads',                      to => 'keayl/direct-uploads#create';
  put  '/keayl/disk/:token',                         to => 'keayl/disk#update';
}
