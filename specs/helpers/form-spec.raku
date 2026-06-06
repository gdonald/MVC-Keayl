use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Helpers::Form;

class FormPost {
  has $.title;
  has $.published;
  has @.errors-title;
  method errors-on($attribute) { $attribute eq 'title' ?? @!errors-title !! () }
  method model-name { 'post' }
}

describe 'MVC::Keayl::Helpers::FormBuilder naming', {
  it 'scopes a field name to the object name', {
    expect(FormBuilder.new(:object-name('post')).field-name('title')).to.be('post[title]');
  }

  it 'derives a field id from the field name', {
    expect(FormBuilder.new(:object-name('post')).field-id('title')).to.be('post_title');
  }
}

describe 'MVC::Keayl::Helpers::FormBuilder fields', {
  it 'prefills a text field from the model', {
    expect(FormBuilder.new(:object-name('post'), :model(FormPost.new(title => 'Hi'))).text-field('title').Str).to.be('<input id="post_title" name="post[title]" type="text" value="Hi" />');
  }

  it 'lets an explicit value override the model', {
    expect(FormBuilder.new(:object-name('post'), :model(FormPost.new(title => 'Hi'))).text-field('title', %( value => 'Over' )).Str).to.be('<input id="post_title" name="post[title]" type="text" value="Over" />');
  }

  it 'never emits a value for a password field', {
    expect(FormBuilder.new(:object-name('user'), :model(FormPost.new(title => 'secret'))).password-field('title').Str.contains('value')).to.be-falsy;
  }

  it 'prefills a textarea content', {
    expect(FormBuilder.new(:object-name('post'), :model(FormPost.new(title => 'Body'))).text-area('title').Str).to.be('<textarea id="post_title" name="post[title]">Body</textarea>');
  }

  it 'renders a hidden companion for a checkbox', {
    expect(FormBuilder.new(:object-name('post')).check-box('published').Str.contains('name="post[published]" type="hidden" value="0"')).to.be-truthy;
  }

  it 'checks a checkbox when the model value is set', {
    expect(FormBuilder.new(:object-name('post'), :model(FormPost.new(published => True))).check-box('published').Str.contains('checked')).to.be-truthy;
  }

  it 'includes the value in a radio button id', {
    expect(FormBuilder.new(:object-name('post')).radio-button('title', 'a').Str).to.be('<input id="post_title_a" name="post[title]" type="radio" value="a" />');
  }

  it 'marks the selected option of a select from the model', {
    expect(FormBuilder.new(:object-name('post'), :model(FormPost.new(title => 'b'))).select('title', ['a', 'b']).Str).to.be('<select id="post_title" name="post[title]"><option value="a">a</option><option selected value="b">b</option></select>');
  }

  it 'humanizes a label by default', {
    expect(FormBuilder.new(:object-name('post')).label('first_name').Str).to.be('<label for="post_first_name">First name</label>');
  }

  it 'builds a submit input', {
    expect(FormBuilder.new(:object-name('post')).submit('Save').Str).to.be('<input type="submit" value="Save" />');
  }
}

describe 'MVC::Keayl::Helpers::FormBuilder errors', {
  it 'adds an error class to a field with model errors', {
    expect(FormBuilder.new(:object-name('post'), :model(FormPost.new(errors-title => ['is required']))).text-field('title').Str.contains('class="field-with-errors"')).to.be-truthy;
  }

  it 'renders the model messages', {
    expect(FormBuilder.new(:object-name('post'), :model(FormPost.new(errors-title => ['is required']))).errors-for('title').Str).to.be('<span class="error">is required</span>');
  }
}

describe 'MVC::Keayl::Helpers::FormBuilder nesting', {
  it 'scopes nested field names', {
    my $form = FormBuilder.new(:object-name('post'));
    my $out = $form.fields-for('author', block => -> $nested { $nested.text-field('name') });
    expect($out.Str).to.be('<input id="post_author_name" name="post[author][name]" type="text" />');
  }
}

