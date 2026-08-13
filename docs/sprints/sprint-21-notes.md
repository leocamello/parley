# Sprint 21 — dependencies you are developing

**Issue #23. Roadmap §2 item 6 — the sixth of the seven that hold the v1.0 tag. The tag is
not cut here.**

Two directories side by side is how a library and its consumer are actually worked on, and
until this sprint it cost a `parley publish ../index` after every edit. Path dependencies were
the highest-value feature missing from the tool, and both new vocabulary words were cheapest
*before* the tag: after it there are published entries, and a schema that moved is a
migration.

Three rulings shape everything below. **§8 decision 69** makes the cost zero —
`dependency:path:` and `devDependency:constraint:` are root-manifest-only vocabulary, never
serialized, so `#'parley-index' 1` is byte-identical and every entry published to date stays
valid. **§8 decision 68** puts the mechanism in the source layer — a path dependency is an
*overlay*, the fifth application of the put-it-in-the-source pattern, so `Resolver`, both
strategies, `ConstraintLedger` and every settled source class are untouched. **§8 decision
83**, with **§8 decision 84** minted mid-sprint, makes *needs an index* a property of the
manifest rather than of the grammar.

```
PARLEY-VERIFY: PASS seed=20260718 run=1091 passed=1091 failed=0 errors=0
```

---

## 1. What shipped

**Two new classes**, both declared on the issue before RED, in directories `scripts/run-tests.st`
already files in — so that script is unchanged:

- **`Parley.PathDependency`** (`src/domain/`) — the immutable `(name, declared path)` value.
  The path is recorded **raw**, exactly as the author wrote it, because a lock travels with its
  checkout and must carry `'../kernel-text'` rather than one machine's expansion. No value
  equality (the decision-23 precedent), and deliberately *not* a `Dependency` subclass: a path
  dependency has no `VersionConstraint` at all, so `satisfiedBy:` would have no honest answer.
- **`Parley.PathOverlay`** (`src/source/`) — a `PackageSource` **decorator** around the wired
  source, or around nothing. Its `snapshot` is its one I/O moment: read each sibling's own
  `Package.st` through the settled `ManifestFile`, walk the siblings' own path dependencies to
  fixpoint, refuse one name supplied by two directories, re-seed the base through the settled
  `seededWith:`, then compose.

**Ten declared settled-class exceptions**, each inside the bound issue #23 states:
`ManifestBuilder` (the two vocabulary words, `build` validation), `LibraryManifest` (the two
collections), `IndexSnapshot` (`overlaying:` and `pathProvenance`), `Resolution` (`withPaths:`,
`provenanceOf:`, `pathNames`, `pathFreeView`, the alternative tuple in `fromLockEntry:`),
`PinVerification` (the three declared kinds), `IndexEntryWriter` (`writeLock:on:` renders the
`#path` tuple), `ExecutionScope` (the child line gains the sibling file-ins), `Publisher`
(step 0), `CLI` and `CommandLine`.

**The census stayed at eight.** `PathOverlay` performs no direct `File` I/O: siblings are read
through `ManifestFile`, which already holds its census seat, and the visited set's key is
computed by **string arithmetic** rather than asked of the filesystem —
`BoundaryTableTest`'s prohibition never saw a ninth class.
**`deserializationBoundaries` did not grow** — no new reader exists. **The §4.2 error partition
did not grow** — the three new refusals are composed `CliResult` answers, not error classes.

### 1.1 CF-5's three categories, with the zero written out

| category | count | evidence |
|---|---|---|
| new laws in **new** test files | **108** | the six new files sum to exactly 108 selectors |
| **new laws in settled test files** | **0** | `1091 − 983 = 108`, and all 108 are accounted for above |
| re-pins of settled laws | **11**, plus 1 disclosed non-mover touch | §4 |

```
34  tests/acceptance/Sprint21AcceptanceTest.st      13  tests/laws/PathGrammarTest.st
17  tests/laws/ModeFlagTest.st                      16  tests/laws/PathOverlayTest.st
15  tests/laws/PathLockTest.st                      13  tests/laws/PathVocabularyTest.st
                                                    --- 108
```

