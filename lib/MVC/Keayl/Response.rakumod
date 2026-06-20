use v6.d;
use MVC::Keayl::Live;

unit class MVC::Keayl::Response;

has Int $.status is rw;
has     @!body-parts;
has     $!binary-body;

has %!headers;
has @!header-order;
has $!stream-source;
has $!live;
has $.live-promise is rw;

submethod BUILD(Int :$status = 200, :%headers, :$body) {
  $!status = $status;

  for %headers.kv -> $name, $value {
    self.set-header($name, $value ~~ Positional ?? $value.join(', ') !! ~$value);
  }

  @!body-parts = $body.defined ?? [$body] !! [];
}

method set-header(Str:D $name, Str:D $value) {
  my $key = $name.lc;

  @!header-order.push($key) unless %!headers{$key}:exists;
  %!headers{$key} = { name => $name, values => [$value] };

  self
}

method add-header(Str:D $name, Str:D $value) {
  my $key = $name.lc;

  if %!headers{$key}:exists {
    %!headers{$key}<values>.push($value);
  } else {
    @!header-order.push($key);
    %!headers{$key} = { name => $name, values => [$value] };
  }

  self
}

method delete-header(Str:D $name) {
  my $key = $name.lc;

  %!headers{$key}:delete;
  @!header-order = @!header-order.grep(* ne $key);

  self
}

method has-header(Str:D $name --> Bool) {
  %!headers{$name.lc}:exists
}

method header(Str:D $name --> Str) {
  my $key = $name.lc;
  return Str unless %!headers{$key}:exists;

  %!headers{$key}<values>.join(', ')
}

method header-values(Str:D $name --> List) {
  my $key = $name.lc;
  return () unless %!headers{$key}:exists;

  %!headers{$key}<values>.List
}

method headers(--> Hash) {
  my %out;

  for @!header-order -> $key {
    %out{ %!headers{$key}<name> } = %!headers{$key}<values>.join(', ');
  }

  %out
}

method !header-pairs(--> List) {
  my @out;

  for @!header-order -> $key {
    for %!headers{$key}<values>.list -> $value {
      @out.push: %!headers{$key}<name> => $value;
    }
  }

  @out
}

multi method content-type(--> Str)            { self.header('content-type') }
multi method content-type(Str:D $value)       { self.set-header('Content-Type', $value) }

multi method location(--> Str)                { self.header('location') }
multi method location(Str:D $value)           { self.set-header('Location', $value) }

method content-length(--> Int) {
  self!body-blob.bytes
}

method write(Str:D $chunk) {
  @!body-parts.push($chunk);
  self
}

method stream($source --> ::?CLASS) {
  $!stream-source = $source;
  self
}

method is-streaming(--> Bool) {
  $!stream-source.defined
}

method stream-chunks(--> Seq) {
  return ().Seq without $!stream-source;
  $!stream-source.map({ $_ ~~ Blob ?? $_ !! .Str.encode('utf-8') }).Seq
}

method live-stream(--> MVC::Keayl::Live::Stream) {
  without $!live {
    $!live = MVC::Keayl::Live::Stream.new;
    $!stream-source = $!live.chunks;
  }

  $!live
}

method is-live(--> Bool) {
  $!live.defined
}

method stream-supply(--> Supply) {
  supply {
    emit $_ for self.stream-chunks;
  }
}

method streaming-finish(--> List) {
  self.set-header('Content-Type', 'text/html; charset=utf-8')
    unless self.has-header('content-type');

  ($!status, $(self!header-pairs))
}

multi method body(--> Str)              { $!binary-body.defined ?? $!binary-body.decode('utf-8') !! @!body-parts.join }
multi method body(Str:D $value)         { $!binary-body = Nil; @!body-parts = [$value]; self }
multi method body(Blob:D $value)        { $!binary-body = $value; @!body-parts = []; self }

method !body-blob(--> Blob) {
  $!binary-body // self.body.encode('utf-8')
}

method finish(--> List) {
  self.set-header('Content-Type', 'text/html; charset=utf-8')
    unless self.has-header('content-type');

  my $blob = self!body-blob;
  self.set-header('Content-Length', $blob.bytes.Str);

  ($!status, $(self!header-pairs), $($blob))
}
