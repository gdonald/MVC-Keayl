use v6.d;
use MVC::Keayl::Job;

unit class MVC::Keayl::Mailer::DeliveryJob is MVC::Keayl::Job;

method perform($mailer, Str:D $action, |args) {
  $mailer.deliver($action, |args)
}
