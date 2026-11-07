# Running code with dependencies

Use `parley exec <script>` from your project directory. It starts a child GNU
Smalltalk process with the project's installed packages available and the
path dependencies from its lockfile loaded in dependency order.

For published dependencies, run `parley install` first. `exec` does not fetch
or install them for you. For path-only projects, follow the
[two-package guide](developing-two-packages.md): `resolve` writes the path
pins, and `exec` reads those source files fresh on every invocation.

## Load an installed package

The [publishing walkthrough](publishing.md) creates the `greeter` package and
an application that depends on it. In that application's directory, this is
a complete script:

```smalltalk
"run.st"
PackageLoader fileInPackage: 'greeter'.
Transcript showCr: (Greeter greet: 'world').
ObjectMemory quit: 0
```

```sh
parley install --source ../my-index
parley exec run.st
```

The greeting is `Hello, world!`. Loading an installed package is explicit:
being registered does not make its classes available until
`PackageLoader fileInPackage:` loads it. Classes enter the scope declared by
the package; the package name is not an automatically created namespace.

`exec` preserves the script's stdout, stderr and exit code. It accepts quoted
script paths containing spaces or apostrophes:

```sh
parley exec 'hello world.st'
```

The named file must exist. Parley's argument preservation does not promise
that every downstream tool accepts every possible filename; in particular,
publishing still depends on `gst-package` and its XML/archive handling.

## Exit codes and CI

GNU Smalltalk 3.2.5 can continue after an unhandled error in a top-level
script and then exit `0`. `exec` faithfully returns that status; it cannot
infer that the script failed from the child's output.

If a script's success **matters to CI**, make the outcome explicit. For the
`greeter` example, this script checks its result and exits accordingly:

```smalltalk
| result |
PackageLoader fileInPackage: 'greeter'.
result := Greeter greet: 'world'.
result = 'Hello, world!' ifFalse: [ObjectMemory quit: 1].
ObjectMemory quit: 0
```

This checks the stated result. It is not a general exception handler: an
unhandled error before the check still has the toolchain's behavior described
above. Programs and test harnesses must define their own failure handling.
Parley's nonzero-exit guarantee covers its own diagnosed failures, not every
runtime error in an arbitrary script.

## What Parley checks before running

Parley checks that the script is a regular readable file
**before anything is spawned**. A missing file or a directory is refused at exit `1`:

```text
$ parley exec typo.st
/home/you/project/typo.st: missing or unreadable script - nothing was run
$ echo $?
1
```

The path in your output names your project. Parley performs this check because
GNU Smalltalk 3.2.5 does not give those file-opening failures a useful nonzero
exit status. An absent file cannot contain its own explicit failure guard.

If the lock names a path dependency, Parley also reads its manifest before
launching the child. A missing or malformed sibling is diagnosed at that
boundary. Relative script paths are resolved against the project directory.

## The child process and manual invocations

For installed archives, the command composed by `exec` has this shape:

```sh
gst -g -i -I .parley/packages/parley.im --no-user-files run.st
```

`-i` rebuilds from the kernel for each invocation, and `--no-user-files`
excludes personal startup customizations. The image directory exposes the
project's registered archives. `-g`, whose long spelling is
`--no-gc-message`, suppresses image-rebuild chatter at its source while
leaving your script's output streams untouched.

When path pins exist, Parley adds their source filenames before the script
in the command. The manual example above does not perform that extra work,
nor does it run Parley's preconditions. Prefer `parley exec` for the project
workflow.

You can load an existing saved image without forcing a kernel rebuild:

```sh
gst -I .parley/packages/parley.im --no-user-files run.st
```

This starts from the image on disk. Objects loaded or changed in that process
are not automatically saved back to the image when the process ends.

For an interactive session with installed archives available:

```sh
gst -I .parley/packages/parley.im --no-user-files
```

At the Smalltalk prompt:

```smalltalk
PackageLoader fileInPackage: 'greeter'.
(Greeter greet: 'REPL') printNl.
```

The reply is `'Hello, REPL!'`. An absolute image path lets you start this
session from another directory.

## Coming from pip

| Python workflow | Parley workflow |
| --- | --- |
| Create and activate a virtual environment | Each project uses its own `.parley/`; nothing to activate |
| `pip install` declared dependencies | `parley install --source <index>` |
| Declare dependencies in `pyproject.toml` | Declare them in `Package.st` |
| Record pinned versions | `parley resolve` writes `parley.lock` |
| Import a dependency | Explicitly send `PackageLoader fileInPackage:` |
| `python run.py` in that environment | `parley exec run.st` |

There is no global install. Package loading follows Smalltalk class and
namespace declarations rather than Python's module import model.

[Guide index](README.md)
