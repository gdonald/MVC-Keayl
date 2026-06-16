use v6.d;
use Crypt::Random;
use Digest::HMAC;
use Digest::SHA1::Native;
use MIME::Base64;
use JSON::Fast;
use MVC::Keayl::HttpAuthentication;

unit module MVC::Keayl::Storage;

sub to-bytes($data --> Blob) {
  $data ~~ Blob ?? $data !! $data.Str.encode('utf-8')
}

sub generate-key(--> Str) is export {
  crypt_random_buf(16).list.map(*.fmt('%02x')).join
}

sub checksum-for($data --> Str) is export {
  sha1-hex(to-bytes($data))
}

class Blob is export {
  has $.id is rw;
  has Str $.key;
  has Str $.filename;
  has Str $.content-type;
  has Int $.byte-size;
  has Str $.checksum;
  has %.metadata;
  has $.created-at;

  method build($data, :$filename, :$content-type, :$key, :%metadata, :$created-at --> Blob) {
    my $bytes = to-bytes($data);

    self.new(
      key          => $key // generate-key(),
      filename     => $filename.defined ?? $filename.Str !! Str,
      content-type => $content-type.defined ?? $content-type.Str !! 'application/octet-stream',
      byte-size    => $bytes.bytes,
      checksum     => checksum-for($bytes),
      metadata     => %metadata // {},
      :$created-at,
    )
  }

  method extension(--> Str) {
    my $dot = ($!filename // '').rindex('.');
    $dot.defined ?? $!filename.substr($dot + 1) !! Str
  }

  method is-image(--> Bool) {
    ($!content-type // '').starts-with('image/')
  }

  method to-hash(--> Hash) {
    {
      key => $!key, filename => $!filename, content-type => $!content-type,
      byte-size => $!byte-size, checksum => $!checksum, metadata => %!metadata,
    }
  }
}

class Attachment is export {
  has $.id is rw;
  has Str $.name;
  has Str $.record-type;
  has $.record-id;
  has $.blob is rw;
  has $.created-at;
}

class Verifier is export {
  has Str $.secret is required;
  has &.clock = sub { now };

  method !sign(Str:D $payload --> Str) {
    hmac-hex($!secret, $payload, &sha1)
  }

  method generate($data, Str :$purpose, :$expires-in --> Str) {
    my %envelope = data => $data, purpose => ($purpose // Str);
    %envelope<expires-at> = &!clock().Numeric + $expires-in if $expires-in.defined;

    my $payload = MIME::Base64.encode-str(to-json(%envelope, :!pretty), :oneline);

    $payload ~ '--' ~ self!sign($payload)
  }

  method verify(Str $token, Str :$purpose --> Mu) {
    return Nil without $token;

    my $separator = $token.rindex('--');
    return Nil without $separator;

    my $payload   = $token.substr(0, $separator);
    my $signature = $token.substr($separator + 2);
    return Nil unless secure-compare(self!sign($payload), $signature);

    my %envelope = from-json(MIME::Base64.decode-str($payload));

    return Nil unless (%envelope<purpose> // Str) eqv ($purpose // Str);
    return Nil if %envelope<expires-at>.defined && &!clock().Numeric >= %envelope<expires-at>;

    %envelope<data>
  }
}
