# Parley — Roadmap & Ranking

**What this is:** the forward-looking priority list, the rules that order it, and the deferred list every sprint's scope is checked against. It is **tracked and canonical** — where a sprint's scope and this file disagree, one of them is wrong and the disagreement is the finding.

**Who edits it:** the human operator only, at Gate C staging (see [`operating/runbook.md`](operating/runbook.md) §3). The agent **reads** this file — `.github/copilot-instructions.md` §2 item 5 asks it to check every issue's scope against the deferred list below — and never edits it.

**What it is not:** the delivery record. What was actually built, sprint by sprint, is [`sprints/`](sprints/); the rationale behind each design ruling is [`design/architecture.md` §8](design/architecture.md#8-decision-log).

---

## 1. Ranking rules

These exist because they were learned the hard way. Sprints 8, 9 and 10 were each scoped by the *previous* sprint's close-out finding rather than by this list — every one defensibly — while the standing #1 priority was deferred twice. Nobody drifted; the roadmap simply never won a comparison it was never entered into.

1. **The top item is the default sprint.** It wins unless something displaces it, and displacement is a written decision, not a silence.
2. **Deferral counters.** Every item carries `deferred N×`. Increment on each displacement. **At 3, deferral stops being a judgment call**: the item is either staged next or demoted out of the top slot with a recorded reason. An item cannot sit at #1 indefinitely while never being built — that state means the ranking is wrong, and the ranking should be fixed rather than repeatedly overridden.
3. **⏱ External clocks outrank preference.** An item whose cost of waiting is set by something outside the project (adoption, a published schema, a third party depending on current behavior) outranks one without. Its displacement declaration must state what the clock has cost so far.
4. **Carried gaps ride along.** A defect found at close-out is recorded and ranked there, but **scheduled at Gate C** against this list. Prefer *roadmap item + carried gap* over a pure gap-repair sprint. A gap that is a genuine **prerequisite** of the roadmap item is the best case — and the only case where the gap leading is not a displacement at all.
5. **Trigger-gated items do not queue.** An item waiting on a condition (a measurement, an external precondition) does not compete for the top slot until its trigger fires. It is listed so it is not forgotten, not so it is ranked.

---

## 2. Current priority list

### In flight

- *(nothing — Sprint 11 closed; next sprint staged at Gate C.)*

### Recently delivered

- **Sprint 11 — the inspection verbs, and the debt they let us clear.** Issue #13, commit `1a8a251`, **585 laws**. `why` / `tree` / `check` (this list's top item, built as ranked), plus the three carried gaps the sprint's own work made cheap: `check` is the named consumer that closed the unread `retirementReasonFor:version:` (§8 decision 37 discharged); hex-digest validation was the third caller that triggered the `isLockString:` dedup into `Parley.SchemaShape`; and the drift law's textual anchor was hardened with its claim bounded in writing. The graph verbs walk the lock plus the snapshot and never enter the resolver ([§8 decision 40](design/architecture.md#8-decision-log)), proved by a trap double on the real path. Close-out rulings: [decision 44](design/architecture.md#8-decision-log) (batch for a project, first-defect for a file).
- **Sprint 10 — retirement: the third schema, and the boundary that guards it.** ⏱ Issue #12, commit `c15c2c5`, **539 laws**. Retire/yank schema headroom (`#'parley-retired' 1` index-level record, Doc B §5.5; snapshot filtering, Doc C §2.1; scan tag dispatch, Doc F §4.2), with decision 35's lock body/value validation and the deserialization-boundary law riding along **as a prerequisite** — a retirement record is a third sender of `IndexEntryReader readFrom:`, and adding a new operator-editable boundary while the boundary reasoning is unfixed would ship the same defect a third time. Ruled at staging: [§8 decision 37](design/architecture.md#8-decision-log).

### Next, in order

1. **The remaining ergonomics verbs** — *deferred 0×; **top of the list**; no external clock.* The inspection half shipped in Sprint 11 (`why`, `tree`, `check`). What is left is the **editing** half, and it is left because each needs a ruling rather than an afternoon: **selective `parley update <pkg>`** — the first real pressure on the all-or-nothing grammar, which today is the whole point of `update` — then **`parley add`**, which needs a ruling on machine-editing `Package.st` and will not get a good one under a sprint's scope pressure. Sprint 11's `PinnedGraph` note belongs here too: if a fourth verb wants the pinned graph, the walk now living in `CLI` private methods becomes a value object at that moment, not before.
2. **`PubGrubStrategy` + prereleases** — *deferred 0×; **trigger-gated**, does not compete until its trigger fires.* Pre-validated by Hex and Bundler, both of which discarded backtracking resolvers after pathological freezes on real graphs. The trigger is **graph size or observed slowness, never calendar**. Prereleases ride in the same sprint because they touch `Version` comparison — the declared single change site — exactly once.
3. **`RegistrySource` + entry signing** — *deferred 0×; **blocked on hosting**, an external precondition.* Per-package HTTP fetch of signed canonical entries (Hex's model; Cargo's sparse-index lesson — git indexes lose at scale). Byte-stable canonical rendering makes entry signing unusually cheap, because canonicalization is already a law. Made cheaper again by decision 37: retirement never rewrites a published entry, so signatures stay valid across a retirement.

### Carried gaps — ranked, unscheduled (runbook §2.4)

Recorded at Gate B — or, for the first item below, at an operator walkthrough of the shipped binary — and scheduled at Gate C against the list above, never at the moment of discovery. Ranked most severe first.

- **`parley exec` can report success for a script that failed.** ⚠️ *Severity: moderate — the highest-ranked open item, and the only one in the fail-wrong family.* GNU Smalltalk 3.2.5 continues past an unhandled error at the top level of a filed-in script and then exits `0`, so `parley exec broken.st` prints the child's own backtrace and leaves `$? = 0`. **Parley is not misbehaving**: Doc E §2.2 says the child's exit code is an answer and `run:` reports it faithfully, and the §4.2 boundary guarantee covers *Parley's diagnoses*, not a script's runtime. But it is the one remaining path by which a user can be lied to about success — the disease family of decisions 30, 31, 35 and 39, arriving from the one direction the boundary was never meant to cover. Found by using the binary, not by a law; no law can currently see it, because the child is outside every enumeration Parley has.

  **Consumer constraint (documented in the README):** a script whose success matters to CI must end with an explicit `ObjectMemory quit:` — verified to propagate correctly in both directions. Until this is ruled, `parley exec` alone is not a CI pass/fail signal.

  **What a fix would have to decide** — this is design, not repair, which is why it is not being folded into a sprint: whose responsibility is a script's success? A `--strict` mode could compose a preamble that installs a top-level handler and quits nonzero, which is permissible (the script is the operator's *own* file, the same trust category as their `Package.st`, so the third-party-evaluation ban is not in play) but changes what `exec` promises. The alternative is to keep `exec` a faithful pass-through and treat the guarded-script idiom as the documented answer. Either way it wants an operator ruling and a decision-log entry, not a patch.

