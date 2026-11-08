use v6.d;
use MIME::Base64;
use Crypt::Random;

my %extension-types =
  pdf => 'application/pdf', zip => 'application/zip', csv => 'text/csv',
  txt => 'text/plain', html => 'text/html', json => 'application/json',
  png => 'image/png', jpg => 'image/jpeg', jpeg => 'image/jpeg',
  gif => 'image/gif', svg => 'image/svg+xml';

my @day-names   = <Sun Mon Tue Wed Thu Fri Sat>;
my @month-names = <Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec>;

my sub message-date(DateTime:D $when --> Str) {
  my $utc = $when.utc;

  sprintf '%s, %02d %s %04d %02d:%02d:%02d +0000',
    @day-names[$utc.day-of-week % 7], $utc.day, @month-names[$utc.month - 1], $utc.year,
    $utc.hour, $utc.minute, $utc.second.Int;
}

my sub content-type-for(Str:D $filename --> Str) {
  my $dot = $filename.rindex('.');
  return 'application/octet-stream' without $dot;
  %extension-types{$filename.substr($dot + 1).lc} // 'application/octet-stream'
}

class MVC::Keayl::Mail::Attachment {
  has Str  $.filename;
  has Str  $.content-type;
  has      $.content;
  has Bool $.inline = False;
  has Str  $.content-id;

  method encoded-content(--> Str) {
    my $buf = $!content ~~ Blob ?? $!content !! ($!content // '').Str.encode('utf-8');
    MIME::Base64.encode($buf)
  }
}

class MVC::Keayl::Mail::Attachments does Associative {
  has $.entries = [];
  has Bool $.inline = False;

  method AT-KEY(Str() $name)              { $!entries.first(*.filename eq $name) }
  method EXISTS-KEY(Str() $name --> Bool) { so self.AT-KEY($name) }

  method ASSIGN-KEY(Str() $name, $value) {
    my %spec = $value ~~ Associative ?? $value.Hash !! %( content => $value );

    $!entries.push: MVC::Keayl::Mail::Attachment.new(
      filename     => $name,
      content-type => %spec<content-type> // %spec<mime-type> // content-type-for($name),
      content      => %spec<content>,
      inline       => $!inline,
      content-id   => %spec<content-id> // ($!inline ?? $name !! Str),
    );
  }

  method inline(--> MVC::Keayl::Mail::Attachments) {
    self.WHAT.new(entries => $!entries, inline => True)
  }

  method list(--> List) { $!entries.List }
}

class MVC::Keayl::Mail {
  has Str $.from is rw;
  has     @.to is rw;
  has     @.cc is rw;
  has     @.bcc is rw;
  has Str $.reply-to is rw;
  has Str $.subject is rw;
  has Str $.html-part;
  has Str $.text-part;
  has     %.headers;
  has     @.attachments;
  has DateTime $.date = DateTime.now;
  has Str      $.message-id;

  method has-html(--> Bool)  { $!html-part.defined }
  method has-text(--> Bool)  { $!text-part.defined }
  method multipart(--> Bool) { self.has-html && self.has-text }

  method recipients(--> List) { (|@!to, |@!cc, |@!bcc).list }

  method message-id(--> Str) {
    $!message-id //= do {
      my $domain = ($!from // '').match(/ '@' (<-[>\s]>+) /)[0] // 'localhost';
      "<{crypt_random_buf(16).list.map(*.fmt('%02x')).join}\@$domain>"
    }
  }

  method header-lines(--> List) {
    my @lines = "Date: {message-date($!date)}", "Message-ID: {self.message-id}";

    @lines.push: "From: $!from"          if $!from.defined;
    @lines.push: "To: {@!to.join(', ')}"   if @!to;
    @lines.push: "Cc: {@!cc.join(', ')}"   if @!cc;
    @lines.push: "Reply-To: $!reply-to"   if $!reply-to.defined;
    @lines.push: "Subject: $!subject"     if $!subject.defined;

    @lines.push: "{.key}: {.value}" for %!headers.sort(*.key);

    @lines.push: 'MIME-Version: 1.0';
    @lines.List
  }

  method !body-lines(Str:D $boundary --> List) {
    if self.multipart {
      return (
        "Content-Type: multipart/alternative; boundary=\"$boundary\"", '',
        "--$boundary", 'Content-Type: text/plain; charset=utf-8', '', $!text-part,
        "--$boundary", 'Content-Type: text/html; charset=utf-8', '', $!html-part,
        "--$boundary--",
      );
    } elsif self.has-html {
      return ('Content-Type: text/html; charset=utf-8', '', $!html-part);
    }

    ('Content-Type: text/plain; charset=utf-8', '', ($!text-part // ''))
  }

  method !attachment-lines($attachment --> List) {
    my $disposition = $attachment.inline ?? 'inline' !! 'attachment';

    my @lines = (
      "Content-Type: {$attachment.content-type}; name=\"{$attachment.filename}\"",
      'Content-Transfer-Encoding: base64',
      "Content-Disposition: $disposition; filename=\"{$attachment.filename}\"",
    );

    @lines.push: "Content-ID: <{$attachment.content-id}>" if $attachment.content-id.defined;
    @lines.push: '';
    @lines.push: $attachment.encoded-content;
    @lines
  }

  method encoded(Str:D :$boundary = 'KEAYL_PART_BOUNDARY', Str:D :$mixed-boundary = 'KEAYL_MIXED_BOUNDARY' --> Str) {
    my @lines = self.header-lines;

    if @!attachments {
      @lines.push: "Content-Type: multipart/mixed; boundary=\"$mixed-boundary\"";
      @lines.push: '';
      @lines.push: "--$mixed-boundary";
      @lines.append: self!body-lines($boundary);

      for @!attachments -> $attachment {
        @lines.push: "--$mixed-boundary";
        @lines.append: self!attachment-lines($attachment);
      }

      @lines.push: "--$mixed-boundary--";
    } else {
      @lines.append: self!body-lines($boundary);
    }

    @lines.join("\n").subst(/\r?\n/, "\r\n", :g)
  }
}
