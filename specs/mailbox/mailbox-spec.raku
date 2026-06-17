use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Request;
use MVC::Keayl::Mailbox;
use MVC::Keayl::Mailbox::Router;
use MVC::Keayl::Mailbox::Ingress;

sub sample-email {
  qq:to/EMAIL/.trim;
  From: Alice <alice\@example.com>
  To: Support <support\@example.com>, help\@example.com
  Cc: watcher\@example.com
  Subject: Need help with billing
  Message-ID: <abc123\@example.com>

  Please help me, my invoice is wrong.
  EMAIL
}

describe 'parse-message', {
  let(:message, { parse-message(sample-email) });

  it 'extracts the sender address', {
    expect(message.from).to.be('alice@example.com');
  }

  it 'extracts every recipient address', {
    expect(message.to.sort.join(',')).to.be('help@example.com,support@example.com');
  }

  it 'extracts cc addresses', {
    expect(message.cc.head).to.be('watcher@example.com');
  }

  it 'extracts the subject', {
    expect(message.subject).to.be('Need help with billing');
  }

  it 'extracts the message id', {
    expect(message.message-id).to.be('<abc123@example.com>');
  }

  it 'keeps the body', {
    expect(message.body.trim).to.be('Please help me, my invoice is wrong.');
  }

  it 'unfolds continuation lines', {
    expect(parse-message("Subject: a very long\n  folded subject line\nFrom: a\@b.com\n\nbody").subject).to.be('a very long folded subject line');
  }
}

describe 'InboundEmail state machine', {
  let(:email, { InboundEmail.new(raw => sample-email) });

  it 'starts pending', {
    expect(email.is-pending).to.be-truthy;
  }

  it 'moves to processing', {
    email.processing-bang;
    expect(email.is-processing).to.be-truthy;
  }

  it 'moves to delivered', {
    email.delivered-bang;
    expect(email.is-delivered).to.be-truthy;
  }

  it 'moves to bounced', {
    email.bounced-bang;
    expect(email.is-bounced).to.be-truthy;
  }

  it 'moves to failed', {
    email.failed-bang;
    expect(email.is-failed).to.be-truthy;
  }
}

describe 'Mailbox processing', {
  it 'runs before, process, then after', {
    my @log;
    my class SupportMailbox is Mailbox {
      has @.log;
      method process { @.log.push('process:' ~ self.message.subject) }
    }
    SupportMailbox.before-processing(-> $m { $m.log.push('before') });
    SupportMailbox.after-processing(-> $m { $m.log.push('after') });

    my $mailbox = SupportMailbox.new(inbound-email => InboundEmail.new(raw => sample-email));
    $mailbox.perform-processing;

    expect($mailbox.log.join(',')).to.be('before,process:Need help with billing,after');
  }

  it 'delivers a processed email', {
    my class PlainMailbox is Mailbox { method process { } }
    my $email = InboundEmail.new(raw => sample-email);
    PlainMailbox.new(inbound-email => $email).perform-processing;
    expect($email.is-delivered).to.be-truthy;
  }
}

describe 'Mailbox bouncing', {
  it 'marks the email bounced and runs the bounce callback', {
    my @log;
    my class BounceMailbox is Mailbox {
      has @.log;
      method process { self.bounce }
    }
    BounceMailbox.after-processing(-> $m { $m.log.push('after') });
    BounceMailbox.on-bounce(-> $m { $m.log.push('bounced') });

    my $mailbox = BounceMailbox.new(inbound-email => InboundEmail.new(raw => sample-email));
    $mailbox.perform-processing;

    expect($mailbox.inbound-email.is-bounced && $mailbox.log.join(',') eq 'bounced').to.be-truthy;
  }
}

describe 'Mailbox failure', {
  it 'runs a matching rescue handler and marks the email failed', {
    my @log;
    my class FailMailbox is Mailbox {
      has @.log;
      method process { die 'boom' }
    }
    FailMailbox.rescue-from(Exception, -> $m, $error { $m.log.push('rescued:' ~ $error.message) });

    my $mailbox = FailMailbox.new(inbound-email => InboundEmail.new(raw => sample-email));
    $mailbox.perform-processing;

    expect($mailbox.inbound-email.is-failed && $mailbox.log.head eq 'rescued:boom').to.be-truthy;
  }

  it 're-raises an unrescued failure', {
    my class UnrescuedMailbox is Mailbox { method process { die 'unhandled' } }
    expect({ UnrescuedMailbox.new(inbound-email => InboundEmail.new(raw => sample-email)).perform-processing }).to.throw;
  }
}

