use v6.d;
use JSON::Fast;
use Crypt::Random;

sub generate-session-id(--> Str) {
  crypt_random_buf(16).list.map(*.fmt('%02x')).join
}

class MVC::Keayl::Session does Associative {
  has      %.data;
  has Bool $.dirty = False;
  has Bool $.was-reset = False;

  method AT-KEY(Str() $key)              { %!data{$key} }
  method EXISTS-KEY(Str() $key --> Bool) { %!data{$key}:exists }

  method ASSIGN-KEY(Str() $key, $value) {
    %!data{$key} = $value;
    $!dirty = True;
  }

  method DELETE-KEY(Str() $key) {
    $!dirty = True;
    %!data{$key}:delete;
  }

  method reset {
    %!data       = ();
    $!dirty      = True;
    $!was-reset  = True;
  }

  method keys    { %!data.keys }
  method to-hash { %!data.clone }
  method empty(--> Bool) { %!data.elems == 0 }
}

role MVC::Keayl::Session::Store {
  method load($cookies --> Hash)             { ... }
  method commit($cookies, $session)          { ... }
}

class MVC::Keayl::Session::CookieStore does MVC::Keayl::Session::Store {
  has Str $.key        = '_session';
  has Str $.serializer = 'signed';

  method !jar($cookies) {
    $!serializer eq 'encrypted' ?? $cookies.encrypted !! $cookies.signed
  }

  method load($cookies --> Hash) {
    my $raw = self!jar($cookies){$!key};
    return {} without $raw;
    (try from-json($raw)) // {}
  }

  method commit($cookies, $session) {
    return unless $session.dirty;

    if $session.empty {
      $cookies.delete($!key);
    } else {
      self!jar($cookies).set($!key, to-json($session.to-hash, :!pretty), :http-only, :path('/'));
    }
  }
}

role MVC::Keayl::Session::Backend {
  method read(Str $id --> Hash)   { ... }
  method write(Str $id, %data)    { ... }
  method delete(Str $id)          { ... }
}

class MVC::Keayl::Session::MemoryBackend does MVC::Keayl::Session::Backend {
  has %.sessions;

  method read(Str $id --> Hash) { (%!sessions{$id} // {}).clone }
  method write(Str $id, %data)  { %!sessions{$id} = %data.clone }
  method delete(Str $id)        { %!sessions{$id}:delete }
}

class MVC::Keayl::Session::ServerSideStore does MVC::Keayl::Session::Store {
  has      $.backend is required;
  has Str  $.key = '_session_id';

  method load($cookies --> Hash) {
    my $id = $cookies.signed{$!key};
    return {} without $id;
    $!backend.read($id)
  }

  method commit($cookies, $session) {
    return unless $session.dirty;

    my $current-id = $cookies.signed{$!key};

    if $session.was-reset {
      $!backend.delete($current-id) with $current-id;
      $current-id = Str;
    }

    if $session.empty {
      $!backend.delete($current-id) with $current-id;
      $cookies.delete($!key);
    } else {
      my $id = $current-id // generate-session-id();
      $cookies.signed.set($!key, $id, :http-only, :path('/'));
      $!backend.write($id, $session.to-hash);
    }
  }
}
