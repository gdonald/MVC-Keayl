use v6.d;
use MVC::Keayl::Mailer::Delivery;
use MVC::Keayl::Mail;

unit class MVC::Keayl::Mailer::Delivery::File does MVC::Keayl::Mailer::Delivery;

has IO() $.directory is required;
has Int  $!counter = 0;

method deliver(MVC::Keayl::Mail:D $mail --> IO::Path) {
  $!directory.mkdir;

  my $file = $!directory.add($!counter++.fmt('%06d') ~ '.eml');
  $file.spurt: $mail.encoded;

  $file
}
