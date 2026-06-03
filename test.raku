#!/usr/bin/env raku

use v6.d;

$*OUT.out-buffer = False;

%*ENV<AUTHOR_TESTING> = 1;

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
