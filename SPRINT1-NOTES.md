# Sprint 1 Notes — Manifest Authoring & Byte-Stable Serialization

## What was built

- `src/domain/Dependency.st` — `Parley.Dependency`: immutable
  `(name, VersionConstraint)` value; class-side construction;
  `satisfiedBy:` delegates to the constraint algebra's `allows:`;
  `=` and `hash` together.
- `src/manifest/ManifestErrors.st` — `Parley.ManifestError` (one batched
  error carrying the full `problems` list from `build`) and
  `Parley.ManifestVocabularyError` (unknown selector, nearest-selector
  suggestion via a cheap same-keyword-count + shared-prefix heuristic,
  and the full vocabulary).
- `src/manifest/ManifestBuilder.st` — the single sanctioned mutable edge
  object. Vocabulary = explicit methods in category
  `'manifest vocabulary'` (`name:`, `version:`, `summary:`, `author:`,
  `license:`, `fileIns:`, `dependency:constraint:`, `dependency:`),
  each with a method comment, recording raw strings only.
  `class >> vocabulary` reflects over the category; `doesNotUnderstand:`
  is the error path only. `build` batch-validates (required fields,
  name format, version parse, constraint parses, duplicates,
  self-dependency) and signals ONE `ManifestError` or answers an
  immutable `LibraryManifest`.
- `src/manifest/LibraryManifest.st` — immutable manifest; read-only
  accessors; `fileIns` order preserved exactly;
  `class >> fromIndexEntry:` reconstructs from a parsed entry with
  constraints re-parsed through `VersionConstraint fromString:` into
  structurally identical objects.
- `src/manifest/IndexEntryWriter.st` — canonical `#'parley-index' 1`
  rendering per Doc B §5.4: tag + version first; fixed key order, all
  keys always present; `dependencies` sorted by name; `fileIns` never
  sorted; constraints via `printString` (the wire form); single spaces,
  single-line body, single trailing newline.
- `src/manifest/IndexEntryReader.st` — `Parley.IndexEntryParseError`
  (positioned), `Parley.IndexEntryFormatError` (tag/version), and
  `Parley.IndexEntryReader`: a self-contained recursive-descent parser
  accepting ONLY literal arrays, strings (with `''` escaping), symbols
  (`#name` / `#'quoted'`) and non-negative integers; everything else is
  a positioned parse error; never touches a compiler pathway. Unknown
  tag / unsupported version are distinct, descriptive
  `IndexEntryFormatError`s.
- `src/manifest/Parley.st` — the `Parley define:` entry point (see
  ambiguity 1 below).
- Test suite (written first, in the red phase):
  `tests/support/ManifestGenerators.st` (subclasses the Sprint 0
  `DomainGenerators`; same LCG and `PARLEY_SEED` contract),
  `tests/laws/ManifestBuilderTest.st`, `tests/laws/MicroFormatTest.st`
  (law 9: 200 randomized round-trips + byte-stability; law 10: one
  rejection test per token class with exact positions), and
  `tests/acceptance/Sprint1AcceptanceTest.st` (`testS1_`–`testS15_`).

## Spec ambiguities / open points and their resolution

1. **The `Parley define:` receiver (the declared open point).** On gst
   3.2.5, `Parley` is the namespace object, and namespaces
   (`BindingDictionary>>doesNotUnderstand:`) treat unknown keyword
   sends as *binding setters* — `Parley define: [...]` on the bare
   namespace silently creates a `#define` binding and answers the
   namespace. Hosting a real method there would require extending the
   kernel `Namespace` class outside `*parley-compat` rules. Resolution
   (human-approved on issue #3, Option A): the entry point is the class
   `Parley.Parley`, a thin gateway defined *inside* the Parley
   namespace — `define:` creates a fresh `ManifestBuilder`, runs the
   block via `value:`, sends `build`, nothing more. Wherever the Parley
   namespace is current (all Parley source, the test suites, tooling
   file-ins), the token `Parley` resolves to the class and the Doc B §2
   syntax works verbatim. **Top-level caveat:** at raw Smalltalk top
   level the token still names the namespace, so bare `gst Package.st`
   is not yet supported; the author-facing evaluation path (Phase 3
   CLI/publish tooling) must file `Package.st` in with the Parley
   namespace current — deferred, deliberately, to the sprint that
   builds it. Doc B §2 was amended with a short entry-point-resolution
   note; no kernel or `*parley-compat` changes were made.
2. **Reader error classes.** Doc B names no exception classes for the
   reader. Resolution (flagged at RED review): `IndexEntryParseError`
   with a `position` accessor (1-based index of the first
   grammar-breaking character — so `1.5` errors at the `.`, `#[1 2]`
   at the `[`, `3 factorial` at the `f`) and a distinct
   `IndexEntryFormatError` for unknown tag / unsupported format
   version (S14).
3. **Canonical rendering is single-line.** Doc B §5.2 displays the
   entry multi-line, §5.4 rule 5 demands single spaces between
   elements. Resolution: §5.2 is illustrative pretty-printing; the
   canonical byte form is one flat line plus a single trailing newline
   (pinned exactly by `testS9_`).
4. **`ManifestError problems`** answers descriptive strings, each
   naming the offending value, so problems are individually
   identifiable (S5) without inventing a problem-object hierarchy Doc B
   doesn't specify.

## Verification audit

```
sprint: 1
date: 2026-07-19T01:22:43Z
toolchain: GNU Smalltalk version 3.2.5
PARLEY-SEED: 20260718
PARLEY-VERIFY: PASS seed=20260718 run=148 passed=148 failed=0 errors=0
```

Repeatability: reruns with `--seed 20260718` produce identical
`PARLEY-VERIFY` lines; the suite also passes with `--seed 1` and
`--seed 987654321` (148/148 each).

## Toolchain

```
GNU Smalltalk version 3.2.5
```
