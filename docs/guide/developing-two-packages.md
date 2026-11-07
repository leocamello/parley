# Developing two packages together

A path dependency lets a consumer use a sibling checkout immediately. You
can edit the library and rerun the consumer without publishing a release for
each edit. This expands the [sixty-second walk](../../README.md#the-sixty-second-walk)
into commands you can copy into a fresh directory.

## Make the library and consumer

```sh
mkdir -p parley-dev-demo/kernel-text parley-dev-demo/my-app
cd parley-dev-demo
cat > kernel-text/Text.st <<'ST'
Object subclass: KernelText [
    KernelText class >> shout: aString [ ^aString, '!' ]
]
ST
cat > kernel-text/Package.st <<'ST'
Parley define: [:pkg |
    pkg
        name: 'kernel-text';
        version: '0.1.0';
        fileIns: #('Text.st') ]
ST
cat > my-app/Package.st <<'ST'
Parley define: [:pkg |
    pkg
        name: 'my-app';
        version: '0.1.0';
        fileIns: #('run.st');
        dependency: 'kernel-text' path: '../kernel-text' ]
ST
cat > my-app/run.st <<'ST'
Transcript showCr: (KernelText shout: 'working together').
ObjectMemory quit: 0
ST
cd my-app
parley resolve
parley exec run.st
```

The result is `working together!`. No index or `install` invocation is needed
for this path-only project. `resolve` records the path in the lockfile, and
`exec` loads the sibling's declared source files before running the script.

Edit `../kernel-text/Text.st` so `shout:` appends `'!!'`, then run:

```sh
parley exec run.st
```

The result changes immediately to `working together!!`. The source is read
fresh; Parley does not rebuild and register a sibling archive on each run.

## What a path pin means

The directory is relative to the declaring manifest. Its own `Package.st`
supplies its name, version and dependencies. A path dependency takes precedence
over an index release of the same name.

The lock records the path as written, rather than a digest of local source:

```smalltalk
#('kernel-text' '0.1.0' #path '../kernel-text')
```

`install` does not fetch, store or register a path pin. `check` reports when
the sibling's declared version differs from its lock pin. `why` identifies
the path that supplied the dependency. `info` still asks the index what it
publishes, so it does not turn a local checkout into an index release.

For a project whose dependencies are all paths, these inspections need no
index:

```sh
parley check
parley tree
parley why kernel-text
```

When a sibling also depends on published packages, provide an index and
install those archives. `exec` loads path-supplied sources in dependency
order, preserving each manifest's `fileIns:` order.

## Development dependencies

Use `devDependency:constraint:` for a published tool needed to develop this
root project, but not by its consumers. For example, if your index contains
`kernel-lint`, add this declaration to the root manifest:

```smalltalk
devDependency: 'kernel-lint' constraint: '^1.0.0'
```

That line is a message in the existing `pkg` cascade, not a complete manifest.
It makes the root project's resolution include `kernel-lint`; it does not
create the package in an index. Supply the appropriate source and use
`parley install` to fetch its archive.

Development dependencies are root-only: consumers of a published package do
not inherit its author's development tools, and a sibling's development
dependencies do not become dependencies of your project through the path
overlay.

## Preparing a release

`parley publish` refuses a manifest containing a path dependency. Publish the
library first, then replace the consumer's path clause with a version
constraint that its index can satisfy:

```smalltalk
dependency: 'kernel-text' constraint: '^0.1.0'
```

After switching from a path to an archive, scripts must
[load the package explicitly](running-code.md#load-an-installed-package)
with `PackageLoader fileInPackage:` before using its classes; automatic
source loading applies to path pins.

Development dependencies are omitted from published metadata. Keep them in
the authoring manifest if you still need them locally.

The [publishing guide](publishing.md) walks through both sides of an archive
release. The [configuration guide](configuration.md#offline-and-locked-invocations)
explains `--offline` and `--locked` when you need to constrain an invocation.

[Guide index](README.md)
