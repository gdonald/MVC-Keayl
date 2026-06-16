use v6.d;
use MVC::Keayl::SafeString;
use MVC::Keayl::ActionText;
use MVC::Keayl::ActionText::Repository;

unit module MVC::Keayl::ActionText::RichTextable;

my Repository $default-repository;

sub set-rich-text-repository(Repository:D $repository) is export {
  $default-repository = $repository;
}

sub rich-text-repository(--> Repository) is export {
  $default-repository //= MemoryRepository.new
}

sub reset-rich-text() is export {
  $default-repository = Nil;
}

class RichTextProxy is export {
  has $.record   is required;
  has Str $.name is required;
  has $.repository = rich-text-repository();

  method !type { $!record.^name }
  method !id   { $!record.id }

  method row {
    $!repository.find(self!type, self!id, $!name)
  }

  method body(--> MVC::Keayl::ActionText::Content) {
    with self.row -> $row { $row.body } else { MVC::Keayl::ActionText::Content }
  }

  method assign(Str() $html --> ::?CLASS) {
    my $content = MVC::Keayl::ActionText::Content.from-html($html);

    with self.row -> $row {
      $row.body = $content;
    } else {
      $!repository.create(MVC::Keayl::ActionText::RichText.new(
        name        => $!name,
        record-type => self!type,
        record-id   => self!id,
        body        => $content,
      ));
    }

    self
  }

  method to-html(*%options --> SafeString) {
    with self.body -> $body { $body.to-html(|%options) } else { html-safe('') }
  }

  method to-plain-text(--> Str) {
    with self.body -> $body { $body.to-plain-text } else { '' }
  }

  method to-trix-html(--> SafeString) {
    with self.body -> $body { $body.to-trix-html } else { html-safe('') }
  }

  method is-present(--> Bool) {
    self.row.defined && !self.body.is-empty
  }
}

my %declarations{Mu};

sub declarations-for(Mu $class --> Hash) {
  my %merged;
  for $class.^mro.reverse -> $ancestor {
    %merged{.key} = .value for (%declarations{$ancestor} // {}).pairs;
  }
  %merged
}

role RichTextable is export {
  method has-rich-text(Str:D $name --> ::?CLASS) {
    (%declarations{self.WHAT} //= {}){$name} = True;
    self
  }

  method rich-text(Str:D $name --> RichTextProxy) {
    RichTextProxy.new(record => self, :$name)
  }

  method rich-text-names(--> List) {
    declarations-for(self.WHAT).keys.sort.List
  }

  method FALLBACK(Str $name, |args) {
    X::Method::NotFound.new(method => $name, typename => self.^name).throw
      unless declarations-for(self.WHAT){$name}:exists;

    self.rich-text($name)
  }
}
