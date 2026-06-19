use v6.d;
use MVC::Keayl::Controller;

unit module MVC::Keayl::Assets::Serving;

my IO::Path $asset-root;

sub set-asset-root(IO() $root) is export {
  $asset-root = $root;
}

sub asset-root(--> IO::Path) is export {
  $asset-root
}

sub reset-asset-root() is export {
  $asset-root = IO::Path;
}

class AssetsController is MVC::Keayl::Controller is export {
  method show {
    my $path = self.params<path>;

    return self.head(404) without $path;
    return self.head(404) if $path.contains('..');
    return self.head(404) without asset-root();

    my $file = asset-root.add($path);
    return self.head(404) unless $file.e && $file.f;

    self.send-file($file, disposition => 'inline');
    self.response.set-header('Cache-Control', 'public, max-age=31536000, immutable');

    self.response
  }
}
