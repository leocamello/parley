# Sprint 14 — the sparse-index client: fetch what a resolution can reach, and nothing else

**Issue:** #16 · **Specs of record:** Doc F (`docs/design/publish-and-sources.md`) **§7** with Doc B (`docs/design/manifest-and-serialization.md`) **§5.6**/§7, Doc C (`docs/design/resolver.md`) §1/**§1.2**/§2 and Doc E (`docs/design/execution-and-cli.md`) §4.2 · **Decisions:** §8 **50** (staging) and **51** (RED), following 23, 27, 35, 37, 38, 43, 46 and 47.

> **This file was opened mid-sprint**, at the Stage 3 ruling, so the RED-time record
> is written while it is exact rather than reconstructed at wrap. Stage 5 **extends**
> it — "What was built", "Verification evidence", "Noted, not built" and the
> close-out sections are still owed — and must not overwrite what is already here.
> `wrap-sprint.sh` stages this path if it exists; it never writes it.

## Ambiguities hit, and how they were resolved

### 1. Decision 50 never said where the closure's seeds come from (RED — escalated, ruled)

The agent halted at Stage 3 before writing a line, because RED pins the constructor
protocol byte-for-byte and the specs of record answered the question with silence.
Decision 50 seeds the pre-fetch closure with "the root manifest's declared names
union the lock's pinned names", and nothing said where `SparseIndexSource` finds
`Package.st` and `parley.lock`. Every path the agent could see was closed by a
settled ruling: the constructor is pinned three-keyword (`base:cache:runner:`, no
working directory), the settled `CLI` sends bare `snapshot` at six sites, seeds as
construction-time *values* contradict pathname-passivity (`init --index <base>` in
an empty directory must work), and the process cwd is ruled out by every wiring law.
Three candidates were offered — cache-path derivation, a fourth constructor keyword,
an explicit seeds collaborator — and none pinned. **The halt was correct**: this is
exactly the case AGENTS.md §8 exists for.

