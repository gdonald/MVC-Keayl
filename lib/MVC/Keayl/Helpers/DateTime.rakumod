use v6.d;

unit module MVC::Keayl::Helpers::DateTime;

sub distance-of-time-in-words($from, $to = DateTime.now, Bool :$include-seconds = False --> Str) is export {
  my $seconds = abs(($to.Instant - $from.Instant).Real);
  my $minutes = ($seconds / 60).round;

  if $minutes <= 1 {
    unless $include-seconds {
      return $minutes == 0 ?? 'less than a minute' !! '1 minute';
    }

    my $whole = $seconds.round;
    return 'less than 5 seconds'  if $whole < 5;
    return 'less than 10 seconds' if $whole < 10;
    return 'less than 20 seconds' if $whole < 20;
    return 'half a minute'        if $whole < 40;
    return 'less than a minute'   if $whole < 60;
    return '1 minute';
  }

  return "$minutes minutes"                          if $minutes < 45;
  return 'about 1 hour'                              if $minutes < 90;
  return 'about ' ~ ($minutes / 60).round ~ ' hours' if $minutes < 1440;
  return '1 day'                                     if $minutes < 2520;
  return ($minutes / 1440).round ~ ' days'           if $minutes < 43200;
  return 'about 1 month'                             if $minutes < 86400;
  return ($minutes / 43200).round ~ ' months'        if $minutes < 525600;

  my $years = ($minutes / 525600).round;
  $years == 1 ?? 'about 1 year' !! "about $years years"
}

sub time-ago-in-words($from, $to = DateTime.now, Bool :$include-seconds = False --> Str) is export {
  distance-of-time-in-words($from, $to, :$include-seconds)
}
