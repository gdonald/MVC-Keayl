use v6.d;
use MIME::Base64;

my %extension-types =
  pdf => 'application/pdf', zip => 'application/zip', csv => 'text/csv',
  txt => 'text/plain', html => 'text/html', json => 'application/json',
  png => 'image/png', jpg => 'image/jpeg', jpeg => 'image/jpeg',
  gif => 'image/gif', svg => 'image/svg+xml';

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

  method has-html(--> Bool)  { $!html-part.defined }
  method has-text(--> Bool)  { $!text-part.defined }
  method multipart(--> Bool) { self.has-html && self.has-text }

  method recipients(--> List) { (|@!to, |@!cc, |@!bcc).list }

  method header-lines(--> List) {
    my @lines;

    @lines.push: "From: $!from"          if $!from.defined;
    @lines.push: "To: {@!to.join(', ')}"   if @!to;
    @lines.push: "Cc: {@!cc.join(', ')}"   if @!cc;
    @lines.push: "Bcc: {@!bcc.join(', ')}" if @!bcc;
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

    @lines.join("\n")
  }
}
