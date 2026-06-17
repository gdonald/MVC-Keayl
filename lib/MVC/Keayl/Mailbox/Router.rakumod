use v6.d;
use MVC::Keayl::Mailbox;

unit module MVC::Keayl::Mailbox::Router;

sub value-matches($matcher, Str $value, Bool :$substring --> Bool) {
  return False without $value;
  return so $value ~~ $matcher if $matcher ~~ Regex;

  $substring
    ?? $value.lc.contains($matcher.lc)
    !! $value.lc eq $matcher.lc
}

sub any-matches($matcher, @values --> Bool) {
  so @values.first({ value-matches($matcher, $_) })
}

class Router is export {
  has @!routes;

  method routing(:$to, :$from, :$subject, :$recipient, :&matching, Bool :$all, :$mailbox! --> Router) {
    @!routes.push: %(
      :$to, :$from, :$subject, :$recipient, :&matching, :$all, :$mailbox,
    );
    self
  }

  method !rule-matches(%rule, InboundEmail:D $email --> Bool) {
    my $message = $email.message;

    return True if %rule<all>;

    my $matched = False;

    with %rule<recipient> { return False unless any-matches($_, $message.recipients); $matched = True }
    with %rule<to>        { return False unless any-matches($_, $message.to); $matched = True }
    with %rule<from>      { return False unless value-matches($_, $message.from); $matched = True }
    with %rule<subject>   { return False unless value-matches($_, $message.subject, :substring); $matched = True }
    with %rule<matching>  { return False unless $_($email); $matched = True }

    $matched
  }

  method mailbox-for(InboundEmail:D $email) {
    for @!routes -> %rule {
      return %rule<mailbox> if self!rule-matches(%rule, $email);
    }

    Nil
  }

  method route(InboundEmail:D $email) {
    my $mailbox-class = self.mailbox-for($email);
    return Nil if $mailbox-class =:= Nil;

    $mailbox-class.new(inbound-email => $email).perform-processing;
    $email
  }
}
