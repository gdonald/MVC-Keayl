use v6.d;
use MVC::Keayl::SafeString;
use MVC::Keayl::Helpers::Tag;

unit module MVC::Keayl::Helpers::Asset;

sub default-asset-path(Str:D $source, $type? --> Str) is export {
  return $source if $source.starts-with('/') || $source.contains('://');

  my $path = $source;
  $path ~= '.' ~ $type if $type.defined && !$path.contains('.');

  '/assets/' ~ $path
}

sub asset-path(Str:D $source, :$type, :&resolver = &default-asset-path --> Str) is export {
  resolver($source, $type)
}

sub default-alt(Str:D $source --> Str) {
  $source.subst(/^ .* '/' /, '').subst(/ '.' \w+ $/, '').split(/<[_-]>/)>>.tc.join(' ')
}

sub image-tag(Str:D $source, %options?, :&resolver = &default-asset-path --> SafeString) is export {
  my %attributes = %options // {};

  %attributes<src>   = asset-path($source, :resolver(&resolver));
  %attributes<alt> //= default-alt($source);

  tag('img', %attributes)
}

sub image-submit-tag(Str:D $source, %options?, :&resolver = &default-asset-path --> SafeString) is export {
  my %attributes = %options // {};

  %attributes<type>  = 'image';
  %attributes<src>   = asset-path($source, :resolver(&resolver));
  %attributes<alt> //= default-alt($source);

  tag('input', %attributes)
}

sub stylesheet-link-tag(*@sources, :&resolver = &default-asset-path, *%options --> SafeString) is export {
  safe-join(
    @sources.map(-> $source {
      tag('link', %( rel => 'stylesheet', href => asset-path($source, :type('css'), :resolver(&resolver)), |%options ))
    }),
    "\n"
  )
}

sub javascript-include-tag(*@sources, :&resolver = &default-asset-path, *%options --> SafeString) is export {
  safe-join(
    @sources.map(-> $source {
      content-tag('script', '', %( src => asset-path($source, :type('js'), :resolver(&resolver)), |%options ))
    }),
    "\n"
  )
}
