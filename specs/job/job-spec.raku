use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Job;
use MVC::Keayl::Job::QueueAdapter::Inline;
use MVC::Keayl::Job::QueueAdapter::Test;
use MVC::Keayl::Job::QueueAdapter::Async;

class RecordJob is MVC::Keayl::Job {
  method perform($sink, $value) { $sink.push: $value }
}

class GreetJob is MVC::Keayl::Job {
  method perform($sink, :$name = 'world') { $sink.push: "hi $name" }
}

class BoomJob is MVC::Keayl::Job {
  method perform { die 'job failed' }
}

describe 'MVC::Keayl::Job perform-now', {
  it 'runs the job immediately', {
    my @ran;
    RecordJob.perform-now(@ran, 7);
    expect(@ran).to.be([7]);
  }

  it 'forwards named arguments to perform', {
    my @ran;
    GreetJob.perform-now(@ran, name => 'Ada');
    expect(@ran).to.be(['hi Ada']);
  }

  it 'raises for a job without a perform implementation', {
    expect({ MVC::Keayl::Job.perform-now }).to.throw;
  }

  it 'propagates an error raised inside perform', {
    expect({ BoomJob.perform-now }).to.throw;
  }
}

describe 'MVC::Keayl::Job queue', {
  it 'defaults to the default queue', {
    expect(RecordJob.new.queue-name).to.be('default');
  }
}

describe 'MVC::Keayl::Job perform-later', {
  before-each { MVC::Keayl::Job.reset-queue-adapter }

  it 'runs inline when no adapter is configured', {
    my @ran;
    RecordJob.perform-later(@ran, 3);
    expect(@ran).to.be([3]);
  }

  it 'runs through the inline adapter on enqueue', {
    MVC::Keayl::Job.queue-adapter(MVC::Keayl::Job::QueueAdapter::Inline.new);
    my @ran;
    RecordJob.perform-later(@ran, 5);
    expect(@ran).to.be([5]);
  }

  it 'returns the job instance', {
    MVC::Keayl::Job.queue-adapter(MVC::Keayl::Job::QueueAdapter::Test.new);
    my @ran;
    expect(RecordJob.perform-later(@ran, 1) ~~ RecordJob).to.be-truthy;
  }
}

describe 'MVC::Keayl::Job::QueueAdapter::Test', {
  before-each { MVC::Keayl::Job.reset-queue-adapter }

  it 'collects enqueued jobs without running them', {
    my $adapter = MVC::Keayl::Job::QueueAdapter::Test.new;
    MVC::Keayl::Job.queue-adapter($adapter);
    my @ran;
    RecordJob.perform-later(@ran, 1);
    RecordJob.perform-later(@ran, 2);
    expect($adapter.enqueued.elems).to.be(2);
  }

  it 'leaves enqueued jobs unrun until performed', {
    my $adapter = MVC::Keayl::Job::QueueAdapter::Test.new;
    MVC::Keayl::Job.queue-adapter($adapter);
    my @ran;
    RecordJob.perform-later(@ran, 1);
    expect(@ran).to.be([]);
  }

  it 'runs every enqueued job on perform-all', {
    my $adapter = MVC::Keayl::Job::QueueAdapter::Test.new;
    MVC::Keayl::Job.queue-adapter($adapter);
    my @ran;
    RecordJob.perform-later(@ran, 1);
    RecordJob.perform-later(@ran, 2);
    $adapter.perform-all;
    expect(@ran).to.be([1, 2]);
  }

  it 'empties the queue when cleared', {
    my $adapter = MVC::Keayl::Job::QueueAdapter::Test.new;
    $adapter.enqueue(RecordJob.new);
    $adapter.clear;
    expect($adapter.enqueued.elems).to.be(0);
  }
}

describe 'MVC::Keayl::Job::QueueAdapter::Async', {
  before-each { MVC::Keayl::Job.reset-queue-adapter }

  it 'runs the job on a separate thread', {
    my $adapter = MVC::Keayl::Job::QueueAdapter::Async.new;
    MVC::Keayl::Job.queue-adapter($adapter);
    my @ran;
    RecordJob.perform-later(@ran, 9);
    $adapter.wait;
    expect(@ran).to.be([9]);
  }
}
