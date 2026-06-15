use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Controller;
use ControllerFixtures;

describe 'MVC::Keayl::Controller add-renderer', {
  let(:response, { ReportsController.new.dispatch('export') });

  it 'dispatches a registered render option to its handler', {
    expect(response.body).to.be("1,2\n3,4");
  }

  it 'lets the handler set the content type', {
    expect(response.content-type).to.be('text/csv');
  }
}

describe 'MVC::Keayl::Controller add-flash-types', {
  it 'exposes a registered flash type as a reader helper', {
    expect(NoticeController.new.dispatch('create').body).to.be('saved');
  }
}
