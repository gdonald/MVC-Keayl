use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Mailer;
use MVC::Keayl::Mail;
use MVC::Keayl::Mailer::Delivery::Test;
use MVC::Keayl::Mailer::Preview;
use MVC::Keayl::View;
use MVC::Keayl::I18n;
use MVC::Keayl::Job;
use MVC::Keayl::Job::QueueAdapter::Test;
use MVC::Keayl::Parameters;

sub renderer { MVC::Keayl::View.new(paths => ['specs/lib/views']) }

class MailerFeatureNoticeMailer is MVC::Keayl::Mailer {
  method welcome($name) {
    self.mail(to => 'user@example.com', from => 'noreply@example.com', subject => 'Welcome', template => 'notice_mailer/welcome', locals => %( :$name ));
  }
}

class MailerFeatureListMailer is MVC::Keayl::Mailer {
  method notify {
    self.mail(to => ['a@x.com', 'b@x.com'], cc => 'c@x.com', bcc => 'd@x.com', reply-to => 'reply@x.com', subject => 'Hi');
  }
}

class MailerFeatureFileMailer is MVC::Keayl::Mailer {
  method report {
    self.attachments<report.pdf> = 'PDF-BYTES';
    self.mail(to => 'a@x.com', subject => 'Report');
  }
  method newsletter {
    self.attachments.inline<logo.png> = %( content-type => 'image/png', content => 'PNG-BYTES' );
    self.mail(to => 'a@x.com', subject => 'News');
  }
}

class MailerFeatureGreetingMailer is MVC::Keayl::Mailer {
  method welcome($name) { self.mail(to => 'u@x.com', locals => %( :$name )) }
}

class MailerFeaturePreview is Preview {
  method welcome { MailerFeatureNoticeMailer.new(view-renderer => renderer()).build('welcome', 'Ada') }
}

describe 'recipients and reply-to', {
  let(:mail, { MailerFeatureListMailer.new.build('notify') });

  it 'keeps multiple recipients', {
    expect(mail.to.elems).to.be(2);
  }

  it 'sets the reply-to', {
    expect(mail.reply-to).to.be('reply@x.com');
  }

  it 'collects to, cc, and bcc as recipients', {
    expect(mail.recipients.sort.join(',')).to.be('a@x.com,b@x.com,c@x.com,d@x.com');
  }

  it 'carries the reply-to header in the encoded message', {
    expect(mail.encoded.contains('Reply-To: reply@x.com')).to.be-truthy;
  }
}

describe 'attachments', {
  let(:encoded, { MailerFeatureFileMailer.new.build('report').encoded });

  it 'makes the message multipart/mixed', {
    expect(encoded.contains('multipart/mixed')).to.be-truthy;
  }

  it 'sets an attachment disposition', {
    expect(encoded.contains('Content-Disposition: attachment; filename="report.pdf"')).to.be-truthy;
  }

  it 'infers the content type from the filename', {
    expect(encoded.contains('application/pdf')).to.be-truthy;
  }

  context 'inline attachments', {
    let(:inline-encoded, { MailerFeatureFileMailer.new.build('newsletter').encoded });

    it 'uses an inline disposition', {
      expect(inline-encoded.contains('Content-Disposition: inline; filename="logo.png"')).to.be-truthy;
    }

    it 'carries a content id', {
      expect(inline-encoded.contains('Content-ID: <logo.png>')).to.be-truthy;
    }
  }
}

describe 'class-level defaults', {
  it 'supplies the sender and reply-to', {
    my class DefaultsMailer is MVC::Keayl::Mailer {
      method ping { self.mail(to => 'a@x.com', subject => 'Ping') }
    }
    DefaultsMailer.default(from => 'default@x.com', reply-to => 'reply@x.com');

    my $mail = DefaultsMailer.new.build('ping');
    expect($mail.from eq 'default@x.com' && $mail.reply-to eq 'reply@x.com').to.be-truthy;
  }

  it 'lets an explicit value override the default', {
    my class OverrideMailer is MVC::Keayl::Mailer {
      method ping { self.mail(to => 'a@x.com', from => 'explicit@x.com', subject => 'Ping') }
    }
    OverrideMailer.default(from => 'default@x.com');
    expect(OverrideMailer.new.build('ping').from).to.be('explicit@x.com');
  }
}

describe 'before and after action callbacks', {
  it 'wraps the action', {
    my class CallbackMailer is MVC::Keayl::Mailer {
      has @.log;
      method ping { @.log.push('action'); self.mail(to => 'a@x.com', subject => 'Ping') }
    }
    CallbackMailer.before-action(-> $m { $m.log.push('before') });
    CallbackMailer.after-action(-> $m { $m.log.push('after') });

    my $mailer = CallbackMailer.new;
    $mailer.build('ping');
    expect($mailer.log.join(',')).to.be('before,action,after');
  }
}

