use lib 'specs/lib';
use BDD::Behave;
use MVC::Keayl::Assets;
use MVC::Keayl::Assets::Serving;
use MVC::Keayl::Parameters;
use MVC::Keayl::Helpers::Asset;
use MVC::Keayl::View;
use MVC::Keayl::CLI;
use CLIFixtures;

class SilentSink {
  method say($) { }
}

class ErrorSink {
  has @.lines;
  method say($message) { @!lines.push: $message }
}

sub params(%data) {
  MVC::Keayl::Parameters.new(%data)
}

describe 'fingerprinting', {
  it 'digests the same content the same', {
    expect(digest-for('body { color: red }')).to.be(digest-for('body { color: red }'));
  }

  it 'digests different content differently', {
    expect(digest-for('a') ne digest-for('b')).to.be-truthy;
  }

  it 'embeds the digest before the extension', {
    expect(so digested-name('application.css', 'body {}') ~~ /^ 'application-' <[0..9a..f]>+ '.css' $/).to.be-truthy;
  }
}

describe 'manifest build', {
  let(:source, {
    my $dir = temp-dir('spec-assets-source');
    $dir.add('css').mkdir;
    $dir.add('css/app.css').spurt('body { color: red }');
    $dir
  });

  it 'maps a logical path to its digested name', {
    expect(MVC::Keayl::Assets::Manifest.build(source(), output => temp-dir('spec-assets-out')).lookup('css/app.css').starts-with('css/app-')).to.be-truthy;
  }

  it 'writes the digested file to the output directory', {
    my $output = temp-dir('spec-assets-out2');
    my $manifest = MVC::Keayl::Assets::Manifest.build(source(), :$output);
    expect($output.add($manifest.lookup('css/app.css')).e).to.be-truthy;
  }
}

describe 'manifest json', {
  it 'round-trips through json', {
    my $manifest = MVC::Keayl::Assets::Manifest.new(assets => %( 'app.css' => 'app-abc.css' ));
    expect(MVC::Keayl::Assets::Manifest.from-json($manifest.to-json).lookup('app.css')).to.be('app-abc.css');
  }
}

describe 'the manifest resolver', {
  let(:resolver, { manifest-resolver(MVC::Keayl::Assets::Manifest.new(assets => %( 'application.css' => 'application-abc123.css' ))) });

  it 'maps a logical name to its digested path', {
    expect(resolver()('application', 'css')).to.be('/assets/application-abc123.css');
  }

  it 'passes an unknown asset through', {
    expect(resolver()('unknown.js', Str)).to.be('/assets/unknown.js');
  }

  it 'leaves an external url alone', {
    expect(resolver()('https://cdn/app.css', Str)).to.be('https://cdn/app.css');
  }
}

describe 'helpers resolving through the manifest', {
  let(:resolver, { manifest-resolver(MVC::Keayl::Assets::Manifest.new(assets => %( 'application.css' => 'application-abc.css', 'logo.png' => 'logo-def.png' ))) });

  it 'resolves a stylesheet link', {
    expect(stylesheet-link-tag('application', resolver => resolver()).Str.contains('href="/assets/application-abc.css"')).to.be-truthy;
  }

  it 'resolves an image source', {
    expect(image-tag('logo.png', resolver => resolver()).Str.contains('src="/assets/logo-def.png"')).to.be-truthy;
  }
}

describe 'the configured digested-resolver', {
  before-each({
    reset-asset-manifest;
    set-asset-manifest(MVC::Keayl::Assets::Manifest.new(assets => %( 'application.css' => 'application-xyz.css' )));
  });

  it 'consults the configured manifest', {
    expect(digested-resolver('application', 'css')).to.be('/assets/application-xyz.css');
    reset-asset-manifest;
  }
}

describe 'the default view resolver', {
  before-each({ reset-asset-manifest });

  it 'fingerprints an asset url when a manifest is loaded', {
    set-asset-manifest(MVC::Keayl::Assets::Manifest.new(assets => %( 'app.css' => 'app-abc.css' )));
    expect(MVC::Keayl::View.new.asset-resolver.('app', 'css')).to.be('/assets/app-abc.css');

    reset-asset-manifest;
  }

  it 'emits a plain asset url when no manifest is loaded', {
    expect(MVC::Keayl::View.new.asset-resolver.('app', 'css')).to.be('/assets/app.css');
  }
}

