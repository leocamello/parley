# Parley Design — Manifest Authoring & Micro-Format Serialization

> **Scope:** `Package.st` authoring, `ManifestBuilder`, `LibraryManifest` / `ApplicationManifest`, `ManifestVocabularyError` / `ManifestError`, the literal micro-format, and the `IndexEntryWriter` / `IndexEntryReader` pair. All classes in the `Parley` namespace.

---

## 1. Trust Framing (read first)

The builder is a **vocabulary, a validator, and a serialization gateway** — not a security sandbox. A `Package.st` author owns their file and machine; nothing prevents arbitrary Smalltalk in it and nothing needs to. **The security boundary is the static index entry:** Parley never executes, compiles, or evaluates third-party `Package.st` files, and never passes any third-party content — index entries and lockfiles included — through `Behavior>>evaluate:` or any compiler pathway. Static artifacts are read exclusively by `IndexEntryReader` (§5). Do not build an evaluation sandbox; the architecture deliberately doesn't need one.

---

## 2. `Package.st` Authoring Convention

The file's outermost expression is a message send to the well-known entry point, passing a one-argument block:

```smalltalk
"Package.st"
Parley define: [:pkg |
    pkg
        name: 'kernel-json';
        version: '0.3.1';
        summary: 'A JSON reader/writer speaking pure message sends';
        author: 'Leonardo';
        license: 'MIT';
        fileIns: #('Reader.st' 'Writer.st' 'Extensions.st');
        dependency: 'kernel-streams' constraint: '>=1.0 <2.0';
        dependency: 'kernel-strings' constraint: '^0.4.2' ]
```

`Parley class >> define:` creates a fresh `ManifestBuilder`, evaluates the block with it, sends `build`, and answers the immutable manifest. No compiler tricks, no global-binding gymnastics; an author can run `gst Package.st` and inspect the result live.

