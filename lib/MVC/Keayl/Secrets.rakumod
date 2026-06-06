use v6.d;
use Digest::HMAC;
use Digest::SHA1::Native;

unit class MVC::Keayl::Secrets;

has Str $.secret-key-base is required;

method resolve(%env = %*ENV, Str :$config --> MVC::Keayl::Secrets) {
  my $base = $config // %env<KEAYL_SECRET_KEY_BASE> // %env<SECRET_KEY_BASE>;

  die 'no secret key base configured (set KEAYL_SECRET_KEY_BASE or pass :config)' without $base;

  self.new(secret-key-base => $base)
}

method derive-key(Str:D $salt, Int :$length = 32 --> Str) {
  my $output  = Buf.new;
  my $counter = 1;

  while $output.bytes < $length {
    $output ~= hmac($!secret-key-base, $salt ~ chr($counter), &sha1);
    $counter++;
  }

  $output.subbuf(0, $length).list.map(*.fmt('%02x')).join
}

method signing-key(--> Str)    { self.derive-key('signed cookie') }
method encryption-key(--> Str) { self.derive-key('encrypted cookie') }
