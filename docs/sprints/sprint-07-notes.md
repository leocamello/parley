# Sprint 7 Notes — Publisher + GitIndexSource (issue #9)

## What was built

The Phase 4 opener — "the ecosystem loop closes." Three new classes
(one new `src/` directory) and the three declared settled-class
exceptions, and nothing else:

- **`Parley.Publisher`** (`src/publish/`) — manifest → toolchain-built
  archive → published index entry, over four immutably held
  collaborators (`manifest:in:to:runner:`); construction is
  pathname-passive. `publish` runs the Doc F §1 pipeline in order:
  refusal-first (an existing `<dest>/<name>-<version>.st` is a
  category error — nothing else is checked, nothing written, nothing
  spawned), batched pre-flight over the declared `fileIns` in sorted
  filename order, destination-confined staging in
  `<dest>/.parley-publish-stage/`, the real toolchain build through
  the runner, then digest-and-land. Answers the landed archive's
  sha256 hex digest. `packageXml` answers the §1.1 composition as a
  pure value.
- **`Parley.PublishError`** (`src/publish/`) — the `ManifestError`
  problems house style: `problems`, and `messageText` pinned as
  `Publish has <n> problem(s): ` with problems joined by `; `.
- **`Parley.GitIndexSource`** (`src/source/`) — a git checkout used as
  an index directory, by pure composition: it holds an inner
  `DirectorySource` over the cache and adds exactly ONE git moment, at
  `snapshot` (clone when the cache is absent, `pull --ff-only` when it
  is present). A nonzero git exit is one `SourceError` carrying the
  command line and the exit code and no stderr text.
  `versionsOf:` / `manifestFor:version:` / `fetch:version:` are pure
  delegation and run no git at all.

The three declared settled-class exceptions, and no others:

1. **`IndexEntryWriter`** gained `write:archive:sha256:on:` — the
   published rendering, identical to the settled `write:on:` except
   `#archive` names the landed archive and carries its digest. The
   shared head was extracted into one private helper
   (`writeHeadOf:on:`) so the two renderings cannot drift; the settled
   `write:on:` output is byte-identical (S5 and the Sprint 1 oracles).
2. **`DirectorySource`** scan gained §5.2 schema-shape validation
   (Doc F §4) — the Sprint 4 ruled gap, closed. After the settled
   tag/format checks and before duplicate detection, each entry must
   carry the eight keys in the fixed order, each with its schema kind.
   A violation is ONE problem naming the file and the defect, batched
   with every other scan problem into the one `SourceError` in
   sorted-filename order. The reader stays a pure literals-only
   parser. The fixed key order is derived from `schemaKeys`, so the
   contract and its rendering cannot drift.
3. **`CLI`** gained the `publish <dir>` dispatch and verb: load the
   manifest, run the pipeline, answer one success line naming the
   package and version on exit 0, or the `PublishError`'s problems on
   exit 1. No source collaborator required. (The pinned usage verbs
   line had already been amended operator-side at staging.)

Tests: 53 new (`PublishFixtures` + the `TrapRunner` double;
`SchemaValidationTest`, `IndexEntryWriterArchiveTest`, `PublisherTest`,
`GitIndexSourceTest`; `Sprint7AcceptanceTest` with `testS1_`–
`testS18_`). The S18 exit criterion runs the whole ecosystem for real:
author A's `parley publish` builds a star with the toolchain and lands
the release; author B resolves, installs and registers it, and B's
curated child records A's class as present; then the same index,
carried in a fixture git repository, is cloned by a `GitIndexSource`
and resolves to a byte-identical lockfile.

## Ambiguities hit and how they were resolved

1. **The composed `package.xml` was required to be byte-pinned, but a
   successful publish removes the stage** — so the canonical bytes
   would have been observable only through the failure path. Rather
   than pin them there, RED introduced `Publisher >> packageXml` as a
   pure value message and additionally asserted the staged file
   matches it. Raised on issue #9 as a selector the spec did not name;
   the operator **approved and closed the drift by amending Doc F §1**
   to name `packageXml` and to state that `Publisher` construction is
   pathname-passive (§3 already said so for `GitIndexSource`; the laws
   depend on it for both).
2. **Value parseability is not schema shape.** Doc F §4 scopes the new
   validation to shape, so a `#version 'banana'` still escapes the
   scan as a raw error rather than a batched problem. Deliberately not
   extended past the spec; raised on issue #9 and **ruled** by the
   operator: fail-stop, not a soundness gap, and the narrowed
   remainder of the Sprint 4 ruled gap — scheduled as a Sprint 8
   candidate. "Diagnosis, not crash" is therefore true for shape, not
   for value.
3. **The settled regression guard could have manufactured a third
   pass-in-red.** S5 (the settled writer's byte-unchanged output) is
   declared to pass in red; duplicating it into the writer law file
   would have added an undeclared one. It lives only in
   `tests/acceptance/`, and the law file records why. Red closed with
   `passed=358` = 356 settled + exactly `testS5_` and `testS17_`.
4. **RED spawn-freedom vs. real git and real builds** (the Sprint 6
   pattern, reused): every publish and git law touches the missing
   class before any fixture builder runs, and every fixture git
   command goes through `ProcessRunner` — so the red phase spawned
   nothing at all.
5. **Green-phase mechanics not covered by any law, checked
   empirically before relying on them:** git absolutizes a relative
   local clone URL at clone time, so `git -C <cache> pull --ff-only`
   fast-forwards from any working directory; `git clone` of a missing
   local path exits 128. Staging sweeps a stage left behind by an
   earlier failed build before recreating it, so publish stays
   re-runnable while fail-stop still never cleans up behind its own
   error.

All exact wordings (the eight schema-violation problems, the refusal,
pre-flight and build-failure problems, the git-failure problem, the
publish success line) and all byte oracles (the composed
`package.xml`, the published entry, the S4 writer entry) were pinned in
RED and confirmed on issue #9 at Gate A.

## Verification

From `.parley/audit`:

```
sprint: 7
date: 2026-07-24T23:39:11Z
toolchain: GNU Smalltalk version 3.2.5
PARLEY-SEED: 20260718
PARLEY-VERIFY: PASS seed=20260718 run=409 passed=409 failed=0 errors=0
```

Green was reached in five increments, one verifier run each, the
settled-class surgery first and alone: schema validation
(`passed=374`), the writer selector (`381`), `Publisher` +
`PublishError` (`394`), `GitIndexSource` (`406`), the CLI verb
(`409`). The 356 settled laws stayed green throughout.

`tmp/` absent after every clean run; the developer image was never
mutated. No network was contacted: every fixture repository is a local
path under `tmp/` and every clone is a local-path clone. The
developer's git config was never read for identity nor written —
committer identity is supplied per command via
`git -c user.name=… -c user.email=…`.

Exact toolchain version outputs:

```
gst --version        -> GNU Smalltalk version 3.2.5
gst-package --version -> gst-package - GNU Smalltalk version 3.2.5
git --version        -> git version 2.43.0
```
