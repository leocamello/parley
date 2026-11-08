# Parley

[![verify](https://github.com/leocamello/parley/actions/workflows/verify.yml/badge.svg)](https://github.com/leocamello/parley/actions/workflows/verify.yml)

> *Smalltalk packages, resolved by conversation.*

Parley is a native command-line package manager for [GNU Smalltalk](https://www.gnu.org/software/smalltalk/) 3.2.5, written entirely in Smalltalk. Resolve dependencies, keep reproducible lockfiles, develop sibling packages together, and publish releases to an index you control.

## Status

**v1.0.0 is released.** An index can be flat, or the per-package sparse layout; local, git and HTTP/file sources support the publish–resolve–install–execute loop. Dependency conflicts carry inspectable explanations. Registry hosting, prerelease versions and index signing remain [deferred](docs/roadmap.md); retirement records are supported, but there is no `parley retire` command.

## Installing

Install GNU Smalltalk **3.2.5** and its bundled `gst-package`, then run:

```sh
mkdir -p ~/src ~/.local/bin
git clone https://github.com/leocamello/parley.git ~/src/parley
ln -s ~/src/parley/bin/parley ~/.local/bin/parley
export PATH="$HOME/.local/bin:$PATH"
parley --version
```

The wrapper follows symlinks to its checkout. You can also select it explicitly:

```sh
PARLEY_ROOT=~/src/parley ~/src/parley/bin/parley --version
```

See [installing](docs/guide/installing.md) for prerequisites, shell completion and checks.

## The sixty-second walk

The fastest true thing Parley can show you is the workflow that usually hurts: a library and its consumer, side by side, edited together. Sixty seconds, no index and no publish anywhere.

Make the pair, and give the library one class and a manifest (`parley init` writes a starter to edit):

```smalltalk
"demo/kernel-text/Text.st"
Object subclass: KernelText [
    KernelText class >> shout: aString [ ^aString, '!' ]
]
```

```smalltalk
"demo/kernel-text/Package.st"
Parley define: [:pkg |
    pkg
        name: 'kernel-text';
        version: '0.1.0';
        fileIns: #('Text.st') ]
```

The consumer declares the library **by path** — a directory, not a constraint:

```smalltalk
"demo/my-app/Package.st"
Parley define: [:pkg |
    pkg
        name: 'my-app';
        version: '0.1.0';
        fileIns: #('App.st');
        dependency: 'kernel-text' path: '../kernel-text' ]
```

```sh
cd demo/my-app
parley resolve                # no index needed: the dependency is a directory
cat > run.st <<'ST'
Transcript showCr: (KernelText shout: 'sixty seconds').
ObjectMemory quit: 0
ST
parley exec run.st            # → sixty seconds!
```

Now edit the sibling — make `shout:` append `'!!'` in `../kernel-text/Text.st` — and run `parley exec run.st` again. The change is there. No publish, no rebuild, no re-registration: `exec` reads a path dependency fresh on every run, and `parley.lock` records it as provenance (`#path '../kernel-text'`) rather than as a digest. When the library is ready for the world, `parley publish` takes over — and refuses a manifest that still declares a path, because a release cannot depend on a directory on your laptop.

## Commands

| Command | Purpose |
| --- | --- |
| `parley init` | Create a starter `Package.st` |
| `parley resolve` | Resolve dependencies and write `parley.lock` |
| `parley install` | Resolve, fetch and register dependencies |
| `parley update [<pkg>]` | Re-resolve all pins, or move one package |
| `parley add <pkg> <constraint>` | Declare a dependency and resolve it |
| `parley remove <pkg>` | Remove a dependency and resolve the remainder |
| `parley search <term>` | Search index package names |
| `parley info <pkg>` | Show versions, metadata and dependencies |
| `parley outdated` | Compare pins with available releases |
| `parley publish <dir>` | Build an archive and publish it into an index |
| `parley exec <script>` | Run code with the project's dependencies |
| `parley why <pkg>` | Explain a pinned dependency |
| `parley tree` | Show the pinned dependency graph |
| `parley check` | Check the lock against the manifest and index |
| `parley --version` | Print the version |
| `parley --help`, `parley -h`, `parley help` | Print usage |

| Flag | Meaning |
| --- | --- |
| `--source <dir>` | Read a local flat index |
| `--git <repo>` | Read a flat index through a git checkout |
| `--index <base>` | Fetch sparse metadata per package |
| `--offline` | Refuse git and curl source operations |
| `--locked` | Refuse changes to resolved lock data and leave the lock untouched |
| `--layout flat` / `--layout sparse` | Select the publication layout |

## Configuration

Precedence is **flag > environment > file**. A source flag **always wins**, skipping both lower layers; a set environment variable skips the file. Supply at most one source per layer. Empty environment variables are unset.

```sh
parley resolve --source ../my-index        # flag
PARLEY_SOURCE=../my-index parley resolve   # environment
```

For a persistent default, put `parley.config.st` at the **project root**, beside `Package.st`:

```smalltalk
#(#'parley-config' 1 #source '../my-index' #git '' #index '')
```

Then `parley resolve` uses that file. See [configuration](docs/guide/configuration.md) for git/sparse sources and diagnostics.

## Exit codes

| Code | Meaning for Parley's own commands |
| --- | --- |
| `0` | Success |
| `1` | A project or input diagnosis |
| `2` | Invalid command usage |
| `70` | An internal defect or incomplete installation |

`exec` passes through the child's status; GNU Smalltalk can exit `0` after a script error. Read the [script exit-code guidance](docs/guide/running-code.md#exit-codes-and-ci) before using it in CI.

## Requirements

GNU Smalltalk **3.2.5**, its bundled `gst-package`, and a POSIX shell. Archive operations use the toolchain's `zip`/`unzip`; git sources need `git`, and sparse sources need `curl`. Parley adds no third-party Smalltalk library dependencies. [Installation details](docs/guide/installing.md).

## Development

```sh
./scripts/verify-sprint.sh             # guardrails and SUnit laws
./scripts/verify-sprint.sh --seed 42   # a second deterministic seed
```

Use the verifier for tests. See [CONTRIBUTING.md](CONTRIBUTING.md) for the development workflow.

## Documentation

- [User guide](docs/guide/README.md): installation, configuration, running code, publishing, developing two packages and troubleshooting.
- [Design specifications](docs/design/README.md): the Doc A–F map, [architecture](docs/design/architecture.md), [decision index](docs/design/architecture.md#8-decision-log) and [rationale](docs/design/rationale.md).
- [Roadmap](docs/roadmap.md) and [delivery record](docs/sprints/).

## How this was built

Parley doubles as a methodology experiment: a five-stage sprint pipeline — requirements, architecture, failing tests, implementation, wrap — in which the test suite is written and human-reviewed before any implementation exists, every behavior ships as a law, and every design ruling lands in a decision log in the same commit as the change that cites it.

The record is public, and it is the interesting half of the repository:

- The six component specs — [domain-model.md](docs/design/domain-model.md), [manifest-and-serialization.md](docs/design/manifest-and-serialization.md), [resolver.md](docs/design/resolver.md), [installer.md](docs/design/installer.md), [execution-and-cli.md](docs/design/execution-and-cli.md) and [publish-and-sources.md](docs/design/publish-and-sources.md) — under [docs/design/](docs/design/), beside the system blueprint and its decision log.
- The sprint-by-sprint delivery record in [docs/sprints/](docs/sprints/): what each sprint built, the ambiguities it hit and how each was resolved, and the seed and law count it closed at.
- The method audit in [docs/method/findings.md](docs/method/findings.md), which grades the pipeline against its own misses and counts what actually caught each defect:

| Findings tally (quoted from the audit) | Count |
| --- | --- |
| Defect-findings | **32** |
| — caught by a mechanism | **18** |
| — caught by luck | **14** |
| Confirmation-findings (excluded from the ratio) | **6** |

The suite behind all of it stands at **1226** axiomatic laws, and both numbers above are held by drift laws in that same suite: the tally must equal the audit's own table, and the law count must equal the suite CI discovers — this section fails the build when it goes stale.

## Parley, packaged by Parley

The checkout you are reading is itself a Parley package. A root [Package.st](Package.st) declares `parley` at the version the tool answers — the literal and the constant held equal by a drift law — and names every source file under `src/`, with its subdirectory path, in load order, held equal to the tree by a second one. On every suite run Parley **publishes itself** into a transient index through its own `publish` machinery, a consumer project resolves and installs `parley 1.0.0`, and a curated child image loads the star and asks the gateway its version. The package manager, packaged by itself, proved by the same laws that prove everything else; the showcase index is transient test state and is never committed.

## License

[MIT](LICENSE)
