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

- *Nothing in flight.* Sprint 14 closed; the next sprint is staged at Gate C against the list below.

### Recently delivered

- **Sprint 14 — the sparse-index client: fetch what a resolution can reach, and nothing else.** Issue #16, commit `d54b490`, **709 laws**. This list's top item, staged and delivered undisplaced — the **fourth** consecutive sprint the ranking won on its own merits, and the v1.0 distribution answer (§5). `Parley.SparseIndexSource` serves per-package metadata over a curl process seam, so the whole source is provable offline against a `file://` tree and hosting is later a deployment rather than a redesign. Its stated trigger was **the ruling, not the calendar**, and both rulings fired before the code: [§8 decision 50](design/architecture.md#8-decision-log) at staging — the one I/O moment may be a **closure, never a callback**, so `snapshot` walks the seeds to fixpoint and answers one complete immutable snapshot, leaving `Resolver`, `IndexSnapshot` and both strategies untouched (the fourth put-it-in-the-source application) — and [§8 decision 51](design/architecture.md#8-decision-log) at RED, when the agent halted rather than invent: the seeds are **values supplied by the `CLI`** through `seededWith:`, because the source must never read `Package.st` or `parley.lock`. Wire efficiency is proved by **counting recorded curl command lines**, never inferred, and S15 is the one scenario a listing-caching implementation fails after passing every other. Close-out ruling: [decision 52](design/architecture.md#8-decision-log) — a best-effort read may swallow only the errors whose diagnosis it defers to.

- **Sprint 13 — `parley add <pkg> <constraint>`: the tool edits the manifest, and never re-renders it.** Issue #15, commit `d9b6fad`, **662 laws**. This list's top item, staged and delivered undisplaced — the third consecutive sprint the ranking won on its own merits. Its stated trigger was **the ruling, not the calendar**, and the ruling fired before staging: [§8 decision 49](design/architecture.md#8-decision-log) — Parley never re-renders a file it did not write. `Parley.ManifestEditor` inserts one clause into a recognized cascade and preserves every other byte; the edit is verified by re-loading through the settled `ManifestFile load:`; an unfamiliar shape is refused with the exact text to paste and the file untouched. Adding holds the existing pins (`holding:` in its **third** application, no resolver change again), and the verb is atomic. The byte-preservation laws compare bytes and lines against hand-written oracles rather than computed ones, because an oracle produced by the same splice cannot fail when the splice is wrong — and S3 (comments, blank line and the author's indentation survive) is the scenario a `ManifestBuilder` round-trip passes S1, S2 and S4 and then fails. Sprint 12's deleted-held-pin gap rode along as S13 and is **cleared**. Close-out ruling: [decision 49 narrowed](design/architecture.md#8-decision-log) — atomicity is the manifest and the lock, not the store.

- **Sprint 12 — selective `parley update <pkg>`: move one, hold the rest.** Issue #14, commit `a899ca8`, **612 laws**. This list's top item, staged and delivered undisplaced. Holding lives in the snapshot ([§8 decision 46](design/architecture.md#8-decision-log)), so `Resolver`, `BacktrackingStrategy` and `ConstraintLedger` are neither modified nor entered differently — a selective update is a normal resolution of a smaller world, and a future `PubGrubStrategy` inherits it for free. The byte-identity of the pins that did **not** move is asserted tuple by tuple, and the S2/S8/S10 contrast halves run plain `update` against identical fixtures so that no proof can pass on a fixture where the other outcome was impossible. Close-out rulings: [decision 47](design/architecture.md#8-decision-log) (narrowing can only offer what the snapshot can describe — ruled at the red review, after the literal reading was found to let `update` write a lock with an empty digest) and [decision 48](design/architecture.md#8-decision-log) (already-newest narrows the report, never the contract).

- **Sprint 11 — the inspection verbs, and the debt they let us clear.** Issue #13, commit `1a8a251`, **585 laws**. `why` / `tree` / `check` (this list's top item, built as ranked), plus the three carried gaps the sprint's own work made cheap: `check` is the named consumer that closed the unread `retirementReasonFor:version:` (§8 decision 37 discharged); hex-digest validation was the third caller that triggered the `isLockString:` dedup into `Parley.SchemaShape`; and the drift law's textual anchor was hardened with its claim bounded in writing. The graph verbs walk the lock plus the snapshot and never enter the resolver ([§8 decision 40](design/architecture.md#8-decision-log)), proved by a trap double on the real path. Close-out rulings: [decision 44](design/architecture.md#8-decision-log) (batch for a project, first-defect for a file).
- **Sprint 10 — retirement: the third schema, and the boundary that guards it.** ⏱ Issue #12, commit `c15c2c5`, **539 laws**. Retire/yank schema headroom (`#'parley-retired' 1` index-level record, Doc B §5.5; snapshot filtering, Doc C §2.1; scan tag dispatch, Doc F §4.2), with decision 35's lock body/value validation and the deserialization-boundary law riding along **as a prerequisite** — a retirement record is a third sender of `IndexEntryReader readFrom:`, and adding a new operator-editable boundary while the boundary reasoning is unfixed would ship the same defect a third time. Ruled at staging: [§8 decision 37](design/architecture.md#8-decision-log).

