use v6.d;
use YAMLish;
use Digest::HMAC;
use Digest::SHA1::Native;
use OpenSSL::CryptTools;
use Crypt::Random;
use MVC::Keayl::HttpAuthentication;

unit class MVC::Keayl::Credentials does Associative;

sub to-hex(Blob:D $bytes --> Str) {
  $bytes.list.map(*.fmt('%02x')).join
}

sub from-hex(Str:D $hex --> Blob) {
  Blob.new($hex.comb(2).map({ :16($_) }))
}

sub aes-key(Str:D $secret --> Blob) {
  (sha1($secret) ~ sha1($secret ~ "\x01")).subbuf(0, 32)
}

sub encrypt-content(Str:D $plaintext, Str:D $master-key --> Str) is export {
  my $key        = aes-key($master-key);
  my $iv         = crypt_random_buf(16);
  my $ciphertext = encrypt($plaintext.encode('utf-8'), :aes256, :$key, :$iv);

  my $payload = to-hex($iv) ~ '--' ~ to-hex($ciphertext);

  $payload ~ '--' ~ hmac-hex($master-key, $payload, &sha1)
}

sub decrypt-content(Str:D $stored, Str:D $master-key --> Str) is export {
  my $trimmed   = $stored.trim;
  my $separator = $trimmed.rindex('--');
  return Str without $separator;

  my $payload   = $trimmed.substr(0, $separator);
  my $signature = $trimmed.substr($separator + 2);

  return Str unless secure-compare(hmac-hex($master-key, $payload, &sha1), $signature);

  my ($iv-hex, $ciphertext-hex) = $payload.split('--', 2);
  return Str without $ciphertext-hex;

  my $key       = aes-key($master-key);
  my $plaintext = try decrypt(from-hex($ciphertext-hex), :aes256, :$key, :iv(from-hex($iv-hex)));
  return Str without $plaintext;

  (try $plaintext.decode('utf-8')) // Str
}

sub generate-master-key(--> Str) is export {
  crypt_random_buf(16).list.map(*.fmt('%02x')).join
}

has Str          $.master-key is required;
has IO::Path()   $.path;
has              %!data;

sub paths-for(IO::Path $root, $env --> List) {
  $env.defined
    ?? ($root.add("config/credentials/$env.yml.enc"), $root.add("config/credentials/$env.key"))
    !! ($root.add('config/credentials.yml.enc'),      $root.add('config/master.key'))
}

method resolve(IO() :$root = '.'.IO, Str :$env, Str :$master-key is copy, :%env-vars = %*ENV --> MVC::Keayl::Credentials) {
  my ($path, $key-path) = paths-for($root, $env);

  $master-key //= %env-vars<KEAYL_MASTER_KEY> // ($key-path.e ?? $key-path.slurp.trim !! Str);

  die 'no master key configured (set KEAYL_MASTER_KEY or write config/master.key)' without $master-key;

  my $credentials = self.new(:$master-key, :$path);
  $credentials.reload;
  $credentials
}

method reload(--> ::?CLASS) {
  %!data = ($!path.defined && $!path.e)
    ?? (load-yaml(decrypt-content($!path.slurp, $!master-key) // '') // {})
    !! {};

  self
}

method AT-KEY(Str() $key)              { %!data{$key} }
method EXISTS-KEY(Str() $key --> Bool) { %!data{$key}:exists }

method read(*@keys) {
  my $node = %!data;

  for @keys -> $key {
    return Nil without $node;
    return Nil unless $node ~~ Associative;
    $node = $node{$key};
  }

  $node
}

method to-hash(--> Hash) { %!data.clone }

method content(--> Str) {
  ($!path.defined && $!path.e) ?? decrypt-content($!path.slurp, $!master-key) !! ''
}

method save-content(Str:D $yaml --> ::?CLASS) {
  $!path.parent.mkdir;
  $!path.spurt(encrypt-content($yaml, $!master-key));
  %!data = load-yaml($yaml) // {};

  self
}

method write(%new-data --> ::?CLASS) {
  self.save-content(save-yaml(%new-data))
}
