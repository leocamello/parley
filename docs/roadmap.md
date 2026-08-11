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

- **Sprint 19 — the commands stop shouting, and the project remembers where its index is.** Issue #21, staged at Gate C on 2026-08-10 against **876 laws**. **§2 items 3 AND 4, staged together and undisplaced — the ninth consecutive sprint the ranking won on its own merits.** Not a displacement: the two are adjacent, both at deferred 0×, and nothing below them is jumped. They are paired because **Gate C's probes shrank both** — `exec` was carved out of item 3 (its GC message is on **stderr**, from the image load Parley composes, and its plumbing shares one stream with the author's program, so separating them is the deferred buffering mechanism by name), and item 4's installation half was found **already delivered** in Sprint 17, leaving only the configuration half. `Publisher` and `Installer` gain a stdout redirect on their composed plumbing lines ([decision 63](design/architecture.md#8-decision-log)); `Parley.Configuration` (`src/exec/`) reads a project-root `parley.config.st` in the settled micro-format under `#'parley-config' 1`, **not** under `.parley/` because that directory is regenerable state, and **an explicit flag always wins** ([decisions 64](design/architecture.md#8-decision-log) and [65](design/architecture.md#8-decision-log)). The **Sprint 18 carried gap rides along**: a recovered anchor means the load failed whatever the file recorded, closing a fail-wrong where a `Package.st` with a raising `define:` exited `0` ([decision 76](design/architecture.md#8-decision-log)). **The `exec` carve-out was re-ruled pre-RED, 2026-08-11** ([decision 77](design/architecture.md#8-decision-log)): the toolchain's documented `-g` (`--no-gc-message`) suppresses the GC chatter at the source — probed: stderr drops to zero bytes, both streams and the exit code untouched — so `exec` goes quiet by flag, the fragment is no longer kept, and the carve-out's two-route ground is recorded as the enumeration it was.

### Recently delivered

