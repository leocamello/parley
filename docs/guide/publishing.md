# Publishing and consuming a package

`parley publish <dir>` builds an archive from your own `Package.st` and writes
its static metadata into an index directory you own. That directory can be a
local folder, a git repository, or content served by a web server. Parley
does not operate a hosted registry.

This walkthrough creates a library, an index and a consumer side by side.
Use a fresh directory so the files below do not overwrite existing work.

## Create the library and destination

```sh
mkdir -p parley-publish-demo/greeter parley-publish-demo/my-index parley-publish-demo/my-app
cd parley-publish-demo/greeter
cat > Greeter.st <<'ST'
Object subclass: Greeter [
    Greeter class >> greet: aName [ ^'Hello, ', aName, '!' ]
]
ST
cat > Package.st <<'ST'
Parley define: [:pkg |
    pkg
        name: 'greeter';
        version: '1.0.0';
        fileIns: #('Greeter.st') ]
ST
```

The destination must already exist and be writable. `publish` does not create
it: a mistyped destination is a diagnosis, not a new index in the wrong place.

`fileIns:` names the files to load, in load order. Their order is semantic and
is preserved in the archive. Publishing uses GNU Smalltalk's bundled
`gst-package` tool to build the `.star` archive.

## Choose one layout

Choose a layout for this index and run its command. The consumer example below
uses the flat layout:

```sh
parley publish ../my-index --layout flat
```

For a sparse index, use this command instead, with a fresh index directory:

```sh
parley publish ../my-index --layout sparse
```

Both commands report `published greeter 1.0.0` when they succeed. The flag is
optional only for flat: `parley publish ../my-index` has the same meaning as
the explicit flat command.

| Layout | Files for this release | Consumer source |
| --- | --- | --- |
| `flat` | `my-index/greeter-1.0.0.st` and `my-index/greeter-1.0.0.star` | `--source` or `--git` |
| `sparse` | `my-index/greeter/versions.st`, `greeter-1.0.0.st` and `greeter-1.0.0.star` | `--index` |

The layout is stated, never inferred from directory contents. An unknown
layout is a usage error at exit `2`. Keep an index's layout consistent with
the source consumers use.

## Install from the flat index

From the library directory used above, create the consumer:

```sh
cd ../my-app
cat > Package.st <<'ST'
Parley define: [:pkg |
    pkg
        name: 'my-app';
        version: '1.0.0';
        fileIns: #('run.st');
        dependency: 'greeter' constraint: '^1.0.0' ]
ST
cat > run.st <<'ST'
PackageLoader fileInPackage: 'greeter'.
Transcript showCr: (Greeter greet: 'world').
ObjectMemory quit: 0
ST
parley install --source ../my-index
parley exec run.st
```

`install` resolves the dependency, writes the lock, verifies the archive's
SHA-256 digest, and registers it in the project's package directory. `exec`
prints `Hello, world!`.

## Consume the sparse layout

If you chose the sparse publish command, use the same consumer files with
this source selection instead:

```sh
parley install --index "file://$(cd ../my-index && pwd)"
parley exec run.st
```

The local `file://` walkthrough needs `curl`, just as an HTTP sparse source
does. If the directory path contains spaces or other URL-significant bytes,
percent-encode them in the URL. Shell quoting alone does not perform URL
encoding.

A served sparse index uses its base URL as `--index`; a flat index committed
to git uses its repository URL as `--git`. Publishing writes local files. You
remain responsible for committing or serving those files through your chosen
transport.

## Release boundaries

Releases are immutable. Re-publishing the same package name and version into
an index is refused; publish a new version for a new release. Normal
preflight refusals leave the destination unchanged. A failed archive build
leaves its staging directory available for inspection.

For sparse publication, Parley lands the entry and archive before updating
the version listing. An interrupted publication can therefore leave an
unlisted release, rather than a listing that advertises absent files.

The authoring manifest is executable Smalltalk on the author's machine.
Consumers resolve from static index entries; they never evaluate your
`Package.st` to discover dependencies. Archive contents are fetched only
after resolution and checked against their recorded hash before installation.

Path dependencies cannot be published: a release cannot depend on a directory
on your laptop. Replace them with published constraints when preparing a
release. Development dependencies stay local to the root project and are
omitted from its published entry. See
[developing two packages](developing-two-packages.md).

[Guide index](README.md)
