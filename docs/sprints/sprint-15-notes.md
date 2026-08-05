# Sprint 15 — publishing into a sparse index, `--version`, and the v1.0 line

**Issue:** #17 · **Specs of record:** Doc F (`docs/design/publish-and-sources.md`) **§8** with §1/§5 and §7.1/§7.5, Doc B (`docs/design/manifest-and-serialization.md`) **§5.6**/§5.1/§5.4/§7, Doc E (`docs/design/execution-and-cli.md`) §4.1/§4.2 · **Decisions:** §8 **53** (this sprint's ruling) and **52** (the gap it clears), following 26, 35, 38, 43, 45, 47 and 49.

**The last v1.0 sprint.** Sprint 14 shipped the sparse-index *client*; this is the producer. `publish <dir>` wrote the flat layout a `DirectorySource` scans and nothing wrote the per-package layout `SparseIndexSource` reads — the gap between a package manager and an ecosystem, and the last thing v1.0 was missing.

## Ambiguities hit, and how they were resolved

### 1. S7's byte-identity and Doc F §1's fail-stop stage contradict each other on the build-failure ground (RED — raised, ruled)

S7 requires every refusal to leave the destination tree byte-identical and lists **build failure** among the grounds. Doc F §1 step 4 rules the opposite for that one ground — the destination-confined stage is **left in place for inspection**, because fail-stop never cleans up behind an error — and `PublisherTest` pins that byte-for-byte at lines 321–334, a settled law this sprint may not touch.

**Resolved before writing the scenario**, on the tiebreaker issue #17 states itself: *where this issue and the docs disagree, the docs win.* Doc F §8.3 scopes the atomicity claim to **the entry, the archive and the listing** — the decision-49 shape, which was narrowed at the Sprint 13 close-out for exactly this reason (a claim that cannot be made should be narrowed in writing, not faked). So S7 compares the **whole** tree for the other four grounds with no exception, and for the build-failure ground compares the tree *without* the stage while separately requiring that no package directory, entry, archive or listing appeared.

**The operator confirmed the ruling at Gate A and checked the premise rather than the argument:** `SparseIndexSource` addresses `<base>/<name>/…` by constructed URL from its seeds and never enumerates the base, so a leftover stage is genuinely invisible to the client. The Gate A amendment went further and made that mechanical — the scan-clean law now includes a **failed build** in its sequence and asserts the stage really was left behind, so the header's argument is now warranted by a test rather than by prose.

### 2. Where the layout selector lives, given that no new class is allowed

Doc F §8.1 rules that the rows live in `CommandLine class >> publishLayouts` and are consumed twice; issue #17 forbids a new class and forbids a `SparsePublisher` subclass. A layout, though, answers **three** questions — where the release lands, what must be sound before anything is built, and what else the layout maintains once the release is down — and the table would have had to name three `Publisher` selectors, putting the Publisher's private protocol in the composition root.

**Resolved by asking rather than restating.** `Publisher class >> flatLayout` and `sparseLayout` answer the three-selector specs, where the methods they name live; `publishLayouts` declares which layouts *exist* and asks the Publisher for each spec. One definition, consumed twice, and no `isKindOf:` anywhere: the Publisher performs the three selectors and never branches on which layout it holds.

### 3. A settled artifact had to be written by a class forbidden from touching the writer

`IndexEntryWriter` is consumed-never-modified, so the `#'parley-listing' 1` rendering could not live where the other three schemas' renderings live. It lives in `Publisher >> renderListing:`, built on the settled `Version` comparison and `printString`. The fixtures do **not** re-render it: `PublishLayoutFixtures listingFor:` delegates to Sprint 14's `SparseIndexFixtures listingFor:`, so the producer is asserted against the bytes the consumer was built to read, from both ends of the same fixture.

## Operator amendments (Gate A)

Nine new laws passed in red where five had been declared. Two amendments landed, both strengthening:

1. **`testAnUnrecognizedLayoutIsAUsageErrorAndNeverAFallback` passed for the wrong reason** — on the pre-sprint tree `--layout` is not a flag at all, so *every* `--layout` invocation is exit `2` and the law would have kept passing had the flag never shipped. It now asserts the recognized half beside it, read from the same table.
2. **The scan-clean law argued the stage was invisible without exercising it** (ambiguity 1 above).
3. Documentation only: the three settled trailing-flag guards were described in prose but not listed. A guard that passes in red is only legitimate once declared.

