use v6.d;

unit class JobFeatWidget;

has $.id;

method find($id) { JobFeatWidget.new(id => $id.Int) }

# The GlobalID locator resolves a class by name through GLOBAL, which a module
# imported into an EVALed spec does not reach on its own.
GLOBAL::<JobFeatWidget> := JobFeatWidget;
