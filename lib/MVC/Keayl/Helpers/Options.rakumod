use v6.d;
use MVC::Keayl::SafeString;
use MVC::Keayl::Helpers::Tag;

unit module MVC::Keayl::Helpers::Options;

sub sanitize-to-id(Str:D $name --> Str) is export {
  $name.subst(/<[\[\(]>/, '_', :g).subst(/<[\]\)]>/, '', :g)
}

sub option-parts($choice --> List) {
  return ($choice.key, $choice.value, {}) if $choice ~~ Pair;

  if $choice ~~ Positional {
    my @parts = $choice.list;
    return (@parts[0], @parts[1] // @parts[0], (@parts[2] // {}).hash);
  }

  ($choice, $choice, {})
}

sub selected-set($selected --> List) {
  ($selected ~~ Positional ?? $selected.list !! ($selected,)).grep(*.defined).map(~*).list
}

sub member-value($item, $accessor) {
  return $item."$accessor"() if $item.^can(~$accessor);
  return $item{$accessor}    if $item ~~ Associative;
  ~$item
}

sub options-for-select(@choices, $selected?, $disabled? --> SafeString) is export {
  my @selected-values = selected-set($selected);
  my @disabled-values = selected-set($disabled);

  safe-join(@choices.map(-> $choice {
    my ($label, $value, %attrs) = option-parts($choice);

    %attrs<value>    = ~$value;
    %attrs<selected> = True if @selected-values.first({ $_ eq ~$value });
    %attrs<disabled> = True if @disabled-values.first({ $_ eq ~$value });

    content-tag('option', ~$label, %attrs)
  }))
}

sub options-from-collection-for-select(@collection, $value-method, $text-method, $selected? --> SafeString) is export {
  my @choices = @collection.map(-> $item {
    member-value($item, $text-method) => member-value($item, $value-method)
  });

  options-for-select(@choices, $selected)
}

sub grouped-options-for-select(@grouped, $selected? --> SafeString) is export {
  safe-join(@grouped.map(-> $group {
    my $label   = $group ~~ Pair ?? $group.key   !! $group[0];
    my @choices = ($group ~~ Pair ?? $group.value !! $group[1]).list;

    content-tag('optgroup', options-for-select(@choices, $selected), %( label => ~$label ))
  }))
}

sub select-tag(Str:D $name, $option-tags, %options? --> SafeString) is export {
  my %attrs = %options // {};

  my $multiple      = %attrs<multiple>:delete;
  my $include-blank = %attrs<include-blank>:delete;
  my $prompt        = %attrs<prompt>:delete;

  my $field-name = $name;

  if $multiple {
    %attrs<multiple> = True;
    $field-name ~= '[]';
  }

  %attrs<name>  = $field-name;
  %attrs<id>  //= sanitize-to-id($name);

  my @prefix;
  @prefix.push(content-tag('option', $prompt ~~ Str ?? ~$prompt !! 'Please select', %( value => '' ))) if $prompt;
  @prefix.push(content-tag('option', '', %( value => '' ))) if $include-blank && !$prompt;

  my $inner = $option-tags ~~ SafeString ?? $option-tags !! html-safe(~$option-tags);

  content-tag('select', safe-join([|@prefix, $inner]), %attrs)
}

my @default-time-zones = (
  'International Date Line West', 'Hawaii', 'Alaska', 'Pacific Time (US & Canada)',
  'Mountain Time (US & Canada)', 'Central Time (US & Canada)', 'Eastern Time (US & Canada)',
  'Atlantic Time (Canada)', 'UTC', 'London', 'Berlin', 'Paris', 'Madrid', 'Moscow',
  'Kolkata', 'Singapore', 'Tokyo', 'Sydney', 'Auckland',
);

sub time-zone-select(Str:D $name, $selected?, %options?, :@zones = @default-time-zones, :@priority-zones --> SafeString) is export {
  my @ordered = @priority-zones ?? (|@priority-zones, |@zones) !! @zones;

  select-tag($name, options-for-select(@ordered.list, $selected), %options // {})
}

my @month-names = <January February March April May June July August September October November December>;

sub date-component($value, Str:D $part) {
  return Nil without $value;

  given $part {
    when 'year'   { return $value.year       if $value ~~ Dateish }
    when 'month'  { return $value.month      if $value ~~ Dateish }
    when 'day'    { return $value.day        if $value ~~ Dateish }
    when 'hour'   { return $value.hour       if $value ~~ DateTime }
    when 'minute' { return $value.minute     if $value ~~ DateTime }
    when 'second' { return $value.second.Int if $value ~~ DateTime }
  }

  Nil
}

sub part-select(Str:D $field, @choices, $selected, %options --> SafeString) {
  my $prefix = %options<prefix> // 'date';
  my $name   = $prefix ~ '[' ~ $field ~ ']';

  select-tag($name, options-for-select(@choices, $selected.defined ?? ~$selected !! Nil), %( id => $prefix ~ '_' ~ $field ))
}

sub select-year($selected?, Int :$start-year, Int :$end-year, Str :$field-name = 'year', *%options --> SafeString) is export {
  my $current = date-component($selected, 'year') // ($selected ~~ Int ?? $selected !! Nil);

  my $from = $start-year // (($current // 2020) - 5);
  my $to   = $end-year   // (($current // 2030) + 5);

  my @years = $from <= $to ?? ($from .. $to).list !! ($from ... $to).list;

  part-select($field-name, @years.map({ $_ => $_ }), $current, %options)
}

sub select-month($selected?, Bool :$use-numbers = False, Str :$field-name = 'month', *%options --> SafeString) is export {
  my $current = date-component($selected, 'month') // ($selected ~~ Int ?? $selected !! Nil);

  my @choices = (1 .. 12).map(-> $number {
    ($use-numbers ?? sprintf('%02d', $number) !! @month-names[$number - 1]) => $number
  });

  part-select($field-name, @choices, $current, %options)
}

sub select-day($selected?, Str :$field-name = 'day', *%options --> SafeString) is export {
  my $current = date-component($selected, 'day') // ($selected ~~ Int ?? $selected !! Nil);

  part-select($field-name, (1 .. 31).map({ $_ => $_ }), $current, %options)
}

sub select-hour($selected?, Str :$field-name = 'hour', *%options --> SafeString) is export {
  my $current = date-component($selected, 'hour');

  part-select($field-name, (0 .. 23).map({ sprintf('%02d', $_) => $_ }), $current, %options)
}

sub select-minute($selected?, Str :$field-name = 'minute', *%options --> SafeString) is export {
  my $current = date-component($selected, 'minute');

  part-select($field-name, (0 .. 59).map({ sprintf('%02d', $_) => $_ }), $current, %options)
}

sub select-second($selected?, Str :$field-name = 'second', *%options --> SafeString) is export {
  my $current = date-component($selected, 'second');

  part-select($field-name, (0 .. 59).map({ sprintf('%02d', $_) => $_ }), $current, %options)
}

sub select-date($selected?, *%options --> SafeString) is export {
  safe-join([
    select-year($selected, |%options),
    select-month($selected, |%options),
    select-day($selected, |%options),
  ], "\n")
}

sub select-time($selected?, *%options --> SafeString) is export {
  safe-join([
    select-hour($selected, |%options),
    select-minute($selected, |%options),
  ], "\n")
}

sub multiparam-select(Str:D $prefix, Int:D $position, @choices, $selected --> SafeString) is export {
  my $name = $prefix ~ '(' ~ $position ~ 'i)';
  my $id   = $name.subst(/<[\[\(]>/, '_', :g).subst(/<[\]\)]>/, '', :g);

  select-tag($name, options-for-select(@choices.list, $selected.defined ?? ~$selected !! Nil), %( :$id ))
}

sub month-choices(--> List) is export {
  (1 .. 12).map({ @month-names[$_ - 1] => $_ }).list
}
