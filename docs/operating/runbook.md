# Parley — Operator Runbook (human-side gates, executable from a clear session)

This is the human operator's counterpart to the `operator/kickoffs/sprint-NN.md` files: everything that happens **between** agent sessions — the review gates, the close-out, and the staging of the next sprint. A fresh session with no prior context should be able to run any gate from this document alone.

**Tracked, and edited by the human operator only.** This file used to live under `operator/`, excluded wholesale — which meant the entire gate discipline existed on one disk with no history and no backup. It is now version-controlled under `docs/operating/`. The **agent never edits it** (the same rule that governs `.parley/scope`, `scripts/*` and `.githooks/*`); it may read it, and that is harmless — knowing what a reviewer checks does not corrupt the work being reviewed.

What stays local under `operator/` (still excluded wholesale): the master plan, the kickoff prompts, and the landscape audits. The pipeline's *binding* rules for the agent remain `.github/copilot-instructions.md` and `AGENTS.md`.

**Canonical companions, all tracked:** the decision log is [`docs/design/architecture.md` §8](../design/architecture.md#8-decision-log); the priority list and deferred list are [`docs/roadmap.md`](../roadmap.md); the delivery record is [`docs/sprints/`](../sprints/).

---

## 0. Session bootstrap — find out which gate is pending

From a clear session, establish state in this order:

1. `git -C ~/Projects/parley log --oneline -5` and `git status -sb` — what landed, what's unpushed.
2. `cat .parley/scope` — active sprint number and phase.
3. `gh issue list --state all --limit 6` — the milestone issues and their labels.
4. [`docs/roadmap.md`](../roadmap.md) **§2** — the standing priority list and what is in flight. (`operator/master-plan.md` §9 keeps the narrative sprint history; the roadmap is what ranks the *next* one.)
5. The current sprint's milestone issue thread — the agent posts its halts and questions there.

Then match the state to a gate:

| Observed state | Pending gate |
| --- | --- |
| `phase: red`, agent reported "red gate satisfied / awaiting review" | **Gate A — RED review & phase flip** |
| `phase: green`, agent committed `feat(...)` and HALTED after wrap | **Gate B — sprint close-out** |
| Milestone issue closed, no next milestone issue exists | **Gate C — stage the next sprint** |
| Agent reports `🛑 CIRCUIT BREAKER TRIPPED` | **Mid-sprint: breaker ruling** (§4) |
| Agent asked a design question on the issue mid-sprint | **Mid-sprint: design ruling** (§4) |

Standing conventions (apply at every gate):

- **Never** include `Co-Authored-By` / AI-attribution trailers in commits or PRs.
- Only the human edits `.parley/scope`, `scripts/*`, `.githooks/*`, `docs/roadmap.md`, and this runbook. The agent never does — if a wrap commit *contains* a scope-file change, verify it was the operator's own working-tree edit swept in by staging (this is benign and has happened; note it in the close-out comment).
- Kickoff prompts, the master plan and the landscape audits stay out of git (`.git/info/exclude`) and out of the scope regexes. This runbook, the roadmap and the decision log are **tracked** and live under `docs/`, which every scope regex already admits.
- Long issue comments and every other gate artifact: write to `operator/staging/sprint-NN/` — never a session scratchpad, which does not survive the session and leaves the gate's record self-dated rather than observed (finding **F21**, inventory row 25) — and post with `gh issue comment N --body-file ...` (`gh issue close` has no `--comment-file`; comment first, then `gh issue close N --reason completed`).

---

## 1. Gate A — RED review & phase flip

The agent has written the full test suite, satisfied the red gate, posted its **test-defined protocol decisions** on the milestone issue, and halted.

1. **Fetch the decisions:** `gh issue view <N> --json comments -q '.comments[-1].body'`.
2. **Confirm nothing settled was touched:** `git status --short` must show only *new* test files (plus nothing staged). The scope file must be untouched.
3. **Read every new test file** and check:
   - **Traceability:** every scenario `Sn` in the issue has exactly one `testSn_*` selector in `tests/acceptance/`.
   - **Scenario fidelity:** Given/When/Then of each issue scenario is what the test actually asserts (versions, constraints, exact pinned strings/bytes).
   - **Pinned artifacts:** verify exact-byte/exact-string pins against the specs yourself (e.g. constraint renderings against Doc A §3.5; position arithmetic in reader-rejection tests by counting characters).
   - **Weak tests:** any test that *passes* in red must be either a declared regression guard (fine) or a defect — a "passing for the wrong reason" test can never demonstrate red→green. Strengthen it (see step 5).

     **Enumerate the pass set; do not eyeball it.** The gate prints failures, so the tests that matter in this phase are the ones it does *not* print, and the count alone will not tell you which. Two commands (findings F10, which is the Sprint 15 instance this recipe comes from):
     ```bash
     ./scripts/verify-sprint.sh 2>&1 | grep -oE 'PARLEY-(FAILURE|ERROR): Parley\.[A-Za-z0-9]+>>##.*' \
       | sed "s/.*>>##//; s/'//g" | sort -u > /tmp/failing.txt
     grep -hoE '^    test[A-Za-z0-9_]+' <the sprint's new test files> | sed 's/^ *//' | sort -u > /tmp/all.txt
     comm -23 /tmp/all.txt /tmp/failing.txt     # every new test that PASSES in red
     ```
     **RECONCILE `all.txt` AGAINST `run` BEFORE TRUSTING `comm`** (Sprint 20, carry-forward CF-5). The second command enumerates *the sprint's new test files*, so **a new law added to a settled file falls outside it entirely** and its red-phase pass is never checked. The arithmetic is what exposes that: `wc -l < /tmp/all.txt` must equal `run` minus the pre-sprint baseline, and when it comes up short the missing selectors are new laws living in settled files —
     ```bash
     git diff -U0 <baseline-sha> -- tests/ | grep -E '^\+ {4}test[A-Za-z0-9_]+ \['   # new laws in amended files
     ```
     — add them to `all.txt` and re-run `comm`. Sprint 20's count was 71 against a `run` delta of 72, and the missing selector was a legitimate new law in a settled file that no enumeration keyed to new *files* could see. **Require the agent to declare a new-law-in-a-settled-file in its own category**, since a "New (N) / Amended (M)" split conceals it: a settled file growing a law is a different act from a settled file being re-pinned, and only one of them is covered by a declared mover list.

     Diff that against the declared passes-in-red list in the kickoff and the test files' headers. **An undeclared pass is a finding**, even when the test turns out to be a legitimate guard — the declaration is what makes a red-phase pass reviewable at all. Cross-check with the arithmetic: `passed` should equal the settled law count plus exactly the number of passes you can name.
   - **Derivations:** for pinned conflict-proof narrations, hand-trace the strategy semantics (selection order, collapse points, exhaustion order) to confirm the pinned lines are what the spec's reference shape actually produces.
4. **Independently run the red gate:** `./scripts/verify-sprint.sh` — every test file loads (`PARLEY-TESTFILE` per file), zero parse errors, prior sprints' tests still pass, new failures are MNU/missing-behavior, overall suite FAILS.
5. **Adjudicate the protocol decisions** against the design docs — approve, correct, or rule. Reviewer amendments to tests are allowed and are made directly by the operator, under one rule: **strengthen, never weaken**, and tell the agent (the amended version becomes the reviewed test). Re-run the gate after any amendment.
6. **Post the review** on the issue (decisions confirmed/corrected, amendments listed, gate evidence), **flip `phase:` to `green`** in `.parley/scope`, then:
   ```
   git add .parley/scope <any amended test files>
   git commit -m "chore(loop): flip Sprint <N> phase to green after red-phase test review"
   ./scripts/sync-loop.sh <issue>
   ```

   **DO NOT PUSH — the flip commit stays local until the wrap** (ruled at the Sprint 18 close-out; method finding **F17**). `phase: green` means *these tests must now pass*, and at the instant of the flip they cannot: the tree carries the RED tests and none of the implementation. Pushing it puts `origin/main` in the one state that cannot satisfy the gate it declares, **for the whole duration of GREEN** — hours or days. Sprint 18 did exactly that and CI was red across `d320ba2` and `896e6c3` until the wrap landed. The failing run is not the damage; **an expected red is an alarm nobody reads**, and the next real breakage arrives mid-GREEN looking identical. `sync-loop.sh` labels the issue from local state and needs no push.

   **The same holds for mid-sprint ruling commits** (§4): commit them so the agent's tree has them, and let them ride out with the wrap push at Gate B §2.6. If one genuinely must be shared before then — an agent on another machine — that is a declared exception, said out loud, not a habit.
7. Tell the agent to begin Stage 4 (GREEN).

---

## 2. Gate B — sprint close-out

The agent has gone green, run `wrap-sprint.sh`, written `docs/sprints/sprint-<NN>-notes.md`, committed, and halted.

1. **Inspect the deliverable:** `git status -sb` (expect `ahead 1`), `git show <sha> --stat`, read `docs/sprints/sprint-<NN>-notes.md` and `.parley/audit` (they must agree on seed/counts/date).
2. **Check the commit's file list** against the sprint scope; scrutinize any touched settled file against the issue's declared exceptions; verify any scope-file line in the commit was the operator's own edit (see conventions).
3. **Review doc amendments** in the commit (if any) against what Stage 2 approved.
4. **Rule on flagged open questions — diagnose and rank, but do NOT schedule.** The notes' "noted, not built" items are the important ones. Judge severity honestly: a soundness-class gap gets a ruling that names the defect, states the **consumer constraint** until it lands, and estimates what the fix costs. Record it in the close-out comment and, if design-level, in the decision log at [`docs/design/architecture.md` §8](../design/architecture.md#8-decision-log) — the single copy, never the master plan.

   **A ranking of "latent" or "unreachable" is a claim about the runtime — probe it or mark it unprobed.** Deferring rests on the reachability claim, and that claim is normally reached by reasoning over the error types you can think of, which enumerates your imagination rather than the runtime's behaviour. So: **name the probe that would falsify the ranking, and either run it or write "unprobed" beside the ranking.** This is not optional carefulness — the Sprint 14 close-out ranked §8 decision 52 unreachable in a sentence (*"nothing in the gathering path signals outside `ManifestError` and `LockError`"*) and shipped a confident wrong diagnosis that was one `mkdir` away; Sprint 15 found it while hunting a test driver, by luck (findings F11). Cost of the probe that would have caught it: one `mkdir` and one `resolve`.

   **Assign no sprint number here.** Scheduling happens at Gate C (§3), reading `docs/roadmap.md` cold, and the split is deliberate. A carried gap is at its most persuasive in this gate — concrete, reproducible, small, and on screen — and the roadmap is nowhere in view. Three consecutive sprints (8, 9, 10) were scoped by the previous sprint's close-out finding rather than by the roadmap, every one of them defensibly, while the roadmap's own top priority was deferred twice. Nobody drifted; the roadmap simply never won a comparison it was never entered into. Write "**carried gap, unscheduled**" and let Gate C decide against the standing priorities.

   **When the sprint's ruling is a GENERAL RULE, enumerate its domain and probe every member — including the rule's mirror.** The clause above governs a ranking that says *unreachable*; this one governs a ruling that says *always*. A sprint that rules "every boundary that reads a file must check readability" and then fixes the three boundaries that motivated it has not applied the rule — it has fixed three bugs and written a sentence. The unfixed members are **defects already shipped**, not future risk, and the phrase to distrust is any close-out that ranks the remainder prospectively (*"the next one added will be in the same blind spot"*), because that is a claim the present is safe. So: **write the domain as a list, walk it, and probe each member; or record in the close-out that the domain is unenumerated.** And check the **mirror** — a rule about reading does not cover writing, a rule about `add` does not cover `update` — because the mirror is where the next instance lives. Sprint 16 ruled decision 56 for readers, applied it to three of them, and ranked the rest as a future concern; six `chmod` calls at Gate B found six shipped defects, five of them on the write side the rule never mentioned (findings F12, §8 decision 59). Cost of the probe: six commands.

   **Then rule on what the sprint taught the METHOD, and write it down.** A separate axis from the carried gap above: a gap is a defect in the product, a finding is a defect — or a confirmation — in the pipeline. Append it to [`docs/method/findings.md`](../method/findings.md) in that file's five-field form, then run `./scripts/check-method-findings.sh`. **The entry cites specific evidence from this sprint or it is not written**: a breaker trip, a red-gate catch, a scope-sentinel breach, a halt-and-ask, a re-ruled or narrowed decision, an operator amendment, a Gate A miss found at Gate B. Never general musing about process — the gate rejects an entry whose **Evidence** field cites nothing resolvable.

   **Classify it for the tally, and let the answer be unflattering.** Every defect-finding records whether it was caught by a **mechanism** (red or green gate, breaker, scope sentinel, traceability gate, a checklist item — something that *halts*) or by **luck** (an operator reading something adjacent, or a close-out that happened to look). "**What caught it: nothing**" is a legitimate and valuable answer, and the running ratio at the top of the file is updated in the same edit. Confirmation-findings are counted separately and excluded from the ratio, because a ratio that counted them could be improved by writing more of them. The tally is the point of the file: "the pipeline caught 3 of 6, and here are the 3 it missed" is a far stronger claim than six vignettes about a process that worked.

   **This outlives Parley, which is why the form is two-layer.** Each entry's **Rule** is written to be portable — lifted unchanged into a pipeline running on another language and another codebase — while its **Evidence** is what makes the rule credible rather than an opinion. The findings file is the extractable half of this pipeline; do not treat it as project-local scaffolding to be dropped at v1.0.

   **You write this, never the agent**: it has no cross-sprint memory and is the subject of most findings. `docs/method/` sits inside the scope regex, and `wrap-sprint.sh` refuses to wrap when it is staged.
5. **Independently verify:** `./scripts/verify-sprint.sh` must pass green.
6. **Push and close.** This is the sprint's **only** push, and it carries everything held back since the phase flip — the flip commit, any mid-sprint ruling commits, the wrap, and this close-out (§1.6, finding **F17**). Push only once `verify-sprint.sh` is green in step 5, so every commit that reaches `origin/main` leaves it in a state a stranger can clone and verify against the phase it declares.
   ```
   git push origin main
   gh issue comment <N> --body-file <close-out review>   # commit, audit, traceability, rulings
   gh issue close <N> --reason completed
   ```
7. **Anti-drift maintenance:**
   - If `docs/design/*.md` changed this sprint, no mirror refresh is needed — `docs/design/` is the single copy. Confirm `docs/design/README.md` still describes the doc accurately if its scope changed.
   - **Decision log — `docs/design/architecture.md` §8, the single copy.** Add an entry for every sprint-won design ruling, **in the same commit as the doc change that cites it**. There is no second log to mirror into: the tracked summary and the operator's fuller copy drifted by four decisions before this rule existed, leaving tracked docs citing decisions a cloner could not resolve. Never write a decision only into the master plan.
   - **Roadmap — `docs/roadmap.md`.** Move the completed item out of the priority list, and increment the deferral counter of anything this sprint displaced (§3.0).
   - **Master plan:** mark the sprint completed in §9 (issue, commit, law count, any ruled gap) and bump the version/changelog line if the amendment is substantive. The master plan now *references* the decision log and the roadmap rather than duplicating them.

---

## 3. Gate C — stage the next sprint

Scope comes from the tracked roadmap, **`docs/roadmap.md`** §2. If reality has diverged from it (a ruled gap, a split), amend the roadmap first — the plan wins until amended, so amend it rather than drift from it.

### 3.0 The displacement rule (run this BEFORE drafting the issue)

Amending §9 prevents *silent* drift. It does nothing about **priority inversion** — inserting a new item at the top of the roadmap is a fully compliant way to keep deferring what was already there. This step is the forcing function. It is now *mechanizable* — `docs/roadmap.md` is tracked, so a gate script can compare a staged sprint against the priority list — but no such check exists yet, and until one does this remains a human step run in order.

1. **Read `docs/roadmap.md` §2 cold**, before opening the close-out notes or the carried-gap rulings. Whatever is at the top is the default sprint. It wins by default; anything else has to earn the slot.

   **Record the cold read as the session's first output message, not as a file** (ruled at Sprint 19's Gate C; relational-inventory **row 24**). This step's entire value is the *order* it ran in, and a file cannot carry that: Sprint 18's cold read was written to `operator/staging/sprint-18-cold-read.md`, whose **mtime was the latest of every Gate C artifact** — after the issue, the comment, the plan and the kickoff — because mtime records last modification. That neither proves nor disproves the ordering; **nothing recorded it either way.** A session transcript is inherently ordered and cannot be back-dated, so stating the cold read in the transcript *before* opening anything else makes the ordering evidence instead of assertion. Same rule wherever a gate's validity depends on sequence — Gate A's *read the tests before running the gate*, Gate B's *probe before ranking*.