- **Sprint 18 — writing your first `Package.st`: the authoring boundary speaks Parley's voice.** ✅ **DELIVERED 2026-08-10**, issue #20 closed, commit `c9c72e9`, **847 → 876 laws**. Staged at Gate C on 2026-08-09 against **847 laws**. **§2 item 2, staged undisplaced — the eighth consecutive sprint the ranking won on its own merits**, and item 2 of the seven holding the v1.0 tag. The authoring boundary is the only place in the tool where text reaches the terminal that Parley did not write: a malformed manifest prints an 11-line kernel backtrace carrying Parley's own source paths, and the authoring diagnoses are the only family that never names the file. `Parley.ManifestCapture` (`src/manifest/`) rebinds `Transcript` around **a block its caller supplies** and performs no file I/O of its own — so `ManifestFile` keeps the `FileStream fileIn:` decision 73 deliberately left unwrapped, keeps its seat in the decision-60 census, and **the census does not grow** ([decision 61](design/architecture.md#8-decision-log)). The capture is **evidence, not output**: discarded on success, mined for its file-and-line anchor on failure, never echoed ([decision 62](design/architecture.md#8-decision-log)). The **F13 carried gap rides along** as a genuine member of the same defect class — a diagnosis asserting a cause it never checked — with the state root's law driving the whole *shape*-space of a path rather than two permission states ([decision 74](design/architecture.md#8-decision-log)).

### Recently delivered

- **Sprint 17 — the boundary table: every diagnosis earns its predicate.** ⏱ Issue #19, commit `bba2c79`, **847 laws**. This list's top item, staged and delivered **undisplaced** — the **seventh** consecutive sprint the ranking won on its own merits, and **item 1 of the seven holding the v1.0 tag**. `Parley.PathGuard` (`src/compat/`) is now the single site in Parley performing file I/O: it prechecks *and* translates, so the rule is total rather than enumerated, and all eight census classes route through it. The seven probed states are closed — five write-side refusals that answered `internal error: … this is a defect in Parley` at exit `70` now answer one line naming the path and a checked remedy at exit `1`; the two read boundaries decision 56 never reached carry their predicates; and the shipped wrapper resolves its symlink chain, honours a pre-set `PARLEY_ROOT`, and exits `70` naming an absent main script instead of reporting total failure as success at exit `0`. The completeness law is a **prohibition** — nothing outside `PathGuard` performs direct `File` I/O — which makes relational-inventory row 21 mechanical for the first time. Ruled at staging: [decision 60](design/architecture.md#8-decision-log) (a prohibition's exemption list is a census, not the motivating set) and [66](design/architecture.md#8-decision-log) (the wrapper resolves its own location). Ruled at the RED review: [decision 72](design/architecture.md#8-decision-log) — the state root answers `ExecutionError` as a **carrier**, not an attribution. Ruled mid-GREEN on a halt-and-ask: [decision 73](design/architecture.md#8-decision-log) — a structural diagnosis law governs the row's **sentence**, and what may prefix it is bounded by another law rather than by silence. Close-out gap: `ensureDirectory:` conflates an unwritable parent with a path of the wrong type, producing a *false* claim about a writable directory — **carried gap, unscheduled** (method finding **F13**).

- **Sprint 16 — v1.0 readiness: the flows a first user actually walks.** Issue #18, commit `96ad6b2`, **795 laws**. This list's top item, staged and delivered undisplaced — the **sixth** consecutive sprint the ranking won on its own merits. Five defects found by walking the shipped binary rather than reading this file, none of them a missing feature: `exec` now refuses a script that is not a regular readable file before spawning anything (exit `1`, naming it) while decision 45's pass-through stands unchanged; a `parley.lock` that cannot be read as a file is refused by **every** verb including `resolve`, naming the path; `--help`/`-h`/`help` answer the usage lines at exit `0` beside `--version`; the held-pins line is **earned** — both verbs re-resolve against the unheld snapshot and emit it only if that succeeds; and no usage error creates project state. Ruled at staging: [decision 56](design/architecture.md#8-decision-log) (readability before shape), [57](design/architecture.md#8-decision-log) (a question is not an error; `createStateDirectories` runs only once a verb will run) and [58](design/architecture.md#8-decision-log) (a remedy line is asserted only when checked). Ruled at RED: the lock readability repair is **not** `parley update` — the corrupt-lock repair is true by construction and a directory-shaped lock breaks the construction — and the usage determination lives in `CLI` as one predicate `run:` itself consumes. Ruled mid-sprint: decision 56's **third** application, `ManifestFile`, a **conformance gap** — Doc E §4.1 step 0 promised a readability check from Sprint 8 and the code never made it. Decisions [52](design/architecture.md#8-decision-log) and [55](design/architecture.md#8-decision-log) both **cleared**. Close-out ruling: [decision 59](design/architecture.md#8-decision-log) — the write side owes the same diagnosis, and a general rule owes its whole domain (method finding **F12**).

- **Sprint 15 — publishing into a sparse index, `--version`, and the v1.0 line.** Issue #17, commit `87a9e34`, **756 laws**. This list's top item, staged and delivered undisplaced — the **fifth** consecutive sprint the ranking won on its own merits, and **the last item on the v1.0 line** (§5). Sprint 14 shipped the sparse-index client; this shipped the producer, closing the gap between a package manager and an ecosystem: `publish <dest> --layout sparse` writes the per-package layout `SparseIndexSource` reads, and S16 proves the loop end to end and offline — author A publishes a real toolchain-built `.star`, author B resolves, installs and `exec`s it through `--index` over `file://`. Ruled at staging: [§8 decision 53](design/architecture.md#8-decision-log) — a destination's layout is **stated, never inferred**, because an empty destination is the commonest case and carries no evidence to read; a sparse publish is atomic and writes the listing **last**, so the producer cannot manufacture the index defect its own client diagnoses (Doc F §7.5). The layout is a **parameter of one pipeline** — `Publisher class >> flatLayout`/`sparseLayout` answer three-selector specs and the Publisher never branches — so `flat` output stays byte-identical to Sprint 7's. Sprint 14's [decision 52](design/architecture.md#8-decision-log) gap rode along and is **cleared**. Close-out rulings: [decision 54](design/architecture.md#8-decision-log) (the prebuilt image deferred on its measurements — the blocker is silent staleness, not speed) and [decision 55](design/architecture.md#8-decision-log) (exit `70` is honest about failure and imprecise about blame).

- **Sprint 14 — the sparse-index client: fetch what a resolution can reach, and nothing else.** Issue #16, commit `d54b490`, **709 laws**. This list's top item, staged and delivered undisplaced — the **fourth** consecutive sprint the ranking won on its own merits, and the v1.0 distribution answer (§5). `Parley.SparseIndexSource` serves per-package metadata over a curl process seam, so the whole source is provable offline against a `file://` tree and hosting is later a deployment rather than a redesign. Its stated trigger was **the ruling, not the calendar**, and both rulings fired before the code: [§8 decision 50](design/architecture.md#8-decision-log) at staging — the one I/O moment may be a **closure, never a callback**, so `snapshot` walks the seeds to fixpoint and answers one complete immutable snapshot, leaving `Resolver`, `IndexSnapshot` and both strategies untouched (the fourth put-it-in-the-source application) — and [§8 decision 51](design/architecture.md#8-decision-log) at RED, when the agent halted rather than invent: the seeds are **values supplied by the `CLI`** through `seededWith:`, because the source must never read `Package.st` or `parley.lock`. Wire efficiency is proved by **counting recorded curl command lines**, never inferred, and S15 is the one scenario a listing-caching implementation fails after passing every other. Close-out ruling: [decision 52](design/architecture.md#8-decision-log) — a best-effort read may swallow only the errors whose diagnosis it defers to.

- **Sprint 13 — `parley add <pkg> <constraint>`: the tool edits the manifest, and never re-renders it.** Issue #15, commit `d9b6fad`, **662 laws**. This list's top item, staged and delivered undisplaced — the third consecutive sprint the ranking won on its own merits. Its stated trigger was **the ruling, not the calendar**, and the ruling fired before staging: [§8 decision 49](design/architecture.md#8-decision-log) — Parley never re-renders a file it did not write. `Parley.ManifestEditor` inserts one clause into a recognized cascade and preserves every other byte; the edit is verified by re-loading through the settled `ManifestFile load:`; an unfamiliar shape is refused with the exact text to paste and the file untouched. Adding holds the existing pins (`holding:` in its **third** application, no resolver change again), and the verb is atomic. The byte-preservation laws compare bytes and lines against hand-written oracles rather than computed ones, because an oracle produced by the same splice cannot fail when the splice is wrong — and S3 (comments, blank line and the author's indentation survive) is the scenario a `ManifestBuilder` round-trip passes S1, S2 and S4 and then fails. Sprint 12's deleted-held-pin gap rode along as S13 and is **cleared**. Close-out ruling: [decision 49 narrowed](design/architecture.md#8-decision-log) — atomicity is the manifest and the lock, not the store.

- **Sprint 12 — selective `parley update <pkg>`: move one, hold the rest.** Issue #14, commit `a899ca8`, **612 laws**. This list's top item, staged and delivered undisplaced. Holding lives in the snapshot ([§8 decision 46](design/architecture.md#8-decision-log)), so `Resolver`, `BacktrackingStrategy` and `ConstraintLedger` are neither modified nor entered differently — a selective update is a normal resolution of a smaller world, and a future `PubGrubStrategy` inherits it for free. The byte-identity of the pins that did **not** move is asserted tuple by tuple, and the S2/S8/S10 contrast halves run plain `update` against identical fixtures so that no proof can pass on a fixture where the other outcome was impossible. Close-out rulings: [decision 47](design/architecture.md#8-decision-log) (narrowing can only offer what the snapshot can describe — ruled at the red review, after the literal reading was found to let `update` write a lock with an empty digest) and [decision 48](design/architecture.md#8-decision-log) (already-newest narrows the report, never the contract).

- **Sprint 11 — the inspection verbs, and the debt they let us clear.** Issue #13, commit `1a8a251`, **585 laws**. `why` / `tree` / `check` (this list's top item, built as ranked), plus the three carried gaps the sprint's own work made cheap: `check` is the named consumer that closed the unread `retirementReasonFor:version:` (§8 decision 37 discharged); hex-digest validation was the third caller that triggered the `isLockString:` dedup into `Parley.SchemaShape`; and the drift law's textual anchor was hardened with its claim bounded in writing. The graph verbs walk the lock plus the snapshot and never enter the resolver ([§8 decision 40](design/architecture.md#8-decision-log)), proved by a trap double on the real path. Close-out rulings: [decision 44](design/architecture.md#8-decision-log) (batch for a project, first-defect for a file).
- **Sprint 10 — retirement: the third schema, and the boundary that guards it.** ⏱ Issue #12, commit `c15c2c5`, **539 laws**. Retire/yank schema headroom (`#'parley-retired' 1` index-level record, Doc B §5.5; snapshot filtering, Doc C §2.1; scan tag dispatch, Doc F §4.2), with decision 35's lock body/value validation and the deserialization-boundary law riding along **as a prerequisite** — a retirement record is a third sender of `IndexEntryReader readFrom:`, and adding a new operator-editable boundary while the boundary reasoning is unfixed would ship the same defect a third time. Ruled at staging: [§8 decision 37](design/architecture.md#8-decision-log).

### Next, in order

**The v1.0 line was re-ranked on 2026-08-07.** Sprint 15 declared it complete against a
definition that counted capabilities and never counted the experience of using them; three
consecutive close-outs then found instances of that omission and ranked each as a one-off
defect. The list is what was wrong. **Items 1–6 are that category, enumerated once, in the
order a user meets them; item 7 is the machinery that cuts the tag.** Each is now an ordinary
roadmap item that wins on its own merits rather than a displacement.

**Item 1 was delivered in Sprint 17. The numbering below is deliberately NOT compacted** — §8 decision 66 and several issue bodies cite these items by number, and renumbering would silently stale every one of those references (relational-inventory row 22, which this project has now been bitten by eight times). The *order* is the rank; the *numbers* are identifiers.
2. ~~**Writing your first `Package.st`**~~ — ✅ **DELIVERED in Sprint 18** (issue #20, commit
   `c9c72e9`, **876 laws**), *deferred 0×, staged undisplaced.* The authoring boundary no longer
   lets any text reach the terminal that Parley did not write or does not document keeping:
   probed through the shipped binary at Gate B across nine inputs, both streams captured
   separately. §8 decisions 61, 62, **74** and **75**. **The numbering is not compacted** — see
   the note above.
3. **Running your first command** — *deferred 0×; **in flight**, Sprint 19 with item 4 (issue #21).* Every successful verb prints more foreign
   text than its own: `publish` emits five `mkdir`/`ln`/`rm`/`cd`/`zip` lines per one of its
   own, `add` and `install` emit an `/usr/bin/install -c` line, `exec` emits a GC message.
   **Re-probed at Sprint 19's Gate C, 2026-08-10, and the earlier note was wrong.** It read
   *"all of it is on stdout and stderr is clean, so silencing is a redirect"*; measured, the
   `publish` and `install` chatter is on **stdout** but `exec`'s GC message is on **stderr**,
   emitted by the `gst -i -I <target>/parley.im` image load Parley composes
   (`ExecutionScope.st:77`) — `gst -f <script>` alone writes nothing to stderr, so it is
   plumbing rather than the user's program. **That falsifies the premise the item was scoped
   on**, and splits it: `publish`/`install` spawn plumbing children that are *not* the user's
   program, so discarding their stdout is the ruled-in redirect; `exec` spawns **one** child
   that is both the plumbing and the user's program on **one** stream, so suppressing the GC
   message means suppressing the script's own stderr — which is [decision 45](design/architecture.md#8-decision-log)'s
   territory and the deferred *output capture* row's actual subject. §8 decision 63.
   **The `exec` half was re-ruled pre-RED, 2026-08-11** ([decision 77](design/architecture.md#8-decision-log)):
   the two-route reading above missed the toolchain's own `-g` (`--no-gc-message`), which
   suppresses the message at the source, touching neither stream — probed on the exact
   composed shape. `exec` goes quiet by flag; nothing crosses the output-capture deferral.
4. **Getting Parley, and telling it where your index is** — *deferred 0×; **in flight**, Sprint
   19 with item 3 (issue #21).* **Re-probed at Sprint 19's Gate C, 2026-08-10, and the earlier
   note was wrong.** It read *"the README has no installation section at all"*; the
   `## Installing` section has existed since Sprint 17, whose §8 decision 66 ruled and fixed
   the broken symlink install that exited `0` on total failure — a filesystem state answering
   the wrong exit code. **What remains is the configuration half only:** there is no
   configuration of any kind, so `--source <dir>` is retyped on every command forever; Sprint
   19 extends the existing `## Installing` section with the configuration route rather than
   rewriting it. §8 decisions 64, 65.
5. **The verbs that close the grammar** — *deferred 0×.* `remove`, `search`, `info`,
   `outdated`. All four are present in all seven of the package managers this project
   benchmarks against; `remove` is the declared other half of `add` and its deferral trigger
   has fired (§3). §8 decision 67.
6. **Dependencies you are developing** — *deferred 0×.* Path dependencies and dev-only
   dependencies. In an ecosystem with no published packages, two directories side by side is
   *the* workflow, and today it costs a `parley publish` per edit. Both are **root-manifest-only
   vocabulary**, so the index entry schema does not move. §8 decisions 68, 69.
7. **The release** — *deferred 0×.* CHANGELOG, the declared release manifest with a law over
   it, shell completions, the CI drift law, and the tag. §8 decisions 70, 71.

### Harness, not a sprint

Numbered separately because it is **not** a sprint and must not be ranked as one: the harness —
`scripts/verify-sprint.sh`, `.githooks/`, `wrap-sprint.sh` — has never been sprint scope, and this
lands as `chore(ci):` on the `chore(loop):` precedent. It is listed here because the item was
nearly lost by having no slot at all: it was specified only in an operator-local plan, and §6
item 1 below already reasons about *CI's toolchain source* as future work, which presumes a CI
that nothing scheduled building. **A forward reference to an unscheduled thing is the same
two-artifacts-disagreeing shape [§8 decision 60](design/architecture.md#8-decision-log) was ruled
about**, so the fix is a slot rather than a memory.

- **CI runs the one gate** — ⏱ *not started; **honoured at Sprint 18's Gate C**: it lands as one
  `chore(ci):` commit immediately **before** the scope advance, so Sprint 18's first push is
  observed.* Ruled rather than re-dated, because the commitment was to a date and re-dating a
  written commitment is what §8 decision 60 was ruled about. **It is not folded into the sprint:**
  the harness has never been sprint scope, and admitting it would make `verify-sprint.sh`'s own
  scope sentinel police the file that runs it. `scripts/verify-sprint.sh` is
  the single verification entry point and it runs on one laptop. This project's central public
  claim is *847 axiomatic laws, green, seeded, reproducible*, and today nothing lets a reader
  check it — the one thing the method refuses to do anywhere else. Ubuntu 22.04 packages
  `gnu-smalltalk` **3.2.5-1.3ubuntu1**, the exact baseline (probed 2026-08-06; dropped from Ubuntu
  24.04+ and Debian bookworm+), so the whole of it is `runs-on: ubuntu-22.04` plus an apt line,
  an assertion that `gst --version` reports 3.2.5, `verify-sprint.sh --phase green`, and a second
  step on an explicit non-default seed — a suite that only ever runs one seed is not a randomized
  suite. **CI observes the loop and never participates in it:** it does not run `wrap-sprint.sh`,
  edit `.parley/scope`, or push. **`--phase green` on `push` to `main` is safe across a red phase,
  and that is a checked fact rather than a hope** (verified at Sprint 18's Gate C against
  `62aee7a`): the red-phase test files are never committed — the phase-flip commit carries only
  `.parley/scope` and any operator test amendments, and the sprint's tests reach `main` for the
  first time inside the green wrap commit. So every state that exists on `main` is green, which is
  exactly the claim CI is being asked to check. **The workflow therefore passes `--phase green`
  explicitly and never reads `phase:` from `.parley/scope`** — a workflow that trusted the scope
  file would go green by agreeing that a red phase is allowed to fail. **The first run is itself a probe** — whether the *distro* 3.2.5
  passes the suite the `/usr/local` source build passes is an open question, and a difference
  would be a portability defect found before the tag rather than after, which is most of CI's
  value. The drift law binding the workflow to `verify-sprint.sh` is **item 7's** (§8 decision
  71): the workflow exists first, and the law that stops it drifting lands with the rest of the
  release machinery.

### Standing, not competing

- **`PubGrubStrategy` + prereleases** — *deferred 0×; **trigger-gated**.* Unchanged.
- **Entry signing** — *deferred 0×; **2.0 axis**.* Unchanged.

### Carried gaps — ranked, unscheduled (runbook §2.4)

Recorded at Gate B — or, for the first item below, at an operator walkthrough of the shipped binary — and scheduled at Gate C against the list above, never at the moment of discovery. Ranked most severe first.

- ~~**`ensureDirectory:` makes a false claim about a writable directory.**~~ ✅ **LANDED in Sprint 18** (§8 decision 74, commit `c9c72e9`). The split lives in `ensureDirectory:` itself, so it is **total over all four call sites** — `.parley`, `.parley/packages`, `.parley/git`, `.parley/index` — and the fourth was probed at Gate B though no scenario drives it. **Method finding F13's portable half is only one-twelfth applied:** the state-root row is now driven through a path's four *shapes*, and the other eleven boundary rows are still driven through two permission bits (inventory row 21, footnote [m]). *Recorded at the Sprint 17 close-out (method finding **F13**); scheduled into Sprint 18 at Gate C, 2026-08-09.* A regular file at `<workdir>/.parley` — or at `<workdir>/.parley/packages` with `.parley` writable — is refused with `/…/f1: could not be written - check its permissions and try again` while `test -w /…/f1` answers writable. `CommandLine>>ensureDirectory:` names the **parent** by a deliberate and documented rule, and that rule conflates two states: *the parent cannot be written*, and *the path exists and is not a directory*. In the second the sentence is **false** and the remedy cannot work, which is what [decision 58](design/architecture.md#8-decision-log) forbids outright. **Severity: soundness-class**, and probed rather than reasoned (the four commands are in the close-out). Not a wrong exit code — both states answer exit `1`, so Sprint 17's headline criterion holds and no law failed. **Consumer constraint until it lands:** an operator with a stray file at either path is told to check permissions that are already correct and given no route to the real fix.

  **Why it rides along with Sprint 18 rather than waiting** (Gate C, and this is a ranking decision recorded rather than a convenience): it is not a prerequisite — the authoring boundary reads and parses where this one creates a directory — but it is a live member of **the same defect class Sprint 18 exists to abolish**, a diagnosis asserting a cause it never checked. The fix is small and the correct sentence already exists one row over. And the tag is held on this list, so deferring it leaves a **false** sentence in software that is about to be released, which is a compounding rather than a bounded cost of waiting. It carries [decision 74](design/architecture.md#8-decision-log): the state root's law drives the whole *shape*-space of a path, which is F13's rule made forced rather than recorded.

- **`parley exec` reports the child's exit code, and 3.2.5 makes that a weaker promise than it sounds.** ✅ *Ruled at Sprint 12 staging — closed as a bounded limitation, not carried as a defect ([§8 decision 45](design/architecture.md#8-decision-log)).* GNU Smalltalk 3.2.5 continues past an unhandled error at the top level of a filed-in script and exits `0`, so `parley exec broken.st` prints the child's backtrace and reports success. Whether a fix existed had been estimated, never probed. **Probed at staging: it does not.** A handler installed around `FileStream fileIn:` never fires — a filed-in statement's doit context is parentless, the same mechanic decision 34 found for authoring — and `Behavior>>evaluate:` fails identically (probed at Sprint 9); there is no `SystemExceptions.UnhandledError` on this toolchain. What is left is capturing the child's output and pattern-matching a backtrace, which is heuristic and would end the live streaming that makes `exec` usable.

  **Consumer constraint (documented in the README, unchanged):** a script whose success matters to CI must end with an explicit `ObjectMemory quit:` — verified to propagate in both directions. `parley exec` alone is not a CI pass/fail signal.

  Reopens only if output capture arrives for another reason. Kept visible because the constraint is live, not because the item is queued.
- **The boundary drift law sees only textually spelled senders** (§8 decisions 38 corrected and 43). Hardened in Sprint 11: the walk normalizes whitespace, so a send split across lines is still a send. What stays invisible is a send assembled by `perform:` or split by an interleaved comment, and **there is no reflective alternative on 3.2.5** — probed at Sprint 11 staging: `whichSelectorsReferTo:` searches literals rather than sends and finds none of the real senders; `allCallsOn:` does not exist. *Severity: low.* **Consumer constraint:** the law proves every *textually spelled* sender is declared, not every sender — and that claim is now written into the law itself. Not a gap awaiting a fix; a bounded claim awaiting a toolchain that can do better.
- **`check` requires `--source`**, because its retirement leg and both graphs' non-root edges need a snapshot. A source-less `check` (lock validity + `PinVerification` only) would be a weaker verb wearing the same name, so Sprint 11 left it unbuilt rather than half-built. The trigger is an operator wanting a lock-only check in a context with no index reachable — which has not happened. *Severity: none. No consumer constraint.*

### Recently cleared

- ~~**A conflict under held pins does not say whether holding is the reason**~~ — cleared in Sprint 16 (S12–S14), at the trigger the Sprint 13 close-out named: *the next sprint that touches the holding path*. **The ranking that came with it was wrong, and that is the more useful record.** It was ranked *"truthful but incomplete"*; it was not truthful, because a sentence naming a cause asserts that cause, and the commonest way to reach it is a typo'd package name where `parley update` cannot help. Fixed exactly as estimated — re-resolve against the unheld snapshot and emit the line only if that succeeds ([decision 58](design/architecture.md#8-decision-log)) — with the over-narrowing twin on **both** verbs so the shared sentence cannot be deleted instead of earned.
- ~~**Exit `70` is honest about failure and imprecise about blame**~~ ([decision 55](design/architecture.md#8-decision-log)) — cleared in Sprint 16 (S4–S7), at the trigger the Sprint 15 close-out named: *the next sprint that touches the §4.1 lock boundary*. **Ranked "low severity" without probing the output — F11's failure mode, a second time in the same decision's life.** The shipped wording put a kernel integer on screen under a sentence claiming a defect in Parley and never named the file. Now every lock-reading verb, including `resolve`, answers one `LockError` naming the path. The repair line was re-ruled at the RED review: **not** `parley update`, whose write cannot succeed against a directory either.
- ~~**A seed-gathering failure would blame the package, silently**~~ (§8 decision 52) — cleared in Sprint 15 (S14), at the trigger the Sprint 14 close-out named: the last v1.0 sprint, after which a latent wrong-blame diagnosis would be in released software. The fix was exactly as estimated — two identifiers, `on: Error` becoming `on: ManifestError` and `on: LockError`, plus one law. **The ranking that came with it was wrong, and that is the more useful record.** It was ranked *"latent rather than live — an operator cannot currently reach it"*; it was reachable one `mkdir` away, because `pinnedResolution` guards only the two reader errors while `File>>contents` on a **directory** signals a kernel `SystemExceptions.WrongClass` straight past them. On the pre-sprint tree that made `resolve --index` answer a conflict blaming the package. The reachability claim had been reasoned, never probed — recorded as method finding **F11**, with a runbook change (§2.4) requiring a latent ranking to name its falsifying probe and run it.
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
| A `RegistrySource` that *is* a renamed `DirectorySource` | The original decision-27 reason, and it still holds: a source with no protocol of its own earns nothing. What is **no longer** deferred is the sparse-index **client**, which has a protocol, is testable offline, and shipped as the sparse-index client (§5, Sprint 14) | §5 |
| Prerelease versions | Smallest well-defined semver surface for MVP; rides with `PubGrubStrategy` when that lands | §8 decision 8 |
| Backjumping | Data supports it; the payoff belongs to `PubGrubStrategy`, not the backtracking loop | §8 decision 14 |
| `PubGrubStrategy` | Trigger-gated on graph size or observed slowness | §2 above |
| `parley retire` verb | Retirement records are authored by the index owner; a verb is ergonomics | Sprint 10 scope |
| Retirement **reporting** on `install` | Requires the index on the fast path, which the settled no-snapshot law forbids; belongs to `parley check` | §8 decision 37 |
| Un-retiring; package-level (vs release-level) retirement | Retirement is additive and monotonic in MVP | Sprint 10 scope |
| Output capture; any shell-quoting layer | **Split, 2026-08-07** — the row deferred one mechanism and was read as forbidding a different one. *Output capture* — buffering a child's stream into the image — stays deferred, reason unchanged: the child streams to Parley's own stdout/stderr. *Discarding* a plumbing child's stdout by redirect is **ruled in**: it buffers nothing, touches no stderr, and interpolates no user text, so this row's stated reason never reached it. *Shell quoting* stays deferred — Parley still composes command lines from paths it controls | Doc E §1; §8 decision 63; *running your first command* (§2) |
| A prebuilt image | Per-invocation file-in is the honest MVP cost; deferred tooling polish. **Confirmed 2026-08-07 with fresh evidence**, not merely carried: re-probed at `--version` **47 ms** and `init` **55 ms** end to end, so decision 54's measurement-based deferral stands and is stronger than when it was made. None of its three triggers fires | Doc E §4.3, §8 decision 54 |
| Pruning the `--git` cache | No verb removes checkouts; one directory per distinct repo location | Sprint 9 notes |
| **Changing** an existing constraint | **Narrowed 2026-08-07 to this half alone.** `parley remove <pkg>` leaves this row: its stated trigger — *`add`'s recognizer surviving a sprint of real use* — fired four sprints ago, and it is *the verbs that close the grammar* (§2). **In-place replacement stays deferred, same reason:** it is an *edit* wanting decision 49's recognize-or-refuse ruling applied to overwriting, with its own refusal surface, and nothing is silently wrong meanwhile because `add` refuses a different constraint rather than overwriting it. New trigger: the first user who reports that refusal as a blocker | Sprint 13 scope, §8 decision 49; §6 |
| Batching lock problems | One file, one repair, one problem — deliberately unlike the scan, and unlike `check`, which batches because it reports on a project rather than a file | §8 decision 44 |
| Color / ANSI output | The diagnosis set is pinned **byte-for-byte** by law across 36 line literals and 111 fixture methods. Adding ANSI means re-pinning every one of them in the same sprint that changes their meaning — the largest possible surface on which to make an invisible mistake — and v1.0's promise is that the wording is settled. It is also a `--color` tri-state (`auto`/`always`/`never`) plus TTY detection, which 3.2.5 does not offer natively. Trigger: the fixture set surviving one release unchanged | §6 |
| `--json` / machine-readable output | Structured output serves consumers that do not exist yet: there is no editor plugin, no CI action and no dashboard reading Parley. Building it now would pin an output schema against zero feedback. **Note the in-voice alternative when it lands:** Parley already owns a byte-stable literal format and a reader for it, so `#'parley-report' 1` may serve better than JSON and costs almost nothing. Trigger: the first tool that wants to consume Parley's output | §6 |
| `--dry-run` | `add` and `remove` are already atomic and already refuse before writing, so the flag would today mean "print what a successful command would print". Trigger: the first verb whose effect is not trivially reversible — cache pruning is the likely one | the 2026-08-07 re-ranking |
| Optional dependencies / feature flags | Unlike `path:` and `devDependency:`, these **must** appear in the index entry, so they are a schema change with a migration. Every benchmarked manager that has them added them after 1.0. Trigger: a package that genuinely cannot be expressed without them | §6, §8 decision 69 |
| Workspaces / multi-package repositories | Real machinery — a workspace manifest, shared lock, member resolution — and nobody has three Parley packages in one repository yet. Trigger: a repository with three or more Parley packages | §6 |
| `parley config` verb | The file is a small literal artifact edited by hand; a verb is ergonomics. Same reasoning as `parley retire`. Trigger: users mis-editing the file | §6; *getting Parley, and telling it where your index is* (§2) |
| `parley test` verb | `parley exec` already runs a script in the resolved environment; a `test` verb is a naming convention over it. Trigger: a conventional test path emerging in real packages | §6 |
| `parley cache` verb | Rides with the already-deferred `--git` cache pruning. Trigger: the same as pruning | §6 |
| Distro packaging, Homebrew, man pages, a documentation site | Distribution for a tool whose only installation route was broken until Sprint 17. Do the route first, measure demand second. Trigger: the first external contributor or packaging request | §6 |
| Publishing Parley itself into a Parley index | Charming, and it proves nothing the test suite does not already prove end to end. No trigger | the 2026-08-07 re-ranking |

---

## 4. Phase map (where the roadmap sits)

Phases 1–5 are complete: the v1.0 line closed with Sprint 15 (§5). See [`design/architecture.md`](design/architecture.md) §3–§5.5 for what each phase means and [`sprints/`](sprints/) for what each sprint delivered.

| Phase | Content | State |
| --- | --- | --- |
| 1 | The algebraic domain model | ✅ Sprint 0 |
| 2 | The pure resolution engine | ✅ Sprints 2–3 |
| 3 | The orchestration bridge — installer, execution scope, CLI | ✅ Sprints 4–6 |
| 4 | The ecosystem — publish, sources, the shipped binary, the blame boundaries, the inspection verbs | ✅ Sprints 7–11 |
| 5 | The release — the editing verbs, the sparse-index client, release hardening | ✅ Sprints 12–15, the v1.0 line (§5) |
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
| 14 | The sparse-index client | The list's top item when it was staged (§2). Provable with no network and no server. ✅ Delivered, issue #16, commit `d54b490`. |
| 15 | Release hardening | The list's top item when it was staged (§2): `--version`, publishing to a shared index, docs for a stranger, and the prebuilt-image call taken on measurements. ✅ Delivered, issue #17, commit `87a9e34`. |

| 16 | v1.0 readiness | Not on the original line. Added 2026-08-05 from a hands-on audit of the shipped binary: five first-session defects, every one the tool disagreeing with itself. ✅ Delivered, issue #18, commit `96ad6b2`. |
| 17 | The boundary table | ⏱ Item 1 of seven; the hold is on the list (§2). Added 2026-08-06 at the Sprint 16 close-out from six probed states ([§8 decision 59](design/architecture.md#8-decision-log), finding **F12**). ✅ Delivered, issue #19, commit `bba2c79`. |
| 18 | Writing your first `Package.st` | ⏱ The authoring boundary — the only foreign text in the tool. ✅ Delivered, issue #20, commit `c9c72e9`. |
| 19 | Running your first command; getting Parley, configuring it | ⏱ **Items 3 AND 4, paired at Gate C 2026-08-10** (issue #21, in flight): the Gate C probes shrank both — `exec` carved out of item 3 (carve-out re-ruled to `-g` pre-RED, decision 77), item 4's installation half found already delivered in Sprint 17 — so the pair holds one sprint. §8 decisions 63, 64, 65, 76, 77. |
| 20 | The verbs that close the grammar | Parity: all four exist in all seven benchmarked managers. |
| 21 | Dependencies you are developing | Root-only vocabulary; cheapest **before** entries exist. |
| 22 | The release | CHANGELOG, release manifest, completions, **the tag**. |

*(Rows 20–22 renumbered 2026-08-11, at the Sprint 19 document review: pairing items 3 and 4
into Sprint 19 shifted every planned row below it, and the previous mapping ran to Sprint 23.
These sprint numbers are predictions, not identifiers — §2's item numbers are the identifiers,
and those are never compacted.)*

**🔒 THE v1.0 TAG IS HELD UNTIL §2 ITEM 7 — THE RELEASE — LANDS** (Sprint 22 on the current
mapping). Re-keyed 2026-08-11 from *"until Sprint 23 lands"*: the hold is keyed to the item
rather than to a sprint number, because the mapping has already moved once — the pairing of
items 3 and 4 into Sprint 19 shifted every planned row — and a hold spelled as a sprint
number goes stale by citation the moment it does. Re-ruled 2026-08-07, replacing the
Sprint-16 hold on Sprint 17 alone. That hold was correct about its own item and wrong about
the count: it held the tag for one instance of a category whose other six members were not on
this list. §2 items 1–7 are that category enumerated. The feature line completed at Sprint 15
and nothing below adds an axis; what is being finished is the difference between a tool that
is correct and a tool that is usable by someone who did not write it.

**The feature line is complete.** All four of its sprints landed undisplaced, in the order ruled at the v1.0 staging on 2026-08-02. What v1.0 claims is what §5 opened with and nothing more: the complete, honest, local-and-git package manager whose client already speaks the registry protocol — proved offline, over `file://`, with a package published by one working directory and consumed by another through a layout neither downloads in full. Hosting remains a deployment, not a redesign.

### What was ruled *out* of the line, and why

- **`parley exec`'s exit-code truthfulness** — closed as a bounded limitation at Sprint 12 staging (§8 decision 45), not carried and not scheduled. Probed rather than estimated: no handler placement works on 3.2.5, `-f` is inert, and the only remaining mechanism is pattern-matching the child's backtrace out of a captured stream, which would buy "no failing outcome exits `0`" by breaking "never claim more than you can prove". `exec` is a **runner, not a test harness**, and v1.0 says so where the operator meets it.
- **Entry signing** — §2, *standing, not competing*. Checksum pinning plus transport trust is what the comparable registries shipped their own 1.0 on.
- **`PubGrubStrategy` and prereleases** — §2, *standing, not competing*, trigger-gated on real graph sizes. A resolver swap is not a release blocker; it is a performance answer waiting for a performance question.

### The 2.0 axis

Hosting, entry signing, and whatever governance a shared index needs. Reached from a v1.0 whose entry format is already canonical and signable, and whose client already fetches per-package metadata over a real transport — which is the whole point of building the road before the destination.

---

## 6. The 1.x line — what comes after the tag

**Distinct from §5's 2.0 axis.** The 2.0 axis is *hosting, signing, governance* — an operated
service and a from-scratch crypto implementation. This section is the ordinary next work: not
deferred for a reason, merely not in v1.0. Each item carries a **trigger, never a date**
(finding F9), and none of them competes for a slot until its trigger fires.

1. **⏱ CI's toolchain source.** Ubuntu 22.04 (`gnu-smalltalk` 3.2.5-1.3ubuntu1) is the only
   distro release still packaging the baseline — dropped from Ubuntu 24.04+ and Debian bookworm+.
   When GitHub retires the `ubuntu-22.04` runner label, CI needs a pinned container image on
   `ghcr.io` or a cached source build. **The external clock is somebody else's support calendar**,
   which is precisely what ⏱ marks. Trigger: *GitHub announces the label's deprecation.*
2. **Color output.** §3. Trigger: the fixture set surviving one release unchanged.
3. **`--json` / machine-readable output.** §3. Trigger: the first consuming tool.
4. **Optional dependencies and feature flags.** §3 — a schema change with a migration.
5. **Workspaces.** §3.
6. **Changing an existing constraint (`add` over an existing clause).** §3.
7. **`parley config`, `parley test`, `parley cache`.** §3 — ergonomics over settled mechanics.
8. **Distribution: Homebrew, distro packaging, man pages, a documentation site.** §3.

**What is explicitly NOT on this line:** anything that would reopen the resolver's purity
contract, the constraint normal form, or the index entry schema. Those are 2.0 conversations.
