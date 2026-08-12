# Sprint 20 — the verbs that close the grammar

**Issue #22.** Doc E §4/§4.1/§4.2 · Doc B §2.1 · Doc C §2 · Doc F §7.3 ·
§8 decisions **67**, **79**, **80**, **81**, **82**.
Roadmap §2 item 5 — the fifth of the seven that hold the v1.0 tag. **The tag is not cut here.**

```
sprint: 20
date: 2026-08-12T16:12:30Z
toolchain: GNU Smalltalk version 3.2.5
PARLEY-SEED: 20260718
PARLEY-VERIFY: PASS seed=20260718 run=983 passed=983 failed=0 errors=0
```

`gst --version` in full:

```
GNU Smalltalk version 3.2.5
Copyright 2009 Free Software Foundation, Inc.
Written by Steve Byrne (sbb@gnu.org) and Paolo Bonzini (bonzini@gnu.org)
```

Baseline 910 laws → **983**. No new class, no new `src/` directory, `scripts/run-tests.st`
unchanged.

---

## 1. What shipped

**Four verbs.** `remove <pkg>` deletes one dependency clause from `Package.st` and moves the
project off it; `search <term>` matches package names the index publishes; `info <pkg>` reports
one package's metadata and every version it published; `outdated` compares the lock against the
index in two columns. None of them enters the resolver.

**Two riders.** Every usage error now names what was wrong on line one while `--help` answers
the block alone at exit `0`; and `GitIndexSource` stopped printing text Parley did not compose.

