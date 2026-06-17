use v6.d;
use MVC::Keayl::Controller;
use MVC::Keayl::Mailbox;
use MVC::Keayl::Mailbox::Router;

unit module MVC::Keayl::Mailbox::Ingress;

role Repository is export {
  method create(InboundEmail:D $email) { ... }
  method all(--> List)                 { ... }
}

class MemoryRepository does Repository is export {
  has @!emails;
  has Int $!seq = 0;

  method create(InboundEmail:D $email) {
    $email.id = ++$!seq;
    @!emails.push($email);
    $email
  }

  method all(--> List) {
    @!emails.List
  }
}

class Ingress is export {
  has Router $.router is required;
  has Repository $.repository = MemoryRepository.new;

  method receive(Str:D $raw --> InboundEmail) {
    my $email = InboundEmail.new(:$raw);
    $!repository.create($email);
    $!router.route($email);
    $email
  }
}

class RelayIngress is Ingress is export {
}

class SourceIngress is Ingress is export {
  has $.source is required;

  method poll(--> List) {
    $!source.fetch.map({ self.receive($_) }).List
  }
}

my Ingress $default-ingress;

sub set-mailbox-ingress(Ingress:D $ingress) is export {
  $default-ingress = $ingress;
}

sub mailbox-ingress(--> Ingress) is export {
  $default-ingress
}

sub reset-mailbox-ingress() is export {
  $default-ingress = Nil;
}

class RelayController is MVC::Keayl::Controller {
  method create {
    return self.head(503) without mailbox-ingress();

    mailbox-ingress.receive(self.request.body);
    self.head(204)
  }
}
