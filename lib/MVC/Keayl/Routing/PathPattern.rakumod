use v6.d;
use MONKEY-SEE-NO-EVAL;

unit class MVC::Keayl::Routing::PathPattern;

sub read-ident(Str $source, $pos is rw --> Str) {
  my $start = $pos;
  $pos++ while $pos < $source.chars && $source.substr($pos, 1) ~~ /\w/;
  $source.substr($start, $pos - $start)
}

sub quote-literal(Str $text --> Str) {
  my $escaped = $text.subst('\\', '\\\\', :g).subst("'", "\\'", :g);
  "'" ~ $escaped ~ "'"
}

# Compile one level of the pattern (the top level, or the inside of a `(...)`
# group) into a Raku regex source fragment, collecting dynamic segment names.
sub compile-group(Str $source, $pos is rw, @names --> Str) {
  my @parts;

  while $pos < $source.chars {
    my $char = $source.substr($pos, 1);

    if $char eq ')' {
      last;
    } elsif $char eq '(' {
      $pos++;
      my $inner = compile-group($source, $pos, @names);
      $pos++ if $pos < $source.chars && $source.substr($pos, 1) eq ')';
      @parts.push("[ $inner ]?");
    } elsif $char eq ':' {
      $pos++;
      my $name = read-ident($source, $pos);
      @names.push($name);
      @parts.push("\$<$name>=[ <-[/.]>+ ]");
    } elsif $char eq '*' {
      $pos++;
      my $name = read-ident($source, $pos);
      @names.push($name);
      @parts.push("\$<$name>=[ .+ ]");
    } else {
      @parts.push(quote-literal($char));
      $pos++;
    }
  }

  @parts.join(' ')
}

sub compile-pattern(Str:D $source --> List) {
  my @names;
  my $pos = 0;
  my $body = compile-group($source, $pos, @names);

  ("rx\{ ^ $body \$ }".EVAL, |@names)
}

has Str   $.source;
has Regex $.regex;
has Str   @.names;
has       %.constraints;
has       %.defaults;

submethod BUILD(Str:D :$source, :%constraints, :%defaults, Bool :$format) {
  $!source = $format ?? $source ~ '(.:format)' !! $source;
  %!constraints = %constraints;
  %!defaults = %defaults;

  my ($regex, @names) = compile-pattern($!source);
  $!regex = $regex;
  @!names = @names;
}

method match(Str:D $path --> Hash) {
  my $matched = $path ~~ $!regex;
  return Nil without $matched;

  my %params = %!defaults.clone;

  for @!names -> $name {
    next without $matched{$name};
    %params{$name} = ~$matched{$name};
  }

  for %!constraints.kv -> $name, $constraint {
    next unless %params{$name}:exists && %params{$name}.defined;

    my $check = %params{$name} ~~ $constraint;
    return Nil unless $check && $check.from == 0 && $check.to == %params{$name}.chars;
  }

  %params
}
