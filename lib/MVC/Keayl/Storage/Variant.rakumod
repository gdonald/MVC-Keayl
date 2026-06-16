use v6.d;
use JSON::Fast;
use Digest::SHA1::Native;
use MVC::Keayl::Storage;
use MVC::Keayl::Storage::Service;
use MVC::Keayl::Storage::Repository;
use MVC::Keayl::Storage::Attached;

unit module MVC::Keayl::Storage::Variant;

role Transformer is export {
  method transform(Buf:D $bytes, %transformations) { ... }
}

class IdentityTransformer does Transformer is export {
  method transform(Buf:D $bytes, %transformations) {
    $bytes
  }
}

class CallableTransformer does Transformer is export {
  has &.block is required;

  method transform(Buf:D $bytes, %transformations) {
    &!block($bytes, %transformations)
  }
}

sub transformations-digest(%transformations --> Str) {
  sha1-hex(to-json(%transformations.sort.hash, :!pretty, :sorted-keys))
}

class Variant is export {
  has MVC::Keayl::Storage::Blob:D $.blob is required;
  has %.transformations;
  has Service $.service        = storage-service();
  has Repository $.repository  = storage-repository();
  has Transformer $.transformer = storage-transformer() // IdentityTransformer.new;

  method key(--> Str) {
    $!blob.key ~ '/variants/' ~ transformations-digest(%!transformations)
  }

  method is-processed(--> Bool) {
    $!service.exist(self.key)
  }

  method process(--> Variant) {
    return self if self.is-processed;

    my $source      = $!service.download($!blob.key);
    my $transformed = $!transformer.transform($source, %!transformations);
    $!service.upload(self.key, $transformed);

    self
  }

  method processed(--> Variant) { self.process }

  method download {
    self.process;
    $!service.download(self.key)
  }

  method url(*%options --> Str) {
    $!service.url(self.key, |%options)
  }
}

set-variant-builder(sub ($blob, %transformations --> Variant) {
  Variant.new(:$blob, :%transformations)
});
