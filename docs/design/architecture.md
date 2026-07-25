# Parley — Architecture

> *Smalltalk packages, resolved by conversation.*

**Status:** Canonical. This document is the system-wide blueprint. Where code or discussion disagrees with this document, this document wins until it is amended. Detailed component specifications live in the three design documents ([domain-model.md](domain-model.md), [manifest-and-serialization.md](manifest-and-serialization.md), [resolver.md](resolver.md)); this document defines the system and its invariants.

**Project:** Parley — a modern, native command-line package manager for GNU Smalltalk, written entirely in Smalltalk, targeting the stable **GNU Smalltalk 3.2.5** baseline. CLI verbs: `parley init`, `parley install`, `parley resolve`, `parley update`, `parley exec`, `parley publish`.

---

## 1. Core Philosophy & Engine Hygiene

### 1.1 The Moat

The hero of this codebase is the idea of **live objects, clean message passing, and refactor-as-you-think**. Every part of the dependency pipeline is an independent domain object answering messages. There are no centralized procedural scripts, no "manager" god-objects, and no glue code that reduces the domain to data shuffled between functions. When logic grows conditional branches on the *kind* of thing it handles, that is the signal to introduce polymorphism, not more branching.

Parley is a self-contained, object-shaped domain. It depends only on the GNU Smalltalk 3.2.5 kernel and the bundled `gst-package` tooling. **No third-party library dependencies, ever** — including serialization libraries (see §2.4).

### 1.2 Engine Constraints (3.2.5 Reality)

Three platform facts shape the architecture and MUST NOT be fought:

1. **No in-image version isolation.** The namespace system cannot host two versions of the same class simultaneously. All dependency isolation is **process-level** (§5), never in-image. In-image version sandboxing is a platform impossibility, not an engineering challenge.
2. **Missing convenience protocol.** Methods such as `ifEmpty:` / `ifEmpty:ifNotEmpty:` do not exist on 3.2.5 collections. They are supplied via the compatibility layer (§1.3), never via scattered verbose workarounds.
3. **No STON or modern serialization.** All static artifacts use the **literal micro-format** (§2.4) with a purpose-built reader. Serialization NEVER round-trips through the compiler for third-party content.

### 1.3 Open-Class Hygiene (`*parley-compat`)

Modernizing extensions to kernel classes are permitted under strict rules:

- All kernel extensions live in a single method category: **`*parley-compat`**.
- The layer is **minimal**: only methods the codebase demonstrably uses, defined once, loaded at the project entry point.
- Extensions are **defensive**: selectors match well-known ANSI/Pharo semantics exactly, so a future collision with a third-party package defining the same selector is behavior-identical.

Rationale: Parley loads third-party code into images. Extension collisions are dependency hell in its most Smalltalk-shaped form; the compat layer must never cause one.

### 1.4 Namespacing & Naming

- **All Parley classes live in the `Parley` namespace.** GNU Smalltalk namespaces are suitable for organizing our own code; they are *not* an isolation mechanism (§1.2.1).
- Kernel class names are never shadowed. In particular, the contiguous version span class is **`VersionRange`**, never `Interval` (a gst kernel class).
- The string `gpm` must not appear anywhere in code, categories, docs, or artifacts. The project's only name is Parley.

### 1.5 Structural Immutability

3.2.5 has no enforced immutability, so it is achieved by shape:

- **Zero public setters** anywhere in the domain model.
- All construction flows through **class-side methods** that validate and normalize before answering an instance.
- Every algebraic or transforming operation answers a **new instance**; no domain method mutates its receiver after initialization.

The single sanctioned exception is `ManifestBuilder` (§2.1) — a deliberately mutable *edge object* outside the domain model, alive only for the duration of one `Parley define:` evaluation.

---

## 2. The Manifest / Metadata Trust Architecture

Authoring is programmatic; solving is static. These are different artifacts with different trust levels.

### 2.1 Authoring: `Package.st`

Developers describe their package in an executable Smalltalk file for Mix-style ergonomics. The file's outermost expression is:

```smalltalk
Parley define: [:pkg |
    pkg
        name: 'kernel-json';
        version: '0.3.1';
        dependency: 'kernel-streams' constraint: '>=1.0 <2.0' ]
```

`Parley class >> define:` creates a fresh `ManifestBuilder`, runs the block, sends `build`, and answers an immutable manifest. The builder is a **vocabulary, validator, and serialization gateway — not a security sandbox**. The file's author owns their file and machine; nothing prevents them writing arbitrary Smalltalk in it, and nothing needs to. Full builder spec: [manifest-and-serialization.md](manifest-and-serialization.md).

