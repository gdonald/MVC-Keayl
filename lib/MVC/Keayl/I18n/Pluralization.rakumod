use v6.d;

unit module MVC::Keayl::I18n::Pluralization;

sub base-locale(Str:D $locale --> Str) {
  $locale.split('-')[0].lc
}

our %RULES =
  en => -> $count { $count == 1 ?? 'one' !! 'other' },

  ja => -> $count { 'other' },
  zh => -> $count { 'other' },
  ko => -> $count { 'other' },
  vi => -> $count { 'other' },

  fr => -> $count { $count.abs < 2 ?? 'one' !! 'other' },

  ru => -> $count {
    my $mod10  = $count % 10;
    my $mod100 = $count % 100;

    if $mod10 == 1 && $mod100 != 11 {
      'one'
    } elsif $mod10 ~~ 2..4 && $mod100 !~~ 12..14 {
      'few'
    } else {
      'many'
    }
  },

  pl => -> $count {
    my $mod10  = $count % 10;
    my $mod100 = $count % 100;

    if $count == 1 {
      'one'
    } elsif $mod10 ~~ 2..4 && $mod100 !~~ 12..14 {
      'few'
    } else {
      'many'
    }
  };

sub plural-rule(Str:D $locale --> Code) is export {
  %RULES{base-locale($locale)} // %RULES<en>
}

sub plural-category(Str:D $locale, $count --> Str) is export {
  plural-rule($locale)($count)
}

sub register-plural-rule(Str:D $locale, &rule --> Nil) is export {
  %RULES{base-locale($locale)} = &rule;
}
