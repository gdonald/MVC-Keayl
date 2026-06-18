use v6.d;
use MVC::Keayl::Mail;
use MVC::Keayl::Mailer::DeliveryJob;

unit class MVC::Keayl::Mailer;

has      $.view-renderer;
has      $.delivery;
has      $.i18n;
has Str  $.default-from;
has Str  $.action is rw;
has      $.message is rw;
has      $!attachments;

my %defaults{Mu};
my %before-actions{Mu};
my %after-actions{Mu};
my @interceptors;
my @observers;

sub underscore(Str:D $word --> Str) {
  $word.subst(/<?after .> <:Lu>/, { '_' ~ $/.Str }, :g).lc
}

sub normalize($value --> List) {
  return () without $value;
  ($value ~~ Positional ?? $value.list !! ($value,)).grep(*.defined).list
}

method mailer-path(--> Str) {
  underscore(self.^name.subst(/^ 'GLOBAL::' /, ''))
}

method default(*%options --> ::?CLASS) {
  (%defaults{self} //= {}){.key} = .value for %options;
  self
}

method !default-value(Str:D $key) {
  for self.^mro -> $class {
    return %defaults{$class}{$key} if (%defaults{$class} // {}){$key}:exists;
  }
  Nil
}

method !default-headers(--> Hash) {
  my %merged;
  for self.^mro.reverse -> $class {
    %merged{.key} = .value for (%defaults{$class} // {}).pairs;
  }
  %merged<from>:delete;
  %merged<reply-to>:delete;
  %merged
}

method before-action(&callback --> ::?CLASS) {
  (%before-actions{self} //= []).push(&callback);
  self
}

method after-action(&callback --> ::?CLASS) {
  (%after-actions{self} //= []).push(&callback);
  self
}

method !run-callbacks(%registry) {
  my @callbacks;
  @callbacks.append(|(%registry{$_} // [])) for self.^mro.reverse;
  .(self) for @callbacks;
}

method register-interceptor($interceptor --> ::?CLASS) {
  @interceptors.push($interceptor);
  self
}

method register-observer($observer --> ::?CLASS) {
  @observers.push($observer);
  self
}

method reset-interceptors(--> ::?CLASS) { @interceptors = (); self }
method reset-observers(--> ::?CLASS)    { @observers = (); self }

method attachments(--> MVC::Keayl::Mail::Attachments) {
  $!attachments //= MVC::Keayl::Mail::Attachments.new
}

method !render-part(Str:D $template, Str:D $format, %locals --> Str) {
  return Str without $!view-renderer;

  my $file = $!view-renderer.resolve($template, $format);
  return Str unless $file.defined && $file.e;

  $!view-renderer.render-template($template, %locals, :$format)
}

method !i18n-subject(%locals --> Str) {
  return Str without $!i18n;

  my $scope = self.mailer-path.subst('/', '.', :g) ~ '.' ~ ($!action // '');
  $!i18n.translate('subject', scope => $scope, default => ($!action // '').tc, |%locals)
}

method mail(:$to, :$from, :$subject, :$cc, :$bcc, :$reply-to, :%locals, :%headers, Str :$template --> MVC::Keayl::Mail) {
  my $name = $template // (self.mailer-path ~ '/' ~ $!action);

  my $html = self!render-part($name, 'html', %locals);
  my $text = self!render-part($name, 'text', %locals);

  my $resolved-subject = $subject // self!i18n-subject(%locals);

  MVC::Keayl::Mail.new(
    from        => ($from // self!default-value('from') // $!default-from),
    to          => normalize($to),
    cc          => normalize($cc),
    bcc         => normalize($bcc),
    reply-to    => ($reply-to // self!default-value('reply-to')),
    subject     => $resolved-subject,
    html-part   => $html,
    text-part   => $text,
    headers     => %( |self!default-headers, |%headers ),
    attachments => self.attachments.list,
  )
}

method build(Str:D $action, |args --> MVC::Keayl::Mail) {
  $!action = $action;

  self!run-callbacks(%before-actions);
  my $mail = self."$action"(|args);
  $!message = $mail;
  self!run-callbacks(%after-actions);

  $mail
}

method !run-interceptors(MVC::Keayl::Mail:D $mail) {
  for @interceptors -> $interceptor {
    $interceptor ~~ Callable ?? $interceptor($mail) !! $interceptor.delivering-email($mail);
  }
}

method !run-observers(MVC::Keayl::Mail:D $mail) {
  for @observers -> $observer {
    $observer ~~ Callable ?? $observer($mail) !! $observer.delivered-email($mail);
  }
}

method deliver(Str:D $action, |args --> MVC::Keayl::Mail) {
  my $mail = self.build($action, |args);

  self!run-interceptors($mail);
  .deliver($mail) with $!delivery;
  self!run-observers($mail);

  $mail
}

method deliver-later(Str:D $action, |args --> MVC::Keayl::Mailer::DeliveryJob) {
  MVC::Keayl::Mailer::DeliveryJob.perform-later(self, $action, |args)
}
