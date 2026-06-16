use lib 'specs/lib';
use BDD::Behave;
use JSON::Fast;
use MVC::Keayl::Request;
use MVC::Keayl::Parameters;
use MVC::Keayl::Storage;
use MVC::Keayl::Storage::Service;
use MVC::Keayl::Storage::Attached;
use MVC::Keayl::Storage::Variant;
use MVC::Keayl::Storage::Serving;

my $temp-counter = 0;

sub temp-root {
  $*TMPDIR.add('keayl-variant-spec-' ~ $*PID ~ '-' ~ $temp-counter++)
}

sub params(%data) {
  MVC::Keayl::Parameters.new(%data)
}

class StoragePhoto does Attachable {
  has $.id;
}
StoragePhoto.has-one-attached('image');

describe 'variant keys', {
  let(:blob, {
    my $b = MVC::Keayl::Storage::Blob.build('image-bytes', filename => 'a.png', content-type => 'image/png');
    $b.id = 1;
    $b
  });

  it 'namespaces the variant key under the source blob', {
    my $variant = MVC::Keayl::Storage::Variant::Variant.new(blob => blob, transformations => %( resize => '100x100' ));
    expect($variant.key.starts-with(blob.key ~ '/variants/')).to.be-truthy;
  }

  it 'produces different keys for different transformations', {
    my $small = MVC::Keayl::Storage::Variant::Variant.new(blob => blob, transformations => %( resize => '100x100' ));
    my $large = MVC::Keayl::Storage::Variant::Variant.new(blob => blob, transformations => %( resize => '500x500' ));
    expect($small.key eq $large.key).to.be-falsy;
  }

  it 'produces a stable key for the same transformations', {
    my $first  = MVC::Keayl::Storage::Variant::Variant.new(blob => blob, transformations => %( resize => '100x100' ));
    my $second = MVC::Keayl::Storage::Variant::Variant.new(blob => blob, transformations => %( resize => '100x100' ));
    expect($first.key).to.be($second.key);
  }
}

describe 'identity variant processing', {
  before-each({
    reset-storage;
    set-storage-service(DiskService.new(root => temp-root));
  });

  let(:photo, {
    my $p = StoragePhoto.new(id => 1);
    $p.image.attach(%( io => 'original', filename => 'p.png', content-type => 'image/png' ));
    $p
  });

  it 'is not processed until requested', {
    expect(photo.image.variant(resize => '50x50').is-processed).to.be-falsy;
  }

  it 'transforms and stores on download', {
    expect(photo.image.variant(resize => '50x50').download.decode).to.be('original');
  }

  it 'caches a processed variant in the service', {
    my $variant = photo.image.variant(resize => '50x50');
    $variant.process;
    expect($variant.is-processed).to.be-truthy;
  }
}

describe 'a pluggable transformer', {
  before-each({
    reset-storage;
    set-storage-service(DiskService.new(root => temp-root));
    set-storage-transformer(MVC::Keayl::Storage::Variant::CallableTransformer.new(
      block => sub ($bytes, %transformations) { ('[' ~ %transformations<resize> ~ ']' ~ $bytes.decode).encode('utf-8') },
    ));
  });

  let(:photo, {
    my $p = StoragePhoto.new(id => 2);
    $p.image.attach(%( io => 'pixels', filename => 'q.png', content-type => 'image/png' ));
    $p
  });

  it 'drives the variant bytes', {
    expect(photo.image.variant(resize => '10x10').download.decode).to.be('[10x10]pixels');
  }
}

describe 'MVC::Keayl::Storage::Serving::DirectUploadsController', {
  before-each({
    reset-storage;
    set-storage-service(DiskService.new(root => temp-root));
  });

  let(:response, {
    MVC::Keayl::Storage::Serving::DirectUploadsController.new(
      params => params({ blob => { filename => 'upload.txt', content-type => 'text/plain', byte-size => 5, checksum => 'abc' } }),
    ).dispatch('create')
  });

  it 'creates the blob record', {
    expect(response.status).to.be(201);
  }

  it 'returns a signed blob id', {
    my %payload = from-json(response.body);
    expect(%payload<signed-id>.chars > 0).to.be-truthy;
  }

  it 'returns an upload url', {
    my %payload = from-json(response.body);
    expect(%payload<direct-upload><url>.starts-with('/keayl/disk/')).to.be-truthy;
  }

  it 'echoes the content type header', {
    my %payload = from-json(response.body);
    expect(%payload<direct-upload><headers><Content-Type>).to.be('text/plain');
  }
}

describe 'MVC::Keayl::Storage::Serving::DiskController', {
  before-each({
    reset-storage;
    set-storage-service(DiskService.new(root => temp-root));
  });

  let(:blob, {
    my $b = MVC::Keayl::Storage::Blob.build('', filename => 'late.txt', content-type => 'text/plain');
    storage-repository.create-blob($b);
    $b
  });

  it 'acknowledges the upload', {
    my $token = storage-verifier.generate(blob.key, purpose => 'upload', expires-in => 300);
    my $request = MVC::Keayl::Request.new(method => 'PUT', body => 'uploaded-content');
    my $response = MVC::Keayl::Storage::Serving::DiskController.new(:$request, params => params({ token => $token })).dispatch('update');
    expect($response.status).to.be(204);
  }

  it 'stores the uploaded bytes', {
    my $token = storage-verifier.generate(blob.key, purpose => 'upload', expires-in => 300);
    my $request = MVC::Keayl::Request.new(method => 'PUT', body => 'uploaded-content');
    MVC::Keayl::Storage::Serving::DiskController.new(:$request, params => params({ token => $token })).dispatch('update');
    expect(storage-service.download(blob.key).decode).to.be('uploaded-content');
  }
}