- **The boundary drift law sees only textually spelled senders** (§8 decisions 38 corrected and 43). Hardened in Sprint 11: the walk normalizes whitespace, so a send split across lines is still a send. What stays invisible is a send assembled by `perform:` or split by an interleaved comment, and **there is no reflective alternative on 3.2.5** — probed at Sprint 11 staging: `whichSelectorsReferTo:` searches literals rather than sends and finds none of the real senders; `allCallsOn:` does not exist. *Severity: low.* **Consumer constraint:** the law proves every *textually spelled* sender is declared, not every sender — and that claim is now written into the law itself. Not a gap awaiting a fix; a bounded claim awaiting a toolchain that can do better.
- **`check` requires `--source`**, because its retirement leg and both graphs' non-root edges need a snapshot. A source-less `check` (lock validity + `PinVerification` only) would be a weaker verb wearing the same name, so Sprint 11 left it unbuilt rather than half-built. The trigger is an operator wanting a lock-only check in a context with no index reachable — which has not happened. *Severity: none. No consumer constraint.*

### Recently cleared

- ~~**`isLockString:` is duplicated across two classes**~~ — cleared in Sprint 11 by `Parley.SchemaShape` ([§8 decision 41](design/architecture.md#8-decision-log)), at the trigger Sprint 10 named rather than on a date: hex-digest validation was the third caller. Both private copies are **deleted**, not bypassed — S12 proves it with `includesSelector:`, so a copy left behind would fail even if nothing called it. The second worked example of these rules: a gap deferred *with a named trigger* was cleared the sprint its trigger fired, at a fraction of the cost of fixing it early.
- ~~**`retirementReasonFor:version:` is written, tested and unread**~~ — cleared in Sprint 11 by `parley check`, its ruled consumer ([§8 decision 37](design/architecture.md#8-decision-log)). Never a gap; scheduling, and it landed where it was scheduled.
- ~~**Retire/yank schema headroom**~~ ⏱ — staged as Sprint 10 after **2 deferrals**. Kept visible as the worked example of these rules: it sat at #1 for two sprints while carried gaps displaced it, which is the pattern §1 exists to stop.

---

## 3. Deferred list (check every sprint's scope against this)

`.github/copilot-instructions.md` §2 item 5 requires each issue to declare collisions with this list — or justify them. Nothing here is forbidden forever; each is deferred **with a reason**, and a sprint that wants one must say so explicitly rather than drift into it.

| Deferred | Reason | Decision |
| --- | --- | --- |
| `RegistrySource`, registry hosting, signing, yanking-as-deletion | A registry source without a registry is either a renamed `DirectorySource` or an untestable HTTP shell; it arrives with hosting | §8 decision 27 |
| Prerelease versions | Smallest well-defined semver surface for MVP; rides with `PubGrubStrategy` when that lands | §8 decision 8 |
| Backjumping | Data supports it; the payoff belongs to `PubGrubStrategy`, not the backtracking loop | §8 decision 14 |
| `PubGrubStrategy` | Trigger-gated on graph size or observed slowness | §2 above |
| `parley retire` verb | Retirement records are authored by the index owner; a verb is ergonomics | Sprint 10 scope |
| Retirement **reporting** on `install` | Requires the index on the fast path, which the settled no-snapshot law forbids; belongs to `parley check` | §8 decision 37 |
| Un-retiring; package-level (vs release-level) retirement | Retirement is additive and monotonic in MVP | Sprint 10 scope |
| Output capture; any shell-quoting layer | Parley composes command lines from paths it controls; the child streams to Parley's own stdout/stderr | Doc E §1 |
| A prebuilt image | Per-invocation file-in is the honest MVP cost; deferred tooling polish | Doc E §4.3 |
| Pruning the `--git` cache | No verb removes checkouts; one directory per distinct repo location | Sprint 9 notes |
| Batching lock problems | One file, one repair, one problem — deliberately unlike the scan, and unlike `check`, which batches because it reports on a project rather than a file | §8 decision 44 |

---

## 4. Phase map (where the roadmap sits)

Phases 1–3 are complete and Phase 4 is open. See [`design/architecture.md`](design/architecture.md) §3–§5.5 for what each phase means and [`sprints/`](sprints/) for what each sprint delivered.

| Phase | Content | State |
| --- | --- | --- |
| 1 | The algebraic domain model | ✅ Sprint 0 |
| 2 | The pure resolution engine | ✅ Sprints 2–3 |
| 3 | The orchestration bridge — installer, execution scope, CLI | ✅ Sprints 4–6 |
| 4 | The ecosystem — publish, sources, the shipped binary, the blame boundaries | 🔄 Sprints 7–10 |
