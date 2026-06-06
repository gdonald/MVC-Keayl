use v6.d;
use Digest::HMAC;
use Digest::SHA1::Native;
use OpenSSL::CryptTools;
use Crypt::Random;

my @day-names   = <Sun Mon Tue Wed Thu Fri Sat>;
my @month-names = <Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec>;

sub http-date(DateTime:D $when --> Str) {
  my $utc = $when.utc;
  sprintf('%s, %02d %s %04d %02d:%02d:%02d GMT',
    @day-names[$utc.day-of-week % 7], $utc.day, @month-names[$utc.month - 1],
    $utc.year, $utc.hour, $utc.minute, $utc.second.Int)
}

sub uri-encode(Str:D $text --> Str) {
  $text.subst(/<-[A..Za..z0..9\-._~]>/, { sprintf('%%%02X', .Str.encode('utf-8')[0]) }, :g)
}

sub uri-decode(Str:D $text --> Str) {
  $text.subst(/'%' (<[0..9A..Fa..f]> ** 2)/, { chr(:16(~$0)) }, :g)
}

sub to-hex(Blob:D $bytes --> Str) {
  $bytes.list.map(*.fmt('%02x')).join
}

sub from-hex(Str:D $hex --> Blob) {
  Blob.new($hex.comb(2).map({ :16($_) }))
}

sub secure-equal(Str:D $left, Str:D $right --> Bool) {
  return False unless $left.chars == $right.chars;

  my $difference = 0;
  $difference = $difference +| ($left.substr($_, 1).ord +^ $right.substr($_, 1).ord) for ^$left.chars;

  $difference == 0
}

sub sign-value(Str:D $value, Str:D $secret --> Str) {
  $value ~ '--' ~ hmac-hex($secret, $value, &sha1)
}

sub unsign-value(Str:D $stored, Str:D $secret) {
  my $separator = $stored.rindex('--');
  return Nil without $separator;

  my $value     = $stored.substr(0, $separator);
  my $signature = $stored.substr($separator + 2);

  secure-equal(hmac-hex($secret, $value, &sha1), $signature) ?? $value !! Str
}

sub aes-key(Str:D $secret --> Blob) {
  (sha1($secret) ~ sha1($secret ~ "\x01")).subbuf(0, 32)
}

sub encrypt-value(Str:D $value, Str:D $secret --> Str) {
  my $key        = aes-key($secret);
  my $iv         = crypt_random_buf(16);
  my $ciphertext = encrypt($value.encode('utf-8'), :aes256, :$key, :$iv);

  my $payload = to-hex($iv) ~ '--' ~ to-hex($ciphertext);

  $payload ~ '--' ~ hmac-hex($secret, $payload, &sha1)
}

sub decrypt-value(Str:D $stored, Str:D $secret) {
  my $separator = $stored.rindex('--');
  return Str without $separator;

  my $payload   = $stored.substr(0, $separator);
  my $signature = $stored.substr($separator + 2);

  return Str unless secure-equal(hmac-hex($secret, $payload, &sha1), $signature);

  my ($iv-hex, $ciphertext-hex) = $payload.split('--', 2);
  return Str without $ciphertext-hex;

  my $key       = aes-key($secret);
  my $plaintext = try decrypt(from-hex($ciphertext-hex), :aes256, :$key, :iv(from-hex($iv-hex)));
  return Str without $plaintext;

  (try $plaintext.decode('utf-8')) // Str
}

sub build-set-cookie(Str:D $name, Str:D $value, %options --> Str) {
  my @parts = $name ~ '=' ~ uri-encode($value);

  @parts.push('Path=' ~ $_)   with %options<path>;
  @parts.push('Domain=' ~ $_) with %options<domain>;

  with %options<expires> {
    @parts.push('Expires=' ~ ($_ ~~ DateTime ?? http-date($_) !! ~$_));
  }

  @parts.push('Max-Age=' ~ $_)  with %options<max-age>;
  @parts.push('SameSite=' ~ $_) with %options<same-site>;
  @parts.push('Secure')   if %options<secure>;
  @parts.push('HttpOnly') if %options<http-only>;

  @parts.join('; ')
}

class MVC::Keayl::Cookies::Jar does Associative {
  has $.store is required;
  has &.encode is required;
  has &.decode is required;

  method AT-KEY(Str() $name) {
    my $raw = $!store.raw-get($name);
    return Nil without $raw;
    &!decode($raw)
  }

  method EXISTS-KEY(Str() $name --> Bool) { $!store.raw-exists($name) }
  method DELETE-KEY(Str() $name)          { $!store.delete($name) }

  method ASSIGN-KEY(Str() $name, $value) { $!store.set-raw($name, &!encode(~$value), {}) }

  method set(Str() $name, $value, *%options) {
    $!store.set-raw($name, &!encode(~$value), %options);
    self
  }

  method delete(Str() $name, *%options) {
    $!store.delete($name, |%options);
    self
  }
}

class MVC::Keayl::Cookies does Associative {
  has %.incoming;
  has Str $.secret = '';
  has %!outgoing;

  method parse(Str $header?, Str :$secret = '' --> MVC::Keayl::Cookies) {
    my %incoming;

    with $header {
      for $header.split(/\s* ';' \s*/) -> $pair {
        next unless $pair.contains('=');
        my ($name, $value) = $pair.split('=', 2);
        %incoming{$name.trim} = uri-decode($value // '');
      }
    }

    self.new(:%incoming, :$secret)
  }

  method raw-get(Str() $name) {
    return %!outgoing{$name}<value> if %!outgoing{$name}:exists;
    %!incoming{$name}
  }

  method raw-exists(Str() $name --> Bool) {
    (%!outgoing{$name}:exists) || (%!incoming{$name}:exists)
  }

  method set-raw(Str() $name, Str() $value, %options) {
    %!outgoing{$name} = { :$value, options => %options };
  }

  method set(Str() $name, $value, *%options) {
    self.set-raw($name, ~$value, %options);
    self
  }

  method delete(Str() $name, *%options) {
    self.set-raw($name, '', %( |%options, expires => 'Thu, 01 Jan 1970 00:00:00 GMT', max-age => 0 ));
    self
  }

  method AT-KEY(Str() $name)              { self.raw-get($name) }
  method EXISTS-KEY(Str() $name --> Bool) { self.raw-exists($name) }
  method DELETE-KEY(Str() $name)          { self.delete($name) }

  method ASSIGN-KEY(Str() $name, $value) {
    if $value ~~ Associative && ($value<value>:exists) {
      my %options = $value.grep(*.key ne 'value').map({ .key => .value }).hash;
      self.set($name, $value<value>, |%options);
    } else {
      self.set($name, $value);
    }
  }

  method signed(--> MVC::Keayl::Cookies::Jar) {
    MVC::Keayl::Cookies::Jar.new(
      store  => self,
      encode => -> $value  { sign-value($value, $!secret) },
      decode => -> $stored { unsign-value($stored, $!secret) },
    )
  }

  method encrypted(--> MVC::Keayl::Cookies::Jar) {
    MVC::Keayl::Cookies::Jar.new(
      store  => self,
      encode => -> $value  { encrypt-value($value, $!secret) },
      decode => -> $stored { decrypt-value($stored, $!secret) },
    )
  }

  method set-cookie-headers(--> List) {
    %!outgoing.sort(*.key).map(-> $pair {
      build-set-cookie($pair.key, $pair.value<value>, $pair.value<options>)
    }).List
  }
}