**Resolution:** ruled by the operator at RED as **§8 decision 51**, and all three
candidates were disqualified *together*, by a rule none of them names — **the source
must never read `Package.st` or `parley.lock`**. Both are operator-editable files
whose deserialization boundaries are already owned (`ManifestFile` by file-in, the
`CLI` by the §4.1 lock read), so a second reader duplicates a row of
`deserializationBoundaries` and gives one malformed file two wordings — the defect
class §8 decision 35 exists to prevent; and a `PackageSource` whose `snapshot` can
signal `ManifestError` or `LockError` contradicts Doc C §1, which already forbids
the adjacent thing in writing (`manifestFor:version:` is *"NEVER a `Package.st`
evaluation"*). The seeds are therefore **values, supplied by the caller**, through
one new protocol message, `seededWith:` — `SparseIndexSource` answering a new
instance holding them, `DirectorySource` and `GitIndexSource` answering `self`
because a source that reads its whole index needs no hint. The caller is the `CLI`,
and the placement is forced rather than chosen: it is the only object already
holding both the loaded manifest and the read lock when `snapshot` is sent.

**The constructor was never wrong.** `base:cache:runner:` stands exactly as Doc F
§7.3 and the issue both spell it. What was missing was *protocol*, not a keyword —
which is why every candidate that grew the constructor felt wrong to the agent that
proposed them, and why nothing already reviewed had to be re-litigated. The halt
cost one round trip and contradicted no approved artifact.

### 2. `parley add --index` was broken by construction, and no staged scenario could see it

Found while ruling #1, not by the halt, and it is the more expensive of the two
because **it would have shipped green**. `CLI >> add:constraint:` takes its snapshot
at `src/exec/CLI.st:302` and edits `Package.st` at `src/exec/CLI.st:316`, then
resolves the **post-edit** manifest against that **pre-edit** snapshot
(`src/exec/CLI.st:328`) — the edit happens as late as possible precisely because it
must be rollback-able. A scanning source never noticed, because it holds the whole
index either way. A sparse source seeded from the manifest and the lock would never
fetch the added name's listing — it is in neither — so §8 decision 47 turns the miss
into an ordinary empty candidate set, and
`add <name> <constraint> --index <base>` fails **every time** with a `#noVersions`
`ConflictReport` that blames the package while atomically restoring the file. `add`
requires a source (`src/exec/CLI.st:115`), so the combination is reachable.

The failure mode is what makes it dangerous: not a crash, not an exit `70`, but a
*plausible* conflict narration at exit `1` from a verb whose atomicity contract is
working perfectly. Scenarios S1–S15 as staged were all blind to it — none exercises
`add`, and every one of them would have stayed green.

**Resolution:** ruled with decision 51 — **`add` seeds the name it is adding**. The
seed set for that verb is the ordinary one plus `aName`. Scenario **S16** was added
to issue #16 to pin it, and the law is written to fail loudly on exactly this
regression rather than to assert a happy path in passing.

**The lesson, for the close-out to weigh:** a scenario table can be complete against
the sprint's *new* surface and still blind to a settled verb the new surface changes
the meaning of. Every scenario here was written about `SparseIndexSource`; the
defect was in `add`. Nothing in the six-item Stage 1 checklist asks "which settled
verbs does this change the meaning of, without changing their code?" — S16 exists
because a ruling happened to walk past it, which is not a mechanism.

## Operator amendments

Both landed at the Stage 3 ruling, ahead of any RED test, so the agent reads an
already-correct spec — the same discipline as the staging amendments `d815055` and
`f4aff8a`.

- **`28b56ef`** — the decision-51 ruling in the specs of record, one commit per
  runbook §4: Doc C §1's protocol block names `seededWith:` and a **new §1.2** rules
  it in full; Doc F §7/§7.3/§7.5 name the seed's provenance, state that the
  three-keyword constructor excludes the seeds *deliberately*, and add the seeding
  and `CLI`-supplies-the-seeds law obligations; `architecture.md` §8 gains
  **decision 51**; `docs/design/README.md`'s Doc C row names §1.2.
- **Issue #16 body amended** — `seededWith:` in the `SparseIndexSource` scope
  bullet; two new in-scope bullets (the seeding protocol; `add` seeding its own
  name); **three further declared settled-class exceptions** (`CLI`,
  `DirectorySource`, `GitIndexSource`), each bounded in writing — no verb's wording,
  exit code, ordering or diagnosis moves, and every settled scan law re-runs
  unchanged; those three removed from the untouched-classes list; **new scenario
  S16**; and the architecture-impact section updated to five exceptions.

`.parley/scope` is **unchanged** — `scope-14` already admits `src/source/` and
`src/exec/`, and the phase stayed `red` throughout.

---

*Stage 5 continues below: "What was built", "Verification evidence", "Noted, not
built", and the Gate B close-out rulings.*

## What was built

One new class, five bounded settled-class exceptions, and the sanctioned fixture
re-pins — nothing else in `src/` moved.

- **`Parley.SparseIndexSource`** (`src/source/SparseIndexSource.st`, new) — the
  sparse-index client, the `GitIndexSource` composition applied a second time: an
  inner `DirectorySource` over `<cache>/entries` and exactly one transport moment,
  at `snapshot`. That moment is the **decision-50 closure**: walk the seed names to
  fixpoint (each reachable package's listing, the entries it names, the names those
  entries declare, repeat, with a visited set for cycle termination), then answer
  the inner source's sealed immutable `IndexSnapshot`. `seededWith:` (decision 51)
  answers a **new instance** holding the union of the seed sets — no I/O, receiver
  unchanged. The curl grounds are closed: `0` hit, `37`/`22` miss, anything else one
  `SourceError` naming the exact command line and exit code. A missing **listing**
  is decision 47's ordinary undescribed name; a missing **entry a listing names** is
  an index defect — one problem naming both files (Doc F §7.3). Listing problems and
  missing-entry problems batch into one `SourceError` in sorted order. Listings are
  cached in `<cache>/listings/`, **beside** the scanned entries directory, never in
  it (S10); a listing is re-fetched every snapshot, a cached entry never (S15).
  `fetch:version:` fetches the archive into the entries directory once — a cache
  hit spawns nothing — then delegates to the inner source, so settled
  missing-archive diagnosis and hash verification see exactly the fetched bytes.
- **`IndexEntryReader`** (declared exception, staging) — `formatTags` grew by
  `#'parley-listing'` (last), and the rejection sentence grew with it by
  construction through `formatTagsText`; Doc B §7's illustrative message moved in
  the same change.
- **`CommandLine`** (declared exception, staging) — third `sourceFlags` row
  (`'--index'`, `SparseIndexSource`, `#indexSourceOn:`); the builder puts the cache
  at `<workingDir>/.parley/index/<sha256 of the base URL>/` (the `--git` convention
  applied a second time); fourth `deserializationBoundaries` row
  (`SparseIndexSource` / `'version listings'`).
- **`CLI`** (declared exception, decision 51) — the usage header and `flags:` lines
  gained `--index` (the `verbs:` line is byte-identical); private `seedNames`
  gathers the manifest's declared names union the lock's pins **best-effort** (each
  in a silent handler — every file already has a settled boundary owning its
  diagnosis, and `resolve` with a corrupt lock stays exit 0 per the settled
  `LockBoundaryTest` law); `seededSource` sends `seededWith:` unconditionally at
  all six snapshot sites; `seededSourceAdding:` gives `add` its own name (S16). No
  verb's wording, exit code, ordering or diagnosis moved.
- **`DirectorySource` / `GitIndexSource`** (declared exceptions, decision 51) —
  `seededWith: someNames [^self]`, the honest answer for sources that hold their
  whole index. No other change; every settled scan law re-ran unchanged.
- **Test-side re-pins (sanctioned, GREEN, same increment as the `CommandLine`
  change)** — `ExecFixtures usageLines` (five lines), `ManifestEditFixtures
  addUsageLines`, `SelectiveUpdateFixtures selectiveUsageLines`,
  `LockBoundaryFixtures sourceFlagNames`/`sourceClassNames`, `LockSchemaFixtures
  boundaryClassNames`/`boundaryFileFor:`/`probeSenderFileNames`, and
  `BoundaryCoverageTest`'s two declared growth points (the SparseIndexSource
  malformed-listing driver row; the sender-class oracle).

