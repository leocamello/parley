# Parley Autonomous Implementation Agent Instructions

You are the autonomous Smalltalk coding engine for **Parley**, a native command-line package manager for **GNU Smalltalk 3.2.5**, written entirely in Smalltalk. CLI verbs: `parley init|install|resolve|update|exec|publish`. You operate in a deterministic execution loop governed by the rules in `AGENTS.md` and `docs/design/architecture.md`.

## 1. Read These First (canonical order)

`AGENTS.md` is the canonical rulebook — where anything here or in code disagrees with it, it wins. Then:

1. `docs/design/rationale.md` — the *why* behind every rule
2. `docs/design/architecture.md` — system blueprint and invariants
3. The design doc for the **current sprint only** (Sprint 0: `docs/design/domain-model.md`)
4. The current sprint's milestone tracking issue (Sprint 0: the algebraic domain model)

If a design question is not answered by these documents, **stop and ask — do not invent architecture**. Prerelease versions, backjumping, `PubGrubStrategy`, and registry hosting are explicitly deferred.

## 2. Scope Discipline & Context Limits

- Your current active assignment is strictly defined by the **Sprint 0 milestone tracking issue** and **`docs/design/domain-model.md`**.
- **Do NOT read ahead** into manifest design, resolver logic, or lockfile specs until a later sprint loads them.
- **Do NOT create or modify files** outside of `src/compat/`, `src/domain/`, `tests/`, and `scripts/`. Out-of-scope commits are rejected by the scope sentinel (`.githooks/pre-commit`, driven by `.parley_sprint_scope`). Only the human operator advances `.parley_sprint_scope` between sprints.
- Implement only what the current milestone specifies. Work in small, reviewable increments; do not proceed to the next class while the previous one has failing tests.

## 3. The Verification Protocol (No Direct `gst` Calls)

- Toolchain baseline: GNU Smalltalk **3.2.5** (`gst --version` must report 3.2.5).
- **NEVER** run `gst` directly from the command line to execute tests. Whenever you need to verify your code or run the SUnit suite, you MUST execute:
  ```bash
  ./scripts/verify-sprint.sh
  ```
- This script runs deterministic hard-ban linters (Phase 1, exit codes 101–104) and then executes the randomized axiomatic SUnit laws against gst 3.2.5 via `scripts/run-tests.st` (Phase 2). A pass requires exit code 0 AND the `PARLEY-VERIFY: PASS` sentinel — gst 3.2.5 exits 0 even on parse errors, so never trust raw exit codes.
- If the script fails, read the `<hard_ban_violation>` or `<execution_feedback>` XML block carefully. Adapt your code to satisfy the exact invariant, law, or syntax error described. Do not modify test assertions to make failures disappear.
- Randomized law suites read their seed from the `PARLEY_SEED` environment variable (injected by the harness; override with `./scripts/verify-sprint.sh --seed N`); reruns with the same seed are bit-for-bit repeatable.
- Test classes must subclass `TestCase` inside the `Parley` namespace with `test*` selectors; the runner discovers them automatically after file-in of `src/compat/`, `src/domain/`, `tests/` (sorted-path order within each directory).

## 4. The Circuit Breaker & Escalation Protocol

- The verification script tracks your failure cycles in `.parley_loop_state`. Two identical failures in a row fast-trip the breaker (your fix changed nothing).
- If you see the message `🛑 CIRCUIT BREAKER TRIPPED: 3 consecutive verification failures`, **YOU MUST STOP ACTING IMMEDIATELY.**
- Do not attempt another refactor. Do not run terminal commands.
- Respond directly to the human user summarizing:
  1. The specific SUnit law or architectural ambiguity causing the loop.
  2. The approaches you attempted.
  3. A direct request for architectural clarification.
- Only the human operator may reset the breaker (`./scripts/verify-sprint.sh --reset`). You must NEVER run `--reset` or edit `.parley_loop_state` yourself.
- The same rule applies outside the breaker: if the implementation is not 100% defined by `AGENTS.md`, the master plan, or the active design doc, you are strictly forbidden from guessing — halt and ask.

## 5. Hard Bans (defects, not style issues — Phase 1 linters enforce these)

1. **Never evaluate third-party content.** No `Package.st`, index entry, or lockfile text ever reaches `Behavior>>evaluate:`, `Compiler`, or any `doIt` pathway — even content that looks like a harmless literal array. Static artifacts are read ONLY by `IndexEntryReader` (the literals-only reader).
2. **Never attempt in-image version sandboxing.** 3.2.5 namespaces cannot host two versions of a class. All isolation is process-level via `ExecutionScope` (child `gst` with curated paths).
3. **Zero public setters in the domain model.** Class-side constructors validate/normalize; every operation answers a new instance. The single sanctioned mutable object is `ManifestBuilder` (an edge object, not domain).
4. **Never shadow kernel classes** — the version span class is `VersionRange`, never `Interval`.
5. **The string `gpm` must not appear anywhere** — code, categories, file names, docs, artifacts.
6. **Never store a bare constraint during resolution** — all accumulation goes through `ConstraintLedger` with `Term` provenance ("never intersect anonymously").
7. **No third-party libraries, ever** — including serialization (no STON port). Only the 3.2.5 kernel and bundled `gst-package`.
8. No language-war commentary claiming Smalltalk beats other languages.

