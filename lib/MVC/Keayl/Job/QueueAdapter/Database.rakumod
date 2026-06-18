use v6.d;
use MVC::Keayl::Job::QueueAdapter;
use MVC::Keayl::Job;
use MVC::Keayl::Job::GlobalID;

role MVC::Keayl::Job::QueueAdapter::Database::Store {
  method insert(%record)               { ... }
  method eligible(Real:D $now --> List) { ... }
  method remove($id)                   { ... }
  method all(--> List)                 { ... }
}

class MVC::Keayl::Job::QueueAdapter::Database::MemoryStore does MVC::Keayl::Job::QueueAdapter::Database::Store {
  has @!rows;
  has Int $!seq = 0;

  method insert(%record) {
    %record<id> = ++$!seq;
    @!rows.push(%record);
    %record
  }

  method eligible(Real:D $now --> List) {
    @!rows
      .grep({ !.<scheduled-at>.defined || .<scheduled-at> <= $now })
      .sort({ ($^b<priority> // 0) <=> ($^a<priority> // 0) })
      .List
  }

  method remove($id) {
    @!rows = @!rows.grep({ .<id> != $id });
  }

  method all(--> List) { @!rows.List }
}

class MVC::Keayl::Job::QueueAdapter::Database does MVC::Keayl::Job::QueueAdapter {
  has MVC::Keayl::Job::QueueAdapter::Database::Store $.store = MVC::Keayl::Job::QueueAdapter::Database::MemoryStore.new;
  has &.clock = sub { now };

  method enqueue(MVC::Keayl::Job:D $job) {
    $!store.insert(%(
      job-class      => $job.WHAT,
      job-class-name => $job.^name.subst(/^ 'GLOBAL::' /, ''),
      arguments      => serialize-arguments($job.arguments),
      queue-name     => $job.queue-name,
      priority       => $job.priority,
      scheduled-at   => ($job.scheduled-at.defined ?? $job.scheduled-at.Numeric !! Nil),
    ));

    $job
  }

  method !locate-class(%row) {
    return %row<job-class> if %row<job-class>.defined || %row<job-class> ~~ MVC::Keayl::Job;

    my $resolved = try ::(%row<job-class-name>);
    $resolved =:= Nil || $resolved ~~ Failure ?? Nil !! $resolved
  }

  method work(--> Int) {
    my $now  = &!clock().Numeric;
    my @rows = $!store.eligible($now);

    for @rows -> %row {
      my $class = self!locate-class(%row);
      next if $class =:= Nil;

      my $job = $class.new(
        arguments  => deserialize-arguments(%row<arguments>),
        queue-name => %row<queue-name>,
        priority   => %row<priority>,
      );

      $job.execute;
      $!store.remove(%row<id>);
    }

    @rows.elems
  }
}