The **S17 typo** in the issue body — `wrap-sprint.sh` greps `\bS[0-9]+\b` over the whole body, so a stray `S17` in the Scope section would have demanded a `testS17_*` selector — was found at RED and fixed operator-side before GREEN.

## What was built

**No new class and no new directory**; `scripts/run-tests.st` unchanged. Four declared settled-class exceptions, each bounded:

- **`Parley.Publisher`** — the destination layout as a **parameter of one pipeline**. `manifest:in:to:layout:runner:` beside the settled four-keyword constructor (which now delegates with `flatLayout`, unchanged in meaning); `flatLayout`/`sparseLayout` specs; `releaseDir` as a table lookup (`flatReleaseDir` → `<dest>`, `sparseReleaseDir` → `<dest>/<name>`); the listing read (`listingVersionsInto:`, the fifth deserialization boundary), its rendering (`renderListing:`, sorted by **`Version` comparison** and rendered through `Version printString`), and the read-modify-write (`writeSparseListing`). The pipeline gained one step — the layout's own pre-flight, **before anything is staged**, so a malformed listing costs the author a message and nothing else — and `land` now writes the archive, then the entry, then **the listing last**, then removes the stage.
- **`Parley.CommandLine`** — `publishLayouts` (the declaration consumed twice), `publishLayoutFlag`, `defaultPublishLayout`, `publishLayoutNamed:`; the **fifth** `deserializationBoundaries` row (`Publisher` → version listings); `versionFlag`/`versionLine`; and `--version` recognized in `dispatch:` **ahead of verb dispatch and before `createStateDirectories`**.
- **`Parley.CLI`** — the `--layout` pass-through (`publish <dir> --layout <name>`, an unrecognized value answering usage **before** the manifest is loaded), the usage `flags:` line, and the **decision-52 narrowing** of `seedNames`' two catches from `Error` to `ManifestError` and `LockError`.
- **`Parley.Parley`** — `version`, answering `'1.0.0'`, the single definition the `--version` line composes itself from.

Plus the README, rewritten for a stranger and now **guarded by a drift law** rather than by good intentions: its verb list is compared against the CLI's own usage `verbs:` line, read live from the running tool.

### Why `--version` is not a grammar change

`CommandLine`'s settled `valueOf:in:` treats a **trailing** flag as *not a flag* — it travels to the CLI, which answers usage — and several settled laws rest on exactly that. `--version` carries no value, so teaching the grammar that valueless flags are flags would have silently changed what every one of those laws tests **without touching a line of them**: they would keep passing and no longer be about the same thing. It is one declared special case, recognized narrowly (the whole argv is the flag and nothing else), and three laws hold the settled behaviour where it was: `resolve --version`, `resolve --nonsense` and `--version extra` all still answer usage at exit `2`.

## Verification evidence

```
sprint: 15
date: 2026-08-05T18:08:10Z
toolchain: GNU Smalltalk version 3.2.5
PARLEY-SEED: 20260718
PARLEY-VERIFY: PASS seed=20260718 run=756 passed=756 failed=0 errors=0
```

Exact `gst --version` (first line; the banner continues with the 2009 FSF copyright, the GPL notice, and the default kernel/image paths `/usr/local/share/smalltalk/kernel` and `/usr/local/var/lib/smalltalk`):

```
GNU Smalltalk version 3.2.5
```

`gst-package --version` reports `gst-package - GNU Smalltalk version 3.2.5`; `curl 8.5.0` answers, and every `--index` law resolves over `file://`. **No network was contacted at any point.** 756 laws, up from Sprint 14's 709: 47 new (16 acceptance scenarios, 17 layout laws, 14 release-hardening laws).

Four toolchain facts were **probed rather than assumed**, and two changed how a law was written:

- **`gst-package` archives are not byte-reproducible** — it shells out to `zip`, which records mtimes, so two builds of identical inputs differ. S1's "the entry bytes are identical to the flat publish's" is therefore asserted with each publish's own runtime digest substituted out, which is the settled Doc E §5 digest discipline applied to a comparison rather than to a literal.
- **`File>>contents` on a directory signals `SystemExceptions.WrongClass`** — the driver S14 needed, and the reason decision 52's gap turned out to be reachable (below).
- `gst -q <script> -a --version` passes the flag through to Smalltalk; gst does not intercept it.
- A class referenced by a method in an earlier-loaded file binds correctly once the later file defines it (`CommandLine` in `src/exec/` naming `Publisher` in `src/publish/`).