describe 'Router', {
  it 'picks a mailbox by recipient', {
    my class RepliesMailbox is Mailbox { method process { } }
    my class DefaultMailbox is Mailbox { method process { } }

    my $router = Router.new;
    $router.routing(to => 'support@example.com', mailbox => RepliesMailbox);
    $router.routing(all => True, mailbox => DefaultMailbox);

    expect($router.mailbox-for(InboundEmail.new(raw => sample-email)).^name.ends-with('RepliesMailbox')).to.be-truthy;
  }

  it 'falls through to the catch-all', {
    my class RepliesMailbox is Mailbox { method process { } }
    my class DefaultMailbox is Mailbox { method process { } }

    my $router = Router.new;
    $router.routing(to => 'support@example.com', mailbox => RepliesMailbox);
    $router.routing(all => True, mailbox => DefaultMailbox);

    my $other = InboundEmail.new(raw => "To: nobody\@example.com\nFrom: x\@y.com\n\nhi");
    expect($router.mailbox-for($other).^name.ends-with('DefaultMailbox')).to.be-truthy;
  }

  it 'matches a subject substring', {
    my class SubjectMailbox is Mailbox { method process { } }
    my $router = Router.new;
    $router.routing(subject => 'billing', mailbox => SubjectMailbox);
    expect($router.mailbox-for(InboundEmail.new(raw => sample-email)) !=:= Nil).to.be-truthy;
  }

  it 'does not route a non-matching subject', {
    my class SubjectMailbox is Mailbox { method process { } }
    my $router = Router.new;
    $router.routing(subject => 'billing', mailbox => SubjectMailbox);
    expect($router.mailbox-for(InboundEmail.new(raw => "Subject: hello\n\nx")) =:= Nil).to.be-truthy;
  }

  it 'matches a regex sender', {
    my class FromMailbox is Mailbox { method process { } }
    my $router = Router.new;
    $router.routing(from => rx:i/ '@example.com' $/, mailbox => FromMailbox);
    expect($router.mailbox-for(InboundEmail.new(raw => sample-email)) !=:= Nil).to.be-truthy;
  }
}

describe 'RelayIngress', {
  it 'routes, delivers, and records the inbound email', {
    my class IngressMailbox is Mailbox { method process { } }

    my $router = Router.new;
    $router.routing(all => True, mailbox => IngressMailbox);

    my $ingress = RelayIngress.new(:$router);
    my $email   = $ingress.receive(sample-email);

    expect($email.is-delivered && $ingress.repository.all.elems == 1).to.be-truthy;
  }
}

describe 'SourceIngress', {
  it 'pulls and processes every fetched message', {
    my class PollMailbox is Mailbox { method process { } }
    my class FakeSource {
      has @.messages;
      method fetch { @!messages }
    }

    my $router = Router.new;
    $router.routing(all => True, mailbox => PollMailbox);

    my $ingress = SourceIngress.new(:$router, source => FakeSource.new(messages => [sample-email, sample-email]));
    expect($ingress.poll.elems).to.be(2);
  }
}

describe 'RelayController', {
  before-each({ reset-mailbox-ingress });

  it 'accepts a posted raw email', {
    my class WebMailbox is Mailbox { method process { } }
    my $router = Router.new;
    $router.routing(all => True, mailbox => WebMailbox);
    set-mailbox-ingress(RelayIngress.new(:$router));

    my $request  = MVC::Keayl::Request.new(method => 'POST', body => sample-email);
    my $response = MVC::Keayl::Mailbox::Ingress::RelayController.new(:$request).dispatch('create');

    expect($response.status).to.be(204);
  }

  it 'reports unavailable without a configured ingress', {
    my $request  = MVC::Keayl::Request.new(method => 'POST', body => 'x');
    my $response = MVC::Keayl::Mailbox::Ingress::RelayController.new(:$request).dispatch('create');
    expect($response.status).to.be(503);
  }
}