New test files (Stage 3, reviewed at Gate A): `tests/support/SparseIndexFixtures.st`
(fixtures, pinned wordings, `CountingProcessRunner` — records AND delegates to the
settled `ProcessRunner`), `tests/laws/SparseIndexSourceTest.st` (23 laws; operator-
amended at the flip), `tests/laws/IndexFlagTest.st` (8 laws),
`tests/acceptance/Sprint14AcceptanceTest.st` (S1–S16, one selector each).

## Verification evidence

From `.parley/audit` (wrap re-run):

```
sprint: 14
date: 2026-08-04T18:06:11Z
toolchain: GNU Smalltalk version 3.2.5
PARLEY-SEED: 20260718
PARLEY-VERIFY: PASS seed=20260718 run=709 passed=709 failed=0 errors=0
```

Toolchain: `gst --version` → `GNU Smalltalk version 3.2.5`; `gst-package --version`
→ `gst-package - GNU Smalltalk version 3.2.5`; `curl --version` → `curl 8.5.0
(x86_64-pc-linux-gnu)`. Every URL in every law is a `file://` absolute path; no law
contacts a network; `ProcessRunner` remains the only class that spawns.

662 settled laws stayed green throughout. The two declared passes-in-red (the
`--index` exclusivity laws) now pass for the mutual-exclusion reason — `--index` is
a real flag and a usage error builds no source, proved on a `TrapRunner`. The
traceability gate matched `testS1_`–`testS16_` to the issue's scenarios.

**GREEN-time amendments to the (then-untracked) acceptance file, disclosed on #16
(comment 5182819780):** S7's line selector matched the settled unquoted
`Incompatibility` narration (pinned byte-for-byte by `TermIncompatibilityTest`), and
S16's fixture published the probe star under its real name — probed toolchain fact:
`gst-package` 3.2.5 rejects a staged `.star` whose file name does not match the
`package.xml` name inside it. Neither weakens an assertion; both were probed with
throwaway `gst -q` scripts and the answers pasted in the report.

## Noted, not built

