# Sprint 8 — the diagnosis boundary: the binary is the product

**Issue:** [#10](https://github.com/leocamello/parley/issues/10) · **Specs of record:** Doc E §4.2/§4.3 (rewritten at staging, amended at Gate A), Doc F §1/§4.1 (added at staging), Doc B §5.2 · **Decisions:** 31, 32

Sprint 7 closed the ecosystem loop in the test suite. Through the shipped binary it did not work:

```
$ parley publish ../index
UndefinedObject(Object)>>doesNotUnderstand: #manifest:in:to:runner:
$ echo $?
0
```

`bin/parley-main.st` hardcoded its file-in list and was never told about `src/publish/`. 409 laws could not see it, because Doc E declared the wrapper exempt from SUnit obligations. That exemption is gone. **Glue that chooses an exit code is not glue; it is the product.**

---

## What was built

### `Parley.CommandLine` (`src/exec/CommandLine.st`) — new

The composition root of one invocation. `in: aWorkingDir runner: aProcessRunner` (pathname-passive — nothing is read, written or spawned at construction; immutable; class-side; no value equality per decision 23); `run: anArgvArray` answers a `CliResult`. It never prints and never terminates the image.

It holds everything the wrapper held except loading, printing and exiting: the leading-`--` strip, the `--source <dir>` grammar, the wiring (store at `<workingDir>/.parley/store`, target at `<workingDir>/.parley/packages`, **both derived from the working directory, never the process cwd**), and the boundary. It sits *above* the settled `CLI` and hands it the verb argv unchanged — `CLI` was not touched, and the pinned usage lines did not move.

### The diagnosis boundary (Doc E §4.2)

| Outcome | `lines` | `exitCode` |
| --- | --- | --- |
| Success | the verb's own lines | `0` |
| Usage | the pinned usage lines (the `CLI`'s own answer, passed through) | `2` |
| A **declared** Parley error | its `problems`, or its `messageText` as one line | `1` |
| Anything else | one line naming the error class and message text | `70` |

The exit-70 wording, pinned in RED:

```
internal error: <ErrorClass>: <messageText> - this is a defect in Parley, not in your project
```

Expressed as nested `on:do:` handlers, never an `isKindOf:` chain. The handlers are **derived from the declaration**: `batchedErrorClasses` and `messageErrorClasses` fold through `exceptionSetOf:` into the `ExceptionSet`s `run:` installs, and `diagnosedErrorClasses` is their concatenation — so the boundary cannot claim one set and catch another. `CommandLineTest>>testASubclassOfADeclaredErrorIsDiagnosedByHandling` signals a `DerivedSourceError` (a subclass named nowhere in `src/`) and requires exit `1` with its problems: a class-identity chain could not pass it.

### `bin/parley-main.st` — rewritten to four steps

File in every `src/` directory in load order; send `CommandLine in: Directory workingName runner: ProcessRunner new` `run: Smalltalk arguments`; print the lines; `ObjectMemory quit:` the code. Printing and exiting happen here alone.

### The two drift laws

- **S8** — the wrapper's own source must name every existing `src/` subdirectory. This is the law that would have caught the motivating defect.
- **S7** — every `Error` subclass in the `Parley` namespace is either covered by the boundary's declared diagnosed set or named in the declared undiagnosed list, with **no third bucket** and no double-counting. Coverage is by *handling* (is-a or inherits-from), exactly as `on:do:` computes it, so a subclass is accounted for without being named.

### The two Sprint 7 ruled gaps, closed

- **`Publisher` destination check** (Doc F §1) — a destination that does not exist or is not a directory is one `PublishError` problem, checked before the refusal check. Nothing written, nothing created, no process spawned. Publish does **not** create the destination: creating it silently would make a typo indistinguishable from an intent.
- **Value-shape validation in the `DirectorySource` scan** (Doc F §4.1) — after the shape checks and **before** duplicate detection (which needs a parsed version to compare), `#version` must parse as a `Version` and every dependency constraint as a `VersionConstraint`. Each violation is one batched problem. The settled parsers are *consumed* through `parses:`, never re-implemented — they stay the single definition of what parses. With this, a directory source has no remaining way to crash on third-party content.

### `ManifestFile` path check (decision 31)

`load:` checks the path before filing it in, signalling one `ManifestError`. See "Ambiguities" below — this was the sprint's third settled-class exception, granted at Gate A.

---

## Verification

From `.parley/audit`:

```
sprint: 8
date: 2026-07-25T01:01:37Z
toolchain: GNU Smalltalk version 3.2.5
PARLEY-SEED: 20260718
PARLEY-VERIFY: PASS seed=20260718 run=461 passed=461 failed=0 errors=0
```

461 cases — the 409 settled laws plus 52 new ones — green on the first audit re-run with the same seed, bit-for-bit identical to the confirming run before it. `tmp/` is absent after a clean run; the developer image was never mutated; no network was contacted.

Exact toolchain:

```
$ gst --version
GNU Smalltalk version 3.2.5
Copyright 2009 Free Software Foundation, Inc.
Written by Steve Byrne (sbb@gnu.org) and Paolo Bonzini (bonzini@gnu.org)

GNU Smalltalk comes with NO WARRANTY, to the extent permitted by law.
You may redistribute copies of GNU Smalltalk under the terms of the
GNU General Public License.  For more information, see the file named
COPYING.

Using default kernel path: /usr/local/share/smalltalk/kernel
Using default image path: /usr/local/var/lib/smalltalk

$ gst-package --version
gst-package - GNU Smalltalk version 3.2.5

$ git --version
git version 2.43.0
```

### The product, proved by hand

```
$ cd <work> && parley publish <dest>
published kernel-greeting 1.0.0
$ echo $?
0
$ ls <dest>
kernel-greeting-1.0.0.st  kernel-greeting-1.0.0.star
```

```
$ cd <empty work> && parley resolve --source <index>
<work>/Package.st: missing or unreadable Package.st - run parley init to write one
$ echo $?
1
```

Nonzero, one diagnosis line, zero backtrace markers — and exit `1`, not `70`: the operator's problem reported as the operator's problem, naming the verb that fixes it. The motivating defect is closed end to end.

---

## Ambiguities hit, and how they were resolved

Both were carried to issue #10 at the end of RED rather than guessed at, and both were ruled at Gate A.

### 1. S4 required a settled-class exception the issue had not declared — decision 31

S4 specifies "a working directory with no `Package.st`" ⇒ exit `1` with the `ManifestError`'s problems. Probed against the toolchain: 3.2.5's `FileStream fileIn:` signals `SystemExceptions.FileError` — a **kernel** error — on a missing file, so `ManifestFile load:` never reached its define-less check and the outcome was exit `70`, not `1`. Making S4 true needed a third declared exception on `ManifestFile`.

**Ruled: granted.** Exit `70` prints *"this is a defect in Parley, not in your project"*; for someone who forgot `parley init` that is the fail-wrong disease in its second form — not a lying exit code but a lying attribution of blame. Restating S4 as exit-`70` would have made the sprint's own motivating example an exception to its own rule. `ManifestFile load:` gained the path check; the pinned wording was approved unchanged; Doc E §3 gained step 0.

### 2. The closed set's second bucket was not provable — decision 32

Doc E §4.2 required each non-diagnosed class to be "provably never signaled out of a verb". Tracing every signal site, that is true of `ConstraintFormatError` and `VersionFormatError` (every caller inside a verb catches them) but **false** of three others. Rather than write a comment claiming something the code could not support, the escape paths were declared by name.

**Ruled: rename the bucket, don't fake it.** Doc E §4.2 was what was wrong, so Doc E is what changed: the second ground is now *"declared undiagnosed with its ground named"* — either provably never signaled out of a verb, **or** reaching exit `70` by a named escape path accepted for now as fail-stop. The law's partition guarantee is undiminished.

---

## Amendments made by the operator

Recorded here because they are corrections to work I delivered, not to work I proposed.

1. **The S8 drift law was enumerating nothing** (Gate A). In 3.2.5, `File>>files` answers **regular files only — never subdirectories**, and `src/` holds nothing but directories, so `srcSubdirectoryNames` answered `#()`. Both S8 laws were failing on their own `deny: names isEmpty` guard, not on `src/publish` — my RED report named a failure I had not checked. That guard is the only reason the drift law written *because an unenumerated directory shipped unreachable* did not itself enumerate nothing and pass vacuously in green. Fixed with `namesDo:`, the idiom `PublishFixtures fileNamesIn:` already used.
2. **`ShippedBinaryTest` failure law strengthened** from `deny: code = 0` to `assert: code = 1`, with an instruction to halt rather than relax it — pinning that the boundary's code survives `ObjectMemory quit:` and the process boundary, which "nonzero" alone would not.
3. **A law added for Doc E §4.2's third usage ground** (a source-requiring verb with no `--source`), which nothing covered.
4. **The S2 fixture/oracle pairing** (Gate B). Both S2 sites fed the index with `SourceFixtures populateDiamondIn:` — placeholder shas `'ab12'`/`'cd34'`/`'ef56'` — while asserting the lock equals `ExecFixtures diamondLockString`, which embeds the true digests. The two literals could never be equal; no correct `CommandLine` would have satisfied that assertion. I stopped rather than patch a signed-off test; the operator applied `InstallFixtures populateInstallDiamondIn:` at both sites (the settled pairing all 11 existing uses of the oracle reach). Strictly strengthening: the oracle becomes a live constraint on digest bytes instead of an unreachable literal. The other two `populateDiamondIn:` call sites were deliberately left alone — S14's clean-directory legs assert versions only.

Declared passes in red, all approved, none an acceptance scenario: two `ValueValidationTest` regression guards on the settled §4 shape check, and `DiagnosisBoundaryTest`'s stale-name guard.

---

## Noted, not built

Two gaps are carried out of Sprint 8 deliberately. Both are declared, neither is hidden.

### 1. Three undiagnosed error classes still land on exit `70` (decision 32)

`IndexEntryParseError` and `IndexEntryFormatError` escape the `CLI`'s `parley.lock` read; `ManifestVocabularyError` escapes `ManifestFile load:` when the author's own `Package.st` has a typo. All three are named with their escape path in `CommandLineFixtures>>undiagnosedErrorClassNames`, and the S7 partition holds over them.

They land on exit `70` — nonzero, one line, no backtrace — so the fail-stop invariant holds and no script is ever lied to about success. What they lack is the **right blame**: they are operator problems reported as Parley's, which is precisely the disease decision 31 cured for the missing-`Package.st` case. Closing them needs a lock-validation boundary and an authoring-error boundary — design, not a fix.

### 2. `GitIndexSource` is built, lawful, and unreachable from the binary

The same *class* of gap as `src/publish/` was, and declared as such on issue #10. Wiring it means designing a flag grammar for a repo **and** a cache path, which is design rather than a fix. The `bin/` drift law covers **directories, not flags**, and does not falsely claim otherwise — `src/source/` is named by the wrapper, so the law is silent about a source class inside it that no flag can reach.

### Harness note

`scripts/wrap-sprint.sh` stages `src/ tests/ scripts/` and does not know about `bin/`, which entered the scope regex only this sprint. `bin/parley-main.st` was staged by hand. Only the operator edits `scripts/*`.
