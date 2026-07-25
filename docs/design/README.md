# Parley — Design Documents

These are the **canonical specs**. Where code, a kickoff prompt, or a
conversation disagrees with a document here, the document wins until it is
amended through the pipeline's Stage 2. Amendments land here and nowhere else.

## Reading order

Start with the two system-wide documents, then read only the component spec
for the work in hand:

1. [`rationale.md`](rationale.md) — *why* the architecture is shaped this way.
2. [`architecture.md`](architecture.md) — the system blueprint, invariants, class inventory, and decision log.
3. The lettered component spec below.

The binding engineering rules are in [`AGENTS.md`](../../AGENTS.md); the loop
protocol is [`.github/copilot-instructions.md`](../../.github/copilot-instructions.md).

## The lettered specs (Docs A–F)

Docs are referred to by letter throughout the codebase, the milestone issues,
and the sprint notes — `"Spec: docs/design/resolver.md §2"` and `"per Doc C"`
mean the same thing. This table is the map.

| Doc | File | Covers | Introduced |
| --- | --- | --- | --- |
| **A** | [`domain-model.md`](domain-model.md) | The keystone algebra: `Version`, `VersionRange`, `VersionConstraint`, `Term`, `Incompatibility`, `Dependency` | Sprint 0 |
| **B** | [`manifest-and-serialization.md`](manifest-and-serialization.md) | `Package.st` authoring, `ManifestBuilder`, the literal micro-format, `IndexEntryWriter`/`Reader` | Sprint 1 |
| **C** | [`resolver.md`](resolver.md) | The pure resolver, `ConstraintLedger` provenance, `BacktrackingStrategy`, conflict narration, the `PackageSource` protocol | Sprint 2 |
| **D** | [`installer.md`](installer.md) | `Sha256`, the content-addressed `ContentStore`, `Installer`, the `gst-package` registration plan | Sprint 5 |
| **E** | [`execution-and-cli.md`](execution-and-cli.md) | `ProcessRunner`, `ExecutionScope` (the curated child `gst`), `ManifestFile`, `CLI`, `CommandLine` and the diagnosis boundary, `LockError` and the lock/authoring blame boundaries, the shipped binary | Sprint 6 |
| **F** | [`publish-and-sources.md`](publish-and-sources.md) | The publish pipeline, the composed `package.xml`, schema-shape and value-shape validation, `GitIndexSource` | Sprint 7 |

## Why the filenames are not letter-prefixed

Renaming these files to `c-resolver.md` and friends would be tidier at `ls`,
and it is deliberately not done: **39 files under `src/` and `tests/` cite
these filenames** in their header comments (`"Spec: docs/design/resolver.md
§2; issue #4 S9, S17."`). Renaming would touch that many settled-API files for
a cosmetic gain, and every one of them would need a declared exception on the
milestone issue. This table carries the letter map instead, at zero cost to
the code.

## Invariants these documents own

Amending any of the following is an architecture change, not an edit — it goes
through Stage 2 and gets a decision-log entry in
[`architecture.md`](architecture.md) §8:

- The **trust boundary**: the static index entry, never the builder. No
  third-party content reaches any compilation pathway (Doc B).
- The **constraint normal form**: sorted, disjoint, non-adjacent ranges;
  structural equality denotes set equality (Doc A).
- **Byte-stable serialization**: fixed key order, dependencies sorted by name,
  `fileIns:` order preserved exactly (Doc B §5).
- The **purity contract**: the resolver is a pure function of (root manifest,
  immutable snapshot) and answers a value, never an exception (Doc C).
- **Process-level isolation only** — 3.2.5 cannot host two versions of a class
  in one image, so `ExecutionScope` spawns a curated child (Doc E).
