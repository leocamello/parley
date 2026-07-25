# Sprint 9 — the blame boundary

> **Issue:** [#11](https://github.com/leocamello/parley/issues/11) · **Specs of record:** Doc E §3, §4.1, §4.2, §5; Doc F §3; master plan §8 decisions 30–34.

Sprint 8 made the binary tell the truth about *whether* it failed. This sprint makes it tell the truth about **whose fault it was**, and makes every source Parley ships reachable from the binary.

---

## What was built

### `Parley.LockError` (`src/exec/LockError.st`, new)

The diagnosis for a `parley.lock` that cannot be read. It carries `problems` exactly as its batched siblings do, so the Sprint 8 boundary absorbed it with **no new mechanism**: the handler is derived from `CommandLine class >> batchedErrorClasses`, so adding the name to that list *was* the change. The declared diagnosed set is now **six**.

### The lock boundary — `CLI>>pinnedResolution` (declared settled-class exception 1)

The lockfile read is now a boundary. An unparseable lock, and one that parses but is not a `#'parley-lock' 1` artifact, each signal one `LockError`:

```
<lockPath>: <the reader's own message> - run parley update to rewrite it
```

The reader's message travels **verbatim** — it names a character position, and on a hand-edited file that position is the operator's only handle. The repair named is `parley update` because `update` is the one verb that never reads the lock; `testUpdateNeverReadsTheLockAndRepairsIt` and S3 prove the advice true rather than asserting it. `install` diagnoses and stops: repairing silently would make a damaged lock indistinguishable from a valid one (decision 29 applied to the lockfile). The settled reader and `Resolution fromLockEntry:` are consumed unchanged.

### The authoring boundary — `Parley.Parley class >> define:` + `ManifestFile load:` (declared settled-class exceptions 2 and 3)

An author error inside the developer's own `Package.st` is now the author's diagnosis at exit `1`, carrying the original error's own text unchanged:

- a **`ManifestVocabularyError`** ⇒ one `ManifestError` problem carrying the vocabulary error's message text verbatim, suggestion included;
- a **`ManifestError` from `ManifestBuilder>>build`** ⇒ re-signaled with its `problems` **intact**, never flattened.

`define:` captures and answers `nil`; `ManifestFile` signals from its own frame. Classification is by **handling** — two `on:do:` handlers, never an `isKindOf:` chain — so each arm carries exactly what its error knows. All three ordering rules from the ruling are implemented: both slots cleared at entry, the captured error checked **before** the `recorded isNil` check, and first-error-wins across repeated `define:`.

### `--git <repo>` and the source flag table — `CommandLine`

`CommandLine class >> sourceFlags` is a declared table of `(flag, source class, builder message)`. It is consumed twice — the wiring is built from it and the source drift law reads the same rows — so the wiring and the law cannot disagree. `--git <repo>` builds a `GitIndexSource` whose checkout is `<workingDir>/.parley/git/<sha256 of the repo location>`; keying through the settled `Sha256` turns any repo string into one deterministic filesystem-safe name, so no escaping layer was invented. `--source` and `--git` together are a usage error at exit `2`, answered by the settled CLI itself so the two grammars can never print different usages. `GitIndexSource` was **consumed, not modified**.

### The exit criterion, met

Every Parley error class is now either diagnosed at exit `1` or **provably never signaled out of a verb**. Doc E §4.2's strong claim is true again, and S7 demonstrates it mechanically: each of the five declared-undiagnosed classes is driven through a real verb with a real input, and each row pairs a *raw* driver (proving the input reaches that class's signal site) with a *verb* driver (reading the answer the operator gets). The weaker ground stays in the doc with no members.

---

## Verification evidence

```
sprint: 9
date: 2026-07-25T19:29:19Z
toolchain: GNU Smalltalk version 3.2.5
PARLEY-SEED: 20260718
PARLEY-VERIFY: PASS seed=20260718 run=500 passed=500 failed=0 errors=0
```

Toolchain: `gst --version` → **GNU Smalltalk version 3.2.5**; `gst-package --version` → **gst-package - GNU Smalltalk version 3.2.5**; `git --version` → **git version 2.43.0**.

Suite: 461 settled laws → **500** (39 added). `tmp/` absent after the run; the developer image was never mutated; no network was contacted — every fixture repository is a local path under `tmp/`, built through `ProcessRunner` with the committer identity supplied per command.

