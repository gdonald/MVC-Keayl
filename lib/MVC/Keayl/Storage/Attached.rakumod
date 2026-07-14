use v6.d;
use MVC::Keayl::Storage;
use MVC::Keayl::Storage::Service;
use MVC::Keayl::Storage::Repository;

unit module MVC::Keayl::Storage::Attached;

my Service $default-service;
my Repository $default-repository;
my Str $default-secret = 'keayl-storage';

sub set-storage-service(Service:D $service) is export {
  $default-service = $service;
}

sub storage-service(--> Service) is export {
  $default-service
}

sub set-storage-repository(Repository:D $repository) is export {
  $default-repository = $repository;
}

sub storage-repository(--> Repository) is export {
  $default-repository //= MemoryRepository.new
}

sub set-storage-secret(Str:D $secret) is export {
  $default-secret = $secret;
}

my &variant-builder;

sub set-variant-builder(&builder) is export {
  &variant-builder = &builder;
}

my $default-transformer;

sub set-storage-transformer($transformer) is export {
  $default-transformer = $transformer;
}

sub storage-transformer() is export {
  $default-transformer
}

sub storage-verifier(--> MVC::Keayl::Storage::Verifier) is export {
  MVC::Keayl::Storage::Verifier.new(secret => $default-secret)
}

sub reset-storage() is export {
  $default-service     = Nil;
  $default-repository  = Nil;
  $default-secret      = 'keayl-storage';
  $default-transformer = Nil;
}

sub encode-segment(Str:D $value --> Str) {
  $value.subst(/<-[A..Za..z0..9._~-]>/, { '%' ~ $_.Str.encode('utf-8').list.map(*.fmt('%02X')).join }, :g)
}

sub blob-serving-path(MVC::Keayl::Storage::Blob:D $blob, Bool :$proxy, :$expires-in, :$filename --> Str) is export {
  my $signed = storage-verifier.generate($blob.id, purpose => 'blob', |(expires-in => $_ with $expires-in));
  my $mode   = $proxy ?? 'proxy' !! 'redirect';
  my $name   = $filename // $blob.filename // $blob.key;

  '/keayl/blobs/' ~ $mode ~ '/' ~ $signed ~ '/' ~ encode-segment($name)
}

