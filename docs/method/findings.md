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
| 25 | A gate artifact's **self-asserted date** ↔ any durable record that the artifact existed on that date | — | **Unforced** — F21 <sup>[q]</sup> |
| 26 | A number asserted in one document ↔ the same number in the document it was quoted from | — | **Unforced** — F22 <sup>[r]</sup> |
| 27 | A law's asserted **exit code** ↔ the set of distinct refusal paths that can reach that law's argv | — | **Unforced** — F26 <sup>[s]</sup> |
| 28 | A control-flow construct that must **unwind** ↔ the toolchain's actual unwinding semantics for it | — | **Unforced** — F24 <sup>[t]</sup> |

**Eight mechanical, nine procedural, eleven unforced.**

- **[a]** Known-partial: textually spelled senders only, because 3.2.5 offers no reflective alternative (§8 decisions 38 corrected, 43).
- **[b]** Written *because* `GitIndexSource` shipped lawful and unreachable for a whole sprint — nothing constructed it.
- **[c]** Known-partial: covers **directories, not classes**, which is exactly how [b]'s defect passed it — `src/source/` was named by the wrapper while the class inside it had no flag.
- **[d]** Every `Parley` `Error` subclass must be in the diagnosed set or the declared undiagnosed list — **no third bucket**, coverage computed by handling as `on:do:` does.
- **[e]** This pair is why usage re-pins land in GREEN with the code change rather than in RED.
- **[f]** Adopted *after* the miss it records; four sprints of evidence since.
- **[m]** Forced by Sprint 17 **only for the two hostile states the law enumerates** — unreadable and unwritable. A path of the *wrong type* is not driven, and that is exactly where F13's defect lives. The row is mechanical against the enumeration, not against the property. **Sprint 18's decision 74 narrows the partial without closing it:** the *state-root* row is now driven through a path's four **shapes** — absent, already a directory, a regular file, wrong-type-or-unwritable parent — and each answers its own declared sentence. That is **one row of twelve.** The other eleven are still driven through the same two permission bits, so the property/enumeration gap this footnote records is now one-twelfth closed and eleven-twelfths open, and saying "F13 is fixed" would be the highlight-reel reading. **Sprint 19 adds a thirteenth row** (`parley.config.st (read)`) and the honest number needs two figures rather than one. On the **property**, the new row is covered: eight input states — a directory, unparseable, wrong tag, missing/misordered/unknown key, non-String value, two sources — each answering its own exact sentence, all eight re-probed through the shipped binary at Gate B. On the **mechanism**, it is not: the row's own driver in `PathFixtures readRowDriversTracking:hostile:` is the same two permission bits as the other eleven, and the eight shapes live in a *separate* enumeration (`ConfigFixtures hostileShapesTracking:`) consumed by two laws outside the table. So the table forces **1 of 13** and the property holds for **2 of 13** — and the gap between those numbers is itself a row-22 pair: two enumerations of one boundary's states, with nothing comparing them. A fourteenth row copying the table's driver alone inherits the two-bit drive and nothing warns.
- **[n]** Named in §8 decision 60 when the census resolved a Scope/Architecture-impact disagreement; **added to this table at the Sprint 17 close-out, eight instances in**, every one caught by an operator reading one artifact against another and none by a gate. **Sprint 18 added six more, and the count is kept honestly because a tidy count is how this row stops being believed.** Four at Gate C, by reading the code against the staging plan: a selector that does not exist (`Parley.Parley class >> load:`), Doc E §4.1 cited for a §3 subject, four declared settled-class exceptions where the code needs two, and an S2 promising a re-voicing the toolchain cannot perform. One at the RED review: *six* absolute Parley source paths where the shipped binary prints **four**, propagated from the staging plan into the issue, Doc B §2.2, decision 62 and four test comments before anyone ran the binary and counted. One at GREEN: the operator's own Gate A impact list, two sites short — see F16. **Sprint 19 added seven more, and every one was caught by a person reading one artifact against another.** Two at Gate C: the roadmap's *"all of it is on stdout"* (false — `exec`'s chatter is on stderr, which is what carved `exec` out) and its *"the README has no installation section at all"* (false since Sprint 17). Three pre-RED, by the coding agent's halt-and-ask — a **mechanism**, and the first time this row has been caught by one: the issue named `Installer` as composing the `install -c` line (probed — it composes no command line at all; the echo is the registration child's), it declared `IndexEntryReader` **not** an exception while the tag whitelist is enforced inside `readFrom:`, and S3 promised a `.star` byte-identical to the pre-sprint tool's, which the toolchain cannot give because a zip embeds staged mtimes. One at the pre-RED ruling, by an operator read: the Doc E amendments the Gate C comment promised for RED had **never landed** — commit `3fbbf5f` carried only Doc B §5.7 and §8. One at the RED review, by an operator read: the issue, Doc B §5.7, Doc E §4.1 and two test comments all called `Configuration` the **fourth** sender of `IndexEntryReader` when `src/` has four senders already, making it the fifth. **Sprint 20 added ten more and they are written up as F22, because the class earned its own entry the moment an instance turned up inside the artifact written to correct one.** Eight at Gate C, zero caught by a mechanism, **two of them defects in the Gate C artifact itself**. One pre-RED, by the coding agent's halt — §8 decision 79, already on `origin/main` past a Gate C review, carrying **three** wrong counts in one sentence (three grounds where the shipped `verbRowFor:withSource:` comment had said four since Sprint 16; a seven-line block where the binary answers six; three positional laws where the family is eleven methods). One at Gate A, by an operator re-derivation: **the agent's corrected mover list — the artifact fixing decision 79's undercount — was itself short** by three README drift laws, five positional methods and a sixth pinned copy. **Thirty-one instances. Four of the thirty-one were caught by a mechanism and all four are the same one — an agent halting to ask rather than a gate halting to check.**
- **[g]** Adopted at Sprint 14. **Still untested after its first opportunity:** Sprint 15 introduced no new class at all, so the widened item was answered "n/a" rather than exercised. Recorded as untested, not as coverage — the opportunity is what expired, not the doubt.
- **[o]** The operator-local narrative half of what the tracked roadmap keeps canonically. It is **untracked**, so no drift law can ever see it — which is why it drifted three sprints (15, 16 and 17 all delivered without reaching it) before anyone compared them. Raised at Sprint 18's Gate C, which deliberately did **not** write this row itself because `docs/method/` is operator-authored and a gate that authors its own findings is how the tally becomes a highlight reel. The forcing step that exists — runbook §3 step 6 — is **the weak kind**: a checklist item a reviewer works, not a law that halts. The tracked/untracked split leaves nothing stronger available, and saying so is the point of the row. **Checked again at Sprint 19's Gate B: the delivery drift is zero** — §9 records Sprints 15-18 and Sprint 19 is added by this close-out, in order. But the header's v6.1 staging entry (2026-08-11) still names *"four declared settled-class exceptions (`Publisher`, `Installer`, `CommandLine`, `ManifestFile`)"*, which the pre-RED rulings superseded the same day — `Installer` withdrawn, `ExecutionScope` and `IndexEntryReader` granted, five in total. **The row drifts within a sprint as well as across sprints, and step 6 only looks across.** Corrected in this close-out.
- **[p]** Raised while reviewing Sprint 18's Gate C output, and **not an accusation about that session** — its cold read reached the demonstrably correct conclusion and caught a §2 divergence a retroactive write-up would not have produced. The pair is structural. Runbook §3.0 step 1 exists *because* the roadmap must be read **before** the carried gap; the only artifact is `operator/staging/sprint-18-cold-read.md`, whose **mtime is the latest of every Gate C artifact** — after the issue, the comment, the plan and the kickoff. mtime records last modification, so it neither proves nor disproves the ordering; **nothing records it either way.** The same hole sits under Gate A's *read the tests before running the gate* and Gate B's *probe before ranking*. **Unlike [o] this one has a cheap real mechanism**: require the ordered step to be a **message in the session transcript** rather than a file, because a transcript is inherently ordered and an mtime is not. Sprint 18's own Gate B is the demonstration — its probe-before-ranking order is legible precisely because it happened as conversation rather than as a file. Adopting it is a runbook §3.0 change and belongs to **Gate C**, not to this close-out.
- **[q]** The durability twin of [p]. [p] asks *did the steps run in that order*; this asks *did this artifact exist when it says it did* — and the two share a cause, which is that a gate's real working surface is a scratch directory nothing preserves. Raised at Sprint 19's close-out from evidence in **Sprint 17's** thread (F21). **Cheap real mechanism available and unwritten:** gate artifacts are already written to `operator/staging/`, which is a directory on the operator's disk that survives a session; the convention line that still sends them to a session scratchpad is the gap, and correcting it costs one line of runbook §0.
- **[r]** Established by **F22** at Sprint 20's close-out and **added to this table at Sprint 21's Gate B, one sprint late** — the finding said *establishes inventory row 26* and no row appeared, which is row 26's own failure mode applied to row 26. There is no cheap mechanism: a doc-to-doc drift law would need a shared vocabulary these documents do not have, and inventing one to make a metric checkable is how the metric stops describing anything. The working practice is the remedy — **at every gate, re-derive the numbers the previous artifact asserts rather than quoting them.** It paid out immediately: this gate quoted *next row 27* from `operator/master-plan.md` v6.5, read the table, found it ending at 25, and "corrected" the master plan — which was right — before checking F22's own text. The master plan had been quoting F22 faithfully; the table was the drifted copy.
- **[s]** Both sides are enumerable and the comparison is cheap, which is what makes this row uncomfortable: for any argv, the refusals reachable from it are a finite list a person can write, and a law asserting only the code is checkable against that list by reading. Nothing does it. **The failure is silent by construction** — the law passes, and passes for a reason indistinguishable from the one it intends. Sprint 21's `testS29` survived a RED review, a Gate A review, eleven GREEN rounds and a wrap while proving nothing about the flag in its own name. A drift law is not obviously available (the reachable-refusal set is a property of control flow, not of a declared table), so the honest status is unforced with a **cheap procedural remedy**: when a law asserts an exit code, assert the sentence too, and where two refusals genuinely share a sentence, say so in the law.
- **[t]** Raised by F24 and the most uncomfortable row in this table, because the pair is invisible in **both** artifacts: the code reads correctly against the language standard, and the toolchain's departure from that standard is not written anywhere in the repository until a probe puts it there. There is no text walk that finds it — `pass` is a legitimate send whose safe and unsafe shapes differ only in whether the handler's value is returned. **What is available is narrow and worth stating:** the repository now records the probed behaviour beside the one construct that depends on it, and the count of `pass` sends in `src/` is two, small enough that a reviewer can read both. That is not forcing. It is a small enough domain to enumerate, which is the weakest useful thing to say about a pair and is said here rather than dressed up.
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
| Defect-findings | **25** |
| — caught by a mechanism | **13** (F3, F4, F6, F10, F12, F14, F15, F16, F18, F21, F23, F24, F27) |
| — caught by luck | **12** (F1, F2, F5, F11, F13, F17, F19, F22, F25, F28, F29, F30) |
| Confirmation-findings (excluded from the ratio) | 6 (F7, F8, F9, F20, F31, F32) |

**Sprint 21 moved the ratio the wrong way and that is the honest result.** Six defect-findings
were added, **four of them luck** — and the two mechanism entries are qualified rather than
clean. F24's catch was a Gate B walk succeeding where `testS29`, the law built for exactly that
claim, passed against the broken build; F27's was a guardrail halting on its own false
positive. **F26 is counted under F24** rather than separately: it is the rule extracted from
that catch, not a second catch.

The unflattering summary, stated plainly because a tally that flatters is not worth keeping:
**Sprint 21's suite went full green at 1091 laws while shipping a fail-wrong at exit 0, and
four of its own laws proved nothing.** Every gate reported success throughout. What found the
defects was a second party re-probing fixtures during GREEN and driving the shipped binary at
Gate B — a person, eleven times over, not a mechanism.

**The pipeline caught 10 of 17, and two of the ten are soft.** **F18**: three of its four instances were caught and the fourth — a red-phase impact list naming 13 of 24 settled movers — was caught by nothing, and it is the instance the rule is about. **F21** is the opposite shape and worth reading as the strongest catch in the file: an agent refused to reconstruct lost work and said so, which is a halt and therefore a mechanism, and it is the only entry here where the mechanism that fired was **an agent's own judgement rather than a script or a checklist**. It is also the finding that went unwritten for two sprints because its number was taken, which is its own small lesson about record-keeping.

**F18 is the softest catch in the column.** Three of its four
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

---

## F21 — A gate's working surface is not durable, so its record ends up self-dated rather than observed

**Rule (portable).** Review gates do their real work in a scratch area — a temp directory, an unsaved buffer, a chat window — and publish a summary somewhere durable afterwards. That split is invisible while nothing goes wrong and total when something does: **lose the scratch area and the gate's own evidence is gone, leaving only a memory of having done the work.** What follows is the part worth naming, because it is where the damage actually lands. The reviewer now has two options and both are bad. Reconstruct from memory, and the published artifact **asserts a date it cannot support** — it says the gate ran on the day the reviewer remembers, and nothing anywhere can confirm or refute that. Or refuse, and the gate has to run again. Teams take the first option almost every time, because the second looks like waste and the first looks like tidying up.

**So: a gate's artifacts are written to a durable location as the gate runs, not summarised into one afterwards** — and durable means *survives the session*, which a scratch directory keyed to a process ID does not. The test is one question a stranger can ask of any gate artifact: *what, other than this document's own header, records that this existed on the date it claims?* If the answer is nothing, the date is a recollection wearing the costume of a record. **And when the scratch area is lost anyway, refusing to reconstruct is the correct move and should be recognised as one**, because the alternative manufactures provenance, which is worse than an admitted gap.

**Evidence (Parley, Sprint 17, resolvable by any stranger).** `gh issue view 19 --json comments`:

| artifact | says | posted |
| --- | --- | --- |
| issue #19 opened | — | `2026-08-06T21:32:15Z` |
| Gate C amendment comment | **"Amended 2026-08-07, before any RED work exists"** | **`2026-08-09T15:34:37Z`** |
| Stage 3 — RED complete | — | `2026-08-09T16:30:21Z` |

**The artifact that gates RED reached a durable surface fifty-six minutes before the phase it gates, carrying a self-date two days earlier.** Every other comment on that thread — the RED report, the RED amendment, Gate A, the GREEN halt-and-ask, Gate B — falls inside a three-and-a-half-hour window on 08-09. The two-day hole between the issue opening and anything durable appearing is the loss-and-re-emission window, and the operator's account is that the Gate C work lived in a session scratch directory under `/tmp` that did not survive.

Note precisely what the timestamps do and do not establish, because overclaiming here would be the same error the finding is about. They establish that **a gate artifact's self-asserted date and its only durable record differ by two days, with nothing reconciling them.** They do not, on their own, distinguish *work done on 08-07 and re-emitted* from *work written on 08-09 and misdated* — and that is the finding rather than a weakness in it. **A gate whose provenance cannot be distinguished from a plausible fabrication has the same evidentiary value as one, whichever actually happened.**

**What caught it: a mechanism, and an unusual one — the coding agent halted and refused to reconstruct.** Asked to carry on from work that no longer existed, it declined to rebuild the lost gate output from memory and said so, which forced the gap into the open instead of papering it over. That is a halt, so it counts as a mechanism, and it is the only entry in this file where the mechanism that fired was **an agent's own judgement rather than a script or a checklist item**. Two things stop that being flattering. The halt surfaced the *loss*; it did not surface the *rule*, which went unwritten for two more sprints — the entry was drafted as "F16" in a release plan, the number was taken by an actual F16, and the finding was dropped rather than renumbered. And the durable-location convention that would prevent a recurrence was **already in use** by every gate since — artifacts have gone to `operator/staging/` for four sprints — while the runbook §0 line telling reviewers where to put them still says *"write to the session scratchpad."* **The practice fixed itself and the instruction did not**, which is exactly how the next reviewer reintroduces this.

**Status.** First instance. Establishes inventory **row 25**, the durability twin of **row 24** — [p] asks whether a gate's steps ran in the order it claims, this asks whether its artifact existed on the date it claims, and both have the same cause. Kin to **F8** (a claim that cannot be made is narrowed in writing, never faked) — F8 governs claims about the product, this governs claims about the process that reviewed it. **Companion action, flagged to the human operator and deliberately not applied here:** runbook §0's convention line should read `operator/staging/` rather than *the session scratchpad*. The runbook is human-edited, and a finding that quietly rewrote the rule it is about would be its own small violation of F8.

---

## F22 — The only thing that catches a cross-artifact contradiction is a second party reading one artifact against another — including inside the artifact written to correct one

**Rule (portable).** A project accumulates statements about itself in more places than it has readers: an issue, a design doc, a decision log, a plan, a code comment, a test oracle. Each is written by someone looking at one of the others, never at all of them, so a wrong count or a wrong name **propagates by being quoted** and every copy afterwards looks like corroboration. No gate sees it. A test suite checks the code against itself; a drift law checks a doc against the running tool; **nothing checks a doc against a doc**, and the class of defect that lives in that gap is invisible in exact proportion to how confidently it is written.

What makes this worth its own entry rather than a footnote is where the instances keep landing. **The artifact written to correct the contradiction is itself a member of the class** — a ruling that fixes a miscount is written by a person reading the same small set of documents under the same time pressure, and it acquires its own. So the remedy cannot be "write a correction more carefully." **The only thing that has ever caught this class is a second party working one artifact against the repository**, and the test of whether that happened is not whether a review occurred but whether *someone re-derived the number instead of reading it*.

**Evidence (Parley, Sprint 20).** Ten instances across three gates of one sprint, and the shape of the last two is the finding.

At **Gate C**, eight were found at staging by a second reader working the draft against the repository — **zero caught by a mechanism** — and **two of the eight were defects in the Gate C artifact itself**.

At the **pre-RED ruling**, the coding agent halted and posted five repository facts the issue or the tracked docs had wrong. The one that matters: **§8 decision 79 — landed on `origin/main` at `9b5d443`, past a Gate C review — carried three wrong counts at once.** It said *three* usage grounds where `CLI class >> verbRowFor:withSource:` had enumerated **four** in its own method comment since Sprint 16; it said a **seven-line** block where the shipped binary answers **six** (476 B, probed); and it said **three** settled laws pinned `lines at: 2` where the real family is **eleven methods**, four of them one README drift law copied into three sprint suites. Three numbers, one sentence each, all three quotable, none checkable by any law in the repository.

Then the instance that closes the loop. **The agent's own corrected mover list — the artifact whose entire purpose was to fix decision 79's undercount — was itself short**: three README drift laws, five positional methods and a sixth pinned copy of the header. It was caught at Gate A by the operator's hands re-deriving the list against the repository rather than reading the agent's. **The correction acquired the defect it was correcting**, which is the same shape as Gate C's two-of-eight and is why this is a rule about second readers rather than about care.

**What caught it: nothing mechanical, and the near-miss is instructive.** Two catches here were agent halts, which inventory row 22's footnote [n] has counted as a mechanism since Sprint 19 — an agent halting to ask rather than a gate halting to check. That precedent is kept, but it must not be allowed to flatter this entry: **a halt fires when the author happens to notice, and the two instances that define this finding — a defect inside a Gate C artifact, and a defect inside the ruling that corrected decision 79 — were both caught by a *different person* re-deriving a number, not by anyone halting.** Classified **luck**, and the classification is the point: had the operator's hands read the agent's list instead of rebuilding it, Sprint 20 would have shipped a mover list short by nine sites, and every gate would have been green throughout.

**Status.** Establishes inventory **row 26**. Row 22's count moves from twenty-one to **thirty-one instances, four caught by a mechanism and all four the same one** — an agent halting to ask. Kin to **F18** (a list derived from spelling enumerates what the grep can see) and to **F12** (a general rule owes its whole domain); F22 is the layer above both — F18 and F12 are about deriving a set wrongly, this is about the *number itself* travelling by quotation between documents no law compares. **Companion action, deliberately not applied by this finding:** there is no cheap mechanism available. A doc-to-doc drift law would need a shared vocabulary these documents do not have, and inventing one to make a metric checkable is how the metric stops describing anything. What *is* cheap and is recorded here as the working practice: **at every gate, re-derive the numbers the previous artifact asserts rather than quoting them** — which is what caught nine of these ten.

---

## F23 — A toolchain constraint recorded five times still cost a run, and the remedy applied was a sixth copy

**Rule (portable).** When a codebase hits a platform limit, the fix lands with a comment where it was hit. Hit it again elsewhere and a second comment lands there. Nothing is wrong with any individual copy, and the copies are why the next occurrence is not prevented: **a note attached to the site that already handles the constraint is invisible from the site that is about to violate it.** Written knowledge that lives only beside its own application is not documentation, it is a scar — legible after the fact, silent beforehand.

The trap in the remedy is worth naming because it is what a careful author reaches for. Having been bitten, the natural repair is *a comment where I was bitten* — which produces one more copy, raises the count, and leaves the next site exactly as unprotected as this one was. **The fix for a constraint that did not reach the author is a mechanism that fires at write time, or an accepted permanent cost; it is never another copy.**

**Evidence (Parley, Sprint 20).** GNU Smalltalk 3.2.5's `Array class >> with:` exists up to **five** arguments; a sixth is a `doesNotUnderstand` at the **first send of the composed method**, so it takes out every caller at once rather than the one line that overflowed. Adding four verb rows to `CLI class >> verbRows` put a sixth `with:` in one group. `passed` fell **881 → 605** in a single increment — 276 laws — because `verbRows` is consulted by every verb, every usage determination, and every law reaching either.

The constraint was **already recorded in the repository in five places**, all predating this sprint:

| where | since |
| --- | --- |
| `docs/sprints/sprint-10-notes.md:119` | Sprint 10 |
| `src/source/DirectorySource.st:262` | Sprint 10 |
| `src/exec/CommandLine.st:258` | Sprint 14 |
| `src/exec/CommandLine.st:512` | Sprint 14 |
| `tests/support/AuthoringFixtures.st:181` | Sprint 18 |

**`src/exec/CommandLine.st:258` is the one that makes this a finding rather than a mishap.** It records the constraint for `sourceFlags` — *"the rows are built in groups of at most five"* — which is the **same declared-row-table idiom** `verbRows` uses, in a file the sprint was editing under a declared exception, four lines from code the agent changed. The knowledge was one file away from the hand that needed it and did not arrive.

The remedy applied was a comment on `verbRows` (`src/exec/CLI.st:136`), which is **the sixth copy**. That is not a criticism of the comment — it belongs there. It is the observation that the same sprint spent its entire F18 effort collapsing five copies of the usage block into one, having established that duplicated text is a mover no grep can see, and then answered a duplicated-knowledge failure by duplicating the knowledge.

**What caught it: a mechanism, cleanly — the green gate, in one run.** This is the column's least ambiguous entry: the defect existed for exactly one verifier run, the sentinel reported it, the count made the blast radius obvious, and the next increment corrected it. The circuit breaker also behaved correctly and is worth recording precisely, because the sprint notes describe it slightly too kindly: `881 → 605` is a **regression**, and the breaker is progress-aware, so that run **incremented** the streak rather than resetting it. The following run at 895 reset it. The breaker never armed because the regression lasted one run — not because every increment showed progress.

**Status.** First instance. Kin to **F15** (a toolchain behaviour assumed rather than probed) and to **F18** (duplicated text is invisible to the tool that would find it); F23 sits between them — the fact *was* probed, years of it were written down, and the writing had no way to reach the reader. **Companion action, flagged and deliberately not applied here:** the honest options are a lint over `src/` and `tests/` for a sixth consecutive `with:` in one send — cheap, mechanical, fires at commit time — or accepting this as a recurring one-run cost and saying so. Choosing the second is legitimate; choosing neither, and adding a seventh comment next time, is how this finding gets a second instance.

**Companion APPLIED, 2026-08-12, on the human operator's direction (the first option):** `scripts/verify-sprint.sh` **Ban 105** — a Phase-1 lint over `src/` and `tests/` for a sixth consecutive `with:` sent to **one receiver**, textual with its bound stated in the ban's own comment (comments and strings stripped; parenthesized sends collapse to a placeholder so nested chains count per receiver; `.`, `;`, `[` and `]` break a chain, so a chain whose argument is a multi-statement block escapes — none has ever been written). Verified in both directions before landing: the 983-law tree passes with the ban in place, and a planted six-chain fails fast at exit `105` naming its file, before a byte of the suite runs — converting a five-times-recorded memory into the mechanism column this file exists to prefer. **Amended 2026-08-12, one sprint later: the first build had a blind spot the defect itself found.** The scan checked only the fully-collapsed text, so a six-chain written **inside an argument's parentheses** — the commonest shape in a test — vanished into the placeholder before it was ever counted. Sprint 21's RED hit exactly that at runtime (a DNU on `#with:with:with:with:with:with:` while Phase 1 passed), and the agent reproduced the ban's own algorithm to prove the miss rather than assert it. The scan now tests **every parenthesis depth** (verified: the argument-position shape fails at exit `105`; the nested declared-table idiom stays clean; the full tree passes). A lint written from one instance inherits that instance's shape — whether that is F24 or a second F23 instance is Gate B's to classify, with the honest note that the lint caught nothing here: a runtime DNU and the agent's diligence did.

**Classified at Sprint 21's Gate B: a SECOND F23 INSTANCE, not a new finding.** The rule F23 states is *a note attached to the site that already handles the constraint is invisible from the site that is about to violate it*, and the mechanism built to replace those notes reproduced the same shape one level up: **Ban 105 was written from the one instance that motivated it**, so it saw the top-level chain that had bitten and not the argument-position chain that had not yet. The lint is the sixth copy's replacement and it inherited the sixth copy's field of view. Recording it as a second instance rather than as F24 keeps the count honest — the rule did not need amending, its own remedy needed the amendment — and it sharpens the portable half: **a lint built from one defect encodes that defect's shape; the acceptance test for a new lint is a planted instance in every shape the constraint can take, not in the shape that prompted it.** What caught it: **luck**, and the entry above already says so — a runtime `doesNotUnderstand` during RED while Phase 1 passed clean.

---

## F24 — `pass` does not unwind on this toolchain, and the comment justifying it was the defect's disguise

**Rule (portable).** A comment that *reconciles* a suspicious construct with a rule that forbids it is load-bearing in a way ordinary commentary is not: it is the artifact a later reader consults **instead of** re-deriving the behaviour. So it must cite a **probe**, never an argument. A reconciliation written from reasoning does not merely fail to catch the defect — it **conceals** it, because code and comment then share one misunderstanding and a reader checking either against the other finds agreement. *Decision 43's standard — state the bound you actually measured — applies to comments, and most urgently to the comments that exist to explain why a rule does not apply here.*

The second half is about **who asks**. A reviewer who anticipates a hazard and asks for a *justification* has requested the wrong artifact: justification is producible by thought, and the hazard in question was only decidable by execution. **Ask for the probe, or the prophylaxis becomes the disguise.**

**Evidence (Parley, Sprint 21, found at Gate B).** `parley add <pkg> <c> --locked` and `parley remove <pkg> --locked` answered **exit 0 with the ordinary success pin-lines while writing neither `Package.st` nor `parley.lock`** — a fail-wrong at exit 0, against `CommandLine>>run:`'s own contract that *no failing command ever exits 0*, in the sprint's own new feature, one sprint before the v1.0 tag. `resolve --locked` and `update --locked` were correct throughout.

The cause is a toolchain behaviour, probed at the gate rather than assumed:

> **In GNU Smalltalk 3.2.5, `Exception>>pass` does not unwind.** It runs the outer handler, **discards that handler's value**, and **resumes execution after the inner `on:do:`**.

So `CLI>>addResolving:against:unheld:restoring:lock:` — `[self writeLock: outcome] on: LockError do: [:e | self restore: …. e pass]` — let `CommandLine>>run:`'s boundary compose the exit-1 refusal, threw it away, and fell through into `installResolution:`, which succeeded. The **atomicity** half was always true; the restore ran and both files stayed byte-identical. Only the exit code and the lines lied.

**The comment at that site is what makes this F24 rather than a bug report.** It is a nine-line paragraph reconciling the construct with §8 decision 75, which had examined and refused catch-restore-pass elsewhere. It argues — correctly, and irrelevantly — that decision 75's grounds were about wrapping an author's whole program in a broad catch, and that this block contains nothing but Parley's own write step. Every sentence is true. None of them is about whether `pass` unwinds, which is the only question that mattered, and which one probe would have answered. **The paragraph was requested by the operator's verifier-hands as a prophylactic against exactly this class of construct, and it asked for a reconciliation rather than for a probe. That miss is the reviewer's, and it belongs in this file more than the defect does.**

**Blast radius: exactly one site**, established by sweeping every `pass` send in `src/`:

| site | shape | verdict |
| --- | --- | --- |
| `src/manifest/Parley.st:92` | `^anError pass` | **safe** — `pass` is the handler's returned final action, so its answer *becomes* the handler's answer and resumption cannot arise. Sprint 1's green laws confirm it. |
| `src/exec/CLI.st:1574` | `e pass]` as the last statement of a `do:` block whose value is then discarded | **broken** — the one dangerous site, reached by `add` and by `remove`. |

**What caught it: a mechanism — Gate B's mandated walk — and the mechanism built for it failed.** The close-out brief named `--locked` add-atomicity as a thing to drive through the shipped binary, and driving it took one command. That is the checklist column working. But the honest weight of this entry sits on the other side: **`Sprint21AcceptanceTest>>testS29` exists for precisely this claim and passed against the broken build**, for the reason F26 records. A gate that halts is worth more than a walk that happens to look, and here the gate did not halt.

**Status.** First instance. Kin to **F15** (a toolchain behaviour assumed rather than probed) and **F23** (a fact recorded but unreachable); F24 is the sharper case — the fact was neither probed nor recorded, and the artifact that should have prompted the probe was spent arguing instead. **Companion action, in flight at the time of writing:** the falsifier is landed and **red** — `testS29` strengthened at `7f93a4f`, failing at `1090/1091` against the broken build, which is the order this project runs on: the falsifier before the fix. The repair itself is the implementer's and is relayed rather than written here — restore, then **signal fresh** so the error unwinds — with the reconciliation comment rewritten **in the same edit** to cite the probed behaviour and to name `src/manifest/Parley.st:92` as the safe contrast shape. This entry is not closed until both have landed and the shipped binary has been hand-probed for `add` and `remove`.

---

## F25 — Four laws green by construction in one sprint, and the fixture idiom that produced them

**Rule (portable).** A fixture chosen to be *minimal* is chosen for the author's convenience, and minimality removes exactly the parts of the world a law needs in order to fail. When a cheap fixture makes an **earlier** refusal fire than the one under test, the law passes on the wrong refusal and nothing distinguishes that from success. So: **the default fixture is the realistic one, and the degenerate one is used only where the degeneracy is the law's own subject.** The test that a law is not green by construction is cheap and should be routine — *remove the thing the law is about and re-run it; if it still passes, it was never testing that thing.*

**Evidence (Parley, Sprint 21, issue #23).** Four instances, in one sprint, all found by a second party rather than by any gate. The laws are in `tests/acceptance/Sprint21AcceptanceTest.st`, `tests/laws/PathGrammarTest.st` and `tests/laws/UsageGroundTest.st`; the fixture at fault is `tests/support/PathDepFixtures.st`'s `plainEntryFor:`, whose empty `#archive` makes **§8 decision 25**'s diagnosis fire first:

| law | what made it vacuous | found |
| --- | --- | --- |
| `Sprint21AcceptanceTest>>testS34` | every entry written by `plainEntryFor:` carries an empty `#archive`, so `update` answered **decision 25**'s no-published-archive diagnosis before reaching the claim | GREEN round nine |
| `PathGrammarTest>>testTheEditingVerbsRefuse…` (dev row) | both rows removed `kernel-text`, which the **dev** row's manifest does not declare in any kind — the row asked about an absent name and could not have failed had `devDependency:` clauses *been* recognized | GREEN round eleven |
| `UsageGroundTest>>testTheFourFirstLinesDifferFromEachOther` | after decision 83 the fourth argv was no longer a usage ground, and the line it answered contained **the fixture's own path**, so it differed from its neighbours by construction | GREEN round eleven |
| `Sprint21AcceptanceTest>>testS29` | empty `#archive` again — decision 25 refused before `--locked` was consulted — **and** the law asserted only the exit code and byte-identity, which that wrong refusal satisfies | **Gate B**, and it was hiding F24 |

The decisive probe is the same one in three of the four: **drive the law with the thing it names removed.** S29 passed identically with `--locked` deleted from its argv. The editing law's dev row passed identically whether or not the recognizer saw dev clauses. A law that cannot tell those apart is decorative.

**What caught them: luck, and the classification is not close.** No gate halts on a vacuous law — that is the definition of the failure. Three were found only because a reviewer was already inside those fixtures repairing *other* defects and probed before repairing; the fourth was found at Gate B by driving the shipped binary. Had Sprint 21 gone green without a reviewer editing fixtures at all, **all four would have shipped green and vacuous**, every gate reporting success. The sprint's headline number — 1091 laws, full green — is exactly the number that would have been reported.

**Status.** First instance as a named class, though **F10** and **F18** are its relatives (a comparison that enumerates nothing; duplicated text no grep can see). **Ruling applied at this close-out:** in Parley's fixtures, **real published archives are the default** and `plainEntryFor:`'s empty `#archive` is reserved for laws whose subject *is* decision 25. Two scenarios were converted at Gate B and their cost declarations amended to admit the spawn.

---

## F26 — Two refusal paths sharing an exit code make the exit code worthless as an assertion

**Rule (portable).** An exit code is a **classification**, not an identity: a well-built tool deliberately maps many distinct failures onto one code, because that is what lets a caller branch on *kind* rather than on *cause*. A law that asserts only the code therefore asserts only the kind — and wherever two refusal paths can reach the same argv, the law will accept the wrong one silently. **Assert the diagnosis's own sentence.** The wording is the only artifact that distinguishes the paths, which is why the wording is declared once and consumed twice.

The corollary is a design constraint, not just a testing one: *a refusal worth distinguishing is worth wording distinctly*, and if two refusals genuinely share a sentence then the law cannot tell them apart and neither can the operator.

**Evidence (Parley, Sprint 21, issue #23, found at Gate B).** `tests/acceptance/Sprint21AcceptanceTest.st`'s `testS29` asserted `result exitCode = 1` plus byte-identity of `Package.st` and `parley.lock`. All three held — against a build that **ignored `--locked` entirely** — because the fixture's empty `#archive` made decision 25's no-published-archive diagnosis fire first, and that refusal also exits 1 and also writes nothing. Two paths, one code, one law that could not see the difference. The sprint's other `--locked` laws did assert the wording (`ModeFlagTest>>testUpdateUnderLockedRefusesAndWritesNothing` compares against `CommandLine lockedRefusalFor:pinned:would:`), which is why `update` was correct and `add` was not: **the laws differed, and the code followed the laws.**

The strengthened S29 now asserts `result lines = (Array with: (PathDepFixtures lockedRefusalFor: 'kernel-b' pinned: … would: '1.0.0'))` and fails against the broken build — verified red before the fix existed, at `1090/1091` with S29 the only failure.

**What caught it: the same walk that caught F24**, and this entry is the rule extracted from that catch rather than a second catch. Counted once in the tally, under F24's classification.

**Status.** First instance. Directly kin to **F25** — a vacuous fixture and an under-specified assertion are two ways to reach one outcome, and S29 had both at once, which is why it survived a RED review, a Gate A review, eleven GREEN rounds and a wrap.

---

## F27 — A one-actor circuit breaker met a three-session topology it predates

**Rule (portable).** A guardrail that counts *consecutive identical failures* encodes an assumption about **how many actors touch the tree**. Add a second actor — a reviewer, a second agent, a human running the same command to see for themselves — and the counter stops measuring "the worker is spinning" and starts measuring "the tree failed twice", which is the normal state of a phased build. **When the topology a mechanism was built for changes, the mechanism does not fail loudly; it starts producing confident wrong verdicts.** The repair is a read-only mode for observers, not a higher threshold.

**Evidence (Parley, Sprint 21).** The breaker tripped on a **false positive**. It arms on three consecutive failures and has an identical-hash branch that treats a byte-identical failing run as a spin. Sprint 21 runs three sessions against one checkout — coding agent, human operator, and the operator's verifier-hands — and an operator verification run over an unchanged tree produced byte-identical output to the agent's last run. A one-actor breaker read a second actor's legitimate verification as the first actor spinning. **The agent halted immediately, attempted no reset, and disclosed that its own "zero failures" parse was an artifact of an empty log** — which is the halt-and-ask column working exactly as intended.

**Companion applied:** `./scripts/verify-sprint.sh --observe` (`799dc51`) — a full run that neither reads nor writes breaker state, for exactly the observer case. Used for every verification in the eleven GREEN rounds and at Gate B.

**What caught it: a mechanism** — the breaker halted and the agent halted with it rather than working around it. The finding is not that it fired; it is that the topology had changed three sessions earlier and nothing had re-derived the guardrail's assumption against it.

**Status.** First instance. Kin to **F13** (a rule applied to the members that motivated it) one level up: here the *mechanism's own preconditions* were the unenumerated domain.

---

## F28 — The sprint's only-push rule was violated by the session that verifies the rules, and detection was luck

**Rule (portable).** A rule that says *this happens exactly once, at the end* is enforced by whoever happens to remember it, unless the command that could violate it checks first. **The check must live at the command, not in the reviewer's head** — and the reviewer is not the safe party, because the reviewer's own work is the work least likely to be reviewed by anyone else.

**Evidence (Parley, Sprint 21, mid-GREEN).** F17 fixed the sprint's push discipline: **one push, at Gate B, carrying the whole held stack.** During GREEN the operator's verifier-hands landed a harness fix (`--observe`, F27's companion) and pushed it — and that push carried the **held flip commit, the reviewed RED suite and the mid-sprint ruling commits** to `origin/main` with them. F17's first violation, committed by the session whose job is to verify that rules are followed. It left one red CI run on `799dc51` in the history; the human force-pushed `origin` back.

**Detection was luck**: a CI notification, noticed. Nothing in the toolchain objected, because `git push` has no opinion about what a sprint considers held.

**Companion applied, as a standing rule:** before any push, run `git log origin/main..HEAD --oneline` and confirm **every** commit in the range is meant to publish. Harness fixes landed mid-sprint stay **local** while a stack is held. The check costs one command and names precisely the thing that goes wrong.

**What caught it: luck.** Recorded in this file rather than smoothed over, because the alternative reading — *the reviewer knows the rules, so the reviewer is safe* — is the belief that produced it.

---

## F29 — SUnit's run count double-books a test whose `tearDown` raises, and the reconciliation recipe read it as a different defect

**Rule (portable).** A count derived as `passed + failures + errors` is only a count of *tests* if those sets are disjoint, and a framework that files one test under two of them breaks that silently — inflating both the total and the failure count by the same number, which is **the exact signature of a genuinely different problem**. When a reconciliation recipe infers a cause from an arithmetic shortfall, it must first assert the disjointness the arithmetic assumes. **Any recipe that reasons from a total needs a guard proving the total counts what it says.**

**Evidence (Parley, Sprint 21, issue #23, Gate A; the scenarios are `tests/acceptance/Sprint21AcceptanceTest.st`'s S9 and S10, repaired at `a5545fe`).** gst 3.2.5 computes `runCount` as `passed size + failures size + errors size`, and `runCase:` files a test under **both** `failures` and `errors` when `tearDown` raises after the body has already failed. S9 and S10 tracked one capture directory twice, so teardown raised on the second removal. The enumeration `all.txt` came up **short by 2** against `run − 983` — which is precisely the signature runbook §1 step 4 attributes to *new laws living in settled files* (carry-forward CF-5). The prescribed `git diff` grep found nothing, correctly, because CF-5 was clean; the real cause was two double-booked tests. **Cost: the first hour of Gate A.**

**Companion applied, to runbook §1 step 4:**

```bash
comm -12 <(grep '^PARLEY-FAILURE:' run.txt | sed 's/.*>>##//; s/.$//' | sort -u) \
         <(grep '^PARLEY-ERROR:'   run.txt | sed 's/.*>>##//; s/.$//' | sort -u)
```

**must print nothing**, and it is run *before* the arithmetic is trusted. A non-empty intersection is a broken `tearDown`, not a new law. Verified empty at this close-out.

**What caught it: luck** — an operator reconciling counts by hand and refusing to accept the recipe's answer when the grep it prescribed came back empty. A recipe that had been believed would have sent the gate hunting for laws that did not exist.

**Status.** First instance. Kin to **F10** (the class-qualified `comm` caution) and its neighbour in the same step: Sprint 21 also found that `sed 's/.*>>##//'` collapses two classes sharing a selector name (`Sprint12`/`Sprint13AcceptanceTest>>testS12_TheArgvGrammar`), reading 142 where 143 failed. Both settled movers, nothing masked — **but a new selector sharing a name with a settled one would be reported as failing while actually absent.** F10's rule needs its second half: qualify by class before counting.

---

## F30 — The same double proved the same thing twice in one sprint, and the second time was a Gate B walk

**Rule (portable).** A recording double answers "what would have been run"; it cannot answer "what running it produces". When a law's subject is a **transport** — anything whose whole content is the effect of executing something — a recording double does not make the law cheaper, it makes it **impossible**, and the failure presents as a diagnosis about the *world* rather than about the double. **The tell is a diagnosis naming a resource that demonstrably exists**; that is the moment to check the runner rather than the fixture.

**Evidence (Parley, Sprint 21, issue #23).** Twice, on the same misreading, in `tests/acceptance/Sprint21AcceptanceTest.st` and `tests/support/SparseIndexFixtures.st`:

1. **S4** (the sparse re-seed). Driven with the default `RecordingRunner`, the resolve answered `kernel-streams/versions.st: missing or unreadable listing`. That names the **cache** path, not the base — and the base demonstrably held that listing, carrying `#(#'parley-listing' 1 #versions #('1.4.0'))`, before the verb ran. The invited repair was *publish the listing into the base tree*, which is a no-op: `SparseIndexFixtures publish:` writes listing and entry together. The real cause was that `curl` was being **recorded instead of run**. Repaired at GREEN round eleven by driving `CountingProcessRunner`, which delegates and records — buying the law its mechanism assertion (the curl it issued for a name in neither the root manifest nor the lock) rather than only its outcome.
2. **S29** (`add` under `--locked`), where the empty-`#archive` fixture is the same instinct applied to artifacts instead of processes — a cheap stand-in for a real published release, producing an earlier refusal that satisfied the law. See **F25**.

**What caught it: luck both times** — a reviewer re-probing a fixture rather than applying a proposed repair. The first would have shipped as a green law over a transport that never ran; the second did ship, through a wrap, and was caught at Gate B.

**Status.** First instance as a named class. The portable half is the tell, not the rule: *a diagnosis about a missing resource, over a resource you can see, is a diagnosis about your double.*

---

## F31 — The trap double sprang (confirmation)

**Evidence (Parley, Sprint 21, issue #23 — `tests/laws/InspectionVerbTest.st`).** **§8 decision 40**'s discipline — prove a read-only verb never reaches the resolver by giving it a resolver that *signals* if entered, and prove the trap itself is on the path by driving a verb that must spring it — worked as designed and is the sprint's cleanest mechanism entry. `ResolverTrapCLI` overrides the single funnel `resolveAndLock:`; `testResolveStillTripsTheResolverTrap` is the guard that keeps the purity laws from passing against a double that sits on no path at all.

Recorded because the pattern is transferable and cheap: **a negative law needs a positive twin proving its instrument works.** Without the twin, "this verb never enters the resolver" and "this trap was never wired" are indistinguishable — and the second is the state a refactor produces silently. This is the same shape as the `deny: … isEmpty` guards the drift laws grew after Sprint 8, generalised from *collections* to *doubles*.

**No defect behind it.** Counted as a confirmation and excluded from the ratio.

---

## F32 — CF-5 closed at a measured zero rather than an asserted one (confirmation)

**Evidence (Parley, Sprint 21, issue #23 — `docs/sprints/sprint-21-notes.md` §1.1).** CF-5 requires *a new law in a settled file* to be declared as its **own category**, separate from new files and from re-pins, because the `all.txt` enumeration walks the sprint's new test files and a law added to a settled one falls outside it entirely — its red-phase pass never checked. The usual failure is to write "none" from memory.

Sprint 21 closed it **arithmetically**: `1091 − 983 = 108` new selectors, and the six new test files sum to exactly 108 (34 + 17 + 13 + 15 + 16 + 13). The two numbers meeting is the evidence; **zero is what is left over**, not what was claimed.

What makes it a confirmation worth writing rather than a routine count: the zero **held through eleven GREEN rounds of reviewer edits**, and it held for a reason that was chosen rather than lucky — every one of the eleven behaviour re-pins added assertions **inside** an existing method, so `run` never moved off 1091 from RED to green. Had any re-pin been written as a new law beside the old one — the natural shape, and the tidier-looking diff — the category would have been non-zero, and the only thing that would have noticed is this declaration.

**No defect behind it.** Counted as a confirmation and excluded from the ratio.
