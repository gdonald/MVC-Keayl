use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Storage;
use MVC::Keayl::Storage::Service;
use MVC::Keayl::Storage::Repository;
use MVC::Keayl::Storage::Attached;

my $temp-counter = 0;

sub temp-root {
  $*TMPDIR.add('keayl-storage-spec-' ~ $*PID ~ '-' ~ $temp-counter++)
}

sub cleanup($root) {
  return unless $root.e;
  for $root.dir -> $entry {
    $entry.f ?? $entry.unlink !! cleanup($entry);
  }
  $root.rmdir;
}

class StorageUser does Attachable {
  has $.id;
}
StorageUser.has-one-attached('avatar');
StorageUser.has-many-attached('documents');

describe 'MVC::Keayl::Storage::Blob', {
  let(:blob, { MVC::Keayl::Storage::Blob.build('hello world', filename => 'greeting.txt', content-type => 'text/plain') });

  it 'records the byte size', {
    expect(blob.byte-size).to.be(11);
  }

  it 'computes a checksum', {
    expect(blob.checksum).to.be(checksum-for('hello world'));
  }

  it 'derives the extension from the filename', {
    expect(blob.extension).to.be('txt');
  }

  it 'gets a storage key', {
    expect(blob.key.chars > 0).to.be-truthy;
  }

  context 'for a text file', {
    it 'is not an image', {
      expect(blob.is-image).to.be-falsy;
    }
  }

  context 'for an image file', {
    let(:image, { MVC::Keayl::Storage::Blob.build('x', filename => 'pic.png', content-type => 'image/png') });

    it 'reports being an image', {
      expect(image.is-image).to.be-truthy;
    }
  }
}

describe 'MVC::Keayl::Storage::Service::DiskService', {
  let(:root, { temp-root });
  let(:service, { DiskService.new(:root(root)) });

  it 'reports an uploaded key as existing', {
    service.upload('abcdef12', 'payload');
    expect(service.exist('abcdef12')).to.be-truthy;
  }

  it 'downloads what it uploaded', {
    service.upload('abcdef12', 'payload');
    expect(service.download('abcdef12').decode).to.be('payload');
  }

  it 'reports a missing key as absent', {
    expect(service.exist('missing0')).to.be-falsy;
  }

  it 'deletes a key', {
    service.upload('abcdef12', 'payload');
    service.delete('abcdef12');
    expect(service.exist('abcdef12')).to.be-falsy;
  }
}

describe 'MVC::Keayl::Storage::Service::ExternalService', {
  let(:service, {
    my class FakeClient {
      has %.store;
      method upload($key, $data, *%) { %!store{$key} = $data }
      method download($key)          { %!store{$key} }
      method delete($key)            { %!store{$key}:delete }
      method exist($key)             { %!store{$key}:exists }
      method url($key, *%)           { "https://cdn.test/$key" }
    }
    ExternalService.new(client => FakeClient.new)
  });

  it 'round-trips existence through the client', {
    service.upload('k1', 'data');
    expect(service.exist('k1')).to.be-truthy;
  }

  it 'downloads through the client', {
    service.upload('k1', 'data');
    expect(service.download('k1').decode).to.be('data');
  }

  it 'builds a url through the client', {
    expect(service.url('k1')).to.be('https://cdn.test/k1');
  }
}

describe 'MVC::Keayl::Storage::Service::MirrorService', {
  let(:primary-root, { temp-root });
  let(:mirror-root, { temp-root });
  let(:primary, { DiskService.new(root => primary-root) });
  let(:mirror, { DiskService.new(root => mirror-root) });
  let(:service, { MirrorService.new(primary => primary, mirrors => [mirror]) });

  it 'writes to the primary', {
    service.upload('deadbeef', 'replicated');
    expect(primary.exist('deadbeef')).to.be-truthy;
  }

  it 'writes to every mirror', {
    service.upload('deadbeef', 'replicated');
    expect(mirror.exist('deadbeef')).to.be-truthy;
  }

  it 'reads from the primary', {
    service.upload('deadbeef', 'replicated');
    expect(service.download('deadbeef').decode).to.be('replicated');
  }

  it 'deletes from every mirror', {
    service.upload('deadbeef', 'replicated');
    service.delete('deadbeef');
    expect(mirror.exist('deadbeef')).to.be-falsy;
  }
}

describe 'has-one-attached', {
  before-each({
    reset-storage;
    set-storage-service(DiskService.new(root => temp-root));
  });

  let(:user, { StorageUser.new(id => 1) });

  it 'has no attachment on a fresh record', {
    expect(user.avatar.is-attached).to.be-falsy;
  }

  context 'after attaching a file', {
    before-each({ StorageUser.new(id => 1).avatar.attach(%( io => 'avatar-bytes', filename => 'me.png', content-type => 'image/png' )) });

    it 'links a blob to the record', {
      expect(user.avatar.is-attached).to.be-truthy;
    }

    it 'exposes the blob filename', {
      expect(user.avatar.filename).to.be('me.png');
    }

    it 'downloads the uploaded bytes', {
      expect(user.avatar.download.decode).to.be('avatar-bytes');
    }
  }

  context 'when attaching a signed blob id', {
    let(:blob, {
      my $b = MVC::Keayl::Storage::Blob.build('shared', filename => 'doc.txt', content-type => 'text/plain');
      storage-repository.create-blob($b);
      $b
    });

    it 'links the existing blob', {
      my $signed = storage-verifier.generate(blob.id, purpose => 'blob');
      user.avatar.attach($signed);
      expect(user.avatar.blob.id).to.be(blob.id);
    }
  }

  context 'when attaching twice', {
    it 'replaces the single attachment', {
      user.avatar.attach(%( io => 'first', filename => 'a.txt' ));
      user.avatar.attach(%( io => 'second', filename => 'b.txt' ));
      expect(user.avatar.filename).to.be('b.txt');
    }
  }
}

describe 'purge', {
  before-each({
    reset-storage;
    set-storage-service(DiskService.new(root => temp-root));
  });

  let(:user, { StorageUser.new(id => 3) });

  it 'unlinks the attachment', {
    user.avatar.attach(%( io => 'gone', filename => 'g.txt' ));
    user.avatar.purge;
    expect(user.avatar.is-attached).to.be-falsy;
  }

  it 'deletes the blob from the service', {
    user.avatar.attach(%( io => 'gone', filename => 'g.txt' ));
    my $key = user.avatar.blob.key;
    user.avatar.purge;
    expect(storage-service.exist($key)).to.be-falsy;
  }
}

describe 'has-many-attached', {
  before-each({
    reset-storage;
    set-storage-service(DiskService.new(root => temp-root));
  });

  let(:user, { StorageUser.new(id => 4) });

  it 'records every attachment', {
    user.documents.attach(%( io => 'one', filename => '1.txt' ), %( io => 'two', filename => '2.txt' ));
    expect(user.documents.elems).to.be(2);
  }

  it 'exposes each blob', {
    user.documents.attach(%( io => 'one', filename => '1.txt' ), %( io => 'two', filename => '2.txt' ));
    expect(user.documents.blobs.map(*.filename).sort.join(',')).to.be('1.txt,2.txt');
  }
}

describe 'an undeclared attachment name', {
  it 'is a method-not-found error', {
    my $user = StorageUser.new(id => 5);
    expect({ $user.nonexistent }).to.throw;
  }
}