**The zero is a measurement, not an assumption.** Every re-pin added assertions *inside* an
existing method and added no selector anywhere, so `run` held at **1091 from RED through
green**. Had any re-pin been written as a new law beside the old one, this category would be
non-zero — and `all.txt` cannot see such a law, which is exactly why CF-5 requires the category
to be declared rather than inferred.

---

## 2. The workflow, in shipped bytes, with the streams apart

This is roadmap item 6's promise and the reason the sprint exists. Walked through `bin/parley`
on two real directories, **capturing stdout and stderr separately** — which the Gate A walk did
not do. Merging them cannot show that the plumbing is quiet, and *quiet* is a claim this
project now makes (§8 decision 77, finding F19).

`tmp/wf-app/Package.st` declares one dependency by path; `tmp/wf-text` is the sibling.

```
$ parley resolve
exit=0
--- stdout ---
kernel-text 1.2.0
--- stderr ---
--- (end) ---

$ cat parley.lock
#(#'parley-lock' 1 #root 'my-app' #packages #(#('kernel-text' '1.2.0' #path '../wf-text')))

$ parley exec probe.st
exit=0
--- stdout ---
text-before
--- stderr ---
--- (end) ---

# edit ../wf-text/KernelText.st ONLY — no publish, no rebuild, no re-registration

$ parley exec probe.st
exit=0
--- stdout ---
text-after
--- stderr ---
--- (end) ---

$ cat parley.lock
#(#'parley-lock' 1 #root 'my-app' #packages #(#('kernel-text' '1.2.0' #path '../wf-text')))
LOCK BYTE-IDENTICAL: yes
```

Three things are visible here and each is a ruling made real. The lock records **provenance
instead of a digest**, carrying the declared string byte for byte. The second `exec` answers
`text-after` because the sibling is read **fresh at exec time** and its `fileIns` ride the
composed child line ahead of the script — the rebuild-and-re-register alternative was named and
ruled out in decision 68 as publish-per-edit in mechanism. And **stderr is empty at every
step**: the plumbing says nothing, so the only bytes on the operator's terminal are the ones
Parley composed and the ones their own program printed.

---

## 3. Ambiguities hit, and how each resolved

**The trust framing was settled before RED and never reopened.** `PathOverlay` executes a
sibling's `Package.st` through `ManifestFile`, and that is inside the boundary by decision 69's
own argument: `path:` is root-manifest-only vocabulary, the developer owns both directories,
and a published entry can never declare a path. The Absolute Trust Invariant is untouched.

**Which spelling opens the sibling file** — decision 68 is deliberately silent, and the
question surfaced only when the aliasing law made the read strategy observable. Asked on the
issue, ruled at Gate A: open through the **declared** string, canonicalising **only** for the
visited-set key, so the settled `ManifestFile` diagnosis names the author's own path with no
re-voicing. No decision minted; the choice sits inside decision 68's silence.

**`PinVerification` and the word *provenance*.** Doc E §4.1 read *verifies by presence and
provenance*, which admits a reading where the lock tuple must carry `#path`. Implemented that
way first; it fails reviewed scenario S12, which builds a valid path pin through the settled
`root:triples:` with no provenance at all. Flagged rather than decided silently, and upheld on
a ground stronger than the test: `PinVerification` verifies the **declared manifest**, so it
learns a dependency is a path dependency from the declaration and never from the lock's own
record — requiring provenance would make it a consumer of that record. Doc E §4.1 amended;
**presence only**.

**Whether `why`/`tree` needed a fifth consumer of the composed resolution view.** The four
boundary sentences ruled at GREEN step 3 make a fifth consumer a halt-and-ask, so it was
halted on. The dilemma was false: both walks already read `manifest dependencies`, the declared
manifest, and reading `manifest pathDependencies` beside it is not consuming the wiring value.
The composed view carries **synthetic** `*` constraints for the `Resolver`; reporting verbs
need the **declared** edges with their real annotations. Two values, two purposes, one object
read twice — `declaredEdgesOf:` is separate from `resolutionViewOf:` and each comment says why.
`devDependencies` joined the same walk as a recorded sub-decision: `why kernel-lint` answered
zero lines, the identical gap shape, one line of the same fix.

