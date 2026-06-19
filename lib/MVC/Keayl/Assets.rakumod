use v6.d;
use JSON::Fast;
use Digest::SHA1::Native;
use MVC::Keayl::SafeString;
use MVC::Keayl::Helpers::Tag;

unit module MVC::Keayl::Assets;

sub digest-for($content --> Str) is export {
  sha1-hex($content ~~ Blob ?? $content !! $content.Str.encode('utf-8'))
}

sub digested-name(Str:D $logical, $content --> Str) is export {
  my $digest = digest-for($content);
  my $dot    = $logical.rindex('.');

  $dot.defined
    ?? $logical.substr(0, $dot) ~ '-' ~ $digest ~ $logical.substr($dot)
    !! $logical ~ '-' ~ $digest
}

sub walk-files(IO::Path $dir --> Seq) {
  gather for $dir.dir.sort({ .basename }) -> $entry {
    if $entry.d {
      take $_ for walk-files($entry);
    } elsif $entry.f {
      take $entry;
    }
  }
}

class Manifest is export {
  has %.assets;

  method lookup(Str:D $logical) {
    %!assets{$logical}
  }

  method to-json(--> Str) {
    to-json({ assets => %!assets }, :sorted-keys)
  }

  method from-json(Str:D $json --> Manifest) {
    my %data = from-json($json);
    self.new(assets => (%data<assets> // {}))
  }

  method build(IO() $source, IO() :$output --> Manifest) {
    my %assets;

    for walk-files($source) -> $file {
      my $logical  = $file.relative($source);
      my $content  = $file.slurp(:bin);
      my $digested = digested-name($logical, $content);

      %assets{$logical} = $digested;

      with $output {
        my $target = $output.add($digested);
        $target.parent.mkdir;
        $target.spurt($content);
      }
    }

    self.new(:%assets)
  }
}

my Manifest $default-manifest;

sub set-asset-manifest(Manifest:D $manifest) is export {
  $default-manifest = $manifest;
}

sub asset-manifest(--> Manifest) is export {
  $default-manifest
}

sub reset-asset-manifest() is export {
  $default-manifest = Manifest;
}

sub logical-name(Str:D $source, $type --> Str) {
  my $logical = $source;
  $logical ~= '.' ~ $type if $type.defined && !$logical.contains('.');
  $logical
}

sub manifest-resolver(Manifest:D $manifest --> Callable) is export {
  sub ($source, $type?) {
    return $source if $source.starts-with('/') || $source.contains('://');

    my $logical = logical-name($source, $type);
    '/assets/' ~ ($manifest.lookup($logical) // $logical)
  }
}

sub digested-resolver($source, $type?) is export {
  return $source if $source.starts-with('/') || $source.contains('://');

  my $logical  = logical-name($source, $type);
  my $digested = $default-manifest.defined ?? $default-manifest.lookup($logical) !! Str;

  '/assets/' ~ ($digested // $logical)
}

class ImportMap is export {
  has @.pins;

  method pin(Str:D $name, Str :$to, Bool :$preload = False --> ImportMap) {
    @!pins.push: %( :$name, to => ($to // '/assets/' ~ $name ~ '.js'), :$preload );
    self
  }

  method pin-all-from(IO() $dir, Str :$under, Bool :$preload = False --> ImportMap) {
    for walk-files($dir).grep(*.extension.lc eq 'js') -> $file {
      my $relative = $file.relative($dir).subst(/ '.js' $ /, '');
      my $name     = $under.defined ?? $under ~ '/' ~ $relative !! $relative;

      self.pin($name, to => '/assets/' ~ $name ~ '.js', :$preload);
    }

    self
  }

  method imports(Manifest :$manifest --> Hash) {
    my %imports;

    for @!pins -> %pin {
      %imports{%pin<name>} = resolve-import(%pin<to>, $manifest);
    }

    %imports
  }

  method to-json(Manifest :$manifest --> Str) {
    to-json({ imports => self.imports(:$manifest) }, :sorted-keys)
  }
}

sub resolve-import(Str:D $to, $manifest --> Str) {
  return $to without $manifest;
  return $to unless $to.starts-with('/assets/');

  my $logical  = $to.substr('/assets/'.chars);
  my $digested = $manifest.lookup($logical);

  $digested.defined ?? '/assets/' ~ $digested !! $to
}

sub javascript-importmap-tags(ImportMap:D $importmap, Manifest :$manifest --> SafeString) is export {
  my @tags;

  @tags.push: content-tag('script', html-safe($importmap.to-json(:$manifest)), %( type => 'importmap' ));

  for $importmap.pins.grep(*<preload>) -> %pin {
    @tags.push: tag('link', %( rel => 'modulepreload', href => resolve-import(%pin<to>, $manifest) ));
  }

  safe-join(@tags, "\n")
}
