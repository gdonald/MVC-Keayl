use v6.d;
use MVC::Keayl::Adapter;
use MVC::Keayl::Request;
use MVC::Keayl::Response;

unit class MVC::Keayl::Adapter::Test does MVC::Keayl::Adapter;

method request(
  Str:D $method,
  Str:D $target,
       :%headers,
       :$body,
  Str  :$scheme = 'http',
  Str  :$remote-address,
  --> MVC::Keayl::Response
) {
  my $request = MVC::Keayl::Request.new(
    :$method,
    :$target,
    :%headers,
    :$body,
    :$scheme,
    :$remote-address,
  );

  self.app.call($request)
}

method get(Str:D $target, |c)    { self.request('GET',    $target, |c) }
method post(Str:D $target, |c)   { self.request('POST',   $target, |c) }
method put(Str:D $target, |c)    { self.request('PUT',    $target, |c) }
method patch(Str:D $target, |c)  { self.request('PATCH',  $target, |c) }
method delete(Str:D $target, |c) { self.request('DELETE', $target, |c) }
method head(Str:D $target, |c)   { self.request('HEAD',   $target, |c) }