## The prebuilt-image decision, taken on measurements

Measured on this machine and toolchain, 20 runs each unless noted, wall clock per run:

| Path | ms/run |
| --- | --- |
| bare `gst`, kernel only, no Parley | **12.3** |
| current path — `bin/parley --version`, filing in all 43 `src/*.st` | **55.5** |
| prebuilt image (3.2 MB snapshot, all of `src/` filed in) | **5.6** |
| `parley resolve --source <dir>`, one dependency, no child process (10 runs) | **67.7** |
| `parley publish --layout sparse`, real `gst-package` + `zip` (5 runs) | **194.7** |

The file-in costs **≈43 ms** per invocation (55.5 − 12.3). A prebuilt image removes all of it and then some — 5.6 ms is *faster than bare `gst`*, because loading a snapshot skips kernel bootstrap — so the saving is **≈50 ms per invocation**. As a share of real work that is 63% of a metadata-only `resolve` against a local directory and 22% of a `publish` that spawns the toolchain; against `install` or `exec`, which spawn children per package, it is smaller still.

**Ruling: defer, with named triggers — not refuse, and not build.** 50 ms is not a user-visible cost for a tool whose ordinary commands spawn `gst-package`, `git` or `curl`. Against it sits a 3.2 MB build artifact that must be kept in step with `src/` and that **goes stale silently**: an image built from older sources runs older code and says nothing, which is the fail-wrong class this project refuses everywhere else, and no law today could catch it. Shipping the artifact would mean shipping a freshness guard with it, and that is design, not tooling polish.

Three triggers, any one of which reopens it: **(a)** a consumer that invokes `parley` in a per-file loop, where 43 ms × N becomes felt; **(b)** `src/` growth pushing file-in past ~250 ms, at which point it dominates even the spawning verbs; **(c)** a staleness guard arriving for another reason — a content hash of `src/` embedded in the image and checked at startup — which is what would make the artifact safe to ship at all.

## Noted, not built

- **Nothing in the out-of-scope list was touched.** No hosting, no signing, no yanking-as-deletion, no `RegistrySource`, no cache pruning, no prereleases, no backjumping, no `PubGrubStrategy`, no `remove`, no output capture. `SparseIndexSource`, `IndexEntryReader`, `IndexEntryWriter`, `DirectorySource`, `GitIndexSource`, the resolver and all of `src/domain/` are untouched — `SparseIndexSource` is the **oracle** for S8 and S16, scanning the tree this sprint publishes.
- **The prebuilt image was measured, not built** (above).

## Close-out

**§8 decision 52's gap is reachable on the shipped tree, not latent as ranked.** The Sprint 14 close-out ranked it "latent rather than live — nothing in the gathering path signals outside `ManifestError` and `LockError` today, and an operator cannot currently reach it." That is not so. `CLI >> pinnedResolution` guards only `IndexEntryParseError, IndexEntryFormatError`, so a `parley.lock` that is a **directory** — an ordinary operator mistake, one `mkdir` away — passes `exists` and raises `SystemExceptions.WrongClass` from `contents`, straight past that handler into `seedNames`' `on: Error`. On the pre-sprint tree, `resolve --index <base>` against that project answers a `#noVersions` `ConflictReport` **blaming the package**. Confirmed by the operator at `src/exec/CLI.st:692` at Gate A, and it is now the driver of S14: narrowed, the error reaches the settled taxonomy at exit `70`. The re-ranking is the finding; the fix shipped with it.

**A second-order observation, offered rather than claimed.** Exit `70` says *this is a defect in Parley, not in your project* — and a lock that is a directory is the operator's state, not Parley's defect. Decision 52 rules exit `70` for exactly this class and the ruling is right about the alternative (a confident wrong sentence is worse than an honest fail-stop), but the blame line is imprecise for inputs that are neither well-formed nor a Parley bug. Diagnosing them properly would mean the lock boundary validating *readability* alongside shape, which is a contract change on a settled verb rather than a fix. Ranked here for Gate B, not scheduled.

**The exit criterion, met.** S16 runs it end to end and offline: author A publishes a real toolchain-built `.star` into an empty base with `--layout sparse`; author B declares the package and runs `resolve` → `install` → `exec` through `--index` over `file://`; the lock pins the published digest, the archive is hash-verified into the store, the registration plan runs, and a curated child answers `present`. Published by one working directory, consumed by another, over a layout neither downloads in full.