**Two provenance bounds that read as contradictory and are not.**
`declaredProvenanceOf:` names only what the **root declared**, because a conflict speaks
*before* resolution, where a sibling's declaration is not yet a fact of the project.
`hopAnnotationFor:dependency:resolution:` reads the **lock's** provenance, so a transitive path
pin is named there. Each method's comment names the other and states the difference, so a Gate
B diff reads design rather than drift.

---

## 4. The settled-mover list, and which assertion moved each

**40 movers at Gate A → 11 at round ten → 0 at close. None ever joined, at any round.** The
mover set built from the *property* at RED is what made a three-mover swing at decision 84 a
non-event rather than an investigation.

### 4.1 The governing distinction — KEPT versus MOVED

| | verbs | why |
|---|---|---|
| **MOVED out of the grammar** | `resolve`, `check`, `tree`, `why` | a project that needs no index must still be inspectable |
| **KEPT** | `install`, `update`, `add`, `remove` | write verbs; the mirror is deferred with its trigger, and S33 holds the bound |
| **KEPT, deliberately** | `search`, `info`, `outdated` | index **questions** by decision 68's matrix — a project with no index has no answer for them to give |

The last row is an exclusion rather than an oversight, recorded in the code's own comment so
the ruling survives into the artifact.

### 4.2 The 29 that cleared on artifacts

26 cleared on **one change**: `CLI class >> usageBlock` growing from six lines to eight — the
header gaining `[--offline] [--locked]` and the `flags:` block gaining a row for each. Three
more cleared on a **second literal copy of the header row** in
`SparseIndexFixtures>>usageHeaderLine`, consumed by `IndexFlagTest:272`, `Sprint14:532` and
`Sprint15:488`.

**That second copy is an F18 miss of mine, and it is the sprint's own lesson repeated.** My RED
sweep enumerated *consumers of `ExecFixtures usageLines`*; a fixture holding its own copy of one
**row** of the block is structurally invisible to that search — precisely what Sprint 20 wrote
into that fixture's comment after paying for it. The generalisation for the next sprint: when an
oracle is re-pinned, sweep the **text of the moved rows**, never the senders of the oracle.

### 4.3 The eleven behaviour re-pins — falsified *by ruling*

Decisions 83 and 84 made these false, so each asserts the new behaviour in full rather than
merely deleting the old claim.

| # | law | the assertion that moved it |
|---|---|---|
| 1 | `CliTest>>testSourceRequiringVerbsWithoutASourceAnswerUsage` | iterated `#('resolve' 'install' 'update')` at exit 2 |
| 2 | `CommandLineTest>>testASourceRequiringVerbWithoutASourceIsUsageAtExitTwo` | argv `#('resolve')` at exit 2 |
| 3 | `Sprint6AcceptanceTest>>testS19_unknownInputAnswersUsage` | the same iterated list |
| 4 | `InspectionVerbTest>>testAnInspectionVerbWithoutASourceAnswersUsage` | `why`/`tree`/`check` at exit 2 |
| 5 | `ReadinessTest>>testNoUsageErrorCreatesProjectState` | `deny: .parley exists` over an argv set containing `resolve` |
| 6 | `Sprint16AcceptanceTest>>testS17_ACommandThatRefusesToRunLeavesTheFilesystemAlone` | the same shared fixture |
| 7 | `Sprint19AcceptanceTest>>testS8_NoConfigAndNoFlagAnswersTheSettledUsageLines` | exit 2 + `#needsIndex` lines + a shared-block tail |
| 8 | `Sprint20AcceptanceTest>>testS8_eachUsageGroundAnswersItsOwnFirstLine` | the `s20-8-index` row's argv |
| 9 | `UsageGroundTest>>testEachVerbGrammarGroundAnswersItsOwnFirstLine` | the `ug-index` row's argv |
| 10 | `UsageGroundTest>>testAVerbThatNeedsAnIndexIsToldSoRatherThanToldItsArgumentsAreWrong` | driven argv `#('resolve')` |
| 11 | `UsageGroundTest>>testTheNeedsIndexSentenceNamesEveryDeclaredSourceFlag` | driven argv `#('resolve')` |

**A brief was corrected by the tool at re-pin 7.** The round's direction described Sprint19 S8
as resolving at exit 0 with the no-dependencies confirmation. Its fixture is the settled diamond
root, which declares `a` and `b` — so decision 83's ruled answer there is the **in-verb refusal
at exit 1**, not the dependency-free confirmation. Probed before applying:

```
exit=1
| no index is wired, and Package.st declares a and b - give --source, --git or --index, or record one in parley.config.st
```

**A twelfth touch, deliberately not counted.**
`UsageGroundTest>>testTheFourFirstLinesDifferFromEachOther` was **still passing** and moved
anyway: it reads first lines only and asserts no exit code, so once `resolve` left the grammar
its fourth row answered a line naming the fixture's own path — distinct from its neighbours *by
construction*. It would have passed with the two sentences it exists to separate merged.
Falsified quietly rather than loudly. The re-pin count stays eleven.

### 4.4 Non-movers, confirmed rather than assumed

`SourceFlagTest:149`'s three-column shape law (the mode flags are a **second** declared table,
because they build nothing) · every settled lock-byte oracle (a path-free lock is byte-identical
to Sprint 20's) · the settled `ExecutionScope` composition (unchanged when no path pins exist) ·
the config laws (`#'parley-config' 1` untouched) · the README **verb** drift laws (no new verb) ·
the **holding-map family**, derived from `CLI>>heldVersionsOf:except:` rather than from a grep:
no settled fixture carries a path pin, so the decision-68 exclusion changes nothing there.

---

## 5. Test edits during GREEN — 17 files across eight commits

Sprint 20's equivalent section recorded one edit. This sprint's is the largest surface it has
had, and **every entry is a reviewer edit ruling a mid-sprint halt**: a law or fixture that
could not pass in **any permitted build**, halted on rather than edited around, probed before
repair. The freeze held — the agent edited no frozen test at any point.

`git diff --stat ccd93cc HEAD -- tests/` → **17 files, 799 insertions, 137 deletions.**

| SHA | what it ruled |
|---|---|
| `859a85e` | two frozen-test defects — a binary-precedence comma, and `methodComment`, a selector 3.2.5 does not have |
| `c007999` | the purity law resolves an ordinary edge (the `Resolver` seeds from `dependencies` alone) |
| `3455c85` | the grammar bound law follows decision 84 — the moved verbs **re-asserted**, not merely removed |
| `a5545fe` | the sibling fixtures write an **author's** source, not the harness's (S9, S10) |
| `3121e78` | three reporting-matrix fixtures that could not pass — S6 cross-manifest, S21's exact edge, S24's retirement order |
| `a1dc212` | ninth round — two verified green, four advanced with probed causes |
| `2409ee2` | tenth round — the second header copy, S34's unrelated pin compared before-to-after |
| `6ca9a3a` | eleventh round — the eleven re-pins, S4's real second cause, an editing row that tested nothing |

**Three of these are findings rather than repairs**, and are named as such:

- **S4's "missing listing" was a misdiagnosis.** The diagnosis names the **cache** path, and the
  base already held `kernel-streams/versions.st` before the verb ran — publishing it again is a
  provable no-op. The real second cause was the **runner**: a `RecordingRunner` records the
  `curl` instead of running it, so nothing ever reached the cache. The scenario's declared cost
  is amended from the probe rather than from the plan — real processes now appear in S9, S10,
  S13, S17 **and S4**, where a recording double does not make the law cheaper but impossible.
- **The editing law's dev row was not testing its own subject.** Both rows removed
  `kernel-text`, which the dev row's manifest never declares — so that row asked the editor
  about an absent name and **could not have failed had `devDependency:constraint:` clauses been
  recognized**. Green by construction. Each row now removes the name its own clause kind
  declares, under a guard asserting that name is really in the file.
- **`testTheFourFirstLinesDifferFromEachOther` was falsified quietly** — §4.3 above.

**Two defects of the agent's own were caught by planted guards rather than by review**, and
both are worth the record:

- **The trap seam.** Inlining `resolve` to hold the snapshot for the conflict-provenance line
  moved the verb off `resolveAndLock:` — the method `ResolverTrapCLI` overrides. Both trap laws
  fired immediately. That is §8 decision 51's defect shape exactly: a settled consumer whose
  *meaning* changed without its code changing. Restored, with provenance taken from the
  manifest's own declarations instead.
- **The overlay bypass.** `seededSourceAdding:` still sent `seededWith:` to the bare source, so
  `info` and `add` saw a world with no path dependencies in it. Found by probing why `info`
  answered the settled not-published line about a name a directory really supplies. The rule
  was then **enumerated in its own units** rather than asserted: zero bare `source snapshot`
  sends, exactly two seeding entry points, both routing through `overlaidSource`, ten snapshot
  sends reaching one of them — the one deliberate non-wrap being `Installer source: source`,
  which is what the path-free view exists for.

---

## 6. Verifier discipline

The verifier ran **exactly once per code increment** throughout, every diagnostic taken from
that single run.

```
sprint: 21
date: 2026-08-13T18:51:03Z
toolchain: GNU Smalltalk version 3.2.5
PARLEY-SEED: 20260718
PARLEY-VERIFY: PASS seed=20260718 run=1091 passed=1091 failed=0 errors=0
```

`.parley/audit` and these notes agree on seed, counts and date.

**The companion check** (runbook §1 step 4, finding F24's own recommendation):

```
comm -12 <(grep '^PARLEY-FAILURE:' run.txt | sed 's/.*>>##//; s/.$//' | sort -u) \
         <(grep '^PARLEY-ERROR:'   run.txt | sed 's/.*>>##//; s/.$//' | sort -u)
```

**Empty.** Trivially so at full green, both sets being empty — but stated because it is the
check whose absence cost Gate A its first hour, and the close-out is where it becomes a habit.
gst 3.2.5 counts `runCount` as `passed + failures + errors`, and files a test under **both**
lists when `tearDown` raises after the body failed; that is what inflated Gate A's headline by
two.

**The circuit breaker tripped once, on a false positive**, and the mechanism was corrected
rather than the agent. Three consecutive non-zero exits are the normal state of a phased GREEN
build, but the trip came from the **identical-hash** branch: an operator verification run over
the same tree produced byte-identical output, so a one-actor breaker read a second actor's
legitimate work as a spin. Fixed by `verify-sprint.sh --observe` (`799dc51`), a full run that
neither reads nor writes breaker state. The agent halted immediately, attempted no reset, and
disclosed that its "zero failures" parse was an artifact of an empty log.

**Three harness findings, all of the same family** — a mechanism structurally blind to one
member of the class it guards:

1. **Ban 105's parenthesis blind spot.** It collapses parenthesised sends *before* counting, so
   a six-`with:` chain written as an argument — the commonest shape in a test — is erased before
   the regex sees it. Caught at runtime as a `doesNotUnderstand: #with:with:with:with:with:with:`.
2. **A method that fails to compile is silently omitted.** `Resolution.st:42` assigned an
   undeclared temporary; gst printed **one warning line**, continued loading, and left
   `fromLockEntry:` simply absent. Parse-error count stayed 0 and the gate reported clean. The
   interim mechanism is to probe every method an increment adds for **existence** before running
   the verifier, which is what found it.
3. **The breaker's one-actor assumption**, above.

---

## 7. What this sprint did not do

**The tag is not cut.** It is held on item 7, the release.

Optional dependencies and feature flags stay deferred — they move the entry schema decision 69
freezes. Workspaces stay deferred and are explicitly not this: no workspace manifest, no shared
lock, no member resolution. `add`/`remove` still refuse the two new clause kinds with the exact
text to paste or delete and the file byte-identical, which is Doc B §2.1's stated bound with its
trigger. No config key for `--offline` or `--locked` — they are per-invocation assertions, so
`#'parley-config' 1` is byte-identical. A warm-cache offline mode is not built: `--offline`
refuses network sources outright rather than serving stale caches.

**One carried observation, flagged and deliberately not fixed.** `exec`'s script precondition
resolves the script against the **process cwd**, while Doc E §4.2 rules that all state derives
from the **working directory**. They coincide under `bin/parley`, so it is invisible where users
stand and visible only where a working directory is injected. It is the conformance-gap family —
the doc promised, the code differed, nothing could see it. Fixing it moves settled `CliTest:441`
and sits outside every bound this sprint held, so it is Gate B's to rank.

Prereleases, backjumping and `PubGrubStrategy` are untouched; `Version` comparison was not
modified. A future `PubGrubStrategy` inherits path dependencies for free, because the overlay
composes into the snapshot and the search loop never learns that any of it happened.
