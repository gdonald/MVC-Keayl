use v6.d;
use MVC::Keayl::Mail;

unit class MVC::Keayl::Mailer;

has     $.view-renderer;
has     $.delivery;
has Str $.default-from;
has Str $.action is rw;

sub underscore(Str:D $word --> Str) {
  $word.subst(/<?after .> <:Lu>/, { '_' ~ $/.Str }, :g).lc
}

sub normalize($value --> List) {
  return () without $value;
  ($value ~~ Positional ?? $value.list !! ($value,)).grep(*.defined).list
}

method mailer-path(--> Str) {
  underscore(self.^name.subst(/^ 'GLOBAL::' /, ''))
}

method !render-part(Str:D $template, Str:D $format, %locals --> Str) {
  return Str without $!view-renderer;

  my $file = $!view-renderer.resolve($template, $format);
  return Str unless $file.defined && $file.e;

  $!view-renderer.render-template($template, %locals, :$format)
}

method mail(:$to, :$from, :$subject, :$cc, :$bcc, :%locals, :%headers, Str :$template --> MVC::Keayl::Mail) {
  my $name = $template // (self.mailer-path ~ '/' ~ $!action);

  my $html = self!render-part($name, 'html', %locals);
  my $text = self!render-part($name, 'text', %locals);

  MVC::Keayl::Mail.new(
    from      => ($from // $!default-from),
    to        => normalize($to),
    cc        => normalize($cc),
    bcc       => normalize($bcc),
    :$subject,
    html-part => $html,
    text-part => $text,
    headers   => %headers,
  )
}

method build(Str:D $action, |args --> MVC::Keayl::Mail) {
  $!action = $action;
  self."$action"(|args)
}

method deliver(Str:D $action, |args --> MVC::Keayl::Mail) {
  my $mail = self.build($action, |args);
  .deliver($mail) with $!delivery;

  $mail
}
