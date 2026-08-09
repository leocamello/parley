# Sprint 17 — the boundary table: every diagnosis earns its predicate

**Issue:** [#19](https://github.com/leocamello/parley/issues/19). **Roadmap §2 item 1 of the seven that hold the v1.0 tag** — the tag is **not** cut.

```
sprint: 17
date: 2026-08-09T18:33:55Z
toolchain: GNU Smalltalk version 3.2.5
PARLEY-SEED: 20260718
PARLEY-VERIFY: PASS seed=20260718 run=847 passed=847 failed=0 errors=0
```

`gst --version` reports **GNU Smalltalk version 3.2.5** exactly.

---

## 1. What the sprint was for

Sprint 16 ruled §8 decision 56 as a general rule — *a boundary that reads a file begins by requiring that path to be a regular readable file* — and applied it to three boundaries. Its close-out probed the rest of the domain through the shipped binary and found **six ordinary filesystem states still answering `internal error: … - this is a defect in Parley, not in your project` at exit `70`**, three of them naming no path at all. Five were the rule's mirror: decision 56 governs *reading*, and nothing governed *writing*. A **seventh** was probed at the Gate C amendment and was worse — the canonical installation, a symlink from a directory on `PATH`, printed `gst`'s own message and exited **`0`**.

The deeper reason this was a sprint and not seven patches: `ManifestFile` said `missing or unreadable Package.st` from Sprint 8 while its predicate tested `exists` alone. Eight sprints of a right sentence over a missing predicate, invisible because reviewers read the sentence and nothing in the repository could compare a sentence against a check.

## 2. What was built

**`Parley.PathGuard`** (new, `src/compat/`) — the single site in Parley that performs file I/O. It carries the two write predicates and the read predicate, the diagnosis composition, and every filesystem operation the tool makes. It **prechecks**, so a refusal happens before anything is created (the atomicity `publish` and `add` need), **and translates**, wrapping the operation in a broad catch that answers the caller's own declared refusal naming the path.

Broad is correct and does not contradict §8 decision 52: that decision governs a catch that *defers*, and this one *owns* the diagnosis with nothing but the operation inside the guarded block. Two consequences the docs now state: the TOCTOU window can still occur but can no longer produce a bad diagnosis, and disk-full, a read-only mount and every mode nobody listed answer the same good sentence.

**The census, routed.** All eight declared classes — `CLI`, `Publisher`, `SparseIndexSource`, `ContentStore`, `ManifestFile`, `DirectorySource`, `GitIndexSource`, `CommandLine` — now route their I/O through the chokepoint and add their own diagnosis. The census walk over `src/` finds direct `File`/`FileStream`/`Directory` sends in exactly two files afterwards: `src/compat/PathGuard.st` (15 sites — it *is* the chokepoint) and `src/exec/ManifestFile.st` (one: `FileStream fileIn:`, deliberately untranslated, §5 below).

**`CommandLine class >> pathBoundaries`** — twelve rows, each naming its path role, its direction, its declared error, and how it is guarded. Nine an operator reaches by running a verb; three the tool reaches on its own behalf.

**`bin/parley`** — resolves its symlink chain, honours a pre-set `PARLEY_ROOT`, and checks its main script before exec'ing `gst`, exiting `70` naming the path when it is absent (§8 decision 66). It must check rather than delegate: `gst -f <missing file>` exits `0` on this toolchain.

**README** — the permission diagnostics and, for the first time, the installation route. Documenting it was pointless while it was broken.

## 3. The seven probed states, before and after

Shipped text, captured through `bin/parley` on the pre-sprint tree and again on the wrapped one. Fixture paths are the probe's own.

### State 1 — read-only `parley.lock`, `resolve`

```
$ /home/lhnascimento/Projects/parley/bin/parley resolve --source …/probe/idx
internal error: FileError: could not open /tmp/…/probe-before/p1/parley.lock - this is a defect in Parley, not in your project
$ echo $?
70
```
```
$ /home/lhnascimento/Projects/parley/bin/parley resolve --source …/probe/idx
/tmp/…/probe-after/p1/parley.lock: could not be written - check its permissions and try again
$ echo $?
1
```

### State 2 — read-only project directory, `resolve` (no lock)

```
internal error: FileError: Permission denied - this is a defect in Parley, not in your project
$ echo $?
70
```
```
/tmp/…/probe-after/p2: could not be written - check its permissions and try again
$ echo $?
1
```

### State 3 — read-only `Package.st`, `add`

```
internal error: FileError: could not open /tmp/…/probe-before/p3/Package.st - this is a defect in Parley, not in your project
$ echo $?
70
```
```
/tmp/…/probe-after/p3/Package.st: could not be written - check its permissions and try again
$ echo $?
1
```

### State 4 — `init` into a read-only directory

```
internal error: FileError: Permission denied - this is a defect in Parley, not in your project
$ echo $?
70
```
```
/tmp/…/probe-after/p4: could not be written - check its permissions and try again
$ echo $?
1
```

### State 5 — `publish` into a read-only destination

```
internal error: FileError: Permission denied - this is a defect in Parley, not in your project
$ echo $?
70
```
```
/tmp/…/probe-after/p5dest: could not be written - check its permissions and try again
$ echo $?
1
```

### State 6a — unreadable index entry `.st`, `resolve`

```
internal error: FileError: could not open /tmp/…/probe-before/idx6/c-2.4.0.st - this is a defect in Parley, not in your project
$ echo $?
70
```
```
c-2.4.0.st: missing or unreadable entry file
$ echo $?
1
```

### State 6b — unreadable `.star`, `install`

```
internal error: FileError: could not open /tmp/…/probe-before/idx7/a-1.0.0.star - this is a defect in Parley, not in your project
$ echo $?
70
```
```
a 1.0.0: fetch failed - Source directory has 1 problem(s): a-1.0.0.star: missing or unreadable archive file
$ echo $?
1
```

### State 7 — the shipped wrapper through a symlink

```
$ ln -s ~/Projects/parley/bin/parley <dir on PATH>/parley
$ parley --version
gst: Couldn't open file `/tmp/…/scratchpad/bin/parley-main.st': No such file or directory
$ echo $?
0

$ parley --version          # through a symlink to a symlink
gst: Couldn't open file `/tmp/…/85933e50-…/bin/parley-main.st': No such file or directory
$ echo $?
0
```
```
$ parley --version          # symlink on PATH
parley 1.0.0
$ echo $?
0

$ parley --version          # through a symlink to a symlink
parley 1.0.0
$ echo $?
0
```

### State 7b — a pre-set `PARLEY_ROOT`, main script absent

```
$ PARLEY_ROOT=/tmp/claude-1000/emptyroot ./bin/parley --version
parley 1.0.0
$ echo $?
0
```
*(the pre-set value was discarded: the wrapper recomputed `PARLEY_ROOT` from `$0` and ran normally — which is why the missing-script state was unconstructible)*
```
$ PARLEY_ROOT=/tmp/claude-1000/emptyroot ./bin/parley --version
parley: cannot find /tmp/claude-1000/emptyroot/bin/parley-main.st - this Parley installation is incomplete
$ echo $?
70
```

## 4. Ambiguities hit, and how each was resolved

**The declared error for the state-directory row — asked, not invented (§8 decision 72).** Probed at RED: in a read-only working directory the *first* thing that fails is `CommandLine createStateDirectories`, for every verb, before the verb's own boundary is reached. No settled error obviously fit and the issue declared exactly one new class, so this was a halt-and-ask. Ruled `ExecutionError`, no new class — with a binding bound: the row records itself as *the wiring state directory*, and the table states that `ExecutionError` is the **carrier** for a filesystem precondition rather than an attribution. An `init` refused in a read-only directory has nothing to do with executing anything.

**The prohibition's exemption list — the issue and Doc E read differently.** The issue calls `PathGuard` *the single site*; Doc E §4.1 says *a ninth class performing direct `File` I/O fails the law*, with the eight-class census as the exemption list. Docs win, so the law exempts the eight and states its own bound: the live claim is that a ninth never starts. In practice the routing went further than the law requires — nothing outside the chokepoint does direct I/O at all, save the one ruled exception.

**The structural law versus a settled carrier (§8 decision 73).** Halted mid-GREEN. `DirectorySource` signals its own `SourceError` naming the archive, but the only verb that reads a `.star` is `install`, and `Installer` prefixes `'<name> <version>: fetch failed - '` — a literal law-pinned for the archive-*absent* case. Three tests asserted the *verb-level line's* shape and no in-scope implementation could satisfy them; making the unreadable case answer differently from the absent one would have been the regression. Ruled: **the law asserts the line ends with the row's declared sentence and that the sentence opens with the path** — as strong as before for eleven rows, and for the twelfth it admits the carrier while keeping the sentence intact and path-first. The vacuity the earlier strengthening closed stays closed: the abolished `internal error: …` ends with no row's *declared* sentence. What bounds the prefix is named rather than left to silence — S12 drives the same twelve rows under both hostile states and holds every one to never exit `70`, never name a kernel class, never print a backtrace and never carry the undiagnosed prefix.

**Two ambiguities that turned out to be test defects, both self-caught, both repaired at RED:** the `SourceFixtures` diamond paired with the `InstallFixtures` lock oracle (different digests, and `add`/`install` run the full pipeline), and a structural law that passed vacuously because `internal error: FileError: could not open <path> - this is a defect in Parley…` genuinely contains a path, a cause and a remedy.

## 5. Precheck yes, translate no — the one ruled exception

`ManifestFile` prechecks through `PathGuard isReadableFile:` and leaves its `FileStream fileIn:` **untranslated**. That is a ruling, not an omission: the guarded block would contain the author's whole program, so a broad translation would relabel a vocabulary typo or a division by zero as an I/O failure — decision 52's discriminator, in the one place this project has been most careful about blame. Sprint 18 owns that boundary.

It is recorded as the **fourth column of the boundary table** (`#prechecked` against every other row's `#guarded`) with a law over it, rather than as prose. Sprint 8's `ManifestFile` defect was a right sentence over a missing predicate that survived eight sprints precisely because the reasoning lived where nothing could compare it against the code.

## 6. Method evidence: a driver that never evaluated hid a defect the gate could not see

Recorded because it is evidence about the pipeline, not merely a fixture fix.

`BoundaryTableTest` and S12 error out in red on the `pathBoundaries` MNU. The driver *builders* run — they are evaluated to construct the row list — but the driver **blocks** never do. Two defects hid there and surfaced only once the table existed at GREEN:

1. **The `parley.lock (read)` driver ran `parley check` with no `--source`.** `check` is a source-requiring verb, so it answered the pinned usage lines at exit `2`: that row could never refuse, and its law would have reported a green boundary that had never been exercised.
2. **`PathFixtures boundaryRoleNames` was left unsorted** by the decision-72 rename, against a law that compares a sorted table to it.

The operator recorded this exact exposure at the phase flip — *drivers that never evaluate in red hide defects the gate structurally cannot see* — after reading the mirror drivers by hand rather than trusting the gate. Both repairs were declared before the wrap; neither changed a claim. The general shape is worth carrying: **a red gate proves that a law fails, not that its fixtures work**, and any law fronted by a missing-class MNU has an unexercised interior for the whole of RED.

## 7. Scope

No settled class outside the declared eight-class census was modified. `Parley.Parley`, `ManifestBuilder`, `ManifestEditor`, the authoring diagnosis literals and the kernel backtrace on a malformed `Package.st` were **not** touched — all Sprint 18's. `scripts/run-tests.st`, `.parley/scope`, `scripts/*` and `.githooks/*` are unchanged. The 36 settled line literals and the 111 pinned fixture methods are byte-identical; this sprint added lines in the settled grammar and did not re-tone the existing set.

**The v1.0 tag is not cut.** It is held on seven roadmap items, of which this is item 1.
