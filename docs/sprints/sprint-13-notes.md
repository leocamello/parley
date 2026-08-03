# Sprint 13 — `parley add <pkg> <constraint>`: the tool edits the manifest, and never re-renders it

**Issue:** #15 · **Specs of record:** Doc B (`docs/design/manifest-and-serialization.md`) **§2.1** with Doc E (`docs/design/execution-and-cli.md`) §4.1/§5 and Doc C (`docs/design/resolver.md`) §2.2 · **Decisions:** §8 **49** (following 31, 44, 46 and 47).

## What was built

- **`Parley.ManifestEditor`** (`src/manifest/ManifestEditor.st` — the sprint's one
  new class) — the textual surgery, and nothing else. Given text, it answers text
  or `nil`: it opens no file, knows nothing of locks, sources or verbs, and
  mutates nothing. Everything about `add` that is *risky* — writing, re-reading,
  rolling back — stayed in the `CLI`, where the atomicity contract lives.
  - **Recognition scans code, not text.** Comments, string literals and character
    literals are skipped whole (the `advancePast:` scanner — a quote that is a
    *value* never opens a literal region, the same discipline §8 decision 38 put
    into the drift-law stripper). This is load-bearing rather than tidy: the
    settled `parley init` template's own header comment spells both the token
    `Parley` and a complete `dependency: 'name' constraint: '^1.0.0'` clause, so a
    recognizer reading raw bytes miscounts the `define:` sends **and** invents a
    declaration that is not there. Both halves are pinned by
    `testAClauseNamedOnlyInACommentIsNotADeclaration`.
  - **The recognized shape, stated as six conditions** — exactly one
    `Parley define:` send; a balanced `[:pkg | … ]`; no top-level `.` in the body
    (a second statement means the file *computes*, and "after the last clause"
    stops being well defined); at least one clause, none blank; every
    `;`-separated clause's joined keyword selector present in the settled
    `ManifestBuilder class >> vocabulary` (**consumed, never re-listed**, so the
    two cannot drift); and every `dependency:`/`dependency:constraint:` clause
    readable as string literals. Anything else is refused.
  - **The insertion preserves every other byte.** One clause goes in immediately
    after the last clause's final character, at *that line's own* indentation —
    the author's six spaces are as deliberate as their comments, and imposing the
    template's eight would be a small re-render. The closing bracket, the trailing
    newline, the blank lines and the comments all travel through untouched.
- **`CLI>>add:constraint:`** (`src/exec/CLI.st` — the third declared exception on
  this class) — recognize, refuse or insert; write; **re-load through the settled
  `ManifestFile load:`**; assert the manifest gained *exactly* the new dependency
  and is otherwise equal (name, version, `fileIns:` order, every pre-existing
  `Dependency`); resolve against `source snapshot holding:` **every** existing pin
  (Doc C §2.2 in its third application, no resolver change again); rewrite the
  lock byte-stably; then install + register through the settled
  `installResolution:` tail.
  - **The four diagnoses, all exit `1`, none exit `70`:** no `Package.st` (the
    settled missing-manifest line — signalled by `load:` itself, so §8 decision
    31's sentence keeps one definition); an unrecognized shape (one line naming
    the file **and the exact text to paste**); already declared with a *different*
    constraint (one line naming the existing one); and the shared deleted-held-pin
    line. A conflict under the held pins answers the settled `ConflictReport`
    narration preceded by the settled Sprint 12 held-pins line.
  - **Atomicity is real, not narrated.** `restore:lock:` puts back the manifest
    bytes and the lock as it stood (removing the lock when there was none) on a
    failed reload, a failed verification, a conflict, and any nonzero install or
    registration outcome.
  - **Already declared identically is an idempotent success** — exit `0`, one
    pinned line, both files byte-identical — **and the pipeline still runs**
    (§8 decision 48: the report may narrow, the contract may not).
- **The shared deleted-held-pin diagnosis** — `deletedHeldPinLineIn:against:`,
  reached by **both** `add` and `update <pkg>` after their (differently
  constructed) held maps go through the one `heldVersionsOf:except:`. This closes
  Sprint 12's carried gap: §8 decision 47 made a deleted held pin *sound* by
  offering nothing for it, which left an ordinary unsatisfiable narrowed world —
  truthful, and reading as a version conflict when the real defect is a missing
  index entry.
