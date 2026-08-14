# Parley Design — Publish & the Git Index Source

> **Scope:** `Publisher`, `PublishError` (`src/publish/` — a NEW directory), `GitIndexSource` (`src/source/`), the archive-carrying `IndexEntryWriter` selector, the `CLI` `publish` verb, the schema-shape entry validation folded in from the Sprint 4 ruling (`DirectorySource` scan), and — from Sprint 14 — `SparseIndexSource` (§7, `src/source/`). This is the Phase 4 opener (Sprint 7, issue #9). All classes in the `Parley` namespace; structural immutability applies throughout (class-side construction; zero public setters; no value equality on the new classes — the decision-23 precedent). `RegistrySource` is **not** in this document or this phase: it is deferred entirely with registry hosting (§8 decision 27).

Publishing closes the authoring loop: the manifest an author wrote with the Doc B §2 vocabulary becomes a static index entry plus a toolchain-built archive that any `PackageSource` can serve and any Sprint 5/6 consumer can install and execute. The trust boundary (architecture §2.2) is untouched: publish runs on the **author's own machine over the author's own manifest** — the one `Package.st` evaluation context that has always been sanctioned — and its product is exactly the static, literals-only artifact every other machine consumes.

## 1. `Publisher` — manifest → archive → entry

- `Publisher class >> manifest: aManifest in: aWorkingDir to: aDestDir runner: aProcessRunner` — the four collaborators held immutably; construction is **pathname-passive** (no I/O, no process — a publisher can be built over paths that do not exist yet). `aManifest` is the already-loaded `LibraryManifest` (the CLI loads it through `ManifestFile`; `Publisher` never reads `Package.st` itself); `aWorkingDir` is where the manifest's `fileIns` live; `aDestDir` is the index directory being published into.
- `publish` — the pipeline below. On success answers the archive's **sha256 hex digest**; on any problem signals **one `PublishError`**.
- `packageXml` — the §1.1 composition as a **pure value** (no I/O, no process). It exists because a successful `publish` removes the stage, so the canonical bytes would otherwise be observable only through the failure path; step 3 writes exactly these bytes into the stage. (Operator ruling, Sprint 7 Gate A.)

The pipeline, in order:

0. **Refusal first (a release cannot depend on somebody's laptop — Sprint 21, §8 decision 69):** a manifest declaring a **path dependency** signals one `PublishError` whose single problem names the dependency and its declared path (exact wording pinned in RED). Nothing is checked after it, nothing is written, no process is spawned. Dev dependencies do **not** refuse — they are simply never serialized (Doc B §5.2), and the entry's byte-identity with and against them is law.
1. **Refusal first (releases are immutable):** if `<dest>/<name>-<version>.st` already exists, signal one `PublishError` whose single problem names the package and version (exact wording pinned in RED). Nothing else is checked, nothing is written — republishing is a category error, not a batch member.
2. **Pre-flight (batched):** every manifest `fileIn` must exist in `aWorkingDir`. Missing ones batch into one `PublishError`, problems in sorted filename order (the house style). No process has been spawned yet.
3. **Stage:** create `<dest>/.parley-publish-stage/` — sweeping a stage an earlier failed build left behind, so staging is deterministic and publish stays re-runnable; "fail-stop never cleans up" governs the run that *failed*, not the next one — then write the composed `package.xml` (§1.1) and a byte-exact copy of each `fileIn` into it, **preserving each fileIn's relative subdirectory path and creating its parent directories through `PathGuard`** (Sprint 22, §8 decision 86 — probed 2026-08-14: `gst-package` builds a star from a nested `<filein>`, creating the nested staging directories in its own working area, and the settled child composition loads it). Staging is **destination-confined** (the Doc D §4 precedent); the stage directory is invisible to a `DirectorySource` scan (which reads only the directory's files, not subdirectories).
4. **Build:** run `gst-package --target-directory <dest>/.parley-publish-stage <dest>/.parley-publish-stage/package.xml` through the runner — the toolchain builds `<stage>/<name>.star` (it owns the archive format; Parley never zips). A nonzero exit is **fail-stop**: one `PublishError` whose single problem carries the exact command line and exit code (wording pinned in RED). The stage is left in place for inspection — fail-stop never cleans up behind an error.
5. **Digest and land:** read the star's bytes, digest through the settled `Sha256`, write `<dest>/<name>-<version>.star` (the bytes) and `<dest>/<name>-<version>.st` (the entry, through the §2 writer selector, carrying that filename and digest), then remove the stage. The filenames follow the Doc B §5.2 example (`kernel-json-0.3.1.star`); they are storage convention only — entry identity remains contents-not-filename (Sprint 4), and registration re-stages archives under `<name>.star` per Doc D §4.

Step 1 is preceded by one **destination check** (Sprint 8, closing the Sprint 7 ruled gap): if `aDestDir` does not exist or is not a directory, signal one `PublishError` whose single problem names it (exact wording pinned in RED, following the `DirectorySource` `'<path>: missing or unreadable directory'` precedent applied to the write side). Publish **does not create** the destination — an author publishing into a directory that is not there has made an error worth naming, and creating it silently would make a typo indistinguishable from an intent. Nothing is checked after it, nothing is written, no process is spawned.

**And the destination must be WRITABLE, not merely present** (§8 decision 59, Sprint 17). The check above answers a destination that is absent or is not a directory; a destination that exists, is a directory, and cannot be written was left to the write itself, which on 3.2.5 signals a kernel `FileError: Permission denied` — outside `PublishError`, so it reached the §4.2 boundary as `internal error: … - this is a defect in Parley, not in your project` at exit `70`, **never naming the destination**. Probed through the shipped binary at the Sprint 16 close-out. So the destination check also requires `isDirectory and: [isWriteable]` (3.2.5's spelling — there is no `isWritable`), answering the same one-problem `PublishError` naming the path and a remedy. This is the same rule as decision 56 with the direction reversed, and it is the rule Doc F already lived by in spirit: **`publish` refuses rather than half-creating**, so refusing before the stage exists is the only refusal consistent with step 3.

**A publish refused by the destination check leaves the destination exactly as it found it.** The claim is scoped to *this* refusal deliberately, and the scoping is the point: §1 step 3 rules that *"fail-stop never cleans up" governs the run that failed*, so a refusal raised later — a build that exits nonzero at step 4 — leaves the stage directory behind for inspection. Both are correct, and they are different promises. What §8.3 pins byte-for-byte is the **sparse publish's** atomicity across entry, archive and listing; what this paragraph adds is that the destination check fires early enough that there is nothing to restore. The check is a **precheck**, run before step 1 and therefore before any part of the write is attempted: no stage directory, no `package.xml`, no `.star`, no entry, and no process spawned. That is what makes the refusal assertable on the *artifact* rather than on the exit code — the scenario asserts the destination is still empty, which an implementation that created the stage and then failed would not satisfy even while answering the same line and the same code. It is also why the check cannot be left to the write: by the time a write fails, step 3 has already created the stage. Like Doc E §4.1's write boundaries, the destination check runs through `Parley.PathGuard` — the single site performing file I/O (§8 decisions 59 and 60) — and it is a **precheck, not a lock**: a destination can become unwritable between the check and the landing of step 5, and Parley makes no claim about that window. What it does claim is that such a failure still answers this section's own `PublishError` naming the destination, at exit `1`, never the exit-`70` sentence blaming Parley.

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
- **Reachable from the binary** (Sprint 9): `CommandLine`'s `--git <repo>` flag builds one, with the cache at `<workingDir>/.parley/git/<sha256 of the repo location>` (Doc E §4.2). Until then `GitIndexSource` was built, lawful and unreachable — a source class inside a directory the `bin/` drift law *did* name, which is why Sprint 9 adds a second drift law over the flag table rather than widening the first.

## 4. Schema-shape entry validation (`DirectorySource` — the Sprint 4 gap, closed)

The Sprint 4 ruling: a literal-valid, tag-valid entry missing §5.2 schema keys fails the scan with a raw error — fail-stop, never fail-wrong — until validation lands here. It lands in the **scan** (a declared settled-class exception on `DirectorySource`); the reader stays a pure literals-only parser.

After the settled tag/format checks, each entry must have the §5.2 shape: the eight keys `#name #version #summary #author #license #fileIns #dependencies #archive`, present, **in the fixed order**, each with its schema kind — strings for the five scalar fields; `fileIns` an array of strings; `dependencies` an array of `#(name constraint)` string pairs; `archive` either `#()` or `#(<filename> #sha256 <hex>)` — and from Sprint 11 the digest must be **64 lowercase hex characters** (`SchemaShape isHexDigest:`, Doc B §7.1), so a malformed digest is a batched scan problem rather than a later corruption report (§8 decision 42). A violation is **one problem naming the file and the defect** (exact wordings pinned in RED), batched with every other scan problem into the **one `SourceError`** in sorted-filename order (Sprint 4 semantics, unchanged). Directory sources stop being operator-curated: a malformed entry is now a diagnosis, not a crash.

### 4.1 Value-shape validation (Sprint 8 — the remainder of the gap, closed)

Shape validation asks whether a field is a string; it never asked whether the string means anything. So a `#version 'banana'` — shape-perfect — still escaped the scan as a raw error. That is the last place a malformed entry crashes instead of diagnosing, and it closes here.

After the §4 shape checks pass and **before** duplicate detection (which needs a parsed version to compare), each entry's values must parse:

- `#version` must parse as a `Version` (the settled `Version fromString:`);
- every `#dependencies` pair's constraint must parse as a `VersionConstraint` (the settled `VersionConstraint fromString:`).

A violation is **one problem naming the file and the unparseable value** (exact wordings pinned in RED), batched exactly as every other scan problem is. One problem per file, as always: the first defect the file has is the one the operator is told about. With this, **every** rejection path of the scan is a batched `SourceError` — a directory source has no remaining way to crash on third-party content.

The settled parsers are consumed unchanged and stay the single definition of what parses: validation asks them, it never re-implements them.

### 4.2 The scan dispatches on tag (Sprint 10 — retirement records)

With Doc B §5.5 the index holds two kinds of artifact, so the scan reads each `.st` file, takes the tag the reader already validated, and dispatches: `#'parley-index'` is a release entry (§4/§4.1 above, unchanged), `#'parley-retired'` is a retirement record. **Contents-not-filename identity** (Doc C §1) decides which is which — never the filename — so an index owner may name and split these files however they like, and several retirement records merge.

**The wrong-tag diagnosis is corrected with the dispatch** (Sprint 10 RED review). The settled scan told an operator `'<file>: wrong artifact tag #'parley-lock' - a source directory holds only #''parley-index'' 1 entries'`. From this sprint that sentence is **false**: a source directory legitimately holds retirement records too, and a diagnosis that misstates what is allowed sends the operator to delete a file that belongs there. It becomes:

```
<file>: wrong artifact tag #'parley-lock' - a source directory holds #'parley-index' 1 entries and #'parley-retired' 1 records
```

The two settled oracles pinning the old sentence (`DirectorySourceTest>>wrongTagProblemFor:`, `CommandLineFixtures>>wrongTagProblemFor:`) were amended by the operator at the RED review. This falls inside the declared `DirectorySource` exception — it is the same change as the dispatch, seen from the error path — and it is a *strengthening*: the branch now fires only for tags that are genuinely wrong.

A retirement record gets its own shape validation, exactly as an entry does: the single key `#retirements`, an Array of three-element `#(<name> <version> <reason>)` String tuples, each version parsing through the settled `Version fromString:` (§4.1's lesson). Violations are one problem naming the file and the defect, batched into the same one `SourceError` in sorted-filename order — a retirement record is index content like any other, and a malformed one is a diagnosis, not a crash.

The retirements collected are handed to the snapshot (Doc C §2.1), which is where they take effect. The scan's job ends at reading and validating; it makes no resolution decision. This is a **declared settled-class exception** on `DirectorySource`; `GitIndexSource` holds an inner `DirectorySource` and inherits retirement support without being touched at all.

## 5. The `CLI` `publish` verb

- Argv grammar gains `publish <dir>` (a declared settled-class exception on `CLI`; the pinned usage verbs line was amended at staging, operator-side): `<dir>` is the destination index directory. `publish` with no directory answers the usage lines, exit `2`. No source collaborator is required.
- The verb: `ManifestFile load:` the working directory's `Package.st`, then `Publisher manifest:in:to:runner: publish`. Success answers one line, exit `0` (wording pinned in RED — it names the package and version); a `PublishError`'s problems become the lines, exit `1`; a `ManifestError` reports as the other verbs do.
- The wrapper (`bin/parley-main.st`) needs no change beyond what the argv already carries.

## 6. SUnit Requirements for This Doc

- **`Publisher`:** the real build (a published star the toolchain accepts and the curated child loads); the entry byte-oracle (composed §5.2 bytes carrying the runtime digest); the composed `package.xml` byte-oracle; refusal-first (an existing entry refuses with the pinned problem and the destination is byte-unchanged); pre-flight batching (missing `fileIns`, sorted, nothing written, **no process spawned** — provable with a recording runner); build fail-stop (a runner answering nonzero: the pinned command-and-code problem, nothing landed in the destination); the stage is gone after success and destination-confined always.
- **Writer:** the new selector's byte-pinned oracle; the settled `write:on:` output byte-unchanged (a declared regression guard — it passes in red).
- **`GitIndexSource`:** first `snapshot` clones (fixture repositories are built locally through `ProcessRunner`, with committer identity supplied per-command via `git -c user.name=… -c user.email=…` — the developer's git config is never touched); a later `snapshot` sees upstream growth through `--ff-only` pull; a git failure is the pinned one-problem `SourceError`; `fetch:version:` answers archive bytes from the checkout without running git (provable: grow upstream after snapshot — fetch still answers the snapshotted bytes).
- **Schema validation:** each violation kind (missing key, wrong order, wrong kind, malformed `#archive`) is one pinned problem; multiple bad files batch into one `SourceError` in sorted-filename order alongside a clean directory still scanning (asserted in the same law via a second directory); the settled parse/tag errors are unchanged.
- **Value validation (Sprint 8):** an unparseable `#version` and an unparseable dependency constraint are each one pinned problem; they batch with the shape and settled problems in sorted-filename order; a shape-valid, value-valid directory still scans; and **no scan input crashes** — the settled parse/tag/shape/duplicate problem shapes are all unchanged around them.
- **`Publisher` destination check (Sprint 8):** a destination that does not exist is one pinned `PublishError` problem — nothing written, **no process spawned** (recording runner), and the destination is not created.
- **Retirement records (§4.2, Sprint 10):** a directory holding entries **and** a retirement record scans into a snapshot carrying both (dispatch proved by tag, not filename — the law names the retirement file something that looks like an entry); several retirement records merge; each malformed-record kind (missing `#retirements`, wrong tuple arity, non-String field, unparseable version) is one pinned problem batched into the same one `SourceError` in sorted-filename order alongside malformed *entries*; a retirement naming a release the index does not hold is accepted silently (an index owner may retire ahead of a deletion); and `GitIndexSource` inherits all of it **without being touched** — proved by running one retirement law through a git-cloned fixture.
- **`CLI`:** `publish <dir>` success line and exit codes; the refusal surfacing as lines exit `1`; `publish` without a directory answering usage exit `2` (**passes in red** — the settled CLI already answers usage for unknown shapes — declared).
- **End-to-end (the sprint's exit):** author A publishes into a directory; author B's working dir depends on the published package; `install` + `exec` prove the class visible in B's curated child — **the ecosystem loop closes**. A second e2e leg resolves the same published index through a `GitIndexSource` clone.
- **Hygiene:** every fixture path (working dirs, destinations, repos, caches, stores, targets) under `tmp/`, unique per test, removed recursively in tearDown; `tmp/` empty or absent after a clean run; the developer image never mutated; no network, ever — git operates on local paths only.

## 7. `SparseIndexSource` — per-package metadata over a process seam (Sprint 14, §8 decision 50)

A `PackageSource` whose index is served one package at a time — the shape crates.io migrated *to* and Hex.pm has always served — so a client fetches only the packages a resolution can reach, never the whole index. The transport is a process seam exactly as git is: `curl -sfS <url> -o <file>` through the settled `ProcessRunner`, which makes the whole source provable offline against a static directory tree over `file://`. No HTTP is implemented in Smalltalk, and no law ever contacts a network.

**The purity contract is untouched — the one I/O moment is a closure (§8 decision 50).** A sparse index cannot enumerate its packages, so `snapshot` walks instead of scanning: seed with the root manifest's declared names union the lock's pinned names when a lock exists — **handed to the source as values by the `CLI` through `seededWith:`, never read by the source itself** (§8 decision 51, Doc C §1.2); fetch each reachable package's version listing and the entries it names; read the names those entries declare; repeat to fixpoint; then answer one complete immutable `IndexSnapshot` over the reachable closure, before resolution begins. The resolver never learns this source exists. A name the closure never reached is indistinguishable from a package the index does not publish — decision 47's describability line governs it unchanged, so a listing miss for a declared name is an ordinary empty candidate set, never an error.

### 7.1 The index layout

One directory per package under the base, holding a version listing plus the settled artifacts, byte-identical to what `publish` writes:

```
<base>/<name>/versions.st                 the listing (§7.2)
<base>/<name>/<name>-<version>.st         the settled index entry (§2, Doc B §5.2)
<base>/<name>/<name>-<version>.star       the archive
```

`<base>` is any URL scheme curl accepts; the laws use `file://` absolute paths only. Entry identity remains contents-not-filename (Sprint 4) for the *scanned* artifacts — the entry bytes are exactly the §2 writer's, and the scan dispatches on tags as always. The listing is different and legitimately so: it is located by constructed URL — a fetch, not a scan — which is filename-as-address, the same way a package's directory is.

### 7.2 The listing — the fourth deserialization boundary

`versions.st` is one literal array in the house micro-format, the fourth schema — **defined in Doc B §5.6**, where the other three schemas live; this section owns only its consumption:

```
#'parley-listing' 1 #versions #('1.0.0' '1.1.0')
```

It is read ONLY by `IndexEntryReader readFrom:` — which makes `SparseIndexSource` the **fourth sender** and the fourth row of `CommandLine class >> deserializationBoundaries`; the drift law and the exact-enumeration guard (§8 decisions 35, 38, 43) move in the same commit, and the row arrives with its malformed-input law as the table's contract requires. Consuming the new tag means widening `IndexEntryReader class >> formatTags` — a **declared settled-class exception on `IndexEntryReader`** (Doc B §7's standing rule), whose rejection sentence grows in the same change by construction (`formatTagsText` renders it from the whitelist). A malformed listing — wrong tag, missing `#versions`, a non-String member, an unparseable version — is **one problem naming the file and the defect**, batched into the one `SourceError` (§4 conventions, unchanged).

### 7.3 The source

- `SparseIndexSource class >> base: aBaseUrl cache: aCacheDir runner: aProcessRunner` — pathname-passive construction (no I/O, no process); holds an inner `DirectorySource` over the cache's flat entries directory, the `GitIndexSource` composition applied a second time. **Three keywords, and the seeds are not among them** (§8 decision 51): a constructor that took the working directory, a manifest path or a lock path would make the source read the project, which is the one thing it must never do.
- `seededWith: someNames` — the closure's seed, arriving as **values** through the Doc C §1.2 protocol message; answers a new instance holding them, performing no I/O. The `CLI` supplies them, because it is the only object already holding both the loaded manifest and the read lock when `snapshot` is sent; the source itself never reads `Package.st` or `parley.lock`, never files in the author's Smalltalk, and can never signal `ManifestError` or `LockError` out of `snapshot`. A source that was never seeded has an empty seed set, so its closure reaches nothing and it answers an empty snapshot — the ordinary undescribed-name state of §8 decision 47, not an error.
- `snapshot` — the §8 decision 50 closure over the seeds, then the inner source's `snapshot` over the fetched entries. Listings are re-fetched every snapshot (they are the one mutable artifact — a publish appends to them); entry fetches are skipped on a cache hit, because releases are immutable (§1 step 1). Retirement records ride in the entries directory as they do everywhere else and reach the snapshot through the settled §4.2 dispatch, untouched. **Listings never land in the scanned entries directory — a prohibition, not an implication:** the settled scan rejects any artifact that is not index-or-retired with a wording pinned byte-for-byte by two settled laws (`DirectorySourceTest`, `SchemaValidationTest`), so a listing inside the scan would turn every snapshot into a `SourceError` and fail both. Listings are cached beside the entries directory, never in it.
- **The curl grounds, declared closed:** exit `0` with the bytes in the `-o` file is a hit; exit `37` (`file://` miss) and exit `22` (`-f` on an HTTP error response) are a miss; **any other** nonzero exit is one `SourceError` problem carrying the exact command line and exit code — the `GitIndexSource` transport-failure precedent verbatim. A missing *listing* is the undescribed-name case above; a missing *entry that a listing names* is an index defect, one problem naming both files, batched.
- `versionsOf:`, `manifestFor:version:` — pure delegation to the inner `DirectorySource`.
- **There is no catalogue, and `parley search` therefore refuses over this source** (§8 decision **80**, Sprint 20). §7.1's layout publishes one listing **per package** and no index-level list of package names, and a base URL cannot be enumerated over the transport — so the names this source can reach are exactly the seeded closure above, and nothing else exists to search. The tempting implementation is to search the snapshot the source already answers, and it is **wrong rather than partial**: that snapshot is the closure reachable from the operator's own manifest and lock, so `search` would return the packages they already depend on, omit the rest of the index in silence, and be indistinguishable from a complete result. `search` therefore answers **exit `1`** — the argv is well-formed and the transport is the limit — with one line naming the transport, why the question cannot be answered here, and the flags that can answer it. **`info` and `outdated` are unaffected**, and the distinction is the reason: both are keyed by names the caller already holds (`info` seeds with the package it was asked about, `outdated` with the lock's pins), which is exactly what `seededWith:` exists for. The capability is keyed off `CommandLine class >> sourceFlags`, the declaration the wiring already holds — **not** a new `PackageSource` protocol selector, which would change three settled sources to record a property of one.
- `fetch:version:` — the metadata/archive split holds: resolution consumed listings and entries only, and the archive is fetched here, at install time, into the cache and handed on for the settled hash verification (Doc D). A cache-hit archive is not re-fetched.

### 7.4 The cache and the flag

- `CommandLine` gains `--index <base>` as the **third row of `sourceFlags`** with its builder message — a declared settled-class exception on `CommandLine`, its first; the flag drift law is what forces this row to exist the moment the class ships, which is that law doing its job. The usage lines gain the flag; the verbs line is unchanged.
- The cache lives at `<workingDir>/.parley/index/<sha256 of the base URL>/` — the `--git` convention (Doc E §4.2) applied to the second remote source, listings beside a flat `entries/` directory the inner `DirectorySource` scans.

### 7.5 SUnit requirements for this section

- **The closure:** a transitive dependency (root → a → b, with b appearing in no manifest the operator wrote) is reached, fetched and resolvable; a package the closure cannot reach is **never fetched** (proved by counting the runner's curl invocations); the closure seeded from a lock reaches every pinned name; a dependency cycle in the metadata terminates at fixpoint. Every closure law constructs the source directly and sends `seededWith:` — the seeds are values, so no law needs a working directory, a `Package.st` or a `parley.lock` to exercise the walk.
- **The seeding protocol (§8 decision 51):** `seededWith:` performs no I/O — a source seeded against a runner that would signal on any spawn answers without spawning; it answers a **new** instance, the receiver still holding its previous seeds (the §2.2 `holding:` shape); a source that was never seeded answers an empty snapshot rather than an error; and `DirectorySource` and `GitIndexSource` answer `self`, their snapshots byte-for-byte unchanged by any seed — proved by a settled scan law re-run through `seededWith:`, which is what keeps the message on the protocol rather than on one class.
- **The `CLI` supplies the seeds:** every verb that consumes a snapshot resolves against a closure reaching the manifest's declared names and the lock's pinned names; and **`add` seeds the name it is adding** — `add <name> <constraint> --index <base>` against a base publishing `<name>` succeeds, because the snapshot precedes the edit and the added name is in neither file the seed set is otherwise built from. Without that seed the verb fails always with a `#noVersions` conflict, so the law is written to fail loudly on the exact regression it exists for.
- **The grounds:** hit, `file://` miss, and the error ground (a runner answering an undeclared exit code becomes the pinned one-problem `SourceError`) — each proved offline; a listing miss for a declared name resolves to the ordinary empty-candidate conflict, never a crash; an entry a listing names that is absent is the pinned index-defect problem.
- **The boundary:** every malformed-listing kind is one pinned problem batched in sorted-filename order beside malformed entries; the `deserializationBoundaries` drift law passes with the fourth row and its per-boundary law present.
- **Determinism (§7 of AGENTS.md, unchanged):** the same tree over `file://` answers an identical `Resolution` and a byte-identical lockfile; a second `snapshot` over an unchanged tree agrees with the first on every observable — `versionsOf:`, `dependenciesOf:version:` and `sha256For:version:` across the closure (`IndexSnapshot` implements no value equality, and decision 23 is the standing precedent against adding it casually — the obligation is stated in messages the class already answers).
- **Freshness across snapshots (the §3 growth precedent):** a version published upstream after a first `snapshot` is offered by a second — the listing was re-fetched — while the entries already cached are not fetched again (count the runner's curl invocations: one listing fetch, one fetch per *new* entry, zero per cached one).
- **The split:** archives are untouched until `fetch:version:` (count the curl invocations again); a fetched archive is hash-verified by the settled installer path; a cache-hit archive spawns nothing.
- **Hygiene:** every base tree and cache under `tmp/`, unique per test, removed in tearDown; no network, ever.

## 8. Publishing into a sparse index (Sprint 15, §8 decision 53)

Sprint 14 shipped the client half of a shared index; this is the producer half, and it is the gap between "package manager" and "ecosystem". `publish <dir>` writes the flat layout a `DirectorySource` scans. A sparse index is a different layout for a different consumer (§7.1), and the two are not interchangeable, so **the destination layout is stated by the operator and never inferred (§8 decision 53).**

### 8.1 The flag, and why it is not an inference

- `publish <dir> --layout <name>` — `flat` (the settled behaviour, and the default when the flag is absent) or `sparse`. An unrecognized value is a usage error at exit `2`, never a silent fallback.
- The rows live in `CommandLine class >> publishLayouts`, a **declaration consumed twice** exactly as `sourceFlags` is: the wiring is built from it and a drift law reads the same rows, so a layout can never be lawful and unreachable — the defect `GitIndexSource` shipped with for a whole sprint (Doc E §4.2).
- **Inference is refused for the settled reason.** Choosing the layout by looking at the destination's contents would make an empty directory ambiguous and a typo indistinguishable from intent — the same argument that makes `publish` refuse to *create* its destination (§1) and makes `--source` with `--git` a usage error rather than a silent preference. A valued flag also needs no new argv grammar: `valueOf:in:` already reads it.

### 8.2 What a sparse publish writes

Into `<dest>/<name>/`, byte-identical to what §7.1 specifies a client will fetch:

```
<dest>/<name>/versions.st                 the listing (Doc B §5.6)
<dest>/<name>/<name>-<version>.st         the settled index entry (§2)
<dest>/<name>/<name>-<version>.star       the archive
```

- **The listing is read before it is written.** Publishing into an index that already holds the package means loading `versions.st`, adding the new version, and re-rendering. That makes `Publisher` a sender of `IndexEntryReader readFrom:` and therefore the **fifth deserialization boundary** — a row in `CommandLine class >> deserializationBoundaries` arriving with its malformed-input law, as that table's contract requires. A malformed existing listing is one `PublishError` problem naming the file and the defect; **nothing is written**.
- **Order is semantic, not lexical.** Versions render sorted by `Version` comparison, so `1.9.0` precedes `1.10.0`. Rendering is the settled §5.1/§5.4 grammar unchanged. Publishing the same set of versions in any order produces byte-identical listings.
- **Re-publishing an existing `(name, version)` is the settled refusal** — one `PublishError` problem, nothing written, the listing unchanged, no process spawned. An index that already published a release does not silently get a second one.

### 8.3 The producer cannot manufacture the state the client calls an index defect

Doc F §7.5 rules that a listing naming an entry the index does not hold is an **index defect** — Sprint 14's S8, one `SourceError` problem naming both files. A publisher that appended to the listing before writing the entry, or that half-failed between them, would manufacture exactly that state.

**So a sparse publish is atomic: the entry, the archive and the listing all move or none do** — the decision-49 shape applied to publish. Any refusal restores the destination byte-for-byte, and the listing is written **last**, after the entry and the archive are in place, so an interrupted publish leaves an index that is merely missing a release rather than one that lies about holding it. The exit criterion is mechanical: publish a package into a sparse tree, then resolve it through `SparseIndexSource` in the same test, offline over `file://`.

### 8.4 SUnit requirements for this section

- **The layout flag:** `--layout sparse` writes §8.2's tree; absent, `publish` writes the settled flat layout with **byte-identical output to Sprint 7's** (a settled-behaviour guard, not a new claim); an unrecognized value is usage at exit `2`; the `publishLayouts` drift law passes with both rows.
- **The listing:** a first publish creates it; a second publish into the same package appends and re-renders; versions order semantically (`1.9.0` before `1.10.0`, asserted on bytes); the same versions published in either order give byte-identical files; a malformed existing listing is one pinned `PublishError` problem with nothing written.
- **Atomicity:** every refusal leaves the destination byte-identical (compare the whole tree, not just the listing); no scenario can produce a listing naming an absent entry — asserted by scanning the published tree with the settled `SparseIndexSource` and requiring a clean snapshot.
- **The loop closes:** author A publishes into a sparse tree with `--layout sparse`; author B resolves, locks, installs and `exec`s against it through `--index <base>` over `file://`, with a real toolchain-built `.star`. Offline, no network, every path under `tmp/`.
