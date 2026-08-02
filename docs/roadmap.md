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

- *Nothing in flight.* Sprint 12 closed; the next sprint is staged at Gate C against the list below.

### Recently delivered

- **Sprint 12 — selective `parley update <pkg>`: move one, hold the rest.** Issue #14, commit `a899ca8`, **612 laws**. This list's top item, staged and delivered undisplaced. Holding lives in the snapshot ([§8 decision 46](design/architecture.md#8-decision-log)), so `Resolver`, `BacktrackingStrategy` and `ConstraintLedger` are neither modified nor entered differently — a selective update is a normal resolution of a smaller world, and a future `PubGrubStrategy` inherits it for free. The byte-identity of the pins that did **not** move is asserted tuple by tuple, and the S2/S8/S10 contrast halves run plain `update` against identical fixtures so that no proof can pass on a fixture where the other outcome was impossible. Close-out rulings: [decision 47](design/architecture.md#8-decision-log) (narrowing can only offer what the snapshot can describe — ruled at the red review, after the literal reading was found to let `update` write a lock with an empty digest) and [decision 48](design/architecture.md#8-decision-log) (already-newest narrows the report, never the contract).

- **Sprint 11 — the inspection verbs, and the debt they let us clear.** Issue #13, commit `1a8a251`, **585 laws**. `why` / `tree` / `check` (this list's top item, built as ranked), plus the three carried gaps the sprint's own work made cheap: `check` is the named consumer that closed the unread `retirementReasonFor:version:` (§8 decision 37 discharged); hex-digest validation was the third caller that triggered the `isLockString:` dedup into `Parley.SchemaShape`; and the drift law's textual anchor was hardened with its claim bounded in writing. The graph verbs walk the lock plus the snapshot and never enter the resolver ([§8 decision 40](design/architecture.md#8-decision-log)), proved by a trap double on the real path. Close-out rulings: [decision 44](design/architecture.md#8-decision-log) (batch for a project, first-defect for a file).
- **Sprint 10 — retirement: the third schema, and the boundary that guards it.** ⏱ Issue #12, commit `c15c2c5`, **539 laws**. Retire/yank schema headroom (`#'parley-retired' 1` index-level record, Doc B §5.5; snapshot filtering, Doc C §2.1; scan tag dispatch, Doc F §4.2), with decision 35's lock body/value validation and the deserialization-boundary law riding along **as a prerequisite** — a retirement record is a third sender of `IndexEntryReader readFrom:`, and adding a new operator-editable boundary while the boundary reasoning is unfixed would ship the same defect a third time. Ruled at staging: [§8 decision 37](design/architecture.md#8-decision-log).

### Next, in order

1. **`parley add <pkg> <constraint>`** — *deferred 0×; **now #1**, Sprint 12 having landed; no external clock.* The last of the ergonomics verbs, and the one that needs a **ruling before a sprint**: it machine-edits the operator's `Package.st`, which is executable Smalltalk, not a data file Parley owns. Rewriting it means either a text-level edit that must preserve the author's formatting and comments, or a round-trip through `ManifestBuilder` that would silently reformat a file the author wrote by hand. Neither is obviously right and the choice is not a sprint-scope decision. **Trigger for staging: the ruling, not the calendar.**
2. **The sparse-index client** — *deferred 0×; the v1.0 distribution answer (§5).* `SparseIndexSource`: per-package metadata at `<base>/<name>/<version>`, fetched on demand, hash-pinned — the shape crates.io migrated *to* and Hex.pm has always served. **Not blocked on hosting**, because the transport is a process seam like git: `curl -sfS <url> -o <file>` through the settled `ProcessRunner`, which means the whole source is provable offline against a static directory tree over `file://` (probed at the v1.0 staging: exit `0` on a hit, exit `37` on a miss — two distinct grounds, no network, no HTTP implementation in Smalltalk). Ships the protocol so that hosting is later a deployment rather than a redesign.
3. **Release hardening** — *deferred 0×; the last v1.0 item.* `parley --version` (there is no version constant anywhere in `bin/` or `src/exec/` — the first thing every bug report needs); **publishing to a shared index** (`publish <dir>` writes to a directory you own; git-index-as-registry needs the other half, commit-and-push or a documented contributor workflow — this is the gap between "package manager" and "ecosystem"); README and docs for a stranger; and the prebuilt-image decision **taken on measurements**, trigger-gated like `PubGrubStrategy` rather than on intuition.
4. **`PubGrubStrategy` + prereleases** — *deferred 0×; **trigger-gated**, does not compete until its trigger fires.* Pre-validated by Hex and Bundler, both of which discarded backtracking resolvers after pathological freezes on real graphs. The trigger is **graph size or observed slowness, never calendar**. Prereleases ride in the same sprint because they touch `Version` comparison — the declared single change site — exactly once.
5. **Entry signing** — *deferred 0×; **2.0 axis** (§5), not a v1.0 blocker.* Byte-stable canonical rendering already makes signing unusually cheap *whenever* it lands, because canonicalization is a law rather than a convention, and decision 37 keeps signatures valid across a retirement. What is not cheap is the verification itself: under the no-third-party-libraries ban it is PKCS#1 v1.5 over `LargeInteger` or Ed25519 curve arithmetic, written from scratch and vector-anchored like `Sha256` — a crypto sprint, where a subtle error is a security defect rather than a failing law. crates.io ran for years on checksums and transport trust; Hex added signing later. v1.0 does the same.

