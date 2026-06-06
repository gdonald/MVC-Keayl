use v6.d;

unit class MVC::Keayl::ParameterFilter;

constant REDACTED = '[FILTERED]';

has @.filters = <passw secret token _key crypt salt certificate otp ssn>;
has @.also;

submethod TWEAK {
  @!filters.append(|@!also) if @!also;
}

method !matches(Str:D $key --> Bool) {
  for @!filters -> $filter {
    return True if $filter ~~ Regex && $key ~~ $filter;
    return True if $filter ~~ Str   && $key.lc.contains($filter.lc);
  }

  False
}

method !walk($value) {
  return self!walk-hash($value)                    if $value ~~ Associative;
  return $value.map({ self!walk($_) }).Array       if $value ~~ Positional;
  $value
}

method !walk-hash(%hash --> Hash) {
  my %result;

  for %hash.kv -> $key, $value {
    %result{$key} = self!matches(~$key) ?? REDACTED !! self!walk($value);
  }

  %result
}

method filter(%params --> Hash) {
  self!walk-hash(%params)
}
