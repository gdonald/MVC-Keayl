# Background jobs

`MVC::Keayl::Job` runs work either now or later. A job subclass implements
`perform`, and the framework runs it synchronously or hands it to a queue adapter
for later execution.

## Defining a job

```perl6
class WelcomeJob is MVC::Keayl::Job {
  method perform($user-id) {
    # send a welcome email, warm a cache, ...
  }
}
```

- `WelcomeJob.perform-now($id)` runs `perform` immediately and returns its result.
- `WelcomeJob.perform-later($id)` enqueues the job on the configured adapter and
  returns the job. Positional and named arguments both pass straight through to
  `perform`.

Every job is on the `default` queue unless changed.

## Queue adapters

The adapter decides what "later" means. Set it once, for all jobs:

```perl6
MVC::Keayl::Job.queue-adapter(MVC::Keayl::Job::QueueAdapter::Async.new);
```

A queue adapter is any `MVC::Keayl::Job::QueueAdapter` (a role with one
`enqueue($job)` method). Three are built in:

- **Inline** (`...::QueueAdapter::Inline`) runs the job on enqueue, so
  `perform-later` behaves like `perform-now`.
- **Test** (`...::QueueAdapter::Test`) collects enqueued jobs in `enqueued`
  without running them. `perform-all` runs and drains them, `clear` empties the
  queue.
- **Async** (`...::QueueAdapter::Async`) runs each job on its own thread and
  records the promises; `wait` blocks until the enqueued jobs finish.

With no adapter configured, `perform-later` runs the job inline, so a job is
always runnable without setup.

```perl6
my $adapter = MVC::Keayl::Job::QueueAdapter::Test.new;
MVC::Keayl::Job.queue-adapter($adapter);

WelcomeJob.perform-later(42);   # collected, not run
$adapter.perform-all;           # now it runs
```

`reset-queue-adapter` clears the configured adapter, returning to the inline
default.