### Carried gaps — ranked, unscheduled (runbook §2.4)

Recorded at Gate B — or, for the first item below, at an operator walkthrough of the shipped binary — and scheduled at Gate C against the list above, never at the moment of discovery. Ranked most severe first.

- **`parley exec` reports the child's exit code, and 3.2.5 makes that a weaker promise than it sounds.** ✅ *Ruled at Sprint 12 staging — closed as a bounded limitation, not carried as a defect ([§8 decision 45](design/architecture.md#8-decision-log)).* GNU Smalltalk 3.2.5 continues past an unhandled error at the top level of a filed-in script and exits `0`, so `parley exec broken.st` prints the child's backtrace and reports success. Whether a fix existed had been estimated, never probed. **Probed at staging: it does not.** A handler installed around `FileStream fileIn:` never fires — a filed-in statement's doit context is parentless, the same mechanic decision 34 found for authoring — and `Behavior>>evaluate:` fails identically (probed at Sprint 9); there is no `SystemExceptions.UnhandledError` on this toolchain. What is left is capturing the child's output and pattern-matching a backtrace, which is heuristic and would end the live streaming that makes `exec` usable.

  **Consumer constraint (documented in the README, unchanged):** a script whose success matters to CI must end with an explicit `ObjectMemory quit:` — verified to propagate in both directions. `parley exec` alone is not a CI pass/fail signal.

  Reopens only if output capture arrives for another reason. Kept visible because the constraint is live, not because the item is queued.
