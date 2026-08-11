# Parley — Method Findings

What the *pipeline* learned, as distinct from what the sprints delivered.
`docs/sprints/` records what was built. `docs/design/architecture.md` §8 records what
was ruled. This file records what the process itself got right and wrong, with the
evidence that proves each claim.

**Every entry cites specific evidence from the sprint it covers** — a breaker trip, a
red-gate catch, a scope-sentinel breach, a halt-and-ask, a re-ruled or narrowed
decision, an operator amendment, a Gate A miss found at Gate B. Never general musing
about process. `scripts/check-method-findings.sh` enforces it mechanically: an entry
whose **Evidence** field cites nothing resolvable fails the gate.

**Entries are two-layer by design.** The **Rule** is portable — it is written to survive
this project and to be lifted, unchanged, into a pipeline running on a different
language and a different codebase. The **Evidence** is Parley-specific and is what makes
the rule credible rather than an opinion. Read the rules for transfer; read the evidence
to decide whether you believe them.

---

## The relational inventory

**Every defect this pipeline has missed came from a pair of artifacts that each looked
correct alone and were wrong only with respect to each other, with nothing comparing
them.** The rule that follows from it is short enough to sound like a definition, so the
table comes first: the rule is a claim about *this* list, and the list is what makes it
checkable.

A pair is **forced** when some step cannot complete without the comparison happening —
**mechanically** (a law or gate compares them) or **procedurally** (a stage or checklist
item schedules a human to). It is **unforced** when nothing does, and an unforced pair is
not a defect: it is a place a defect can live undetected for as long as it likes.

| # | The pair | Forced by | Kind |
| --- | --- | --- | --- |
| 1 | Issue scenarios `S1..Sn` ↔ acceptance test selectors | `wrap-sprint.sh` traceability gate | Mechanical |
| 2 | A commit's file list ↔ the active `scope-<N>` regex | pre-commit scope sentinel | Mechanical |
| 3 | `deserializationBoundaries` rows ↔ real senders of `IndexEntryReader readFrom:` in `src/` | `BoundaryCoverageTest` drift law | Mechanical <sup>[a]</sup> |
| 4 | `sourceFlags` rows ↔ the sources the CLI can actually construct | source drift law | Mechanical <sup>[b]</sup> |
| 5 | `src/` subdirectories ↔ the directories the shipped wrapper names | Sprint 8 "S8" drift law | Mechanical <sup>[c]</sup> |
| 6 | `Parley` `Error` subclasses ↔ the declared diagnosed + undiagnosed sets | Sprint 8 "S7" closed-set drift law | Mechanical <sup>[d]</sup> |
| 7 | Pinned usage fixtures ↔ the CLI's real usage output | settled usage laws | Mechanical <sup>[e]</sup> |
| 8 | A design doc's asserted mechanism ↔ the runtime's actual behaviour | RED: tests before implementation | Procedural — F3 |
| 9 | A reviewed test's pinned string ↔ the settled renderer that must produce it | GREEN reached without weakening a reviewed test | Procedural — F4 |
| 10 | A staging decision ↔ its own implementability | halt-and-ask when the specs of record do not answer | Procedural — F6 |
| 11 | `.parley/audit` seed/counts/date ↔ the sprint notes' verification block | runbook Gate B step 1 | Procedural |
| 12 | `docs/roadmap.md` §3 deferred list ↔ what the sprint proposes to build | Stage 1 checklist item 5 | Procedural |
| 13 | The ranking ↔ its own deferral history | deferral counters + written displacement at Gate C | Procedural — F2 <sup>[f]</sup> |
| 14 | A new implementation of a settled protocol ↔ the settled consumers of it | Stage 2 checklist item 2, widened | Procedural — F1 <sup>[g]</sup> |
| 15 | `wrap-sprint.sh`'s staging list ↔ the `scope-<N>` regex | — | **Unforced** — F5 <sup>[h]</sup> |
| 16 | A documented guarantee ↔ what the code actually does | — | **Unforced** — F8 <sup>[i]</sup> |
| 17 | `§8` decision entries ↔ the design docs citing them | — | **Unforced** <sup>[j]</sup> |
| 18 | `docs/sprints/README.md` index rows ↔ the sprint notes files that exist | — | **Unforced** <sup>[k]</sup> |
| 19 | New tests that **pass** in RED ↔ the sprint's declared passes-in-red list | runbook Gate A step 3 weak-test item, via the pass-count arithmetic | Procedural — F10 |
| 20 | A carried gap's asserted **reachability** ↔ the runtime behaviour that would make it reachable | runbook Gate B §2.4 probe-or-mark-unprobed | Procedural — F11, F12 <sup>[l]</sup> |
| 21 | A boundary's stated diagnosis (its **sentence**) ↔ the predicate that boundary actually **checks** | Sprint 17's boundary table: S12 drives every row through its hostile state and requires the row's own declared error | **Mechanical, known-partial** — F12, F13 <sup>[m]</sup> |
| 22 | A cross-reference inside a staging artifact ↔ the thing it points at (a count, a section number, a scenario's text, a sibling artifact's list) | — | **Unforced** — F13, F16 <sup>[n]</sup> |
| 23 | `operator/master-plan.md` §9's narrative sprint history ↔ `docs/roadmap.md` §2, the tracked ranking it narrates | runbook §3 step 6 | **Unforced** <sup>[o]</sup> |
| 24 | A gate whose validity depends on the **order** its steps ran in ↔ any evidence that they ran in that order | — | **Unforced** <sup>[p]</sup> |

**Eight mechanical, nine procedural, seven unforced.**