2. **If the sprint you are about to stage is not the roadmap's top item, write a displacement declaration** in the Gate C staging comment — the same discipline as a declared settled-class exception, since the exception is fine and hiding it is not:
   - what roadmap item is being displaced, and its deferral count;
   - why the displacing item wins *now* (not why it is worth doing — everything on the roadmap is worth doing);
   - whether the displaced item's cost of waiting is bounded or compounding.
3. **Deferral counters.** Every roadmap item carries `deferred N×`; record it in `docs/roadmap.md` §2. Increment it on each displacement. **At 3, deferral stops being an operator judgment call** and becomes a blocking question: either the item is staged next, or it is demoted out of the top slot with a recorded reason. An item cannot sit at #1 indefinitely while never being built — that state means the ranking is wrong, and the ranking should be fixed rather than repeatedly overridden.
4. **External clocks outrank preference.** Mark (⏱ in the roadmap) any item whose cost of waiting is set by something outside the project (adoption, a published schema, a third party's dependency on current behavior). An item with an external clock outranks one without, and its displacement declaration must state what the clock has cost so far. *Retire/yank schema headroom is the live example: publishing has worked since Sprint 8, so every sprint it waits is more entries published against schema v1 that a later change would have to accommodate.*
5. **Carried gaps ride along; they are rarely a whole sprint.** Prefer staging the roadmap item **plus** the carried gap over a pure gap-repair sprint. A gap that is genuinely a prerequisite of the roadmap item is the best case — say so explicitly, because that is the one situation where the gap leading is not a displacement at all.

1. **If the sprint needs a design-doc change** (like Sprint 3's Doc C amendment): apply it to `docs/design/*.md` now (single copy — no mirror to refresh) and cover it explicitly in the Stage 2 approval comment. The agent then reads an already-correct spec at RED.
2. **Draft the milestone issue** (scratchpad file, then `gh issue create --body-file`), following the feature-template shape: Motivation (with "specs of record" and precedence), Scope (in/out, explicit, naming *every* touched settled class), **Acceptance scenarios S1..Sn** (atomic — one behavior, one observable outcome; concrete versions/constraints/bytes; the riskiest work gets the lowest numbers), Architecture impact (docs, classes with directory placement, harness changes or "none", SUnit law obligations), Deferred-collision check. Declare any new class the docs don't name (the `IndexSnapshot` precedent) so the agent never invents one.
3. **Self-review against the closed six-item Stage 1 checklist** (`.github/copilot-instructions.md` §2) and post the Stage 1 + Stage 2 verdicts as an issue comment; create the issue with labels `requirements-approved` + `design-approved`.
4. **Advance the harness (human-only edits):**
   - `.parley/scope`: bump `sprint:`, set `phase: red`, add the `scope-<N>` regex (copy the prior line; add any new `src/<dir>/`). Sprint notes need no entry — `docs/` already covers `docs/sprints/`. Drop scope-7's one-off migration paths (`\.parley_sprint_scope$`, `SPRINT[0-9]+-NOTES\.md$`) from scope-8 onward.
   - `scripts/run-tests.st`: add the new source directory to the file-in list **only if** the sprint introduces one (keep load order: compat, domain, manifest, resolver, ...).
5. **Write `operator/kickoffs/sprint-<NN>.md`** (zero-padded) modeled on the previous one (read it first): read-order with the sprint's spec of record, settled-API boundaries with declared exceptions, scope in/out, RED file list + red-gate expectations (declare any intentional passes-in-red guards), GREEN implementation order (riskiest core surgery first and alone), structural rules, DoD with `wrap-sprint.sh <N> <issue>` and the commit message. No exclude entry is needed — all of `operator/` is excluded wholesale.
6. **Reconcile the operator-local narrative against the tracked roadmap, and say which way it moved.** `operator/master-plan.md` §9 is the narrative half of what `docs/roadmap.md` §2 keeps canonically. It is untracked and operator-local, so **no drift law can ever see it** — which is exactly why it drifted three sprints (15, 16 and 17 all delivered without reaching it) before anyone compared them. It is a **row-18-family pair**: two artifacts each correct alone, wrong with respect to each other, with nothing comparing them. This step is the comparison, and it is deliberately the weak kind of mechanism — a checklist item a reviewer works, not a law that halts — because the tracked/untracked split leaves nothing stronger available. **The tracked roadmap wins every disagreement.** Either amend the plan to match, or record in the Gate C staging comment that the plan is stale and by how many sprints. Silence here is what three sprints of drift looked like.

7. **Commit and mirror:**
   ```
   git add .parley/scope docs/roadmap.md [scripts/run-tests.st] [docs/design/<amended>.md]
   git commit -m "chore(loop): advance scope to Sprint <N> — <name> (red)"
   git push origin main
   ./scripts/sync-loop.sh <new issue>
   ```
8. Hand the user the kickoff prompt for a fresh agent session.

---

## 4. Mid-sprint gates

- **Circuit breaker tripped:** the agent must have halted with the failing law, its attempts, and a question. Rule on the question (against the docs; amend them if the spec is the problem), then — and only then — `./scripts/verify-sprint.sh --reset`. The reset is human-only.
- **Design question on the issue:** answer with a ruling, not options. If the ruling amends architecture, land it in `docs/design/` **and** the decision log at [`docs/design/architecture.md` §8](../design/architecture.md#8-decision-log), in the same commit, so no future sprint re-litigates it. (Precedents: the `Parley.Parley` gateway ruling on issue #3; the decision-pin ruling on issue #4.)
- **Sprint-scope questions** ("is X in scope?"): the milestone issue is the contract; if it's genuinely ambiguous, edit the issue body and say so in a comment.

## 5. Where everything canonical lives

This section used to duplicate a roadmap summary, and it went stale — Sprints 8, 9 and 10 never reached it. Duplicated state is the failure mode this whole reorganization exists to end, so it now points instead of copying.

| Question | Canonical answer | Tracked? |
| --- | --- | --- |
| What ships next, and why that order? | [`docs/roadmap.md`](../roadmap.md) | ✅ |
| Why was this designed this way? | [`docs/design/architecture.md` §8](../design/architecture.md#8-decision-log) | ✅ |
| What does each subsystem specify? | [`docs/design/`](../design/) (Docs A–F) | ✅ |
| What was actually delivered? | [`docs/sprints/`](../sprints/) | ✅ |
| What are the agent's binding rules? | `AGENTS.md`, `.github/copilot-instructions.md` | ✅ |
| How do the human gates run? | this file | ✅ |
| Narrative sprint history, staging notes | `operator/master-plan.md` §9 | ❌ local |
| What each agent session was told | `operator/kickoffs/` | ❌ local |

---

## 6. The release gate — Gate B when the sprint ships a version

Written at the v1.0.0 release (Sprint 22, issue #24), which ran this sequence; it is the
close-out's §2 with a release stapled to the end. **The tag is cut by the operator, never
by the agent, and nothing below starts until §2 steps 1–5 are done** — the wrap inspected,
the settled diffs within bounds, the findings written with the tally and the README moved
in the same edit, and the suite green over the finished tree.

**Standing rule from F38: every close-out edit lands BEFORE the final verify.** A wrap or
close-out that verifies and then writes has a hole the size of what it wrote — the sprints
index drifted exactly there, and S26 caught it at this gate's first run.

1. **Green twice at one commit, both seeds.** Locally: `verify-sprint.sh --observe` green
   on the default seed **and** on a second explicit seed (a randomized suite that only ever
   ran one seed did not run randomized). Then the push (step 4) and CI green on the same
   SHA — two installations of the baseline, not one.
2. **The stranger-walk, from a fresh clone, using only the README.** Mandatory, budgeted,
   never skipped because the laws are green: **every defect this walk has ever found was in
   a repository whose laws were green** (five in Sprint 16, six at its close-out, two
   README gaps at v1.0.0). Clone to an isolated directory — committed state only, exactly
   what the push will publish — and walk Installing, the sixty-second hero, the transcripts,
   and the suite's own self-verification (`verify-sprint.sh --phase green` in the clone). A
   product defect found here is fixed BEFORE the tag, through the ordinary gates; a
   README defect is the operator's close-out edit, re-verified.
3. **The release laws re-confirmed at the exact SHA being tagged**: the `releaseFiles`
   walk, both CHANGELOG laws, the completions byte-identity, the CI one-gate law. They ran
   inside step 1's suite; the point of this step is the SHA — nothing may land between the
   verified commit and the tag. Set the CHANGELOG's release date to the tag's date before
   this, not after.

   **The second release amends a law before it runs.** `testTheHeadingSetEqualsTheReleasedSet`
   hard-codes the released set as `(Array with: Parley version)` — true at v1.0.0, and false
   the moment a second version exists. Declaring the released set is a **staging** ruling for
   the sprint that ships the version, never gate work discovered here with the tag pending.
   (Probed at Sprint 23's Gate C, where the same law ruled the other question: a docs sprint
   moves no version, so all three of the constant, the manifest literal and the CHANGELOG
   stay put.)
4. **The sprint's only push** (F17), preceded by F28's range check:
   `git log origin/main..HEAD --oneline` and confirm **every** commit in the range is meant
   to publish — the held flip, ruling commits, the wrap, the close-out docs. Push, then
   **watch CI to green including the second-seed step before anything else happens.**
5. **Tag the pushed HEAD**: `git tag -a v<X.Y.Z> -m "<message the operator writes>"`, then
   `git push origin v<X.Y.Z>`. **No `Co-Authored-By`, no AI-attribution trailer — in the
   tag message, the Release body, and every commit the release carries.**
6. **The GitHub Release**: title `v<X.Y.Z>`, body = the CHANGELOG's section for this
   version, **verbatim** — one source of the release's words, no trailers, nothing composed
   fresh at the form.
7. **The settings checklist** (decisions.md C-3, run at v1.0.0): repository description =
   the tagline (*Smalltalk packages, resolved by conversation.*); topics `smalltalk`,
   `gnu-smalltalk`, `package-manager`, `dependency-resolver`; confirm the Releases page
   renders the body and the tag.
8. **Roadmap and records**: strike the tag hold the release discharges (§5 at v1.0.0),
   move the delivered item, promote the next-work section to the standing list, fill the
   sprints-index commit cell, reconcile `operator/master-plan.md` §9 and say which way it
   moved. Then the close-out comment on the milestone issue (`--body-file` from
   `operator/staging/sprint-NN/`) and `gh issue close <N> --reason completed`.
