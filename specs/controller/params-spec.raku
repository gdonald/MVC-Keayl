use BDD::Behave;
use MVC::Keayl::Params;
use MVC::Keayl::Parameters;
use MVC::Keayl::Request;

describe 'MVC::Keayl params nesting', {
  it 'nests bracketed keys into a hash', {
    expect(parse-urlencoded('user[name]=Ada&user[email]=a@b.com')<user><name>).to.be('Ada');
  }

  it 'shares the parent hash across sibling keys', {
    expect(parse-urlencoded('user[name]=Ada&user[email]=a@b.com')<user><email>).to.be('a@b.com');
  }

  it 'appends empty-bracket keys to an array', {
    expect(parse-urlencoded('ids[]=1&ids[]=2')<ids>.join(',')).to.be('1,2');
  }

  it 'builds nested arrays under a hash', {
    expect(parse-urlencoded('user[roles][]=admin&user[roles][]=editor')<user><roles>.join(',')).to.be('admin,editor');
  }

  it 'groups an array of hashes', {
    expect(parse-urlencoded('users[][name]=A&users[][age]=1')<users>[0]<name>).to.be('A');
  }

  it 'percent-decodes flat values', {
    expect(parse-urlencoded('q=a%20b')<q>).to.be('a b');
  }
}

describe 'MVC::Keayl params json', {
  it 'parses nested objects', {
    expect(parse-json('{"user":{"name":"Ada"}}')<user><name>).to.be('Ada');
  }

  it 'parses arrays', {
    expect(parse-json('{"ids":[1,2]}')<ids>.join(',')).to.be('1,2');
  }

  it 'parses an empty body to an empty hash', {
    expect(parse-json('').elems).to.be(0);
  }
}

describe 'MVC::Keayl params multipart', {
  my $body = "--X\r\nContent-Disposition: form-data; name=\"title\"\r\n\r\nHello\r\n"
           ~ "--X\r\nContent-Disposition: form-data; name=\"file\"; filename=\"a.txt\"\r\nContent-Type: text/plain\r\n\r\nfile body\r\n"
           ~ "--X--\r\n";

  it 'parses a text field', {
    expect(parse-multipart($body, 'X')<title>).to.be('Hello');
  }

  it 'parses a file filename', {
    expect(parse-multipart($body, 'X')<file><filename>).to.be('a.txt');
  }

  it 'parses a file content as bytes', {
    expect(parse-multipart($body, 'X')<file><content>.decode('latin-1')).to.eq('file body');
  }

  it 'parses a file content type', {
    expect(parse-multipart($body, 'X')<file><type>).to.be('text/plain');
  }

  context 'a binary upload', {
    # Bytes that are not valid UTF-8, as a real image upload carries. They must
    # come back byte-for-byte, never decoded as UTF-8 (which corrupts them).
    let(:file-bytes, { Buf.new(0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x89, 0x50, 0x4E, 0x47) });
    let(:binary-body, {
      my $head = "--B\r\nContent-Disposition: form-data; name=\"img\"; filename=\"x.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n".encode('latin-1');
      my $tail = "\r\n--B--\r\n".encode('latin-1');
      Buf.new(|$head, |file-bytes, |$tail)
    });

    it 'returns the file part as a byte buffer', {
      expect(parse-multipart(binary-body, 'B')<img><content> ~~ Blob).to.be-truthy;
    }

    it 'preserves the binary content byte-for-byte', {
      expect(parse-multipart(binary-body, 'B')<img><content>.list).to.eq(file-bytes.list);
    }
  }

  context 'a text field whose bytes are not valid utf-8', {
    # A lone 0xFF byte is not a valid UTF-8 sequence. The value falls back to its
    # latin-1 reading rather than throwing.
    let(:latin1-body, {
      my $head = "--B\r\nContent-Disposition: form-data; name=\"t\"\r\n\r\n".encode('latin-1');
      my $tail = "\r\n--B--\r\n".encode('latin-1');
      Buf.new(|$head, 0xFF, |$tail)
    });

    it 'falls back to the latin-1 reading of the value', {
      expect(parse-multipart(latin1-body, 'B')<t>).to.eq(Buf.new(0xFF).decode('latin-1'));
    }
  }
}

describe 'MVC::Keayl params merge and indifferent access', {
  let(:params, {
    my $request = MVC::Keayl::Request.new(
      :method<POST>,
      :target('/users?ref=home'),
      :headers({ 'Content-Type' => 'application/x-www-form-urlencoded' }),
      :body('user[name]=Ada'),
    );
    build-params({ id => '5' }, $request)
  });

  it 'merges path params', {
    expect(params<id>).to.be('5');
  }

  it 'merges query params', {
    expect(params<ref>).to.be('home');
  }

  it 'merges body params', {
    expect(params<user><name>).to.be('Ada');
  }
}

describe 'MVC::Keayl params indifferent access', {
  let(:params, { MVC::Keayl::Parameters.new({ '5' => 'five', name => 'Ada' }) });

  it 'accesses a string key directly', {
    expect(params<name>).to.be('Ada');
  }

  it 'coerces a numeric key to a string', {
    expect(params(){5}).to.be('five');
  }
}