**Five declared settled-class exceptions, all inside their bounds:** `ManifestEditor` (the
deletion recognizer and its splice; the insertion path untouched), `CLI` (four verb rows, the
usage composition split, `info` calling the settled `seededSourceAdding:`), `CommandLine` (the
usage-reason table, `helpResult` decoupled, the `search`-capability predicate), `IndexSnapshot`
(two purely additive accessors; the `Resolver` calls neither) and `GitIndexSource`
(`refreshCommand`'s two composed lines gain `--quiet`).

**The census stays at eight.** No class gained direct `File`/`FileStream`/`Directory` I/O.

---

## 2. The defects, in shipped bytes

Every measurement below was taken through `bin/parley` in a throwaway directory. **stdout and
stderr are captured separately**, because the settled runners merge with `2>&1` and cannot tell
text Parley kept on one stream from text it must remove from the other — which is exactly why
F19 survived a whole sprint of chatter work.

### 2.1 Four different mistakes, one byte-identical answer

**Before** — every ground, byte for byte the same, and no line naming which happened:

```
$ parley            → exit 2 · stdout 476 B, 6 lines · stderr 0 B
$ parley bogus      → exit 2 · stdout 476 B, 6 lines · stderr 0 B
$ parley exec       → exit 2 · stdout 476 B, 6 lines · stderr 0 B
$ parley resolve    → exit 2 · stdout 476 B, 6 lines · stderr 0 B
```

**After** — six grounds, six first lines, one shared block:

```
$ parley                              → exit 2 · stdout 545 B, 7 lines · stderr 0 B
no verb given
$ parley bogus                        → exit 2 · stdout 558 B, 7 lines · stderr 0 B
bogus is not a parley verb
$ parley exec                         → exit 2 · stdout 566 B, 7 lines · stderr 0 B
exec does not take those arguments
$ parley resolve                      → exit 2 · stdout 588 B, 7 lines · stderr 0 B
resolve needs an index - give --source, --git or --index
$ parley --source x --git y resolve   → exit 2 · stdout 593 B · stderr 0 B
--source, --git and --index are mutually exclusive - give one
$ parley publish d --layout nope      → exit 2 · stdout 581 B · stderr 0 B
nope is not an index layout - give flat or sparse
```

### 2.2 `--help` did not move

```
before → exit 0 · stdout 476 B, 6 lines · stderr 0 B
after  → exit 0 · stdout 531 B, 6 lines · stderr 0 B
```

Six lines both times, **no reason line**, exit `0` both times. The 55 bytes are the verbs row
going from ten verbs to fourteen — the only line of the block this sprint moves. Four settled
guards (`ReadinessTest:395`, `:426`, `Sprint16:390`, `:716`) hold that claim.

### 2.3 F19 — the composer that printed git's own text

Same fixture repository, same two composed lines, before and after.

| Run | | stdout | stderr |
| --- | --- | --- | --- |
| cold `clone` | **before** | 0 B | **27 B** — `Cloning into 'b1'...` / `done.` |
| | **after** | 11 B — `demo 1.0.0` | **0 B** |
| warm `pull`, unchanged | **before** | **20 B** — `Already up to date.` | 0 B |
| | **after** | 11 B — `demo 1.0.0` | 0 B |
| warm `pull`, index MOVED | **before** | **126 B** — `Updating 1e94b24..3146b40` / `Fast-forward` / a diffstat | **169 B** |
| | **after** | 11 B — `demo 1.1.0` | **0 B** |

**The recorded description of this gap understated it, and the correction is the interesting
half.** Roadmap §2 and release plan §0 both called F19 *"two lines to stderr"*, with the
consumer constraint *"a script capturing stderr will collect them."* Every run after the first
put git's text on **stdout**, above Parley's own answer — the `publish` shape Sprint 19 existed
to abolish, on the stream the record called clean.

**Quiet silences chatter, never failure.** Probed through the shipped binary after the change:

```
$ parley resolve --git /nonexistent/repo     → exit 1
stdout (267 B): git command failed with exit code 128: git clone --quiet /nonexistent/repo /…/.parley/git/5b6e8e2…
stderr  (53 B): fatal: repository '/nonexistent/repo' does not exist
```

The settled `SourceError` still reaches the operator, and it now names the command **actually
run** — flag included. That is a shipped sentence moving, not just a test oracle, and it was
declared as such.

---

## 3. Ambiguities hit, and how each resolved

Two pre-RED rounds and one Gate A addition. **Five repository facts were wrong before I
started, and one ruling of mine was overturned.**

| # | Ambiguity | Resolution |
| --- | --- | --- |
| 1 | The `CommandLine` exception said *four usage rows*; the tool reaches usage by **six** routes | **Asked on #22 (ruling 1).** Ruled: four verb-grammar grounds, six reasons, ONE declared table. My compose-at-site shape for the two flag-grammar routes was **overruled** — two sites writing their own sentence is two wordings no drift law can see. §8 **decision 81** |
| 2 | Decision 79 said the block was **seven** lines | **Probed: six** (476 B). Decision 79 amended in place |
| 3 | *"The predicate keys off `sourceFlags`"* reads naturally as a fourth column | **`SourceFlagTest:149` pins `row size = 3`** and is on no mover list. The predicate reads the `--index` row's class without growing the table. Recorded in decision 81 |
| 4 | Four settled README drift laws force four new `parley <verb>` rows, undeclared anywhere | Confirmed and **declared in this commit**. The operator's review found **three more copies** of that law than I did |
| 5 | `remove`'s deletion span when the dependency is the cascade's **first** clause | **My reading upheld, then corrected by probe**: the span rule I proposed leaves `pkg;`, which does not parse. A clause owns the join **before** it, **except the first**, which owns the join **after** it. §8 **decision 67** amended |
| 6 | `remove`: does it install and register? | **Upheld** — it reuses `add`'s settled tail. Decision 48: a shorter report does not shorten the contract |
| 7 | `info`'s *latest* version | **My reading OVERRULED.** I proposed `versionsOf:`, which **collapses a held name to its held version** (`IndexSnapshot.st:122-125`), so `info` would have answered *this project's pin* as the index's newest release. Ruled: highest non-retired with the held map **bypassed** — which is what the new `allVersionsOf:` accessor is for |
| 8 | `outdated` over a **transitive** pin — one the root manifest never names | **Asked as an interpretation; ruled against both of my options.** "Unconstrained collapses to newest-allowed" recommends an upgrade the graph may forbid; omitting the pin answers *"nothing is outdated"* over a stale lock. Ruled: every pin reported, the allowed column renders a **declared marker**. §8 **decision 82** |

**Two toolchain facts cost a verifier run each and are recorded so they cost nobody another.**
`Array class` answers `with:with:with:with:with:` and **nothing longer** — a sixth `with:` in
one `verbRows` group is a `doesNotUnderstand` at the first send of that method, which is every
verb, every usage determination and every law reaching either (`passed` fell 881 → 605 in one
increment). And a `RecordingRunner` **records and never clones**, so a cold-cache snapshot
driven through one still signals the settled missing-directory `SourceError` — the composed
line is recorded before that, which is what the law asserts.

---

## 4. The settled-mover list, and which assertion moved each

Built from the planned implementation, not from a red run. **A red phase truncates the list at
the first failing assertion, and a `grep` on the oracle's spelling cannot see a duplicate.**
Both limits bit: the issue's list was short by twelve assertion sites, five pinned copies and
one whole family, and the operator's verification added four more.

### A. The block's own copies — five became one

| Definition | What moved | Now |
| --- | --- | --- |
| `ExecFixtures class >> usageLines:361` | the verbs row, ten verbs → fourteen | **the suite's one literal** |
| `ManifestEditFixtures >> usageVerbsLine:757` | a second literal copy | delegates |
| `SelectiveUpdateFixtures >> usageVerbsLine:695` | a third | delegates |
| `InspectionFixtures >> usageVerbsLine:242` | a fourth | delegates |
| `ReleaseHardeningTest >> usageVerbsLine:224` | a live `lines at: 2` read | locates the row by its start |
| `ManifestEditFixtures >> addUsageLines:768` | the whole block | composes; **split in two**, see below |
| `SelectiveUpdateFixtures >> selectiveUsageLines:704` | the whole block | composes; **split in two** |

**Two fixtures had to split**, because their consumers drive *two different grounds*: four sites
are wrong-arity **with** a source (`#wrongArguments`), two are correct-arity with **no** source
(`#needsIndex`). One fixture could not serve both. `addNoSourceUsageLines` and
`selectiveNoSourceUsageLines` are the siblings.

### B. Assertion sites that gained a reason line — 31

Each moved on the assertion `result lines = <the whole usage answer>`, which stopped being the
block alone:

- via `ExecFixtures usageLines` (**19**): `CliTest` :121 :133 :146 :161 · `CommandLineTest`
  :168 :183 :368 · `SourceFlagTest` :230 :248 · `ReadinessTest` :472 · `IndexFlagTest` :277 ·
  `Sprint6` :521 :531 · `Sprint7` :447 · `Sprint9` :433 · `Sprint14` :536 · `Sprint15` :490 ·
  `Sprint16` :485 :675
- via `addUsageLines` (**6**): `AddVerbTest` :550 :564 :579 · `Sprint13` :474 :485 :490
- via `selectiveUsageLines` (**4**): `SelectiveUpdateTest` :342 :359 · `Sprint12` :395 :408
- via `InspectionFixtures usageVerbsLine` (**1**): `InspectionVerbTest` :338
- via `ReleaseHardeningTest usageVerbsLine` (**1**): `:232`

### C. The family no oracle grep can see — 4

Laws asserting **one live usage answer equals another live usage answer**. The equality goes
false because the two argvs now have *different grounds*, and no oracle appears in the line:

| Site | The two answers it compared |
| --- | --- |
| `ReadinessTest:410` | `--help` vs the bare argv — **strengthened**, never weakened: the usage error's *tail* IS the help block and its first line is the reason (S10) |
| `InspectionVerbTest:357` | `why`/`tree`/`check` with no source vs the bare argv |
| `InspectionVerbTest:378` | wrong-arity inspection verbs vs the bare argv |
| `Sprint19:447` | source-less `resolve` vs the bare argv — its failure message is literally *"the usage lines moved"* |

### D. Positional sites — eleven methods, not three

`AddVerbTest:580` · `ReleaseHardeningTest:232` · `InspectionVerbTest:338` · `IndexFlagTest:277`
(and `:271`) · `Sprint12:396`+`:397` · `Sprint13:475` · `Sprint14:536` (and `:531`) ·
`Sprint15:490` (and `:487`) · `Sprint15:633` · `Sprint16:630` · `Sprint17:840`.

Every one read `lines at: 2` — the verbs row until a reason line arrived above the block. All
now locate the row by its own start through `GrammarFixtures verbsRowIn:` / `headerRowIn:`.
**Four of them are the same README drift law copied into three sprint suites beside its own**,
and its failure mode was the worst of the eleven: `indexOfSubstring:` answers `0` when absent,
so `verbsIn:` would have sliced the *header* and split it on its three pipes, extracting
`parley`, `--git` and `--index` as verbs and reporting them as undocumented.

### E. F19 movers — a shipped sentence, not only an oracle

`PublishFixtures cloneCommandFor:cache::474` and `pullCommandFor::479` (the oracles);
`GitIndexSourceTest:142` (the recorded command), `:160`, `:176` and `Sprint7:371` (where
`gitFailureProblemFor:code:` **embeds the command line**, so a failed clone now names
`git clone --quiet …` to the operator); and `GitIndexSourceTest`'s class comment `:14`–`:18`.

### F. Non-movers, confirmed rather than assumed

The 47 sites asserting `exitCode = 2` alone pin the classification, not the text.
`Sprint7` :271 :295 :433 (`runner commands = #()`) are unaffected by `--quiet`.
`Sprint9:239`/`:241` and `ReadinessTest:270`, `:664`–`:668` index into **exit-1** answers, not
usage answers. `PublishLayoutFixtures layoutFlagUsageLine` at `Sprint15:493` uses `includes:`
and survives a prepended line.

### G. A NEW LAW IN A SETTLED FILE — its own category

**`GitIndexSourceTest >> testBothComposedGitLinesCarryTheQuietFlag`** is neither a new file nor
a re-pin, and it is declared separately because **the pass-set recipe keys off new files** and a
new law in a settled file falls outside it. It drives both branches of `refreshCommand` — the
clone branch through an absent cache, the pull branch through a populated one — and reads each
composed line off the recording runner rather than off the fixture that was just handed the
flag.

---

## 5. Test edits during GREEN

**One**, disclosed rather than discovered. `testBothComposedGitLinesCarryTheQuietFlag` (§4.G)
called `snapshot` on a cold cache and let the resulting `SourceError` escape. It errored in RED
— correctly, but for a reason I mis-attributed in the RED report — and would have errored in
GREEN too, for a fixture reason rather than a behaviour one. It now consumes that error through
the settled `problemsFrom:` helper. The assertion it makes is unchanged: the composed clone
line, read off the runner, carries `--quiet`. **No other test file was touched after `ff101b5`.**

---

## 6. Verifier discipline

Eight increments, **one run each**, every one showing progress so the breaker never armed:

| Increment | `passed` |
| --- | --- |
| RED baseline | 872 |
| 1 · `ManifestEditor` deletion, alone | **881** |
| 2 · `remove` wiring (the `Array with:` overflow) | 605 |
| 2 · corrected | **895** |
| 3 · the usage split, alone | **942** |
| 4 · `IndexSnapshot`'s two accessors | **946** |
| 5 · `search` / `info` / `outdated` | **971** |
| 6 · `GitIndexSource --quiet` | **978** |
| 7 · the law fix and the README | **983** |

**After increment 3 the settled surface was checked before moving on**, as the largest re-pin
surface in the sprint required: the only settled classes still failing were the two obligations
still ahead (`--quiet` and the README). The usage split broke no settled law.

**One violation stands on the record from the RED phase**: a third verifier run with no code
change between it and the second, made by reflex. It was disclosed at the time, it did not arm
the breaker, and the pass set it would have listed was recovered arithmetically instead.

---

## 7. What this sprint did not do

The tag is **not** cut — it is held on item 7. In-place constraint replacement stays deferred
(`add` still refuses rather than overwrites). No index schema moved: `#'parley-index' 1` is
byte-identical, and decision 80 **refuses** the sparse catalogue rather than building one.
`--json`, colour output, path dependencies, `--offline` and `--locked` are untouched.
