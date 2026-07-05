use lib 'specs/lib';
use BDD::Behave;
use DBIish;
use MVC::Keayl::Endpoint;
use MVC::Keayl::Request;
use MVC::Keayl::Response;
use MVC::Keayl::Middleware::Database;
use ORM::ActiveRecord::DB;

%*ENV<DISABLE-SQL-LOG> = True;

# A stub app that records whether a request-scoped registry was bound and writes a
# row through the registry's connection, the same path a model query takes.
class ProbeApp does MVC::Keayl::Endpoint {
  has Bool $.registry-bound is rw = False;
  method call(MVC::Keayl::Request:D $request --> MVC::Keayl::Response:D) {
    $!registry-bound = $*AR-CONNECTION-REGISTRY.defined;
    my $db = $*AR-CONNECTION-REGISTRY ?? $*AR-CONNECTION-REGISTRY.db-for(DB.shared.name) !! DB.shared;
    $db.exec('INSERT INTO widgets (name) VALUES (?)', $request.path);
    my $response = MVC::Keayl::Response.new;
    $response.status = 200;
    $response.body('ok');
    $response
  }
}

# Checks a connection out of the registry, then throws before returning, standing
# in for a model query that raises partway through a request.
class ThrowingProbe does MVC::Keayl::Endpoint {
  method call(MVC::Keayl::Request:D $request --> MVC::Keayl::Response:D) {
    $*AR-CONNECTION-REGISTRY.db-for(DB.shared.name);
    die 'boom';
  }
}

sub request(Str:D $path) { MVC::Keayl::Request.new(method => 'GET', :$path) }

describe 'MVC::Keayl::Middleware::Database', {
  let(:dbfile, { $*TMPDIR.add("keayl-db-mw-spec-{$*PID}-{(now * 1e6).Int}.sqlite3").Str });
  let(:probe, { ProbeApp.new });
  let(:middleware, { MVC::Keayl::Middleware::Database.new(app => probe) });

  before-each {
    %*ENV<DATABASE_URL> = 'sqlite:' ~ dbfile;
    DB.set-shared(Nil);
    DB.shared.exec('CREATE TABLE widgets (id INTEGER PRIMARY KEY, name TEXT)');
  }

  after-each {
    DB.shared.pool.disconnect-all;
    DB.set-shared(Nil);
    %*ENV<DATABASE_URL>:delete;
    dbfile.IO.unlink if dbfile.IO.e;
  }

  it 'binds a connection registry for the duration of the request', {
    middleware.call(request('/one'));
    expect(probe.registry-bound).to.be-truthy;
  }

  it 'leaves no registry bound after the request', {
    middleware.call(request('/one'));
    expect($*AR-CONNECTION-REGISTRY.defined).to.be-falsy;
  }

  it 'returns the connection to the pool after the request', {
    middleware.call(request('/one'));
    expect(DB.shared.pool.stats<in-use>).to.eq(0);
  }

  it 'runs the request query on the pooled connection', {
    middleware.call(request('/one'));
    expect(DB.shared.exec('SELECT count(*) FROM widgets')[0][0]).to.eq(1);
  }

  it 'reconnects and succeeds on a request after every pooled connection is dropped', {
    middleware.call(request('/one'));
    DB.shared.pool.disconnect-all;
    middleware.call(request('/two'));
    expect(DB.shared.exec('SELECT count(*) FROM widgets')[0][0]).to.eq(2);
  }

  context 'when the request throws', {
    let(:middleware, { MVC::Keayl::Middleware::Database.new(app => ThrowingProbe.new) });

    it 'propagates the exception', {
      expect({ middleware.call(request('/boom')) }).to.throw;
    }

    it 'still returns the checked-out connection to the pool', {
      try middleware.call(request('/boom'));
      expect(DB.shared.pool.stats<in-use>).to.eq(0);
    }
  }
}
