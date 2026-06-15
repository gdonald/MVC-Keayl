use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Helpers::Options;
use MVC::Keayl::Helpers::Form;

class City {
  has $.id;
  has $.name;
}

class SelectPost {
  has $.city-id;
  has @.tag-ids;
  has $.born;
  method model-name { 'post' }
}

sub builder(*%args) { FormBuilder.new(|%args) }

sub cities { [City.new(id => 1, name => 'NY'), City.new(id => 2, name => 'LA')] }

describe 'MVC::Keayl options-for-select', {
  it 'marks the selected value', {
    expect(options-for-select(['a', 'b'], 'b').Str).to.be('<option value="a">a</option><option selected value="b">b</option>');
  }

  it 'accepts label-value pairs', {
    expect(options-for-select(['Active' => 'active']).Str).to.be('<option value="active">Active</option>');
  }

  it 'carries per-option attributes', {
    expect(options-for-select([['Draft', 'draft', %( disabled => True )]]).Str.contains('disabled')).to.be-truthy;
  }
}

describe 'MVC::Keayl options-from-collection-for-select', {
  it 'reads value and text methods', {
    expect(options-from-collection-for-select(cities, 'id', 'name', 2).Str).to.be('<option value="1">NY</option><option selected value="2">LA</option>');
  }
}

describe 'MVC::Keayl grouped-options-for-select', {
  it 'wraps choices in an optgroup', {
    expect(grouped-options-for-select(['North' => ['NY', 'NJ']]).Str).to.be('<optgroup label="North"><option value="NY">NY</option><option value="NJ">NJ</option></optgroup>');
  }
}

describe 'MVC::Keayl select-tag', {
  it 'wraps options in a select', {
    expect(select-tag('city', options-for-select(['NY', 'LA'])).Str).to.be('<select id="city" name="city"><option value="NY">NY</option><option value="LA">LA</option></select>');
  }

  it 'appends [] and the multiple attribute when multiple', {
    expect(select-tag('city', options-for-select(['NY']), %( multiple => True )).Str.contains('multiple name="city[]"')).to.be-truthy;
  }

  it 'prepends an empty option for include-blank', {
    expect(select-tag('city', options-for-select(['NY']), %( include-blank => True )).Str.contains('<option value=""></option>')).to.be-truthy;
  }

  it 'prepends a prompt option', {
    expect(select-tag('city', options-for-select(['NY']), %( prompt => 'Pick one' )).Str.contains('<option value="">Pick one</option>')).to.be-truthy;
  }
}

describe 'MVC::Keayl time-zone-select', {
  it 'marks the selected zone', {
    expect(time-zone-select('user[tz]', 'UTC').Str.contains('<option selected value="UTC">UTC</option>')).to.be-truthy;
  }

  it 'derives an id from the field name', {
    expect(time-zone-select('user[tz]').Str.contains('id="user_tz" name="user[tz]"')).to.be-truthy;
  }
}

describe 'MVC::Keayl date part selects', {
  it 'marks the selected year within the range', {
    expect(select-year(2020, start-year => 2018, end-year => 2022).Str.contains('<option selected value="2020">2020</option>')).to.be-truthy;
  }

  it 'names the year field under the date prefix', {
    expect(select-year(2020, start-year => 2018, end-year => 2022).Str.contains('id="date_year" name="date[year]"')).to.be-truthy;
  }

  it 'uses month names and marks the selection', {
    expect(select-month(3).Str.contains('<option selected value="3">March</option>')).to.be-truthy;
  }

  it 'marks the selected day', {
    expect(select-day(15).Str.contains('<option selected value="15">15</option>')).to.be-truthy;
  }

  it 'emits year, month, and day selects for a date', {
    my $out = select-date(Date.new(2020, 3, 15)).Str;
    expect($out.contains('name="date[year]"') && $out.contains('name="date[month]"') && $out.contains('name="date[day]"')).to.be-truthy;
  }
}

describe 'MVC::Keayl FormBuilder collection helpers', {
  it 'marks the model value in collection-select', {
    expect(builder(:object-name('post'), :model(SelectPost.new(city-id => 2))).collection-select('city-id', cities, 'id', 'name').Str.contains('<option selected value="2">LA</option>')).to.be-truthy;
  }

  it 'builds radio inputs from a collection', {
    expect(builder(:object-name('post'), :model(SelectPost.new(city-id => 2))).collection-radio-buttons('city-id', cities, 'id', 'name').Str.contains('type="radio"')).to.be-truthy;
  }

  it 'checks the matching radio value', {
    expect(builder(:object-name('post'), :model(SelectPost.new(city-id => 2))).collection-radio-buttons('city-id', cities, 'id', 'name').Str.contains('checked id="post_city-id_2"')).to.be-truthy;
  }

  it 'builds checkbox inputs from a collection', {
    expect(builder(:object-name('post'), :model(SelectPost.new(tag-ids => [2]))).collection-check-boxes('tag-ids', cities, 'id', 'name').Str.contains('type="checkbox" value="1"')).to.be-truthy;
  }

  it 'scopes checkbox names as an array', {
    expect(builder(:object-name('post'), :model(SelectPost.new(tag-ids => [2]))).collection-check-boxes('tag-ids', cities, 'id', 'name').Str.contains('name="post[tag-ids][]"')).to.be-truthy;
  }
}

describe 'MVC::Keayl FormBuilder date-select and time-select', {
  it 'emits multiparameter field names', {
    expect(builder(:object-name('post'), :model(SelectPost.new(born => Date.new(2020, 3, 15)))).date-select('born').Str.contains('name="post[born](1i)"')).to.be-truthy;
  }

  it 'marks the model year', {
    expect(builder(:object-name('post'), :model(SelectPost.new(born => Date.new(2020, 3, 15)))).date-select('born').Str.contains('<option selected value="2020">2020</option>')).to.be-truthy;
  }

  it 'emits hour and minute selects', {
    my $out = builder(:object-name('post')).time-select('at').Str;
    expect($out.contains('name="post[at](4i)"') && $out.contains('name="post[at](5i)"')).to.be-truthy;
  }
}
