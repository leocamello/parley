# Parley Design — Purity, Provenance & The Backtracking Resolver

> **Scope:** `PackageSource` protocol, index snapshots, `ConstraintLedger` / `ConstraintAccumulation`, `Term` / `Incompatibility` behavior, `BacktrackingStrategy`, `Resolution` / `ConflictReport`, and the lockfile fast path. All classes in the `Parley` namespace; structural immutability applies throughout (the ledger produces new accumulation values; see §4.3).

---

## 1. `PackageSource` (polymorphic sources — Cargo's `Source` model)

The resolver never knows where packages live. Protocol, implemented by `DirectorySource`, `GitIndexSource`, `RegistrySource`:

```smalltalk
versionsOf: aPackageName                 "collection of Version"
manifestFor: aPackageName version: aVersion
    "index-entry data (via IndexEntryReader) — NEVER a Package.st evaluation"
fetch: aPackageName version: aVersion    "archive retrieval — install time ONLY"
```

`versionsOf:` and `manifestFor:version:` feed resolution; `fetch:version:` is forbidden during resolution (metadata/archive split).

## 2. The Snapshot & Purity Contract

Before resolution begins, sources answer an **immutable index snapshot**: an in-memory value mapping package → available versions → dependency lists (constraints already parsed to `VersionConstraint`s). The `Resolver` is then a **pure function** of (root manifest, snapshot):

- Zero live I/O mid-resolution.
- Same inputs ⇒ identical output, always (tested: byte-identical lockfile).
- Tests exercise the resolver with hand-built in-memory snapshots — no filesystem, no network.

Resolution answers exactly one of two **values** (never search-loop exceptions):

- `Resolution` — the flat concrete set: `(package, version, sha256)` triples. Feeds `IndexEntryWriter>>writeLock:on:` and the `Installer`.
- `ConflictReport` — wraps the root `Incompatibility` of the failure's derivation tree.

The strategy seam: `Resolver strategy: BacktrackingStrategy new`. A future `PubGrubStrategy` must be an additive swap — this doc's value objects (`Term`, `Incompatibility`) are PubGrub's clauses; only the loop changes.

---

## 3. `Term` & `Incompatibility` behavior

- `Term` — `(package, VersionConstraint, isPositive)`. A positive term asserts "any selected version of P satisfies C"; a negative term asserts the complement. `negated` flips polarity.
- `Incompatibility` — an immutable set of terms that cannot all hold, plus `cause`:

| kind | `cause` | born when |
| --- | --- | --- |
| external `#dependency` | the symbol | read off an index entry: `{P@v, not (Q C)}` — "P v depends on Q C" |
| external `#noVersions` | the symbol | a package's candidate set under its accumulated constraint is empty |
| external `#decision` | the symbol | a strategy decides `pkg → v`: the single positive exact term `{pkg = v}` — the origin of that decision's pin term (§5) |
| **derived** | the parent `Incompatibility` pair/collection it was proved from | at ledger collapse or candidate exhaustion (§5) |

Derived incompatibilities form a **derivation tree** via `cause` links.

- `Incompatibility>>printOn:` renders the human sentence for this node only ("because kernel-a 1.2.0 depends on kernel-c >=1.0.0 <2.0.0 and kernel-b 2.0.0 depends on kernel-c >=2.0.0 <3.0.0, kernel-a 1.2.0 and kernel-b 2.0.0 are incompatible"). Constraints render via their canonical `printString`.
- `ConflictReport>>printOn:` walks the tree recursively — render both causes, then the conclusion. Numbered-line rendering for shared subtrees (PubGrub-style "because (1) and (3)…") is a pure presentation refinement inside `ConflictReport`; it touches nothing else and may be deferred.
- Reports are live objects: tests (and users, and the content series) send messages directly to the tree — `cause`, `terms`, `isExternal`, `isDerived`.

---

## 4. `ConstraintLedger` — Never Intersect Anonymously

### 4.1 The rule

The running constraint on a package is **never stored bare**. The ledger maps package name → `ConstraintAccumulation`, which holds (a) the running intersection and (b) the list of contributing `Term`s — who imposed what. Provenance is recorded as a side effect of normal operation; when an intersection collapses, the contributors are already in hand and the `Incompatibility` constructs itself. **The search loop contains zero explanation-flavored branches.**

### 4.2 Core protocol

```smalltalk
"ConstraintLedger"
recordTerm: aTerm
    "Answers nil on success, or an external/derived Incompatibility
     built from the accumulation's terms when the intersection collapses."
constraintFor: aPackageName    "the accumulated VersionConstraint (any if untouched)"
termsFor: aPackageName         "the contributing Terms"
undecidedPackagesGiven: aPartialAssignment

"reference shape"
recordTerm: aTerm [
    | acc |
    acc := self accumulationFor: aTerm package.
    acc := acc addingTerm: aTerm.          "answers a NEW accumulation value"
    self at: aTerm package put: acc.
    ^acc constraint isEmpty
        ifTrue: [Incompatibility conflictFrom: acc terms]
        ifFalse: [nil]
]
```

