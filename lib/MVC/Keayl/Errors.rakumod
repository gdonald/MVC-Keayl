use v6.d;

class X::MVC::Keayl::NotFound is Exception {
  has $.message-text = 'not found';
  method message(--> Str) { $!message-text }
}

class X::MVC::Keayl::InvalidAuthenticityToken is Exception {
  has $.message-text = 'invalid authenticity token';
  method message(--> Str) { $!message-text }
}
