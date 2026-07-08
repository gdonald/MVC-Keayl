#!/usr/bin/env raku

use v6.d;

$*OUT.out-buffer = False;

%*ENV<AUTHOR_TESTING> = 1;

# Run the suite in the test environment so apps booted through the config loader
# default to the silent log level and their request logging stays out of the
# test output.
%*ENV<KEAYL_ENV> = 'test';

chdir $*PROGRAM.parent;

my $jobs = max(2, ($*KERNEL.cpu-cores // 2) - 2);

my @all-stages = (
  { :name<prove6>, :dir<t>,     :cmd['prove6', "-j$jobs", '-Ilib', 't'] },
  { :name<behave>, :dir<specs>, :cmd['behave', '--parallel', $jobs.Str] },
);

my $only = @*ARGS[0];

my @stages = $only.defined
  ?? @all-stages.grep({ .<name> eq $only })
  !! @all-stages;

if $only.defined && !@stages {
  note "Unknown stage '$only'. Available: @all-stages.map(*<name>).join(', ')";
  exit 2;
}

my %durations;
my $total-start = now;

sub format-ts(--> Str) {
  my $d = DateTime.now;
  sprintf '%04d-%02d-%02d %02d:%02d:%02d',
  $d.year, $d.month, $d.day,
  $d.hour, $d.minute, $d.second.Int;
}

# Precompile every provided module once, single-threaded, so the parallel
# prove6 and behave workers read a populated precomp store instead of racing to
# write it (a cold-precomp race can segfault MoarVM).
sub warm-precomp() {
  return unless 'META6.json'.IO.e;

  my @modules;
  my $in-provides = False;

  for 'META6.json'.IO.lines -> $line {
    unless $in-provides {
      $in-provides = True if $line ~~ / '"provides"' /;
      next;
    }
    last if $line ~~ /^ \s* '}'/;
    @modules.push(~$0) if $line ~~ / '"' (<-["]>+) '"' \s* ':' /;
  }

  return unless @modules;

  say "==> [{format-ts()}] warming precompilation (@modules.elems() modules)";
  run 'raku', '-Ilib', '-e', @modules.map({ "need $_;" }).join("\n");
  say '';
}

END {
  if %durations {
    say '';
    say '==> Runtimes';
    for @stages -> $s {
      next unless %durations{$s<name>}:exists;
      printf "  %-9s %7.2fs\n", $s<name>, %durations{$s<name>};
    }
    printf "  %-9s %7.2fs\n", 'total', (now - $total-start).Num;
  }
}

warm-precomp() if @stages;

for @stages -> $s {
  unless $s<dir>.IO.d && $s<dir>.IO.dir.elems {
    say "==> [{format-ts()}] skip $s<name> ($s<dir>/ is empty)";
    say '';
    next;
  }

  my @cmd = $s<cmd>.list;
  say "==> [{format-ts()}] @cmd.join(' ')";

  my $start = now;
  my $proc  = run(|@cmd);
  %durations{$s<name>} = (now - $start).Num;

  exit $proc.exitcode unless $proc.exitcode == 0;
  say '';
}
