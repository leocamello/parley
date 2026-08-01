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
snapshot                                 "the immutable IndexSnapshot of §2"
```

`versionsOf:` and `manifestFor:version:` feed resolution; `fetch:version:` is forbidden during resolution (metadata/archive split). `snapshot` is the source's **one I/O moment**: it reads all metadata once and answers the immutable `IndexSnapshot` value that resolution consumes — after it answers, the source is out of the loop until install time.

### 1.1 `DirectorySource` (the first real source)

A directory of index-entry files, read entirely at `snapshot` time:

- **Layout:** each `.st` file in the directory holds exactly one `#'parley-index' 1` artifact, parsed by `IndexEntryReader` — never the compiler. Package identity (name, version) comes from the **entry contents, not the filename**; the `<name>-<version>.st` naming convention is recommended layout, never load-bearing.
- **Determinism:** files are read in sorted-filename order. Same directory contents ⇒ identical snapshot ⇒ byte-identical lockfile (§7).
- **Hashes:** a release's `sha256` is taken from the entry's `#archive` field (`#(<file> #sha256 '<hash>')`); an empty `#archive #()` — today's `IndexEntryWriter` output — yields `''`, exactly the `IndexSnapshot` "absent" convention. Real hashing arrives with the installer/publish work.
- **Errors:** problems are batched into one `SourceError` (the `ManifestError problems` style — a `problems` array of human-readable strings in sorted-filename order): a file that does not parse as a literal artifact (carrying the reader's positioned reason), a file whose artifact is not a `#'parley-index' 1` entry, a duplicate (name, version) across files, a **§5.2 schema-shape violation** (Sprint 7, closing the Sprint 4 ruled gap — full contract in [publish-and-sources.md](publish-and-sources.md) §4), or a missing/unreadable directory. A directory that scans clean but empty answers an empty snapshot — resolution then fails as an ordinary `#noVersions` `ConflictReport`, a value, never a source error.
- **Fetch:** `fetch:version:` answers the raw bytes of the archive file named by the entry's `#archive` field, resolved relative to the source directory; problems (unknown (package, version), `#archive #()`, missing/unreadable archive file) signal a one-problem `SourceError` — full contract in [installer.md](installer.md) §1.1 (this was a stub through Sprint 4). The metadata/archive split holds by construction: resolution consumes the snapshot value, so the fetch path cannot be touched mid-resolution.

## 2. The Snapshot & Purity Contract

Before resolution begins, sources answer an **immutable index snapshot**: an in-memory value mapping package → available versions → dependency lists (constraints already parsed to `VersionConstraint`s). The `Resolver` is then a **pure function** of (root manifest, snapshot):

- Zero live I/O mid-resolution.
- Same inputs ⇒ identical output, always (tested: byte-identical lockfile).
- Tests exercise the resolver with hand-built in-memory snapshots — no filesystem, no network.

Resolution answers exactly one of two **values** (never search-loop exceptions):

- `Resolution` — the flat concrete set: `(package, version, sha256)` triples. Feeds `IndexEntryWriter>>writeLock:on:` and the `Installer`.
- `ConflictReport` — wraps the root `Incompatibility` of the failure's derivation tree.

The strategy seam: `Resolver strategy: BacktrackingStrategy new`. A future `PubGrubStrategy` must be an additive swap — this doc's value objects (`Term`, `Incompatibility`) are PubGrub's clauses; only the loop changes.

### 2.1 Retirement lives in the snapshot, and the resolver never learns about it (Sprint 10)

A retired release (Doc B §5.5) must be invisible to fresh resolution and still reachable for an existing lock. Both fall out of the snapshot's existing shape with **zero resolver change**, and that is the point — the resolver stays a pure function of (root manifest, snapshot), unaware that retirement exists:

- `versionsOf:` **excludes** retired versions. The resolver selects only from what it is offered, so a retired release is never picked, never appears in a conflict derivation, and needs no special case anywhere in the search loop.
- `dependenciesOf:version:` and `sha256For:version:` **still answer** for a retired release. A lock that already pins one verifies and installs exactly as before.
- `retirementReasonFor:version:` answers the author's reason, or `nil` — carried so consumers can surface it, and used by nothing inside resolution.

Adding a kind-check to the resolver would have been the obvious implementation and the wrong one: it would put a policy decision inside a pure search, and every future strategy would have to reimplement it. Filtering at the snapshot means `PubGrubStrategy` inherits retirement semantics for free.

**Not yet surfaced to consumers, deliberately.** Telling an operator that a *pinned* dependency has been retired requires reading the index on the `install` fast path — and Doc E §4.1's settled law says that path must complete **without consuming the source's snapshot**, proved by a snapshot-signaling source double. Retirement reporting therefore belongs with a verb that is allowed to consult the index (the deferred `parley check`), not to `install`. Sprint 10 delivers the schema and the resolution semantics; a retired release is observable through `update` and fresh `resolve`, where the snapshot is consumed anyway.

### 2.2 Held pins live in the snapshot too, and the resolver never learns about them either (Sprint 12)

Selective `parley update <pkg>` moves one package and leaves the rest of the lock where it is. The obvious implementation — teach the resolver about "pinned" packages — is the wrong one for the reason §2.1 already gives: it puts policy inside a pure search and every future strategy reimplements it. The right one is the same trick, applied a second time.

- `IndexSnapshot>>holding: aDictionary` (name → `Version`) answers a **new** snapshot in which `versionsOf:` offers, for every held name, exactly the held version — and nothing else. Unheld packages are unaffected. The receiver is unchanged: structural immutability, an operation answering a new instance (Architecture §1.5).
- Everything else answers as before. `dependenciesOf:version:` and `sha256For:version:` are untouched, because a held pin must still describe itself.
- The `Resolver`, `BacktrackingStrategy` and `ConstraintLedger` are **not modified and not entered differently**. `update <pkg>` resolves the ordinary way against a narrower snapshot; a selective update is a normal resolution of a smaller world.

**A held pin outranks a retirement.** When a held version is also retired, the snapshot offers it anyway — narrowing wins. This looks like a conflict between §2.1 and this section and is not: `versionsOf:`'s retirement filter answers "what may a *fresh* resolution pick", and a held pin is not being picked, it is being *kept*. The precedent is exactly decision 37's second half — an existing lock keeps installing a retired release, because excluding it from fresh resolution was never meant to strand a project that already depends on it. A selective update is, for every package it does not name, closer to `install` than to `resolve`. The verb that tells an operator a pin has been retired is `check` (Doc E §4.1), which exists for that purpose and reports it as a problem; failing an unrelated `update kernel-a` because `kernel-b`'s pin was retired last week would blame the wrong package for the wrong thing.

**Provenance stays at the CLI, not in the ledger.** When holding the rest makes the named package unmovable, the resolver answers an ordinary `ConflictReport` about a world with few candidates — truthful, but silent about *why* the world was small. The missing sentence is supplied by the verb, not by a new `Term` kind: Doc E §4.1's `update <pkg>` prepends one line naming that the other pins were held and that `parley update` moves everything. Blame belongs at the boundary that had the context — the same placement as decisions 31, 35, 42 and 44.

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

**Decision pins — the soundness invariant (§8 decision 22; ruled on issue #4).** Deciding `pkg → v` records a positive exact-pin term (`pkg` = `v`, origin: that decision's `#decision` incompatibility, §3) into the descent ledger copy, before the candidate's dependency edges. An edge met later that contradicts an already-decided package therefore empties that package's accumulation and surfaces as an ordinary `recordTerm:` collapse whose provenance holds the pin and the offending edge. Decisions and derivations share one ledger: a `Resolution` can never violate a recorded edge, the search loop contains no soundness re-check branches, and backtracking discards pins with the ledger copy.

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
- **Retirement (§2.1, Sprint 10):** a snapshot built with a retired release omits that version from `versionsOf:` while `dependenciesOf:version:` and `sha256For:version:` still answer for it (the two halves of "excluded from fresh resolution, still fetchable", asserted together); a resolution over a snapshot whose highest version is retired selects the next lower one **and the resolver is unchanged** — proved by resolving the same shape against a hand-built snapshot with that version simply absent and asserting the identical `Resolution`; retiring every version of a required package answers a `ConflictReport`, never a crash; `retirementReasonFor:version:` answers the author's reason and `nil` for a live release; and a snapshot with no retirements is byte-identical in behavior to a pre-Sprint-10 one (declared regression guard).
- **`DirectorySource` (§1.1):** a real directory of entry files snapshots correctly (versions, parsed constraints, hashes); malformed/mis-tagged/duplicate entries batch into one `SourceError` in sorted-filename order; a snapshot is a sealed value — files added after `snapshot` answers do not change it; end-to-end: directory → resolve → lockfile bytes on disk, byte-identical across runs and equal to the hand-built-snapshot result for the same shape.