### 2.2 The Trust Boundary (clarified)

> **The security boundary is the static index entry, not the builder.**

At publish time, the manifest is serialized into an immutable static **index entry** in the literal micro-format. The registry serves index entries, not manifests.

**Absolute Trust Invariant:** Parley's resolver — and every consumer of *third-party* package information — operates **exclusively on static index entries**. Third-party `Package.st` files are NEVER executed, compiled, or evaluated. Evaluating a `Package.st` is something only its own author's tooling does, on their own machine, at authoring/publish time.

**Compiler Ban:** No third-party content is ever passed to `Behavior>>evaluate:`, `Compiler`, `doIt`-style facilities, or any compilation pathway — *including* content that "looks like" a harmless literal array. Reading a static artifact by compiling it is a trust-boundary violation even when the content is expected to be literals. All static artifacts are read exclusively by the literal reader (§2.4).

### 2.3 Metadata vs. Archive (the Cargo split)

Index entries (name, version, constraints, checksum) are tiny and separate from `.star` archives. Resolution touches only index metadata; archives are fetched **after** a successful resolution, at install time, and verified by content hash.

### 2.4 The Literal Micro-Format

All static artifacts — index entries and lockfiles — are a single Smalltalk **literal array** in canonical form.

**The reader** is a purpose-built recursive-descent parser (target: ~50 lines) that accepts *only*: literal arrays `#( … )`, strings `'…'` (with `''` escaping), symbols (`#name` and `#'quoted'`), and non-negative integers, plus whitespace. **Everything else is rejected** — identifiers, floats, scaled decimals, characters, byte arrays, `true`/`false`/`nil`, comments, brace arrays, and any message-send syntax. Rejection is a parse error naming the offending token and position. The reader never delegates to the compiler (§2.2).

**Canonical rendering rules** (byte-stability — required for meaningful content hashes, diffs, and the byte-identical-lockfile test):

1. Every artifact opens with a **format tag and version**: `#'parley-index' 1` or `#'parley-lock' 1`.
2. **Fixed key order** — keys appear in the schema-defined order, always all present (empty string / empty array when unset).
3. **Dependencies sorted by package name.** (Contrast: `fileIns:` order is semantic load order and is preserved exactly — see [manifest-and-serialization.md](manifest-and-serialization.md) §"Two ordering rules".)
4. Constraints are rendered via `VersionConstraint printString` — **the canonical normal form is the wire form**. Authoring sugar (`^0.4.2`) may serialize as its expansion (`>=0.4.2 <0.5.0`); this is correct. Sugar belongs at authoring time; normal form belongs at rest.
5. Deterministic whitespace: single spaces, no trailing whitespace, single trailing newline.

Schemas, writer/reader pairing, and the round-trip law: [manifest-and-serialization.md](manifest-and-serialization.md).

---

## 3. Phase 1 — The Algebraic Domain Model

Full specification: **[domain-model.md](domain-model.md)**. System-level summary and invariants:

- **`Version`** — immutable `major.minor.patch` value object. MVP **rejects prerelease/build tags** with a clear error (prerelease ordering is deferred whole, not half-built; `Version` comparison is the single change site if revisited). `=` and `hash` are always implemented together.
- **`VersionRange`** — one contiguous span: `min`, `max`, `includeMin`, `includeMax`; `nil` bound = unbounded. Explicit open/closed bounds (half-open ranges cannot be faked with version arithmetic).
- **`VersionConstraint` (the Keystone)** — NOT a subclass hierarchy (`Exact`/`Range`/`Union` subclasses create an N×N double-dispatch matrix and undecidable equality) and not an interval tree. A **two-level normal form**:

  > **Invariant:** a `VersionConstraint` holds a sorted `Array` of disjoint, non-adjacent `VersionRange`s. All construction passes through normalization. Two constraints denoting the same version set are structurally identical.

  Closed set-algebra protocol: `allows:`, `intersect:`, `union:`, `complement`, and derived `difference:` / `isSubsetOf:`, plus `isEmpty` / `isAny`. `complement` exists from day one because PubGrub's negative terms are complements.
