# AGENTS.md — Parley Coding Agent System Manual (v4.0)

> **Status:** Canonical system instructions for any AI coding agent or human contributor working on this repository. Where code or conversational assumptions disagree with this document, this document wins.
>
> **Project:** Parley — a modern, native command-line package manager for GNU Smalltalk 3.2.5, written entirely in Smalltalk. *"Smalltalk packages, resolved by conversation."*
>
> **Document map:** This manual states the rules. The *why* lives in `docs/design/rationale.md`. The system blueprint is `docs/design/architecture.md`. Component specs: `docs/design/domain-model.md`, `docs/design/manifest-and-serialization.md`, `docs/design/resolver.md`. Read the relevant design doc before implementing any class it covers.

---

## 1. The Guiding Philosophy ("The Moat")

- **The hero is the idea:** live objects, clean message passing, refactor-as-you-think. Every domain concept is an independent object answering messages.
- **No procedural spaghetti:** never write massive centralized scripting logic or "manager" god-objects. If logic branches on the *kind* of object it handles, introduce polymorphism — do not add branching.
- **Self-contained domain:** Parley depends only on the GNU Smalltalk 3.2.5 kernel and bundled `gst-package` tooling. **Never add a third-party library dependency** — including any serialization library (no STON port; see §4).
- **No language wars:** never write code, comments, or docs claiming Smalltalk beats other languages.

## 2. Hard Bans (violating any of these is a defect, not a style issue)

1. **Never evaluate third-party content.** No third-party text — `Package.st` files, index entries, lockfiles, anything — is ever passed to `Behavior>>evaluate:`, the `Compiler`, `doIt` facilities, or any compilation pathway. This includes content that looks like a harmless literal array. Static artifacts are read ONLY by `IndexEntryReader` (the literals-only reader; Doc B).
2. **Never attempt in-image version sandboxing.** GNU Smalltalk 3.2.5 namespaces cannot host two versions of the same class. All isolation is process-level via `ExecutionScope` (child `gst` invocations with curated paths).
3. **Zero public setters in the domain model.** All construction flows through class-side methods that validate and normalize; every algebraic/transforming operation answers a new instance. The single sanctioned mutable object is `ManifestBuilder` (an edge object, not domain).
4. **Never shadow kernel classes.** The version span class is `VersionRange`, never `Interval`.
5. **No `gpm`.** The string `gpm` must not appear in code, categories, file names, docs, or artifacts. The project's only name is Parley.
6. **Never store a bare constraint during resolution.** All constraint accumulation goes through `ConstraintLedger` with `Term` provenance ("never intersect anonymously"; Doc C).

## 3. Namespaces, Categories & Naming

- All Parley classes live in the **`Parley` namespace**.
- All kernel-class extensions (3.2.5 polyfills such as `Collection>>ifEmpty:` / `ifEmpty:ifNotEmpty:`) live exclusively in the method category **`*parley-compat`**, kept minimal and defensive: selectors match well-known ANSI/Pharo semantics exactly.
- The `ManifestBuilder` DSL vocabulary is defined as **explicit methods** in the method category `'manifest vocabulary'`, each with a method comment (they become hover docs). `doesNotUnderstand:` is the **error path only** — it answers a `ManifestVocabularyError` (unknown selector, nearest-selector suggestion, full vocabulary reflected from the category). **Never implement DSL vocabulary through `doesNotUnderstand:`** — phantom selectors are invisible to tooling.

## 4. The Trust Boundary

- **Authoring:** developers write `Package.st` — evaluated via `Parley define: [:pkg | …]` against `ManifestBuilder`. The builder is for **ergonomics, validation, and serialization** — it is NOT a security sandbox, and no evaluation sandbox is to be built.
- **The security boundary is the static index entry.** At publish, manifests serialize to the literal micro-format. The resolver and all consumers of third-party package information operate **exclusively on static index entries**; third-party `Package.st` files are never executed.
- **Metadata/archive split:** resolve entirely against lightweight index metadata; touch `.star` archives only after resolution, at install time, hash-verified.

## 5. Serialization Rules (byte-stability is mandatory)

1. Every static artifact is one literal array opening with a format tag + version: `#'parley-index' 1` / `#'parley-lock' 1`.
2. Accepted literals ONLY: arrays `#( … )`, strings, symbols, non-negative integers. The reader rejects everything else with a positioned parse error.
3. **Fixed key order**; all schema keys always present.
4. **`dependencies` are sorted by package name.**
5. **`fileIns:` order is preserved exactly — never sort it.** It maps to `gst-package` load order, which is semantic in Smalltalk. Same document, opposite ordering rules, both deliberate.
6. Constraints serialize via `VersionConstraint printString` — canonical normal form is the wire form (`'^0.4.2'` may serialize as `'>=0.4.2 <0.5.0'`; this is correct).
7. Deterministic whitespace: single spaces, no trailing whitespace, single trailing newline.

## 6. Resolution Rules

- `Resolver` is a **pure function** of (root manifest, immutable index snapshot). Zero live I/O mid-resolution. Sources answer immutable snapshots before resolution begins.
- Resolution answers a **value**: `Resolution` or `ConflictReport`. Never signal exceptions in the search loop.
- `BacktrackingStrategy`: smallest-domain-first selection (fewest allowed candidates; ties alphabetical), candidates highest-first, **copy-on-descend** ledgers (backtracking = discarding a ledger; no undo logs). Conflicts are built at collapse points on the way down and merged at exhaustion; the unwind carries finished values only. **No backjumping in the MVP.**
- The strategy seam must stay clean: `Resolver strategy: BacktrackingStrategy new` today; `PubGrubStrategy` must be an additive swap later.
- Lockfiles ship day one. Default invocation path: verify pins against the lockfile; re-resolve only on manifest change or explicit `parley update`.

## 7. Testing Requirements

**Mandatory pre-flight:** every code snippet or module must execute cleanly against GNU Smalltalk 3.2.5 before shipping or committing.

**Test laws, not just examples.** Randomized cases (hundreds per run) MUST use a deterministic seed. The complete required law set:

1. Commutativity of `union:` and `intersect:`.
2. Associativity of `union:` and `intersect:`.
3. De Morgan: `(a union: b) complement = (a complement intersect: b complement)`, and the dual.
4. Double complement: `a complement complement = a`.
5. Absorption: `a union: (a intersect: b) = a`.
6. Identity/annihilator: `a intersect: VersionConstraint any = a`; `a intersect: VersionConstraint none = VersionConstraint none`.
7. **Normalization invariant:** internal range arrays remain sorted, disjoint, non-adjacent after every operation.
8. **Randomized membership consistency:** `(a intersect: b) allows: v` ⇔ `(a allows: v) and: [b allows: v]` for random `v` — primary net for bound-inclusivity off-by-ones.
9. **Round-trip identity law:** *build → serialize → read = build* (writer/reader compose to identity on manifests).
10. **Literal-reader rejection tests:** every non-literal token class (identifiers, floats, characters, booleans, `nil`, comments, message sends) must fail to parse with a positioned error.
11. **Resolver determinism:** same manifest + same snapshot ⇒ identical `Resolution` and **byte-identical lockfile**.
12. **Derivation-tree inspection:** tests send messages directly to failed `ConflictReport` trees and verify narrated proofs render stably.

## 8. Scope Discipline

Implement what the current milestone specifies — nothing more. Do not invent architecture: if a design question is not answered by the design docs or the master plan, stop and ask rather than improvising. Prerelease version support, backjumping, `PubGrubStrategy`, and registry hosting are all explicitly deferred; do not build them.
