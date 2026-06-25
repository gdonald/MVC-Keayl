use v6.d;
use MVC::Keayl::Middleware;
use MVC::Keayl::Request;
use MVC::Keayl::Response;

unit class MVC::Keayl::Middleware::Static is MVC::Keayl::Middleware;

has IO::Path:D $.root is required;
has Str        $.url-prefix = '';

my constant %CONTENT-TYPES =
  html        => 'text/html; charset=utf-8',
  htm         => 'text/html; charset=utf-8',
  css         => 'text/css; charset=utf-8',
  js          => 'text/javascript; charset=utf-8',
  mjs         => 'text/javascript; charset=utf-8',
  json        => 'application/json; charset=utf-8',
  xml         => 'application/xml',
  txt         => 'text/plain; charset=utf-8',
  svg         => 'image/svg+xml',
  png         => 'image/png',
  jpg         => 'image/jpeg',
  jpeg        => 'image/jpeg',
  gif         => 'image/gif',
  webp        => 'image/webp',
  avif        => 'image/avif',
  ico         => 'image/x-icon',
  woff        => 'font/woff',
  woff2       => 'font/woff2',
  ttf         => 'font/ttf',
  otf         => 'font/otf',
  eot         => 'application/vnd.ms-fontobject',
  pdf         => 'application/pdf',
  map         => 'application/json',
  wasm        => 'application/wasm',
  webmanifest => 'application/manifest+json';

sub content-type-for(Str $extension --> Str) {
  %CONTENT-TYPES{$extension.lc} // 'application/octet-stream'
}

method call(MVC::Keayl::Request:D $request --> MVC::Keayl::Response:D) {
  return self.app.call($request) unless $request.method eq 'GET' | 'HEAD';

  my $file = self!resolve($request.path);

  return self.app.call($request) without $file;

  self!serve($file, :head($request.method eq 'HEAD'))
}

method !resolve(Str:D $path --> IO::Path) {
  my $relative = $path;

  if $!url-prefix ne '' {
    return IO::Path unless $path eq $!url-prefix || $path.starts-with($!url-prefix ~ '/');

    $relative = $path.substr($!url-prefix.chars);
  }

  $relative = $relative.subst(/^ '/'+ /, '');

  return IO::Path if $relative eq '';
  return IO::Path if $relative.split('/').first({ $_ eq '..' || $_ eq '' }).defined;

  my $candidate = $!root.add($relative);

  return IO::Path unless $candidate.e && $candidate.f;
  return IO::Path unless self!within-root($candidate);

  $candidate
}

method !within-root(IO::Path:D $candidate --> Bool) {
  my $root-abs = $!root.absolute.IO.resolve.Str;
  my $cand-abs = $candidate.absolute.IO.resolve.Str;

  $cand-abs eq $root-abs || $cand-abs.starts-with($root-abs ~ '/')
}

method !serve(IO::Path:D $file, Bool :$head --> MVC::Keayl::Response) {
  my $response = MVC::Keayl::Response.new(status => 200);

  $response.content-type(content-type-for($file.extension));
  $response.body($file.slurp(:bin)) unless $head;

  $response
}
