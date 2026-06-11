use v6.d;
use MVC::Keayl::Mailer::Delivery;
use MVC::Keayl::Mail;

unit class MVC::Keayl::Mailer::Delivery::Test does MVC::Keayl::Mailer::Delivery;

my @deliveries;

method deliver(MVC::Keayl::Mail:D $mail) {
  @deliveries.push: $mail;
  $mail
}

method deliveries(--> List) { @deliveries.List }

method clear { @deliveries = () }
