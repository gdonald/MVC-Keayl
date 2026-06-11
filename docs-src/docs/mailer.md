# Mailer

`MVC::Keayl::Mailer` builds email the way a controller builds a response: an
action renders HAML views into the parts of a message, and a delivery method
sends it.

## Defining a mailer

Subclass `MVC::Keayl::Mailer` and give each action a method that calls `mail`:

```perl6
class NoticeMailer is MVC::Keayl::Mailer {
  method welcome($user) {
    self.mail(
      to      => $user.email,
      from    => 'noreply@example.com',
      subject => 'Welcome',
      locals  => %( name => $user.name ),
    );
  }
}
```

`build($action, |args)` runs the action and returns the
[`MVC::Keayl::Mail`](#the-message); `deliver($action, |args)` builds it and hands
it to the configured delivery, returning the mail.

```perl6
my $mailer = NoticeMailer.new(view-renderer => $view, delivery => $delivery);
$mailer.deliver('welcome', $user);
```

## Views

`mail` renders the message body from views named for the mailer and action,
`<mailer-path>/<action>` (so `NoticeMailer#welcome` looks under
`notice_mailer/welcome`). It renders an `html` and a `text` part when both
templates exist:

```
app/views/notice_mailer/welcome.html.haml
app/views/notice_mailer/welcome.text.haml
```

A message with both parts is multipart; one with a single template carries just
that part. Pass `:template` to override the lookup, `:locals` for the view
locals, `:cc` / `:bcc` for extra recipients, and `:headers` for custom headers.
`default-from` on the mailer supplies a sender when an action gives none.

## The message

`MVC::Keayl::Mail` holds `from`, `to`, `cc`, `bcc`, `subject`, the `html-part`
and `text-part`, and custom `headers`. `encoded` serializes it to an RFC-822
message, using `multipart/alternative` with a text and an html part when both are
present.

## Delivery

A delivery is any `MVC::Keayl::Mailer::Delivery` (a role with one `deliver(Mail)`
method). Three are built in:

- **Test** (`MVC::Keayl::Mailer::Delivery::Test`) collects messages in a
  process-wide list for assertions. `deliveries` reads them, `clear` empties it.
- **File** (`MVC::Keayl::Mailer::Delivery::File`) writes each `encoded` message to
  a numbered `.eml` file under its `directory`.
- **SMTP** (`MVC::Keayl::Mailer::Delivery::SMTP`) builds the envelope (`host`,
  `port`, `from`, `to`, `data`) and hands it to a pluggable `transport` callable,
  which performs the actual send.

```perl6
my $delivery = MVC::Keayl::Mailer::Delivery::SMTP.new(
  host      => 'mail.example.com',
  port      => 587,
  transport => -> %envelope { send-over-smtp(%envelope) },
);
```
