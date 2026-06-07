use v6.d;

unit module MVC::Keayl::Mime;

my %format-to-type;
my %type-to-format;

sub register-mime(Str:D $format, Str:D $type, :@aliases --> Nil) is export {
  %format-to-type{$format} = $type;
  %type-to-format{$type} //= $format;
  %type-to-format{$_} //= $format for @aliases;
}

sub mime-type(Str:D $format --> Str) is export {
  %format-to-type{$format} // Str
}

sub mime-format(Str:D $type --> Str) is export {
  %type-to-format{$type.lc.split(';')[0].trim} // Str
}

sub parse-accept($header --> List) is export {
  return () without $header;

  my @entries;

  for $header.split(',') -> $part {
    next if $part.trim eq '';

    my @bits = $part.split(';');
    my $type = @bits[0].trim.lc;
    my $quality = 1.0;

    for @bits[1 .. *] -> $param {
      my ($key, $value) = $param.split('=', 2);
      $quality = (+$value // 1.0) if $key.defined && $key.trim eq 'q';
    }

    @entries.push: { :$type, :$quality };
  }

  @entries.sort({ -$_<quality> }).map(*<type>).List
}

sub negotiate(@available, $accept --> Str) is export {
  return @available[0] without $accept;
  return @available[0] if $accept.trim eq '';

  for parse-accept($accept) -> $type {
    return @available[0] if $type eq '*/*';

    my $format = mime-format($type);
    return $format if $format.defined && @available.first(* eq $format);

    if $type.ends-with('/*') {
      my $prefix = $type.substr(0, *- 1);

      for @available -> $candidate {
        my $candidate-type = mime-type($candidate);
        return $candidate if $candidate-type.defined && $candidate-type.starts-with($prefix);
      }
    }
  }

  Str
}

register-mime('html', 'text/html',            aliases => ['application/xhtml+xml']);
register-mime('text', 'text/plain');
register-mime('json', 'application/json',     aliases => ['text/x-json', 'application/jsonrequest']);
register-mime('xml',  'application/xml',      aliases => ['text/xml']);
register-mime('js',   'text/javascript',      aliases => ['application/javascript']);
register-mime('css',  'text/css');
register-mime('csv',  'text/csv');
register-mime('rss',  'application/rss+xml');
register-mime('atom', 'application/atom+xml');
register-mime('yaml', 'application/x-yaml',   aliases => ['text/yaml']);
register-mime('ics',  'text/calendar');
register-mime('png',  'image/png');
register-mime('jpeg', 'image/jpeg');
register-mime('gif',  'image/gif');
register-mime('pdf',  'application/pdf');
register-mime('zip',  'application/zip');
