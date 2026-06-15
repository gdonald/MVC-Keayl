use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Helpers::Form;
use MVC::Keayl::Helpers::Tag;
use MVC::Keayl::Helpers::Asset;

class FieldPost {
  has $.email;
  has $.born;
  has $.avatar;
  method model-name { 'post' }
}

sub builder(*%args) { FormBuilder.new(|%args) }

describe 'MVC::Keayl typed field helpers', {
  it 'builds a type=email input', {
    expect(builder(:object-name('post')).email-field('email').Str).to.be('<input id="post_email" name="post[email]" type="email" />');
  }

  it 'prefills an email field from the model', {
    expect(builder(:object-name('post'), :model(FieldPost.new(email => 'a@b.c'))).email-field('email').Str).to.be('<input id="post_email" name="post[email]" type="email" value="a@b.c" />');
  }

  it 'builds a type=url input', {
    expect(builder(:object-name('post')).url-field('site').Str).to.be('<input id="post_site" name="post[site]" type="url" />');
  }

  it 'builds a type=tel input', {
    expect(builder(:object-name('post')).telephone-field('phone').Str).to.be('<input id="post_phone" name="post[phone]" type="tel" />');
  }

  it 'builds a type=number input', {
    expect(builder(:object-name('post')).number-field('rank').Str).to.be('<input id="post_rank" name="post[rank]" type="number" />');
  }

  it 'builds a type=range input', {
    expect(builder(:object-name('post')).range-field('level').Str).to.be('<input id="post_level" name="post[level]" type="range" />');
  }

  it 'builds a type=search input', {
    expect(builder(:object-name('post')).search-field('q').Str).to.be('<input id="post_q" name="post[q]" type="search" />');
  }

  it 'builds a type=color input', {
    expect(builder(:object-name('post')).color-field('shade').Str).to.be('<input id="post_shade" name="post[shade]" type="color" />');
  }
}

describe 'MVC::Keayl date and time field helpers', {
  it 'builds a type=date input', {
    expect(builder(:object-name('post')).date-field('born').Str).to.be('<input id="post_born" name="post[born]" type="date" />');
  }

  it 'builds a type=time input', {
    expect(builder(:object-name('post')).time-field('at').Str).to.be('<input id="post_at" name="post[at]" type="time" />');
  }

  it 'builds a type=datetime-local input', {
    expect(builder(:object-name('post')).datetime-field('at').Str).to.be('<input id="post_at" name="post[at]" type="datetime-local" />');
  }

  it 'builds a type=month input', {
    expect(builder(:object-name('post')).month-field('period').Str).to.be('<input id="post_period" name="post[period]" type="month" />');
  }

  it 'builds a type=week input', {
    expect(builder(:object-name('post')).week-field('period').Str).to.be('<input id="post_period" name="post[period]" type="week" />');
  }
}

describe 'MVC::Keayl file-field', {
  it 'builds a type=file input', {
    expect(builder(:object-name('post')).file-field('avatar').Str).to.be('<input id="post_avatar" name="post[avatar]" type="file" />');
  }

  it 'appends [] and the multiple attribute when multiple', {
    expect(builder(:object-name('post')).file-field('avatar', %( multiple => True )).Str).to.be('<input id="post_avatar" multiple name="post[avatar][]" type="file" />');
  }

  it 'sets the upload url data attribute for direct upload', {
    expect(builder(:object-name('post')).file-field('avatar', %( direct-upload => '/uploads' )).Str.contains('data-direct-upload-url="/uploads"')).to.be-truthy;
  }
}

describe 'MVC::Keayl button-tag and image-submit-tag', {
  it 'builds a submit button', {
    expect(button-tag('Save').Str).to.be('<button type="submit">Save</button>');
  }

  it 'defaults its content', {
    expect(button-tag().Str).to.be('<button type="submit">Button</button>');
  }

  it 'honours an explicit type', {
    expect(button-tag('Reset', %( type => 'reset' )).Str).to.be('<button type="reset">Reset</button>');
  }

  it 'builds an image submit input', {
    expect(image-submit-tag('search.png').Str).to.be('<input alt="Search" src="/assets/search.png" type="image" />');
  }
}
