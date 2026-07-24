# Sprint 2 Notes — The Pure Resolution Engine

## What was built

`src/resolver/` (all classes in the `Parley` namespace, class-side
construction, private `set...` initializers, zero public setters):

- **`Term`** — immutable (package, constraint, isPositive) clause atom;
  `negated`; `=`/`hash` on the three value fields only (`origin` — the
  Incompatibility that imposed the term — is provenance and excluded);
  narration phrase renders exact pins as bare versions.
- **`Incompatibility`** — immutable terms + cause. External constructors
  `package:version:dependsOn:constraint:` (#dependency edge) and
  `noVersionsOf:matching:blamedOn:`; derived constructors
  `conflictFrom:` (ledger collapse; cause = the contributing terms'
  origins, conclusion drawn from the causes' positive terms) and
  `exhausted:blamedOn:causes:`. `printOn:` renders the canonical Doc C §3
  single-node sentence.
- **`ConstraintAccumulation`** — immutable; `addingTerm:` answers a new
  accumulation with the intersection recomputed and the term appended.
- **`ConstraintLedger`** — the Doc C §4.2 reference shape. `recordTerm:`
  answers nil while satisfiable, the collapse Incompatibility with full
  provenance when an accumulation empties (hard ban 6: no bare
  constraint is ever stored). `copy` is copy-on-descend: own dictionary,
  shared immutable accumulation values.
- **`IndexSnapshot`** — the approved concrete immutable snapshot
  receiver; `releases:` builds from hand-written tuples; `versionsOf:`,
  `dependenciesOf:version:`, `sha256For:version:` ('' when absent).
- **`Resolution`** — the flat (package, version, sha256) success value +
  root manifest name; `isResolution` true; `packageNames` sorted;
  `=`/`hash` together.
- **`BacktrackingStrategy`** — the Doc C §5 reference shape:
  smallest-domain-first (ties alphabetical), candidates highest-first,
  copy-on-descend ledgers, external incompatibilities born on the way
  down, derived at collapse/exhaustion, the unwind carries finished
  values only. Zero I/O, zero exceptions, zero explanation branches. No
  backjumping (deferred; the provenance data supports it).
- **`Resolver`** — the pure function. `Resolver strategy:` seam; root
  manifest dependencies enter the ledger as initial terms whose origins
  are root #dependency edges; failure roots are wrapped in a
  `ConflictReport`.
- **`ConflictReport`** — wraps the derivation-tree root; delegates the
  node protocol (`cause`/`terms`/`isExternal`/`isDerived`);
  `isResolution` false; `printOn:` narrates the proof — post-order over
  derived nodes, causes before conclusions, one sentence per line, no
  trailing newline.

`src/manifest/` (the one declared exception — the pair owns both
schemas per Doc B §7):

- **`IndexEntryWriter class >> writeLock:on:`** — canonical
  `#'parley-lock' 1` bytes: `#root`, then `#packages` sorted by name,
  each `#(name version #sha256 hash)`, single-line, single trailing
  newline. Byte-stable.
- **`IndexEntryReader`** — `validateTagOf:` now accepts both
  `#'parley-index' 1` and `#'parley-lock' 1`; the unsupported-version
  error names the offending version (e.g. `99`); the index-entry path
  is byte-identical (all Sprint 1 MicroFormat pins stayed green).

## Ambiguities and their resolution

All protocol points Doc C leaves open were posted as 12 numbered
decisions on issue #4
(https://github.com/leocamello/parley/issues/4#issuecomment-5013816467)
during RED and approved by the human reviewer before GREEN began —
notably: `Term` origin excluded from equality, the four
`Incompatibility` constructors, the exact narration grammar and the
pinned S12/S15 three-line proof, `ConflictReport` root delegation,
`Resolution` accessors carrying the root name for `#root`,
`IndexSnapshot releases:` tuples, `undecidedPackagesGiven:` over a
name→Version dictionary, and the `FetchTrapSnapshot` purity double.
GREEN implemented those decisions exactly; no new ambiguity surfaced.

One reviewer amendment landed with the phase flip (commit 5e0ab55):
the unsupported-lock-version rejection test requires the error message
to name the version ('99') so it cannot pass via the unknown-tag path —
honored by threading the tag and version into the reader's message.

Noted, not built (outside every scenario and the Doc C reference
shape): a dependency edge that constrains an *already-decided* package
without collapsing its ledger accumulation is not detected as a
conflict. If a later sprint's scenarios reach that shape, it needs a
design ruling on issue #4 first.

## Verification

From `.parley_verification_audit`:

```
sprint: 2
date: 2026-07-19T02:42:00Z
toolchain: GNU Smalltalk version 3.2.5
PARLEY-SEED: 20260718
PARLEY-VERIFY: PASS seed=20260718 run=203 passed=203 failed=0 errors=0
```

Toolchain: `gst --version` → `GNU Smalltalk version 3.2.5`

203 tests green: the 148 Sprint 0–1 suites plus the Sprint 2 law suites
(`TermIncompatibilityTest`, `ConstraintLedgerTest`, `ResolverTest`,
`LockfileFormatTest`) and `Sprint2AcceptanceTest` (S1–S17, traceability
gate verified by `wrap-sprint.sh 2 4`). Reruns with `--seed 20260718`
are bit-for-bit repeatable.
