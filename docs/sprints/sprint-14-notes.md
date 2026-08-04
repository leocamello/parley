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
