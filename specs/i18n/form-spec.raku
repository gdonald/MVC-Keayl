use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Helpers::Form;
use I18nFixtures;

class FakeUser {
  has Bool $.persisted = False;
  method is-persisted { $!persisted }
}

sub builder(*%options) {
  FormBuilder.new(object-name => 'user', i18n => build-backend, |%options)
}

describe 'MVC::Keayl::Helpers::Form I18n labels', {
  it 'uses a translated string for a form label', {
    expect(~builder.label('password')).to.be('<label for="user_password">Secret</label>');
  }

  it 'falls back to the human attribute name for a label', {
    expect(~builder.label('email_address')).to.be('<label for="user_email_address">Email address</label>');
  }
}

describe 'MVC::Keayl::Helpers::Form I18n placeholders', {
  it 'resolves a translated placeholder when placeholder is True', {
    expect(~builder.text-field('email_address', { placeholder => True })).to.match(/'placeholder="you@example.com"'/);
  }
}

describe 'MVC::Keayl::Helpers::Form I18n submit text', {
  it 'interpolates the model name for a new record', {
    expect(~builder(model => FakeUser.new).submit).to.match(/'value="Create Member"'/);
  }

  it 'uses the update key for a persisted record', {
    expect(~builder(model => FakeUser.new(persisted => True)).submit).to.match(/'value="Update your account"'/);
  }
}

describe 'MVC::Keayl::Helpers::Form without a backend', {
  let(:plain, { FormBuilder.new(object-name => 'user') });

  it 'humanizes the attribute for a label', {
    expect(~plain.label('email_address')).to.be('<label for="user_email_address">Email address</label>');
  }

  it 'defaults submit text to Save', {
    expect(~plain.submit).to.match(/'value="Save"'/);
  }
}
