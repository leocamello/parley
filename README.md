# Parley

> *Smalltalk packages, resolved by conversation.*

Parley is a modern, native command-line package manager for [GNU Smalltalk](https://www.gnu.org/software/smalltalk/) 3.2.5, written entirely in Smalltalk.

The language is called Smalltalk — casual conversation. A **parley** is the formal one: a negotiation between independent parties to resolve a conflict. And that is exactly what dependency resolution is — a negotiation between constraints, ending either in agreement (a `Resolution`) or a documented account of why the parties couldn't agree (a `ConflictReport`, rendered as a narrated transcript of the negotiation).

## Status

**v1.0, and the loop closes in both directions.** An author can publish a package into an index — flat, or the per-package sparse layout a client reads without ever downloading the whole index — and a consumer can resolve it, install it, and execute code against it in a curated child image, over a local directory, a git checkout or a `file://`/HTTP base. Every step is driven through the shipped `bin/parley` binary and proven that way by the test suite. What is *not* here yet: **registry hosting**, **prerelease versions**, **index signing**, and a `parley retire` verb (retirement *records* are honoured — a retired release is excluded from fresh resolution and reported by `parley check` — but the index owner writes the record by hand).

## Commands

```
parley init                     Create a new package with a Package.st manifest
parley resolve                  Resolve dependencies and write the lockfile
parley install                  Resolve, fetch, and register dependencies
parley update [<pkg>]           Re-resolve ignoring the lockfile — or move one package
parley add <pkg> <constraint>   Declare a dependency and move the project onto it
parley remove <pkg>             Delete a dependency and move the project off it
parley search <term>            Find packages the index publishes by name
parley info <pkg>               Show a package's versions, metadata and dependencies
parley outdated                 Show which pins have newer releases, and which need a wider constraint
parley publish <dir>            Build the archive and land a release in an index
parley exec <script>            Run a program inside a curated, resolved environment
parley why <pkg>                Explain what put a package in the lockfile
parley tree                     Show the pinned dependency graph
parley check                    Verify the lockfile against the manifest and the index
parley --version                Print the version, and nothing else
parley --help                   Print these usage lines, and nothing else
```

Asking the tool a question is not an error. `parley --help`, `parley -h` and `parley help` are the same question and all three exit `0`, as `parley --version` does — and none of them creates project state, because a `.parley/` that appeared when you asked what a command does would be state created by a question. Failing to *say* what you want still is an error: `parley` with no arguments, an unknown verb, and a trailing `parley resolve --help` all exit `2`.

Three flags select the index for the verbs that need one, and they are mutually exclusive — giving two is a usage error rather than a silent preference, because a typo should not look like a working command:

```
--source <dir>    index entries in a local directory
--git <repo>      index entries in a git repository (cloned once, pulled --ff-only)
--index <base>    index entries fetched per package from a sparse index
```

Parley's state for a project lives beside that project, under `<working-dir>/.parley/` — never beside the process's current directory. There is nothing to activate and nothing global.

### Exit codes

Parley never answers a backtrace, and no failing command ever exits `0`:

| Code | Meaning |
| --- | --- |
| `0` | success |
| `1` | a diagnosis — Parley understood what is wrong with your project and is telling you |
| `2` | usage — the command was not well formed |
| `70` | a defect in **Parley**, not in your project. One line, never a dump. Please report it. |

The split between `1` and `70` is deliberate and law-enforced: a script checking `$?` can tell "your input is wrong" from "the tool is broken".

### When Parley cannot read or write a file

Every file boundary in Parley checks the path before it commits to anything, and refuses by naming it. A checkout you cannot write, a root-owned `parley.lock`, a bad umask, a `chmod -R a-w` cache: those are states of your filesystem, not defects in Parley, and it says so at exit `1` rather than claiming to be broken.

```
$ parley resolve --source ../index
/srv/app/parley.lock: could not be written - check its permissions and try again
$ echo $?
1
```

The same shape covers the read side (`missing or unreadable Package.st`, `missing or unreadable archive file`) and every write: `init` and `add` on `Package.st`, `resolve` and `update` on `parley.lock`, `publish` on its destination. A refused write leaves the filesystem exactly as it found it — nothing is half-created, and `add` never moves your manifest without moving your lock.

The check is a **precheck, not a lock**. A path can become unwritable between the check and the write, and Parley makes no claim about that window; what it does guarantee is that such a failure still names the file at exit `1`, and never reports itself as broken.

### When your `Package.st` is broken

`Package.st` is a program Parley *runs*, which makes it the one place where text on your terminal was not written by Parley. GNU Smalltalk's own report of a failed statement is captured and re-voiced: you get one line naming your file and the line to open, not a stack trace through Parley's source tree.

```
$ parley resolve --source ../index
Object: nil
/srv/app/Package.st: line 2 raised an error while the manifest was being read - fix that line and try again
$ echo $?
1
```

Several problems in one manifest come back as **one batch naming the file**, so a single run tells you everything to fix rather than one thing per run:

```
$ parley resolve --source ../index
/srv/app/Package.st: 4 problem(s) in this manifest
missing required field name
invalid version 'nope'
fileIns must declare at least one file to load
invalid constraint 'garbage' for dependency 'demo'
```

**Two fragments in that output are the toolchain's, not Parley's, and both are deliberate.**

- **`Object: nil`, on standard output.** GNU Smalltalk writes the receiver of a failed message send below the level any Smalltalk code can reach, so Parley cannot remove it. It carries no stack frame and no file path. What Parley does is *end the line* it leaves dangling, so the fragment stays on its own line instead of running into the diagnosis underneath it.
- **`Package.st:3: parse error, expected ']'`, on standard error.** When the file will not even parse, GNU Smalltalk says so — naming your file *and* the line — and Parley **keeps** it, because it is the most useful sentence anything produces about a manifest that cannot be read and Parley cannot reconstruct it. On standard output Parley then reports `no manifest defined - the file never sent Parley define:`: it genuinely cannot tell a file that failed to parse from one that never declared a package, and rather than guess it says the thing that is true of both. The line on standard error is what tells you which you have.

**Your own `Transcript` output during a load is captured and discarded, and that is deliberate.** If your `Package.st` prints something while Parley is reading it — a progress line, a computed version — you will not see it. A manifest is a *declaration*, and the only thing Parley takes from running it is the package it declares; everything the run writes to the terminal is captured so that the toolchain's own output cannot reach you, and your own writing is in that same stream with nothing to tell it apart. Parley's standard output is a contract with whoever is reading it: every line is one Parley composed or one it documents keeping. If you want a program whose output you see, that is `parley exec`.

## Installing

Parley runs from a checkout. Clone it, then put the wrapper on your `PATH`:

```bash
git clone https://github.com/leocamello/parley.git ~/src/parley
ln -s ~/src/parley/bin/parley ~/.local/bin/parley
parley --version
```

The symlink is the supported route: `bin/parley` resolves its own symlink chain — including a link to a link — before locating the checkout, so it works from anywhere on your `PATH`. If you would rather point it explicitly, set `PARLEY_ROOT` to the checkout and the wrapper honours it:

```bash
PARLEY_ROOT=~/src/parley ~/src/parley/bin/parley --version
```

An installation whose `bin/parley-main.st` is missing exits `70` naming the path it looked for — a broken install is a defect in Parley, and it will not pretend to have succeeded.

### Recording your index once, in `parley.config.st`

`--source`, `--git` and `--index` are how you tell Parley where your index is. You do not have to retype them on every command: write them once, in a `parley.config.st` at the **project root**, beside `Package.st` and `parley.lock`.

```smalltalk
#(#'parley-config' 1 #source '../my-index' #git '' #index '')
```

It is Parley's own literal format — the same one index entries and lockfiles use — read by the same reader. All three keys are present, in that order, and the empty string means *not set*. Declare **at most one**: a file naming two sources is refused, for the same reason `--source` with `--git` is a usage error rather than a silent preference.

```sh
parley resolve                  # uses ../my-index, from the file
parley resolve --source ../other  # uses ../other; the file is not read at all
```

**A flag on the command line always wins**, and when you pass one the configuration file is not consulted at all — not for the flag you gave, and not for the ones you left out. That is what makes the file safe to add to a project that already works: it can only supply a default you did not type.

It lives at the project root and **not** under `.parley/`, deliberately. That directory is regenerable state — the store, the caches, the package target — and deleting it is a fair way to clean a project. Your configuration is yours, and it survives that:

```sh
rm -rf .parley && parley resolve   # still finds your index
```

Four things can be wrong with the file, and each answers one line naming it at exit `1`, never a backtrace: it is not a regular readable file, it does not parse, it is not a `#'parley-config' 1` artifact, or its body is malformed — a missing, misordered or unknown key, a value that is not a string, or two sources at once.

```
$ parley resolve
/home/you/project/parley.config.st: malformed configuration, the keys must be #source #git #index in that order - fix it or remove it and try again
$ echo $?
1
```

No Parley command writes this file, which is why every one of those lines ends the same way: fix it or remove it. Removing it always works — the tool goes back to the flags it always had.

## Publishing a package

`parley publish <dir>` builds the archive with `gst-package` from your own manifest and lands a release in the index directory you give it. An index is a directory you own — a folder, a git repository you push, a path behind any web server. There is no hosted registry to sign up for.

The destination has two shapes, and **you state which one you are writing**:

```sh
parley publish ../my-index                    # flat (the default)
parley publish ../my-index --layout sparse    # per-package
```

| Layout | What it writes | Who reads it |
| --- | --- | --- |
| `flat` | `<dir>/<name>-<version>.st` and `.star`, side by side | `--source`, `--git` |
| `sparse` | `<dir>/<name>/` holding `versions.st`, the entry and the archive | `--index` |

The layout is **stated, never inferred from the destination**: a brand-new index is empty and carries no evidence to read, so guessing would turn a mistyped path into a successful publish into the wrong shape. An unrecognized `--layout` value is a usage error at exit `2`, never a fallback to the default.

Two rules hold in both layouts. **Releases are immutable** — publishing a `(name, version)` the index already holds is refused, and nothing is written. **A refusal leaves the destination as it found it**: the entry and the archive land before `versions.st` is rewritten, so an interrupted sparse publish leaves an index that is merely missing a release rather than one that claims to hold a release it does not have.

`parley publish` needs no index flag: publishing produces index entries, it does not consume them.

## Using an installed package

### Coming from pip

The model maps almost one-to-one, with one important difference at the import step:

| Python | Parley |
| --- | --- |
| `python -m venv .venv` + `activate` | nothing to activate — every project's environment is `<project>/.parley/` |
| `pip install requests` | `parley install --source <index>` |
| `pyproject.toml` / `requirements.txt` | `Package.st` |
| `pip freeze` → pinned versions | `parley.lock` (written by `resolve`, byte-stable) |
| `import requests` | `PackageLoader fileInPackage: 'greeter'` |
| `python run.py` | `parley exec run.st` |

So **`parley exec` is the pip-and-import equivalent**: it is `python run.py` with the project's environment already in place.

Two differences worth knowing up front:

- **There is no global install and no activation.** Every project resolves into its own `<project>/.parley/`, so you are always in the equivalent of a virtualenv and never in a system-wide one.
- **Loading is explicit, and it is not namespaced.** A package is *not* on a search path waiting to be found — nothing is available until you ask for it, and when you do, its classes land in scope directly. `PackageLoader fileInPackage: 'greeter'` behaves like `from greeter import *`, not like `import greeter`.

A complete program:

```smalltalk
"run.st"
PackageLoader fileInPackage: 'greeter'.
Transcript showCr: (Greeter greet: 'world').
```

```sh
parley install --source ../index
parley exec run.st                     # → Hello, world!
```

### The three ways to run

`install` leaves a real GNU Smalltalk image at `<project>/.parley/packages/parley.im`, so `exec` is a convenience, not the only door.

**1. `parley exec run.st`** — use this for anything repeatable. It composes the curated child for you:

```sh
gst -g -i -I .parley/packages/parley.im --no-user-files run.st
```

`-i` rebuilds the image from the kernel on every run, so **no state leaks between runs**. That reproducibility is the whole point, and it is what makes `exec` the right choice in CI.

`-g` (`--no-gc-message`) is why your terminal stays clean. Rebuilding the image makes GNU Smalltalk write `"Global garbage collection... done"` to standard error — Parley's plumbing talking, in the middle of your program's own output. The flag stops it being written at all, which is the only way to remove it without touching the stream your script writes on: **your stdout and your stderr both reach you untouched**, and so does your exit code. Run the command by hand without `-g` and you will see the difference.

**2. The same command by hand, without `-i`** — reuses the built image instead of rebuilding it:

```sh
gst -I .parley/packages/parley.im --no-user-files run.st
```

Roughly an order of magnitude faster to start. The trade is real: the image now accumulates whatever you file into it, so this is for iterating, not for reproducing.

**3. An interactive REPL with your dependencies available:**

```sh
gst -I .parley/packages/parley.im --no-user-files
```

```smalltalk
st> PackageLoader fileInPackage: 'greeter'.
st> (Greeter greet: 'REPL') printNl.
'Hello, REPL!'
```

This is the closest thing to `python` inside an activated virtualenv, and it is the fastest way to explore a dependency you have just installed. The image path may be absolute, so the REPL works from any directory.

### What `exec` checks before it runs anything

`parley exec <script>` checks one thing itself, before anything is spawned: that `<script>` is a file it can read. A path that is missing — or that turns out to be a directory — is refused with one line at exit `1`, and no child process starts:

```
$ parley exec typo.st
typo.st: missing or unreadable script - nothing was run
$ echo $?
1
```

Parley checks this rather than leaving it to the child because GNU Smalltalk 3.2.5 answers exit `0` for both cases — printing `gst: Couldn't open file` for the missing script, and nothing at all for the directory — and because the discipline described in the next section is unavailable here: a file that does not exist cannot carry a guard.

### One sharp edge

`exec` reports the child's exit code faithfully — and GNU Smalltalk 3.2.5 continues past an unhandled error at the top level of a script, then **exits `0`**. So a script that fails can still leave you with `$? = 0`:

```
$ parley exec broken.st
Object: nil error: did not understand #greet:   ← the child's own backtrace, not Parley's
$ echo $?
0
```

Parley's own "never exit `0` on failure" guarantee covers Parley's diagnoses, not your script's runtime behaviour. If a script's success matters to CI, end it deliberately:

```smalltalk
result isNil ifTrue: [ObjectMemory quit: 1].
ObjectMemory quit: 0
```

## Design highlights

- **Live-object domain.** Every pipeline concept — a version, a constraint, a source, a conflict, an execution scope — is an independent object answering messages. Conflict reports are inspectable derivation trees, not error strings.
- **Static trust boundary.** Authors write executable `Package.st` manifests for ergonomics, but the resolver consumes only static, literals-only index entries. Third-party code is never evaluated to compute a dependency graph.
- **Deterministic by construction.** Byte-stable serialization, day-one lockfiles, and a pure resolver: same inputs produce a byte-identical lockfile, every time.
- **Honest sandboxing.** GNU Smalltalk 3.2.5 cannot host two versions of a class in one image, so Parley doesn't pretend otherwise: `parley exec` launches a clean child `gst` process whose curated package path exposes exactly the resolved set.
- **Tested as laws.** The constraint algebra is verified against mathematical laws (De Morgan, absorption, double complement, membership consistency) over hundreds of seeded random cases per run.

Read more in [docs/design/architecture.md](docs/design/architecture.md) and [docs/design/rationale.md](docs/design/rationale.md).

## Requirements

- [GNU Smalltalk](https://www.gnu.org/software/smalltalk/) **3.2.5** (the stable baseline; `gst --version` should report 3.2.5)
- No other dependencies — Parley is self-contained by design

## Development

```bash
./scripts/verify-sprint.sh              # lint guardrails + full SUnit suite
./scripts/verify-sprint.sh --seed 42    # run the randomized law suites with an explicit seed
```

Verification is the single gate: it runs deterministic lint guardrails first, then the axiomatic SUnit suite against gst 3.2.5. See [CONTRIBUTING.md](CONTRIBUTING.md) for the workflow and [AGENTS.md](AGENTS.md) for the binding engineering rules.

## Documentation

Start at [docs/design/README.md](docs/design/README.md) — it indexes the specs
and maps the Doc A–F letters used throughout the code to their files.

| Document | Contents |
| --- | --- |
| [docs/design/architecture.md](docs/design/architecture.md) | System blueprint, invariants, and the decision log |
| [docs/design/rationale.md](docs/design/rationale.md) | Why the architecture is shaped this way |
| [Doc A — domain-model.md](docs/design/domain-model.md) | `Version`, `VersionRange`, `VersionConstraint` — the keystone set algebra |
| [Doc B — manifest-and-serialization.md](docs/design/manifest-and-serialization.md) | `Package.st` authoring and the literal micro-format |
| [Doc C — resolver.md](docs/design/resolver.md) | The pure resolver, constraint provenance, and conflict narration |
| [Doc D — installer.md](docs/design/installer.md) | `Sha256`, the content-addressed store, and `gst-package` registration |
| [Doc E — execution-and-cli.md](docs/design/execution-and-cli.md) | `ProcessRunner`, `ExecutionScope`, the CLI verbs, and the diagnosis boundary |
| [Doc F — publish-and-sources.md](docs/design/publish-and-sources.md) | The publish pipeline, entry validation, and `GitIndexSource` |
| [docs/sprints/](docs/sprints/) | The delivery record — what each sprint built, with its seed and law count |

## License

[MIT](LICENSE)
