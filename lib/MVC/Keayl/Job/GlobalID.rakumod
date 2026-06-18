use v6.d;

unit module MVC::Keayl::Job::GlobalID;

sub is-locatable($value --> Bool) {
  so $value.defined && $value !~~ Cool && $value.^can('id') && $value.WHAT.^can('find')
}

sub to-gid($record --> Str) is export {
  'gid://keayl/' ~ $record.^name.subst(/^ 'GLOBAL::' /, '') ~ '/' ~ $record.id
}

sub locate(Str:D $gid) is export {
  return Nil unless $gid ~~ / 'gid://keayl/' (<-[/]>+) '/' (.+) /;

  my $class = try ::(~$0);
  return Nil if $class =:= Nil || $class ~~ Failure;
  return Nil unless $class.^can('find');

  $class.find(~$1)
}

sub serialize-value($value) is export {
  return %( '_keayl_gid' => to-gid($value) ) if is-locatable($value);
  return $value.map(&serialize-value).Array  if $value ~~ Positional;
  return $value.map({ .key => serialize-value(.value) }).Hash if $value ~~ Associative;
  $value
}

sub deserialize-value($value) is export {
  if $value ~~ Associative {
    return locate($value<_keayl_gid>) if $value<_keayl_gid>:exists;
    return $value.map({ .key => deserialize-value(.value) }).Hash;
  }
  return $value.map(&deserialize-value).Array if $value ~~ Positional;
  $value
}

sub serialize-arguments(Capture:D $arguments --> Hash) is export {
  %(
    positional => $arguments.list.map(&serialize-value).Array,
    named      => $arguments.hash.map({ .key => serialize-value(.value) }).Hash,
  )
}

sub deserialize-arguments(%data --> Capture) is export {
  my @positional = (%data<positional> // []).map(&deserialize-value);
  my %named      = (%data<named> // {}).map({ .key => deserialize-value(.value) });

  Capture.new(list => @positional, hash => %named)
}
