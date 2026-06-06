use v6.d;
use MVC::Keayl::SafeString;
use MVC::Keayl::Helpers::Tag;

unit module MVC::Keayl::Helpers::Url;

sub url-for($target --> Str) is export {
  return $target.Str if $target ~~ Str;
  return $target<path>.Str if $target ~~ Associative && ($target<path>:exists);
  $target.Str
}

sub link-to($body, $url?, %options? --> SafeString) is export {
  my $href = url-for($url // $body);

  content-tag('a', $body, %( |(%options // {}), href => $href ))
}

sub button-to($body, $url, %options? --> SafeString) is export {
  my %opts         = %options // {};
  my $method       = (%opts<method>:delete) // 'post';
  my %form-options = (%opts<form>:delete) // {};

  my $hidden = $method.lc eq 'post'
    ?? html-safe('')
    !! tag('input', %( type => 'hidden', name => '_method', value => $method.lc ));

  my $button = content-tag('button', $body, %( |%opts, type => 'submit' ));

  content-tag('form', safe-join([$hidden, $button]), %( |%form-options, action => url-for($url), method => 'post' ))
}
