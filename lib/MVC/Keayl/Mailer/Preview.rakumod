use v6.d;
use MVC::Keayl::Controller;
use MVC::Keayl::SafeString;

unit module MVC::Keayl::Mailer::Preview;

my %registry;

class Preview is export {
}

class Previews is export {
  method register(Str:D $name, $preview-class) {
    %registry{$name} = $preview-class;
    self
  }

  method reset {
    %registry = ();
    self
  }

  method names(--> List) {
    %registry.keys.sort.List
  }

  method emails(Str:D $name --> List) {
    return () unless %registry{$name}:exists;

    my $class     = %registry{$name};
    my $inherited = Preview.^methods.map(*.name).Set;

    $class.^methods.map(*.name).grep({ !$inherited{$_} && $_ !~~ /^ <[A..Z_]>/ }).unique.sort.List
  }

  method mail(Str:D $name, Str:D $email) {
    return Nil unless %registry{$name}:exists;
    return Nil unless self.emails($name).first($email);

    %registry{$name}.new."$email"()
  }
}

class PreviewController is MVC::Keayl::Controller is export {
  method index {
    my @items;

    for Previews.names -> $name {
      @items.push: '<li>' ~ html-escape($name) ~ '<ul>';
      for Previews.emails($name) -> $email {
        my $path = '/keayl/mailers/' ~ $name ~ '/' ~ $email;
        @items.push: '<li><a href="' ~ html-escape($path) ~ '">' ~ html-escape($email) ~ '</a></li>';
      }
      @items.push: '</ul></li>';
    }

    self.render(html => '<ul>' ~ @items.join ~ '</ul>')
  }

  method show {
    my $name  = self.params<preview>;
    my $email = self.params<email>;
    my $part  = self.params<part> // 'html';

    my $mail = Previews.mail($name, $email);
    return self.head(404) without $mail;

    given $part {
      when 'text' { self.render(plain => $mail.text-part // '') }
      when 'raw'  { self.render(plain => $mail.encoded) }
      default     { self.render(html => $mail.html-part // $mail.text-part // '') }
    }
  }
}
