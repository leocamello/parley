# Sprint 5 Notes — the Installer (issue #7)

## What was built

The Installer value pipeline per Doc D (`docs/design/installer.md`), all
new classes in `src/install/`:

- **`Parley.Sha256`** — pure FIPS 180-4 SHA-256 against the 3.2.5
  kernel; one public message, `hexDigestOf:` → 64 lowercase hex. 32-bit
  arithmetic via `bitAnd: 16rFFFFFFFF`; the round constants and initial
  hash rendered in decimal. Landed first and alone: all four
  issue-pinned vectors (both padding edges) plus the determinism, shape
  and distinctness laws went green before any other class was touched.
- **`Parley.ContentStore`** — the content-addressed cache: `on:`
  (no I/O; lazy one-level root creation on first `store:`), idempotent
  `store:` → `<sha256>.star`, `containsHash:`, `pathForHash:`,
  `verifyHash:` (detection only; `''` is never a valid key).
- **`Parley.DirectorySource fetch:version:`** — the sole declared
  settled-class exception: the Sprint 4 stub body replaced per
  Doc D §1.1 (archive bytes from the file named by the entry's
  `#archive` field, resolved relative to the source directory; three
  one-problem `SourceError` shapes). Two comment lines in the same file
  (header + class comment) lost their now-false "stub" wording —
  ruled within the exception by the operator on issue #7.
- **`Parley.InstallError`** — one batched error per install pass;
  `problems` in sorted package-name order; messageText
  `'Install has <n> problem(s): '` joined by `'; '` (house style).
- **`Parley.InstalledSet`** — the immutable product: (name, Version,
  sha256, store path) tuples; `packageNames`, `versionOf:`,
  `sha256For:`, `pathFor:`; NO value equality (decision-23 precedent);
  `registrationCommandsFor:` composes the registration plan as pure
  `gst-package --install --target-directory <dir> <path>` strings —
  execution belongs to Sprint 6's `ExecutionScope`; no process is
  spawned anywhere in `src/` or tests.
- **`Parley.Installer`** — `source:store:`, `install:` per Doc D §1:
  sorted package-name order; empty-sha problem before the cache check;
  cache hits skip fetch entirely; fetch `SourceError`s become batched
  problems; verify-then-store (a mismatch never enters the store);
  clean packages complete even when others fail; re-install is a
  no-op.

Tests: `tests/support/InstallFixtures.st` (+ `FailingFetchSource`),
`tests/laws/Sha256Test.st`, `ContentStoreTest.st`, `SourceFetchTest.st`,
`InstallerTest.st`, `tests/acceptance/Sprint5AcceptanceTest.st`
(S1–S17). Every fixture digest is the true SHA-256 of its archive
bytes, operator-verified against `sha256sum`; the S17 lockfile oracle
carries the three true 64-hex digests and is byte-stable across runs.
`tmp/` is absent after a clean run.

## Ambiguities and their resolution

- No design questions were needed: Doc D + the amended Doc C §1.1 +
  Doc B §5.2 answered everything. All test-pinned protocol decisions
  (fetch and install problem wordings, pipeline order, the plan living
  on `InstalledSet`, one-level lazy root creation) were posted on
  issue #7 at RED and approved unamended at Gate A.
- Mid-sprint the circuit breaker tripped procedurally (a diagnostic
  re-run with no code change produced the seeded suite's byte-identical
  failure output — the fast-trip signature). The operator verified no
  law or design question was involved, reset the breaker, and codified
  the rule: one verifier run per code increment, diagnostics taken from
  that run's output.

## Verification

From `.parley_verification_audit`:

```
sprint: 5
date: 2026-07-20T19:11:25Z
toolchain: GNU Smalltalk version 3.2.5
PARLEY-SEED: 20260718
PARLEY-VERIFY: PASS seed=20260718 run=308 passed=308 failed=0 errors=0
```

`gst --version` (first line):

```
GNU Smalltalk version 3.2.5
```
