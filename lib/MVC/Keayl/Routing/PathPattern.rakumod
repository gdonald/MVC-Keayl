use v6.d;
use MONKEY-SEE-NO-EVAL;

unit class MVC::Keayl::Routing::PathPattern;

sub read-ident(Str $source, $pos is rw --> Str) {
  my $start = $pos;
  $pos++ while $pos < $source.chars && $source.substr($pos, 1) ~~ /\w/;
  $source.substr($start, $pos - $start)
}

sub parse-group(Str $source, $pos is rw --> Array) {
  my @nodes;

  while $pos < $source.chars {
    my $char = $source.substr($pos, 1);

    if $char eq ')' {
      last;
    } elsif $char eq '(' {
      $pos++;
      my @inner = parse-group($source, $pos);
      $pos++ if $pos < $source.chars && $source.substr($pos, 1) eq ')';
      @nodes.push: { type => 'optional', children => @inner };
    } elsif $char eq ':' {
      $pos++;
      @nodes.push: { type => 'param', name => read-ident($source, $pos) };
    } elsif $char eq '*' {
      $pos++;
      @nodes.push: { type => 'glob', name => read-ident($source, $pos) };
    } else {
      @nodes.push: { type => 'literal', text => $char };
      $pos++;
    }
  }

  @nodes
}

sub quote-literal(Str $text --> Str) {
  my $escaped = $text.subst('\\', '\\\\', :g).subst("'", "\\'", :g);
  "'" ~ $escaped ~ "'"
}

sub node-regex(%node --> Str) {
  given %node<type> {
    when 'literal'  { quote-literal(%node<text>) }
    when 'param'    { "\$<{%node<name>}>=[ <-[/.]>+ ]" }
    when 'glob'     { "\$<{%node<name>}>=[ .+ ]" }
    when 'optional' { '[ ' ~ %node<children>.map(&node-regex).join(' ') ~ ' ]?' }
  }
}

sub names-in(@nodes, :$required --> List) {
  my @names;
  for @nodes -> %node {
    given %node<type> {
      when 'param' | 'glob' { @names.push(%node<name>) }
      when 'optional' { @names.append(names-in(%node<children>)) unless $required }
    }
  }
  @names.List
}

sub generate-part(@nodes, %params, %used --> Str) {
  my $out = '';

  for @nodes -> %node {
    given %node<type> {
      when 'literal' {
        $out ~= %node<text>;
      }
      when 'param' | 'glob' {
        %used{%node<name>} = True;
        $out ~= %params{%node<name>} // '';
      }
      when 'optional' {
        my @inner = names-in(%node<children>);
        $out ~= generate-part(%node<children>, %params, %used)
          if @inner.grep({ !(%params{$_}.defined) }).elems == 0;
      }
    }
  }

  $out
}

sub percent-encode(Str $text --> Str) {
  $text.subst(/<-[A..Za..z0..9._~-]>/, -> $match {
    $match.Str.encode('utf-8').list.map({ '%' ~ sprintf('%02X', $_) }).join
  }, :g)
}

has Str $.source;
has Regex $.regex;
has @.ast;
has Str @.names;
has Str @.required-names;
has %.constraints;
has %.defaults;

submethod BUILD(Str:D :$source, :%constraints, :%defaults, Bool :$format) {
  $!source = $format ?? $source ~ '(.:format)' !! $source;
  %!constraints = %constraints;
  %!defaults = %defaults;

  my $pos = 0;
  @!ast = parse-group($!source, $pos);
  @!names = names-in(@!ast);
  @!required-names = names-in(@!ast, :required);

  $!regex = ("rx\{ ^ " ~ @!ast.map(&node-regex).join(' ') ~ " \$ }").EVAL;
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

method generate(%params, Bool :$trailing = False, :$anchor --> Str) {
  my %used;
  my $path = generate-part(@!ast, { %!defaults, %params }, %used);

  $path ~= '/' if $trailing && $path ne '/' && !$path.ends-with('/');

  my @pairs;
  for %params.kv -> $key, $value {
    next if %used{$key};
    next without $value;
    @pairs.push: $key => $value;
  }

  my $query = @pairs
    ?? '?' ~ @pairs.sort(*.key).map({ percent-encode(.key.Str) ~ '=' ~ percent-encode(.value.Str) }).join('&')
    !! '';

  my $fragment = $anchor.defined ?? '#' ~ $anchor !! '';

  $path ~ $query ~ $fragment
}
