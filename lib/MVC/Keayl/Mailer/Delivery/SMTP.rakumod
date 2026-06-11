use v6.d;
use MVC::Keayl::Mailer::Delivery;
use MVC::Keayl::Mail;

unit class MVC::Keayl::Mailer::Delivery::SMTP does MVC::Keayl::Mailer::Delivery;

has Str $.host = 'localhost';
has Int $.port = 25;
has     &.transport is required;

method deliver(MVC::Keayl::Mail:D $mail) {
  &!transport(%(
    host => $!host,
    port => $!port,
    from => $mail.from,
    to   => $mail.recipients,
    data => $mail.encoded,
  ))
}
