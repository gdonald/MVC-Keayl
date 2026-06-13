use v6.d;
use JSON::Fast;
use YAMLish;
use MVC::Keayl::I18n::Pluralization;
use MVC::Keayl::Helpers::Number;

unit class MVC::Keayl::I18n;

class X::MVC::Keayl::I18n::MissingTranslation is Exception {
  has Str $.locale;
  has Str $.key;

  method message(--> Str) { "translation missing: $!locale.$!key" }
}

class X::MVC::Keayl::I18n::MissingInterpolation is Exception {
  has Str $.name;
  has Str $.string;

  method message(--> Str) { "missing interpolation argument '$!name' in \"$!string\"" }
}

has %.store;
has Str  $.default-locale  = 'en';
has      @.available-locales;
has %.fallbacks;
has Bool $.use-fallbacks   = True;
has Bool $.raise-on-missing = False;
has Str  $!current-locale;

sub deep-merge(%base, %overrides --> Hash) {
  my %result = %base;

  for %overrides.kv -> $key, $value {
    if %result{$key} ~~ Associative && $value ~~ Associative {
      %result{$key} = deep-merge(%result{$key}, $value);
    } else {
      %result{$key} = $value;
    }
  }

  %result
}

method locale(--> Str) {
  $*KEAYL-I18N-LOCALE // $!current-locale // $!default-locale
}

method set-locale(Str:D $locale --> ::?CLASS) {
  $!current-locale = $locale;
  self
}

method with-locale(Str:D $locale, &block) {
  my $*KEAYL-I18N-LOCALE = $locale;
  block()
}

method available-locales(--> List) {
  return @!available-locales.List if @!available-locales;
  %!store.keys.sort.List
}

method is-available(Str:D $locale --> Bool) {
  self.available-locales.grep($locale).Bool
}