- **Caret semantics — Cargo-exact:** `^1.2.3` → `[1.2.3, 2.0.0)`; `^0.2.3` → `[0.2.3, 0.3.0)`; `^0.0.3` → `[0.0.3, 0.0.4)`.
- **`Term`** — `(package, VersionConstraint, isPositive)`; negation is constraint complement.
- **`Incompatibility`** — a set of Terms that cannot all hold, plus a `cause`: **external** (`#dependency`, `#noVersions`) or **derived** (cause links to parent incompatibilities). Derived incompatibilities form a **derivation tree**; **`ConflictReport`** wraps the root and renders narrated proofs via `printOn:`.
- **`LibraryManifest`** (loose constraints) vs. **`ApplicationManifest`** (environment + lockfile): the Bundler Gemfile/gemspec lesson, preventing libraries from shipping pins that deadlock the graph.

---

## 4. Phase 2 — The Pure Resolution Engine

Full specification: **[resolver.md](resolver.md)**. System-level summary and invariants:

- **`PackageSource` protocol** (Cargo's `Source` model): `DirectorySource`, `GitIndexSource`, `RegistrySource` all answer `versionsOf:`, `manifestFor:version:`, `fetch:version:`. The resolver never knows where packages live.
- **Purity contract:** `Resolver` is a pure function of (root manifest, immutable index snapshot). Zero live I/O mid-resolution. Resolution answers exactly one of two **values** — a `Resolution` or a `ConflictReport` — never hot-loop exceptions.
- **Strategy seam:** `Resolver strategy: BacktrackingStrategy new` (MVP) → `PubGrubStrategy new` later, without touching the domain model. The MVP's `Term`/`Incompatibility` objects are PubGrub's clauses; only the loop around them changes.
- **`ConstraintLedger` — never intersect anonymously.** The running constraint on a package is never stored bare; the ledger keeps the intersection *and* the contributing `Term`s. When an intersection collapses, the `Incompatibility` constructs itself from provenance the ledger already holds. **The search loop contains zero explanation-flavored branches.**
- **`BacktrackingStrategy`:** deterministic DFS. **Smallest-domain-first** package selection (fewest allowed candidates, ties alphabetical), candidates highest-first. **Copy-on-descend** ledgers — backtracking discards a ledger; there are no undo logs. Conflicts are created at collapse points on the way down and merged at exhaustion points; the unwind carries finished values. **No backjumping in the MVP** (the provenance data already supports it; the payoff belongs to `PubGrubStrategy`).
- **Lockfiles, day one:** literal micro-format, exact versions + archive content hashes. Fast path: verify pins; re-resolve only on manifest change or explicit `parley update`. Applications commit lockfiles; libraries do not ship them as constraints.

---

## 5. Phase 3 — The Orchestration Bridge

- **`Installer`** — strictly post-resolution: fetch each `.star` archive via its `PackageSource`, verify by **content hash** (content-addressed cache; integrity for free), register via the flagless `gst-package` baseline (staged under the star's true name — Doc D §4) and local `PackageLoader`. The installed set is an immutable value; switching or rolling back an environment re-points rather than mutates.
- **`ExecutionScope`** — the honest `bundle exec` for 3.2.5. Holds the resolved, content-hashed `.star` set; answers `run:` by composing and launching a **clean child `gst` invocation** with a curated package path, so only the exact resolved set is visible to that image's `PackageLoader`. The scope is a domain object: inspectable, composable, and the single home of invocation logic.
- **`CLI` / `CliResult`** — the six verbs as an orchestration that answers a **value**: the CLI never prints and never terminates the image.

## 5.5 Phase 4 — The Ecosystem (Sprint 7+)

- **`Publisher`** — manifest → toolchain-built `.star` → populated index entry, landed into a destination index. Refusal-first (releases are immutable), batched pre-flight, destination-confined staging, build fail-stop. Parley never zips: the toolchain owns the archive format (Doc F §1).
- **`GitIndexSource`** — a git checkout used as an index directory, by pure composition over `DirectorySource` plus exactly one git moment at `snapshot`. `fetch:version:` runs no git, so install-time bytes are the ones resolution saw (Doc F §3).
- **`CommandLine` and the diagnosis boundary** — the composition root of one invocation: the flag grammar, the wiring (all state derived from the *working directory*, never the process cwd), and the error boundary. **No Parley command ever answers a backtrace, and no failing command ever exits `0`.** A declared Parley error is a diagnosis at exit `1`; anything else is a defect in Parley at exit `70`, distinct so a script can tell "your input is wrong" from "the tool is broken". The boundary is a **closed set with a law**, and the shipped binary is law-guarded — glue that chooses an exit code is not glue, it is the product (Doc E §4.2/§4.3, §8 decision 30).

---

## 6. Axiomatic SUnit Testing

The algebra is tested **as laws** over randomized generated versions and constraints (hundreds of generated cases per run, **deterministic seed** for reproducibility):

1. Commutativity and associativity of `union:` and `intersect:`.
2. De Morgan: `(a union: b) complement = (a complement intersect: b complement)`, and the dual.
3. Double complement: `a complement complement = a`.
4. Absorption: `a union: (a intersect: b) = a`.
5. Identity/annihilator: `a intersect: VersionConstraint any = a`; `a intersect: VersionConstraint none = VersionConstraint none`.
6. **Normalization invariant:** after any construction or operation, ranges are sorted, disjoint, non-adjacent.
7. **Membership consistency (randomized):** for random `v`: `(a intersect: b) allows: v` ⇔ `(a allows: v) and: [b allows: v]` — the primary net for bound-inclusivity off-by-ones.
8. **Round-trip identity:** *build → serialize → read = build* — the writer/reader pair composes to the identity on manifests, proving the authoring path and resolver path converge on identical values.
9. **Literal-reader rejection:** any non-literal input MUST fail to parse with a positioned error.
10. Resolver purity and determinism: same manifest + same snapshot ⇒ identical `Resolution` and **byte-identical lockfile**.
11. Conflict-report snapshots: derivation trees render stably; tests send messages directly to failed `ConflictReport` trees.

---

## 7. Class Inventory

| Class | Phase | Role |
| --- | --- | --- |
| `Parley.Version` | 1 | Immutable `major.minor.patch`; no prereleases (MVP) |
| `Parley.VersionRange` | 1 | Contiguous span; explicit bounds; `nil` = unbounded |
| `Parley.VersionConstraint` | 1 | Keystone: normalized union of disjoint ranges; closed set algebra |
| `Parley.Term` | 1 | `(package, constraint, isPositive)` |
| `Parley.Incompatibility` | 1 | External or derived; derivation-tree node |
| `Parley.Dependency` | 1 | Name + constraint; `satisfiedBy:` delegates to `allows:` |
| `Parley.ManifestBuilder` | 1 | Mutable edge object; restricted DSL receiver for `Package.st` |
| `Parley.ManifestVocabularyError` / `ManifestError` | 1 | Live, inspectable authoring errors |
| `Parley.LibraryManifest` / `ApplicationManifest` | 1 | Loose constraints vs. environment + lockfile |
| `Parley.IndexEntryWriter` / `IndexEntryReader` | 1 | The micro-format pair; round-trip = identity |
| `Parley.PackageSource` (protocol) | 2 | `DirectorySource`, `GitIndexSource`, `RegistrySource` |
| `Parley.ConstraintLedger` / `ConstraintAccumulation` | 2 | Constraint + provenance; `recordTerm:` |
| `Parley.Resolver` | 2 | Pure function; `strategy:` seam |
| `Parley.BacktrackingStrategy` | 2 | MVP solver; future `PubGrubStrategy` |
| `Parley.Resolution` / `ConflictReport` | 2 | The two possible answers of resolution |
| `Parley.IndexSnapshot` | 2 | The sealed, immutable view of a source the resolver consumes |
| `Parley.SourceError` | 2 | Batched source problems: every rejection path of a scan is a diagnosis |
| `Parley.PinVerification` | 2 | Whether a lockfile's pins still satisfy the manifest |
| `Parley.Sha256` | 3 | Pure FIPS 180-4; the integrity primitive, vector-anchored |
| `Parley.ContentStore` | 3 | Content-addressed `<sha256>.star` cache; detection only, never self-repair |
| `Parley.Installer` | 3 | Fetch, hash-verify, register via `gst-package` |
| `Parley.InstalledSet` / `InstallError` | 3 | The immutable install product; batched install problems |
| `Parley.ProcessRunner` | 3 | **The one process seam** — the only pathway that ever creates a child process |
| `Parley.ExecutionScope` | 3 | Process-level sandbox; `run:` launches curated child `gst` |
| `Parley.ExecutionError` | 3 | Fail-stop registration failure: the command line and its exit code |
| `Parley.ManifestFile` | 3 | Loads the owner's own `Package.st` (namespace-current file-in; decision 19) |
| `Parley.CLI` / `CliResult` | 3 | The six verbs as an orchestration answering a value |
| `Parley.Publisher` / `PublishError` | 4 | Manifest → archive → entry; batched publish problems |
| `Parley.CommandLine` | 4 | The composition root: flag grammar, wiring, and the diagnosis boundary |
| `Parley.LockError` | 4 | A `parley.lock` that cannot be read — the operator's file, named as such |

---

## 8. Decision Log

1. **Target 3.2.5; extensions only in `*parley-compat`** — modernity modeled into the image, collisions contained.
2. **Manifest/metadata split** — Mix ergonomics at authoring, Cargo static determinism at solving.
3. **Static index entry = the security boundary; builder = ergonomics/validation** — no evaluation sandbox is built because none is needed.
4. **Compiler ban for third-party content** — the trust invariant holds at every layer, including "harmless-looking" literals.
5. **Literal micro-format + literals-only reader** — STON absent in 3.2.5; self-contained scoping forbids porting one.
6. **Canonical byte-stable serialization** — hashes, diffs, and lockfile determinism require it.
7. **Two-level constraint normal form** — decidable equality, no N×N dispatch, canonical printing for free.
8. **Cargo-exact caret; no prereleases (MVP)** — smallest well-defined semver surface.
9. **`complement` from day one** — the keystone must already speak negation for PubGrub.
10. **Never intersect anonymously** — provenance recorded on the way down; explanations emerge from data.
11. **Values, not exceptions, from resolution** — purity, testability, no hot-loop ceremony.
12. **Copy-on-descend backtracking** — immutable values make backtracking "return from the method".
13. **Smallest-domain-first** — deterministic, fail-fast, legible derivation trees.
14. **No backjumping in MVP** — data supports it; payoff belongs to `PubGrubStrategy`.
15. **Lockfile day one** — determinism as a product feature.
16. **Process-level sandboxing** — 3.2.5 cannot isolate versions in-image; child `gst` with curated paths is the honest `bundle exec`.
17. **Explicit DSL methods; DNU as error path only** — the manifest vocabulary is browsable API surface (senders, implementors, completion, hover docs); `doesNotUnderstand:` turns typos into rich `ManifestVocabularyError`s.
18. **Axiomatic SUnit laws** — set theory proven over generated versions.
19. **`Parley.Parley` entry-point gateway** — 3.2.5 namespaces swallow unknown keyword sends as binding setters; a shadow class inside the namespace preserves the Doc B §2 authoring syntax verbatim without any kernel extension.
20. **Single-line canonical rendering** — one artifact, one line; diffs and hashes stay meaningful.
21. **`Term` carries an equality-excluded `origin`** — provenance travels with the term without polluting its value identity.
22. **Decision pins** — the resolver records *why* a version was chosen, not only that it was; the Sprint 2 soundness gap closed in Sprint 3.
23. **`ApplicationManifest` carries no value equality** — a composition of environment and lockfile is not a value; the precedent every later composition root follows.
24. **Source-protocol unknowns are ordinary values, never errors** — "this source has no such package" is an answer, not an exception.
25. **The install-pipeline contract** — fetch → verify → store, in that order; the store never repairs itself.
26. **Name-equality MVP constraint + staged registration plan** — 3.2.5's `StarPackage` requires filename to equal internal package name, so registration stages each content-addressed archive under its true name before the flagless `gst-package --target-directory`.
27. **`RegistrySource` is deferred entirely, not stubbed** — a registry source without a registry is either a renamed `DirectorySource` or an untestable HTTP shell; it arrives with hosting.
28. **A declared settled-class exception is a *public contract* exception, not a line-count exception** — private helpers in service of a declared change need no separate declaration; new public selectors always do.
29. **Fail-stop governs the run that failed, not the run after it** — preserving a failed run's evidence must not make the next invocation non-deterministic.
30. **Glue that chooses an exit code is not glue** — the "wrapper exempt from SUnit obligations" declaration let a `src/` directory ship unreachable, so the shipped `publish` verb answered a backtrace **and exited `0`**. The exemption is withdrawn: the wiring and the boundary live in `CommandLine` with laws, and `bin/` is drift-guarded.
31. **A boundary must blame the right party** — 3.2.5's `fileIn:` signals a kernel error on a missing file, so `resolve` before `parley init` was answered with exit `70` ("a defect in Parley"). `ManifestFile` checks the path first: exit `1`, naming the verb that fixes it. Fail-wrong in its second form is a lying *attribution*, not a lying exit code.
32. **The closed-set law states what the code can support** — the second bucket is "declared undiagnosed with its ground named", not "provably never signaled out of a verb", because three classes could not meet the stronger claim. A law that asserts something untrue is the disease, not the cure. (Sprint 9 closes those escapes and the strong claim becomes true again.)
33. **A reviewer amendment is delivered work and carries the same burden of proof** — a Gate A review must verify fixture/oracle *pairings*, not only pinned literals; "the reviewer wrote it" is not evidence.
