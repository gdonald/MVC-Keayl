use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Flash;
use MVC::Keayl::Controller;
use MVC::Keayl::Request;

describe 'MVC::Keayl::Flash carrying', {
  it 'carries a written flash to the session', {
    my $flash = MVC::Keayl::Flash.new;
    $flash<notice> = 'Saved';
    expect($flash.to-session-value).to.be(%( notice => 'Saved' ));
  }

  it 'reads a flash from the session this request', {
    expect(MVC::Keayl::Flash.from-session(%( notice => 'Saved' ))<notice>).to.be('Saved');
  }

  it 'does not carry a shown flash again', {
    expect(MVC::Keayl::Flash.from-session(%( notice => 'Saved' )).to-session-value).to.be({});
  }
}

describe 'MVC::Keayl::Flash keep', {
  it 'carries a flash for another request', {
    my $flash = MVC::Keayl::Flash.from-session(%( notice => 'Saved' ));
    $flash.keep;
    expect($flash.to-session-value).to.be(%( notice => 'Saved' ));
  }

  it 'retains only the named entry', {
    my $flash = MVC::Keayl::Flash.from-session(%( notice => 'Saved', alert => 'Oops' ));
    $flash.keep('notice');
    expect($flash.to-session-value).to.be(%( notice => 'Saved' ));
  }
}

describe 'MVC::Keayl::Flash discard', {
  it 'drops an entry from the session', {
    my $flash = MVC::Keayl::Flash.new;
    $flash<notice> = 'Saved';
    $flash.discard('notice');
    expect($flash.to-session-value).to.be({});
  }
}

describe 'MVC::Keayl::Flash now', {
  it 'is readable this request', {
    my $flash = MVC::Keayl::Flash.new;
    $flash.now<alert> = 'Right now';
    expect($flash<alert>).to.be('Right now');
  }

  it 'is not carried to the next request', {
    my $flash = MVC::Keayl::Flash.new;
    $flash.now<alert> = 'Right now';
    expect($flash.to-session-value).to.be({});
  }
}

describe 'MVC::Keayl::Controller flash cycle', {
  it 'shows a flash on the next request then drops it', {
    my class WriteController is MVC::Keayl::Controller {
      method create {
        self.flash<notice> = 'Created';
        self.render(:plain('ok'));
      }
    }

    my class ReadController is MVC::Keayl::Controller {
      method show {
        self.render(:plain(self.flash<notice> // 'none'));
      }
    }

    my $first   = WriteController.new(secret => 'k').dispatch('create');
    my $cookie  = $first.header('Set-Cookie').subst(/';'.*/, '');

    my $second  = ReadController.new(secret => 'k', request => MVC::Keayl::Request.new(headers => %( cookie => $cookie ))).dispatch('show');
    expect($second.body).to.be('Created');
  }
}

describe 'MVC::Keayl::Flash registered types', {
  before-each({ register-flash-type('success') });

  it 'reads a registered type through a method', {
    my $flash = MVC::Keayl::Flash.new;
    $flash<success> = 'Saved';
    expect($flash.success).to.be('Saved');
  }

  it 'writes a registered type through a method', {
    my $flash = MVC::Keayl::Flash.new;
    $flash.success('Updated');
    expect($flash<success>).to.be('Updated');
  }

  it 'lists the registered types', {
    expect(flash-types.first(* eq 'success').defined).to.be-truthy;
  }

  it 'raises for an unregistered type', {
    expect({ MVC::Keayl::Flash.new.bogus }).to.throw;
  }
}
