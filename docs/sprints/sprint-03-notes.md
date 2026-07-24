# Sprint 3 Notes — Trustworthy Resolution

## What was built

The decision-pin soundness fix (amended Doc C §3/§5/§7, master plan §8
decision 22), then the remaining pure Phase-2 surfaces — all in the
`Parley` namespace, class-side construction, zero public setters:

- **`Incompatibility`** (extended, declared exception) — the external
  `#decision` kind: `decisionOf:version:` builds the single positive
  exact term `{pkg = v}`; `isExternal` true, `cause = #decision`. Its
  sentence is `'b 2.0.0 is selected'` (the term's narration phrase +
  `' is selected'`), composing into derived nodes' because-clauses
  through the existing `conclusionOn:` machinery.
- **`BacktrackingStrategy`** (extended, declared exception) —
  `try:version:ledger:solution:` now records the decision pin — an
  ordinary `Term` (`pkg` exactly `v`, positive, origin: that decision's
  `#decision` node) via `recordTerm:` — into the descent ledger copy
  **before** the candidate's dependency edges. A late edge contradicting
  an already-decided package empties that package's accumulation and
  surfaces as an ordinary `recordTerm:` collapse whose provenance holds
  the pin and the offending edge. No other strategy change; no soundness
  re-check branches; backtracking discards pins with the ledger copy.
- **`Resolution class >> fromLockEntry:`** (extended, declared) — the
  lock read-back path mirroring `LibraryManifest fromIndexEntry:`:
  key-scan of the parsed `#'parley-lock' 1` array, versions re-parsed
  via `Version fromString:`; write → read → `fromLockEntry:` = identity,
  and re-writing the reconstruction is byte-identical.
- **`ApplicationManifest`** (`src/manifest/`, new, approved on the
  issue) — the immutable manifest+lock association per Doc B §4:
  `manifest:lock:` / `manifest:` (no lock yet), `hasLock`, `lock` (nil
  when absent), `manifest`, and delegating read-only accessors
  (`name`/`version`/`summary`/`author`/`license`/`fileIns`/
  `dependencies`).
- **`PinVerification`** (`src/resolver/`, new, approved on the issue) —
  the pure half of the Doc C §6 fast path: `of:lock:` checks the ROOT
  manifest's constraints only against the lock's pins, batching every
  problem (missing pin / violated pin, `ManifestError problems` style,
  manifest-declaration order) into one immutable verdict value with
  `isValid` and `problems`. Extra transitive pins are valid. A pure
  function of its two arguments — no snapshot, no resolver, no I/O.

Test surfaces: `tests/support/SoundnessFixtures.st` (the late-edge
shapes, the seeded random snapshot+root generator over
`DomainGenerators`/`PARLEY_SEED`, and the post-hoc soundness checker),
`tests/laws/SoundnessTest.st`, `tests/laws/PinVerificationTest.st`, and
`tests/acceptance/Sprint3AcceptanceTest.st` (S1–S13, traceability gate
verified by `wrap-sprint.sh 3 5`).

## Ambiguities and their resolution

All test-defined protocol points were posted as 11 numbered decisions on
issue #5
(https://github.com/leocamello/parley/issues/5#issuecomment-5015683267)
during RED and approved at the Gate A review before GREEN began. The one
substantive ruling: **the S2 fixture amendment** — with the issued Given
(`a` {2.0.0} only) both domains tie at 1, the smallest-domain
tie-break's alphabetical rule decides `a` before `b`, and the failure
surfaces as a bare `#noVersions` leaf with no `#decision` node anywhere
in the cause tree, making the issued Then unsatisfiable by any sound
implementation. Amended Doc C §7 requires the late edge to land on an
*already-decided* package (docs win), so the unsatisfiable shape keeps
both `a` versions, each depending on `b` `'^1.0'`. The reviewer
re-derived the analysis independently, approved the amendment, and
edited the issue body's S2 Given to match. Also ruled at review:
`ApplicationManifest` ships without `=`/`hash` this sprint (value
equality would drag the settled `LibraryManifest` into scope).

Declared red-phase passes (regression guards on settled bytes, like
Sprint 2's index-path guard): `testS6_soundResolutionsAreUndisturbedByPins`
and `SoundnessTest>>testPinsLeaveSoundOutcomesByteIdentical` pin the
Sprint 2 S16 lockfile bytes byte-for-byte — GREEN left them untouched,
proving pins never alter already-sound outcomes.

No new ambiguity surfaced during GREEN; the implementation followed the
approved decisions exactly. Soundness landed first and alone: after only
the `Incompatibility`/`BacktrackingStrategy` changes the run was
`passed=217 failed=0 errors=16` with every remaining error an MNU on the
three not-yet-built surfaces.

## Verification

From `.parley_verification_audit`:

```
sprint: 3
date: 2026-07-19T16:32:47Z
toolchain: GNU Smalltalk version 3.2.5
PARLEY-SEED: 20260718
PARLEY-VERIFY: PASS seed=20260718 run=233 passed=233 failed=0 errors=0
```

Toolchain: `gst --version` → `GNU Smalltalk version 3.2.5`

233 tests green: the 203 Sprint 0–2 suites (untouched) plus
`SoundnessTest`, `PinVerificationTest` and `Sprint3AcceptanceTest`
(S1–S13). The randomized post-hoc soundness law runs 200 seeded cases
per suite (plus the two fixed late-edge shapes as a deterministic
prefix); two consecutive `--seed 20260718` runs produced bit-for-bit
identical harness output.
