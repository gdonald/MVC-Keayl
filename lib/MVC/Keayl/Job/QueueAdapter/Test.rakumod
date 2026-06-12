use v6.d;
use MVC::Keayl::Job::QueueAdapter;
use MVC::Keayl::Job;

unit class MVC::Keayl::Job::QueueAdapter::Test does MVC::Keayl::Job::QueueAdapter;

has @.enqueued;

method enqueue(MVC::Keayl::Job:D $job) {
  @!enqueued.push: $job;
  $job
}

method perform-all() {
  my @jobs = @!enqueued;
  @!enqueued = ();
  .execute for @jobs;
}

method clear() { @!enqueued = () }