> **Entry-point resolution on GNU Smalltalk 3.2.5 (issue #3):** the global `Parley` is the namespace object, and 3.2.5 namespaces treat unknown keyword sends as binding setters — they cannot host `define:` without a kernel extension. The entry point is therefore the class `Parley.Parley`, a thin gateway defined *inside* the Parley namespace: wherever the Parley namespace is current, the token `Parley` resolves to that class and the syntax above works verbatim. At raw Smalltalk top level the token still names the namespace, so bare `gst Package.st` is not yet supported; the author-facing evaluation path (Phase 3 CLI/publish tooling) files `Package.st` in with the Parley namespace current.

---

## 3. `ManifestBuilder`

### 3.1 Character

The **one deliberately mutable object in Parley** — an *edge object* (airlock), not domain. It exists for the duration of one `define:` evaluation, accumulates raw declarations, and is discarded the moment `build` answers. The zero-setters rule governs the domain model; the builder stands in front of it.

### 3.2 Vocabulary — explicit methods, category `'manifest vocabulary'`

Each vocabulary word is a **real method with a method comment** (comments become hover docs in tooling; senders/implementors/completion must work on the DSL surface). **Never implement vocabulary through `doesNotUnderstand:`.**

| Selector | Records | Notes |
| --- | --- | --- |
| `name:` | package name string | required |
| `version:` | version string | required; parsed at `build` |
| `summary:` | one-line description | optional |
| `author:` | author string | optional |
| `license:` | license identifier | optional |
| `fileIns:` | array of `.st` file names | required, non-empty; **order is semantic** (§6) |
| `dependency:constraint:` | `(name, constraintString)` pair | constraint parsed at `build` |
| `dependency:` | `(name, '*')` | sugar for an unconstrained dependency |

Vocabulary messages **record raw strings only** — no parsing mid-cascade. All parsing and validation happens in `build` so the author receives one complete error report per run.

### 3.3 `doesNotUnderstand:` — the error path ONLY

```smalltalk
doesNotUnderstand: aMessage [
    ^ManifestVocabularyError
        signalUnknown: aMessage selector
        vocabulary: self class vocabulary
]
```

`ManifestBuilder class >> vocabulary` answers the selectors by **reflecting over the `'manifest vocabulary'` method category**, so the error's "known messages" list is derived from the actual methods and cannot drift. The error carries: the unknown selector, a nearest-selector suggestion (cheap heuristic — same keyword count and shared prefix; do not over-engineer), and the full vocabulary. It is a live, inspectable domain error object, rendered as:

> `Package.st` sent `#depends:on:` — not part of the manifest vocabulary. Did you mean `#dependency:constraint:`? Known messages: `name:`, `version:`, `summary:`, `author:`, `license:`, `fileIns:`, `dependency:constraint:`, `dependency:`.

### 3.4 `build` — batch validation

Performs, in one pass, collecting ALL problems before failing:

1. Required fields present (`name`, `version`, non-empty `fileIns`).
2. Package name format: lowercase letters, digits, hyphens; must start with a letter.
3. `version` parses via `Version fromString:`.
4. Every dependency constraint parses via `VersionConstraint fromString:`.
5. No duplicate dependency names; no self-dependency.

On any problems: signal **one `ManifestError`** carrying the full problem list (an author fixes a file per edit-run cycle, not per error). On success: answer an immutable `LibraryManifest`. Immutability begins at that exact instant.

---

## 4. Manifests

- **`LibraryManifest`** — name, version (`Version`), summary/author/license, fileIns (ordered), dependencies (collection of `Dependency` with **loose** constraints). Immutable; read-only accessors.
- **`ApplicationManifest`** — a `LibraryManifest` plus the application's lockfile association. Applications commit lockfiles; libraries never ship pins as constraints (the Bundler Gemfile/gemspec lesson — prevents graph deadlock).
- `LibraryManifest class >> fromIndexEntry:` reconstructs a manifest from a parsed index entry; constraints re-parse through `VersionConstraint fromString:`, landing in the exact same normalized objects the builder produced. **Author path and resolver path converge on identical values** — provable via the round-trip law (§7).

---

## 5. The Literal Micro-Format

### 5.1 Accepted grammar (COMPLETE — everything else is rejected)

```
artifact  := array
array     := '#(' element* ')'
element   := array | string | symbol | integer
string    := '\'' chars '\''          ('' escapes a quote)
symbol    := '#' identifier | '#\'' chars '\''
integer   := digit+                    (non-negative)
```

Whitespace (space, tab, newline) separates elements. **Rejected with a positioned parse error** (token + character position): identifiers outside symbols, floats, scaled decimals, negative numbers, characters (`$a`), booleans, `nil`, byte arrays `#[…]`, brace arrays `{…}`, comments `"…"`, and any message-send syntax. The reader is a self-contained recursive-descent parser (target ~50 lines) and **never delegates to the compiler**.

### 5.2 Index entry schema (`#'parley-index'`, format 1)

Fixed key order; ALL keys always present (empty string / empty array when unset):

```smalltalk
#(#'parley-index' 1
  #name 'kernel-json'
  #version '0.3.1'
  #summary 'A JSON reader/writer speaking pure message sends'
  #author 'Leonardo'
  #license 'MIT'
  #fileIns #('Reader.st' 'Writer.st' 'Extensions.st')
  #dependencies #(
      #('kernel-streams' '>=1.0.0 <2.0.0')
      #('kernel-strings' '>=0.4.2 <0.5.0'))
  #archive #('kernel-json-0.3.1.star' #sha256 'ab12…'))
```

### 5.3 Lockfile schema (`#'parley-lock'`, format 1)

```smalltalk
#(#'parley-lock' 1
  #root 'my-app'
  #packages #(
      #('kernel-json' '0.3.1' #sha256 'ab12…')
      #('kernel-streams' '1.4.0' #sha256 'cd34…')))
```

`packages` sorted by name; exact versions only (three components), no constraints.

### 5.4 Canonical rendering (byte-stability)

1. Format tag + version first, always.
2. Fixed key order per schema; all keys present.
3. `dependencies` and lockfile `packages` sorted by package name.
4. Constraints rendered via `VersionConstraint printString` (normal form is the wire form); versions via `Version printString` (always three components).
5. Single spaces between elements; no trailing whitespace; single trailing newline.
6. `fileIns` — **preserved order, never sorted** (§6).

---

## 6. Two Ordering Rules (both deliberate — do not "fix" either)

| Field | Rule | Why |
| --- | --- | --- |
| `fileIns` | **preserve author order exactly** | maps to `gst-package` load sequence; load order is semantic in Smalltalk |
| `dependencies` / lock `packages` | **sort by name** | order is meaningless; canonical form and byte-stability demand sorting |

---

## 7. `IndexEntryWriter` / `IndexEntryReader`

Serialization does **not** live on the builder or the manifest. The writer/reader are a dedicated pair owning the micro-format for both schemas (index + lock, distinguished by tag).

- `IndexEntryWriter` — `write: aManifest on: aStream` / `writeLock: aResolution on: aStream`, applying §5.4 exactly.
- `IndexEntryReader` — `readFrom: aStream` → parsed structure → `LibraryManifest fromIndexEntry:` / lock value. Unknown format tag or unsupported format version is a clear error (forward-evolution point).
- **Round-trip identity law (SUnit, required):** *build → write → read = build* — the pair composes to the identity on manifests, verified in complete isolation (no builder, no resolver).

## 8. SUnit Requirements for This Doc

- Round-trip identity (randomized manifests: random names, versions, constraints, fileIns orders).
- Byte-stability: writing the same manifest twice yields identical bytes; permuting `dependency:` declaration order in `Package.st` yields identical bytes; permuting `fileIns:` DOES change bytes (order is semantic).
- Reader rejection: one test per rejected token class (float, identifier, character, boolean, `nil`, comment, negative integer, byte array, message send), each asserting a positioned error.
- Builder: vocabulary error carries selector/suggestion/vocabulary; `build` batches multiple problems into one `ManifestError`; duplicate and self-dependency rejection; vocabulary reflection matches the `'manifest vocabulary'` category exactly.
