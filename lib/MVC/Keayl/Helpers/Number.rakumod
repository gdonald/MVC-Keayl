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

sub number-to-phone($number, Bool :$area-code = False, Str :$delimiter = '-', :$extension, :$country-code --> Str) is export {
  my $digits = (~$number).trim;

  my $formatted = $area-code
    ?? $digits.subst(/(\d ** 1..3) (\d ** 3) (\d ** 4) $/, { '(' ~ $0 ~ ') ' ~ $1 ~ '-' ~ $2 })
    !! $digits.subst(/(\d ** 0..3) (\d ** 3) (\d ** 4) $/, { ($0 eq '' ?? '' !! $0 ~ $delimiter) ~ $1 ~ $delimiter ~ $2 });

  my $prefix = $country-code.defined ?? '+' ~ $country-code ~ $delimiter !! '';
  my $suffix = $extension.defined    ?? ' x ' ~ $extension                !! '';

  $prefix ~ $formatted ~ $suffix
}

sub round-significant($value, Int $digits) {
  return $value if $value == 0;

  my $magnitude = floor(log($value.abs) / log(10));
  my $factor    = 10 ** ($digits - 1 - $magnitude);

  ($value * $factor).round / $factor
}

sub number-to-human($number, Int :$precision = 3, Str :$separator = '.' --> Str) is export {
  my @units = (
    10 ** 15 => 'Quadrillion',
    10 ** 12 => 'Trillion',
    10 ** 9  => 'Billion',
    10 ** 6  => 'Million',
    10 ** 3  => 'Thousand',
  );

  my $abs     = $number.abs;
  my $divisor = 1;
  my $unit    = '';

  for @units -> $pair {
    if $abs >= $pair.key {
      $divisor = $pair.key;
      $unit    = $pair.value;
      last;
    }
  }

  my $rounded = round-significant($number / $divisor, $precision);
  my $text    = $rounded.Str;
  $text       = $text.subst('.', $separator) if $separator ne '.';

  $unit ?? $text ~ ' ' ~ $unit !! $text
}

sub number-to-human-size($bytes, Int :$precision = 2 --> Str) is export {
  return ($bytes == 1 ?? '1 Byte' !! "$bytes Bytes") if $bytes < 1024;

  my @units = <KB MB GB TB PB EB>;
  my $exp   = min(floor(log($bytes) / log(1024)), @units.elems);
  my $size  = $bytes / (1024 ** $exp);

  my $formatted = sprintf('%.*f', $precision, $size).subst(/ '.'? '0'+ $/, '');

  $formatted ~ ' ' ~ @units[$exp - 1]
}
