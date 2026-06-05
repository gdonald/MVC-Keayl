use v6.d;
use MVC::Keayl::View::Handler::HAML;

unit class MVC::Keayl::View;

has @.paths;
has %.handlers;
has Str  $.default-handler = 'haml';
has Str  $.default-format  = 'html';
has Bool $.cache  = True;
has Bool $.reload = True;
has      %!store;

submethod TWEAK {
  %!handlers{'haml'} //= MVC::Keayl::View::Handler::HAML.new;
}

method register-handler(Str:D $extension, $handler --> ::?CLASS) {
  %!handlers{$extension} = $handler;
  self
}

# Resolve a template name and format to a file by search-path then handler
# precedence: {path}/{name}.{format}.{ext}, falling back to {path}/{name}.{ext}.
method resolve(Str:D $name, Str:D $format --> IO::Path) {
  for @!paths -> $path {
    for %!handlers.keys.sort -> $ext {
      my $with-format = $path.IO.add($name ~ '.' ~ $format ~ '.' ~ $ext);
      return $with-format if $with-format.e;
    }
    for %!handlers.keys.sort -> $ext {
      my $bare = $path.IO.add($name ~ '.' ~ $ext);
      return $bare if $bare.e;
    }
  }

  IO::Path
}

method !lookup-name(Str:D $name, $controller --> Str) {
  return $name if $name.contains('/');
  return $name without $controller;
  $controller.controller-path ~ '/' ~ $name
}

method !compiled-for(IO::Path:D $file --> List) {
  my $key     = $file.absolute;
  my $handler = %!handlers{$file.extension} // die "no view handler for .{$file.extension}";

  with %!store{$key} -> $entry {
    return ($entry<compiled>, $handler) if !$!reload || $entry<mtime> == $file.modified.Num;
  }

  my $compiled = $handler.compile($file.slurp);
  %!store{$key} = { mtime => $file.modified.Num, :$compiled } if $!cache;

  ($compiled, $handler)
}

method render-template(Str:D $name, %locals, Str :$format, :$controller --> Str) {
  my $lookup = self!lookup-name($name, $controller);
  my $fmt    = $format // $!default-format;
  my $file   = self.resolve($lookup, $fmt);

  die 'template not found: ' ~ $lookup ~ '.' ~ $fmt unless $file.defined && $file.e;

  my ($compiled, $handler) = self!compiled-for($file);
  $handler.render($compiled, %locals)
}

method render-inline(Str:D $template, %locals, :$controller --> Str) {
  my $handler = %!handlers{$!default-handler} // die "no view handler '$!default-handler'";
  $handler.render($handler.compile($template), %locals)
}

method render-layout(Str:D $layout, Str:D $content, %locals, :$controller --> Str) {
  self.render-template('layouts/' ~ $layout, { %locals, content => $content }, :$controller)
}