**Green increments** (one verifier run each, the prescribed order; the breaker's progress-awareness kept the streak reset throughout):

| # | Increment | passed |
| --- | --- | --- |
| 0 | RED gate | 469 (21 failed, 8 errors) |
| 1 | `LockError`, alone | 474 |
| 2 | the lock boundary | 483 |
| 3 | the authoring boundary (both arms) | 485 → **490** after the regression fix |
| 4 | `sourceFlags` + `--git` | **500** |

---

## Ambiguities hit, and how they were resolved

### 1. Doc E §3's boundary could not be built where the doc placed it (RED — escalated, ruled)

Doc E §3 said the file-in inside `ManifestFile load:` "is wrapped". **That is impossible on 3.2.5.** Probed before writing a line of test code:

- the doit context of a filed-in statement is **parentless** — `thisContext parentContext` answers `UndefinedObject>>__terminate`, not the caller of `fileIn:`;
- so an `on:do:` around `FileStream fileIn:` is not in the signaling chain and never fires. gst prints its own backtrace and abandons the statement;
- a handler in a method **called by** the filed-in statement does catch it, with the message intact and the file-in continuing.

Sprint 8's declared escape ("`ManifestVocabularyError` escapes `load:` → exit 70") was therefore also wrong: it was *swallowed*, which is worse — a confident wrong sentence ("no manifest defined" about a file that did send `define:`) preceded by a dump.

**Resolution:** halted at the RED review with the probe evidence and requested a third settled-class exception on `Parley.Parley class >> define:` — the one Parley frame a filed-in `Package.st` enters. The operator verified independently, additionally probed `Behavior>>evaluate:` (fails identically), granted it, and **widened it to `ManifestError`** (§8 decision 34), with three load-bearing ordering rules and the batch-preservation requirement. Doc E §3 was rewritten with the verified mechanic so no future sprint re-derives the dead end.

### 2. The widening broke five settled Sprint 1 laws (GREEN — found and fixed)

Capturing unconditionally in `define:` also swallowed errors from a **live** `Parley define:`, breaking the settled authoring contract that `define:` signals to its own caller (Sprint 1 S4–S8). Fixed by scoping the boundary to the one context whose signaling chain is cut: `ManifestFile class >> isLoading`, set across the file-in, is what `define:` asks; anywhere else the error is `pass`ed on untouched. Increment 3's first run is the record of the regression and its repair.

### 3. The diagnosed-set oracle had to move in RED

`CommandLineFixtures diagnosedErrorClassNames` went from five names to six, which is exactly the deliberate decision the closed-set drift law exists to force. Three settled laws (`DiagnosisBoundaryTest`, `Sprint8AcceptanceTest testS7`, `CommandLineTest`) therefore failed in red **by design** and returned in green. Declared at the RED review and approved.

### 4. Two enumeration questions, probed rather than assumed

`(File name: 'src/source') files` answers the three regular `.st` files, so `files` is correct for the source drift law — unlike Sprint 8's `src/` law, which enumerates *directories* and needs `namesDo:`. `testTheFixtureEnumerationSeesTheShippedSources` guards it against the empty-collection trap (the decision-33 lesson). The `--git` mutual-exclusion scenarios pass in red for an unrelated reason and were declared as such rather than dressed up.

---

## Operator amendments

- **§8 decision 34** and the Doc E §3 rewrite, §4.2 correction and §5 obligation — the ruling above, landed operator-side before GREEN.
- The widened arm's **two additional laws** were specified by the operator and are in `LockBoundaryTest`: the batch-preserved `ManifestError`, and its no-backtrace twin through the shipped binary (the only law in that file that spawns — gst's dump reaches a *terminal*, and no value-level law can see one).
- One framing correction accepted: S7's `VersionFormatError` row drives the index-entry reader, not a `Package.st`, so no existing law covered the build-time swallow. The widening was a genuine addition justified by the §4.2 no-backtrace invariant, not something an existing red test already demanded.

---

## Noted, not built

- **A semantically broken but well-formed lock.** A `#'parley-lock' 1` artifact that parses and carries the right tag but has a malformed body (a missing `#packages` key, say) still reaches `Resolution fromLockEntry:` and fails with a **kernel** error at exit `70`. Doc E §4.1 specifies exactly two rejection grounds — does not parse, wrong tag — and both are closed. The closed-set law does not see this because it enumerates *Parley* error classes only; a lock schema validation mirroring Doc F §4's entry-shape check is the shape of the fix.
- **Retire/yank schema headroom** — deliberately excluded (the landscape audit's top recommendation); it is a schema decision deserving its own staging.
- **A prebuilt image.** Every `bin/parley-main.st` invocation still files in all of `src/`; the shipped-binary and end-to-end laws pay that cost per child. Deferred tooling polish, unchanged since Sprint 8.
- **`RegistrySource`, hosting, signing, yanking** (decision 27); prereleases, backjumping, `PubGrubStrategy`; network git; output capture and any shell-quoting layer — all still deferred, none touched.
- **`--git` refresh semantics are the settled source's.** A second `resolve --git` reuses the checkout and pulls `--ff-only`; a cache whose repo location changed gets a *different* directory, because the cache name is a pure function of the repo string. Nothing prunes old checkouts — `<work>/.parley/git/` grows one directory per distinct repo location, and no verb removes them.
