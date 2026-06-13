use v6.d;
use MIME::Base64;
use OpenSSL::Digest;

unit module MVC::Keayl::HttpAuthentication;

constant DIGEST-NONCE-TTL = 300;

sub secure-compare(Str() $left, Str() $right --> Bool) is export {
  my $left-bytes  = $left.encode('utf-8');
  my $right-bytes = $right.encode('utf-8');

  return False unless $left-bytes.bytes == $right-bytes.bytes;

  my $result = 0;
  $result = $result +| ($left-bytes[$_] +^ $right-bytes[$_]) for ^$left-bytes.bytes;

  $result == 0
}

# Basic

sub encode-basic-credentials(Str:D $user, Str:D $password --> Str) is export {
  'Basic ' ~ MIME::Base64.encode-str("$user:$password")
}

sub decode-basic-credentials($header --> List) is export {
  return ().List without $header;
  return ().List unless $header ~~ /:i ^ 'Basic' \s+ (\S+) /;

  my $decoded = try MIME::Base64.decode-str(~$0);
  return ().List without $decoded;
  return ().List unless $decoded.contains(':');

  my ($user, $password) = $decoded.split(':', 2);
  ($user, $password).List
}

# Token

sub encode-token-credentials(Str:D $token, *%options --> Str) is export {
  my @pairs = ("token=\"$token\"");
  @pairs.push("{.key}=\"{.value}\"") for %options.sort(*.key);

  'Token ' ~ @pairs.join(', ')
}

sub token-and-options($header --> List) is export {
  return (Str, {}).List without $header;
  return (Str, {}).List unless $header ~~ /:i ^ ['Token'|'Bearer'] \s+ (.+) $/;

  my $rest = ~$0;

  unless $rest ~~ /^ <[\w\-]>+ \s* '='/ {
    return ($rest.trim, {}).List;
  }

  my %options;
  for $rest ~~ m:g/ (<[\w\-]>+) \s* '=' \s* [ '"' (<-["]>*) '"' | (<-[\s,]>+) ] / -> $match {
    %options{~$match[0]} = $match[1].defined ?? ~$match[1] !! ~$match[2];
  }

  my $token = (%options<token>:delete) // (%options<bearer>:delete);
  ($token, %options).List
}

# Digest

sub parse-digest-header($header --> Hash) is export {
  return {} without $header;
  return {} unless $header ~~ /:i ^ 'Digest' \s+ (.+) $/;

  my $rest = ~$0;
  my %params;

  for $rest ~~ m:g/ (<[\w\-]>+) \s* '=' \s* [ '"' (<-["]>*) '"' | (<-[\s,]>+) ] / -> $match {
    %params{~$match[0]} = $match[1].defined ?? ~$match[1] !! ~$match[2];
  }

  %params
}

sub digest-nonce(Str() $secret, Int:D $time --> Str) is export {
  MIME::Base64.encode-str("$time:" ~ md5-hex("$time:$secret"))
}

sub validate-digest-nonce(Str() $secret, $nonce, Int:D $ttl = DIGEST-NONCE-TTL --> Bool) is export {
  return False without $nonce;

  my $decoded = try MIME::Base64.decode-str(~$nonce);
  return False without $decoded;
  return False unless $decoded.contains(':');

  my ($time, $hash) = $decoded.split(':', 2);
  return False unless $time ~~ /^ \d+ $/;
  return False unless secure-compare($hash, md5-hex("$time:$secret"));

  my $age = time - $time.Int;
  0 <= $age <= $ttl
}

sub digest-opaque(Str() $secret --> Str) is export {
  md5-hex("opaque:$secret")
}

sub digest-challenge(Str:D $realm, Str() $secret, Int:D $time --> Str) is export {
  my $nonce  = digest-nonce($secret, $time);
  my $opaque = digest-opaque($secret);

  qq{Digest realm="$realm", qop="auth", nonce="$nonce", opaque="$opaque"}
}

sub expected-digest-response(%params, Str:D $method, Str:D $realm, Str:D $username, Str:D $password, Bool :$password-is-ha1 = False --> Str) is export {
  my $ha1 = $password-is-ha1 ?? $password !! md5-hex("$username:$realm:$password");
  my $ha2 = md5-hex($method.uc ~ ':' ~ (%params<uri> // ''));

  with %params<qop> {
    md5-hex(($ha1, %params<nonce>, %params<nc>, %params<cnonce>, %params<qop>, $ha2).join(':'))
  } else {
    md5-hex(($ha1, %params<nonce>, $ha2).join(':'))
  }
}
