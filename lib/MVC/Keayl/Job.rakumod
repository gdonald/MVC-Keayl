use v6.d;
use MVC::Keayl::Job::QueueAdapter;

unit class MVC::Keayl::Job;

my MVC::Keayl::Job::QueueAdapter $current-adapter;

has Capture $.arguments = \();
has Str     $.queue-name = 'default';

method queue-adapter(::?CLASS: MVC::Keayl::Job::QueueAdapter $adapter?) {
  $current-adapter = $adapter with $adapter;
  $current-adapter
}

method reset-queue-adapter(::?CLASS:) {
  $current-adapter = MVC::Keayl::Job::QueueAdapter;
}

method perform(|args) {
  die "{self.^name} must implement perform"
}

method execute() {
  self.perform(|$!arguments)
}

method perform-now(::?CLASS:U: |args) {
  self.new(arguments => args).execute
}

method perform-later(::?CLASS:U: |args) {
  my $job = self.new(arguments => args);

  with self.queue-adapter -> $adapter {
    $adapter.enqueue($job);
  } else {
    $job.execute;
  }

  $job
}
