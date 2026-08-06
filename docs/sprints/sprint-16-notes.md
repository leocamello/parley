# Sprint 16 — v1.0 readiness: name the file, match the exit code, check the claim

**Issue:** #18 · **Specs of record:** Doc E (`docs/design/execution-and-cli.md`) **§4.1** and **§4.2**, with §3 step 0 · **Decisions:** §8 **56**, **57** and **58** (this sprint's rulings), beside **31**, **44**, **45**, **46**, **49**, **52** and **55**.

**Nothing here is a missing feature.** The product was code-complete and uncut, and it was walked end to end by hand before the tag. The happy path was clean and the diagnoses were, with five exceptions, exactly right — each naming the file *and* the remedy. Every one of the five was the tool disagreeing with itself, and every one sits on a path a new user reaches in their first session.

One sentence governs the sprint, and it is §8 decision 58 generalized: **a diagnosis that names a cause has made a claim, and this tool only makes claims it has checked.** It is why the held-pins line is now earned rather than guessed. It is also why decision 56 exists — a boundary that validates what a file *says* has already claimed the file could be read.

## The five defects, before and after

Every "after" below is the **shipped `bin/parley`**, run by hand against a scratch project after GREEN. The "before" texts are the readiness audit's own recordings (issue #18, decisions 55–58), except where noted as re-probed here.

### 1. `parley exec` answered exit `0` for work that never ran

**Before** — re-probed directly against the toolchain, since this half is 3.2.5's behaviour rather than Parley's:

```
$ gst -i -I .parley/packages/parley.im --no-user-files typo.st
gst: Couldn't open file `typo.st': No such file or directory
$ echo $?
0
```

and for a directory argument, exit `0` with **nothing printed at all** — the worse of the two shapes, because a first user has nothing on screen to read. Parley passed both through faithfully, which is exactly what made it wrong: §8 decision 45's documented consumer constraint (end the script with an explicit `ObjectMemory quit:`) is unavailable precisely here, since a file that does not exist cannot carry a guard.

**After:**

```
$ parley exec typo.st
typo.st: missing or unreadable script - nothing was run
$ echo $?
1
$ parley exec adir
adir: missing or unreadable script - nothing was run
$ echo $?
1
```

Nothing is spawned — asserted on a recording runner, because *it exited 1* is satisfied equally well by a spawn that happened to fail.

### 2. A directory-shaped `parley.lock` blamed Parley and never named the file

**Before** (audit):

```
$ parley check --source ../index
internal error: WrongClass: Invalid argument -9223372036854771711: must be a SmallInteger - this is a defect in Parley, not in your project
$ echo $?
70
```

A kernel integer on the operator's screen, a lie about whose fault it is, and the offending file never named. `parley resolve` against the same project answered the same thing.

**After:**

```
$ parley check --source ../index
/…/proj/parley.lock: not a regular readable file - remove it and run parley resolve to write a new one
$ echo $?
1
$ parley resolve --source ../index
/…/proj/parley.lock: not a regular readable file - remove it and run parley resolve to write a new one
$ echo $?
1
```

Same single sentence from `check`, `why`, `tree`, `install`, `add`, `update <pkg>`, plain `update` and `resolve`. A lock that is *readable but malformed* still leaves `resolve` at exit `0`, unchanged.

### 3. `--help` exited `2` while `--version` beside it exited `0`

**Before** (audit): the usage text was printed, at exit `2`, for `--help`, `-h` and `help` alike — so the first command a new user types failed any `set -e` script or CI smoke check, while `parley --version` succeeded.

**After:**

```
$ parley --help; echo $?
usage: parley <verb> [--source <dir> | --git <repo> | --index <base>]
verbs: init | resolve | install | update [<pkg>] | add <pkg> <constraint> | exec <script> | publish <dir> | why <pkg> | tree | check
flags: --source <dir>  index entries in a local directory
       --git <repo>    index entries in a git repository
       --index <base>  index entries fetched per package from a sparse index
       --layout <name> flat (default) or sparse, the index layout publish writes
