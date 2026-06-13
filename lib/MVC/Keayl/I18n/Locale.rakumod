use v6.d;

unit module MVC::Keayl::I18n::Locale;

sub base-locale(Str:D $locale --> Str) {
  $locale.split('-')[0].lc
}

sub match-available(Str $candidate, @available --> Str) is export {
  return Str without $candidate;
  return $candidate unless @available;
  return $candidate if @available.grep($candidate);

  my $base = base-locale($candidate);

  for @available -> $available {
    return $available if base-locale($available) eq $base;
  }

  Str
}

sub locale-from-param(%params, Str :$param = 'locale' --> Str) is export {
  my $value = %params{$param};
  return Str without $value;

  ($value ~~ Positional ?? $value.first !! $value).Str
}

sub parse-accept-language(Str $header --> List) is export {
  return ().List without $header;

  my @entries = $header.split(',').map(*.trim).grep(*.chars).map(-> $part {
    my ($tag, @params) = $part.split(';').map(*.trim);
    my $quality = 1.0;

    for @params -> $pair {
      $quality = +$0 if $pair ~~ / 'q=' (<[\d.]>+) /;
    }

    %( tag => $tag, quality => $quality );
  });

  @entries.grep({ .<tag> ne '*' }).sort({ -.<quality> }).map(*<tag>).List
}

sub locale-from-subdomain(Str $host --> Str) is export {
  return Str without $host;

  my @labels = $host.split('.');
  @labels.elems >= 3 ?? @labels[0] !! Str
}

sub locale-from-domain(Str $host --> Str) is export {
  return Str without $host;

  my @labels = $host.split('.');
  @labels.elems >= 2 ?? @labels[*-1] !! Str
}

sub raw-candidates($request, Str:D $strategy, Str:D $param --> List) {
  given $strategy {
    when 'param'     { (locale-from-param($request.query-params, :$param),).grep(*.defined).List }
    when 'header'    { parse-accept-language($request.header('accept-language')) }
    when 'subdomain' { (locale-from-subdomain($request.host),).grep(*.defined).List }
    when 'domain'    { (locale-from-domain($request.host),).grep(*.defined).List }
    default          { die "unknown locale strategy '$strategy'" }
  }
}

sub resolve-locale(
  $request,
  :$strategies = <param header>,
  :@available,
  Str :$default = 'en',
  Str :$param   = 'locale'
  --> Str
) is export {
  for $strategies.list -> $strategy {
    for raw-candidates($request, $strategy, $param) -> $candidate {
      my $matched = match-available($candidate, @available);
      return $matched if $matched.defined;
    }
  }

  $default
}

sub locale-url-options(Str $locale, Str :$param = 'locale' --> Hash) is export {
  $locale.defined ?? %( $param => $locale ) !! %()
}
