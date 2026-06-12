use v6.d;
use MVC::Keayl::Job::QueueAdapter;
use MVC::Keayl::Job;

unit class MVC::Keayl::Job::QueueAdapter::Inline does MVC::Keayl::Job::QueueAdapter;

method enqueue(MVC::Keayl::Job:D $job) {
  $job.execute
}
