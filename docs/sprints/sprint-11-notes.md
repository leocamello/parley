# Sprint 11 — the inspection verbs, `SchemaShape`, and the hex-digest grounds

**Issue:** #13 · **Spec of record:** Doc E (`docs/design/execution-and-cli.md`) §4.1/§4.2/§5, with Doc B §5.3/§7.1 and Doc F §4 · **Decisions:** §8 40–43, plus the correction to 38.

## What was built

- **`Parley.SchemaShape`** (`src/manifest/SchemaShape.st`, new) — the shared value
  predicates of the schema validators, class-side and stateless: `isString:`,
  `isStringArray:`, `isHexDigest:`. Built first and alone; both settled private
  copies (`CLI>>isLockString:`, `DirectorySource>>isSchemaString:`/
  `isSchemaStringArray:`) were deleted in the same increment, with S12's
  `includesSelector:` law proving the deletion, not just the bypass.
- **Hex-digest validation at both boundaries** (§8 decision 42):
  - Lock side: `CLI>>lockValueProblemIn:` gains a digest ground after the settled
    version check (the ordering carried from the review), via the new private
    `isLockDigest:` — 64 lowercase hex **or the empty string**, `''` being
    recorded absence per the amended Doc B §5.3 ("the exemption is for absence,
    not laxity"). The digest row was folded into
    `LockSchemaFixtures malformedLockRows` (the carried item), so the settled
    row-walk law now owns the ground.
  - Entry side: `DirectorySource>>valueProblemIn:` gains
    `archiveDigestProblemIn:` — a shape-valid, non-empty `#archive` digest must
    be strictly 64 lowercase hex; `#()` carries no digest string, so absence
    needs no exemption there. Batched and sorted with the scan's other problems.
- **`parley check`** — the verb spelling of the pin fast path: missing lock
  (pinned resolve-repair line, exit 1), invalid lock (the settled `LockError`
  boundary), `PinVerification` problems as lines, and **retirement finally
  reaching a human** — Sprint 10's unread `retirementReasonFor:version:` is now
  read, the author's reason travelling verbatim (decision 37 discharged).
  Healthy is one pinned confirmation line at exit 0.
- **`parley tree`** and **`parley why <pkg>`** — the graph comes from the **lock
  plus the snapshot** (§8 decision 40): root edges from the manifest, all other
  edges from the settled `IndexSnapshot>>dependenciesOf:version:`. The resolver
  is never entered — S9 proves it with a `resolveAndLock:` trap double on the
  real path, and the trap-correctness guard proves the trap springs when
  `resolve` runs. `tree` renders root-down, two-space indents, children sorted,
  repeats marked and not re-expanded; `why` renders every root→target chain,
  each hop naming the demanding constraint, chains sorted and byte-stable.
- **The drift law hardened** (§8 decision 43): the sender walk is parameterized
  (`readerSenderFileNamesUnder:subdirectories:`, with the settled selector
  delegating to it) and matches over `normalizedCodeOf:` — comments and string
  literals stripped, then every whitespace run collapsed to one space — so a
  send split across a line break is still a sender. The claim is **bounded in
  writing** per the decision-38 correction: a textual search, hardened against
  whitespace, nothing stronger.
- `CLI` dispatch gained the three argv rows (`why` size-2 + source, `tree`/
  `check` size-1 + source); the usage `verbs:` line was extended and
  `ExecFixtures usageLines` re-pinned (the sanctioned extend-not-replace).

## Verification evidence

From `.parley/audit` (wrap re-run):

```
sprint: 11
date: 2026-08-01T23:07:44Z
toolchain: GNU Smalltalk version 3.2.5
PARLEY-SEED: 20260718
PARLEY-VERIFY: PASS seed=20260718 run=585 passed=585 failed=0 errors=0
```

Toolchain, exact: `GNU Smalltalk version 3.2.5`; `gst-package - GNU Smalltalk
version 3.2.5`.

RED baseline (issue #13 review): `FAIL run=585 passed=545 failed=28 errors=12`
— 545 = 541 settled + the 4 declared passes-in-red, checked test-by-test at
the operator review. GREEN took three verifier runs total across the sprint:
the RED gate, one failure (spin 1/3 — `Array class` in 3.2.5 has no six-way
`with:`, hit by the digest row joining `malformedLockRows`; fixed by splitting
the literal into a third concatenated group), then PASS 585/585.

## Ambiguities hit and how they were resolved

- **`why`/`tree` on a missing lock** is specified nowhere (S3 covers a package
  absent from an existing lock; only `check` had a missing-lock scenario).
  Resolved without new wording: both answer the same pinned
  `parley.lock is missing - run parley resolve to write it` line at exit 1 —
  the graph comes from the lock, so without a lock there is no graph to
  inspect, and the repair for absence is resolve, not update. Flagged here for
  the close-out rather than halting, as it reuses a reviewed wording and
  invents no new one.
- **Multiple value defects in one lock** (`lockValueProblemIn:` ordering):
  resolved per the review's carried ruling — all version checks run before any
  digest check, so the settled version wording can never be shadowed.
- **`check` with both stale pins and retirements**: no scenario covers the
  combination. The verb batches — `PinVerification` problems first, then
  retirement lines in pinned-name order — because `check` exists for CI and a
  first-problem-only answer would hide the rest. S6/S7 each exercise one kind.
- Operator amendments at the RED review (recorded on issue #13): the
  `hexDigestCorpus` precedence defect (four rows silently lost to a binary
  comma binding tighter than `with:`; fixed operator-side), and the Q1 64-hex
  amendment of ~30 settled placeholder digests, applied in RED so the change
  was provably inert. Q2 (`''` accepted at the lock boundary) was confirmed
  and both docs amended before the flip.

## Operator amendments during GREEN

None. The three carried items (digest row folded into `malformedLockRows`,
version-before-digest ordering, `usageLines` re-pin) were implemented as ruled.

## Noted, not built

- **Reflective sender enumeration** — ruled out by the corrected decision 38:
  `whichSelectorsReferTo:` searches literals, not sends, on 3.2.5. The drift
  law stays textual with its claim bounded; a send assembled by `perform:` or
  split by an interleaved comment stays invisible to it.
- **Lock-problem batching** (one problem per lockfile stands), a **prebuilt
  image**, and **`--git` cache pruning** — the three carried gaps, deliberately
  left with their triggers stated on issue #13.
- **`parley add`**, **selective `parley update <pkg>`**, a **`retire` verb**,
  un-retiring, `RegistrySource`/hosting/signing, prereleases, backjumping,
  `PubGrubStrategy`, network git — all deferred per `docs/roadmap.md` §3.
- **`why`/`tree`/`check` without `--source`** answer usage: the retirement leg
  of `check` and the non-root edges of both graphs need a snapshot. A
  source-less `check` (lock validity + `PinVerification` only) would be a
  weaker verb with the same name — left unbuilt rather than half-built.
- **A `PinnedGraph` object** — the walk lives in `CLI` private methods beside
  the settled verb plumbing. If a fourth verb ever wants the graph, extracting
  a value object is the natural move; today it would be a class with one
  caller.
- `ExecFixtures usageLines`' stale "two lines" comment was corrected as part
  of the sanctioned re-pin.
