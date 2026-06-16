use v6.d;
use MVC::Keayl::SafeString;
use MVC::Keayl::Helpers::Tag;
use MVC::Keayl::Helpers::Url;
use MVC::Keayl::Helpers::Options;

unit module MVC::Keayl::Helpers::Form;

sub member-value($item, $accessor) {
  return $item."$accessor"() if $item.^can(~$accessor);
  return $item{$accessor}    if $item ~~ Associative;
  ~$item
}

sub date-part($value, Str:D $part) {
  return Nil without $value;

  given $part {
    when 'year'   { return $value.year       if $value ~~ Dateish }
    when 'month'  { return $value.month      if $value ~~ Dateish }
    when 'day'    { return $value.day        if $value ~~ Dateish }
    when 'hour'   { return $value.hour       if $value ~~ DateTime }
    when 'minute' { return $value.minute     if $value ~~ DateTime }
    when 'second' { return $value.second.Int if $value ~~ DateTime }
  }

  Nil
}

sub date-year-range($value --> List) {
  my $center = date-part($value, 'year') // 2020;
  (($center - 5) .. ($center + 5)).list
}

sub humanize(Str:D $attribute --> Str) {
  $attribute.subst(/<[_-]>/, ' ', :g).tc
}

sub model-name($model --> Str) {
  return $model.model-name if $model.^can('model-name');
  $model.^name.subst(/^ 'GLOBAL::' /, '').subst(/^ .* '::' /, '').&{ $_.subst(/<?after .> <:Lu>/, { '_' ~ $/.Str }, :g).lc }
}

sub checkbox-checked($current, $checked-value --> Bool) {
  return True if $current === True;
  return False without $current;
  ~$current eq ~$checked-value
}

sub trix-value($value --> Str) {
  return '' without $value;
  return $value.to-trix-html.Str if $value.^can('to-trix-html');
  ~$value
}

