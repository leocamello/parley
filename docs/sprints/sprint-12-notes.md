# Sprint 12 — selective `parley update <pkg>`: move one, hold the rest

**Issue:** #14 · **Spec of record:** Doc C (`docs/design/resolver.md`) §2.2 with Doc E (`docs/design/execution-and-cli.md`) §4.1/§5 · **Decisions:** §8 45–47 (46 built on the precedents 37, 40 and 44; 47 ruled by the operator at the red review).

## What was built

- **`IndexSnapshot>>holding:`** (`src/resolver/IndexSnapshot.st` — the first
  declared settled-class exception) — a derivation answering a **new** narrowed
  snapshot over the shared immutable release/retirement records (the held map is
  copied on the way in). For a held name, `versionsOf:` offers exactly the held
  version; everything else about the receiver's behavior is unchanged, and the
  receiver itself is never mutated (Architecture §1.5, asserted by law). The
  filter lives in the accessor, exactly where Sprint 10 put retirement
  (§8 decision 37 applied a second time):
  - **Held beats retired** (§8 decision 46): a retired held version is offered
    anyway — the §2.1 filter answers what a *fresh* resolution may pick, and a
    held pin is being kept, not picked. The retirement reason still answers
    through the narrowing, so `check` keeps reporting it.
  - **Bounded by describability** (§8 decision 47, operator amendment): a held
    version the snapshot holds **no record for** is offered as nothing at all —
    offering it would let `update` write a lock tuple with an empty digest,
    manufacturing the corruption `check` exists to catch. The describing
    accessors (`dependenciesOf:version:`, `sha256For:version:`,
    `retirementReasonFor:version:`) are untouched in both directions.
- **`CLI>>update:`** (`src/exec/CLI.st` — the second declared exception) — the
  verb: read the pins through the settled Sprint 9 lock boundary, hold every
  pin **except** the named one, resolve the **ordinary way** (the settled
  `Resolver strategy: BacktrackingStrategy new` seam, consumed unchanged — no
  strategy, ledger or `Term` change anywhere) against `source snapshot
  holding: held`, rewrite the lock byte-stably, then install + register through
  the settled `installResolution:` tail. Pins that did not move are
  byte-identical, tuple by tuple.
  - **The three diagnoses, all exit 1:** no lock (the settled inspection-verb
    line — the repair is `resolve`, the verb that writes a *first* lock); not
    pinned (one line, the `why` precedent and the `why` wording); and held pins
    making the move impossible — the pinned held-pins sentence **prepended** to
    the settled `ConflictReport` narration, unmodified (provenance stays at the
    CLI, §8 decision 46). A conflict writes nothing.
  - **Already newest** is a success with its own pinned line, exit 0, the lock
    rewritten to identical bytes; install + register still run behind it, so
    the verb's install contract is unconditional.
  - **Grammar:** `update [<pkg>]` — the 2-element row dispatches only with a
    source wired; wrong arity and the sourceless row answer the pinned usage
    lines at exit 2, whose `verbs:` line now renders `update [<pkg>]`.
    `ExecFixtures usageLines` and `InspectionFixtures usageVerbsLine` were
    re-pinned in the same increment as the CLI usage change (the Sprint 11
    precedent, sanctioned at the red review). `CommandLine` gained nothing.
- **Tests** — `tests/support/SelectiveUpdateFixtures.st` (the two-movable-tools
  index with true digests, the S8 held-conflict index, the S10 retired-held
  index, lock oracles, the narrowing input helper, the registration-plan
  oracle, and every pinned wording); `tests/laws/SelectiveUpdateTest.st` (11
  verb laws); four narrowing laws in `tests/laws/RetirementTest.st` (where the
  `versionsOf:` filter laws already live — including the operator-amended
  describability law); `tests/acceptance/Sprint12AcceptanceTest.st`
  (`testS1_`–`testS12_`). The S2/S8/S10 **contrast halves** run plain `update`
  against the identical fixture and require the different outcome — a proof
  that cannot fail proves nothing.

## Verification evidence

```
sprint: 12
date: 2026-08-02T21:19:53Z
toolchain: GNU Smalltalk version 3.2.5
PARLEY-SEED: 20260718
PARLEY-VERIFY: PASS seed=20260718 run=612 passed=612 failed=0 errors=0
```

- `gst --version` → `GNU Smalltalk version 3.2.5`; `gst-package --version` →
  `gst-package 3.2.5`.
- Red gate (before amendment): `FAIL seed=20260718 run=611 passed=585
  failed=19 errors=7` — all files loading cleanly, all 26 new tests failing,
  zero passes-in-red. After the operator's amendment (the added describability
  law): `FAIL run=612 passed=585 errors=8`.
- Green transition: one intermediate run failed exactly one settled law
  (`InspectionVerbTest>>testTheUsageNamesTheInspectionVerbs`), because Sprint
  11's `InspectionFixtures usageVerbsLine` pins the same `verbs:` line the CLI
  now renders differently. Resolved by the sanctioned GREEN re-pin of that
  fixture in the same increment — the exact mechanism its own method comment
  describes. Final run: `PASS run=612 passed=612`.

## Ambiguities hit and how they were resolved

- **Held-beats-retired vs the §2.1 filter** read as a contradiction while the
  law was written, exactly as the kickoff predicted. Resolved by Doc C §2.2's
  own text (picked vs kept), not in code; no question needed.
- **Does already-newest still install?** Doc E §4.1 pins the line, the exit
  code and the byte-identical rewrite but does not forbid the pipeline. Built
  as: the pipeline runs unconditionally (the verb's install contract stays
  whole), and only the *report* becomes the single pinned line. The tests
  deliberately do not forbid the pipeline, so this is implementation freedom,
  recorded here.
- **The S8 fixture shape** — the held-conflict index deliberately does not
  publish `app-x 1.0.0` (the index moved past the lock), otherwise the resolver
  would backtrack to it and succeed instead of conflicting. Posted at the red
  review and approved; it is also the state decision 47 generalizes.

## Operator amendments

- Doc E's `run:` grammar line brought up to `update [<pkg>]` and the exit-2
  list gained wrong arity (staleness fix).
- **§8 decision 47**: narrowing offers a held version only when the snapshot
  holds a record for it — locked in by
  `testHoldingOffersNothingForAVersionTheSnapshotCannotDescribe` in
  `RetirementTest`, landed with the Doc C §2.2 paragraph in commit `1b7bd09`.

## Noted, not built

- **A precise diagnosis for a deleted held pin** (the operator's carried gap,
  unscheduled): under decision 47 a held pin the index no longer publishes
  narrates as an ordinary version conflict (held-pins line + `ConflictReport`,
  exit 1) — sound, but it reads as a version conflict when the real defect is
  a missing index entry. Naming it precisely is a fourth diagnosis on the
  verb, i.e. a contract change; left for Gate B ranking / Gate C scheduling.
- **Selective downgrade** (`--to <version>`), **updating the root itself**, and
  **`parley add`** (needs a ruling on machine-editing `Package.st`) — all
  explicitly out of scope on issue #14; nothing in this sprint forecloses
  them: `holding:` takes an arbitrary name→version map, so a future `--to`
  is a caller-side change.
- The already-newest report swallows the pin lines; if an operator ever wants
  both the confirmation and the pin listing, that is a wording re-pin, not a
  mechanism change.