0
$ parley -h >/dev/null; echo $?
0
$ parley help >/dev/null; echo $?
0
```

The usage block did not move: `--help` prints what was already there and adds no line to it, so `ExecFixtures usageLines` needed no re-pin. `parley` with no argv, `parley nonsense`, `parley resolve --help` and `parley resolve --version` all still answer exit `2`.

### 4. `add`/`update <pkg>` led a conflict with a remedy that cannot work

**Before** (audit):

```
$ parley add nosuch ^1.0 --source ../index
the other pins were held at their locked versions - run parley update to move everything
no version of nosuch satisfies >=1.0.0 <2.0.0
$ echo $?
1
```

An instruction that cannot help, printed first, on the commonest error there is — a typo'd package name.

**After:**

```
$ parley add nosuch ^1.0 --source ../index
no version of nosuch satisfies >=1.0.0 <2.0.0
$ echo $?
1
```

The line is not deleted; it is **earned**. When holding really is the reason — the unheld re-resolution succeeds — it is still present and still first, on both verbs.

### 5. Every usage error created `<cwd>/.parley/packages` before refusing

**Before** (audit): `parley`, `parley nonsense` and `parley resolve` each created the state directory *before* printing the usage they were always going to print. Found the hard way — a bare `parley` from the repository root during the audit created `.parley/packages` there and broke two settled laws. The tool contaminating its own checkout, caught by the suite rather than by anyone noticing.

**After**, in an empty directory:

```
$ parley >/dev/null; echo $?
2
$ parley nonsense >/dev/null; echo $?
2
$ parley resolve >/dev/null; echo $?
2
$ parley --help >/dev/null; echo $?
0
$ ls -A
$
```

Four refusals and one question, and the directory is still empty.

## Ambiguities hit, and how they were resolved

### 1. S17 needed the usage determination, and it lived in the settled `CLI` (RED — halted and asked)

`createStateDirectories` had to run *after* the usage determination, and `CommandLine` could not make that determination. `parley` (empty argv) it could see; `parley nonsense` needs the verb list and `parley resolve` needs to know which verbs require a source — both `CLI` knowledge. Three alternatives were tried on paper and rejected with reasons: duplicating the grammar in `CommandLine` is the drift `sourceFlags`, `publishLayouts` and `deserializationBoundaries` each exist to prevent; creating the directories *after* the run is impossible, because `ContentStore>>ensureRoot` needs `.parley` to exist and **`Directory create:` is not recursive** (probed); and create-then-delete satisfies S17's assertion while violating the rule the assertion is about.

**Halted and asked rather than guessed.** Ruled in the agent's favour as the **fourth declared `CLI` exception**, with three binding constraints, all met: the dispatch is expressed in terms of the predicate (`verbRows` is one declared table that `run:` performs from and `verbRowFor:withSource:` answers the determination from — not a parallel list that happens to agree today); the predicate is a function of argv and source-*presence* alone and touches no filesystem; and `cliWithSourceIn:` stays *below* `createStateDirectories`, because the `--git`/`--index` builders create their cache roots under `.parley/`.

### 2. What carries the `exec` refusal

Doc E §4.1 says *the verb answers one line naming it, exit `1`*; the Stage 2 verdict says *the two applications of decision 56 signal two different declared errors*. Read together and **ruled as read**: `CLI>>exec:` signals an `ExecutionError`, which the §4.2 boundary maps to one line at exit `1` — identical observable, and the diagnosis stays inside the declared taxonomy like every other `<path>: …` sentence in the tool, all of which are signalled declared errors. `ExecutionError`'s `command` and `exitCode` slots stay `nil`, which is the honest record: no command was composed and no child had an exit code.

### 3. The lock repair line named the verb that answers the same refusal (RED — flagged, operator-corrected)

Decision 56 and Doc E §4.1 both pinned the three-part shape as *(path, defect, `parley update`)*. `parley update` is the **corrupt**-lock repair because it is true *by construction* — `update` is the one verb that never *reads* a lock. A directory-shaped lock breaks the construction: `update`'s **write** cannot succeed either, which is what this sprint's own `testPlainUpdateRefusesAnUnreadableLockItCannotRewrite` asserts. The shipped shape would have answered the defect by naming the verb that answers the same refusal — decision 58's standard broken by the sentence next door to it.

**The pinned shape was shipped in RED and the tension flagged rather than quietly edited.** The operator ruled: the shape stays, the repair changes, and its tail is the **settled missing-lock repair** — once the path is removed the lock is *missing*, not corrupt, and `resolve` is the verb that writes a first one. Doc E §4.1 and decision 56 were amended in the same commit.

### 4. Eleven settled laws handed `exec` a script that was never written (RED — asked, sanctioned)

`CliTest` ×1, `Sprint6AcceptanceTest` ×1, `CommandLineTest` ×7 (through one `execResultIn:runner:` helper) and `Sprint8AcceptanceTest` ×2. Their claims — the exit-code pass-through and the diagnosis boundary — are untouched; their *fixtures* were not there. A law claiming to prove exit-code pass-through while handing the runner a path nobody ever wrote was already not testing its claim, so restoring the fixture strengthens.

**Sanctioned, four additions, zero assertion changes**, with `tmp/` for the two literal-path laws so their pinned command lines stay byte-identical — and required to land **as the first GREEN increment, alone**, where the checkpoint is exact.

### 5. Closing the lock boundary took the two Sprint 15 decision-52 laws' driver with it (GREEN — halted, ruled against)

`ReleaseHardeningTest testASeedGatheringFailure…` and `Sprint15AcceptanceTest testS14_…` were both driven by a directory-shaped `parley.lock` asserting exit `70`, which decision 56 now diagnoses at exit `1`. Decision 55 predicted exactly this: *it reopens as soon as any sprint touches the §4.1 lock boundary.* The agent found the equivalent hole in `ManifestFile>>load:` — `exists` alone, so a directory-shaped `Package.st` reaches `FileStream fileIn:` and signals `SystemExceptions.PrimitiveFailed` (probed) — and **recommended re-driving the two laws onto it and ranking the hole as a carried gap.**

**Ruled against, on four probes the agent had not run**, and the ruling is the better one:

| State | Shipped answer, before |
| --- | --- |
| `Package.st` is a directory | exit `70`, `PrimitiveFailed` |
| `Package.st` has no read permission | exit `70`, `FileError: could not open …` |
| top-level DNU inside `Package.st` | swallowed by gst, exit `0` |
| `define:` block divides by zero | swallowed, surfaces as an ordinary `ManifestError`, exit `1` |

Three things follow. **The hole is not about directories** — row 2 is a bad umask or a root-owned checkout, more reachable than the state the agent found, and it answers by blaming Parley. **It is not a new ruling but a conformance gap**: Doc E §3 step 0 has read *"does not exist or is not readable"* since Sprint 8 and the pinned diagnosis has promised *missing or unreadable Package.st* for just as long, while the code checked `exists` alone — the oldest boundary in the CLI asserting a check it never made, so the predicate is brought into line and **the wording does not move**. And rows 3 and 4 show gst swallows anything raised by filed-in manifest code, so **the only escape from either half of `seedNames` was ever a boundary skipping its readability check** — closing both leaves decision 52's exit-`70` branch with no reachable filesystem driver *by design*. That is the rule succeeding, not coverage lost.

So: `ManifestFile` closed as decision 56's **third application** (the fifth declared settled-class exception), and the two laws **re-driven by fault injection at the seam** — `SeedFaultCLI`, a `CLI` subclass whose lock read signals an error outside both declared boundaries, wired through `SeedFaultCommandLine` so the fault is raised in a real run and observed at the real §4.2 boundary. Both laws keep every assertion verbatim; only the driver moved. The precedent is `InspectionFixtures`' settled `ResolverTrapCLI`. **A law that can only pass while a hole is open is a law underwritten by a defect** — which is how the lock hole survived two sprints.

## Operator amendments

**Gate A (RED review).** Three, all strengthening: the lock repair pin (ambiguity 3); **S8 extended to prove `--help` through `bin/parley` itself**, because the in-image helper spawns `parley-main.st` with `-a` while the wrapper execs it with `-f … --`, and exit `0` for the *question* through the wrapper is the composition neither the marker law nor the settled wrapper law makes — and it is what a CI smoke check actually runs; and the issue body declaring the fourth `CLI` exception, the fixture sanction and the corrected pin.

The operator also checked a premise the RED report left unguarded: the two held-pins laws that assert the line is **present** carry no unheld-resolution guard of their own, so a correct GREEN could have made them unsatisfiable. They hold — the held-conflict index does resolve unheld.

**Mid-sprint (GREEN).** The `ManifestFile` ruling above (ambiguity 5).

**One process note, recorded rather than argued away.** The first GREEN increment's checkpoint was `passed=768 failed=27` with the same twelve names. I truncated that run's output to its last few lines and lost it. I did not re-run — an unchanged re-run is the breaker's fast-trip condition — and confirmed the checkpoint from `.parley/loop-state`, whose third line records `768`. **The state file agrees; the output is gone.** That is adequate evidence and it is not the same thing as having read the run.

## What was built

**No new class, no new directory, no new file format**; `scripts/run-tests.st` unchanged and `scope-16` identical to `scope-15`. Three declared settled-class exceptions at RED, plus two granted mid-sprint:

- **`Parley.CLI`** — `requireReadableLock` and `unreadableLockLine` (the readability precondition, called from `pinnedResolution` *and* from `resolveAndLock:`, which is the path `resolve` and plain `update` take and which cannot delegate to seeding, since `seedNames` catches `LockError` by construction); `requireRunnableScript:` and `unrunnableScriptLineFor:` (the `exec` precondition, before any process is composed); `conflictLinesFor:manifest:unheld:` (the checked held-pins line, **one method serving both verbs** — the Sprint 13 shared-diagnosis precedent); and, granted at Gate A as the **fourth** exception, `verbRows` / `verbRowFor:withSource:` / `row:verb:args:` with `run:` rewritten to perform the selected row.
- **`Parley.CommandLine`** — `helpFlags`, `isHelpRequest:`, `helpResult` (the second declared question flag, recognized as narrowly as the first: the whole argv is one of the three spellings and nothing else), and `answersUsageFor:` with `createStateDirectories` moved below it.
- **`Parley.ManifestFile`** — granted mid-sprint as the **fifth** exception: `load:`'s path check becomes `isFile and: [isReadable]`, the predicate decision 56 gives every file boundary. The pinned wording is unchanged.
- **The README** — the `exec` precondition documented beside decision 45's consumer constraint rather than instead of it (they are neighbours and easy to confuse), and `--help` wherever `--version` appears, in all three spellings. Guarded by the settled Sprint 15 verb drift law, which still passes.

`Resolver`, `IndexSnapshot`, `BacktrackingStrategy`, `ConstraintLedger` and every `*Source` are **consumed, never modified**: decision 58's unheld re-resolution runs the settled resolver against the settled snapshot, and the snapshot it uses is the one `holding:` was derived *from* — kept rather than re-taken, because `holding:` answers a new value and leaves the receiver answering every version (the Doc C §2.2 purity law). Nothing learned about holding.

### Why the dispatch table is not a refactor for its own sake

The argv grammar is unchanged verb for verb and arity for arity; only its spelling moved. It moved because the usage determination needed **one** definition rather than two agreeing ones — a parallel verb list would buy nothing the first time a verb was added to only one of them. It is the same shape as `sourceFlags`, `publishLayouts` and `deserializationBoundaries`: a declaration consumed twice.

## Verification evidence

```
sprint: 16
date: 2026-08-06T21:11:44Z
toolchain: GNU Smalltalk version 3.2.5
PARLEY-SEED: 20260718
PARLEY-VERIFY: PASS seed=20260718 run=795 passed=795 failed=0 errors=0
```

Exact `gst --version` (first line; the banner continues with the 2009 FSF copyright, the GPL notice, and the default kernel/image paths `/usr/local/share/smalltalk/kernel` and `/usr/local/var/lib/smalltalk`):

```
GNU Smalltalk version 3.2.5
```

795 laws, up from Sprint 15's 756: **39 new** — 17 acceptance scenarios and 22 laws. GREEN landed in seven increments, riskiest first and each one verifier run; the breaker never rose above 1/3 because every run detected progress:

| # | Increment | passed |
| --- | --- | --- |
| 1 | the eleven sanctioned `exec` fixtures, **alone** | 768 (checkpoint, unchanged) |
| 2 | the lock readability check | 772 |
| 3 | the `exec` script precondition | 776 |
| 4 | the checked held-pins line, `add` then `update <pkg>` | 780 |
| 5 | the question flags + the `createStateDirectories` reordering | 790 |
| 6 | the README | 793 |
| 7 | `ManifestFile` closed + the two laws re-driven | **795** |

**Six toolchain facts were probed rather than assumed**, and four of them changed how something was written:

- **`File>>exists` answers `true` for a directory**; `isDirectory` `true`, **`isFile` `false`**, `isReadable` `true`. The root of two of the five defects.
- **`File>>isFile` answers `false` for an absent path too**, and `isReadable` `false` for a file whose permissions deny the reader. So `isFile and: [isReadable]` is the whole predicate — and the reason `testAnAbsentLockIsStillAbsentRatherThanUnreadable` exists, because a check written as one predicate turns every lockless project into a lock defect and destroys the settled missing-lock diagnosis, which names a *different* verb.
- **`File>>contents` on a directory signals `SystemExceptions.WrongClass`** carrying `Invalid argument -9223372036854771711: must be a SmallInteger` — the kernel integer that reached the operator's screen.
- **`FileStream fileIn:` on a directory signals `SystemExceptions.PrimitiveFailed`** — the `ManifestFile` half of the same hole.
- **`Directory create:` is not recursive** (`FileError: No such file or directory` on a nested path). This is what ruled out creating the state directories after the run, and therefore what made the fourth `CLI` exception necessary.
- gst answers **exit `0`** both for a script argument that does not exist and for one that is a directory. `doWithIndex:` and `perform:withArguments:` are both available on 3.2.5.

No scenario contacts a network and none runs git. Every fixture path is under `tmp/`, removed recursively in tearDown; `tmp/` is absent after a clean run.

## Noted, not built

- **Nothing in the out-of-scope list was touched.** Output capture and toolchain-chatter suppression stay deferred and were declared as a collision at Stage 1: `publish`, `add` and `install` still stream `gst-package`'s `mkdir`/`ln`/`zip` and `install -c` lines, and `exec` still streams `"Global garbage collection... done"`. That is noisy and it is **honest** — the child writes to Parley's own stdout by design (Doc E §1). No hosting, signing, yanking, `RegistrySource`, prereleases, backjumping, `PubGrubStrategy`, `remove`, constraint editing or cache pruning. The prebuilt image stays deferred; none of decision 54's three triggers fired.
- **Decision 45's substance is unchanged.** A script that runs and fails still exits `0` on 3.2.5, and the guarded-script idiom is still the documented answer. This sprint added the boundary *before* the child, never a claim about the child — `testS3_…` and `testAScriptThatRunsStillPassesItsExitCodeThrough` are the guards.

## Close-out

**Decision 55 is closed and decision 56 has three applications, not two.** The third — `ManifestFile` — was not scope growth but a **conformance gap**: Doc E §3 step 0 promised a readability check from Sprint 8 and the code never made it, so the tool spent eight sprints asserting something it had not checked. It was found only because closing the lock boundary took two settled laws' driver away and forced someone to look. That is worth recording: the gap was invisible while the *sentence* was right and the *predicate* was wrong, which no drift law in this repository can see.

**A carried gap, unscheduled.** The two decision-52 laws are now driven by injected faults rather than by operator states, which is correct — but it means the exit-`70` branch of the §4.2 boundary has **no reachable filesystem driver at all**. That is the design working, and it is also a claim that will need re-checking the next time a file boundary is added: the enumeration that would catch a *new* boundary skipping its readability check does not exist. `deserializationBoundaries` enumerates readers of the literals-only parser, and `ManifestFile` is in it — but it is in it because someone wrote it down, not because a law can see the missing predicate. **Ranked, not scheduled.**

**The exit criterion, met.** S16 runs the first session end to end with the real toolchain: an empty directory, `parley --help` creating nothing, `init`, a typo'd `exec` refused at exit `1`, `add` of a real `gst-package`-built archive that resolves, hash-verifies and registers, `resolve`, `check`, and finally an `exec` whose curated child answers `present`. Every exit code matches what happened, every failure names its file, no command answers a backtrace or a kernel integer, and the only `.parley/` that exists is the one the verbs created.
