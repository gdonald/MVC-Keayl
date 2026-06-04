use v6.d;
use JSON::Fast;
use MVC::Keayl::Parameters;

unit module MVC::Keayl::Params;

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

  $bytes.decode('utf-8')
}

# Build a nested structure from a single bracketed key:
# `user[name]` nests a hash, `ids[]` appends to an array, `user[][name]`
# builds an array of hashes.
sub normalize(%params, Str:D $name, $value) {
  return unless $name ~~ / ^ <[\[\]]>* (<-[\[\]]>+) <[\]]>* /;

  my $key   = ~$0;
  my $after = $name.substr($/.to);

  if $after eq '' {
    %params{$key} = $value;
  } elsif $after eq '[]' {
    %params{$key} //= [];
    %params{$key}.push($value);
  } elsif $after.starts-with('[]') {
    my $rest = $after.substr(2);
    %params{$key} //= [];

    $rest ~~ / ^ <[\[\]]>* (<-[\[\]]>+) <[\]]>* /;
    my $child = ~$0;

    if %params{$key}.elems && %params{$key}[*-1] ~~ Hash && !(%params{$key}[*-1]{$child}:exists) {
      normalize(%params{$key}[*-1], $rest, $value);
    } else {
      my %inner;
      normalize(%inner, $rest, $value);
      %params{$key}.push(%inner);
    }
  } else {
    %params{$key} //= {};
    normalize(%params{$key}, $after, $value);
  }
}

sub decode-pairs(Str:D $encoded --> List) {
  my @pairs;

  for $encoded.split('&', :skip-empty) -> $pair {
    my ($name, $value) = $pair.split('=', 2);
    next unless $name.defined && $name ne '';
    @pairs.push: percent-decode($name) => percent-decode($value // '');
  }

  @pairs.List
}

sub parse-urlencoded(Str:D $encoded --> Hash) is export {
  my %params;
  normalize(%params, .key, .value) for decode-pairs($encoded);
  %params
}

sub parse-json(Str:D $body --> Hash) is export {
  return {} if $body eq '';

  my $data = from-json($body);
  $data ~~ Associative ?? $data.hash !! { _json => $data }
}

sub multipart-boundary(Str $content-type --> Str) {
  return Str without $content-type;
  return ~$0 if $content-type ~~ / 'boundary=' '"'? (<-[";]>+) /;
  Str
}

sub parse-multipart(Str:D $body, Str:D $boundary --> Hash) is export {
  my %params;
  my $delimiter = '--' ~ $boundary;

  for $body.split($delimiter) -> $segment {
    next if $segment eq '' || $segment.starts-with('--');

    my $part = $segment;
    $part .= subst(/^ \r?\n /, '');

    my $split = $part ~~ / \r?\n \r?\n /;
    next without $split;

    my $headers = $part.substr(0, $split.from);
    my $content = $part.substr($split.to).subst(/ \r?\n $/, '');

    next unless $headers ~~ / 'name="' (<-["]>*) '"' /;
    my $name = ~$0;

    if $headers ~~ / 'filename="' (<-["]>*) '"' / {
      my $filename = ~$0;
      my $type = $headers ~~ / 'Content-Type:' \s* (<-[\r\n]>+) / ?? ~$0.trim !! Str;
      normalize(%params, $name, { filename => $filename, content => $content, type => $type });
    } else {
      normalize(%params, $name, $content);
    }
  }

  %params
}

sub parse-body($request --> Hash) {
  my $content-type = $request.header('content-type') // '';

  return parse-json($request.body)        if $content-type.contains('application/json');
  return parse-multipart($request.body, multipart-boundary($content-type)) if $content-type.contains('multipart/form-data');
  return parse-urlencoded($request.body)  if $content-type.contains('application/x-www-form-urlencoded');

  {}
}

sub build-params(%path-params, $request --> MVC::Keayl::Parameters) is export {
  my %query = parse-urlencoded($request.query-string);
  my %body  = parse-body($request);

  MVC::Keayl::Parameters.new({ %query, %body, %path-params })
}