sub rich-text-area-markup(Str:D $name, Str:D $id, Str:D $value, %options --> SafeString) is export {
  my %editor = %options;
  my $input-id = $id ~ '_trix_input';

  %editor<input> = $input-id;
  %editor<class> = class-names(%editor<class> // '', 'trix-content');

  my $hidden = tag('input', %( type => 'hidden', :$name, id => $input-id, value => $value ));
  my $editor = content-tag('trix-editor', '', %editor);

  safe-join([$hidden, $editor], "\n")
}

sub rich-text-area-tag(Str:D $name, $value?, %options? --> SafeString) is export {
  rich-text-area-markup($name, $name, trix-value($value), %options // {})
}

class FormBuilder is export {
  has Str $.object-name;
  has     $.model;
  has     $.i18n;

  method label-text(Str:D $attribute --> Str) {
    return humanize($attribute) without $!i18n;
    $!i18n.form-label($!object-name // $attribute, $attribute)
  }

  method placeholder-text(Str:D $attribute --> Str) {
    return humanize($attribute) without $!i18n;
    $!i18n.form-placeholder($!object-name // $attribute, $attribute)
  }

  method field-name(Str:D $attribute --> Str) {
    $!object-name ?? $!object-name ~ '[' ~ $attribute ~ ']' !! $attribute
  }

  method field-id(Str:D $attribute --> Str) {
    self.field-name($attribute).subst('[', '_', :g).subst(']', '', :g)
  }

  method field-value(Str:D $attribute) {
    return Nil without $!model;
    return $!model."$attribute"() if $!model.^can($attribute);
    Nil
  }

  method errors-on(Str:D $attribute --> List) {
    return () without $!model;
    return $!model.errors-on($attribute).list if $!model.^can('errors-on');
    ()
  }

  method !base-attributes(Str:D $attribute, %options --> Hash) {
    my %attrs = %options;

    %attrs<name> //= self.field-name($attribute);
    %attrs<id>   //= self.field-id($attribute);
    %attrs<class> = class-names(%attrs<class> // '', 'field-with-errors') if self.errors-on($attribute);
    %attrs<placeholder> = self.placeholder-text($attribute) if (%attrs<placeholder> // False) === True;

    %attrs
  }

  method text-field(Str:D $attribute, %options? --> SafeString) {
    my %attrs = self!base-attributes($attribute, %options // {});

    %attrs<type> //= 'text';

    my $value = %attrs<value>:exists ?? (%attrs<value>:delete) !! self.field-value($attribute);
    %attrs<value> = ~$value if $value.defined;

    tag('input', %attrs)
  }

  method password-field(Str:D $attribute, %options? --> SafeString) {
    my %attrs = self!base-attributes($attribute, %options // {});

    %attrs<type> = 'password';

    tag('input', %attrs)
  }

  method hidden-field(Str:D $attribute, %options? --> SafeString) {
    my %attrs = self!base-attributes($attribute, %options // {});

    %attrs<type> = 'hidden';

    my $value = %attrs<value>:exists ?? (%attrs<value>:delete) !! self.field-value($attribute);
    %attrs<value> = ~$value if $value.defined;

    tag('input', %attrs)
  }

  method !value-field(Str:D $type, Str:D $attribute, %options --> SafeString) {
    my %attrs = self!base-attributes($attribute, %options);

    %attrs<type> = $type;

    my $value = %attrs<value>:exists ?? (%attrs<value>:delete) !! self.field-value($attribute);
    %attrs<value> = ~$value if $value.defined;

    tag('input', %attrs)
  }

  method email-field(Str:D $attribute, %options? --> SafeString)     { self!value-field('email', $attribute, %options // {}) }
  method url-field(Str:D $attribute, %options? --> SafeString)       { self!value-field('url', $attribute, %options // {}) }
  method telephone-field(Str:D $attribute, %options? --> SafeString) { self!value-field('tel', $attribute, %options // {}) }
  method number-field(Str:D $attribute, %options? --> SafeString)    { self!value-field('number', $attribute, %options // {}) }
  method range-field(Str:D $attribute, %options? --> SafeString)     { self!value-field('range', $attribute, %options // {}) }
  method search-field(Str:D $attribute, %options? --> SafeString)    { self!value-field('search', $attribute, %options // {}) }
  method color-field(Str:D $attribute, %options? --> SafeString)     { self!value-field('color', $attribute, %options // {}) }

  method date-field(Str:D $attribute, %options? --> SafeString)     { self!value-field('date', $attribute, %options // {}) }
  method time-field(Str:D $attribute, %options? --> SafeString)     { self!value-field('time', $attribute, %options // {}) }
  method datetime-field(Str:D $attribute, %options? --> SafeString) { self!value-field('datetime-local', $attribute, %options // {}) }
  method month-field(Str:D $attribute, %options? --> SafeString)    { self!value-field('month', $attribute, %options // {}) }
  method week-field(Str:D $attribute, %options? --> SafeString)     { self!value-field('week', $attribute, %options // {}) }

  method file-field(Str:D $attribute, %options? --> SafeString) {
    my %opts          = %options // {};
    my $multiple      = %opts<multiple>:delete;
    my $direct-upload = %opts<direct-upload>:delete;

    my %attrs = self!base-attributes($attribute, %opts);
    %attrs<type> = 'file';

    if $multiple {
      %attrs<multiple> = True;
      %attrs<name>     = %attrs<name> ~ '[]';
    }

    if $direct-upload {
      %attrs<data> = %( |(%attrs<data> // {}), 'direct-upload-url' => ~$direct-upload );
    }

    tag('input', %attrs)
  }

  method text-area(Str:D $attribute, %options? --> SafeString) {
    my %attrs = self!base-attributes($attribute, %options // {});

    my $value = %attrs<value>:exists ?? (%attrs<value>:delete) !! self.field-value($attribute);

    content-tag('textarea', ~($value // ''), %attrs)
  }

  method rich-text-area(Str:D $attribute, %options? --> SafeString) {
    my %opts  = %options // {};
    my $value = %opts<value>:exists ?? (%opts<value>:delete) !! self.field-value($attribute);

    rich-text-area-markup(
      self.field-name($attribute),
      self.field-id($attribute),
      trix-value($value),
      %opts,
    )
  }

  method check-box(Str:D $attribute, %options?, $checked-value = '1', $unchecked-value = '0' --> SafeString) {
    my $hidden = tag('input', %( type => 'hidden', name => self.field-name($attribute), value => ~$unchecked-value ));

    my %attrs = self!base-attributes($attribute, %options // {});
    %attrs<type>  = 'checkbox';
    %attrs<value> = ~$checked-value;
    %attrs<checked> = True if checkbox-checked(self.field-value($attribute), $checked-value);

    safe-join([$hidden, tag('input', %attrs)])
  }

  method radio-button(Str:D $attribute, $value, %options? --> SafeString) {
    my %attrs = self!base-attributes($attribute, %options // {});
    %attrs<type>  = 'radio';
    %attrs<id>    = self.field-id($attribute) ~ '_' ~ ~$value;
    %attrs<value> = ~$value;

    my $current = self.field-value($attribute);
    %attrs<checked> = True if $current.defined && ~$current eq ~$value;

    tag('input', %attrs)
  }

  method select(Str:D $attribute, @choices, %options? --> SafeString) {
    my $selected = self.field-value($attribute);

    my @option-tags = @choices.map(-> $choice {
      my ($label, $value) = $choice ~~ Pair ?? ($choice.key, $choice.value) !! ($choice, $choice);
      my %option = value => ~$value;
      %option<selected> = True if $selected.defined && ~$selected eq ~$value;
      content-tag('option', ~$label, %option)
    });

    my %attrs = self!base-attributes($attribute, %options // {});

    content-tag('select', safe-join(@option-tags), %attrs)
  }

  method collection-select(Str:D $attribute, @collection, $value-method, $text-method, %options? --> SafeString) {
    my @choices = @collection.map(-> $item {
      member-value($item, $text-method) => member-value($item, $value-method)
    });

    self.select($attribute, @choices, %options // {})
  }

  method collection-radio-buttons(Str:D $attribute, @collection, $value-method, $text-method, %options? --> SafeString) {
    my $selected = self.field-value($attribute);

    safe-join(@collection.map(-> $item {
      my $value = member-value($item, $value-method);
      my $text  = member-value($item, $text-method);
      my $id    = self.field-id($attribute) ~ '_' ~ ~$value;

      my %attrs = type => 'radio', name => self.field-name($attribute), :$id, value => ~$value;
      %attrs<checked> = True if $selected.defined && ~$selected eq ~$value;

      safe-join([tag('input', %attrs), content-tag('label', $text, %( for => $id ))])
    }), "\n")
  }

  method collection-check-boxes(Str:D $attribute, @collection, $value-method, $text-method, %options? --> SafeString) {
    my @selected = (self.field-value($attribute) // []).list.map(~*);

    safe-join(@collection.map(-> $item {
      my $value = member-value($item, $value-method);
      my $text  = member-value($item, $text-method);
      my $id    = self.field-id($attribute) ~ '_' ~ ~$value;

      my %attrs = type => 'checkbox', name => self.field-name($attribute) ~ '[]', :$id, value => ~$value;
      %attrs<checked> = True if @selected.first({ $_ eq ~$value });

      safe-join([tag('input', %attrs), content-tag('label', $text, %( for => $id ))])
    }), "\n")
  }

  method date-select(Str:D $attribute, %options? --> SafeString) {
    my $value  = self.field-value($attribute);
    my $prefix = self.field-name($attribute);

    safe-join([
      multiparam-select($prefix, 1, (date-year-range($value).map({ $_ => $_ })), date-part($value, 'year')),
      multiparam-select($prefix, 2, month-choices(), date-part($value, 'month')),
      multiparam-select($prefix, 3, (1 .. 31).map({ $_ => $_ }), date-part($value, 'day')),
    ], "\n")
  }

  method time-select(Str:D $attribute, %options? --> SafeString) {
    my $value  = self.field-value($attribute);
    my $prefix = self.field-name($attribute);

    safe-join([
      multiparam-select($prefix, 4, (0 .. 23).map({ sprintf('%02d', $_) => $_ }), date-part($value, 'hour')),
      multiparam-select($prefix, 5, (0 .. 59).map({ sprintf('%02d', $_) => $_ }), date-part($value, 'minute')),
    ], "\n")
  }

  method datetime-select(Str:D $attribute, %options? --> SafeString) {
    safe-join([self.date-select($attribute, %options // {}), self.time-select($attribute, %options // {})], "\n")
  }

  method label(Str:D $attribute, $text?, %options? --> SafeString) {
    my %attrs = %options // {};
    %attrs<for> //= self.field-id($attribute);

    content-tag('label', $text // self.label-text($attribute), %attrs)
  }

  method !submit-action(--> Str) {
    return 'submit' without $!model;

    my $persisted = do if $!model.^can('is-persisted') {
      ?$!model.is-persisted
    } elsif $!model.^can('id') {
      $!model.id.defined
    } else {
      False
    };

    $persisted ?? 'update' !! 'create'
  }

  method !default-submit(--> Str) {
    return 'Save' without $!i18n;
    return 'Save' without $!object-name;

    $!i18n.submit-default($!object-name, self!submit-action)
  }

  method submit($value?, %options? --> SafeString) {
    my %attrs = %options // {};
    %attrs<type>  //= 'submit';
    %attrs<value> //= ~($value // self!default-submit);

    tag('input', %attrs)
  }

  method button($value, %options? --> SafeString) {
    my %attrs = %options // {};
    %attrs<type> //= 'submit';

    content-tag('button', $value, %attrs)
  }

  method fields-for(Str:D $attribute, :$model, :&block --> SafeString) {
    my $nested = FormBuilder.new(
      object-name => self.field-name($attribute),
      model       => $model // self.field-value($attribute),
      i18n        => $!i18n,
    );

    &block ?? block($nested) !! html-safe('')
  }

  method errors-for(Str:D $attribute --> SafeString) {
    my @messages = self.errors-on($attribute);
    return html-safe('') unless @messages;

    content-tag('span', @messages.join(', '), %( class => 'error' ))
  }
}

sub wrap-form($inner, %options, :$url, :$method = 'post', :$csrf-token --> SafeString) {
  my $verb = $method.lc;
  my @hidden;

  @hidden.push: tag('input', %( type => 'hidden', name => '_method', value => $verb ))
    unless $verb eq 'get' | 'post';

  @hidden.push: tag('input', %( type => 'hidden', name => 'authenticity_token', value => $csrf-token ))
    if $csrf-token.defined;

  my %attrs = %options;
  %attrs<action> = url-for($url) if $url.defined;
  %attrs<method> = $verb eq 'get' ?? 'get' !! 'post';

  content-tag('form', safe-join([|@hidden, $inner]), %attrs)
}

sub form-with(:$model, :$url, :$scope, :$method = 'post', :$csrf-token, :$i18n, :&content, *%options --> SafeString) is export {
  my $object-name = $scope // ($model.defined ?? model-name($model) !! Str);

  my $builder = FormBuilder.new(:$object-name, :$model, :$i18n);
  my $inner   = &content ?? content($builder) !! html-safe('');

  wrap-form($inner, %options, :$url, :$method, :$csrf-token)
}

class SimpleFormBuilder is FormBuilder is export {
  has @.required-attributes;

  method !input-type(Str:D $attribute --> Str) {
    return 'password' if $attribute.ends-with('password');
    return 'email'    if $attribute.ends-with('email');
    return 'text'     if $attribute eq 'description' | 'body' | 'content' | 'notes';

    self.field-value($attribute) ~~ Bool ?? 'boolean' !! 'string'
  }

  method !is-required(Str:D $attribute --> Bool) {
    return True if @!required-attributes.first({ $_ eq $attribute });
    return ?self.model.required-attribute($attribute) if self.model.defined && self.model.^can('required-attribute');
    False
  }

  method !input-label(Str:D $attribute, $label-option, Bool $required --> SafeString) {
    return html-safe('') if $label-option === False;

    my $text  = $label-option ~~ Str ?? $label-option !! self.label-text($attribute);
    my $inner = $required
      ?? safe-join([html-safe(html-escape($text)), content-tag('abbr', '*', %( title => 'required' ))], ' ')
      !! html-safe(html-escape($text));

    content-tag('label', $inner, %( for => self.field-id($attribute) ))
  }

  method !input-control(Str:D $as, Str:D $attribute, $collection, %options --> SafeString) {
    given $as {
      when 'text'     { self.text-area($attribute, %options) }
      when 'password' { self.password-field($attribute, %options) }
      when 'boolean'  { self.check-box($attribute, %options) }
      when 'select'   { self.select($attribute, ($collection // []).list, %options) }
      when 'string'   { self.text-field($attribute, %options) }
      default         { self.text-field($attribute, %( |%options, type => $as )) }
    }
  }

  method input(Str:D $attribute, %options? --> SafeString) {
    my %opts = %options // {};

    my $as           = (%opts<as>:delete)         // self!input-type($attribute);
    my $required     = (%opts<required>:delete)   // self!is-required($attribute);
    my $hint-text    = %opts<hint>:delete;
    my $label-option = %opts<label>:delete;
    my $collection   = %opts<collection>:delete;

    my $has-errors = ?self.errors-on($attribute);

    my $label   = self!input-label($attribute, $label-option, $required);
    my $control = self!input-control($as, $attribute, $collection, %opts);
    my $hint    = $hint-text.defined ?? content-tag('span', ~$hint-text, %( class => 'hint' )) !! html-safe('');
    my $error   = self.errors-for($attribute);

    my $wrapper-class = class-names(
      'input', $as,
      %( required => $required, optional => !$required, 'field-with-errors' => $has-errors ),
    );

    content-tag('div', safe-join([$label, $control, $hint, $error].grep({ ~$_ ne '' })), %( class => $wrapper-class ))
  }
}

sub simple-form-for($model, :$url, :$scope, :$method = 'post', :$csrf-token, :$i18n, :@required, :&content, *%options --> SafeString) is export {
  my $object-name = $scope // ($model.defined ?? model-name($model) !! Str);

  my $builder = SimpleFormBuilder.new(:$object-name, :$model, :$i18n, :required-attributes(@required));
  my $inner   = &content ?? content($builder) !! html-safe('');

  wrap-form($inner, %options, :$url, :$method, :$csrf-token)
}
