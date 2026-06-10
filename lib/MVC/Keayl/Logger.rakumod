use v6.d;

unit class MVC::Keayl::Logger;

my constant %LEVELS = debug => 0, info => 1, warn => 2, error => 3, silent => 4;

has Str $.level = 'debug';
has     $.out   = $*ERR;

method !threshold(--> Int) { %LEVELS{$!level.lc} // 0 }

method enabled(Str:D $level --> Bool) {
  (%LEVELS{$level.lc} // 0) >= self!threshold
}

method log(Str:D $level, Str:D $message --> Bool) {
  return False unless self.enabled($level);

  $!out.say($message);
  True
}

method debug(Str:D $message --> Bool) { self.log('debug', $message) }
method info(Str:D $message --> Bool)  { self.log('info', $message) }
method warn(Str:D $message --> Bool)  { self.log('warn', $message) }
method error(Str:D $message --> Bool) { self.log('error', $message) }
