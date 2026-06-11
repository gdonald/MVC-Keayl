use v6.d;
use MVC::Keayl::ErrorReporter;

unit class MVC::Keayl::ErrorReporting;

has @.reporters;

method subscribe(MVC::Keayl::ErrorReporter:D $reporter --> ::?CLASS) {
  @!reporters.push: $reporter;
  self
}

method reporters-count(--> Int) { @!reporters.elems }

method report(Exception:D $error, %context) {
  for @!reporters -> $reporter {
    try $reporter.report($error, %context);
  }
}
