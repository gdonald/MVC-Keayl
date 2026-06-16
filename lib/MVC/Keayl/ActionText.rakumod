use v6.d;
use MVC::Keayl::SafeString;
use MVC::Keayl::Storage;
use MVC::Keayl::Storage::Attached;

unit module MVC::Keayl::ActionText;

my @rich-text-tags = <
  a abbr acronym address b big blockquote br cite code dd del dfn div dl dt
  em figcaption figure h1 h2 h3 h4 h5 h6 hr i img kbd li ol p pre samp small
  span strong sub sup time tt ul var action-text-attachment
>;

my @rich-text-attributes = <
  href src alt title width height name datetime sgid content-type url filename
  filesize previewable presentation caption class
>;

sub sanitize-rich-text(Str() $html --> SafeString) is export {
  sanitize($html, tags => @rich-text-tags, attributes => @rich-text-attributes)
}

sub attr-value(Str $attrs, Str $name --> Str) {
  return Str without $attrs;
  $attrs ~~ / « $name » \s* '=' \s* (<['"]>) (.*?) $0 / ?? ~$1 !! Str
}

sub default-resolver() {
  -> $sgid {
    my $id = storage-verifier.verify($sgid, purpose => 'blob');
    $id.defined ?? storage-repository.find-blob($id) !! Nil
  }
}

sub render-attachment($blob --> Str) {
  return '' without $blob;

  my $path = blob-serving-path($blob, :proxy);

  if $blob.is-image {
    my $kind = ($blob.extension // 'file').lc;
    '<figure class="attachment attachment--preview attachment--' ~ $kind ~ '">'
      ~ '<img src="' ~ html-escape($path) ~ '" alt="' ~ html-escape($blob.filename // '') ~ '">'
      ~ '</figure>'
  } else {
    '<figure class="attachment attachment--file">'
      ~ '<a href="' ~ html-escape($path) ~ '">' ~ html-escape($blob.filename // '') ~ '</a>'
      ~ '</figure>'
  }
}

sub embed-tag($blob --> Str) is export {
  my $sgid = storage-verifier.generate($blob.id, purpose => 'blob');

  '<action-text-attachment sgid="' ~ html-escape($sgid)
    ~ '" content-type="' ~ html-escape($blob.content-type // '')
    ~ '" filename="' ~ html-escape($blob.filename // '')
    ~ '"></action-text-attachment>'
}

class Content is export {
  has Str $.html = '';

  method from-html(Str() $html --> Content) {
    self.new(html => sanitize-rich-text($html).Str)
  }

  method to-trix-html(--> SafeString) {
    html-safe($!html)
  }

  method to-plain-text(--> Str) {
    $!html.subst(/'<' <-[>]>* '>'/, ' ', :g).subst(/\s+/, ' ', :g).trim
  }

  method attachment-sgids(--> List) {
    my @sgids;
    for $!html.match(/ '<action-text-attachment' (<-[>]>*) '>' /, :g) -> $match {
      my $sgid = attr-value(~$match[0], 'sgid');
      @sgids.push($sgid) if $sgid.defined;
    }
    @sgids.List
  }

  method to-html(:&resolver --> SafeString) {
    my &resolve = &resolver // default-resolver();

    my $rendered = $!html.subst(
      / '<action-text-attachment' (<-[>]>*) '>' [ .*? '</action-text-attachment>' ]? /,
      { render-attachment(resolve(attr-value(~$0, 'sgid'))) },
      :g
    );

    html-safe($rendered)
  }

  method is-empty(--> Bool) {
    self.to-plain-text eq '' && self.attachment-sgids.elems == 0
  }

  method Str(--> Str)  { self.to-html.Str }
  method gist(--> Str) { self.Str }
}

class RichText is export {
  has $.id is rw;
  has Str $.name;
  has Str $.record-type;
  has $.record-id;
  has Content $.body is rw;

  method to-html(*%options --> SafeString) {
    $!body.defined ?? $!body.to-html(|%options) !! html-safe('')
  }

  method to-plain-text(--> Str) {
    $!body.defined ?? $!body.to-plain-text !! ''
  }
}

sub rich-text($value, *%options --> SafeString) is export {
  return html-safe('') without $value;
  return $value.to-html(|%options) if $value.^can('to-html');

  Content.from-html(~$value).to-html(|%options)
}
