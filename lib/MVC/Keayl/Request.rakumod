use v6.d;

unit class MVC::Keayl::Request;

has Str $.method;
has Str $.path;
has Str $.query-string;
has     %.headers;

has Str $!conn-scheme;
has Str $!remote-address;
has     $!body-source;
has Str $!variant;

has Bool $!body-read = False;
has Str  $!body-cache;

has Bool $!query-parsed = False;
has      %!query-params;

sub split-target(Str:D $target --> List) {
  my $q = $target.index('?');
  return ($target, '') without $q;

  ($target.substr(0, $q), $target.substr($q + 1));
}

sub normalize-headers(%headers --> Hash) {
  my %out;

  for %headers.kv -> $name, $value {
    %out{$name.lc} = $value ~~ Positional ?? $value.join(', ') !! ~$value;
  }

  %out;
}

sub percent-decode(Str:D $raw --> Str) {
  my $text = $raw.subst('+', ' ', :g);
  my $bytes = Buf.new;

  my $i = 0;
  my $len = $text.chars;

  while $i < $len {
    my $char = $text.substr($i, 1);

    if $char eq '%' && $i + 2 < $len && $text.substr($i + 1, 2) ~~ /^ <[0..9A..Fa..f]> ** 2 $/ {
      $bytes.push: :16($text.substr($i + 1, 2));
      $i += 3;
      next;
    }

    $bytes.append: $char.encode('utf-8');
    $i++;
  }

  $bytes.decode('utf-8');
}

sub parse-query(Str:D $query --> Hash) {
  my %out;
  return %out unless $query;

  for $query.split('&', :skip-empty) -> $pair {
    my ($name, $value) = $pair.split('=', 2);
    next unless $name.defined && $name ne '';

    my $key = percent-decode($name);
    my $val = percent-decode($value // '');

    %out{$key} = %out{$key}:exists ?? [ |%out{$key}.list, $val ] !! $val;
  }

  %out;
}

submethod BUILD(
  Str  :$method = 'GET',
  Str  :$target,
  Str  :$path,
  Str  :$query-string,
       :%headers,
       :$body,
  Str  :$scheme = 'http',
  Str  :$remote-address,
) {
  $!method = $method.uc;

  if $target.defined {
    ($!path, $!query-string) = split-target($target);
  } else {
    $!path = $path // '/';
    $!query-string = $query-string // '';
  }

  %!headers = normalize-headers(%headers);
  $!conn-scheme = $scheme.lc;
  $!remote-address = $remote-address;
  $!body-source = $body;
}

method header(Str:D $name --> Str) {
  %!headers{$name.lc} // Str
}

method has-header(Str:D $name --> Bool) {
  %!headers{$name.lc}:exists
}

method is-get(--> Bool)    { $!method eq 'GET' }
method is-post(--> Bool)   { $!method eq 'POST' }
method is-put(--> Bool)    { $!method eq 'PUT' }
method is-patch(--> Bool)  { $!method eq 'PATCH' }
method is-delete(--> Bool) { $!method eq 'DELETE' }
method is-head(--> Bool)   { $!method eq 'HEAD' }

method is-xhr(--> Bool) {
  (self.header('x-requested-with') // '').lc eq 'xmlhttprequest'
}

method variant(--> Str) {
  $!variant
}

method set-variant($value --> ::?CLASS) {
  $!variant = $value.defined ?? $value.Str !! Str;
  self
}

method detect-variant(--> Str) {
  my $agent = (self.header('user-agent') // '').lc;
  return Str if $agent eq '';

  return 'tablet' if $agent.contains('ipad') || ($agent.contains('android') && !$agent.contains('mobile'));
  return 'phone'  if $agent.contains('iphone') || $agent.contains('mobile');

  Str
}

method scheme(--> Str) {
  with self.header('x-forwarded-proto') {
    return .split(',')[0].trim.lc;
  }

  $!conn-scheme
}

method is-ssl(--> Bool) {
  self.scheme eq 'https'
}

method !host-header(--> Str) {
  self.header('x-forwarded-host') // self.header('host') // Str
}

method host(--> Str) {
  my $header = self!host-header;
  return Str without $header;

  $header.split(':')[0]
}

method port(--> Int) {
  my $header = self!host-header;

  with $header {
    my @parts = $header.split(':');
    return @parts[1].Int if @parts.elems > 1 && @parts[1] ~~ /^ \d+ $/;
  }

  with self.header('x-forwarded-port') {
    return .Int if $_ ~~ /^ \d+ $/;
  }

  self.is-ssl ?? 443 !! 80
}

method remote-ip(--> Str) {
  with self.header('x-forwarded-for') {
    my $first = .split(',')[0].trim;
    return $first if $first;
  }

  $!remote-address // Str
}

method body(--> Str) {
  unless $!body-read {
    my $raw = $!body-source ~~ Callable ?? $!body-source.() !! $!body-source;

    $!body-cache = do given $raw {
      when Blob { .decode('utf-8') }
      when Str  { $_ }
      default   { '' }
    };

    $!body-read = True;
  }

  $!body-cache
}

method query-params(--> Hash) {
  unless $!query-parsed {
    %!query-params = parse-query($!query-string);
    $!query-parsed = True;
  }

  %!query-params
}

method rebase(Str:D $path --> ::?CLASS) {
  self.WHAT.new(
    method         => $!method,
    :$path,
    query-string   => $!query-string,
    headers        => %!headers,
    body           => self.body,
    scheme         => self.scheme,
    remote-address => self.remote-ip,
  )
}
