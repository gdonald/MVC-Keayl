use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Request;
use MVC::Keayl::Controller;
use ControllerFixtures;

describe 'MVC::Keayl::Controller send-data', {
  let(:response, { DownloadController.new.dispatch('data-csv') });

  it 'writes the payload', {
    expect(response.body).to.be("a,b\n1,2");
  }

  it 'sets the content type', {
    expect(response.header('content-type')).to.be('text/csv');
  }

  it 'sets an attachment disposition with the filename', {
    expect(response.header('Content-Disposition')).to.be('attachment; filename="report.csv"');
  }
}

describe 'MVC::Keayl::Controller send-data defaults', {
  it 'honours an inline disposition', {
    expect(DownloadController.new.dispatch('data-inline').header('Content-Disposition')).to.be('inline');
  }

  it 'defaults to octet-stream', {
    expect(DownloadController.new.dispatch('data-inline').header('content-type')).to.be('application/octet-stream');
  }

  it 'sends a binary payload byte-for-byte', {
    my ($status, $headers, $blob) = DownloadController.new.dispatch('data-binary').finish;
    expect($blob.list.join(',')).to.be('0,1,2,255');
  }
}

describe 'MVC::Keayl::Controller send-file', {
  let(:response, { DownloadController.new.dispatch('file') });

  it 'serves the file contents', {
    expect(response.body).to.be('0123456789');
  }

  it 'guesses the content type from the extension', {
    expect(response.header('content-type')).to.be('text/plain');
  }

  it 'uses the basename as the filename', {
    expect(response.header('Content-Disposition')).to.be('attachment; filename="sample.txt"');
  }

  it 'advertises range support', {
    expect(response.header('Accept-Ranges')).to.be('bytes');
  }
}

describe 'MVC::Keayl::Controller send-file overrides', {
  let(:response, { DownloadController.new.dispatch('file-typed') });

  it 'honours an explicit content type', {
    expect(response.header('content-type')).to.be('text/plain');
  }

  it 'honours an explicit filename and disposition', {
    expect(response.header('Content-Disposition')).to.be('inline; filename="down.txt"');
  }
}

describe 'MVC::Keayl::Controller send-file ranges', {
  let(:response, {
    my $request = MVC::Keayl::Request.new(:headers({ Range => 'bytes=2-5' }));
    DownloadController.new(:$request).dispatch('file')
  });

  it 'returns partial content', {
    expect(response.status).to.be(206);
  }

  it 'serves the requested byte range', {
    expect(response.body).to.be('2345');
  }

  it 'sets Content-Range', {
    expect(response.header('Content-Range')).to.be('bytes 2-5/10');
  }

  it 'serves an open-ended range to the end', {
    my $request = MVC::Keayl::Request.new(:headers({ Range => 'bytes=7-' }));
    expect(DownloadController.new(:$request).dispatch('file').body).to.be('789');
  }

  it 'serves a suffix range from the end', {
    my $request = MVC::Keayl::Request.new(:headers({ Range => 'bytes=-3' }));
    expect(DownloadController.new(:$request).dispatch('file').body).to.be('789');
  }
}