- **Publishing into a sparse layout** — `publish <dir>` writes the flat directory
  layout only; the listing-writing half is Sprint 15's release hardening, per the
  issue's out-of-scope list.
- **Cache pruning / size budget** — the `--index` cache is the second unpruned
  cache, declared in the issue, not discovered later.
- **Archive-miss wording of `fetch:version:`** — a transport miss (37/22) on an
  archive fetch leaves the diagnosis to the inner source's settled missing-archive
  problem rather than inventing a fourth transport wording. No law pins the sparse
  spelling of that path; if an operator-facing wording is wanted, it is one problem
  string and one law.
- **Stage 1 checklist blind spot** (from Ambiguity #2, restated for Gate B): no
  checklist item asks "which settled verbs does this change the meaning of without
  changing their code?" — S16 exists because the decision-51 ruling walked past the
  defect, not because a mechanism caught it.
- **`seededWith:` on a future `PubGrubStrategy` swap** — nothing to do now; noted
  that the seam is on the *source* protocol, so a strategy swap does not touch it.

## Close-out

Committed as `feat(source)` on `main`. **Gate B passed** — issue #16 closed, commit
`d54b490`, 709 laws.

**Verified independently, not accepted.** `./scripts/verify-sprint.sh` re-run by the
operator: `PARLEY-VERIFY: PASS seed=20260718 run=709 passed=709 failed=0 errors=0`,
agreeing with `.parley/audit` on seed, counts and date. The commit touches exactly
the five declared exceptions and nothing else in `src/`.

**Both disclosed RED-file amendments were re-derived from the settled tree rather
than taken on trust, and both are accepted as corrections, not weakenings.** S7's
reviewed spelling (`no version of 'ghost'`, quoted) is one the settled
`Incompatibility` narration never produces — `TermIncompatibilityTest.st:160` pins
`no version of a satisfies >=9.0.0 <10.0.0`, unquoted — so the law as reviewed was
unsatisfiable without touching settled resolver output that no exception covers.
The assertion still requires the `#noVersions` narration naming `ghost`, and both
`deny:` guards (no undiagnosed-line prefix, no `curl` leak) survive intact. **The
operator missed this at Gate A**; the agent found it by probing and disclosed it,
which is the protocol working. S16's rename from `newdep` to `parley-probe` is
forced by the toolchain fact that `gst-package` 3.2.5 rejects a staged `.star` whose
filename does not match the internal `package.xml` name; the regression guarded is
name-agnostic, the `init` template declares no dependency, so the added name is
still in neither the manifest nor the lock and the law still discriminates.
`BoundaryCoverageTest` grew additively at the two points its own comments declare as
growth points — a third sender-class name and a fourth driver row — which is the
decision-38 drift law doing its job, not a settled law being bent.

**One close-out ruling, not flagged by the agent: [§8 decision 52](../design/architecture.md#8-decision-log).**
`CLI >> seedNames` gathers the seed set best-effort, and it is *right* to — `resolve`
must ignore a corrupt lock (Doc E §4.1) and the missing-manifest sentence belongs to
`ManifestFile` (decision 31). But both catches take `Error` rather than the two
declared boundary errors they defer to, so a programming error inside seed gathering
leaves not an exception but a **silently empty or partial seed set**. Under a
scanning source that is invisible; under `--index` it is decision 47's describability
line, and the verb answers a `#noVersions` conflict **blaming the package** — the
exact wrong-blame diagnosis S16 exists to prevent, arriving silently, on the one path
no fixture exercises because every law's seed gathering succeeds. **Carried gap,
unscheduled** — latent rather than live, since nothing in the gathering path signals
outside `ManifestError` and `LockError` today. No consumer constraint. The fix is two
identifiers plus one law; the trigger is the next sprint that touches seeding or the
CLI's error taxonomy.

**The Stage 1 blind spot recorded above (Ambiguity #2) is carried forward as the
sprint's most useful finding.** Decision 52 is its second instance in one sprint: both
defects live in a *settled* class whose behaviour the new surface changed without
changing its code, and in both the observable symptom is a confident, wrong,
package-blaming conflict. S16 caught the first because a ruling walked past it, and
the second was caught by a close-out read rather than by a law. That is twice that the
mechanism was luck.
