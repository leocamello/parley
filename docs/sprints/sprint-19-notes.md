# Sprint 19 — the commands stop shouting, and the project remembers its index

**Issue:** [#21](https://github.com/leocamello/parley/issues/21) · **Roadmap §2 items 3 and 4** — items 3 and 4 of the seven holding the v1.0 tag.
**Specs of record:** Doc E §1, §2.1, §2.2, §3, §4.1, §4.2 · Doc B §5.7 · §8 decisions **63, 64, 65, 76, 77**.

```
toolchain: GNU Smalltalk version 3.2.5
PARLEY-SEED: 20260718
PARLEY-VERIFY: PASS seed=20260718 run=910 passed=910 failed=0 errors=0
```

Copied from `.parley/audit` (`sprint: 19`, `date: 2026-08-11T20:08:47Z`). 876 settled laws + 34 new selectors = 910.

---

## 1. The defects, in shipped bytes

Every pair below is the **shipped binary**, stdout and stderr captured **separately**, byte counts from `wc -c`. "Before" is the pre-sprint tool; "after" is this commit.

### 1.1 `publish` — five foreign lines above one composed line

**Before** — stdout (592 bytes), stderr (0 bytes), exit `0` (paths elided in the transcript below; the byte count is of the real capture):

```
mkdir /tmp/gstar-xugeW0
mkdir /tmp/gstar-xugeW0/demo
ln -s -f /…/scratch/e2e/dest/.parley-publish-stage/Demo.st /tmp/gstar-xugeW0/demo/Demo.st
rm -f /…/scratch/e2e/dest/.parley-publish-stage/demo.star
cd /tmp/gstar-xugeW0/demo && zip -n .st:.xml -qr /…/demo.star .
published demo 1.0.0
```

**After** — stdout (**21 bytes**), stderr (0 bytes), exit `0`:

```
published demo 1.0.0
```

### 1.2 `install` — the toolchain's own copy line

**Before** — stdout (324 bytes), stderr (0 bytes), exit `0` (paths elided; byte count of the real capture):

```
/usr/bin/install -c -m 644 /…/app/.parley/packages/.parley-staging/demo.star /…/app/.parley/packages/demo.star
demo 1.0.0
```

**After** — stdout (**11 bytes**), stderr (0 bytes), exit `0`:

```
demo 1.0.0
```

### 1.3 `exec` — the plumbing quietened, the program untouched

Driven with a script that writes one line to **each** stream and quits `3`, so the flag cannot be seen to work by silencing everything. Same script, same composition, `-g` the only difference.

**Before** — stdout (28 bytes), stderr (**67 bytes**), exit `3`:

```
stdout: the script speaks on stdout
stderr: "Global garbage collection... done"
stderr: the script complains on stderr
```

**After** — stdout (**28 bytes, byte-identical**), stderr (**31 bytes**), exit `3`:

```
stdout: the script speaks on stdout
stderr: the script complains on stderr
```

### 1.4 The carried gap — a `Package.st` that half-succeeded

A manifest sending `define:` twice, where the **second** send raises after the first succeeded.

**Before** — stdout, exit **`0`**:

```
Object: nil
Object: nil
no dependencies to resolve - wrote parley.lock
```

**After** — stdout, exit **`1`** (stderr 0 bytes):

```
Object: nil
/…/half/Package.st: line 7 raised an error while the manifest was being read - fix that line and try again
```

The kept `Object: nil` fragment is decision 62's stated bound, terminated onto its own line so it cannot fuse with the sentence below it. The mirror — the **first** `define:` raising and a later one succeeding — answers the same shape naming line 2.

### 1.5 The new capability — a project that remembers its index

```
$ cat parley.config.st
#(#'parley-config' 1 #source '/…/dest' #git '' #index '')
$ rm -rf .parley && parley resolve
demo 1.0.0
$ echo $?
0
```

stderr 0 bytes. No `--source` on the command line, and the state directory deleted immediately before the run.

---

## 2. What was built

**One new class.** `Parley.Configuration` (`src/exec/`, 1 file): reads `<workdir>/parley.config.st` through `PathGuard` and the settled `IndexEntryReader`, answers the value each declared source flag records, and **decides no precedence**. Five hostile shapes, one line each, at exit `1`.

**Five declared settled-class exceptions, each inside its bound:**

| Class | What changed |
| --- | --- |
| `Publisher` | `publish` runs `silencedBuildCommand`; `buildCommand` — the line the diagnosis names — is untouched. |
| `ExecutionScope` | `register` runs `self silenced: command` while the `ExecutionError` still names the **plan** line; `childCommandFor:` gains `-g`. `run:` and the exit-code pass-through untouched. |
| `IndexEntryReader` | `formatTags` gains `#'parley-config'`; the rejection sentence grows from it by construction. |
| `CommandLine` | `sourceChoiceIn:` / `configuredChoice` / `sourceFromChoice:`; `answersUsageFor:withSource:`; the `parley.config.st (read)` row and the `Configuration` deserialization row. The two dead privates the choice replaced (`sourceIn:`, `cliWithSourceIn:`) were removed. |
| `ManifestFile` | `load:` checks the recovered anchor **before** `recorded`. |

**README** — `## Installing` extended with `### Recording your index once, in parley.config.st`; the `exec` composition updated to show `-g` and why it is there. Nothing in the settled section was rewritten.

---

## 3. Ambiguities hit, and how each resolved

**Five were halt-and-asks before RED**, all ruled by the operator on issue #21 (the "Pre-RED rulings" comment) and all recorded there: the config body rule (all three keys, `''` = unset, two non-empty keys a body defect); `ExecutionScope>>register` rather than `Installer` as the site of the `install -c` echo; `formatTags` as a declared exception; `ExecutionError` as the row's carrier; and decision **77**, which re-ruled the `exec` carve-out onto `-g`. Three of them were repository facts the issue had wrong, and the probes are in the ruling comment.

**Four were resolved inside GREEN, and each is a judgement worth naming:**

1. **The redirect literal has two definitions**, in `Publisher>>silencedBuildCommand` and `ExecutionScope>>silenced:`. Doc E §1 gives the redirect to *each composer at its own point of execution*, and the two composers share no home that is not `ProcessRunner` — the seam both decisions 63 and 77 leave untouched. What stops them drifting is that both are pinned against **one** test oracle, `ChatterFixtures stdoutRedirectTail`; either moving fails a law. Both method comments say so.

2. **The configuration is consulted whenever no source flag is given — for every verb, not only the source-requiring ones.** Doc E §4.2 says "when the argv carries no source flag, `run:` consults `Parley.Configuration`", and narrowing that to "and the verb needs a source" is a rule the doc does not state. The consequence is stated rather than hidden: `parley init` in a project whose config is malformed answers the config diagnosis at exit `1` instead of writing a skeleton. That is one line naming the operator's own file with a remedy that works, and it is the same answer every other verb gives.

3. **The read happens before the usage determination and before `createStateDirectories`.** It has to be before the first, or a malformed file is reported as an operator who forgot a flag; and before the second, because a command that refuses to run leaves the filesystem as it found it. The *build* still happens after, because `--git` and `--index` create their cache roots under `.parley/` and 3.2.5's `Directory create:` is not recursive — which is why the choice is carried as a `(row, value)` pair rather than as a built source.

4. **A fixture-label collision inside the reviewed S9 was corrected in GREEN**, and it is flagged here for ratification because it is a change to a reviewed test. `'s19-9-' , <flag>` produced `'s19-9-index'` for the `--index` iteration, which is the label the `--source` iteration's index fixture already owned: `directoryNamed:` swept and recreated that directory, and `tearDown` then removed one path twice and raised out of `PathFixtures unlock:`. The scenario reported an ERROR whose cause was teardown. The label is now `'s19-9-work-<flag>'`. **No assertion changed**, and every assertion in S9 passed before and after — the claim was never in question.

---

## 4. Settled laws re-pinned, and which assertion moved each

Finding **F15** applies to settled re-pins too. Twenty-four settled selectors moved — by a re-pinned literal, by a re-pinned oracle, or by a driver added to a shared enumeration. **None had its claim weakened**, and every one of them is green.

| Re-pin | Selectors | The assertion that moved |
| --- | --- | --- |
| The pinned child composition gains `-g` | `ExecutionScopeTest` ×3, `CliTest>>testExecPropagates…`, `Sprint6AcceptanceTest` ×2 | the composed-command string literal |
| The recorded plan is the plan **silenced** | `CliTest` ×2, `AddVerbTest`, `SelectiveUpdateTest`, `Sprint12`/`Sprint13` S11, `Sprint6` S13 | `runner commands = …` — now `ChatterFixtures silencedPlan:` applied to the **unchanged** plan oracle |
| The recorded build command is silenced | `PublisherTest>>testAFailedBuildIsFailStopAndLandsNothing` | `runner commands`; its *diagnosis* assertion is byte-identical and untouched |
| The reader whitelist grew and its sentence grew with it | `Sprint14AcceptanceTest>>testS6` | the rejection sentence, four tags to five |
| The boundary tables gained their rows | `BoundaryTableTest` ×2, `Sprint17` S12, `BoundaryCoverageTest` ×3, `IndexFlagTest`, `PublishLayoutTest`, `Sprint15` S11 | the declared role/class oracles; three of these (`BoundaryTableTest>>testEveryReadRowRefusesAnUnreadablePath`, `BoundaryCoverageTest>>testEachDeclaredBoundaryDiagnosesItsMalformedInput`, `Sprint17` S12) fail at their **first** assertion — the driver-vs-declaration guard — which is why the red gate never reached their loops |

Three of those class-list oracles (`IndexFlagTest`, `PublishLayoutTest`, `Sprint15` S11) now read `LockSchemaFixtures boundaryClassNames` instead of restating the list, so the **next** boundary moves them by construction. `Sprint15` S11's row **count** is derived the same way.

---

## 5. What the gate does not cover

Carried into Gate B, unchanged from the RED report and extended by the operator's Gate A review:

1. **The four declared RED ERRORs** aborted at the reference to the then-absent `Parley.Configuration`, so the red gate said nothing about their interiors. All four pass now.
2. **Three settled failures failed at a fixture guard** (§4's last row), so the driver loop never ran: in red, *every* obligation the `parley.config.st` row owes — exit `1`, the path named, no kernel class, no backtrace, the exact sentence — was **unexercised**. Structurally unavoidable; stated rather than implied. All of it is exercised now, in green.
3. **Seven of the eight hostile config shapes were never reached in red** — both eight-shape iterations aborted on the first shape. Their pinned wordings were reviewed by hand at Gate A and are approved as written.
4. **S9 aborted at `--source` in red**, so `--git` and `--index` were unexercised there. All three pass now.

---

## 6. Two record-keeping items the operator asked for

**`ChatterFixtures markersMissingFrom:in:` was deleted.** It had no sender, and no green-phase home: once the fix lands nothing in the project can produce those markers, so no law can show the needles are live. They were verified at Gate A against the **red** capture instead — the only moment they are demonstrable — and all seven matched real captured text: `mkdir /` and `/tmp/gstar-` (both from `mkdir /tmp/gstar-h07b0w`), `ln -s -f`, `rm -f` and `&& zip` on S1's stdout; `/usr/bin/install -c` and `.parley-staging` on S2's. That verification is recorded here rather than defended by an invented law.

**A confirmation finding.** `ConfigFixtures hostileShapeLabels` passed its guard in red, which is empirical proof that Sprint 18's `String <=` case-folding lesson (finding F15) was applied correctly when the list was written: the order was taken from the toolchain, not read off the page.

---

## 7. Scope

`scope-19` is identical to `scope-18`; `scripts/run-tests.st` is unchanged — `Parley.Configuration` lives in `src/exec/`, which the harness already files in. The decision-60 census **stays at eight**: every byte the new class reads comes through `PathGuard`. Nothing under `docs/method/`, `scripts/`, `.githooks/` or `.parley/scope` was touched. Nothing was pushed (F17).
