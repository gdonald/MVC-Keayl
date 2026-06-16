use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::ActionText;
use MVC::Keayl::ActionText::Repository;
use MVC::Keayl::ActionText::RichTextable;
use MVC::Keayl::Storage;
use MVC::Keayl::Storage::Service;
use MVC::Keayl::Storage::Attached;
use MVC::Keayl::Helpers::Form;

my $temp-counter = 0;

sub temp-root {
  $*TMPDIR.add('keayl-action-text-spec-' ~ $*PID ~ '-' ~ $temp-counter++)
}

class ActionTextArticle does RichTextable {
  has $.id;
}
ActionTextArticle.has-rich-text('content');

describe 'MVC::Keayl::ActionText::Content sanitization', {
  let(:content, { MVC::Keayl::ActionText::Content.from-html('<h1>Title</h1><script>evil()</script><b onclick="x()">bold</b>') });

  it 'strips disallowed tags, scripts, and event attributes', {
    expect(content.to-trix-html.Str).to.be('<h1>Title</h1><b>bold</b>');
  }

  it 'drops the markup for plain text', {
    expect(content.to-plain-text).to.be('Title bold');
  }

  context 'for blank content', {
    it 'is empty', {
      expect(MVC::Keayl::ActionText::Content.new(html => '').is-empty).to.be-truthy;
    }
  }
}

describe 'has-rich-text', {
  before-each({ reset-rich-text });

  let(:article, { ActionTextArticle.new(id => 1) });

  it 'is not present without rich text', {
    expect(article.content.is-present).to.be-falsy;
  }

  context 'after assigning rich text', {
    before-each({ ActionTextArticle.new(id => 1).content.assign('<h1>Hello</h1><script>bad()</script>') });

    it 'is present', {
      expect(article.content.is-present).to.be-truthy;
    }

    it 'renders its sanitized html', {
      expect(article.content.to-html.Str).to.be('<h1>Hello</h1>');
    }

    it 'exposes plain text', {
      expect(article.content.to-plain-text).to.be('Hello');
    }
  }

  context 'when reassigned', {
    it 'replaces the body', {
      article.content.assign('<p>first</p>');
      article.content.assign('<p>second</p>');
      expect(article.content.to-html.Str).to.be('<p>second</p>');
    }
  }
}

describe 'an undeclared rich text name', {
  it 'is a method-not-found error', {
    my $article = ActionTextArticle.new(id => 3);
    expect({ $article.headline }).to.throw;
  }
}

describe 'embedded attachments', {
  before-each({
    reset-storage;
    set-storage-service(DiskService.new(root => temp-root));
  });

  context 'for an image blob', {
    let(:content, {
      my $blob = MVC::Keayl::Storage::Blob.build('image-bytes', filename => 'photo.png', content-type => 'image/png');
      storage-repository.create-blob($blob);
      MVC::Keayl::ActionText::Content.from-html('<div>look</div>' ~ embed-tag($blob))
    });

    it 'tracks the embedded attachment', {
      expect(content.attachment-sgids.elems).to.be(1);
    }

    it 'renders a preview figure', {
      expect(content.to-html.Str.contains('<figure class="attachment attachment--preview attachment--png">')).to.be-truthy;
    }

    it 'links to the proxy serving path', {
      expect(content.to-html.Str.contains('/keayl/blobs/proxy/')).to.be-truthy;
    }
  }

  context 'for a non-image blob', {
    let(:content, {
      my $blob = MVC::Keayl::Storage::Blob.build('pdf-bytes', filename => 'report.pdf', content-type => 'application/pdf');
      storage-repository.create-blob($blob);
      MVC::Keayl::ActionText::Content.from-html(embed-tag($blob))
    });

    it 'renders a file figure', {
      expect(content.to-html.Str.contains('<figure class="attachment attachment--file">')).to.be-truthy;
    }

    it 'shows the filename', {
      expect(content.to-html.Str.contains('report.pdf')).to.be-truthy;
    }
  }

  context 'for an unresolvable attachment', {
    it 'is dropped on render', {
      my $content = MVC::Keayl::ActionText::Content.from-html('<action-text-attachment sgid="bogus--00"></action-text-attachment>');
      expect($content.to-html.Str).to.be('');
    }
  }
}

describe 'the rich-text view helper', {
  it 'sanitizes and renders a string', {
    expect(rich-text('<p>hi</p><script>x()</script>').Str).to.be('<p>hi</p>');
  }
}

describe 'the rich-text-area form helper', {
  let(:markup, { FormBuilder.new(object-name => 'post').rich-text-area('body').Str });

  it 'emits a trix editor', {
    expect(markup.contains('<trix-editor')).to.be-truthy;
  }

  it 'references the hidden input', {
    expect(markup.contains('input="post_body_trix_input"')).to.be-truthy;
  }

  it 'carries the trix-content class', {
    expect(markup.contains('class="trix-content"')).to.be-truthy;
  }

  it 'emits a hidden input for the value', {
    expect(markup.contains('type="hidden"')).to.be-truthy;
  }

  it 'submits the hidden input under the attribute name', {
    expect(markup.contains('name="post[body]"')).to.be-truthy;
  }

  context 'as a standalone tag', {
    it 'escapes the current value into the hidden input', {
      expect(rich-text-area-tag('comment', '<p>existing</p>').Str.contains('value="&lt;p&gt;existing&lt;/p&gt;"')).to.be-truthy;
    }
  }
}
