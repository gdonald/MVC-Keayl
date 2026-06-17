use v6.d;

unit module MVC::Keayl::Mailbox;

class X::Bounced is Exception is export {
  method message { 'inbound email bounced during processing' }
}

sub extract-addresses(Str $value --> List) is export {
  return () without $value;

  my @addresses;
  for $value.split(',') -> $part {
    my $trimmed = $part.trim;
    next if $trimmed eq '';

    if $trimmed ~~ / '<' (<-[>]>+) '>' / {
      @addresses.push(~$0.trim);
    } elsif $trimmed ~~ / (\S+ '@' \S+) / {
      @addresses.push(~$0.trim);
    }
  }

  @addresses.List
}

class Message is export {
  has %.headers;
  has @.header-order;
  has Str $.body = '';

  method header(Str:D $name --> Str) {
    %!headers{$name.lc} // Str
  }

  method from(--> Str)         { extract-addresses(self.header('from')).head }
  method to(--> List)          { extract-addresses(self.header('to')) }
  method cc(--> List)          { extract-addresses(self.header('cc')) }
  method recipients(--> List)  { (|self.to, |self.cc).list }
  method subject(--> Str)      { self.header('subject') }
  method message-id(--> Str)   { self.header('message-id') }
}

sub parse-message(Str:D $raw --> Message) is export {
  my $normalized = $raw.subst("\r\n", "\n", :g);
  my $boundary   = $normalized.index("\n\n");

  my $header-block = $boundary.defined ?? $normalized.substr(0, $boundary) !! $normalized;
  my $body         = $boundary.defined ?? $normalized.substr($boundary + 2) !! '';

  my @unfolded;
  for $header-block.lines -> $line {
    if $line ~~ /^ \s/ && @unfolded {
      @unfolded[*- 1] ~= ' ' ~ $line.trim;
    } else {
      @unfolded.push($line);
    }
  }

  my %headers;
  my @order;

  for @unfolded -> $line {
    next unless $line ~~ / ^ (<-[:]>+) ':' \s* (.*) $ /;

    my $name  = ~$0.trim.lc;
    my $value = ~$1.trim;

    @order.push($name) unless %headers{$name}:exists;
    %headers{$name} = %headers{$name}:exists ?? %headers{$name} ~ ', ' ~ $value !! $value;
  }

  Message.new(:%headers, header-order => @order, :$body)
}

class InboundEmail is export {
  has $.id is rw;
  has Str $.raw is required;
  has Str $.status is rw = 'pending';
  has $!message;

  method message(--> Message) {
    $!message //= parse-message($!raw)
  }

  method is-pending(--> Bool)    { $!status eq 'pending' }
  method is-processing(--> Bool) { $!status eq 'processing' }
  method is-delivered(--> Bool)  { $!status eq 'delivered' }
  method is-bounced(--> Bool)    { $!status eq 'bounced' }
  method is-failed(--> Bool)     { $!status eq 'failed' }

  method processing-bang(--> InboundEmail) { $!status = 'processing'; self }
  method delivered-bang(--> InboundEmail)  { $!status = 'delivered'; self }
  method bounced-bang(--> InboundEmail)    { $!status = 'bounced'; self }
  method failed-bang(--> InboundEmail)     { $!status = 'failed'; self }
}

my %before{Mu};
my %after{Mu};
my %on-bounce{Mu};
my %rescues{Mu};

class Mailbox is export {
  has InboundEmail $.inbound-email is required;

  method message(--> Message) { $!inbound-email.message }
  method mail(--> Message)    { $!inbound-email.message }

  method before-processing(&callback --> ::?CLASS) {
    (%before{self} //= []).push(&callback);
    self
  }

  method after-processing(&callback --> ::?CLASS) {
    (%after{self} //= []).push(&callback);
    self
  }

  method on-bounce(&callback --> ::?CLASS) {
    (%on-bounce{self} //= []).push(&callback);
    self
  }

  method rescue-from($type, $handler --> ::?CLASS) {
    (%rescues{self} //= []).push: %( :$type, :$handler );
    self
  }

  method process { }

  method !collect(%registry --> List) {
    my @result;
    @result.append(|(%registry{$_} // [])) for self.^mro.reverse;
    @result
  }

  method !run(%registry) {
    .(self) for self!collect(%registry);
  }

  method bounce(--> Nil) {
    $!inbound-email.bounced-bang;
    self!run(%on-bounce);
    X::Bounced.new.throw;
  }

  method !rescue-handler($exception) {
    my @mro = $exception.^mro.map(*.^name);
    my %rank;
    %rank{@mro[$_]} //= $_ for ^@mro;

    my @matching = self!collect(%rescues).grep({ %rank{$_<type>.^name}:exists });
    return Nil unless @matching;

    my $best = @matching.shift;
    $best = $_ if %rank{$_<type>.^name} <= %rank{$best<type>.^name} for @matching;
    $best<handler>
  }

  method perform-processing(--> InboundEmail) {
    {
      CATCH {
        when X::Bounced { }

        default {
          my $exception = $_;
          $!inbound-email.failed-bang;

          my $handler = self!rescue-handler($exception);
          $exception.rethrow without $handler;

          $handler ~~ Callable ?? $handler(self, $exception) !! self."$handler"($exception);
        }
      }

      $!inbound-email.processing-bang;
      self!run(%before);
      self.process;
      self!run(%after);
      $!inbound-email.delivered-bang;
    }

    $!inbound-email
  }
}
