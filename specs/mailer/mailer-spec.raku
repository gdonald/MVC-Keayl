use BDD::Behave;
use MVC::Keayl::Mailer;
use MVC::Keayl::Mail;
use MVC::Keayl::Mailer::Delivery::Test;
use MVC::Keayl::Mailer::Delivery::File;
use MVC::Keayl::Mailer::Delivery::SMTP;
use MVC::Keayl::View;
use CLIFixtures;

class NoticeMailer is MVC::Keayl::Mailer {
  method welcome($name) {
    self.mail(to => 'user@example.com', from => 'noreply@example.com', subject => 'Welcome', locals => %( :$name ));
  }

  method alert {
    self.mail(to => 'ops@example.com', subject => 'Alert');
  }
}

sub renderer { MVC::Keayl::View.new(paths => ['specs/lib/views']) }

sub mailer(*%args) { NoticeMailer.new(view-renderer => renderer(), |%args) }

describe 'MVC::Keayl::Mailer rendering', {
  context 'an action with both templates', {
    let(:mail, { mailer.build('welcome', 'Ada') });

    it 'renders the html part', {
      expect(mail.html-part.contains('Welcome, Ada')).to.be-truthy;
    }

    it 'renders the text part', {
      expect(mail.text-part.contains('Welcome, Ada')).to.be-truthy;
    }

    it 'is multipart', {
      expect(mail.multipart).to.be-truthy;
    }

    it 'sets the recipient', {
      expect(mail.to).to.be(['user@example.com']);
    }

    it 'sets the sender', {
      expect(mail.from).to.be('noreply@example.com');
    }

    it 'sets the subject', {
      expect(mail.subject).to.be('Welcome');
    }
  }

  context 'an action with only an html template', {
    let(:mail, { mailer.build('alert') });

    it 'has the html part', {
      expect(mail.has-html).to.be-truthy;
    }

    it 'has no text part', {
      expect(mail.has-text).to.be-falsy;
    }

    it 'is not multipart', {
      expect(mail.multipart).to.be-falsy;
    }
  }

  it 'uses the default sender when none is given', {
    my $mail = NoticeMailer.new(view-renderer => renderer(), default-from => 'default@example.com').build('alert');
    expect($mail.from).to.be('default@example.com');
  }
}

describe 'MVC::Keayl::Mail encoding', {
  let(:encoded, { mailer.build('welcome', 'Ada').encoded });

  it 'carries the subject header', {
    expect(encoded.contains('Subject: Welcome')).to.be-truthy;
  }

  it 'declares multipart/alternative', {
    expect(encoded.contains('multipart/alternative')).to.be-truthy;
  }

  it 'includes a text part', {
    expect(encoded.contains('text/plain')).to.be-truthy;
  }

  it 'includes an html part', {
    expect(encoded.contains('text/html')).to.be-truthy;
  }
}

describe 'MVC::Keayl::Mail headers', {
  let(:date, { DateTime.new('2026-11-08T14:05:09Z') });

  let(:mail, {
    MVC::Keayl::Mail.new(
      from       => 'a@example.com',
      to         => ['b@example.com'],
      bcc        => ['c@example.com'],
      subject    => 'Hi',
      text-part  => "Hello\nthere",
      date       => date,
      message-id => '<fixed@example.com>',
    )
  });

  it 'leaves out the bcc header', {
    expect(mail.encoded.contains('Bcc:')).to.be-falsy;
  }

  it 'keeps the bcc address a recipient', {
    expect(mail.recipients).to.eq(('b@example.com', 'c@example.com'));
  }

  it 'ends header lines with CRLF', {
    expect(mail.encoded.contains("Subject: Hi\r\n")).to.be-truthy;
  }

  it 'ends body lines with CRLF', {
    expect(mail.encoded.contains("Hello\r\nthere")).to.be-truthy;
  }

  it 'has no bare LF', {
    expect(mail.encoded.split("\r\n").first(*.contains("\n"))).to.be-falsy;
  }

  it 'carries the date header', {
    expect(mail.encoded.contains('Date: Sun, 08 Nov 2026 14:05:09 +0000')).to.be-truthy;
  }

  it 'carries the message id header', {
    expect(mail.encoded.contains('Message-ID: <fixed@example.com>')).to.be-truthy;
  }

  context 'without a given message id', {
    let(:generated, { MVC::Keayl::Mail.new(from => 'a@example.com', subject => 'Hi') });

    it 'generates one at the sender domain', {
      expect(so generated.message-id ~~ /^ '<' <xdigit> ** 32 '@example.com>' $/).to.be-truthy;
    }

    it 'keeps the generated message id across reads', {
      expect(generated.message-id).to.be(generated.message-id);
    }
  }

  context 'without a sender', {
    let(:anonymous, { MVC::Keayl::Mail.new(subject => 'Hi') });

    it 'generates a message id at localhost', {
      expect(anonymous.message-id.ends-with('@localhost>')).to.be-truthy;
    }
  }
}

