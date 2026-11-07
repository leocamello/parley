# Sprint 25 — locked pin provenance

Issue [#27](https://github.com/leocamello/parley/issues/27), requested after
Sprint 23 closed. Baseline `8db6d97`: **1195 tests / 129 files**. This repair
adds **21 tests**, giving **1216 tests / 132 files**, on GNU Smalltalk 3.2.5.

## Behavior and scope

The shared lock-write guard now compares complete canonical pin tuples:
name, version, provenance marker and payload. A same-version path or digest
change, or a transition between path and archive, refuses at exit 1 with
both provenance values. Differences are considered over the sorted union
of package names, so an earlier removal cannot be hidden by a later change.
Existing added/removed/version-change wordings are preserved.

After pins agree, a changed root name or an absent empty lock has a separate
diagnosis. Valid whitespace and package-order variations compare by meaning
and retain their original bytes on success; schema keys keep their required
fixed order. Live path source contents, archive URLs and other fields absent
from the lock are not part of pin identity.

Only `CLI>>lockedRefusalAgainst:` and two private helpers, plus three
class-side `CommandLine` wording declarations, change in production. The
existing writer and literals-only reader supply canonical tuples, avoiding
schema dispatch in the CLI and avoiding `Resolution` equality, which does
not include paths. The guard remains at the existing `writeLock:` site.
No class, dependency, schema, resolver or version change is introduced.

All six writer routes are covered: resolve, full and selective update,
install when it resolves fresh, add and remove. The latter pair retain
atomic manifest/lock restoration. Refusals precede archive installation and
registration. The settled source-free install fast path remains unchanged;
`exec` continues to read recorded paths. Callers checking changed declarations
should use `resolve --locked` before execution, and resolve without the flag
when intentionally accepting a change. The guide states this boundary.

Independent contract review found the behavior already required by Doc E
§4.2 and Doc B §5.3/decision 69. The spec now enumerates that existing
invariant's domain. No new architecture decision or deferred feature was
needed; all 91 historical decisions and their index remain intact.

## RED and GREEN evidence

The twelve acceptance scenarios include real-wrapper path selection and
execution, exact refusal text, preservation of both project files, no
installation process after refusal, and a trap source on the valid install
fast path. Nine law selectors cover digest states, both provenance-kind
transitions, quoted/aliased paths, sorted diagnosis precedence, root and
empty-lock cases, semantic/read-only locks, irrelevant internal digest data
on path pins, and the unchanged corrupt-lock boundary.

The first RED run is **rejected**: two new fixture literals used a bare
identifier where GNU Smalltalk's file-in syntax requires an explicit symbol.
Compiler diagnostics caused 33 tests to disappear, including settled tests;
the run reported 1183 rather than the independently enumerated 1216. The
harness still claimed RED success. Only the two new fixture literals were
corrected, before the test freeze; no assertion or settled test was changed.

The corrected RED run matched the declared inventory exactly:

```text
PARLEY-VERIFY: FAIL seed=20260718 run=1216 passed=1199 failed=17 errors=0
```

Fifteen new selectors failed on missing behavior. The other two failures
were the existing README suite-count assertions. Six declared controls
passed: S10–S12 and the semantic/read-only lock, irrelevant path digest,
and corrupt-lock laws. All 132 file markers were present, the full selector
total agreed, and explicit source-file/line diagnostic inspection was clean.

Independent review checked the tests, actual failure assertions and the
syntax correction. The complete test tree was then fingerprinted and frozen.
The first GREEN increment passed with every frozen test hash unchanged:

```text
PARLEY-SEED: 20260718
PARLEY-VERIFY: PASS seed=20260718 run=1216 passed=1216 failed=0 errors=0
```

The wrap passed traceability for S1–S12 and recorded:

```text
sprint: 25
date: 2026-11-07T23:32:04Z
toolchain: GNU Smalltalk version 3.2.5
PARLEY-SEED: 20260718
PARLEY-VERIFY: PASS seed=20260718 run=1216 passed=1216 failed=0 errors=0
```

An independent production review found no blocker: it checked canonical
schema ownership, sorted precedence, nil safety, metadata diagnoses,
immutability, production scope and the guide's fast-path boundary.

## Product probe and delivery boundary

An isolated five-command baseline probe reproduced both path and digest
failures through `bin/parley`: locked resolve incorrectly exited zero with
the old lock untouched, and execution followed the old path. The repaired
candidate workflow passed eleven command checks: path/digest refusal,
unchanged bytes on refusal, intentional unlocked refresh, execution from
the refreshed path, continued live source editing, and acceptance of changed
archive metadata absent from the lock. These results used the working
candidate over baseline 8db6d97; final committed-checkout evidence belongs
on issue #27. The probe uses locally authored packages and static metadata;
no external service or third-party manifest evaluation is involved.

A fresh local clone of implementation commit
`34eabfba1540a897bb2cde5d187f4af489a686a2` subsequently passed all eleven
product checks. Both changed-provenance refusals returned exit 1 with exact
diagnoses; unlocked refresh switched execution to the second source. An edit
at the unchanged path remained accepted and was visible on execution, while
the same-digest archive metadata change was accepted. Every stderr stream
was empty; the clone's HEAD/tree stayed unchanged and its git status clean.
Only delivery references and this evidence record changed afterward, before
the independent final verification.

README's count and flag description, the configuration guide, this delivery
record and the roadmap are updated before final verification. The wrap audit,
final commits, both deterministic seeds and hosted results belong to the
issue close-out. No release tag or version bump is part of this repair.

## Carried verification gap

[Issue #28](https://github.com/leocamello/parley/issues/28) records the
observed harness defect separately, unscheduled: the gate recognizes only
the phrase `parse error`, while GNU Smalltalk can report other nonthrowing
compiler diagnostics and still emit the runner's file marker. RED 01 proves
false RED acceptance; a false GREEN result is not claimed as observed.

This repair's results are accepted only after reconciling all 1216 selectors,
all 132 file markers and the absence of compiler diagnostic lines. The
harness itself and the operator-authored method findings/tally are unchanged.
The diagnostic and load-integrity repair requires its own scoped tests.
