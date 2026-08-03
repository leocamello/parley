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

### 2.1 Machine editing: recognize or refuse, never re-render (Sprint 13)

`parley add <pkg> <constraint>` has to change a file **the author owns and Parley did not write**. Two mechanisms were on the table and one of them is disqualified by the trust framing this document opens with.

**A `ManifestBuilder` round-trip is not available.** Loading the manifest and re-rendering `Package.st` from the model would be trivial to build and is wrong for a reason that has nothing to do with taste: `Package.st` is **executable Smalltalk**, not a serialization of the manifest. The manifest is a *projection* of the file, and the projection is lossy in both directions — it does not carry the author's comments, their formatting, the reason they pinned a version, or any Smalltalk they wrote that is not vocabulary. Re-rendering would silently replace a program with a different program that happens to build an equal manifest, and would do so most destructively to the most careful authors. It would also invert this project's central boundary: canonical byte-stable rendering is a **law** for index entries and lockfiles precisely because Parley *owns* those artifacts (§5.4). `Package.st` is on the other side of that line. Parley never rewrites what it did not write.

**The mechanism is a textual insertion into a recognized shape, and the refusal is half the feature.** `add` recognizes the canonical cascade — one `Parley define: [:pkg | … ]` whose clauses are vocabulary sends — and inserts one `dependency:constraint:` clause, preserving every other byte of the file including comments, blank lines and indentation. When it does **not** recognize the shape (no `define:`, more than one, a cascade it cannot parse, anything computed), it changes nothing and answers **one line naming the exact text the operator should paste and where**. This is the settled grammar of every other boundary in the tool: fail-stop, never fail-wrong (Doc F §4.1), and name the repair (§8 decisions 31 and 44). An editor that guesses at an unfamiliar file is how a package manager earns a reputation for eating manifests; one that hands back a line to paste has cost the operator five seconds.

**A textual edit is checked semantically, not hoped at.** After writing, `add` re-loads the file through the settled `ManifestFile load:` and asserts the manifest now declares the new dependency and is otherwise **equal to the manifest loaded before the edit**. Parley already owns the reader that decides what a `Package.st` means, so the edit is verified by the same authority that will consume it. If the reload disagrees — or fails to parse at all — the original bytes are restored and the operator sees the refusal, never a half-edited file.

**`add` is atomic: the manifest and the lock move together, or neither moves.** A resolution that fails *after* the edit (the new dependency is unsatisfiable against the held pins) restores the original `Package.st` and the lock as it stood, so a failed `add` leaves a project byte-identical to how it started. The alternative — a manifest naming a dependency the lock does not pin — is precisely the state `PinVerification` exists to report as broken, and it would have been manufactured by the tool.

**Fetched archives are outside that claim, and deliberately so** (narrowed at the Sprint 13 close-out; §8 decision 49). An archive a failed `add` had already fetched may remain in the content-addressed store, where it is **inert until a lock pins it**: it is hash-verified, it is re-used rather than re-fetched on the next run, and no verb reports store contents, so it is not observable project state. The pair above is what the atomicity claim is *for* — it is the pair that can manufacture the `PinVerification` failure — and the store cannot produce that state however it is left. Erasing an archive to satisfy a wider sentence would add machinery to delete something inert that another pin may legitimately share. If the store ever becomes observable as state — pruning, a size budget, a verb that reports contents — this narrowing is what reopens.

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

`packages` sorted by name; exact versions only (three components), no constraints. Each `#sha256` is **64 lowercase hex characters, or the empty string** — validated as that shape from Sprint 11 (§7.1, §8 decision 42), so a mistyped digest is a lockfile diagnosis rather than a corruption report from the store. The empty string is not a mistyped digest but **recorded absence**: it is what the writer renders for a pin whose entry declares `#archive #()`, and it keeps reaching the settled `Installer` diagnosis (`no published archive — the resolution carries an empty sha256`) rather than being rejected at the lock boundary. A boundary that refused it would refuse Parley's own output.

### 5.4 Canonical rendering (byte-stability)

1. Format tag + version first, always.
2. Fixed key order per schema; all keys present.
3. `dependencies` and lockfile `packages` sorted by package name.
4. Constraints rendered via `VersionConstraint printString` (normal form is the wire form); versions via `Version printString` (always three components).
5. Single spaces between elements; no trailing whitespace; single trailing newline.
6. `fileIns` — **preserved order, never sorted** (§6).

### 5.5 Retirement schema (`#'parley-retired'`, format 1) — Sprint 10

