use v6.d;

unit class MVC::Keayl::Mail;

has Str $.from;
has     @.to;
has     @.cc;
has     @.bcc;
has Str $.subject;
has Str $.html-part;
has Str $.text-part;
has     %.headers;

method has-html(--> Bool) { $!html-part.defined }
method has-text(--> Bool) { $!text-part.defined }
method multipart(--> Bool) { self.has-html && self.has-text }

method recipients(--> List) { (|@!to, |@!cc, |@!bcc).list }

method header-lines(--> List) {
  my @lines;

  @lines.push: "From: $!from"          if $!from.defined;
  @lines.push: "To: {@!to.join(', ')}"   if @!to;
  @lines.push: "Cc: {@!cc.join(', ')}"   if @!cc;
  @lines.push: "Bcc: {@!bcc.join(', ')}" if @!bcc;
  @lines.push: "Subject: $!subject"    if $!subject.defined;

  @lines.push: "{.key}: {.value}" for %!headers.sort(*.key);

  @lines.push: 'MIME-Version: 1.0';
  @lines.List
}

method encoded(Str:D :$boundary = 'KEAYL_PART_BOUNDARY' --> Str) {
  my @lines = self.header-lines;

  if self.multipart {
    @lines.push: "Content-Type: multipart/alternative; boundary=\"$boundary\"";
    @lines.push: '';
    @lines.push: "--$boundary";
    @lines.push: 'Content-Type: text/plain; charset=utf-8';
    @lines.push: '';
    @lines.push: $!text-part;
    @lines.push: "--$boundary";
    @lines.push: 'Content-Type: text/html; charset=utf-8';
    @lines.push: '';
    @lines.push: $!html-part;
    @lines.push: "--$boundary--";
  } elsif self.has-html {
    @lines.push: 'Content-Type: text/html; charset=utf-8';
    @lines.push: '';
    @lines.push: $!html-part;
  } else {
    @lines.push: 'Content-Type: text/plain; charset=utf-8';
    @lines.push: '';
    @lines.push: ($!text-part // '');
  }

  @lines.join("\n")
}
