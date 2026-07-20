# Parley Design — Publish & the Git Index Source

> **Scope:** `Publisher`, `PublishError` (`src/publish/` — a NEW directory), `GitIndexSource` (`src/source/`), the archive-carrying `IndexEntryWriter` selector, the `CLI` `publish` verb, and the schema-shape entry validation folded in from the Sprint 4 ruling (`DirectorySource` scan). This is the Phase 4 opener (Sprint 7, issue #9). All classes in the `Parley` namespace; structural immutability applies throughout (class-side construction; zero public setters; no value equality on the new classes — the decision-23 precedent). `RegistrySource` is **not** in this document or this phase: it is deferred entirely with registry hosting (master plan §8 decision 27).

Publishing closes the authoring loop: the manifest an author wrote with the Doc B §2 vocabulary becomes a static index entry plus a toolchain-built archive that any `PackageSource` can serve and any Sprint 5/6 consumer can install and execute. The trust boundary (architecture §2.2) is untouched: publish runs on the **author's own machine over the author's own manifest** — the one `Package.st` evaluation context that has always been sanctioned — and its product is exactly the static, literals-only artifact every other machine consumes.

## 1. `Publisher` — manifest → archive → entry

- `Publisher class >> manifest: aManifest in: aWorkingDir to: aDestDir runner: aProcessRunner` — the four collaborators held immutably. `aManifest` is the already-loaded `LibraryManifest` (the CLI loads it through `ManifestFile`; `Publisher` never reads `Package.st` itself); `aWorkingDir` is where the manifest's `fileIns` live; `aDestDir` is the index directory being published into.
- `publish` — the pipeline below. On success answers the archive's **sha256 hex digest**; on any problem signals **one `PublishError`**.

The pipeline, in order:

1. **Refusal first (releases are immutable):** if `<dest>/<name>-<version>.st` already exists, signal one `PublishError` whose single problem names the package and version (exact wording pinned in RED). Nothing else is checked, nothing is written — republishing is a category error, not a batch member.
2. **Pre-flight (batched):** every manifest `fileIn` must exist in `aWorkingDir`. Missing ones batch into one `PublishError`, problems in sorted filename order (the house style). No process has been spawned yet.
3. **Stage:** create `<dest>/.parley-publish-stage/`, write the composed `package.xml` (§1.1) and a byte-exact copy of each `fileIn` into it. Staging is **destination-confined** (the Doc D §4 precedent); the stage directory is invisible to a `DirectorySource` scan (which reads only the directory's files, not subdirectories).
4. **Build:** run `gst-package --target-directory <dest>/.parley-publish-stage <dest>/.parley-publish-stage/package.xml` through the runner — the toolchain builds `<stage>/<name>.star` (it owns the archive format; Parley never zips). A nonzero exit is **fail-stop**: one `PublishError` whose single problem carries the exact command line and exit code (wording pinned in RED). The stage is left in place for inspection — fail-stop never cleans up behind an error.
5. **Digest and land:** read the star's bytes, digest through the settled `Sha256`, write `<dest>/<name>-<version>.star` (the bytes) and `<dest>/<name>-<version>.st` (the entry, through the §2 writer selector, carrying that filename and digest), then remove the stage. The filenames follow the Doc B §5.2 example (`kernel-json-0.3.1.star`); they are storage convention only — entry identity remains contents-not-filename (Sprint 4), and registration re-stages archives under `<name>.star` per Doc D §4.

### 1.1 The composed `package.xml`

`package.xml` is composed **from the manifest** — the manifest is the single source of truth, and decision 26's name equality holds by construction (the star's internal name IS the manifest name; `ManifestBuilder` §3.4 already guarantees the lowercase format, which the toolchain accepts). The composition is canonical and byte-pinned in RED:

```xml
<package>
  <name>NAME</name>
  <filein>FILE1</filein>
  <filein>FILE2</filein>
</package>
```

— one `<filein>` per manifest `fileIn`, **in manifest order** (load order is semantic), two-space indentation, single trailing newline. Nothing else of the manifest enters `package.xml`: versions, dependencies and prose live in the index entry; the archive is a load unit, not a metadata carrier.

## 2. The published entry (`IndexEntryWriter`)

- `IndexEntryWriter class >> write: aManifest archive: aFileName sha256: aHexDigest on: aStream` — the **one new selector** (a declared settled-class exception): identical §5.2 canonical rendering to the settled `write:on:`, except `#archive #('<aFileName>' #sha256 '<aHexDigest>')` in place of `#archive #()`. The settled `write:on:` is untouched and its output stays byte-identical — the Sprint 1 oracles keep passing unchanged.
- The settled `IndexEntryReader` already consumes populated `#archive` fields (Sprint 4) — round-trip needs no reader change.

## 3. `GitIndexSource` — a git checkout as an index directory

A `PackageSource` whose index is a git repository of entry files. Pure composition — no kind-branching, no scan logic of its own:

- `GitIndexSource class >> repo: aRepoPath cache: aCacheDir runner: aProcessRunner` — the repo location (any path/URL `git clone` accepts; the laws use local paths only — no network in tests, ever), the local checkout directory, and the one process seam. Holds an inner `DirectorySource on: aCacheDir` immutably (construction is pathname-passive; `DirectorySource` touches the disk only when scanned).
- `snapshot` — **the source's one I/O moment, git moment included**: when `aCacheDir` does not exist, run `git clone <repo> <cache>`; when it does, run `git -C <cache> pull --ff-only`; then answer the inner source's `snapshot`. A nonzero git exit signals one **`SourceError`** whose single problem carries the exact command line and exit code (wording pinned in RED) — the settled batched-scan error class; a broken transport and a broken entry are both "this source cannot answer".
- `versionsOf:`, `manifestFor:version:`, `fetch:version:` — pure delegation to the inner `DirectorySource`. `fetch:version:` reads the **existing** checkout and runs no git command: the metadata/archive split holds — resolution consumed the snapshot that the one git moment produced, and install-time fetch must see exactly those bytes, not a moved branch.
- Archives live in the repository beside the entries, exactly as in any directory source.

## 4. Schema-shape entry validation (`DirectorySource` — the Sprint 4 gap, closed)

The Sprint 4 ruling: a literal-valid, tag-valid entry missing §5.2 schema keys fails the scan with a raw error — fail-stop, never fail-wrong — until validation lands here. It lands in the **scan** (a declared settled-class exception on `DirectorySource`); the reader stays a pure literals-only parser.

After the settled tag/format checks, each entry must have the §5.2 shape: the eight keys `#name #version #summary #author #license #fileIns #dependencies #archive`, present, **in the fixed order**, each with its schema kind — strings for the five scalar fields; `fileIns` an array of strings; `dependencies` an array of `#(name constraint)` string pairs; `archive` either `#()` or `#(<filename> #sha256 <hex>)`. A violation is **one problem naming the file and the defect** (exact wordings pinned in RED), batched with every other scan problem into the **one `SourceError`** in sorted-filename order (Sprint 4 semantics, unchanged). Directory sources stop being operator-curated: a malformed entry is now a diagnosis, not a crash.

## 5. The `CLI` `publish` verb

- Argv grammar gains `publish <dir>` (a declared settled-class exception on `CLI`; the pinned usage verbs line was amended at staging, operator-side): `<dir>` is the destination index directory. `publish` with no directory answers the usage lines, exit `2`. No source collaborator is required.
- The verb: `ManifestFile load:` the working directory's `Package.st`, then `Publisher manifest:in:to:runner: publish`. Success answers one line, exit `0` (wording pinned in RED — it names the package and version); a `PublishError`'s problems become the lines, exit `1`; a `ManifestError` reports as the other verbs do.
- The wrapper (`bin/parley-main.st`) needs no change beyond what the argv already carries.

## 6. SUnit Requirements for This Doc

- **`Publisher`:** the real build (a published star the toolchain accepts and the curated child loads); the entry byte-oracle (composed §5.2 bytes carrying the runtime digest); the composed `package.xml` byte-oracle; refusal-first (an existing entry refuses with the pinned problem and the destination is byte-unchanged); pre-flight batching (missing `fileIns`, sorted, nothing written, **no process spawned** — provable with a recording runner); build fail-stop (a runner answering nonzero: the pinned command-and-code problem, nothing landed in the destination); the stage is gone after success and destination-confined always.
- **Writer:** the new selector's byte-pinned oracle; the settled `write:on:` output byte-unchanged (a declared regression guard — it passes in red).
- **`GitIndexSource`:** first `snapshot` clones (fixture repositories are built locally through `ProcessRunner`, with committer identity supplied per-command via `git -c user.name=… -c user.email=…` — the developer's git config is never touched); a later `snapshot` sees upstream growth through `--ff-only` pull; a git failure is the pinned one-problem `SourceError`; `fetch:version:` answers archive bytes from the checkout without running git (provable: grow upstream after snapshot — fetch still answers the snapshotted bytes).
- **Schema validation:** each violation kind (missing key, wrong order, wrong kind, malformed `#archive`) is one pinned problem; multiple bad files batch into one `SourceError` in sorted-filename order alongside a clean directory still scanning (asserted in the same law via a second directory); the settled parse/tag errors are unchanged.
- **`CLI`:** `publish <dir>` success line and exit codes; the refusal surfacing as lines exit `1`; `publish` without a directory answering usage exit `2` (**passes in red** — the settled CLI already answers usage for unknown shapes — declared).
- **End-to-end (the sprint's exit):** author A publishes into a directory; author B's working dir depends on the published package; `install` + `exec` prove the class visible in B's curated child — **the ecosystem loop closes**. A second e2e leg resolves the same published index through a `GitIndexSource` clone.
- **Hygiene:** every fixture path (working dirs, destinations, repos, caches, stores, targets) under `tmp/`, unique per test, removed recursively in tearDown; `tmp/` empty or absent after a clean run; the developer image never mutated; no network, ever — git operates on local paths only.
