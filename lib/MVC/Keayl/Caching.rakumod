use v6.d;
use JSON::Fast;
use Digest::SHA1::Native;

unit module MVC::Keayl::Caching;

my @day-names    = <Sun Mon Tue Wed Thu Fri Sat>;
my @month-names  = <Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec>;
my %month-number = @month-names.kv.map(-> $index, $name { $name => $index + 1 });

sub http-date(DateTime:D $when --> Str) is export {
  my $utc = $when.utc;
  sprintf('%s, %02d %s %04d %02d:%02d:%02d GMT',
    @day-names[$utc.day-of-week % 7], $utc.day, @month-names[$utc.month - 1],
    $utc.year, $utc.hour, $utc.minute, $utc.second.Int)
}

sub parse-http-date(Str $text --> DateTime) is export {
  return DateTime without $text;

  if $text ~~ / \w+ ',' \s+ (\d+) \s+ (\w+) \s+ (\d+) \s+ (\d+) ':' (\d+) ':' (\d+) / {
    my $month = %month-number{~$1};
    return DateTime without $month;

    return DateTime.new(
      year => +$2, :$month, day => +$0,
      hour => +$3, minute => +$4, second => +$5,
      timezone => 0,
    );
  }

  DateTime
}

sub etag-representation($value --> Str) {
  return $value.cache-key                     if $value.^can('cache-key');
  return to-json($value.to-hash, :!pretty)    if $value.^can('to-hash');
  ~$value
}

sub etag-for($value, Bool :$weak = True --> Str) is export {
  my $quoted = '"' ~ sha1-hex(etag-representation($value)) ~ '"';
  $weak ?? 'W/' ~ $quoted !! $quoted
}
