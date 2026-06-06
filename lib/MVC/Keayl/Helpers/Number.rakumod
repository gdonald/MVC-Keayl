use v6.d;

unit module MVC::Keayl::Helpers::Number;

sub number-with-delimiter($number, Str :$delimiter = ',', Str :$separator = '.' --> Str) is export {
  my $string = ~$number;
  my $sign   = '';

  if $string.starts-with('-') {
    $sign    = '-';
    $string .= substr(1);
  }

  my ($integer, $fraction) = $string.split('.', 2);
  my $grouped = $integer.flip.comb(3)>>.flip.reverse.join($delimiter);

  $sign ~ $grouped ~ ($fraction.defined ?? $separator ~ $fraction !! '')
}

sub number-to-currency($number, Str :$unit = '$', Int :$precision = 2, Str :$delimiter = ',', Str :$separator = '.', Str :$format = '%u%n' --> Str) is export {
  my $rounded   = sprintf('%.*f', $precision, $number.abs);
  my $delimited = number-with-delimiter($rounded, :$delimiter, :$separator);
  my $body      = $format.subst('%u', $unit).subst('%n', $delimited);

  $number < 0 ?? '-' ~ $body !! $body
}

sub number-to-percentage($number, Int :$precision = 2, Str :$delimiter = '', Str :$separator = '.' --> Str) is export {
  my $rounded   = sprintf('%.*f', $precision, $number);
  my $delimited = $delimiter ne '' ?? number-with-delimiter($rounded, :$delimiter, :$separator) !! $rounded.subst('.', $separator);

  $delimited ~ '%'
}

sub number-to-human-size($bytes, Int :$precision = 2 --> Str) is export {
  return ($bytes == 1 ?? '1 Byte' !! "$bytes Bytes") if $bytes < 1024;

  my @units = <KB MB GB TB PB EB>;
  my $exp   = min(floor(log($bytes) / log(1024)), @units.elems);
  my $size  = $bytes / (1024 ** $exp);

  my $formatted = sprintf('%.*f', $precision, $size).subst(/ '.'? '0'+ $/, '');

  $formatted ~ ' ' ~ @units[$exp - 1]
}
