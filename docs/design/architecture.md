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

> **This is the single canonical decision log.** It is referenced from every other design doc as "§8 decision N" and from `.github/copilot-instructions.md` §2. It was previously a one-line summary of a fuller log kept in the operator's local master plan, and the two drifted — decisions 34–37 existed only in the untracked copy while tracked docs already cited 35 and 37. Mirrors drift; this repo retired its `design-*.md` mirrors for the same reason. **There is now one copy, and it is this one.** Adding a decision means adding it here, in the same commit as the doc change that cites it.


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
19. **`Parley.Parley` entry-point gateway** — 3.2.5 namespaces swallow unknown keyword sends as binding setters; a shadow class inside the namespace preserves the Doc B §2 syntax verbatim without any kernel extension. Bare top-level `gst Package.st` is deferred to the Phase 3 tooling. (Sprint 1, issue #3.)
20. **Single-line canonical rendering** — §2.4 rule 5's "single spaces between elements" admits no newlines inside an artifact; multi-line listings in the specs are illustrative pretty-printing. The canonical byte form is one flat line plus a single trailing newline. (Sprint 1.)
21. **`Term` carries an equality-excluded `origin`** — provenance (the `Incompatibility` that imposed the term) rides the term itself, so derived incompatibilities recover their parent causes from `conflictFrom: acc terms` alone; `=`/`hash`/`negated` ride the three value fields only. (Sprint 2, issue #4.)
22. **Decision pins** — decisions are recorded in the descent ledger as positive exact-pin terms; late-edge-vs-decision conflicts surface through the existing collapse machinery with full provenance, keeping the search loop free of soundness re-check branches. (Ruled at the Sprint 2 close-out on issue #4; implemented in Sprint 3, issue #5 — the "no code outside tests consumes a `Resolution`" constraint is lifted.)
23. **`ApplicationManifest` carries no value equality (`=`/`hash`)** — it is a plain association value; adding equality would force `=`/`hash` onto the settled `LibraryManifest` (identity-equal by design). Any sprint that needs manifest value equality must declare `LibraryManifest` in scope explicitly. (Ruled at the Sprint 3 RED review on issue #5.)
24. **Source-protocol unknowns are ordinary values, never errors** — `versionsOf:` answers an empty collection and `manifestFor:version:` answers `nil` for an unknown (package, version); scan *problems* batch into one `SourceError` (`problems` strings in sorted-filename order, `ManifestError` house style); an empty-but-clean directory is an empty snapshot and resolution fails as an ordinary `#noVersions` value. Every future source (`GitIndexSource`, `RegistrySource`) follows this contract. (Pinned at the Sprint 4 RED review on issue #6.)
25. **The install-pipeline contract** — per triple in sorted package-name order: an empty `sha256` is a problem before anything else (`''` is never a store key), then cache-hit (a contained hash skips fetch entirely), then fetch, then verify-then-store (a mismatch never enters the store). Only a `SourceError` from `fetch:version:` becomes a batched `InstallError` problem — any other error propagates (a non-conforming source is a defect, not an install problem). The registration plan lives on `InstalledSet` (`registrationCommandsFor:`) as pure string values; `InstalledSet` carries no value equality (decision-23 precedent); `ContentStore` roots are created lazily, one directory level deep. (Pinned at the Sprint 5 RED review on issue #7.)
26. **Name-equality MVP constraint + staged registration plan** — a Parley package's entry name IS its star's internal `package.xml` name (lowercase per Doc B §3.4; the toolchain's name check is pure string equality and accepts lowercase). Forced by 3.2.5: `Kernel.StarPackage` rejects any star whose filename differs from its internal name, binding both `gst-package` and the child's `PackageLoader` — so registration stages each content-addressed archive under its true name inside the target (`install -D -m 644 <store path> <target>/.parley-staging/<name>.star`) then registers it with the **flagless** `gst-package --target-directory` (3.2.5 has no `--install` option despite its help text). The plan stays a pure value on `InstalledSet`, now two pair-adjacent lines per package; archives stay opaque — the true name comes from the tuple, never from reading the archive. Carrying a divergent archive filename through metadata was considered and rejected (it forces a lockfile schema bump or a new `PackageSource` protocol method). (Ruled mid-Sprint 6 on issue #8.)
27. **`RegistrySource` is deferred entirely, not stubbed** — registry hosting is deferred, and a registry source without a registry is either a renamed `DirectorySource` or an untestable HTTP shell; both teach nothing and leave a misleading name in the inventory. The `PackageSource` protocol already proves its polymorphism with two real implementations (`DirectorySource`, `GitIndexSource`); `RegistrySource` arrives with hosting. (Ruled by the operator at Sprint 7 staging.)
28. **A declared settled-class exception is a *public contract* exception, not a line-count exception** — Sprint 7 declared that `IndexEntryWriter` "gains exactly one selector." Keeping `write:on:` byte-identical alongside the new `write:archive:sha256:on:` was done by extracting their shared rendering into a private `writeHeadOf:on:`, so the two forms cannot drift. That private extraction is *inside* the declared exception: same class, same change, no new public contract, and the alternative — duplicating the canonical renderer — is precisely the drift the S5 regression guard exists to catch. Private helpers in service of a declared change need no separate declaration; new public selectors always do. (Ruled by the operator at the Sprint 7 close-out on issue #9.)
29. **Fail-stop governs the run that failed, not the run after it** — `Publisher` staging sweeps a `.parley-publish-stage/` left behind by an earlier failed build before recreating it. "Fail-stop never cleans up behind an error" preserves the *failing* run's evidence for inspection; it does not make the next invocation non-deterministic or un-re-runnable. Doc F §1 step 3 states the sweep. (Ruled by the operator at the Sprint 7 close-out on issue #9.)
30. **Glue that chooses an exit code is not glue** — Doc E §4.2 declared `bin/parley-main.st` "glue, not logic — excluded from SUnit obligations." That exemption let the hardcoded file-in list miss `src/publish/`, so the shipped `publish` verb answered a `doesNotUnderstand:` backtrace and **exited `0`** — fail-wrong, the one failure mode the architecture exists to prevent, undetectable by 409 laws. The exemption is withdrawn: the wiring, the flag grammar and the error boundary move into `Parley.CommandLine` (a composition root, not a manager) with laws; `bin/` keeps only file-in, one send, print and quit, and is itself law-guarded by a drift test requiring it to name every `src/` subdirectory. An escaping error becomes one diagnosis line and exit `70` (`EX_SOFTWARE`), distinct from the `1` of a diagnosed problem, and never a backtrace. (Ruled by the operator at Sprint 8 staging, from a defect found at the Sprint 7 close-out.)
31. **A boundary must blame the right party, so `ManifestFile` checks the path** — Sprint 8's third declared settled-class exception, granted at the RED review. 3.2.5's `FileStream fileIn:` signals a kernel `SystemExceptions.FileError` on a missing file, so `ManifestFile load:` never reached its define-less check and `resolve` before `parley init` — the most ordinary user error in the tool — arrived at the §4.2 boundary *undiagnosed* and would have been answered with exit `70`: "this is a defect in Parley, not in your project." Exit `70` on that input is fail-wrong in its second form: not a lying exit code, but a lying attribution of blame, and a boundary whose flagship case is misfiled is not a boundary. `load:` now checks the path first and signals one pinned `ManifestError`, so issue #10's S4 is exit `1` as specified. The alternative — restating S4 as exit-`70` — was considered and rejected: it would have made the sprint's own motivating example a permanent exception to its own rule. (Ruled by the operator at the Sprint 8 RED review on issue #10.)
32. **The closed-set law states what the code can support: "declared undiagnosed with its ground named", not "provably never signaled out of a verb"** — Doc E §4.2's original wording was false for three of the five undiagnosed classes: `IndexEntryParseError`/`IndexEntryFormatError` escape the `CLI`'s `parley.lock` read and `ManifestVocabularyError` escapes `ManifestFile load:` on an authoring typo. Rather than let a law assert something untrue — the failure mode this whole sprint exists to end — the second bucket is renamed and each escape path is declared by name in `CommandLineFixtures>>undiagnosedErrorClassNames`. The law's guarantee is undiminished: the two lists must **partition** the enumeration, so no new error class can drift into the `70` bucket without someone deciding it should. All three escapes land nonzero, one line, no backtrace, so fail-stop holds; what they lack is the right blame. **Ruled gap carried out of Sprint 8:** reclassifying them as exit-`1` diagnoses needs a lock-validation boundary and an authoring-error boundary — design, not a fix — and is scheduled for Sprint 9. (Ruled by the operator at the Sprint 8 RED review on issue #10.)
33. **A reviewer amendment is delivered work and carries the same burden of proof** — at the Sprint 8 RED review the operator verified every pinned wording byte-for-byte against the settled source, amended three files, and never cross-checked that the fixture *feeding* S2 paired with the oracle S2 asserted against: `SourceFixtures populateDiamondIn:` writes placeholder shas while `ExecFixtures diamondLockString` embeds the true digests, so the two literals could never be equal and no correct `CommandLine` could have satisfied the assertion. The agent found it in GREEN, checked it by hand through the shipped binary rather than asserting it, and **halted instead of patching a signed-off test** — the right call, and the rule stands: amendments to reviewed tests are the operator's. Two lessons, both binding: a Gate A review must verify fixture/oracle *pairings*, not only pinned literals; and "the operator wrote it" is not evidence — it is the same unchecked claim the sprint's own S8 finding was made of, arriving from the other direction. (Ruled by the operator mid-Sprint 8 on issue #10.)
34. **The authoring boundary lives in `Parley.Parley class >> define:`, because on 3.2.5 it cannot live anywhere else — and it covers `ManifestError` too** — Doc E §3 and issue #11 both placed the authoring wrap around the file-in inside `ManifestFile load:`. That wrap can never fire: the doit context of a filed-in statement is **parentless** (`thisContext parentContext` answers `UndefinedObject>>__terminate`), so an `on:do:` around `FileStream fileIn:` is not in the signaling chain. gst prints its own backtrace, abandons the statement, and `load:` answers the define-less diagnosis — a true sentence about the wrong thing, for a file that *did* send `define:`. Verified by the agent and re-verified independently by the operator, along with the one alternative worth considering (`Behavior>>evaluate:`, which fails identically). The handler must sit in a frame the filed-in statement *calls*, and inside Parley there is exactly one: `define:`. Granted as Sprint 9's **third declared settled-class exception**. **Widened at the same ruling to `ManifestError`:** the identical swallow hits `ManifestBuilder>>build`, so `version: 'banana'` today prints a backtrace and reports "no manifest defined" — the same disease, one handler away, and left out it would have falsified the sprint's own headline ("no backtrace, right blame") for the second-most-common authoring error there is. The `problems` batch is re-signaled intact, never flattened. Scope discipline was weighed and the widening ruled *in*: the marginal cost is one class in an `ExceptionSet`, while the marginal cost of excluding it is a discriminating handler plus a documented reason why one authoring error is diagnosed and its sibling is not. Doc E §3 rewritten (including the correction of §4.2's false escape claim — `ManifestVocabularyError` never escaped `load:`; it was swallowed, which is worse than decision 32 declared). (Ruled by the operator at the Sprint 9 RED review on issue #11.)
35. **A closed set over *Parley* error classes does not prove "every operator input is diagnosed" — the remaining blindness is at the deserialization boundaries** — Sprint 9 restored Doc E §4.2's strong claim and S7 demonstrates it, but the claim quantifies over `Error` subclasses defined in the `Parley` namespace. A **kernel** error raised inside a verb is outside the enumeration, so no law sees it. The agent found and ranked first the instance that matters: a `parley.lock` that parses, carries the right tag and declares a supported version but has a malformed body (missing `#packages`) reaches `Resolution fromLockEntry:` and dies as `SystemExceptions.NotFound` at exit `70`. Verified by the operator at close-out: `internal error: NotFound: Invalid argument #packages: key not found - this is a defect in Parley, not in your project`. That is *verbatim the disease of issue #11's own Motivation block*, on the same file, reachable by one line of hand-editing — in-spec, because Doc E §4.1 named exactly two rejection grounds and both are closed, and simultaneously a **soundness-class gap**, because the sprint's stated purpose ("every error names the right party") is not achieved for the input class that motivated it. The lesson generalizes past the lockfile: the honest invariant is per **deserialization boundary** — every point where Parley reads an operator-editable file must validate shape before handing the value to a constructor — not per error class. Enumerating more classes would not have caught this and will not catch the next one. **Scheduled: Sprint 10, first item.** **Consumer constraint until it lands:** Parley may claim only that a lockfile it wrote itself, or one corrupted *syntactically*, is diagnosed; a semantically malformed lock still exits `70` blaming Parley. Doc E §4.1 and §4.2 amended to say so in place, so no reader takes the restored claim for more than it is. (Ruled by the operator at the Sprint 9 close-out on issue #11.)
36. **The scoping of a granted exception is part of the grant, and the RED ruling under-specified it** — decision 34 granted the authoring boundary in `Parley.Parley class >> define:` with the words "wraps … and hands the error to `ManifestFile`". Taken literally that swallows errors from the **live** `Parley define:` API too, and it broke five settled Sprint 1 laws in GREEN — those laws *are* the contract that a live `define:` signals to its own caller. The agent fixed the code rather than the laws, in the same increment, and flagged that the doc's wording would let a future reader reintroduce the hole. Correct on both counts, and the omission was the reviewer's: a ruling that grants a handler must say **which contexts it captures in**. The boundary asks `ManifestFile isLoading` — the one context whose signaling chain is cut — and `pass`es everywhere else; the flag is cleared in an `ensure:`, so a part-way failure can never leave an image where live authoring errors vanish. Doc E §3 amended with the scoping rule and its rationale. Sibling of decision 33 from the other direction: there the reviewer's amendment carried an unchecked claim, here the reviewer's *grant* carried an unstated scope. (Ruled by the operator at the Sprint 9 close-out on issue #11.)

37. **Retirement is an index-level record that filters in the snapshot — not an entry key, and not a resolver concern** — the roadmap's #1 item, designed at Sprint 10 staging. Three rulings, each protecting an invariant that a naive implementation would have broken. **(a) Where the signal lives:** a `#retired` key inside the `#'parley-index'` artifact would require *rewriting a published entry*, contradicting refusal-first publishing (Doc F §1) and changing bytes that are content-addressed and, once signing lands, signed. Retirement is an assertion the index owner makes **about** a release, not a property **of** it, so it lives in a separate `#'parley-retired' 1` artifact (Doc B §5.5) found by tag, never filename (the Sprint 4 contents-not-filename rule). Additive third tag: no format-version bump, and the deferred `RegistrySource` + entry-signing work gets *easier*, not harder. The one-directional cost is stated plainly in the doc — an index that adopts retirements is unreadable to a pre-Sprint-10 Parley, which is the safe failure direction and precisely why the item had an external clock. **(b) Where it takes effect:** in `IndexSnapshot`, not the `Resolver`. `versionsOf:` excludes retired releases so fresh resolution never picks one; `dependenciesOf:version:` and `sha256For:version:` still answer so an existing lock still installs. A kind-check inside the search would have been the obvious implementation and the wrong one — it puts policy in a pure function and forces every future strategy to reimplement it; filtering at the snapshot means `PubGrubStrategy` inherits retirement for free. Doc C §2.1, proved by S7 asserting an *identical* `Resolution` against a snapshot where the version is merely absent. **(c) What is deliberately not built:** reporting a retired **pinned** dependency on `install`, because that requires consulting the index on the fast path and Doc E §4.1's settled law requires that path to complete without consuming the source's snapshot. The tension is real and the answer is a verb allowed to consult the index (the deferred `parley check`) — not a quietly weakened law. Named in the issue as the sprint's most tempting scope creep. (Ruled by the operator at Sprint 10 staging on issue #12.)

38. **A drift law anchored on source text must search code, not prose — and its own guard is what makes the stripper safe** — Sprint 10's deserialization-boundary law enumerates senders of `IndexEntryReader readFrom:` across `src/`. In GREEN it reported a third sender: `CommandLine`, whose new `deserializationBoundaries` **comment quotes the send it is about**. The law caught its own author. The fix searches `codeOf:` the file — comments and string literals stripped, character literals consumed whole so a quote that is a *value* never opens a literal region — because Doc E §4.2 anchors on **senders**, and prose naming a send is not one. The rejected alternative, contorting the comment so it never spells the send, would leave the next writer of an honest comment breaking a drift law for no reason. What makes the stripper safe to write at all is the law that pins the enumeration's answer to exactly `CLI` and `DirectorySource`: strip too much and the real senders vanish, and the same guard fires again. **Residual limit, named rather than hidden:** the search is textual, so a sender split across lines or reached through a temporary is missed. The honest statement of the law is "every *textually spelled* sender is declared". **Correction (Sprint 11 staging):** this entry originally called reflective enumeration (`whichSelectorsReferTo:`) "the stronger form". That was asserted, not probed, and it is **wrong on 3.2.5** — `whichSelectorsReferTo:` searches a method's *literals*, not its send bytecodes, so probing it for `#readFrom:` across the `Parley` namespace answers exactly one hit (`CompiledCode class >> #specialSelectors`, a literal array that happens to contain the symbol) and **none of the real senders**; `allCallsOn:` does not exist. There is no reflective fallback on this toolchain, so the textual anchor is not a shortcut — it is the only mechanism available, and hardening it (§8 decision 43) is the fix rather than replacing it. (Found by the agent in Sprint 10 GREEN; ruled by the operator at the close-out on issue #12; the reflective claim corrected at Sprint 11 staging after probing it.)
39. **A gate must verify that its subject still exists, not merely that it reported success** — the green gate checked exactly two things: exit code `0` and the `PARLEY-VERIFY: PASS` sentinel. It never checked parse errors or that every test file loaded, so a test file that failed to parse did not fail — it **vanished**, taking its laws with it, and the surviving suite passed. Demonstrated by the operator at the Sprint 10 close-out with a deliberately broken probe file: `PARLEY-VERIFY: PASS ... run=529 passed=529 failed=0 errors=0` — **ten laws gone, gate green**. This is the Sprint 7 `publish` disease one level up in the tooling: the thing that reports success is not the thing that was supposed to be checked, and 539 passing laws cannot detect their own absence. Load integrity (`PARSE_ERRORS`, `PARLEY-TESTFILE` count vs. the `tests/` file count) is now asserted in **both** phases; red keeps stating it in its own terms, because red must fail on missing behavior and never on broken syntax. Fixed operator-side in `scripts/verify-sprint.sh` at the close-out, the Sprint 8 `wrap-sprint.sh` precedent. (Ruled by the operator at the Sprint 10 close-out on issue #12.)

40. **`why` and `tree` walk the pinned graph, not the resolution ledger** — the roadmap described these verbs as "near-free from the `ConstraintLedger`'s provenance". Probed at Sprint 11 staging: **false**. The ledger is a transient resolution-time structure, discarded when the search answers, and `Resolution` carries only the root name and `(version, sha256)` triples — no edges, no provenance. Resurrecting the ledger would mean re-resolving, which can legitimately answer a *different* set than the lock pins, so the verbs would explain a world the operator is not running. They instead read the **lock** (what is actually pinned) and the **snapshot** (`dependenciesOf:version:`, already settled), and walk: `tree` renders root-down, `why <pkg>` renders the dependent chains that reach a package. This is strictly better than the ledger route — it answers about the installed world, needs no resolver change, and reuses two settled accessors. (Ruled by the operator at Sprint 11 staging on issue #13.)
41. **A predicate shared by two schema validators gets its own home, not a public selector on a settled class** — `CLI>>isLockString:` and `DirectorySource>>isSchemaString:` are the same predicate, duplicated because sharing it meant adding a public selector to a settled class (the Sprint 10 trade, correctly taken at the time). The third caller arrives with hex-digest validation (§8 decision 42), which is the trigger Sprint 10 named. `Parley.SchemaShape` (`src/manifest/`, **declared here**) holds the shapes the micro-format schemas are made of — `isString:`, `isStringArray:`, `isHexDigest:` — as class-side predicates over values. It is not a manager: it holds no state, makes no decision, and answers questions about values it is handed. Both validators consume it and neither re-implements it, the same rule that keeps `Version fromString:` the single definition of what parses. (Ruled by the operator at Sprint 11 staging on issue #13.)
42. **A digest that cannot be a digest is a shape error, not a tampering report** — the lock's `#sha256` and the entry's `#archive` digest are validated as *strings* and never as hex. A typo'd digest therefore passes both boundaries and fails later at `ContentStore>>verifyHash:`, which reports **corruption** — "the store never repairs itself; this is detection" — when the truth is a mistyped character in a hand-edited file. Nonzero and no backtrace, so not fail-wrong in the exit-code sense, but the same *blame* misattribution as decisions 31 and 35: the operator is told their cache is compromised when their lockfile has a typo. Both boundaries now require 64 lowercase hex characters, through the one `SchemaShape isHexDigest:`. Validating the shape does **not** validate the truth — `verifyHash:` remains the only thing that says a digest matches its bytes, and it keeps its corruption wording for the case that really is corruption. (Ruled by the operator at Sprint 11 staging on issue #13.)
43. **When a toolchain offers no reflective mechanism, harden the textual one and bound the claim honestly** — the deserialization-boundary drift law searches source text because 3.2.5 offers nothing better (§8 decision 38, corrected). Hardening means normalizing whitespace so a receiver and selector split across lines are still one send, which closes the accidental miss. The *deliberate* miss — a send reached through a temporary, `reader := IndexEntryReader. reader readFrom: …` — cannot be closed textually and has no reflective fallback here, so it is answered by a **convention with a law**: every sender spells its receiver, and the enumeration's pinned answer is what detects a violation the moment one appears. A law that cannot prove its full claim should narrow its claim and say why, not quietly keep the wider name. (Ruled by the operator at Sprint 11 staging on issue #13.)