describe 'MVC::Keayl::Mailer::Delivery::Test', {
  before-each { MVC::Keayl::Mailer::Delivery::Test.clear }

  it 'collects the delivered mail', {
    mailer(delivery => MVC::Keayl::Mailer::Delivery::Test.new).deliver('welcome', 'Ada');
    expect(MVC::Keayl::Mailer::Delivery::Test.deliveries.elems).to.be(1);
  }

  it 'collects the delivered message itself', {
    mailer(delivery => MVC::Keayl::Mailer::Delivery::Test.new).deliver('welcome', 'Ada');
    expect(MVC::Keayl::Mailer::Delivery::Test.deliveries[0].subject).to.be('Welcome');
  }

  it 'empties the mailbox when cleared', {
    mailer(delivery => MVC::Keayl::Mailer::Delivery::Test.new).deliver('welcome', 'Ada');
    MVC::Keayl::Mailer::Delivery::Test.clear;
    expect(MVC::Keayl::Mailer::Delivery::Test.deliveries.elems).to.be(0);
  }
}

describe 'MVC::Keayl::Mailer::Delivery::File', {
  it 'writes one message file', {
    my $dir = temp-dir('spec-mailer-file');
    mailer(delivery => MVC::Keayl::Mailer::Delivery::File.new(directory => $dir)).deliver('welcome', 'Ada');
    expect($dir.dir.grep(*.extension eq 'eml').elems).to.be(1);
  }

  it 'writes the encoded message to the file', {
    my $dir = temp-dir('spec-mailer-file-content');
    mailer(delivery => MVC::Keayl::Mailer::Delivery::File.new(directory => $dir)).deliver('welcome', 'Ada');
    my @files = $dir.dir.grep(*.extension eq 'eml');
    expect(@files[0].slurp.contains('Subject: Welcome')).to.be-truthy;
  }
}

describe 'MVC::Keayl::Mailer::Delivery::SMTP', {
  sub captured-envelope {
    my %captured;
    my $delivery = MVC::Keayl::Mailer::Delivery::SMTP.new(
      host      => 'mail.example.com',
      port      => 587,
      transport => -> %envelope { %captured = %envelope },
    );
    mailer(delivery => $delivery).deliver('welcome', 'Ada');
    %captured
  }

  it 'passes the host to the transport', {
    expect(captured-envelope<host>).to.be('mail.example.com');
  }

  it 'passes the sender envelope', {
    expect(captured-envelope<from>).to.be('noreply@example.com');
  }

  it 'passes the recipients envelope', {
    expect(captured-envelope<to>).to.be(['user@example.com']);
  }

  it 'passes the encoded message', {
    expect(captured-envelope<data>.contains('Subject: Welcome')).to.be-truthy;
  }
}

describe 'MVC::Keayl::Mailer delivery result', {
  it 'returns the mail message', {
    my $mail = mailer(delivery => MVC::Keayl::Mailer::Delivery::Test.new).deliver('alert');
    expect($mail ~~ MVC::Keayl::Mail).to.be-truthy;
  }
}
