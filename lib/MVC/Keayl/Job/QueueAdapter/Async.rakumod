use v6.d;
use MVC::Keayl::Job::QueueAdapter;
use MVC::Keayl::Job;

unit class MVC::Keayl::Job::QueueAdapter::Async does MVC::Keayl::Job::QueueAdapter;

has @.promises;

method enqueue(MVC::Keayl::Job:D $job) {
  my $promise = start { $job.execute };
  @!promises.push: $promise;

  $promise
}

method wait() {
  await @!promises;
  @!promises = ();
}