method store-translations(Str:D $locale, %tree --> ::?CLASS) {
  %!store{$locale} = deep-merge(%!store{$locale} // {}, %tree);
  self
}

method load-file(IO() $path --> ::?CLASS) {
  my %data = do given $path.extension.lc {
    when 'yml' | 'yaml' { load-yaml($path.slurp) }
    when 'json'         { from-json($path.slurp) }
    default             { die "unknown locale file type: {$path.basename}" }
  };

  self.store-translations($_, %data{$_}) for %data.keys;
  self
}

method load-locales(IO() $dir --> ::?CLASS) {
  return self unless $dir.d;

  for $dir.dir.grep({ .extension.lc eq any('yml', 'yaml', 'json') }).sort -> $file {
    self.load-file($file);
  }

  self
}

method candidate-locales(Str:D $locale --> List) {
  return ($locale,).List unless $!use-fallbacks;

  my @chain;
  my @queue = $locale;

  while @queue {
    my $current = @queue.shift;
    next if @chain.grep($current);

    @chain.push($current);
    @queue.append(|(%!fallbacks{$current} // []));
    @queue.push($current.subst(/ '-' <-[-]>+ $/, '')) if $current.contains('-');
  }

  @chain.push($!default-locale) unless @chain.grep($!default-locale);
  @chain.List
}

method !scope-parts($scope --> List) {
  return () without $scope;
  return $scope.map(*.Str).List if $scope ~~ Positional;
  $scope.Str.split('.').List
}

method !lookup-raw(Str:D $locale, $key, :$scope) {
  my @parts = (self!scope-parts($scope), $key.Str.split('.')).flat;
  my $node  = %!store{$locale};

  for @parts -> $segment {
    return Nil without $node;
    return Nil unless $node ~~ Associative;
    $node = $node{$segment};
  }

  $node
}

method !interpolate(Str:D $string, %values --> Str) {
  $string.subst(/ '%{' (<-[}]>+) '}' /, -> $/ {
    my $name = ~$0;

    die X::MVC::Keayl::I18n::MissingInterpolation.new(:$name, :$string)
      unless %values{$name}:exists;

    ~%values{$name}
  }, :g)
}

method !render-entry($entry, Str:D $locale, %values, :$count --> Str) {
  if $entry ~~ Associative {
    die "translation entry is not a string" unless $count.defined;

    my $category = $count == 0 && ($entry<zero>:exists)
      ?? 'zero'
      !! plural-category($locale, $count.abs);

    my $chosen = $entry{$category} // $entry<other>;
    die "missing plural category '$category'" without $chosen;

    return self!interpolate(~$chosen, %values);
  }

  self!interpolate(~$entry, %values)
}

method !resolve-default($default, @locales, %values, :$count) {
  return Nil without $default;

  my @candidates = $default ~~ Positional ?? $default.list !! ($default,);

  for @candidates -> $candidate {
    if $candidate ~~ Callable {
      my $result = $candidate();
      return self!render-entry($result, @locales[0], %values, :$count) if $result.defined;
      next;
    }

    for @locales -> $locale {
      my $entry = self!lookup-raw($locale, $candidate);
      return self!render-entry($entry, $locale, %values, :$count) if $entry.defined;
    }
  }

  my $last = @candidates.tail;
  return self!interpolate(~$last, %values) if $last ~~ Str;

  Nil
}

method translate($key, :$locale, :$default, :$count, :$scope, *%interpolations --> Str) {
  my $active   = $locale // self.locale;
  my @locales  = self.candidate-locales($active);
  my %values   = %interpolations;
  %values<count> = $count if $count.defined;

  for @locales -> $loc {
    my $entry = self!lookup-raw($loc, $key, :$scope);
    next without $entry;

    return self!render-entry($entry, $loc, %values, :$count);
  }

  with self!resolve-default($default, @locales, %values, :$count) -> $resolved {
    return $resolved;
  }

  my $missing-key = ((self!scope-parts($scope), $key.Str).flat).join('.');

  die X::MVC::Keayl::I18n::MissingTranslation.new(locale => $active, key => $missing-key)
    if $!raise-on-missing;

  "translation missing: $active.$missing-key"
}

method t(|args) { self.translate(|args) }

# Localization

method !names(Str:D $locale, Str:D $key --> List) {
  for self.candidate-locales($locale) -> $loc {
    my $value = self!lookup-raw($loc, $key);
    return $value.list if $value ~~ Positional;
  }

  ().List
}

method !scalar(Str:D $locale, Str:D $key) {
  for self.candidate-locales($locale) -> $loc {
    my $value = self!lookup-raw($loc, $key);
    return $value if $value.defined && $value !~~ Associative && $value !~~ Positional;
  }

  Nil
}

method !format-string(Str:D $locale, Str:D $key, Str:D $format --> Str) {
  for self.candidate-locales($locale) -> $loc {
    my $value = self!lookup-raw($loc, "$key.formats.$format");
    return $value.Str if $value.defined;
  }

  $format
}

method !strftime($object, Str:D $pattern, Str:D $locale --> Str) {
  my @month-names     = self!names($locale, 'date.month_names');
  my @abbr-months     = self!names($locale, 'date.abbr_month_names');
  my @day-names       = self!names($locale, 'date.day_names');
  my @abbr-days       = self!names($locale, 'date.abbr_day_names');

  my $hour   = $object.^can('hour')   ?? $object.hour   !! 0;
  my $minute = $object.^can('minute') ?? $object.minute !! 0;
  my $second = $object.^can('second') ?? $object.second.Int !! 0;

  my $meridian = $hour < 12 ?? 'am' !! 'pm';
  my $am-pm    = self!scalar($locale, "time.$meridian");

  $pattern.subst(/ '%' (<[\-]>?) (<[A..Za..z%]>) /, -> $/ {
    my $flag      = ~$0;
    my $directive = ~$1;

    given $directive {
      when 'Y' { $object.year.fmt('%04d') }
      when 'y' { ($object.year % 100).fmt('%02d') }
      when 'm' { $flag eq '-' ?? ~$object.month !! $object.month.fmt('%02d') }
      when 'd' { $flag eq '-' ?? ~$object.day   !! $object.day.fmt('%02d') }
      when 'e' { $object.day.fmt('%2d') }
      when 'B' { @month-names ?? ~@month-names[$object.month] !! ~$object.month }
      when 'b' { @abbr-months ?? ~@abbr-months[$object.month] !! ~$object.month }
      when 'A' { @day-names ?? ~@day-names[$object.day-of-week % 7] !! ~$object.day-of-week }
      when 'a' { @abbr-days ?? ~@abbr-days[$object.day-of-week % 7] !! ~$object.day-of-week }
      when 'H' { $hour.fmt('%02d') }
      when 'I' { (($hour % 12) || 12).fmt('%02d') }
      when 'M' { $minute.fmt('%02d') }
      when 'S' { $second.fmt('%02d') }
      when 'p' { $am-pm.defined ?? ~$am-pm !! $meridian.uc }
      when 'P' { $am-pm.defined ?? (~$am-pm).lc !! $meridian }
      when '%' { '%' }
      default  { '%' ~ $flag ~ $directive }
    }
  }, :g)
}

method localize($object, :$locale, Str :$format = 'default' --> Str) {
  my $active = $locale // self.locale;

  return self.number-to-delimited($object, :locale($active)) if $object ~~ Numeric;

  my $key = do given $object {
    when DateTime { 'time' }
    when Date     { 'date' }
    default       { $object ~~ Numeric ?? 'number' !! 'date' }
  };

  self!strftime($object, self!format-string($active, $key, $format), $active)
}

method l(|args) { self.localize(|args) }

# Number formatting driven by the locale store

method !number-defaults(Str:D $locale --> Hash) {
  (self!lookup-raw($locale, 'number.format') // {}).Hash
}

method !number-section(Str:D $locale, Str:D $section --> Hash) {
  my %base    = self!number-defaults($locale);
  my %section = (self!lookup-raw($locale, "number.$section.format") // {}).Hash;

  %( %base, %section )
}

method number-to-delimited($number, :$locale, *%overrides --> Str) {
  my %defaults = self!number-defaults($locale // self.locale);

  number-with-delimiter(
    $number,
    delimiter => (%overrides<delimiter> // %defaults<delimiter> // ','),
    separator => (%overrides<separator> // %defaults<separator> // '.'),
  )
}

method number-to-currency($number, :$locale, *%overrides --> Str) {
  my %format = self!number-section($locale // self.locale, 'currency');

  number-to-currency(
    $number,
    unit      => (%overrides<unit>      // %format<unit>      // '$'),
    precision => (%overrides<precision> // %format<precision> // 2),
    delimiter => (%overrides<delimiter> // %format<delimiter> // ','),
    separator => (%overrides<separator> // %format<separator> // '.'),
    format    => (%overrides<format>    // %format<format>    // '%u%n'),
  )
}

method number-to-percentage($number, :$locale, *%overrides --> Str) {
  my %format = self!number-section($locale // self.locale, 'percentage');

  number-to-percentage(
    $number,
    precision => (%overrides<precision> // %format<precision> // 2),
    delimiter => (%overrides<delimiter> // %format<delimiter> // ''),
    separator => (%overrides<separator> // %format<separator> // '.'),
  )
}

method number-to-human-size($bytes, :$locale, *%overrides --> Str) {
  number-to-human-size(
    $bytes,
    precision => (%overrides<precision> // 2),
  )
}

# Model and form integration

sub underscore(Str:D $word --> Str) {
  $word.subst(/<?after .> <:Lu>/, { '_' ~ $/.Str }, :g).lc
}

sub model-key($model --> Str) {
  return underscore($model.subst(/<[\s\-]>/, '_', :g)) if $model ~~ Str;

  my $name = ($model ~~ Mu:U ?? $model.^name !! $model.^name);
  underscore($name.subst(/^ 'GLOBAL::' /, '').subst(/^ .* '::' /, ''))
}

sub humanize(Str:D $value --> Str) {
  my $text = $value.subst(/ '_id' $ /, '').subst(/<[_\-]>/, ' ', :g);
  $text.subst(/^ . /, *.uc)
}

method human-attribute-name($model, Str:D $attribute, *%options --> Str) {
  my $key = model-key($model);

  self.translate(
    "activerecord.attributes.$key.$attribute",
    default => ["attributes.$attribute", humanize($attribute)],
    |%options,
  )
}

method human-model-name($model, *%options --> Str) {
  my $key = model-key($model);

  self.translate(
    "activerecord.models.$key",
    default => humanize($key),
    |%options,
  )
}

method translate-error($model, Str:D $attribute, Str:D $type, *%options --> Str) {
  my $key = model-key($model);

  self.translate(
    "activerecord.errors.models.$key.attributes.$attribute.$type",
    default => [
      "activerecord.errors.models.$key.$type",
      "activerecord.errors.messages.$type",
      "errors.attributes.$attribute.$type",
      "errors.messages.$type",
      humanize($type),
    ],
    |%options,
  )
}

method form-label($model, Str:D $attribute, *%options --> Str) {
  my $key = model-key($model);

  self.translate(
    "helpers.label.$key.$attribute",
    default => self.human-attribute-name($model, $attribute),
    |%options,
  )
}

method form-placeholder($model, Str:D $attribute, *%options --> Str) {
  my $key = model-key($model);

  self.translate(
    "helpers.placeholder.$key.$attribute",
    default => self.human-attribute-name($model, $attribute),
    |%options,
  )
}

method submit-default($model, Str:D $action = 'submit', *%options --> Str) {
  my $key = model-key($model);

  self.translate(
    "helpers.submit.$key.$action",
    default => ["helpers.submit.$action", humanize($action)],
    model   => self.human-model-name($model),
    |%options,
  )
}
