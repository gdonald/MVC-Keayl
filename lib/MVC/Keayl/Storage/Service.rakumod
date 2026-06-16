use v6.d;
use Digest::SHA1::Native;

unit module MVC::Keayl::Storage::Service;

sub to-bytes($data --> Blob) {
  $data ~~ Blob ?? $data !! $data.Str.encode('utf-8')
}

role Service is export {
  method upload(Str:D $key, $data, *%options)  { ... }
  method download(Str:D $key)                  { ... }
  method delete(Str:D $key)                    { ... }
  method exist(Str:D $key --> Bool)            { ... }
  method url(Str:D $key, *%options --> Str)    { ... }
}

class DiskService does Service is export {
  has IO::Path() $.root is required;

  method !path(Str:D $key --> IO::Path) {
    my $digest = sha1-hex($key);
    $!root.add($digest.substr(0, 2)).add($digest.substr(2, 2)).add($digest)
  }

  method upload(Str:D $key, $data, *%options) {
    my $path = self!path($key);
    $path.parent.mkdir;
    $path.spurt(to-bytes($data));
    $key
  }

  method download(Str:D $key) {
    my $path = self!path($key);
    $path.e ?? $path.slurp(:bin) !! Nil
  }

  method delete(Str:D $key) {
    my $path = self!path($key);
    $path.unlink if $path.e;
    Nil
  }

  method exist(Str:D $key --> Bool) {
    self!path($key).e
  }

  method url(Str:D $key, *%options --> Str) {
    self!path($key).absolute
  }
}

class ExternalService does Service is export {
  has $.client is required;

  method upload(Str:D $key, $data, *%options) {
    $!client.upload($key, to-bytes($data), |%options)
  }

  method download(Str:D $key) {
    $!client.download($key)
  }

  method delete(Str:D $key) {
    $!client.delete($key)
  }

  method exist(Str:D $key --> Bool) {
    so $!client.exist($key)
  }

  method url(Str:D $key, *%options --> Str) {
    $!client.url($key, |%options)
  }
}

class MirrorService does Service is export {
  has Service $.primary is required;
  has @.mirrors;

  method !services(--> List) {
    ($!primary, |@!mirrors).List
  }

  method upload(Str:D $key, $data, *%options) {
    my $bytes = to-bytes($data);
    .upload($key, $bytes, |%options) for self!services;
    $key
  }

  method download(Str:D $key) {
    $!primary.download($key)
  }

  method delete(Str:D $key) {
    .delete($key) for self!services;
    Nil
  }

  method exist(Str:D $key --> Bool) {
    $!primary.exist($key)
  }

  method url(Str:D $key, *%options --> Str) {
    $!primary.url($key, |%options)
  }
}