- **Grammar** — `add <pkg> <constraint>`; the 3-element row dispatches only with a
  source wired, and every other arity answers the pinned usage lines at exit `2`.
  The `verbs:` line renders `add <pkg> <constraint>` between `update [<pkg>]` and
  `exec <script>`, per Doc E §4's own grammar order. `ExecFixtures usageLines`,
  `InspectionFixtures usageVerbsLine` and `SelectiveUpdateFixtures usageVerbsLine`
  were re-pinned in the same increment as the CLI change (the Sprint 11/12
  precedent). **`CommandLine` gained nothing** — it strips flags and hands the rest
  through.
- **Tests** — `tests/support/ManifestEditFixtures.st` (three authored `Package.st`
  originals with hand-written edited counterparts, six refused shapes, the S9–S11
  roots/locks, the S13 deleted-pin index, line-splitting helpers and every pinned
  wording — reusing `SelectiveUpdateFixtures`' tools and held-conflict indexes,
  archives and digests **unchanged**); `tests/laws/ManifestEditorTest.st` (19 laws,
  entirely in memory, no file I/O); `tests/laws/AddVerbTest.st` (16 verb laws);
  `tests/acceptance/Sprint13AcceptanceTest.st` (`testS1_`–`testS13_`).

**The expected texts are authored literals, not computed.** An oracle produced by
the same splice the implementation performs cannot fail when the splice is wrong.
Every edited fixture was written out by hand from the original beside it, and the
laws additionally compare **line by line** — because `the text got longer`, `the
file still parses`, `the file still loads to the same manifest` and `the manifest
has three dependencies` are all **true of the disqualified round-trip design**.

## Verification evidence

```
sprint: 13
date: 2026-08-03T16:49:50Z
toolchain: GNU Smalltalk version 3.2.5
PARLEY-SEED: 20260718
PARLEY-VERIFY: PASS seed=20260718 run=662 passed=662 failed=0 errors=0
```

Toolchain, exact:

```
$ gst --version
GNU Smalltalk version 3.2.5
$ gst-package --version
gst-package - GNU Smalltalk version 3.2.5
```

**612 → 662 laws** (+50: 19 editor laws, 16 verb laws, 13 acceptance scenarios,
S5 and S13 each driving two inputs through one selector). Red gate on the reviewed
tests: `run=662 passed=612 failed=28 errors=22`, zero parse errors, every test file
loaded — **no declared passes in red**, in any of the four files. Green landed in
two increments: the editor alone first (`passed=634`, `errors=0` — byte preservation
proved before anything else existed, as the sprint required), then the verb.

`tmp/` absent after every run. No scenario spawns `bin/parley-main.st`, none runs
git, none contacts a network; S11 registers through the recording runner.

## Ambiguities hit and how they were resolved

All six were raised at the RED review and **ruled by the operator at Gate A**; none
required a design change mid-GREEN.

