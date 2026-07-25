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

- **Sprint 10 — retirement: the third schema, and the boundary that guards it.** ⏱ Issue #12. Retire/yank schema headroom (`#'parley-retired' 1` index-level record, Doc B §5.5; snapshot filtering, Doc C §2.1; scan tag dispatch, Doc F §4.2), with decision 35's lock body/value validation and the deserialization-boundary law riding along **as a prerequisite** — a retirement record is a third sender of `IndexEntryReader readFrom:`, and adding a new operator-editable boundary while the boundary reasoning is unfixed would ship the same defect a third time. Ruled at staging: [§8 decision 37](design/architecture.md#8-decision-log).

### Next, in order

1. **Ergonomics verbs** — *deferred 0×; no external clock, but a named consumer is waiting.* In the order history says users ask for them: `parley why <pkg>` / `tree` first (near-free from the `ConstraintLedger`'s provenance — this is where existing strength is cheapest to expose), then **`parley check`** (a verb spelling of the pin fast path, and the ruled home of **retirement reporting**, which was deferred out of Sprint 10 because warning on a retired *pinned* dependency would break the settled fast-path no-snapshot law), then selective `parley update <pkg>` (the first real pressure on the all-or-nothing grammar), then `parley add` (needs a ruling on machine-editing `Package.st`).
2. **`PubGrubStrategy` + prereleases** — *deferred 0×; **trigger-gated**, does not compete until its trigger fires.* Pre-validated by Hex and Bundler, both of which discarded backtracking resolvers after pathological freezes on real graphs. The trigger is **graph size or observed slowness, never calendar**. Prereleases ride in the same sprint because they touch `Version` comparison — the declared single change site — exactly once.
3. **`RegistrySource` + entry signing** — *deferred 0×; **blocked on hosting**, an external precondition.* Per-package HTTP fetch of signed canonical entries (Hex's model; Cargo's sparse-index lesson — git indexes lose at scale). Byte-stable canonical rendering makes entry signing unusually cheap, because canonicalization is already a law. Made cheaper again by decision 37: retirement never rewrites a published entry, so signatures stay valid across a retirement.

### Recently cleared

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

---

## 4. Phase map (where the roadmap sits)

Phases 1–3 are complete and Phase 4 is open. See [`design/architecture.md`](design/architecture.md) §3–§5.5 for what each phase means and [`sprints/`](sprints/) for what each sprint delivered.

| Phase | Content | State |
| --- | --- | --- |
| 1 | The algebraic domain model | ✅ Sprint 0 |
| 2 | The pure resolution engine | ✅ Sprints 2–3 |
| 3 | The orchestration bridge — installer, execution scope, CLI | ✅ Sprints 4–6 |
| 4 | The ecosystem — publish, sources, the shipped binary, the blame boundaries | 🔄 Sprints 7–10 |
