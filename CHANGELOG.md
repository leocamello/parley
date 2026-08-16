# Changelog

All notable changes to Parley are documented in this file. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
Parley versions follow the same `major.minor.patch` discipline its own
resolver enforces. The newest version heading below is held equal to
`Parley version` by a law in the shipped test suite, so this file is
mechanically current: bumping the constant without an entry fails the
build.

## [1.0.0] - 2026-08-16

The first release: a complete, honest, local-and-git package manager
for GNU Smalltalk 3.2.5, written entirely in Smalltalk, whose client
already speaks the registry protocol.

### Added

- **The verbs.** `init`, `resolve`, `install`, `update` (whole-project
  and single-package), `add`, `remove`, `search`, `info`, `outdated`,
  `exec`, `publish`, `why`, `tree` and `check` — each answering a
  value, never printing from inside the domain, and never exiting `0`
  on a failure.
- **Deterministic resolution.** A pure backtracking resolver over a
  normalized constraint algebra; the same inputs always answer the
  same resolution and a byte-identical `parley.lock`. Conflicts are
  answered as narrated proofs, not stack traces.
- **Three index transports.** A local directory (`--source`), a git
  repository (`--git`), and a sparse per-package index (`--index`),
  all answering one source protocol; archives are content-addressed
  and hash-verified before anything registers.
- **Process-level isolation.** `parley exec` runs your script in a
  clean child image whose package path holds exactly the resolved
  set — the honest `bundle exec` for a namespace system that cannot
  isolate versions in-image.
- **Dependencies you are developing.** `path:` dependencies overlay
  the index during development — edit the sibling, re-run `exec`, no
  publish — and `devDependency:` declarations never reach a published
  entry.
- **Configuration without retyping.** A project records its index in
  `parley.config.st`; from this release the environment supplies the
  same values through `PARLEY_SOURCE`, `PARLEY_GIT` and
  `PARLEY_INDEX`, with the precedence chain flag > environment >
  file — an explicit flag always wins.
- **CI-grade modes.** `--offline` guarantees no network child is
  spawned; `--locked` guarantees `parley.lock` does not change, and
  names the first pin that would have moved.
- **Diagnoses that name the right party.** Every operator-editable
  file is read through a validated boundary: a malformed manifest,
  lock, entry or configuration answers one line naming the file, a
  cause and a checked remedy at exit `1`; a defect in Parley itself
  is exit `70`, and no failing command ever exits `0`.
- **Self-hosting.** Parley ships as its own `Package.st` and the test
  suite publishes, installs and loads Parley with Parley on every
  run.
- **Shell completions.** `completions/parley.bash` and
  `completions/_parley`, generated from the CLI's own declared
  tables and held byte-identical to them by law.