### Next, in order

1. **Release hardening** — *deferred 0×; the last v1.0 item.* `parley --version` (there is no version constant anywhere in `bin/` or `src/exec/` — the first thing every bug report needs); **publishing to a shared index** (`publish <dir>` writes to a directory you own; git-index-as-registry needs the other half, commit-and-push or a documented contributor workflow — this is the gap between "package manager" and "ecosystem"); README and docs for a stranger; and the prebuilt-image decision **taken on measurements**, trigger-gated like `PubGrubStrategy` rather than on intuition.
2. **`PubGrubStrategy` + prereleases** — *deferred 0×; **trigger-gated**, does not compete until its trigger fires.* Pre-validated by Hex and Bundler, both of which discarded backtracking resolvers after pathological freezes on real graphs. The trigger is **graph size or observed slowness, never calendar**. Prereleases ride in the same sprint because they touch `Version` comparison — the declared single change site — exactly once.
3. **Entry signing** — *deferred 0×; **2.0 axis** (§5), not a v1.0 blocker.* Byte-stable canonical rendering already makes signing unusually cheap *whenever* it lands, because canonicalization is a law rather than a convention, and decision 37 keeps signatures valid across a retirement. What is not cheap is the verification itself: under the no-third-party-libraries ban it is PKCS#1 v1.5 over `LargeInteger` or Ed25519 curve arithmetic, written from scratch and vector-anchored like `Sha256` — a crypto sprint, where a subtle error is a security defect rather than a failing law. crates.io ran for years on checksums and transport trust; Hex added signing later. v1.0 does the same.

### Carried gaps — ranked, unscheduled (runbook §2.4)

Recorded at Gate B — or, for the first item below, at an operator walkthrough of the shipped binary — and scheduled at Gate C against the list above, never at the moment of discovery. Ranked most severe first.

- **`parley exec` reports the child's exit code, and 3.2.5 makes that a weaker promise than it sounds.** ✅ *Ruled at Sprint 12 staging — closed as a bounded limitation, not carried as a defect ([§8 decision 45](design/architecture.md#8-decision-log)).* GNU Smalltalk 3.2.5 continues past an unhandled error at the top level of a filed-in script and exits `0`, so `parley exec broken.st` prints the child's backtrace and reports success. Whether a fix existed had been estimated, never probed. **Probed at staging: it does not.** A handler installed around `FileStream fileIn:` never fires — a filed-in statement's doit context is parentless, the same mechanic decision 34 found for authoring — and `Behavior>>evaluate:` fails identically (probed at Sprint 9); there is no `SystemExceptions.UnhandledError` on this toolchain. What is left is capturing the child's output and pattern-matching a backtrace, which is heuristic and would end the live streaming that makes `exec` usable.

  **Consumer constraint (documented in the README, unchanged):** a script whose success matters to CI must end with an explicit `ObjectMemory quit:` — verified to propagate in both directions. `parley exec` alone is not a CI pass/fail signal.

  Reopens only if output capture arrives for another reason. Kept visible because the constraint is live, not because the item is queued.
