use v6.d;
use MVC::Keayl::Storage;

unit module MVC::Keayl::Storage::Repository;

role Repository is export {
  method create-blob(MVC::Keayl::Storage::Blob:D $blob)              { ... }
  method find-blob($id)                                             { ... }
  method find-blob-by-key(Str:D $key)                               { ... }
  method delete-blob(MVC::Keayl::Storage::Blob:D $blob)             { ... }

  method create-attachment(MVC::Keayl::Storage::Attachment:D $att)  { ... }
  method attachments-for(Str:D $type, $id, Str:D $name --> List)    { ... }
  method delete-attachment(MVC::Keayl::Storage::Attachment:D $att)  { ... }

  method attachment-for(Str:D $type, $id, Str:D $name) {
    self.attachments-for($type, $id, $name).head
  }
}

class MemoryRepository does Repository is export {
  has @!blobs;
  has @!attachments;
  has Int $!blob-seq = 0;
  has Int $!attachment-seq = 0;

  method create-blob(MVC::Keayl::Storage::Blob:D $blob) {
    $blob.id = ++$!blob-seq;
    @!blobs.push($blob);
    $blob
  }

  method find-blob($id) {
    @!blobs.first(*.id == $id)
  }

  method find-blob-by-key(Str:D $key) {
    @!blobs.first(*.key eq $key)
  }

  method delete-blob(MVC::Keayl::Storage::Blob:D $blob) {
    @!blobs = @!blobs.grep({ .id != $blob.id });
    Nil
  }

  method create-attachment(MVC::Keayl::Storage::Attachment:D $attachment) {
    $attachment.id = ++$!attachment-seq;
    @!attachments.push($attachment);
    $attachment
  }

  method attachments-for(Str:D $type, $id, Str:D $name --> List) {
    @!attachments.grep({
      .record-type eq $type && .record-id eqv $id && .name eq $name
    }).List
  }

  method delete-attachment(MVC::Keayl::Storage::Attachment:D $attachment) {
    @!attachments = @!attachments.grep({ .id != $attachment.id });
    Nil
  }
}