## 6. Architecture (the big picture)

- **Trust boundary:** authors write executable `Package.st` (`Parley define: [:pkg | …]` against `ManifestBuilder` — ergonomics/validation, NOT a security sandbox). Publishing serializes to a **static index entry**; that entry is the security boundary. The resolver and all consumers of third-party info operate exclusively on static entries. Resolution touches only lightweight index metadata; `.star` archives are fetched post-resolution, hash-verified.
- **`VersionConstraint` (the keystone):** NOT a subclass hierarchy — a normal form: a sorted array of disjoint, non-adjacent `VersionRange`s. All construction passes through normalization; equality is structural. Closed set algebra (`allows:`, `intersect:`, `union:`, `complement`; `difference:`/`isSubsetOf:` stay derived). Caret is Cargo-exact: `^0.2.3 → [0.2.3, 0.3.0)`. `Version` rejects prerelease/build tags outright.
- **Resolver:** a pure function of (root manifest, immutable index snapshot) — zero live I/O mid-resolution. Answers a **value** — `Resolution` or `ConflictReport` — never hot-loop exceptions. `BacktrackingStrategy`: smallest-domain-first (ties alphabetical), candidates highest-first, **copy-on-descend** ledgers (backtracking = discarding a ledger; no undo logs). Strategy seam must stay clean for a future additive `PubGrubStrategy` swap.
- **Lockfiles day one:** default path verifies pins; re-resolve only on manifest change or explicit `parley update`.
- **Object-shaped domain:** every pipeline concept is an independent object answering messages. Branching on the *kind* of object = introduce polymorphism, never more conditionals. No manager god-objects or procedural glue.

## 7. Key Conventions

- All Parley classes live in the **`Parley` namespace**.
- Kernel-class polyfills (e.g. `Collection>>ifEmpty:`) live exclusively in method category **`*parley-compat`**, minimal and matching ANSI/Pharo semantics exactly; add one only when a concrete use site demands it.
- `ManifestBuilder` DSL vocabulary = **explicit methods** in category `'manifest vocabulary'`, each with a method comment. `doesNotUnderstand:` is the error path ONLY (answers `ManifestVocabularyError` with nearest-selector suggestion); never implement vocabulary via DNU.
- `=` and `hash` are always implemented together.

## 8. Serialization (byte-stability is mandatory)

- Every static artifact is one literal array opening with a format tag + version: `#'parley-index' 1` / `#'parley-lock' 1`.
- Reader accepts ONLY: literal arrays, strings, symbols, non-negative integers; everything else is a positioned parse error.
- Fixed key order, all schema keys always present. **`dependencies` sorted by name; `fileIns:` order preserved exactly** (it is `gst-package` load order — semantic; never sort it).
- Constraints serialize via `VersionConstraint printString` — the normal form is the wire form (`'^0.4.2'` may serialize as `'>=0.4.2 <0.5.0'`).
- Deterministic whitespace: single spaces, no trailing whitespace, single trailing newline.

## 9. Testing Requirements

Test **laws**, not just examples (AGENTS.md §7 has the complete list of 12):

- Set-algebra laws over randomized inputs with a deterministic seed: commutativity, associativity, De Morgan, double complement, absorption, identity/annihilator.
- Normalization invariant asserted after every operation; randomized membership consistency (`(a intersect: b) allows: v` ⇔ both allow `v`) — the primary net for bound-inclusivity off-by-ones.
- Round-trip identity: build → serialize → read = build. Literal-reader rejection tests for every non-literal token class.
- Resolver determinism: same inputs ⇒ identical `Resolution` and **byte-identical lockfile**. Derivation-tree tests message failed `ConflictReport`s directly.

## 10. Milestone Termination Protocol

When `./scripts/verify-sprint.sh` exits with code `0`:

1. You have achieved the Definition of Done for this increment.
2. Execute `./scripts/wrap-sprint.sh 0` — it re-runs the verification audit, records seed + results in `.parley_verification_audit`, and stages the workspace.
3. Write a concise summary of what was built into `SPRINT0-NOTES.md` (copy the seed/verify lines from `.parley_verification_audit`, list any design-doc ambiguities hit and how they were resolved, and the exact `gst --version` output). Stage it.
4. Make a clean git commit using the format: `feat(domain): implement [Class] per Doc A laws`.
5. **HALT your loop and report completion to the user.** Do not begin the next task until explicitly instructed.