- **A conflict under held pins does not say whether holding is the reason.** Recorded at the Sprint 13 close-out. Both `add` and `update <pkg>` answer the pinned held-pins line followed by the settled `ConflictReport` narration. That is truthful and it does not separate two different situations: *your new constraint is impossible* and *your new constraint is impossible only because the other pins are held*. The information is in the narration; the sentence is not, and the held-pins line asserts the second reading without having checked it. *Severity: low — right refusal, incomplete explanation, no bad artifact written.* **Consumer constraint:** when `add` or `update <pkg>` reports a held-pin conflict, `parley update` (which holds nothing) is the cheap way to find out whether holding was the cause; if it fails too, the constraint is genuinely unsatisfiable. The fix is probably cheap — re-resolve without holding, and when *that* succeeds say the held pins are the reason and name `parley update` — but it is a second resolution on a failure path and a wording change on two settled verbs, so it is a contract change rather than a patch. This is the same shape as the gap decision 47 left and Sprint 13 closed, one level in. The trigger is an operator misreading it, or the next sprint that touches the holding path.
- **A seed-gathering failure would blame the package, silently** (§8 decision 52, Sprint 14 close-out). `CLI >> seedNames` gathers the decision-51 seed set best-effort, and it is right to: `resolve` must ignore a corrupt lock (Doc E §4.1) and the missing-manifest sentence belongs to `ManifestFile`. But both catches take `Error` rather than the two declared boundary errors they defer to, and a swallowed error leaves a **silently empty or partial seed set** — which under `--index` is decision 47's describability line, so the verb answers a `#noVersions` conflict blaming the package. The exact wrong-blame diagnosis S16 exists to prevent, arriving silently. *Severity: low, and **latent rather than live** — nothing in the gathering path signals outside `ManifestError` and `LockError` today, and no artifact is written on a conflict; it is ranked below the gaps above because an operator cannot currently reach it.* Invisible under `--source` and `--git`, where seeds are ignored, so only the sparse path could ever show it. **Consumer constraint: none today.** The fix is two identifiers — narrow both catches to `ManifestError` and `LockError` — plus one law asserting that a seed-gathering failure outside the declared boundaries surfaces as exit `70` rather than as a conflict. The trigger is the next sprint that touches seeding or the CLI's error taxonomy.
- **The boundary drift law sees only textually spelled senders** (§8 decisions 38 corrected and 43). Hardened in Sprint 11: the walk normalizes whitespace, so a send split across lines is still a send. What stays invisible is a send assembled by `perform:` or split by an interleaved comment, and **there is no reflective alternative on 3.2.5** — probed at Sprint 11 staging: `whichSelectorsReferTo:` searches literals rather than sends and finds none of the real senders; `allCallsOn:` does not exist. *Severity: low.* **Consumer constraint:** the law proves every *textually spelled* sender is declared, not every sender — and that claim is now written into the law itself. Not a gap awaiting a fix; a bounded claim awaiting a toolchain that can do better.
- **`check` requires `--source`**, because its retirement leg and both graphs' non-root edges need a snapshot. A source-less `check` (lock validity + `PinVerification` only) would be a weaker verb wearing the same name, so Sprint 11 left it unbuilt rather than half-built. The trigger is an operator wanting a lock-only check in a context with no index reachable — which has not happened. *Severity: none. No consumer constraint.*

### Recently cleared

- ~~**A held pin the index no longer publishes narrates as a version conflict**~~ — cleared in Sprint 13 (S13), at the trigger the Sprint 12 close-out named rather than on a date: `parley add` opened the same held-pin path for other reasons, so **one** diagnosis now serves both verbs (`parley.lock pins 'x' at V, which the index no longer publishes - run parley update to move off it`). [Decision 47](design/architecture.md#8-decision-log) had already made the state *sound*; this made it legible. The third worked example of these rules — a gap deferred with a named trigger, cleared the sprint its trigger fired, at a fraction of the cost of a dedicated repair sprint, and the acceptance scenario proves it on **both** verbs so the shared wording cannot drift back apart.
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
| `parley remove <pkg>`; **changing** an existing constraint | Both are *edits* rather than additions, and both want decision 49's recognize-or-refuse ruling applied a second time — to deletion and to in-place replacement, each with its own refusal surface. Neither is urgent: `add` refuses a different constraint rather than overwriting it, so nothing is silently wrong, and folding them in would double the recognizer's surface in its first sprint. Trigger: `add`'s recognizer surviving a sprint of real use | Sprint 13 scope, §8 decision 49 |
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
| 12 | Selective `update <pkg>` | The all-or-nothing grammar was the last place the tool forced a diff nobody asked for. ✅ Delivered, issue #14, commit `a899ca8`. |
| 13 | `parley add` | The ruling that gated it is made — [§8 decision 49](design/architecture.md#8-decision-log): a `ManifestBuilder` round-trip is disqualified, because `Package.st` is executable Smalltalk the author owns and the manifest is a lossy projection of it. Recognize or refuse, verify by re-reading, roll back on failure. ✅ Delivered, issue #15, commit `d9b6fad`. |
| 14 | The sparse-index client | §2 item 2. Provable with no network and no server. |
| 15 | Release hardening | §2 item 3: `--version`, publishing to a shared index, docs for a stranger, and the prebuilt-image call taken on measurements. |

### What was ruled *out* of the line, and why

- **`parley exec`'s exit-code truthfulness** — closed as a bounded limitation at Sprint 12 staging (§8 decision 45), not carried and not scheduled. Probed rather than estimated: no handler placement works on 3.2.5, `-f` is inert, and the only remaining mechanism is pattern-matching the child's backtrace out of a captured stream, which would buy "no failing outcome exits `0`" by breaking "never claim more than you can prove". `exec` is a **runner, not a test harness**, and v1.0 says so where the operator meets it.
- **Entry signing** — §2 item 5. Checksum pinning plus transport trust is what the comparable registries shipped their own 1.0 on.
- **`PubGrubStrategy` and prereleases** — §2 item 4, trigger-gated on real graph sizes. A resolver swap is not a release blocker; it is a performance answer waiting for a performance question.

### The 2.0 axis

Hosting, entry signing, and whatever governance a shared index needs. Reached from a v1.0 whose entry format is already canonical and signable, and whose client already fetches per-package metadata over a real transport — which is the whole point of building the road before the destination.
