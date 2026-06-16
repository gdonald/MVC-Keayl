use v6.d;
use MVC::Keayl::ActionText;

unit module MVC::Keayl::ActionText::Repository;

role Repository is export {
  method create(MVC::Keayl::ActionText::RichText:D $record) { ... }
  method find(Str:D $type, $id, Str:D $name)                { ... }
  method delete(MVC::Keayl::ActionText::RichText:D $record) { ... }
}

class MemoryRepository does Repository is export {
  has @!records;
  has Int $!seq = 0;

  method create(MVC::Keayl::ActionText::RichText:D $record) {
    $record.id = ++$!seq;
    @!records.push($record);
    $record
  }

  method find(Str:D $type, $id, Str:D $name) {
    @!records.first({
      .record-type eq $type && .record-id eqv $id && .name eq $name
    })
  }

  method delete(MVC::Keayl::ActionText::RichText:D $record) {
    @!records = @!records.grep({ .id != $record.id });
    Nil
  }
}