describe 'i18n subject lookup', {
  it 'looks up and interpolates a missing subject', {
    my $i18n = MVC::Keayl::I18n.new(
      default-locale => 'en',
      store => %( en => { mailer_feature_greeting_mailer => { welcome => { subject => 'Hello %{name}' } } } ),
    );
    expect(MailerFeatureGreetingMailer.new(:$i18n).build('welcome', 'Ada').subject).to.be('Hello Ada');
  }
}

describe 'deliver-later', {
  before-each({
    MVC::Keayl::Mailer::Delivery::Test.clear;
    MVC::Keayl::Job.reset-queue-adapter;
  });

  it 'enqueues a delivery job instead of delivering now', {
    my $adapter = MVC::Keayl::Job::QueueAdapter::Test.new;
    MVC::Keayl::Job.queue-adapter($adapter);

    MailerFeatureNoticeMailer.new(view-renderer => renderer(), delivery => MVC::Keayl::Mailer::Delivery::Test.new).deliver-later('welcome', 'Ada');

    expect($adapter.enqueued.elems == 1 && MVC::Keayl::Mailer::Delivery::Test.deliveries.elems == 0).to.be-truthy;
    MVC::Keayl::Job.reset-queue-adapter;
  }

  it 'delivers when the job runs', {
    my $adapter = MVC::Keayl::Job::QueueAdapter::Test.new;
    MVC::Keayl::Job.queue-adapter($adapter);

    MailerFeatureNoticeMailer.new(view-renderer => renderer(), delivery => MVC::Keayl::Mailer::Delivery::Test.new).deliver-later('welcome', 'Ada');
    $adapter.perform-all;

    expect(MVC::Keayl::Mailer::Delivery::Test.deliveries.elems).to.be(1);
    MVC::Keayl::Job.reset-queue-adapter;
  }
}

describe 'interceptors and observers', {
  before-each({
    MVC::Keayl::Mailer::Delivery::Test.clear;
    MVC::Keayl::Mailer.reset-interceptors;
    MVC::Keayl::Mailer.reset-observers;
  });

  it 'rewrites the mail before delivery', {
    MVC::Keayl::Mailer.register-interceptor(-> $mail { $mail.to = ['redirected@x.com'] });
    MailerFeatureNoticeMailer.new(view-renderer => renderer(), delivery => MVC::Keayl::Mailer::Delivery::Test.new).deliver('welcome', 'Ada');
    expect(MVC::Keayl::Mailer::Delivery::Test.deliveries[0].to).to.be(['redirected@x.com']);
    MVC::Keayl::Mailer.reset-interceptors;
  }

  it 'notifies an observer after delivery', {
    my @observed;
    MVC::Keayl::Mailer.register-observer(-> $mail { @observed.push($mail.subject) });
    MailerFeatureNoticeMailer.new(view-renderer => renderer(), delivery => MVC::Keayl::Mailer::Delivery::Test.new).deliver('welcome', 'Ada');
    expect(@observed.head).to.be('Welcome');
    MVC::Keayl::Mailer.reset-observers;
  }
}

describe 'previews', {
  before-each({
    Previews.reset;
    Previews.register('notice_mailer', MailerFeaturePreview);
  });

  it 'lists registered previews', {
    expect(Previews.names).to.be(['notice_mailer']);
  }

  it 'lists a preview\'s emails', {
    expect(Previews.emails('notice_mailer')).to.be(['welcome']);
  }

  it 'builds a mail for a preview email', {
    expect(Previews.mail('notice_mailer', 'welcome') ~~ MVC::Keayl::Mail).to.be-truthy;
  }

  it 'does not build an unknown email', {
    expect(Previews.mail('notice_mailer', 'unknown') =:= Nil).to.be-truthy;
  }

  context 'the preview controller', {
    let(:response, {
      my $params = MVC::Keayl::Parameters.new({ preview => 'notice_mailer', email => 'welcome', part => 'html' });
      MVC::Keayl::Mailer::Preview::PreviewController.new(:$params).dispatch('show')
    });

    it 'renders the html part', {
      expect(response.body.contains('Welcome, Ada')).to.be-truthy;
    }

    it 'serves it as html', {
      expect(response.header('content-type')).to.be('text/html; charset=utf-8');
    }

    it 'returns 404 for an unknown preview', {
      my $params = MVC::Keayl::Parameters.new({ preview => 'missing', email => 'welcome' });
      expect(MVC::Keayl::Mailer::Preview::PreviewController.new(:$params).dispatch('show').status).to.be(404);
    }
  }
}