- **A held pin the index no longer publishes narrates as a version conflict, not as the missing entry it is.** Recorded at the Sprint 12 close-out. [Decision 47](design/architecture.md#8-decision-log) made this state **sound** — narrowing refuses to offer a release it cannot describe, so `update <pkg>` can never write the empty-digest lock the literal reading allowed. What it did not do is make it *legible*: the operator sees the held-pins line followed by an ordinary `ConflictReport`, exit `1`, which reads as "your versions disagree" when the truth is "the index owner deleted an entry your lock still pins". *Severity: low — wrong explanation, right refusal, no bad artifact written.* **Consumer constraint:** when `update <pkg>` reports a held-pin conflict that the versions do not seem to justify, check whether the index still publishes every version in `parley.lock`; `parley check` is the verb that will say so directly. Fixing it means a fourth diagnosis on the verb — a contract change, correctly refused mid-sprint. The trigger is an operator hitting it, or `parley add` opening the same verb for other reasons.
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
| Registry **hosting**, entry **signing**, yanking-as-deletion | Hosting is an operated service with an indefinite horizon (storage, CDN, moderation, name squatting, key custody, an entity to hold it); signing is a from-scratch crypto implementation under the no-third-party-libraries ban, where "the laws pass" is not sufficient assurance. Both are the 2.0 axis (§5) | §8 decision 27, narrowed at the v1.0 staging |
| A `RegistrySource` that *is* a renamed `DirectorySource` | The original decision-27 reason, and it still holds: a source with no protocol of its own earns nothing. What is **no longer** deferred is the sparse-index **client**, which has a protocol, is testable offline, and is §5's item 3 | §5 |
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

Phases 1–4 are complete and Phase 5 — the v1.0 line — is open. See [`design/architecture.md`](design/architecture.md) §3–§5.5 for what each phase means and [`sprints/`](sprints/) for what each sprint delivered.

| Phase | Content | State |
| --- | --- | --- |
| 1 | The algebraic domain model | ✅ Sprint 0 |
| 2 | The pure resolution engine | ✅ Sprints 2–3 |
| 3 | The orchestration bridge — installer, execution scope, CLI | ✅ Sprints 4–6 |
| 4 | The ecosystem — publish, sources, the shipped binary, the blame boundaries, the inspection verbs | ✅ Sprints 7–11 |
| 5 | The release — the editing verbs, the sparse-index client, release hardening | 🔄 Sprints 12–15, the v1.0 line (§5) |
| 6 | Hosting, signing, governance | ⏳ the 2.0 axis (§5) |

---

## 5. The path to v1.0

**v1.0 is "the complete, honest, local-and-git package manager — whose client already speaks the registry protocol."** Ruled at the v1.0 staging (2026-08-02). The version ships when the *code* is done, never when a *service* is.

### What v1.0 is not

Not a hosted registry. Hosting is an operated service with an indefinite horizon — storage, CDN, moderation, name squatting, security response, key custody, and a legal entity to hold all of it — and binding a version number to it means the number ships on someone else's schedule. **Hosting, signing and governance are the 2.0 axis.**

The distinction that makes this work, and the one the four-item plan originally blurred: a registry is **a client protocol plus an operated service**, and only the second is blocked. crates.io's own history is the argument — they migrated the *transport* from a git index to a sparse HTTP index without changing what a client fundamentally does: fetch per-package metadata on demand, pin by hash. The durable artifact was never the server.

So v1.0 builds the protocol and proves it offline. The day someone hosts a Parley index, that is a deployment.

### The sequence

| # | Sprint | Why it is on the v1.0 line |
| --- | --- | --- |
| 12 | Selective `update <pkg>` | The all-or-nothing grammar is the last place the tool forces a diff nobody asked for. Staged, issue #14. |
| 13 | `parley add` | Gated on a ruling first: machine-editing `Package.st` is either a formatting-preserving text edit or a `ManifestBuilder` round-trip that silently reformats a hand-written file. The ruling is the prerequisite, not the sprint. |
| 14 | The sparse-index client | §2 item 2. Provable with no network and no server. |
| 15 | Release hardening | §2 item 3: `--version`, publishing to a shared index, docs for a stranger, and the prebuilt-image call taken on measurements. |

### What was ruled *out* of the line, and why

- **`parley exec`'s exit-code truthfulness** — closed as a bounded limitation at Sprint 12 staging (§8 decision 45), not carried and not scheduled. Probed rather than estimated: no handler placement works on 3.2.5, `-f` is inert, and the only remaining mechanism is pattern-matching the child's backtrace out of a captured stream, which would buy "no failing outcome exits `0`" by breaking "never claim more than you can prove". `exec` is a **runner, not a test harness**, and v1.0 says so where the operator meets it.
- **Entry signing** — §2 item 5. Checksum pinning plus transport trust is what the comparable registries shipped their own 1.0 on.
- **`PubGrubStrategy` and prereleases** — §2 item 4, trigger-gated on real graph sizes. A resolver swap is not a release blocker; it is a performance answer waiting for a performance question.

### The 2.0 axis

Hosting, entry signing, and whatever governance a shared index needs. Reached from a v1.0 whose entry format is already canonical and signable, and whose client already fetches per-package metadata over a real transport — which is the whole point of building the road before the destination.
