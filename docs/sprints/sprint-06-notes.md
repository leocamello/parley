# Sprint 6 Notes — ExecutionScope + CLI (issue #8)

## What was built

The Phase 3 closer — "it's a package manager now." Six new classes in
`src/exec/`, one declared settled-class exception, and the untested
executable glue in `bin/`:

- **`Parley.ProcessRunner`** — the one process seam in all of Parley:
  `run:` via the kernel's `Smalltalk system:`, answering the child's
  exit code normalized from the raw wait status (`status // 256`).
- **`Parley.ExecutionError`** — the fail-stop signal of plan
  execution: carries the exact failing command line and exit code;
  `messageText` pinned as `Execution failed with exit code <n>:
  <command>`.
- **`Parley.ExecutionScope`** — the honest `bundle exec` (§8 decision
  16): `registrationCommands` is exactly the installed set's Doc D §4
  staged two-line plan (executed, never recomposed); `register` is
  fail-stop on the first nonzero exit and re-runnable; the pinned
  child composition `gst -i -I <target>/parley.im --no-user-files
  <script>`; `run:` answers the child's exit code as a value.
- **`Parley.ManifestFile`** — decision 19 resolved: `load:` clears
  the recording, files the developer's OWN `Package.st` in with the
  Parley namespace current (so the Doc B §2 syntax works verbatim),
  and answers the manifest `define:` recorded; a define-less file is
  one `ManifestError` naming the path. The declared exception:
  `Parley.Parley class >> define:` gained exactly one send
  (`ManifestFile record:` before answering).
- **`Parley.CLI` / `Parley.CliResult`** — the verbs over injected
  collaborators, answering an immutable value (`lines` Array +
  `exitCode`), never printing, never exiting, spawning only through
  the scope's runner: `init` (Doc B §2 template, one-line refusal),
  `resolve` (byte-stable lock via the settled writer; conflict
  narration as lines, exit 1), `install` (valid-pin fast path proven
  to consume no snapshot; hash-vs-cache corruption fail-stop naming
  the hash; settled `Installer`; `register`), `update` (the verb that
  moves a pin `install` keeps), `exec` (child's code, no lines of the
  CLI's own), usage/exit-2 for the grammar edges.
- **`bin/parley` + `bin/parley-main.st`** — glue only: files `src/`
  in (run-tests order), wires `DirectorySource` from `--source`,
  store at `<cwd>/.parley/store`, target at `<cwd>/.parley/packages`,
  a real runner; prints the lines and exits with the code.

Tests: 48 new (`ExecFixtures` + `RecordingRunner` +
`SnapshotAndFetchTrapSource` support; `ProcessRunnerTest`,
`ExecutionScopeTest`, `ManifestFileTest`, `CliTest` law suites;
`Sprint6AcceptanceTest` with `testS1_`–`testS19_`). The S7 exit
criterion runs the whole story for real: a toolchain-BUILT
`parley-probe.star` → resolve → lockfile → install → staged
registration through real `gst-package` → a curated child loads the
package by name and records its class as present.

## Ambiguities hit and how they were resolved

1. **The toolchain contradicted the approved registration anchors**
   (found pre-RED, reproduced from scratch): 3.2.5's `gst-package`
   accepts no `--install` spelling (install is the flagless default;
   the `--help` text is stale upstream), and the kernel's
   `Kernel.StarPackage` enforces filename/internal-name equality —
   so the original single-line plan over content-addressed
   `<sha256>.star` store paths could never execute, register, or be
   seen by the child. **Halted and asked on issue #8** rather than
   invent architecture. The operator's ruling (landed at `b41fa16`
   before RED restarted): flagless `gst-package`, the name-equality
   MVP constraint (Parley entry name IS the star's internal name),
   and the Doc D §4 staged two-line plan (`install -D -m 644` into
   `<target>/.parley-staging/<name>.star`, then `gst-package
   --target-directory`). E2e fixtures build their star with the
   toolchain itself (`gst-package --target-directory <dir>
   <pkgdir>/package.xml`), digested at fixture time through the
   settled `Sha256`.
2. **RED spawn-freedom vs the star-building fixture**: resolved by
   building the fixture star through `ProcessRunner` itself — the
   one-process-pathway invariant holds inside the tests, and in red
   the fixture fails on the missing class before anything spawns.
3. **Glue-level discovery** (untested `bin/`, noted for the record):
   under `gst -f <script> -- <argv>`, `Smalltalk arguments` includes
   the literal `'--'`; the main script skips a leading `--` before
   parsing. All law-tested surfaces were unaffected.

All exact wordings (usage, init template/refusal, corruption line,
`ExecutionError` message, define-less problem, success pin lines,
lock oracles) were pinned in RED and confirmed on issue #8 at Gate A.

## Verification

From `.parley_verification_audit`:

```
sprint: 6
date: 2026-07-20T20:47:38Z
toolchain: GNU Smalltalk version 3.2.5
PARLEY-SEED: 20260718
PARLEY-VERIFY: PASS seed=20260718 run=356 passed=356 failed=0 errors=0
```

`tmp/` absent after every clean run; the developer image was never
mutated (all real processes confined to `tmp/`; `gst-package` writes
stay target-confined).

Exact toolchain version output (`gst --version`, first line):

```
GNU Smalltalk version 3.2.5
```

(`gst-package --version` reports `gst-package - GNU Smalltalk version
3.2.5`.)