1. **Is "already declared with the identical constraint" textual or semantic?**
   Resolved **textual**. `add` never parses a constraint itself, which leaves the
   settled `ManifestBuilder` the single judge of a spelling and keeps
   `ConstraintFormatError`'s declared ground — *provably never signaled out of a
   verb* (§8 decision 32's partition) — true. The cost is stated rather than
   hidden: `add tool-a '>=1.0.0 <2.0.0'` against a declared `^1.0` refuses instead
   of being idempotent. That is fail-stop, it names the existing constraint, and it
   changes nothing.
2. **Does already-declared skip the pipeline?** No — §8 decision 48 generalises
   past `update <pkg>`, and `testAlreadyDeclaredIdenticallyIsAnIdempotentSuccess`
   asserts the runner is *not* empty. The pins being unchanged says nothing about
   whether the store and target still hold them.
3. **Recognizer before or after `ManifestFile load:`?** **Before.** S5 routes a
   define-less file to the *shape* refusal, and being told the file defines no
   package is true and useless to someone who asked to add something. The
   file-exists check still comes first, so §8 decision 31's sentence is unaffected.
4. **When is the deleted-held-pin check run?** Before the edit, so that path never
   writes at all — which is what makes S13's byte-identical assertion structural
   rather than a rollback that happens to work.
5. **How far does atomicity reach?** Manifest + lock. See "noted, not built".
6. **How does the editor refuse?** `nil` — the settled nil-for-absent convention
   (`retirementReasonFor:version:`, `pinnedResolution`, `constraintFor:`), not a
   refusal object the CLI would have to branch on by kind.

## Operator amendments

**None.** The Gate A review approved all four test files unamended and ruled all
six encoded decisions as written.

## Noted, not built

Ranked, with the trigger each would need. Nothing here was half-built.

1. **The store is not rolled back by a failed `add`.** Doc B §2.1 says "the
   manifest, the lock, the store and the registration all move or none do"; what
   ships restores the manifest and the lock. A fetched archive is content-addressed
   and hash-verified, so it is inert — it is re-used on the next run and is never
   observable as project state — and un-storing it would mean deleting content
   another pin may legitimately share. The honest statement is therefore the
   narrower one, and it is written into `restore:lock:` where the next reader meets
   it. **Trigger:** a store that ever becomes observable as state (pruning, a size
   budget, or a verb that reports store contents). Approved at Gate A.
2. **The refusal does not say *which* condition failed.** All six unrecognized
   shapes answer the same sentence naming the file and the clause to paste. That is
   deliberate for a first sprint — one repair, one sentence, and the recognizer's
   internals are not a contract — but an operator with a large `Package.st` that
   `add` will not touch currently has no way to learn *why*. **Trigger:** a real
   report of a refusal on a manifest the author believed was canonical. Naming the
   ground would also fix the enumeration in place, which is a cost worth paying
   only once the shape has survived use.
3. **`add` does not report that the constraint it inserted is unsatisfiable
   *alone*.** A conflict under held pins answers the held-pins line plus the
   narration, which is correct and does not distinguish "your new constraint is
   impossible" from "your new constraint is impossible *while the others are
   held*". The information is in the narration; the sentence is not. This is the
   same shape as the gap decision 47 left and this sprint closed, one level in.
   **Trigger:** the second time the distinction is misread.
4. **`add` cannot edit anything but the dependency cascade, and cannot change or
   remove a constraint.** Deferred with their reason at staging
   (`docs/roadmap.md` §3): both `parley remove` and in-place constraint replacement
   want decision 49's recognize-or-refuse applied a second time, each with its own
   refusal surface. **Trigger, unchanged:** this recognizer surviving a sprint of
   real use.
5. **A `Package.st` whose last clause is followed by a trailing comment inserts
   after the comment** (`… fileIns: #('A.st') "note" ]` becomes
   `… "note";` + the new clause). The result is valid Smalltalk and loads, and the
   comment survives, so nothing is lost — but the clause reads oddly. No fixture
   covers it and none was invented; recorded so the next reader of
   `lastClauseEndFrom:to:` knows it was seen rather than missed.

## Close-out rulings (Gate B)

Each item above was ruled at the close-out review. Recorded here so the section's
disposition is not left to be reconstructed from the item text, which was written
before the rulings existed.

1. **The doc narrows; store rollback is not scheduled.** Doc B §2.1's "the
   fetch-and-verify and the registration either all land or none do" over-claims:
   the store is content-addressed and hash-verified, so an orphaned archive is not
   observable project state, and the failure mode `PinVerification` exists to
   report — a manifest naming what the lock does not pin — is exactly what the
   shipped rollback prevents and what the store cannot manufacture. Scheduling
   store rollback would add machinery to erase something inert and re-usable. The
   sentence becomes: the manifest and lock move together or not at all; fetched
   archives may remain in the content-addressed store, where they are inert until
   a lock pins them. **Operator-side, at staging**, with a §8 note under decision
   49 so the ruling carries a number.
2. **Leave the refusal as it is; not scheduled.** It already names the repair, which
   is what the operator needs. Naming which of six recognizer conditions failed
   would grow the recognizer's diagnostic surface — the "general parser" slope this
   sprint declared out of scope. Revisit only if real usage shows operators
   confused.
3. **Carried gap, named and ranked.** "Impossible" versus "impossible *while the
   others are held*" goes onto `docs/roadmap.md` §3 as a candidate carried gap, the
   same treatment Sprint 12 gave its own: named, ranked, picked up when a sprint
   touches that ground. The likely fix is cheap — re-resolve without holding, and
   when that succeeds say the held pins are the reason and name `parley update`.
   **Operator-side.**
4. **Already correctly deferred.** Confirmed at close-out: the `parley remove` /
   constraint-replacement row landed in `docs/roadmap.md` §3 at staging (commit
   `d6c658d`) with its staged reason and its trigger intact. Nothing further owed.
5. **Accepted, with a law owed.** The trailing-comment behavior is correct and
   stays. The debt is that it is *unpinned*: **the next sprint that touches the
   editor owes it a fixture and a law, before any change to the insertion logic.**
   An unpinned-but-recorded oddity is fine short-term; changing insertion with no
   law over this case is not.
