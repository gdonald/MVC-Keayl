use v6.d;
use MVC::Keayl::Controller;

unit class MVC::Keayl::PWAController is MVC::Keayl::Controller;

has Str $.app-name = 'Keayl Application';

method controller-path(--> Str) { 'pwa' }

method manifest {
  self.render(
    json => {
      name             => $!app-name,
      short_name       => 'Keayl',
      start_url        => '/',
      display          => 'standalone',
      background_color => '#ffffff',
      theme_color      => '#000000',
      icons            => [],
    },
    content-type => 'application/manifest+json',
  );
}

method service-worker {
  self.render(
    body         => "self.addEventListener('install', event => self.skipWaiting());\nself.addEventListener('activate', event => event.waitUntil(self.clients.claim()));\n",
    content-type => 'text/javascript',
  );
}