`ConstraintAccumulation` is an immutable value; `addingTerm:` answers a new accumulation with the term appended and the intersection recomputed (`constraint intersect: aTerm constraint`).

### 4.3 Copy-on-descend

Each recursion level of the strategy works on **its own ledger copy** (a fresh Dictionary sharing the immutable accumulation values; growth replaces an entry, never mutates one). **Backtracking = discarding a ledger** — literally returning from the method. No undo logs. Graph sizes in a 3.2.5 ecosystem make copy cost irrelevant; the strategy stays re-entrant and trivially testable.

---

## 5. `BacktrackingStrategy`

Deterministic backtracking DFS. Determinism knobs (both mandatory):

- **Package selection — smallest-domain-first:** among undecided packages, pick the one with the fewest allowed candidates under its current accumulated constraint; ties broken alphabetically. (Fail-fast: conflicts surface near their cause; derivation trees stay legible.)
- **Candidate order — highest version first.**

Reference shape:

```smalltalk
solveFrom: ledger solution: partial [
    | pkg candidates failures result |
    pkg := self nextUndecidedIn: ledger given: partial.
    pkg ifNil: [^Resolution from: partial].

    candidates := ((snapshot versionsOf: pkg)
        select: [:v | (ledger constraintFor: pkg) allows: v])
        asSortedCollection: [:a :b | a > b].
    candidates isEmpty ifTrue:
        [^Incompatibility noVersionsOf: pkg
             matching: (ledger constraintFor: pkg)
             blamedOn: (ledger termsFor: pkg)].

    failures := OrderedCollection new.
    candidates do: [:v |
        result := self try: pkg version: v ledger: ledger solution: partial.
        result isResolution ifTrue: [^result].
        failures add: result].
    ^Incompatibility exhausted: pkg
         blamedOn: (ledger termsFor: pkg)
         causes: failures
]
```

`try:version:ledger:solution:` copies the ledger, records **first the decision pin, then** the dependency terms of `pkg@v` from the snapshot (each via `recordTerm:`), answers the first collapse `Incompatibility` if any, and otherwise recurses with the extended partial assignment.

**Decision pins — the soundness invariant (master plan §8 decision 22; ruled on issue #4).** Deciding `pkg → v` records a positive exact-pin term (`pkg` = `v`, origin: that decision's `#decision` incompatibility, §3) into the descent ledger copy, before the candidate's dependency edges. An edge met later that contradicts an already-decided package therefore empties that package's accumulation and surfaces as an ordinary `recordTerm:` collapse whose provenance holds the pin and the offending edge. Decisions and derivations share one ledger: a `Resolution` can never violate a recorded edge, the search loop contains no soundness re-check branches, and backtracking discards pins with the ledger copy.

**Conflict lifecycle:** external incompatibilities are born at collapse points and empty candidate sets *on the way down*; a **derived** incompatibility is born at each exhaustion point (all candidates for a package failed), merging the per-candidate failures. **The unwind carries finished values; it never computes explanations.**

**No backjumping in the MVP.** The provenance data already supports it (every incompatibility knows which assignments it blames) — that's the sign the design is right — but chronological backtracking is easier to verify, and backjumping's benefit region coincides with the `PubGrubStrategy` swap.

---

## 6. Lockfile Fast Path

Default invocation flow for `parley install`:

1. Lockfile present and manifest unchanged → **verify pins**: each locked `(package, version)` still satisfies the manifest's constraints and hashes match the cache. No resolution.
2. Manifest changed or `parley update` → full resolution against a fresh snapshot; on `Resolution`, write the lockfile (byte-stable; [manifest-and-serialization.md](manifest-and-serialization.md) §5.3–5.4).
3. On `ConflictReport` → render the narrated proof; exit nonzero; never write a lockfile.

## 7. SUnit Requirements for This Doc

- Determinism: same snapshot + manifest ⇒ identical `Resolution`, byte-identical lockfile (run twice, compare bytes).
- Diamond dependency: A→C `^1.0`, B→C `^2.0` with a satisfiable shape resolves; unsatisfiable shape answers a `ConflictReport` whose root blames both edges.
- Backtracking: a snapshot where the greedy highest-first pick fails but a lower version succeeds MUST resolve (proves backtracking exists).
- Smallest-domain-first: a snapshot constructed so selection order is observable in the derivation tree.
- Ledger: `recordTerm:` answers `nil` then an `Incompatibility` on collapse; accumulations are fresh values (parent ledger unaffected — copy-on-descend proof).
- Derivation-tree inspection: walk a real failure via `cause` links; assert external leaves and derived internal nodes; snapshot the rendered narration.
- Purity: resolver runs against a hand-built in-memory snapshot with no filesystem or process access.
- **Soundness (decision pins):** a late edge constraining an already-decided package MUST collapse — the recoverable shape backtracks to a compatible candidate; the unsatisfiable shape answers a `ConflictReport` whose external leaves include the `#decision` node. **Randomized post-hoc law:** every answered `Resolution` satisfies the root manifest's constraints and every dependency edge of every selected version (seeded generated snapshots).
