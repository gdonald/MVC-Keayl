use v6.d;
use Crypt::Random;

unit module MVC::Keayl::CSRF;

constant TOKEN-BYTES = 32;

sub to-hex(Blob:D $bytes --> Str) {
  $bytes.list.map(*.fmt('%02x')).join
}

sub from-hex(Str:D $hex --> Blob) {
  Blob.new($hex.comb(2).map({ :16($_) }))
}

sub secure-equal(Blob:D $left, Blob:D $right --> Bool) {
  return False unless $left.bytes == $right.bytes;

  my $difference = 0;
  $difference = $difference +| ($left[$_] +^ $right[$_]) for ^$left.bytes;

  $difference == 0
}

sub generate-token(--> Str) is export {
  to-hex(crypt_random_buf(TOKEN-BYTES))
}

sub mask-token(Str:D $real --> Str) is export {
  my $real-bytes = from-hex($real);
  my $pad        = crypt_random_buf(TOKEN-BYTES);
  my $masked     = Blob.new($pad.list Z+^ $real-bytes.list);

  to-hex($pad ~ $masked)
}

sub unmask-token(Str:D $token --> Blob) {
  my $bytes = from-hex($token);
  return Blob unless $bytes.bytes == TOKEN-BYTES * 2;

  my $pad    = $bytes.subbuf(0, TOKEN-BYTES);
  my $masked = $bytes.subbuf(TOKEN-BYTES);

  Blob.new($pad.list Z+^ $masked.list)
}

sub valid-token($submitted, $real --> Bool) is export {
  return False without $submitted;
  return False without $real;

  my $real-bytes = from-hex($real);

  if $submitted.chars == TOKEN-BYTES * 4 {
    my $candidate = unmask-token($submitted);
    return False without $candidate;
    return secure-equal($candidate, $real-bytes);
  }

  if $submitted.chars == TOKEN-BYTES * 2 {
    return secure-equal(from-hex($submitted), $real-bytes);
  }

  False
}