sub attachable-parts($attachable --> List) {
  if $attachable ~~ Associative {
    return (
      $attachable<io> // $attachable<data>,
      $attachable<filename>,
      $attachable<content-type> // $attachable<content_type>,
    );
  }

  (
    $attachable.io,
    ($attachable.?filename // $attachable.?original-filename),
    ($attachable.?content-type // $attachable.?content_type),
  )
}

sub resolve-blob($attachable, Service:D $service, Repository:D $repository --> MVC::Keayl::Storage::Blob) {
  return $attachable.id.defined ?? $attachable !! $repository.create-blob($attachable)
    if $attachable ~~ MVC::Keayl::Storage::Blob;

  if $attachable ~~ Str {
    my $id = storage-verifier.verify($attachable, purpose => 'blob');
    return Nil without $id;
    return $repository.find-blob($id);
  }

  my ($data, $filename, $content-type) = attachable-parts($attachable);

  my $blob = MVC::Keayl::Storage::Blob.build($data, :$filename, :$content-type);
  $repository.create-blob($blob);
  $service.upload($blob.key, $data);

  $blob
}

class One is export {
  has $.record    is required;
  has Str $.name  is required;
  has Service $.service     = storage-service();
  has Repository $.repository = storage-repository();

  # The attachment lookup is memoised per proxy: a request typically asks
  # is-attached, then blob, then download, and each starts from `attachment`.
  has $!attachment-cache;
  has Bool $!attachment-loaded = False;

  method !type { $!record.^name }
  method !id   { $!record.id }

  method !forget-attachment {
    $!attachment-cache  = Nil;
    $!attachment-loaded = False;
  }

  method attachment {
    unless $!attachment-loaded {
      $!attachment-cache  = $!repository.attachment-for(self!type, self!id, $!name);
      $!attachment-loaded = True;
    }
    $!attachment-cache
  }

  method blob {
    with self.attachment { .blob } else { Nil }
  }

  method is-attached(--> Bool) {
    self.attachment.defined
  }

  method attach($attachable) {
    self.detach;

    my $blob = resolve-blob($attachable, $!service, $!repository);
    return Nil without $blob;

    my $attachment = $!repository.create-attachment(MVC::Keayl::Storage::Attachment.new(
      name        => $!name,
      record-type => self!type,
      record-id   => self!id,
      :$blob,
    ));
    $!attachment-cache  = $attachment;
    $!attachment-loaded = True;
    $attachment
  }

  method detach {
    with self.attachment -> $attachment {
      $!repository.delete-attachment($attachment);
    }
    self!forget-attachment;
    Nil
  }

  method purge {
    with self.attachment -> $attachment {
      with $attachment.blob -> $blob {
        $!service.delete($blob.key);
        $!repository.delete-blob($blob);
      }
      $!repository.delete-attachment($attachment);
    }
    self!forget-attachment;
    Nil
  }

  method download {
    with self.blob -> $blob { $!service.download($blob.key) } else { Nil }
  }

  method url(*%options --> Str) {
    with self.blob -> $blob { $!service.url($blob.key, |%options) } else { Str }
  }

  method signed-id(*%options --> Str) {
    with self.blob -> $blob { storage-verifier.generate($blob.id, purpose => 'blob', |%options) } else { Str }
  }

  method path(Bool :$proxy, :$expires-in, :$filename --> Str) {
    with self.blob -> $blob { blob-serving-path($blob, :$proxy, :$expires-in, :$filename) } else { Str }
  }

  method variant(*%transformations) {
    die 'load MVC::Keayl::Storage::Variant to build variants' without &variant-builder;

    with self.blob -> $blob { variant-builder($blob, %transformations) } else { Nil }
  }

  method filename(--> Str)     { with self.blob { .filename }     else { Str } }
  method content-type(--> Str) { with self.blob { .content-type } else { Str } }
  method byte-size(--> Int)    { with self.blob { .byte-size }    else { Int } }
}

class Many is export {
  has $.record    is required;
  has Str $.name  is required;
  has Service $.service       = storage-service();
  has Repository $.repository = storage-repository();

  # Memoised like One.attachment: blobs, is-attached, and elems all start
  # from `attachments`.
  has $!attachments-cache;

  method !type { $!record.^name }
  method !id   { $!record.id }

  method !forget-attachments {
    $!attachments-cache = Nil;
  }

  method attachments(--> List) {
    ($!attachments-cache //= $!repository.attachments-for(self!type, self!id, $!name))<>
  }

  method blobs(--> List) {
    self.attachments.map(*.blob).List
  }

  method is-attached(--> Bool) {
    so self.attachments.elems
  }

  method elems(--> Int) {
    self.attachments.elems
  }

  method attach(**@attachables) {
    for @attachables -> $attachable {
      my $blob = resolve-blob($attachable, $!service, $!repository);
      next without $blob;

      $!repository.create-attachment(MVC::Keayl::Storage::Attachment.new(
        name        => $!name,
        record-type => self!type,
        record-id   => self!id,
        :$blob,
      ));
    }
    self!forget-attachments;
    self.attachments
  }

  method purge {
    for self.attachments -> $attachment {
      with $attachment.blob -> $blob {
        $!service.delete($blob.key);
        $!repository.delete-blob($blob);
      }
      $!repository.delete-attachment($attachment);
    }
    self!forget-attachments;
    Nil
  }

  method detach {
    $!repository.delete-attachment($_) for self.attachments;
    self!forget-attachments;
    Nil
  }
}

my %declarations{Mu};

sub declarations-for(Mu $class --> Hash) {
  my %merged;
  for $class.^mro.reverse -> $ancestor {
    %merged{.key} = .value for (%declarations{$ancestor} // {}).pairs;
  }
  %merged
}

role Attachable is export {
  method has-one-attached(Str:D $name --> ::?CLASS) {
    (%declarations{self.WHAT} //= {}){$name} = { many => False };
    self
  }

  method has-many-attached(Str:D $name --> ::?CLASS) {
    (%declarations{self.WHAT} //= {}){$name} = { many => True };
    self
  }

  method attached-one(Str:D $name --> One) {
    One.new(record => self, :$name)
  }

  method attached-many(Str:D $name --> Many) {
    Many.new(record => self, :$name)
  }

  method attachment-names(--> List) {
    declarations-for(self.WHAT).keys.sort.List
  }

  method FALLBACK(Str $name, |args) {
    my %declared = declarations-for(self.WHAT);

    X::Method::NotFound.new(method => $name, typename => self.^name).throw
      unless %declared{$name}:exists;

    %declared{$name}<many>
      ?? self.attached-many($name)
      !! self.attached-one($name)
  }
}