- **[a]** Known-partial: textually spelled senders only, because 3.2.5 offers no reflective alternative (§8 decisions 38 corrected, 43).
- **[b]** Written *because* `GitIndexSource` shipped lawful and unreachable for a whole sprint — nothing constructed it.
- **[c]** Known-partial: covers **directories, not classes**, which is exactly how [b]'s defect passed it — `src/source/` was named by the wrapper while the class inside it had no flag.
- **[d]** Every `Parley` `Error` subclass must be in the diagnosed set or the declared undiagnosed list — **no third bucket**, coverage computed by handling as `on:do:` does.
- **[e]** This pair is why usage re-pins land in GREEN with the code change rather than in RED.
- **[f]** Adopted *after* the miss it records; four sprints of evidence since.
- **[m]** Forced by Sprint 17 **only for the two hostile states the law enumerates** — unreadable and unwritable. A path of the *wrong type* is not driven, and that is exactly where F13's defect lives. The row is mechanical against the enumeration, not against the property. **Sprint 18's decision 74 narrows the partial without closing it:** the *state-root* row is now driven through a path's four **shapes** — absent, already a directory, a regular file, wrong-type-or-unwritable parent — and each answers its own declared sentence. That is **one row of twelve.** The other eleven are still driven through the same two permission bits, so the property/enumeration gap this footnote records is now one-twelfth closed and eleven-twelfths open, and saying "F13 is fixed" would be the highlight-reel reading. **Sprint 19 adds a thirteenth row** (`parley.config.st (read)`) and the honest number needs two figures rather than one. On the **property**, the new row is covered: eight input states — a directory, unparseable, wrong tag, missing/misordered/unknown key, non-String value, two sources — each answering its own exact sentence, all eight re-probed through the shipped binary at Gate B. On the **mechanism**, it is not: the row's own driver in `PathFixtures readRowDriversTracking:hostile:` is the same two permission bits as the other eleven, and the eight shapes live in a *separate* enumeration (`ConfigFixtures hostileShapesTracking:`) consumed by two laws outside the table. So the table forces **1 of 13** and the property holds for **2 of 13** — and the gap between those numbers is itself a row-22 pair: two enumerations of one boundary's states, with nothing comparing them. A fourteenth row copying the table's driver alone inherits the two-bit drive and nothing warns.
- **[n]** Named in §8 decision 60 when the census resolved a Scope/Architecture-impact disagreement; **added to this table at the Sprint 17 close-out, eight instances in**, every one caught by an operator reading one artifact against another and none by a gate. **Sprint 18 added six more, and the count is kept honestly because a tidy count is how this row stops being believed.** Four at Gate C, by reading the code against the staging plan: a selector that does not exist (`Parley.Parley class >> load:`), Doc E §4.1 cited for a §3 subject, four declared settled-class exceptions where the code needs two, and an S2 promising a re-voicing the toolchain cannot perform. One at the RED review: *six* absolute Parley source paths where the shipped binary prints **four**, propagated from the staging plan into the issue, Doc B §2.2, decision 62 and four test comments before anyone ran the binary and counted. One at GREEN: the operator's own Gate A impact list, two sites short — see F16. **Sprint 19 added seven more, and every one was caught by a person reading one artifact against another.** Two at Gate C: the roadmap's *"all of it is on stdout"* (false — `exec`'s chatter is on stderr, which is what carved `exec` out) and its *"the README has no installation section at all"* (false since Sprint 17). Three pre-RED, by the coding agent's halt-and-ask — a **mechanism**, and the first time this row has been caught by one: the issue named `Installer` as composing the `install -c` line (probed — it composes no command line at all; the echo is the registration child's), it declared `IndexEntryReader` **not** an exception while the tag whitelist is enforced inside `readFrom:`, and S3 promised a `.star` byte-identical to the pre-sprint tool's, which the toolchain cannot give because a zip embeds staged mtimes. One at the pre-RED ruling, by an operator read: the Doc E amendments the Gate C comment promised for RED had **never landed** — commit `3fbbf5f` carried only Doc B §5.7 and §8. One at the RED review, by an operator read: the issue, Doc B §5.7, Doc E §4.1 and two test comments all called `Configuration` the **fourth** sender of `IndexEntryReader` when `src/` has four senders already, making it the fifth. **Twenty-one instances. Three of the twenty-one were caught by a mechanism and all three are the same one — an agent halting to ask rather than a gate halting to check.**
- **[g]** Adopted at Sprint 14. **Still untested after its first opportunity:** Sprint 15 introduced no new class at all, so the widened item was answered "n/a" rather than exercised. Recorded as untested, not as coverage — the opportunity is what expired, not the doubt.
- **[o]** The operator-local narrative half of what the tracked roadmap keeps canonically. It is **untracked**, so no drift law can ever see it — which is why it drifted three sprints (15, 16 and 17 all delivered without reaching it) before anyone compared them. Raised at Sprint 18's Gate C, which deliberately did **not** write this row itself because `docs/method/` is operator-authored and a gate that authors its own findings is how the tally becomes a highlight reel. The forcing step that exists — runbook §3 step 6 — is **the weak kind**: a checklist item a reviewer works, not a law that halts. The tracked/untracked split leaves nothing stronger available, and saying so is the point of the row. **Checked again at Sprint 19's Gate B: the delivery drift is zero** — §9 records Sprints 15-18 and Sprint 19 is added by this close-out, in order. But the header's v6.1 staging entry (2026-08-11) still names *"four declared settled-class exceptions (`Publisher`, `Installer`, `CommandLine`, `ManifestFile`)"*, which the pre-RED rulings superseded the same day — `Installer` withdrawn, `ExecutionScope` and `IndexEntryReader` granted, five in total. **The row drifts within a sprint as well as across sprints, and step 6 only looks across.** Corrected in this close-out.
- **[p]** Raised while reviewing Sprint 18's Gate C output, and **not an accusation about that session** — its cold read reached the demonstrably correct conclusion and caught a §2 divergence a retroactive write-up would not have produced. The pair is structural. Runbook §3.0 step 1 exists *because* the roadmap must be read **before** the carried gap; the only artifact is `operator/staging/sprint-18-cold-read.md`, whose **mtime is the latest of every Gate C artifact** — after the issue, the comment, the plan and the kickoff. mtime records last modification, so it neither proves nor disproves the ordering; **nothing records it either way.** The same hole sits under Gate A's *read the tests before running the gate* and Gate B's *probe before ranking*. **Unlike [o] this one has a cheap real mechanism**: require the ordered step to be a **message in the session transcript** rather than a file, because a transcript is inherently ordered and an mtime is not. Sprint 18's own Gate B is the demonstration — its probe-before-ranking order is legible precisely because it happened as conversation rather than as a file. Adopting it is a runbook §3.0 change and belongs to **Gate C**, not to this close-out.
- **[h]** Both sides plain text and enumerable: the cheapest available drift law, unwritten. Open; scheduling is a Gate C question.
- **[i]** Four instances (§8 decisions 43, 45, 49, 52), every one caught by a human reading. Not a drift-law candidate — comparing prose to behaviour is not a text walk.
- **[j]** No finding raised it, and it has drifted before: the tracked log and the operator's copy diverged by four decisions, leaving tracked docs citing decisions a cloner could not resolve. The repair was a convention ("same commit as the doc change"), not a check. **Verified in sync at the time of writing** — 31 distinct decisions cited across tracked docs, all 31 resolve in §8. **Re-verified at the Sprint 15 close-out:** 55 decisions defined, every citation across `docs/`, `.github/` and `AGENTS.md` resolves, no dangling reference. Two consecutive clean checks is not forcing — it is two clean checks.
- **[l]** Forced at Sprint 15 by F11's adopted runbook change, and it **paid out at the very next close-out**: Sprint 16's "the next boundary added will be in the same blind spot" is a claim that the present is safe, and §2.4 required it probed. Six `chmod` calls, six defects (F12). Procedural, not mechanical — a reviewer working a checklist, which is what every catch in this file has been.
- **[m]** The pair F12 names and the reason it was invisible for eight sprints: `ManifestFile`'s diagnosis said `missing or unreadable Package.st` from Sprint 8 while its predicate tested `exists` alone. Both sides are enumerable — the diagnosis literals are in `src/`, the boundaries are a list somebody can write — so this is a drift-law candidate, unlike [i]. **Scheduled: Sprint 17 converts it into a table with a law over it.** Until then, the only thing standing between a new boundary and this defect is a reviewer remembering.
- **[k]** No finding raised it, and it went stale for five consecutive sprints; `a36337e` backfilled Sprints 09–13, its message reading *"The table stopped at Sprint 08."* Verified in sync at the time of writing — 15 rows, 15 files. **At the Sprint 15 close-out it was out of sync again** — 16 notes files, 15 rows — and was backfilled in the close-out commit. The row stays unforced, and it has now drifted twice; that it is caught at Gate B each time is the operator's checklist working, not the pair being forced.

Rows 17 and 18 were found by walking the pipeline rather than the findings, and **both had
already drifted** — which is the argument for walking it: *absence of a finding is not
evidence of forcing.* Rows 13 and 14 are forced only because a miss made them so.

**What the mechanical rows have actually caught, stated precisely.** The drift comparisons
themselves have *forced declarations* — Sprint 9's diagnosed set going from five names to
six, Sprint 14's fourth boundary row — but no mechanical row has caught a defect in the
**product**. The two defects mechanical rows did catch were **in themselves**: at Sprint 8
Gate A the `src/` drift law was enumerating nothing (`File>>files` answers regular files
only, never subdirectories) and would have passed vacuously; at Sprint 10 the raw-text walk
counted a *method comment* quoting a send as a third sender. Both were caught by **guards
added to the laws** — a `deny: names isEmpty` and a pinned sender oracle — not by the drift
comparison. The lesson is narrow and worth carrying: *a comparison that enumerates nothing
passes while proving nothing*, which is the same failure `verify-sprint.sh`'s load-integrity
check exists to prevent. A relational check needs a guard that it is comparing anything at all.

**The rule the table demonstrates:**

> **A relational pair is safe when something forces it into contact — mechanically or
> procedurally — and unsafe when nothing does.**

**What this predicts.** Every miss recorded in this file came from a row that was unforced
at the time. The five unforced rows are therefore the standing list of where the next one
comes from — the same job `docs/roadmap.md` §1's deferral counters do for scheduling, and
it should be read the same way: not as a backlog, but as the places where "nothing has
gone wrong yet" is not evidence.

**Where each kind is available.** A drift law needs both sides mechanically readable and
one side a *declaration consumed twice* — that is what makes them unable to disagree.
Row 15 meets that bar (both sides plain text; the `BoundaryCoverageTest` precedent already
walks text rather than the image) and is one law plus one fixture. Rows 16 and 17 do not:
one side is a judgment or a sentence, so the only available forcing is procedural, which
is what rows 8–14 are. **The transferable procedure is not the rule — it is this table:
enumerate your pipeline's relational pairs, mark which are forced and by what, and treat
the unforced rows as the standing risk register.**

---

## The tally — caught by a mechanism, or caught by luck

The number this file exists to produce. A retrospective written from the position of
having already survived will drift into a highlight reel unless it counts its misses, so
each **defect-finding** is classified by what actually caught it:

- **Mechanism** — the red or green gate, the circuit breaker, the scope sentinel, the
  traceability gate, or a checklist item. Something that *halts*.
- **Luck** — an operator reading something adjacent, or a close-out that happened to
  look. Nothing would have stopped the sprint from shipping the defect.

**Confirmation-findings** (a practice that worked, with no defect behind it) are counted
separately and **excluded from the ratio**. This is deliberate and load-bearing: if
confirmations counted, the ratio could be improved by writing more of them, which is
exactly the highlight-reel failure the tally exists to prevent — a metric wearing the
costume of a defect count. **Do not "simplify" this back into a single total.** The
denominator is defects, and it stays defects.

| | Count |
| --- | --- |
| Defect-findings | **16** |
| — caught by a mechanism | **9** (F3, F4, F6, F10, F12, F14, F15, F16, F18) |
| — caught by luck | **7** (F1, F2, F5, F11, F13, F17, F19) |
| Confirmation-findings (excluded from the ratio) | 4 (F7, F8, F9, F20) |

**The pipeline caught 9 of 16, and F18 is the softest catch in the column.** Three of its four
instances were caught; the fourth — a red-phase impact list that named 13 of 24 settled movers —
was caught by nothing, and it is the instance the rule is actually about. **F19 is the sprint's
real miss and it is unambiguous:** a rule about every process a verb spawns was applied to three
composers of five, and the fifth shipped printing 211 bytes the tool did not write, on a stream
that had been echoing the same two lines through every `verify-sprint.sh` run of the sprint,
including the ones read line by line at the RED review.

**The pipeline caught 8 of 14** — and the ratio flatters it. **Both of Sprint 18's
catches are the same mechanism catching the same reviewer's misses one gate late:** F15
and F16 were approved at the RED review and found by the **green** gate, exactly as F14
was. A gate that catches what the previous gate approved is doing its job and is also
evidence that the previous gate's method was wrong; counting it as a clean catch is the
arithmetic being kind. Read the three together — F14, F15, F16 — as one pattern rather
than three successes.

**The split is not random: all four misses are unforced rows of the inventory above** —
F1 (row 14, unforced until Sprint 14), F2 (row 13, unforced until Sprint 11), F5 (row 15,
unforced still), F11 (row 20, unforced still). All five catches are forced rows: F3
(row 8), F4 (row 9), F6 (row 10), F10 (row 19), F12 (row 20, forced by the change F11
itself adopted) — every one of them **procedural rather than mechanical**, now across
nine findings and five sprints of evidence. This pipeline's mechanical gates have still
never caught a defect in the product; what they catch is missing *declarations*, and what
catches defects is a human working a checklist.

**F12 is the first time a change this file adopted went on to catch a later defect**, and
it is the strongest evidence the file is worth keeping: F11's runbook change (probe a
reachability claim or mark it unprobed) is precisely what turned "the next boundary added
will be in the blind spot" into six probed, reproducible defects at Gate B. A finding
that only describes is a memoir; a finding that changes a step and then catches something
is a mechanism with a slow fuse.

That is the whole relationship between the two sections. **The tally says how often the
pipeline was lucky; the inventory says where the luck will be needed next.** Read the
inventory as the standing list and the tally as its scoreboard — a rising catch ratio
means little if the unforced rows have not moved.

---

## F1 — A new implementation of a settled protocol changes the meaning of every settled consumer

**Rule (portable).** When a sprint adds an implementation of an existing interface, the
review question is not "what does the new class do" but "which existing callers now mean
something different, without their code changing". Interfaces whose contract is a
*completeness* claim are the dangerous ones: a second implementation can satisfy the
signature and quietly weaken the claim behind it. Enumerate the consumers, then ask each
one whether it still holds.

**Evidence (Parley, Sprint 14, issue #16, commit `d54b490`).** `SparseIndexSource` made
`snapshot`'s completeness conditional on a seed set. Six settled `CLI` verbs consumed
`snapshot`; one of them, `add`, snapshots *before* it edits `Package.st`
(`src/exec/CLI.st:302` vs `src/exec/CLI.st:316`) and resolves the post-edit manifest
against that pre-edit snapshot. Its seed set therefore could not contain the name being
added, so `parley add --index` would have failed **every time** with a `#noVersions`
conflict blaming the package — exit 1, no crash, atomic rollback working perfectly.
Scenarios S1–S15 were all blind to it: every scenario was written about the new class,
and the defect was in a settled verb.

**What caught it.** **Luck.** Nothing in the pipeline. It surfaced while the operator was
ruling an unrelated Stage 3 halt (§8 decision 51) and happened to read `add`. A second
instance in the same sprint — §8 decision 52, `CLI >> seedNames` catching `Error` where
it means two declared boundary errors, with the same silent package-blaming symptom —
surfaced at a Gate B code read. Twice in one sprint, the mechanism was luck.

**Change adopted.** Stage 2 architecture checklist, item 2 widened rather than a seventh
item added. The question is unanswerable at Stage 1, where you have scenarios but not the
protocol, so an item there would be asked before its answer was knowable, collect a
confident pass, and tax every future review. Honest limit: the amendment catches the
first instance and **not** the second, which is a GREEN-phase implementation choice
invisible at architecture review — see F8's note on where that one belongs.

**Status.** Adopted 2026-08-04, before Sprint 15 staging.

---

## F2 — A ranking that is never entered into a comparison never wins

**Rule (portable).** A priority list does not rank anything by existing. If work can be
scoped from a source the list does not see — the last cycle's findings, the freshest bug,
whatever is on screen — then the list is not competing, and no one has to drift for it to
lose. Make displacement a **written decision** rather than a silence, and give every item
a counter that forces the question after N deferrals.

**Evidence (Parley, Sprints 8–10, recorded in `docs/roadmap.md` §1).** Three consecutive
sprints were scoped by the *previous* sprint's close-out finding rather than by the
priority list — Sprint 8 (issue #10, commit `4ef95a5`), Sprint 9 (`f48ac59`), Sprint 10
(`c15c2c5`). Every one was defensible on its merits, and the standing #1 item was
deferred twice while this happened. The roadmap's own account is exact: *"Nobody drifted;
the roadmap simply never won a comparison it was never entered into."*

**What caught it.** **Luck.** No mechanism existed to catch it — a close-out finding is
concrete and on screen, a priority list is in another file, and nothing forced the two
into contact. It was noticed in hindsight, after three sprints, by an operator reading
the roadmap and comparing it against what had actually been built.

**Change adopted.** `docs/roadmap.md` §1's five ranking rules, written after the fact:
the top item is the default and displacement is a written decision; deferral counters
that stop being a judgment call at 3; external clocks outrank preference; carried gaps
ride along but are *scheduled* at Gate C rather than at the moment of discovery; and
trigger-gated items do not queue. The result held — Sprints 11, 12, 13 and 14 each took
the list's #1 item undisplaced.

**Status.** Adopted at Sprint 11 staging. Four consecutive sprints of evidence that it works.

---

## F3 — A spec can assert a mechanism the runtime does not have, and only writing the test finds out

**Rule (portable).** Design documents describe mechanisms the author believes exist.
Where a spec depends on a runtime capability — an exception reaching a handler, a hook
firing, a reflective query answering — the belief is untested until code runs. Write the
test first, and treat "the doc places this where it cannot be built" as a normal, expected
RED outcome that gets escalated rather than worked around.

**Evidence (Parley, Sprints 8 and 9).** Twice, a settled design doc specified a boundary
the toolchain could not host. Sprint 8 (`sprint-08-notes.md`, issue #10): S4 required a
missing `Package.st` to exit 1, but 3.2.5's `FileStream fileIn:` signals a **kernel**
`SystemExceptions.FileError`, so `ManifestFile load:` never reached its check and the
real outcome was exit 70 — a lying attribution of blame, in the sprint's own motivating
example. Ruled as §8 decision 31. Sprint 9 (`f48ac59`, issue #11): Doc E §3 placed the
authoring wrap around the file-in inside `ManifestFile load:`, and that wrap *can never
fire* — the doit context of a filed-in statement is parentless
(`thisContext parentContext` answers `UndefinedObject>>__terminate`). Probed, escalated,
ruled as §8 decision 34, and Doc E §3 was rewritten with the verified mechanic so no
future sprint re-derives the dead end.

**What caught it.** **Mechanism** — the RED discipline, both times. Tests written before
implementation cannot be satisfied by a mechanism that does not exist, and the agent hit
the wall while writing them rather than after shipping. Note what the mechanism did *not*
do: it did not diagnose the cause. In both cases the agent had to **probe** the runtime
and bring evidence; the gate only guaranteed the collision happened early.

**Status.** Confirmed twice. The practice — probe, then escalate with the probe evidence,
never work around — is now the expected response to a spec/runtime collision.

---

## F4 — A reviewed test can be unsatisfiable against settled output, and review will not always tell you

**Rule (portable).** A test review checks that a test asserts the right thing. It does not
check that the thing is *producible* by code the sprint is allowed to touch. When a test
pins a string, a byte sequence or a rendering, verify the pin against the **existing
renderer**, not against the specification of it — the two drift, and the specification is
the one that reads correctly.

**Evidence (Parley, Sprint 14, issue #16, commit `d54b490`).** The reviewed S7 law
selected conflict lines containing `no version of 'ghost'` — quoted. The settled
`Incompatibility` narration renders the package name **unquoted**, pinned byte-for-byte
at `tests/laws/TermIncompatibilityTest.st:160` as
`no version of a satisfies >=9.0.0 <10.0.0`. The law as reviewed was unsatisfiable
without changing settled resolver output that no declared exception covered. The operator
approved it at Gate A; the miss was the reviewer's, not the agent's.

**What caught it.** **Mechanism** — the green gate. An unsatisfiable law cannot go green,
so the collision was forced during Stage 4. The agent probed the settled renderer,
amended the selector to the settled spelling with both `deny:` guards intact, and
**disclosed** the amendment in the GREEN report rather than quietly satisfying it. That
disclosure is the part worth keeping: the standing rule that reviewed tests are never
weakened silently is what converted a reviewer error into a two-line correction with an
audit trail.

**Change adopted.** None mechanical. The reviewer-side habit is stated instead: at Gate A,
verify pinned strings against the settled renderer that must produce them. Adding a
checklist item for this would duplicate what the green gate already enforces — see the
tally's note that this pipeline's gates catch what can be executed.

**Status.** Recorded at the Sprint 14 close-out, commit `8156f94`.

---

## F5 — A gate's file list is a copy of a rule, and copies drift

**Rule (portable).** When automation enumerates paths that a separate rule also
enumerates — a scope regex, an ignore file, a manifest — the enumeration is a duplicate,
and duplicates drift silently in whichever copy is read less often. Derive the list from
the rule, or accept that the drift will be found by a human noticing an odd output.

**Evidence (Parley, Sprint 8, issue #10, commit `4ef95a5`).** `bin/` entered the scope
regex at Sprint 8, when the wrapper stopped being exempt from laws and became a
deliverable. `scripts/wrap-sprint.sh`'s staging list was not updated with it, so
`bin/parley-main.st` came back unstaged at the Sprint 8 wrap and had to be staged by
hand. The script now carries the incident in a comment above the `git add` line, which is
the only reason the evidence survives.

**What caught it.** **Luck.** `wrap-sprint.sh` prints `git status --short` and an operator
read it. Nothing failed, nothing exited non-zero, and a wrap that silently omitted a
deliverable would have looked identical up to that one line of output.

**Change adopted.** The staging list was corrected and given the rule in prose —
*"Anything inside the active `scope-<N>` regex that a sprint can legitimately change
belongs in this list"* — which is a convention, not a derivation. The duplicate still
exists. Recorded here as an **open** structural weakness rather than a closed one.

**Why this entry is the worked example.** Both sides of this pair are plain text and both
are enumerable: the `git add` list in `scripts/wrap-sprint.sh` and the `scope-<N>` regex in
`.parley/scope`. That is exactly the precondition a drift law needs, and the
`BoundaryCoverageTest` precedent of walking source text rather than the image already shows
the shape. It is the cheapest available demonstration of the pattern named in the tally —
one law, one fixture. It is **not** scheduled here: that is a Gate C decision against the
roadmap, and Sprint 15 is release hardening.

**Status.** Partially addressed at Sprint 8. The underlying duplication is live.

---

## F6 — Halting on an unanswerable spec question is cheap; inventing an answer is expensive

**Rule (portable).** An autonomous agent that meets a question its inputs do not answer
has two options, and their costs are wildly asymmetric. Halting costs one round trip.
Inventing costs a plausible architecture that reviewers must first *detect* as invented
and then unpick from working code. Make halting explicitly correct behaviour, name the
artifacts that constitute "the inputs", and reward the halt in review so the incentive is
never to guess.

**Evidence (Parley, Sprint 14, issue #16).** The agent reached Stage 3, found that §8
decision 50 seeded a pre-fetch closure from files it never said how to locate, and
**halted before writing a line** — offering three candidate resolutions and pinning none.
All three were disqualified by a rule none of them had named (the source must never read
`Package.st` or `parley.lock`), and the correct answer left the reviewed constructor
untouched: the missing piece was a protocol message, not a keyword. Ruled as §8 decision
51, commit `28b56ef`. The halt cost one round trip and contradicted no approved artifact.
The Sprint 9 escalation (§8 decision 34, `f48ac59`) is the same shape a sprint earlier.

**What caught it.** **Mechanism** — the escalation protocol (`AGENTS.md` §8 / the standing
kickoff rule: if a question is answered by none of the specs of record, stop and ask). It
fired exactly as designed.

**The finding underneath is not about the agent.** It is that a *staging* ruling can ship
with a hole in it and pass both Stage 1 and Stage 2 review — decision 50 was reviewed,
approved, and incomplete in a way only an implementer discovers. The escalation protocol
is what makes that survivable, which means it is load-bearing rather than a safety net.

**Status.** Confirmed twice (Sprints 9, 14). No change needed.

---

## F7 — When policy threatens a pure core, move the policy to the boundary that already does I/O

**Rule (portable).** A pure component under pressure to learn about a policy — filtering,
pinning, caching, staleness — is being asked to trade its testability for convenience.
The cheaper answer is almost always to satisfy the policy *before* the pure component
runs, in the layer that already touches the outside world, so the core keeps its
signature and every consumer inherits the behaviour for free.

**Evidence (Parley, Sprints 10, 12, 13 and 14).** Four applications, refused four times in
the resolver: §8 decision 37 (retirement filters in the snapshot, not the search loop);
§8 decision 46 (held pins narrow the snapshot via `holding:` — a selective update is a
normal resolution of a smaller world); §8 decision 47 (narrowing can only offer what the
snapshot can describe); §8 decision 50 (a sparse index pre-fetches to fixpoint in
`snapshot`, so lazy fetching inside `IndexSnapshot` is disqualified by name). `Resolver`,
`BacktrackingStrategy` and `ConstraintLedger` were not modified by any of them, and a
future `PubGrubStrategy` inherits all four.

**What caught it.** N/A — confirmation-finding, excluded from the tally. Each instance was
a design choice made correctly at ruling time, not a defect found.

**Status.** Four consecutive applications. Strong enough to be a default rather than a
precedent.

---

## F8 — A claim that cannot be made is narrowed in writing, never faked

**Rule (portable).** When a documented guarantee turns out to exceed what the code does or
the runtime allows, there are three moves: implement the gap, quietly leave the sentence,
or **rewrite the sentence to the true, smaller claim and record why**. The second is the
common one and the worst, because it leaves a document that reads as a specification and
functions as a wish. Narrowing costs a paragraph and keeps the docs load-bearing.

**Evidence (Parley, Sprints 11–14).** Four instances. §8 decision 43: the drift law
searches source text because 3.2.5 offers no reflective alternative, so the *claim* was
bounded to textually-spelled senders inside the law itself. §8 decision 45: `parley exec`
cannot promise a script's success on 3.2.5 — probed, not assumed — so it promises what it
can and the README carries the consumer constraint. §8 decision 49, narrowed at the
Sprint 13 close-out (`d9b6fad`): `add`'s atomicity is the manifest and the lock, not the
store, because the shipped rollback does not restore the store and should not. §8
decision 52, at the Sprint 14 close-out (`8156f94`): `seedNames` catches `Error` where it
means two declared boundary errors — ranked as a carried gap with the failure mode
written down rather than papered over.

**What caught it.** N/A — confirmation-finding, excluded from the tally. Worth noting that
decision 52's *instance* was caught by luck and is counted under F1; what is confirmed
here is the response, not the detection.

**Status.** Four instances. The practice is settled.

---

## F9 — Defer with a named trigger, never with a date

**Rule (portable).** A deferred item with a date is a promise that will be broken or kept
arbitrarily. A deferred item with a *trigger* — a named future condition that makes it
cheap — costs nothing to carry and gets built at the moment it is cheapest. Record the
trigger with the deferral, and let the gate that schedules work check whether triggers
have fired.

**Evidence (Parley, Sprints 10–13).** Two clean instances, both recorded in
`docs/roadmap.md` §2's "Recently cleared". `isLockString:` was duplicated across two
classes at Sprint 10 with the trigger *"a third caller"*; hex-digest validation was the
third caller at Sprint 11, and `Parley.SchemaShape` (§8 decision 41, commit `1a8a251`)
cleared it — with S12 proving both private copies **deleted** rather than bypassed. The
deleted-held-pin narration gap was deferred at the Sprint 12 close-out (`a899ca8`) with
the trigger *"the next sprint that touches the holding path"*; `parley add` touched it at
Sprint 13 (`d9b6fad`) and one shared diagnosis now serves both verbs.

**What caught it.** N/A — confirmation-finding, excluded from the tally.

**Status.** Two worked examples. The runbook's Gate B/Gate C split — rank at discovery,
schedule against the standing list — is what operationalizes it.

---

## F10 — In a phase whose whole point is failure, the tests that *pass* are the ones needing scrutiny

**Rule (portable).** A red phase reports failures, and every reviewer's attention follows
the report. But a red gate is satisfied by the suite failing *overall* — it says nothing
about the tests that passed, and those are exactly the ones that cannot demonstrate
red→green. A test passing in a red phase is either a declared regression guard or a defect,
and **the reviewer cannot tell which without reconstructing the pass set**, which the gate
does not print. Make the phase's inverted attention explicit: enumerate what passed, diff
it against what was declared to pass, and treat an undeclared pass as a finding.

**Evidence (Parley, Sprint 15, issue #17, Gate A, flip commit `6d5f166`).** Nine of the 47
new tests passed in RED; five were declared. The undeclared four included
`testAnUnrecognizedLayoutIsAUsageErrorAndNeverAFallback`, which asserted that
`publish <dest> --layout nonsense` answers exit `2` — true on the pre-sprint tree for a
reason having nothing to do with the value: `--layout` was not a flag at all, so *every*
`--layout` invocation was exit `2`. The law would have kept passing had the flag never
shipped, and could never have demonstrated red→green. Amended at Gate A to assert the
recognized half beside it, read from the same `publishLayouts` table; it then moved from
pass to error in red, and the suite went `passed=718 errors=6` → `passed=717 errors=7`.
The other three undeclared passes were the settled trailing-flag guards, correct and
described in the file's prose but absent from its declared list.

**What caught it.** **Mechanism** — runbook Gate A step 3's weak-test item, reached through
the pass-count arithmetic the Sprint 14 flip commit had already made a habit
(`756 = 709 settled + 47 new`, `718 = 709 + 9 passing`, against 5 declared). The
discrepancy is visible in the counts alone; identifying *which* four required diffing the
files' selectors against the gate's `PARLEY-FAILURE`/`PARLEY-ERROR` lines by hand.

**Change adopted.** Runbook §1 step 3 now carries the enumeration recipe rather than only
the instruction — the check was already written down, and what was missing was the two
commands that make it executable in seconds instead of by inspection. Left deliberately as
a runbook step and **not** built into `verify-sprint.sh`: the gate's verdict is the suite's,
and teaching it to know which tests are "new" would require it to know what a sprint is.

**Status.** First instance. The row it adds to the inventory (19) is procedural and could
be mechanical — both sides are enumerable — which makes it a candidate the same way row 15 is.

---

## F11 — Ranking a defect "unreachable" is a claim about the runtime, and reasoning is not probing

**Rule (portable).** When a review ranks a known gap as latent, theoretical or
unreachable, that ranking is doing real work: it is what defers the fix. But it is a claim
about what the runtime *can* do, and it is almost always reached by reasoning over the
error types the reviewer can think of — which enumerates the reviewer's imagination, not
the runtime's behaviour. The same probe discipline that governs specs (F3) governs
severity rankings. Name the probe that would make the gap reachable and run it, or record
the ranking as **unprobed** so the next reader knows what kind of claim they inherited.

**Evidence (Parley, Sprint 14 close-out `8156f94`, corrected at Sprint 15, commit
`87a9e34`).** §8 decision 52 was ranked a carried gap on the strength of an explicit
sentence: *"Not observable in the shipped tree, since nothing in the gathering path signals
outside `ManifestError` and `LockError`."* That is false, and cheaply so. `CLI >>
pinnedResolution` (`src/exec/CLI.st:692`) guards only
`IndexEntryParseError, IndexEntryFormatError`; a `parley.lock` that is a **directory** —
one `mkdir` away, an ordinary operator mistake — passes `File>>exists`, and `File>>contents`
then signals a *kernel* `SystemExceptions.WrongClass` straight past that handler into
`seedNames`' `on: Error`. On the pre-sprint tree, `resolve --index <base>` against such a
project answered a `#noVersions` `ConflictReport` **blaming the package** — the confident
wrong sentence the decision exists to prevent, shipped and ranked as unreachable.

**What caught it.** **Luck.** The gap was scheduled for Sprint 15 on the roadmap's trigger
("the next sprint that touches seeding or the CLI's error taxonomy"), and the agent then
needed a *driver* for S14 — an error outside the two declared boundaries — and probed
`File>>contents` on a directory to find one. Had it found a different driver, or had the
decision been deferred one more sprint, the misranking would have stood unchallenged.
Nothing in the pipeline compares a written ranking against the runtime; the ranking was
never re-entered into any comparison after the sprint that produced it.

**The finding underneath is about the operator, not the agent.** The bad ranking was
written at Gate B by the reviewer, in the same entry that correctly diagnosed the defect
and correctly stated the portable rule. Being right about the mechanism and wrong about the
reach is the specific failure mode: the analysis is what produces the confidence that makes
the reachability claim feel like part of it.

**Change adopted.** Runbook §2 step 4 — a gap ranked latent must name the probe that would
falsify the ranking, and either run it or mark the ranking unprobed. Cost is one command;
this instance would have cost a `mkdir` and a `resolve`.

**Status.** First instance. Kin to F3 (a spec asserting a mechanism the runtime lacks),
one level up: F3 governs what the docs claim, F11 governs what the *reviews* claim.

---

## F12 — A rule is ruled once and applied to the instances that motivated it; the rest of its domain is a defect set, not a future risk

**Rule (portable).** When a sprint states a general rule and fixes the instances that
prompted it, the unfixed instances of that same rule are **already defects** — not
"future risk", not "the next one added". Before the sprint closes, **enumerate the rule's
whole domain and probe every member**, including the rule's *mirror image*: a rule stated
for one direction (reading a file) does not cover the other (writing one), and the mirror
is where the next instance lives. A ranking that describes only the *future* exposure of a
rule is a reachability claim about the present, and F11 governs it.

**Evidence (Parley, Sprint 16, commit `96ad6b2`, found at Gate B).** §8 decision 56 was
ruled as a general rule — *"a boundary that reads a file begins by requiring that path to
be a regular readable file"* — and applied to three boundaries: `parley.lock`, the `exec`
script, and (mid-sprint, as a conformance gap) `ManifestFile`. The close-out ranked what
remained as a *prospective* gap: *"the next file boundary added will be in the same blind
spot."* Probed at Gate B against the shipped `bin/parley`, **six existing states were
already in it**, every one answering `internal error: … - this is a defect in Parley, not
in your project` at exit `70`:

| State | Answer |
| --- | --- |
| read-only `parley.lock`, `resolve` | exit `70`, `FileError: could not open <path>` |
| read-only project directory, `resolve` | exit `70`, `Permission denied` — **file never named** |
| read-only `Package.st`, `add` | exit `70`, `FileError: could not open <path>` |
| `init` into a read-only directory | exit `70`, `Permission denied` — **file never named** |
| `publish` to a read-only destination | exit `70`, `Permission denied` — **file never named** |
| unreadable index entry `.st` / `.star` | exit `70` — while `DirectorySource` already carries the sentence `missing or unreadable archive file` |

Five of the six are the rule's **mirror**: decision 56 governs *reading*, and nothing in
the tool governs *writing*. The sixth is the rule's own domain, unapplied — and it is the
`ManifestFile` shape exactly, one boundary over: the sentence was already written and the
predicate behind it was never made.

**What caught it.** **Mechanism** — runbook §2.4, the step F11 itself put there. The
close-out's phrasing ("the next boundary added") is a claim that the present is safe, and
§2.4 requires such a claim to name its falsifying probe and run it. The probe was six
`chmod` calls. Counted as a mechanism, but the weak kind: a checklist item a reviewer
works, not a law that halts. No gate in this repository can see a boundary whose sentence
is right and whose predicate is missing — that is **inventory row 21**, added by this
finding and unforced, now with a measured cost rather than a hypothetical one.

**The generative mistake is subtle and worth naming.** The agent did not miss the rule; it
*stated* the rule correctly and even identified the blind spot in the abstract. What it
did not do is turn its own general sentence into a list and walk it. A rule expressed as
prose feels complete when it is written; a rule expressed as an enumerated table is
complete only when every row is green. The sprint that generalizes a fix is exactly the
sprint least likely to enumerate it, because the generalization already feels like the
work.

**Change adopted.** Runbook §2.4 gains a second clause: when a sprint's ruling is stated
as a *general rule*, the close-out enumerates the rule's domain — including its mirror —
and probes each member, or records the domain as unenumerated. Sprint 17 is staged to
convert this particular domain into a table with a law over it, which is the only way row
20 stops being unforced.

**Status.** First instance. Kin to F5 (an enumeration is a copy of a rule, and copies
drift) inverted: F5 is a written list drifting from reality, F12 is reality with no list
written at all.

---

## F13 — A law that abolishes enumeration can still enumerate its own test states, and the states it omits are where the false diagnosis lives

**Rule (portable).** When a sprint replaces an enumeration with a total rule, check whether the *laws that prove the rule* are themselves enumerated. A chokepoint that translates **any** error makes the *error class* total; it does nothing about the **set of hostile states the laws drive**. If those states are a list — "unreadable" and "unwritable" — then a state outside the list reaches a code path no law exercised, and the diagnosis it produces has never been read by anyone. **The failure mode is not a wrong exit code; it is a confident sentence that is false.** Enumerate the *shapes* a path can take, not just the permissions it can carry: absent, wrong type, wrong type at the parent, a dangling link. The rule's own slogan is the tell — a sprint whose thesis is "enumerating states is the trap" is the likeliest place to find an enumeration of states.

**Evidence (Parley, Sprint 17, commit `bba2c79`, found at Gate B — by luck).** The sprint shipped `PathGuard` as the single site performing file I/O, prechecking *and* translating so that "disk-full, a read-only mount and every mode nobody listed answer the same good sentence" (§8 decision 59). Its boundary table carries twelve rows, and `S12` drives **every** row through a hostile state and its mirror — where "hostile" means exactly two things: `makeUnreadable:` and `makeReadOnly:`. All seven states the sprint set out to fix were verified correct at close-out, by hand, through the shipped `bin/parley`. The defect was found only by inventing states nobody had listed:

```
$ mkdir f1 && cd f1 && parley init          # then replace .parley with a FILE
$ echo junk > .parley
$ parley resolve --source ../idx
/…/f1: could not be written - check its permissions and try again
$ test -w /…/f1 && echo WRITABLE
WRITABLE
```

The directory the tool names **is writable**. `CommandLine>>ensureDirectory:` refuses and, by a deliberate and documented rule, names the *parent* — *"told `<workdir>/.parley` could not be written they are reading a name Parley invented."* That rule is right when the parent really is unwritable, and it conflates two states: **the parent cannot be written**, and **the path exists and is not a directory**. In the second the sentence is false and the remedy — *check its permissions* — cannot work, which is precisely what §8 decision 58 forbids: a tool may only make claims it has checked. The mirror reproduces it (`.parley/packages` as a file, `.parley` writable). Both answer exit `1`, so **the sprint's headline exit criterion holds** and no law failed.

The tool already had the right shape one row over: `parley.lock` as a directory answers `parley.lock: not a regular readable file - remove it and run parley resolve to write a new one` — the offender named, a true cause, a remedy that works.

**What caught it: nothing.** The Gate B checklist said *probe the seven states through the shipped binary*; all seven passed. The defect surfaced only because the operator went past the checklist and asked what a path could be *besides* readable and writable. The checklist would have closed the sprint clean.

**Status.** First instance. Kin to F12 one level down: F12 rules that a general rule owes its whole **domain**; F13 rules that the **laws proving it** owe the whole shape-space of their inputs, and that a chokepoint's totality over error *classes* is not totality over input *states*.

---

## F14 — A red gate proves that a law fails; it does not prove that the law's fixtures work

**Rule (portable).** In a red phase every new law must fail, so **failure carries no information about the law's interior.** A law fronted by a missing-class error — the class the sprint is about to create — aborts at its first reference, and everything after that reference is unexecuted for the whole of RED: driver blocks, oracles, the assertions themselves. A fixture defect there is invisible to the gate *by construction*, and it surfaces only at GREEN, when the law is expected to pass and instead fails for a reason that has nothing to do with the product. **At the red review, separate "this law failed" from "this law's machinery ran":** classify each new law as `FAILURE` (its body executed and an assertion was false) or `ERROR` (it aborted early), and treat every `ERROR` law's interior as **unreviewed by the gate and reviewable only by reading**. Record it as an explicit close-out obligation rather than assuming green will vindicate it.

**Evidence (Parley, Sprint 17, commits `62aee7a` → `bba2c79`).** `BoundaryTableTest` and the `S12` acceptance law both errored in red on a `pathBoundaries` MNU — the class-side declaration the sprint existed to add. Their driver *builders* ran, so twenty-four fixture trees were built and torn down and `tmp/` was clean, which made the machinery look exercised; the driver **blocks** never evaluated. Two defects hid there and surfaced only at GREEN:

1. **The `parley.lock (read)` driver ran `parley check` with no `--source`.** `check` is a source-requiring verb, so it answered the pinned usage lines at **exit `2`** — that row could never refuse, and the law over it would have reported a green boundary that had never once been driven.
2. **`PathFixtures boundaryRoleNames` was left unsorted** by the decision-72 rename, against a law comparing a sorted table against it.

**What caught it: a mechanism — the green gate**, which is the honest answer and also the uncomfortable one, because the green gate catches this *after* the red review has already approved the law. The operator had recorded the exposure at the phase flip — *drivers that never evaluate in red hide defects the gate structurally cannot see* — after reading the mirror drivers by hand rather than trusting the gate, and the coding agent disclosed the `ERROR`-versus-`FAILURE` split unprompted in its own RED report. Both are the practice this finding generalizes; neither was a rule at the time.

**Status.** First instance. Kin to F10 (a red phase reports failures, so attention follows the failures and the *passes* go unexamined) inverted: F10 governs what a red gate does not print, F14 governs what it prints without having checked.

---

## F15 — A `FAILURE` proves the law's body started, not that it reached its claim

**Rule (portable).** F14 splits new laws into `ERROR` (aborted at a missing reference, interior unreviewed) and `FAILURE` (body ran, an assertion was false), and treats `ERROR` as the blind spot. **That split is necessary and insufficient.** A test framework stops at the *first* failed assertion, so a law that opens with a **fixture-correctness guard** — a membership check, a sorted-declaration comparison, a "the drivers and their declared labels agree" assertion — reports a perfectly honest `FAILURE` while everything below the guard, including the driver loop and every assertion about the law's actual subject, never executes. The gate cannot tell that apart from a law that failed on its claim: **both print `FAILURE`.** So at the red review, do not stop at the class of the result — **ask which assertion produced it.** A failure at a guard is `ERROR`-equivalent: unreviewed by the gate, reviewable only by reading. The guards are worth keeping — they are what stops a driver being silently dropped — but a guard placed first converts every downstream claim into an unexamined one for as long as the guard is red.

**Evidence (Parley, Sprint 18, commits `d320ba2` → `c9c72e9`).** `AuthoringDiagnosisTest>>testNoAuthoringDiagnosisReachesTheOperatorWithoutNamingAPath` is S7's law — *no diagnosis the authoring path can produce reaches the operator without naming a path* — quantified over an eight-driver family. It opens by asserting the sorted driver labels equal `AuthoringFixtures familyLabels`. On gst 3.2.5 `String <=` **folds case**, so `'no define:'` sorts before `'no Package.st'`; the declared literal was ASCII-ordered; the guard failed first and **the eight-driver loop never ran.** Through the entire red gate and two GREEN increments that law asserted nothing whatever about the diagnoses it exists to check, while reporting a `FAILURE` indistinguishable from a real one. The operator read the law at Gate A, described in the posted review what it asserts, classified it `FAILURE` under F14 — *"body ran, an assertion was false"* — and never asked **which** assertion. The coding agent found it at GREEN, when the law would not go green for a reason unrelated to the product, and disclosed it unprompted with the collation named at the oracle.

**What caught it: a mechanism — the green gate**, and it is the third consecutive finding with that answer and that discomfort. The red review approved a law that was structurally incapable of checking its own subject; the gate that caught it is the one *after* the gate that should have.

**Status.** First instance. Direct refinement of **F14**: F14 says a red `ERROR` hides the interior, F15 says a red `FAILURE` hides everything past the first failed assertion, and the two together mean **a red gate tells you a law is red and nothing else at all.**

---

## F16 — An impact list built from the spelling misses every site that reaches the value another way

**Rule (portable).** When a change ripples through a set of artifacts, **enumerate the set by the property that makes an artifact affected — never by the spelling that usually accompanies it.** Grepping for a literal finds the sites that write the literal and misses every site reaching the same value through a fixture, a constant, an accessor or a helper. This is the census rule for prohibition laws (a law's exemption list is a census of the property it prohibits, not the set of sites that motivated it) applied one level over, to a **review's impact list** — and it is harder to see there, because an impact list is prose in a review rather than code in a law, and nothing ever runs it.

**Evidence (Parley, Sprint 18, commit `c9c72e9`).** The RED review enumerated the settled oracles that the new batch header would break, and posted four: three in `LockBoundaryTest`, one in `Sprint9AcceptanceTest`. The list was built by grepping the four problem **literals** plus the `vocabularyTypo` / `invalidDeclaration` fixture names. `AddVerbTest>>testAnEditThatWillNotLoadIsRolledBack` and `AddVerbTest>>testAnUnparseableConstraintIsJudgedByTheSettledBuilderAndRolledBack` reach their problems through `ManifestEditFixtures selfDependencyProblem` and `unparseableConstraintProblemFor:`, matched neither pattern, and were absent. **The review then compounded it**: it independently checked the agent's *"nothing else breaks"* claim against three further sites and reported the claim accurate — verifying the entries that were on the list rather than asking how the list had been built. The coding agent found both at GREEN by deriving the set from the property, applied them under the existing bounded grant rather than halting a second time on a decision already made, and recorded the miss in both method comments as the lesson.

**What caught it: a mechanism — the green gate**, when the two oracles failed. Note what that is worth: an oracle mismatch is *guaranteed* to be caught by the green gate, so the mechanism deserves little credit here. The reviewable failure is the method, and no gate examines a review's method.

**Status.** First instance as a *method* finding; the same rule already exists in the product as §8 decision 60, where the operator wrote it, and was then not applied to the operator's own list four sprints later. Inventory **row 22**.

---

## F17 — A gate that asserts a property the method deliberately suspends will be ignored exactly when it matters

**Rule (portable).** A continuous check earns its keep by being **believed**, and it is believed only if a red result means something is wrong. So before wiring one up, ask what the process does *on purpose* that the check forbids — every phased method has such a window: a red-first phase, a migration half-applied, a feature flag mid-rollout, a generated artifact not yet regenerated. **If the pipeline publishes a state that cannot satisfy the check, the check will be red for the whole of that window, everyone will learn that red is normal there, and the next genuine failure inside the window is indistinguishable from the expected one.** The fix is almost never to teach the check about the exception — that is how a check is taught to stay quiet. **It is to stop publishing the state**: hold the commits locally and push once the property holds again, so what is published is always a state that can be verified against what it declares.

**Evidence (Parley, Sprint 18).** CI runs `verify-sprint.sh`, which reads `phase:` from `.parley/scope` and requires the suite to pass when it says `green`. Runbook §1.6 as written had the operator flip `phase:` to `green` and **push** at the RED review — at which instant the tree holds the reviewed RED tests and none of the implementation, so the suite necessarily fails. Observed across the sprint:

| commit | CI | state |
| --- | :-: | --- |
| `016b116` | ✅ | `phase: red`, suite red — as declared |
| `d320ba2` | ❌ | `phase: green` pushed with RED tests, no implementation |
| `896e6c3` | ❌ | same window, mid-GREEN ruling pushed on top |
| `129d1da` | ✅ | wrap pushed, 876/876 |

`origin/main` spent the entire GREEN phase in the one state that cannot satisfy the gate it declares. The window is bounded only by how long GREEN takes — hours here, plausibly days.

**What caught it: luck.** CI is a mechanism and it did fire, on two consecutive commits, and **nothing in the pipeline halts on it** — the flip proceeded, GREEN proceeded, the wrap landed, and no gate consulted it. It surfaced because the human operator mentioned the red build out of band while the close-out was in progress. Had they not, the close-out would have shipped and the same red would have been re-created at Sprint 19's flip, one sprint further from anyone remembering why it was normal.

**Status.** First instance, and the first finding in this file about the *observability* layer rather than the review layer. Kin to the inventory's **row 24** — a property the process depends on with nothing recording whether it held — and to **F8**'s standard, that a limitation not written where people look is not stated at all. Ruled at the Sprint 18 close-out: runbook §1.6 no longer pushes, and §2.6 is the sprint's only push.

---

## F18 — A failing assertion truncates the test, and a red phase truncates the impact list

**Rule (portable).** A red phase produces two kinds of evidence and neither is what it looks like. **First: a failing assertion ends its test.** Everything after it never runs — later iterations of a driver loop, later fixtures the loop would have built, the teardown that would have torn them down. A red gate reporting *n* failures has therefore executed a **prefix** of each failing test, and the length of that prefix is invisible in the report. **Second, and worse: the failures a red phase can produce are only the ones the TESTS caused.** The oracles the *implementation* is about to break cannot fail yet — they are green, and they stay green until the code moves. So a red-phase impact list is structurally a list of one half of the blast radius, and it will look complete, because everything on it is confirmed by a gate.

The two halves compound: the first says *the gate saw less of each test than you think*, the second says *the gate saw fewer tests than there are*. Neither is a defect in the method; both are defects in what the method's output is taken to mean. **So: at RED, build the second list by hand — enumerate every settled oracle the planned implementation will break, from the property rather than from what is currently failing — and record, for every failing test, how far into it the failure got.**

**Evidence (Parley, Sprint 19).** Issue [#21](https://github.com/leocamello/parley/issues/21), RED at `f8c5e3e`, wrap at `89ab038`, recorded in `docs/sprints/sprint-19-notes.md` §4 and §5. Four instances, one sprint, in `tests/acceptance/Sprint19AcceptanceTest.st`, `tests/laws/ConfigurationTest.st`, `tests/laws/BoundaryTableTest.st` and `tests/laws/BoundaryCoverageTest.st`.

1. **Both eight-shape config iterations aborted on shape 1.** `Sprint19AcceptanceTest>>testS10_…` and `ConfigurationTest>>testEveryHostileShapeAnswersOneLineNamingThePath` each drive eight hostile `parley.config.st` shapes through one loop; each failed on *"a directory"*. **Seven of eight shapes, and every pinned sentence they own, were never executed in red.** Likewise `testS9_…` aborted at `--source`, leaving `--git` and `--index` unexercised.
2. **Three settled laws failed at a fixture-correctness guard**, so their driver loops never ran at all: `BoundaryTableTest>>testEveryReadRowRefusesAnUnreadablePath` ("the read drivers and the declared read rows disagree"), `BoundaryCoverageTest>>testEachDeclaredBoundaryDiagnosesItsMalformedInput`, and `Sprint17AcceptanceTest>>testS12`. In red, **every obligation the new `parley.config.st` boundary row owes** — exit `1`, the path named, no kernel class, no backtrace, the exact sentence — was unexercised while the gate reported three honest-looking `FAILURE`s. This is F15's condition reached through a different door: F15 is about a guard *inside* a law, this is about a guard that is the law's first assertion.
3. **A defect hid in the truncated tail.** The reviewed `testS9_…` built its per-flag working directory as `'s19-9-', <flag>`, which for `--index` collides with `'s19-9-index'` — the label the `--source` iteration's index fixture already owned. In red the loop never reached the third iteration, so the collision could not appear; in GREEN it did, `directoryNamed:` swept and recreated a populated directory, and `tearDown` removed one path twice and raised out of `PathFixtures unlock:`, reporting an ERROR whose cause was teardown. **The operator reviewed that test at Gate A and approved it.**
4. **RED declared 13 settled movers; GREEN moved 24.** The 13 were exactly the settled tests the *reviewed tests* broke — six `-g` literals, the build-command re-pin, the reader sentence, and four boundary-table oracles — every one of them failing in red and therefore confirmed by the gate. The other **11** were settled laws that were **green in red and could only fail once the product changed**: seven `runner commands = <registration plan>` sites that reach the plan through a fixture (`CliTest` ×2, `AddVerbTest`, `SelectiveUpdateTest`, `Sprint12`/`Sprint13` S11, `Sprint6` S13), and four that pin the `deserializationBoundaries` class list (`BoundaryCoverageTest`, `IndexFlagTest`, `PublishLayoutTest`, `Sprint15` S11). Two greps at RED — `runner commands` and `namesOfBoundaryClassesIn:` over `tests/` — would have produced all eleven.

**What caught it: a mechanism, and it deserves partial credit at best.** Instance 3 halted GREEN, which is the green gate doing exactly its job; instances 1 and 2 were written down at Gate A as explicit close-out obligations, which is a checklist item working. **Instance 4 was caught by nothing.** The agent's wrap notes list all 24 movers with the assertion that moved each — good practice, and it is *reporting*, not detection: no gate compares 13 to 24, and the question "why were eleven of these invisible at RED?" was asked only because the Gate B brief said to ask it. Read instance 4 as the finding and the other three as its illustrations.

**Status.** First instance as a rule, and it overlaps **F16** by design: F16 says an impact list built from the *spelling* misses sites reaching the value another way, and seven of instance 4's eleven are exactly that shape. F18 is the sharper claim underneath it — those sites could not have been caught by *running* anything at RED, whatever the list was built from, because the code that breaks them had not been written. Kin to **F14** (a red gate proves a law fails, not that its fixtures work) and **F10** (in a phase whose point is failure, scrutinise what passes). Ruled at the Sprint 19 close-out: runbook §1.3 gains the hand-built forward impact list and the per-failure depth note.

---

## F19 — Enumerate a rule's domain in the units the RULE quantifies over, not the units the SPRINT is organised in

**Rule (portable).** **F12** says a rule ruled once and applied to its motivating instances leaves the rest of its domain as a defect set. This is the failure mode *after* a team has learned F12 and is trying to comply: they enumerate a domain, walk it, probe every member — and still ship the defect, because **the list they enumerated was in the wrong units.** Sprints are organised in units of *change*: files touched, classes granted an exception, verbs in the issue. Rules quantify over units of *behaviour*: every process spawned, every path read, every message the user can see. Those two lists are near-identical for a small change, which is what makes the substitution invisible, and they diverge exactly where the rule reaches something the sprint was never going to touch. **So: write the domain as a list before writing the scope, in the rule's own nouns; then check which members the sprint's file list does not reach. Those are the defects the sprint will ship while believing it applied its rule.**

**Evidence (Parley, Sprint 19).** The sprint's exit criterion is a rule about **processes**: *"no verb prints a line Parley did not compose except fragments it deliberately keeps and documents."* Everything that got enumerated was in units of **change**: the issue's five declared settled-class exceptions, a probe table of three verbs (`publish`, `install`, `exec`), and §8 decisions 63 and 77 written against those three. The rule's own domain — every class in `src/` composing a command line run through the one process seam — is five members, and `grep -rn "runner run:" src/` prints it:

| composer | child | state after Sprint 19 |
| --- | --- | --- |
| `Publisher` | `gst-package` | silenced (decision 63) |
| `InstalledSet` plan, run by `ExecutionScope>>register` | `install`, `gst-package` | silenced (decision 63) |
| `ExecutionScope>>childCommandFor:` | `gst` (the author's program) | quiet at source, `-g` (decision 77) |
| `SparseIndexSource` | `curl -sfS` | **already silent, and the precedent** — `-s` drops progress, `-S` keeps errors |
| `GitIndexSource` | `git clone`, `git -C … fetch` | **NOT ADDRESSED — ships noisy** |

Probed at Gate B through the shipped binary, streams captured separately: `parley install --git <repo>` exits `0` with `demo 1.0.0` on stdout and **211 bytes on stderr** —

```
Cloning into '/…/app/.parley/git/ce8ccc708ac40762696ccfd65c5fff27b11124dccd4e070f7ecd0c30233bde07'...
done.
```

— text Parley did not compose, naming an internal cache path keyed by a sha256 the operator never chose and cannot act on. It is the sprint's own opening defect, at the one composer nobody listed. A `parley.config.st` recording `#git` reaches it too, so the sprint's new feature is a second route to it.

**The giveaway was on screen the whole time.** `Cloning into 'tmp/parley-s9-9-work/.parley/git/80b6d2e4…'` and `done.` print in **every** `verify-sprint.sh` run, including the one the operator read line by line at the RED review while checking that the chatter markers were live. Nobody asked whose text it was.

**What caught it: luck.** An operator running the shipped binary as a stranger at Gate B, on a probe (`--git`) that no obligation required — the queued list asked for `publish`, `install`, `exec`, the double-`define:` and the state-directory wipe. No gate, no law, and no checklist item covers a verb the sprint did not name. This is the fifth consecutive sprint whose defects came from running the binary or reading one artifact against another, and none from a law.

**Status.** First instance. Sharpens **F12** rather than repeating it: F12's Sprint 16 evidence was a rule applied to three of *n* known members; here the enumeration step was performed, and performed on the wrong noun. Kin to **F2** (a ranking never entered into a comparison never wins) — an item absent from the list is not outranked, it is unseen. **Carried gap, ranked, unscheduled:** `--quiet` on `GitIndexSource`'s two composed lines, the decision-77 shape and the `curl -sfS` precedent. Probed: `git clone --quiet` answers 0 bytes on both streams, and a failing clone still writes `fatal: repository … does not exist` to stderr at exit `128`, so errors survive.

---

## F20 — A finding that changed a step, and the step then held (confirmation)

**Rule (portable).** The test of a retrospective is not whether its entries are true but whether the changes they caused survive contact with the next cycle. **Record the first clean run of a changed step, with the same evidence you would use to record a failure** — otherwise the file accumulates diagnoses and never learns which of its own prescriptions work, and a step that quietly stopped being followed looks identical to one that was never needed.

**Evidence (Parley, Sprint 19).** Three prescriptions, first full sprint under each.

- **F17's no-push rule held.** Runbook §1.6 stopped pushing at the phase flip. `origin/main` sat at `6a67feb` — **CI green, 2026-08-10T21:00:53Z** — for the entire RED and GREEN phases, and **no red CI run was produced at all**. Sprint 18's equivalent window was two consecutive red commits (`d320ba2`, `896e6c3`) that everyone learned to ignore. The sprint's only push is the wrap, carrying five commits.
- **F15's toolchain lesson was applied where it would have bitten.** `ConfigFixtures hostileShapeLabels` declares an eight-member sorted family; `String <=` folds case on 3.2.5, which is precisely how Sprint 18 shipped a law that asserted nothing for a whole red phase. The list was taken from what the toolchain answers, every label was given a lowercase initial so the order is readable off the page, and **the guard passed in red** — empirical proof rather than a claim in a comment.
- **Inventory row 24's mechanism was used and the ordering stayed legible.** Gate C's cold read of `docs/roadmap.md` §2 was stated as the session's first output message instead of written to a file whose mtime proves nothing. At Sprint 19's Gate C it ran first and the transcript shows it first; the displacement declaration that followed is checkable against it. One caveat worth recording rather than smoothing: the mechanism proves *order*, not *independence* — a reader can still open the roadmap, think about the carried gap, and then type the cold read. It is a real improvement over an mtime and it is not proof.

**What it is not.** No defect sits behind any of the three, which is why this is a confirmation-finding and is **excluded from the ratio**. Its value is that all three are cheap to stop doing and expensive to notice having stopped.