describe 'import maps', {
  it 'defaults a module url under /assets', {
    my $importmap = MVC::Keayl::Assets::ImportMap.new;
    $importmap.pin('application');
    expect($importmap.imports<application>).to.be('/assets/application.js');
  }

  it 'honours an explicit url', {
    my $importmap = MVC::Keayl::Assets::ImportMap.new;
    $importmap.pin('lodash', to => 'https://cdn/lodash.js');
    expect($importmap.imports<lodash>).to.be('https://cdn/lodash.js');
  }

  it 'pins every module in a directory', {
    my $dir = temp-dir('spec-importmap');
    $dir.add('controllers').mkdir;
    $dir.add('controllers/hello.js').spurt('export {}');
    $dir.add('controllers/world.js').spurt('export {}');

    my $importmap = MVC::Keayl::Assets::ImportMap.new;
    $importmap.pin-all-from($dir.add('controllers'), under => 'controllers');

    expect($importmap.imports.keys.sort.join(',')).to.be('controllers/hello,controllers/world');
  }
}

describe 'importmap tags', {
  let(:tags, {
    my $importmap = MVC::Keayl::Assets::ImportMap.new;
    $importmap.pin('application', preload => True);
    javascript-importmap-tags($importmap).Str
  });

  it 'emit the importmap script', {
    expect(tags().contains('<script type="importmap">')).to.be-truthy;
  }

  it 'list the pinned module', {
    expect(tags().contains('"application"')).to.be-truthy;
  }

  it 'emit a modulepreload link for a preloaded pin', {
    expect(tags().contains('<link href="/assets/application.js" rel="modulepreload" />')).to.be-truthy;
  }

  it 'resolve module urls through a manifest', {
    my $manifest = MVC::Keayl::Assets::Manifest.new(assets => %( 'application.js' => 'application-abc.js' ));
    my $importmap = MVC::Keayl::Assets::ImportMap.new;
    $importmap.pin('application', preload => True);
    expect(javascript-importmap-tags($importmap, :$manifest).Str.contains('/assets/application-abc.js')).to.be-truthy;
  }
}

describe 'static serving', {
  it 'serves a digested file with an immutable cache header', {
    my $root = temp-dir('spec-serve');
    $root.add('application-abc.css').spurt('body { color: red }');
    reset-asset-root;
    set-asset-root($root);

    my $response = MVC::Keayl::Assets::Serving::AssetsController.new(params => params({ path => 'application-abc.css' })).dispatch('show');
    expect($response.body eq 'body { color: red }' && $response.header('Cache-Control') eq 'public, max-age=31536000, immutable').to.be-truthy;
    reset-asset-root;
  }

  it 'rejects a path traversal', {
    my $root = temp-dir('spec-serve-traversal');
    reset-asset-root;
    set-asset-root($root);
    expect(MVC::Keayl::Assets::Serving::AssetsController.new(params => params({ path => '../secret' })).dispatch('show').status).to.be(404);
    reset-asset-root;
  }

  it 'returns 404 for an unknown asset', {
    my $root = temp-dir('spec-serve-missing');
    reset-asset-root;
    set-asset-root($root);
    expect(MVC::Keayl::Assets::Serving::AssetsController.new(params => params({ path => 'nope.css' })).dispatch('show').status).to.be(404);
    reset-asset-root;
  }
}

describe 'assets-precompile', {
  it 'builds the manifest and digested files', {
    my $root = temp-dir('spec-precompile');
    $root.add('app/assets/css').mkdir;
    $root.add('app/assets/css/app.css').spurt('body {}');

    my $status = assets-precompile(:$root, out => SilentSink.new);
    my $manifest-file = $root.add('public/assets/manifest.json');
    my $manifest = MVC::Keayl::Assets::Manifest.from-json($manifest-file.slurp);

    expect($status == 0 && $manifest-file.e && $root.add('public/assets').add($manifest.lookup('css/app.css')).e).to.be-truthy;
  }

  it 'fails without an asset source', {
    my $sink = ErrorSink.new;
    my $status = assets-precompile(root => temp-dir('spec-precompile-empty'), err => $sink);
    expect($status == 1 && $sink.lines.join.contains('no asset source')).to.be-truthy;
  }
}
