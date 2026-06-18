use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Job;
use MVC::Keayl::Job::QueueAdapter::Test;
use MVC::Keayl::Job::QueueAdapter::Database;
use MVC::Keayl::Job::GlobalID;

my @perform-sink;
my @db-ran;
my @db-order;
my @db-widget-ran;

class JobFeatRecordJob is MVC::Keayl::Job {
  method perform($sink, $value) { $sink.push: $value }
}

class JobFeatFlakyJob is MVC::Keayl::Job {
  method perform($sink) { $sink.push('try'); die 'transient' }
}
JobFeatFlakyJob.retry-on(Exception, wait => 0, attempts => 3);

class JobFeatDiscardJob is MVC::Keayl::Job {
  method perform($sink) { $sink.push('ran'); die 'nope' }
}
JobFeatDiscardJob.discard-on(Exception);

class JobFeatRescueJob is MVC::Keayl::Job {
  has @.log;
  method perform { die 'oops' }
}
JobFeatRescueJob.rescue-from(Exception, -> $job, $error { $job.log.push('rescued:' ~ $error.message) });

class JobFeatCallbackJob is MVC::Keayl::Job {
  method perform { @perform-sink.push('perform') }
}
JobFeatCallbackJob.before-perform(-> $j { @perform-sink.push('before') });
JobFeatCallbackJob.after-perform(-> $j { @perform-sink.push('after') });

class JobFeatEnqueueJob is MVC::Keayl::Job {
  method perform { }
}
JobFeatEnqueueJob.before-enqueue(-> $j { @perform-sink.push('enqueued') });

# Declared in GLOBAL so the GlobalID locator can resolve it by name from the
# library, which behave's per-file spec scope otherwise hides.
class GLOBAL::JobFeatWidget {
  has $.id;
  method find($id) { JobFeatWidget.new(id => $id.Int) }
}

class JobFeatDbRecordJob is MVC::Keayl::Job {
  method perform($value) { @db-ran.push($value) }
}

class JobFeatDbWidgetJob is MVC::Keayl::Job {
  method perform($widget) { @db-widget-ran.push($widget.id) }
}

class JobFeatDbPriorityJob is MVC::Keayl::Job {
  method perform($label) { @db-order.push($label) }
}

describe 'set', {
  before-each({ MVC::Keayl::Job.reset-queue-adapter });

  it 'assigns the queue and priority', {
    my $adapter = MVC::Keayl::Job::QueueAdapter::Test.new;
    MVC::Keayl::Job.queue-adapter($adapter);
    JobFeatRecordJob.set(queue => 'low', priority => 7).perform-later([], 1);
    expect($adapter.enqueued[0].queue-name eq 'low' && $adapter.enqueued[0].priority == 7).to.be-truthy;
    MVC::Keayl::Job.reset-queue-adapter;
  }

  it 'schedules relative to the clock with wait', {
    MVC::Keayl::Job.clock(sub { 1000 });
    my $adapter = MVC::Keayl::Job::QueueAdapter::Test.new;
    MVC::Keayl::Job.queue-adapter($adapter);
    JobFeatRecordJob.set(wait => 60).perform-later([], 1);
    expect($adapter.enqueued[0].scheduled-at).to.be(1060);
    MVC::Keayl::Job.reset-queue-adapter;
    MVC::Keayl::Job.reset-clock;
  }

  it 'schedules at an absolute time with wait-until', {
    my $adapter = MVC::Keayl::Job::QueueAdapter::Test.new;
    MVC::Keayl::Job.queue-adapter($adapter);
    JobFeatRecordJob.set(wait-until => 5000).perform-later([], 1);
    expect($adapter.enqueued[0].scheduled-at).to.be(5000);
    MVC::Keayl::Job.reset-queue-adapter;
  }
}

describe 'retry-on', {
  before-each({ MVC::Keayl::Job.reset-queue-adapter });

  it 'runs the job up to the attempt limit', {
    my @tries;
    expect({ JobFeatFlakyJob.perform-now(@tries) }).to.throw;
  }

  it 'stops after the attempt limit', {
    my @tries;
    try JobFeatFlakyJob.perform-now(@tries);
    expect(@tries.elems).to.be(3);
  }
}