describe 'MVC::Keayl form-with', {
  it 'opens a post form to the url', {
    my $out = form-with(model => FormPost.new, url => '/posts', content => -> $f { $f.text-field('title') });
    expect($out.Str.contains('<form action="/posts" method="post">')).to.be-truthy;
  }

  it 'adds a method override for non-post verbs', {
    my $out = form-with(model => FormPost.new, url => '/posts/1', method => 'patch', content => -> $f { $f.submit });
    expect($out.Str.contains('name="_method" type="hidden" value="patch"')).to.be-truthy;
  }

  it 'embeds a CSRF token when given one', {
    my $out = form-with(model => FormPost.new, url => '/posts', csrf-token => 'abc', content => -> $f { $f.submit });
    expect($out.Str.contains('name="authenticity_token" type="hidden" value="abc"')).to.be-truthy;
  }

  it 'derives field scope from an explicit scope', {
    my $out = form-with(scope => 'post', url => '/posts', content => -> $f { $f.text-field('title') });
    expect($out.Str.contains('name="post[title]"')).to.be-truthy;
  }
}

describe 'MVC::Keayl simple-form input', {
  it 'wraps the control in a typed wrapper', {
    expect(SimpleFormBuilder.new(:object-name('post')).input('title').Str.contains('<div class="input string optional">')).to.be-truthy;
  }

  it 'builds a humanized label', {
    expect(SimpleFormBuilder.new(:object-name('post')).input('title').Str.contains('<label for="post_title">Title</label>')).to.be-truthy;
  }

  it 'builds a string control by default', {
    expect(SimpleFormBuilder.new(:object-name('post')).input('title').Str.contains('<input id="post_title" name="post[title]" type="text" />')).to.be-truthy;
  }
}

describe 'MVC::Keayl simple-form type inference', {
  it 'infers a password input from the attribute name', {
    expect(SimpleFormBuilder.new(:object-name('user')).input('password').Str.contains('type="password"')).to.be-truthy;
  }

  it 'infers an email input from the attribute name', {
    expect(SimpleFormBuilder.new(:object-name('user')).input('email').Str.contains('type="email"')).to.be-truthy;
  }

  it 'infers a textarea for long-text attributes', {
    expect(SimpleFormBuilder.new(:object-name('post')).input('body').Str.contains('<textarea')).to.be-truthy;
  }

  it 'infers a checkbox from a boolean model value', {
    expect(SimpleFormBuilder.new(:object-name('post'), :model(FormPost.new(published => True))).input('published').Str.contains('type="checkbox"')).to.be-truthy;
  }
}

describe 'MVC::Keayl simple-form options', {
  it 'builds a select from an explicit as and collection', {
    my $out = SimpleFormBuilder.new(:object-name('post')).input('state', %( as => 'select', collection => ['draft', 'live'] )).Str;
    expect($out.contains('<select') && $out.contains('<option value="draft">')).to.be-truthy;
  }

  it 'marks a required input on the wrapper and label', {
    my $out = SimpleFormBuilder.new(:object-name('post'), :required-attributes(['title'])).input('title').Str;
    expect($out.contains('class="input string required"') && $out.contains('<abbr title="required">*</abbr>')).to.be-truthy;
  }

  it 'renders a hint', {
    expect(SimpleFormBuilder.new(:object-name('post')).input('title', %( hint => 'Keep it short' )).Str.contains('<span class="hint">Keep it short</span>')).to.be-truthy;
  }

  it 'annotates an input that has errors', {
    my $model = FormPost.new(errors-title => ['is required']);
    my $out = SimpleFormBuilder.new(:object-name('post'), :model($model)).input('title').Str;
    expect($out.contains('field-with-errors') && $out.contains('<span class="error">is required</span>')).to.be-truthy;
  }
}

describe 'MVC::Keayl simple-form-for', {
  it 'wraps inputs in a form', {
    my $out = simple-form-for(FormPost.new, url => '/posts', content => -> $f { $f.input('title') });
    expect($out.Str.contains('<form action="/posts" method="post">') && $out.Str.contains('class="input string optional"')).to.be-truthy;
  }
}