The third schema, and the answer to "where does a retirement signal live" (§8 decision 37). A retired release stays **fetchable** — an existing lock that pins it keeps installing, because breaking a build that already resolved is never the right response to a late-discovered problem — and is **excluded from fresh resolution**, carrying a reason the author wrote.

```smalltalk
#(#'parley-retired' 1
  #retirements #(
      #('kernel-json' '0.3.1' 'security: CVE-2026-1234, upgrade to 0.3.2')
      #('kernel-old' '1.0.0' 'deprecated: renamed to kernel-new')))
```

`retirements` sorted by name then version (§5.4 rule 3); each tuple is exactly `#(<name> <version> <reason>)`, three Strings, the version exact and three-component.

**The signal is an index-level record, never a key inside the entry.** A `#retired` key in the `#'parley-index'` artifact would require *rewriting a published entry*, which contradicts refusal-first publishing (Doc F §1) and changes bytes that are already content-addressed and possibly signed. Retirement is an assertion the index owner makes **about** a release, not a property **of** it, and the schema says so by keeping them in separate artifacts.

**No format-version bump.** `#'parley-index' 1` and `#'parley-lock' 1` are untouched; this is an additive third tag, and the reader's tag whitelist (§7) grows by one. The cost is one-directional and worth naming plainly: an index that adopts retirements becomes **unreadable to pre-Sprint-10 Parley**, whose scan rejects the unknown tag. That is the safe failure direction — a stale client refuses rather than silently resolving a package the owner retired — but it is exactly why this schema was time-critical: every release published before it lands is another deployed client that a retirement-bearing index will stop. Sprint 10 exists to close that window while it is still cheap.

**Contents-not-filename identity applies** (Doc C §1, Sprint 4). A retirement record is any file in the index whose artifact carries the tag — the scan dispatches on the tag it read, never on the filename — and an index may hold several, merged. This is the same rule that already lets an entry file be named anything.

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
- `IndexEntryReader` — `readFrom: aStream` → parsed structure → `LibraryManifest fromIndexEntry:` / lock value / retirement record. Unknown format tag or unsupported format version is a clear error (forward-evolution point). The whitelist is `#'parley-index'`, `#'parley-lock'` and — from Sprint 10 — `#'parley-retired'` (§5.5); adding a tag is a **declared settled-class exception**, never a silent widening, because "unknown tag is an error" is what makes the forward-evolution point real.

**The rejection message must name every tag the whitelist holds** (Sprint 10 RED review). It reads `unknown format tag <X>: this Parley reads #'parley-index', #'parley-lock' and #'parley-retired' artifacts` — widening the whitelist without widening the sentence would make the forward-evolution point state something false, and this message is the *only* place an operator learns what this build accepts. No settled law pins its bytes (`MicroFormatTest` asserts only that it names the offending tag and differs from the version message), so the sentence stays free to grow with the whitelist — but it must grow **in the same change**.
- **Round-trip identity law (SUnit, required):** *build → write → read = build* — the pair composes to the identity on manifests, verified in complete isolation (no builder, no resolver).

### 7.1 `SchemaShape` — the shapes the schemas are made of (Sprint 11)

`Parley.SchemaShape` (`src/manifest/`) holds the value predicates both schema validators ask, as class-side messages: `isString:`, `isStringArray:`, `isHexDigest:`.

It exists because `CLI>>isLockString:` and `DirectorySource>>isSchemaString:` were the *same* predicate in two classes — duplicated deliberately in Sprint 10, because sharing it then meant adding a public selector to a settled class. Hex-digest validation (§8 decision 42) is the third caller, which is exactly the trigger Sprint 10 named for fixing it.

- `isHexDigest:` — exactly **64 lowercase hex characters**, the shape a sha256 renders as under §5.4. It validates the *shape*, never the truth: whether a digest matches its bytes is `ContentStore>>verifyHash:` and nothing else.
- It holds no state, decides nothing, and answers questions about values handed to it — not a manager, and not a place for future "helpers" to accumulate. A predicate belongs here when **two** schema validators need it; one caller keeps it private, as before.

## 8. SUnit Requirements for This Doc

- Round-trip identity (randomized manifests: random names, versions, constraints, fileIns orders).
- Byte-stability: writing the same manifest twice yields identical bytes; permuting `dependency:` declaration order in `Package.st` yields identical bytes; permuting `fileIns:` DOES change bytes (order is semantic).
- Reader rejection: one test per rejected token class (float, identifier, character, boolean, `nil`, comment, negative integer, byte array, message send), each asserting a positioned error.
- Builder: vocabulary error carries selector/suggestion/vocabulary; `build` batches multiple problems into one `ManifestError`; duplicate and self-dependency rejection; vocabulary reflection matches the `'manifest vocabulary'` category exactly.
