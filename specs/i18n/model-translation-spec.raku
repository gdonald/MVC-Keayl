use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::I18n;
use I18nFixtures;

class User { }

describe 'MVC::Keayl::I18n model translation', {
  let(:backend, { build-backend });

  context 'human-attribute-name', {
    it 'uses a model-specific attribute name', {
      expect(backend.human-attribute-name(User, 'email_address')).to.be('Email address');
    }

    it 'falls back to a generic attribute name', {
      expect(backend.human-attribute-name(User, 'published_at')).to.be('Published at');
    }

    it 'humanizes an unknown attribute', {
      expect(backend.human-attribute-name(User, 'first_name')).to.be('First Name');
    }
  }

  context 'human-model-name', {
    it 'uses a translated model name', {
      expect(backend.human-model-name(User)).to.be('Member');
    }

    it 'humanizes an unknown model name', {
      expect(backend.human-model-name('account')).to.be('Account');
    }

    it 'accepts a model instance in place of the class', {
      expect(backend.human-model-name(User.new)).to.be('Member');
    }
  }

  context 'translate-error', {
    it 'uses a model-and-attribute-specific error message', {
      expect(backend.translate-error(User, 'email_address', 'blank')).to.be('is required');
    }

    it 'falls back to a model-level error message', {
      expect(backend.translate-error(User, 'name', 'blank')).to.be("can't be blank");
    }

    it 'interpolates count into an error message', {
      expect(backend.translate-error(User, 'name', 'too_short', count => 8)).to.be('is too short (minimum is 8 characters)');
    }

    it 'falls back to a generic error message', {
      expect(backend.translate-error(User, 'name', 'taken')).to.be('has already been taken');
    }
  }

  context 'form labels, placeholders, and submit text', {
    it 'uses a translated form label', {
      expect(backend.form-label(User, 'password')).to.be('Secret');
    }

    it 'falls back to the human attribute name for a label', {
      expect(backend.form-label(User, 'email_address')).to.be('Email address');
    }

    it 'resolves a form label from a model instance', {
      expect(backend.form-label(User.new, 'password')).to.be('Secret');
    }

    it 'uses a translated placeholder', {
      expect(backend.form-placeholder(User, 'email_address')).to.be('you@example.com');
    }

    it 'interpolates the model name into the submit text', {
      expect(backend.submit-default(User, 'create')).to.be('Create Member');
    }

    it 'uses a model-specific submit text', {
      expect(backend.submit-default(User, 'update')).to.be('Update your account');
    }

    it 'humanizes an unknown submit action', {
      expect(backend.submit-default(User)).to.be('Submit');
    }
  }
}
