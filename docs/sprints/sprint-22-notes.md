# Sprint 22 — the release: v1.0.0 machinery, the environment layer, and the self-hosting showcase

**Issue:** [#24](https://github.com/leocamello/parley/issues/24) · **Specs:** architecture §8
decisions **70, 71, 85, 86, 87** (landed pre-RED at `27f68c8`; 87 amended in place at
`83cd101`), Doc E §4.1/§4.2/§4.3/§5, Doc B §4, Doc F §1 step 3, roadmap §3's two
recorded overrules · **Toolchain:** `GNU Smalltalk version 3.2.5`

**Audit record** (`.parley/audit`, the wrap's own re-run):

```
sprint: 22
date: 2026-08-16T10:59:13Z
toolchain: GNU Smalltalk version 3.2.5
PARLEY-SEED: 20260718
PARLEY-VERIFY: PASS seed=20260718 run=1140 passed=1140 failed=0 errors=0
```

**The law count the README states is 1140** — `run=1140` is the runner's own count, the
README's sentence carries `**1140** axiomatic laws`, and the S29 law holds the two equal by
re-counting the discovered suite the way the runner counts. The count moved DOWN before up:
1091 − 3 (the `ApplicationManifest` deletion — three laws, the staged "four" corrected
pre-RED and repository-adjudicated at Gate A) + 52 new selectors.

## What changed

- **The environment layer** (§8 decision 85). `CommandLine`'s source-flag table grew its
  per-row fourth field (`PARLEY_SOURCE`/`PARLEY_GIT`/`PARLEY_INDEX`), read by the wiring,
  the amended needs-index sentence and the completions — never spelled at a use site. The
  environment read is one injectable seam: a one-argument valuable, default
  `[:name | Smalltalk getenv: name]` declared as `CommandLine class >> processEnvironment`;
  the settled two-argument constructor delegates with the seam **closed**
  (`emptyEnvironment`), which is what keeps all 59 settled construction sites — and with
  the composer pins, every shipped-binary law — immune to the harness process's
  environment. Precedence is flag > environment > file at the one settled choice site
  (`sourceChoiceIn:`), each winning level skipping everything below (the ruled skip: a
  malformed `parley.config.st` under `PARLEY_SOURCE` is not diagnosed, driven explicitly).
  Two set variables under a flagless argv answer the declared refusal at exit 1 naming
  both, placed exactly where the file's own read sits — before the usage determination and
  before any state exists. Set-empty is unset (probed: 3.2.5's `getenv` answers nil for
  absent and `''` for set-empty; the wiring folds both).
- **`bin/parley-main.st`** — the one send gains
  `environment: CommandLine processEnvironment` (the pre-RED C3 exception): the shipped
  seam is open, every other construction closed. **Declared doc edit riding with it (named
  here per the mid-GREEN ruling):** Doc E §4.3's step-2 sentence spelled the old
  two-argument send and was amended to C3's send in the same increment, as was the
  wrapper's own header comment — a doc conformed to a ruled code change, not a silent
  drift.
- **The self-hosting showcase** (§8 decision 86). A root `Package.st` declares `parley` at
  the literal `'1.0.0'` (held equal to `Parley version` by law) with all 47 `src/` files as
  subdirectory-pathed fileIns in `scripts/run-tests.st`'s load order — the list generated
  from the drift law's own recursive `namesDo:` walk, which is also what caught that the
  within-directory order is 3.2.5's case-folding sort (`InstalledSet` < `Installer` <
  `InstallError`), not ASCII. `Publisher>>stage` creates each fileIn's staging parents
  through `PathGuard` (Doc F §1 step 3), and `removeStage` became a recursive tree removal
  inside the same exception on decision 28's precedent — the flat sweep would have refused
  its own successful nested publish at the cleanup step. S12 proves the loop on every run:
  Parley publishes itself into a transient index, a consumer installs `parley 1.0.0`, and
  a curated child answers the gateway's version.
- **The exec working-directory conformance** (the Sprint 21 carried gap; issue #24 S13,
  P5). One private resolution site in `CLI` (`resolvedScriptPathFor:`) feeds both the
  precondition and the path handed to `ExecutionScope`: a relative script argv joins the
  working directory; an argv opening with `/` passes through — the bound stated in the
  method comment.
- **The deletion** (§8 decision 87). `src/manifest/ApplicationManifest.st` deleted in
  GREEN after its three test laws were deleted in RED; the absence law and the settled
  suite agree, and the Bundler rule survives as Doc B §4 prose.
- **The release machinery** (§8 decisions 70, 71). `Parley class >> releaseFiles` — a
  25-entry declaration beside `version`, the code list riding as `Package.st` under its
  own drift law and the delivery record as the sprints index under S26's. `CHANGELOG.md`
  with exactly one version section (`[1.0.0]`) and no Unreleased heading, held to
  `Parley version` by two laws. The furniture: `SECURITY.md`, `CODE_OF_CONDUCT.md`,
  `.github/ISSUE_TEMPLATE/bug.md` (asking for `parley --version`, `gst --version` and the
  exit code), `.github/PULL_REQUEST_TEMPLATE.md`. The completions
  (`completions/parley.bash`, `completions/_parley`) are written from the test-side
  generator's own output and held byte-identical to the five declared inputs — verbRows,
  the source flags with their variable field, the mode flags, the layouts, and the
  question flags (ruled in at the pre-RED round).
- **The README restructure.** CI badge, Installing moved above the new sixty-second hero
  (the path-dependency walk — decisions.md C-1's slot ruling), the existing depth
  preserved byte-for-byte (zero lines removed, verified mechanically), then
  "How this was built" — linking the six specs, the delivery record and
  `docs/method/findings.md`, quoting the findings tally (25 defect-findings; 13 mechanism
  / 12 luck; 6 confirmation-findings excluded) under the drift law that forces the two
  files to move together — with "Parley, packaged by Parley" directly beside it, and the
  CI-checked law-count sentence written at GREEN's end against the final 1140.

## The showcase loop, as shipped bytes (streams separated)

Publish from the checkout root, consume from a fresh directory — the shipped binary, each
command's stdout and stderr captured separately; **every stderr is empty**:

```
$ parley publish <tmp-index>            # cwd = the Parley checkout
exit=0
stdout | published parley 1.0.0
stderr | (empty)

$ parley install --source <tmp-index>   # cwd = a consumer project depending on parley ^1.0
exit=0
stdout | parley 1.0.0
stderr | (empty)

$ parley exec proof.st                  # proof.st loads the star and asks the gateway
exit=0
stdout | Loading package parley
stdout | the child answers: 1.0.0
stderr | (empty)
```

(`Loading package parley` is the child's own `PackageLoader` line on the child's stdout —
the program's stream, passed through faithfully.) The run in the checkout wrote only the
git-ignored `.parley/packages`; the documented reset gesture (`rm -rf .parley/packages
.parley/git .parley/index`, never `.parley` whole) left `scope` and `audit` standing.

## The environment precedence chain, as shipped bytes (streams separated)

One project declaring `demo-lib ^1.0`; index A publishes 1.0.0, index B publishes 1.1.0;
**every stderr is empty**:

```
$ parley resolve                                          # no flag, no variable, no file
exit=1
stdout | no index is wired, and Package.st declares demo-lib - give --source, --git or --index, record one in parley.config.st, or set PARLEY_SOURCE, PARLEY_GIT or PARLEY_INDEX

$ PARLEY_SOURCE=<A> PARLEY_GIT=<B> parley resolve         # two variables, flagless
exit=1
stdout | PARLEY_SOURCE and PARLEY_GIT are both set - the environment supplies at most one source, unset one or give a source flag

$ PARLEY_SOURCE=<B> parley resolve                        # config file declares A
exit=0
stdout | demo-lib 1.1.0                                   # the environment beat the file

$ PARLEY_SOURCE=<B> parley resolve --source <A>
exit=0
stdout | demo-lib 1.0.0                                   # the flag beat the environment

$ parley resolve                                          # variables cleared; the file answers
exit=0
stdout | demo-lib 1.0.0
```

## Ambiguities hit, and how each resolved

1. **Pre-RED round** (all ruled on #24 before a test existed): the exec-cwd settled-mover
   family was ten files, not one (C1); the needs-index re-pin family's true composer was
   `PathDepFixtures:587`, with `UsageGroundTest` a confirmed non-mover (C2);
   `bin/parley-main.st` needed the declared `environment:` exception (C3); the seam's
   shape, both pinned wordings, the completions' exact file forms (question flags ruled
   in), `releaseFiles`' 25 entries, and the exec absolute-path bound (P1–P5).
2. **The deletion count**: decision 87's "four test laws" was three — the ×2 in
   `Sprint3AcceptanceTest` counted two sends inside one selector. Corrected pre-RED,
   machine-confirmed by the red run, decision 87 amended in place at Gate A (`83cd101`).
3. **Gate A reviewer amendments** (part of the reviewed suite): two further shipped-chain
   composers pinned (`PathFixtures` `wrapperCommandAt:in:args:root:outputTo:` and
   `relativeWrapperCommandWithArgs:outputTo:` — the "three composers" set was enumerated
   by declaration, the sweep found five); the S25 mini-matcher made exact on
   `$`-anchored alternatives; S25's refusal half (`operator/kickoffs/` denied); S26's
   phantom-row falsifier.
4. **Mid-GREEN halt: `ModeFlagTest>>testTheSourceFlagTableIsUntouched`** — Sprint 21's
   own freeze of the table at three columns, in direct contradiction with the reviewed
   four-column re-pin, invisible in red because the table was still three columns then.
   Ruled on #24: the row-size clause **dropped** (one property, one law — the shape's
   single authority is `SourceFlagTest`'s Sprint 22 law), the law renamed
   `testTheModeFlagsNeverEnterTheSourceTable` with its set-freeze and mode/source
   separation intact. Applied verbatim as granted. `ModeFlagTest`'s file comment still
   describes the row as three-column in passing; left as-is, outside the grant's exact
   text.
5. **Three late exec-cwd family members, found by the green gate** (a mechanism):
   `Sprint14AcceptanceTest` S14, `Sprint15AcceptanceTest` S16 and `Sprint16AcceptanceTest`
   S16's typo'd-exec step drive exec in-image through `argv:`-keyword helpers, and the
   original family sweep excluded lines containing `argv` as usage-grammar noise —
   exactly the members the filter threw away. They passed in red (the code still resolved
   against the process cwd) and failed the moment the fix landed. Re-pinned under C1's
   property-defined uniform bound (argv drops its cwd-spelled prefix, oracles preserved),
   and the sweep was re-run with no exclusions: every remaining `exec` argv in the suite
   is a usage-table row, an arity fixture, or Sprint 22's own deliberate cwd decoy.

## The settled movers, as landed (which assertion moved each)

- **The exec-cwd family — thirteen files after the three late members.** In-image argv
  re-pins, oracles preserved: `CliTest` (the pinned child line, script moved into the
  workdir), `CommandLineTest` (the `execResultIn:runner:` helper feeding seven boundary
  laws), `ReadinessTest` (three argv), `PathFixtures` (the boundary-table exec row's
  driver argv), `Sprint6` (the e2e proof argv; the S18 pinned child line),
  `Sprint7`/`Sprint8` (proof argv; the boundary helper), `Sprint16` (S1/S2/S3, the walk's
  typo step and its step 7), `Sprint17` (the exit-70 boundary argv), `Sprint21` (the
  composed-line half), `Sprint14`/`Sprint15` (the offline walks' proof argv).
- **The needs-index sentence family** — one composer, `PathDepFixtures
  needsIndexRefusalFor:`, gaining the third remedy from the `EnvFixtures` mirror; its five
  consumer laws re-pinned through it with no text edits. `UsageGroundTest`: declared
  non-mover, machine-confirmed.
- **`SourceFlagTest`** — the shape law re-pinned to the four-column row (a rename, −1/+1).
- **`ModeFlagTest`** — the granted amendment above (a rename, −1/+1; one clause dropped
  with the shape's authority consolidated).
- **The five shipped-chain composers** — `CommandLineFixtures` ×2, `PathFixtures` ×3
  (Gate A's two included) carrying `EnvFixtures pinnedEmptyPrefix`; inert in red, binding
  from the moment `bin/` reads the environment.
- **Negative movers** — `PinVerificationTest` −2, `Sprint3AcceptanceTest` −1, comments
  amended to cite decision 87; the class file deleted in GREEN.

## New surface

Production: the source-flag table's fourth field, `environmentVariableNames`,
`processEnvironment`, `emptyEnvironment`, `twoVariablesRefusalFor:and:`,
`in:runner:environment:` and the private env-choice/refusal wiring on `CommandLine`; the
third remedy clause in `CLI needsIndexRefusalFor:` and the private
`resolvedScriptPathFor:`; `Publisher`'s `ensureStageParentsFor:` and recursive
`removeStageTree:`; `Parley class >> releaseFiles`. Artifacts: the root `Package.st`,
`CHANGELOG.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, both `.github` templates, both
completions, the restructured README. Tests: `Sprint22AcceptanceTest` (30),
`EnvLayerTest` (8), `ReleaseManifestTest` (8), `CompletionTest` (3), `ReleaseDriftTest`
(3), and four support fixtures (`EnvFixtures`, `ReleaseFixtures`, `CompletionFixtures`,
`ShowcaseFixtures`).

The tag is not cut here. Gate B is the release, and the tag, the GitHub Release and every
repository setting are the operator's.