describe 'discard-on', {
  before-each({ MVC::Keayl::Job.reset-queue-adapter });

  it 'swallows a matching error', {
    my @ran;
    expect({ JobFeatDiscardJob.perform-now(@ran) }).not.to.throw;
  }

  it 'still runs the discarded job once', {
    my @ran;
    JobFeatDiscardJob.perform-now(@ran);
    expect(@ran).to.be(['ran']);
  }
}

describe 'rescue-from', {
  it 'runs its handler on a matching error', {
    my $job = JobFeatRescueJob.new;
    $job.execute;
    expect($job.log.head).to.be('rescued:oops');
  }
}

describe 'perform callbacks', {
  it 'wrap perform with before and after', {
    @perform-sink = ();
    JobFeatCallbackJob.perform-now;
    expect(@perform-sink.join(',')).to.be('before,perform,after');
  }
}

describe 'enqueue callbacks', {
  it 'run when the job is enqueued', {
    MVC::Keayl::Job.reset-queue-adapter;
    @perform-sink = ();
    JobFeatEnqueueJob.perform-later;
    expect(@perform-sink).to.be(['enqueued']);
  }
}

describe 'global ids', {
  it 'serialize a record to a global id', {
    expect(to-gid(JobFeatWidget.new(id => 42))).to.be('gid://keayl/JobFeatWidget/42');
  }

  it 'locate a record from a global id', {
    expect(locate('gid://keayl/JobFeatWidget/42').id).to.be(42);
  }

  it 'locate nothing for an unresolvable id', {
    expect(locate('gid://keayl/JobFeatMissing/1') =:= Nil).to.be-truthy;
  }

  it 'serialize a record argument to a global id', {
    my %serialized = serialize-arguments(\('label', JobFeatWidget.new(id => 5)));
    expect(%serialized<positional>[0] eq 'label' && %serialized<positional>[1]<_keayl_gid> eq 'gid://keayl/JobFeatWidget/5').to.be-truthy;
  }

  it 'deserialize a record argument back to the record', {
    my %serialized = serialize-arguments(\(JobFeatWidget.new(id => 5)));
    expect(deserialize-arguments(%serialized).list[0].id).to.be(5);
  }
}

describe 'the database adapter', {
  before-each({
    MVC::Keayl::Job.reset-queue-adapter;
    @db-ran = ();
    @db-order = ();
    @db-widget-ran = ();
  });

  it 'persists a job until worked', {
    my $adapter = MVC::Keayl::Job::QueueAdapter::Database.new;
    MVC::Keayl::Job.queue-adapter($adapter);
    JobFeatDbRecordJob.perform-later(1);
    expect($adapter.store.all.elems == 1 && @db-ran.elems == 0).to.be-truthy;
    MVC::Keayl::Job.reset-queue-adapter;
  }

  it 'runs and removes a worked job', {
    my $adapter = MVC::Keayl::Job::QueueAdapter::Database.new;
    MVC::Keayl::Job.queue-adapter($adapter);
    JobFeatDbRecordJob.perform-later(1);
    $adapter.work;
    expect(@db-ran.head == 1 && $adapter.store.all.elems == 0).to.be-truthy;
    MVC::Keayl::Job.reset-queue-adapter;
  }

  it 'does not work a future-scheduled job early', {
    my $time = 1000;
    my $adapter = MVC::Keayl::Job::QueueAdapter::Database.new(clock => sub { $time });
    MVC::Keayl::Job.queue-adapter($adapter);
    JobFeatDbRecordJob.set(wait-until => 2000).perform-later(9);
    $adapter.work;
    expect(@db-ran).to.be([]);
    MVC::Keayl::Job.reset-queue-adapter;
  }

  it 'works a record argument by relocating it', {
    my $adapter = MVC::Keayl::Job::QueueAdapter::Database.new;
    MVC::Keayl::Job.queue-adapter($adapter);
    JobFeatDbWidgetJob.perform-later(JobFeatWidget.new(id => 99));
    $adapter.work;
    expect(@db-widget-ran).to.be([99]);
    MVC::Keayl::Job.reset-queue-adapter;
  }

  it 'works higher-priority jobs first', {
    my $adapter = MVC::Keayl::Job::QueueAdapter::Database.new;
    MVC::Keayl::Job.queue-adapter($adapter);
    JobFeatDbPriorityJob.set(priority => 1).perform-later('low');
    JobFeatDbPriorityJob.set(priority => 9).perform-later('high');
    $adapter.work;
    expect(@db-order).to.be(['high', 'low']);
    MVC::Keayl::Job.reset-queue-adapter;
  }
}
