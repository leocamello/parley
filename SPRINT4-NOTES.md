# Sprint 4 Notes — the first real source: DirectorySource and resolve-on-disk

Tracked by GitHub issue #6. Specs of record: Doc C §1/§1.1/§7 (as amended
at staging), Doc C §2, Doc B §5. Purely additive: no Sprint 0–3 class was
touched.

## What was built

- **`Parley.SourceError`** (`src/source/SourceError.st`) — the batched
  scan error in the `ManifestError problems` style: one error per scan,
  a `problems` array of human-readable strings in sorted-filename order,
  messageText `'Source directory has <n> problem(s): '` with problems
  joined by `'; '`.
- **`Parley.DirectorySource`** (`src/source/DirectorySource.st`) — the
  first real `PackageSource`. `on:` holds the directory path immutably;
  `snapshot` is the one I/O moment: every `.st` file read once in
  sorted-filename order, one `#'parley-index' 1` artifact each parsed by
  `IndexEntryReader` (never the compiler), identity from entry contents
  (never filenames), release sha256 off the `#archive` field (`''` for
  `#archive #()`), answered as a sealed `IndexSnapshot` via the settled
  `releases:` protocol. Problems batch — unparseable/mis-tagged file
  (with the reader's positioned reason), wrong tag, duplicate
  (name, version) across files, missing directory — into one
  `SourceError`. `versionsOf:` speaks the snapshot convention;
  `manifestFor:version:` converges with `LibraryManifest fromIndexEntry:`
  and answers nil for an unknown (package, version); `fetch:version:` is
  the pinned install-time stub (`Installer` is Sprint 5).
- **Tests** — `tests/support/SourceFixtures.st` (runtime fixture
  directories under `tmp/`, hand-authored diamond entry set with
  `#archive` shas, offending-file contents, writer-authored path,
  teardown leaving `tmp/` empty/absent), `tests/laws/DirectorySourceTest.st`
  (18 laws: snapshot correctness, every `SourceError` shape, the
  batching/sorted-order law, the sealed-snapshot law,
  contents-not-filename, writer-authored convergence, protocol surface,
  fetch stub, empty-directory and non-`.st` handling),
  `tests/acceptance/Sprint4AcceptanceTest.st` (S1–S12, one selector
  each; S10 pins the Sprint 2 S16 lock string byte-for-byte as the
  on-disk oracle).

## Ambiguities and their resolution

- **RED protocol decisions** (posted on issue #6, approved at the Gate A
  review with no amendments): the `on:` constructor and the exact
  four-message public surface; nil for unknown `manifestFor:version:`;
  the empty-collection convention for unknown `versionsOf:`; the exact
  problem-string wordings (reader-rejected `<basename>: <reader
  messageText>`, wrong tag, duplicate naming both files, missing
  directory naming the path); the `SourceError` messageText format; the
  exact fetch-stub message; the `tmp/parley-<label>` flat fixture
  scheme; the hand-authored diamond entry bytes.
- **`isKindOf: nil` in red phase**: gst 3.2.5 answers true for
  `anObject isKindOf: nil`, which let an early draft of the
  no-partial-snapshot law pass while `SourceError` was still undefined.
  The test was hardened to demand the error's `problems` payload
  (endorsed at review); no test passed in red.
- **`tmp/` teardown**: `File>>stripPath` resolves `tmp/.` to `tmp`, so
  the dot-entry filter in the teardown helper uses raw `namesDo:` dirent
  names instead. `tmp/` is empty or absent after every clean run.
- No design questions needed escalation: the amended Doc C §1/§1.1/§7
  and Doc B §5 answered everything else.

## Verification

From `.parley_verification_audit`:

```
sprint: 4
date: 2026-07-19T22:52:47Z
toolchain: GNU Smalltalk version 3.2.5
PARLEY-SEED: 20260718
PARLEY-VERIFY: PASS seed=20260718 run=263 passed=263 failed=0 errors=0
```

Seeded rerun check: two consecutive `./scripts/verify-sprint.sh
--seed 424242` runs produced identical
`PARLEY-VERIFY: PASS seed=424242 run=263 passed=263 failed=0 errors=0`
lines; `tmp/` absent afterward.

Toolchain (`gst --version`, first line):

```
GNU Smalltalk version 3.2.5
```
