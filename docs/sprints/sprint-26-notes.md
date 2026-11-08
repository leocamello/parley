# Sprint 26 — verification load integrity

Issue [#28](https://github.com/leocamello/parley/issues/28), explicitly
requested after Sprint 25. This delivery number records a harness repair;
it introduces no package-manager feature or architecture decision.
Implementation: `a0e318c`. Baseline `227328c`: **1216 tests / 132 files**. Ten new acceptance scenarios
bring the inventory to **1226 tests / 134 files** on GNU Smalltalk 3.2.5.

## Behavior and scope

Both verification phases now check loading independently of SUnit results.
The runner flushes stdout and stderr after each file-in and emits a flushed
`PARLEY-LOAD-END` boundary before discovery and test execution. The shell
requires exactly one boundary and refuses unexpected nonempty output before
it. Only protocol lines and the exact initial kernel SUnit loading notice
are accepted. Source and test files must load silently.

GNU Smalltalk's file-in primitive can return normally after compiler errors;
compiler diagnostics go directly to stderr, bypassing Transcript. A
`PARLEY-TESTFILE` marker therefore records return from file-in, not proof of
successful compilation. The existing file census remains an independent
check. The gate retains the first fifteen load-diagnostic lines, including
the file and line when supplied, instead of searching only for `parse error`.
Missing or duplicate completion refuses either phase, including a broken
runner. Diagnostic text emitted during running tests remains allowed.

Only `scripts/run-tests.st` and `scripts/verify-sprint.sh` change executable
behavior. Ten SUnit scenarios copy these actual scripts into tiny trusted
fixture trees and invoke the copied official verifier through ProcessRunner.
At most sixteen child invocations cover both phases without copying or
recursively executing the full suite. Captured child diagnostics cannot
contaminate the parent's verification protocol. Cleanup removes each tree,
including child breaker state, without resetting any active verifier state.

No production class, schema, dependency, CLI behavior, workflow topology or
release version changes. No method finding or tally is edited. Contributor
instructions describe the stricter load contract; README's discovered law
count and the delivery index move with the tests.

## Reproduction, review and verification

Isolated probes against the unchanged baseline demonstrated both false RED
and false GREEN acceptance: `#(locked)` produced `expected true, false or
nil`, both test-file markers appeared, only the healthy test ran, and each
gate returned zero. False GREEN is now observed, extending the original
issue's RED-only evidence.

The first full RED run is rejected as evidence: a new fixture used a cleanup
helper that queries symbolic-link state before checking existence. All ten
scenarios errored before their child verifiers ran. Switching to the settled
missing-path-safe recursive helper corrected setup without changing any
assertion. Before freeze, the runtime diagnostic control was strengthened
to exercise both stdout and stderr.

The corrected RED inventory matched exactly:

```text
PARLEY-VERIFY: FAIL seed=20260718 run=1226 passed=1217 failed=9 errors=0
```

S1–S4, S7–S9 failed on the intended verifier defects. S5/S6/S10 passed as
declared controls for ordinary GREEN, ordinary RED and omitted-file census.
The other two failures were the settled README count assertions. All 134
file markers were present, with no compiler diagnostics. Independent review
checked fixture dependencies and the exact failure set, then all 134 test
files were fingerprinted and frozen.

The first GREEN increment correctly rejected unexpected load output but
also rejected the kernel's normal `Loading package SUnit` announcement.
It ran all 1226 tests, with four control failures and zero errors. The gate
was narrowed to permit that exact bootstrap line only before the seed line;
project file-in output remains checked. No frozen test changed.

The corrected GREEN run passed all 1226 tests, with all 134 file markers,
one completion boundary and no compiler diagnostics. Independent review
confirmed the implementation and all frozen test hashes. The required wrap
passed issue traceability for S1–S10 and recorded:

```text
sprint: 26
date: 2026-11-08T12:51:04Z
toolchain: GNU Smalltalk version 3.2.5
PARLEY-SEED: 20260718
PARLEY-VERIFY: PASS seed=20260718 run=1226 passed=1226 failed=0 errors=0
```

Local transcripts, inventories, frozen test hashes and review evidence are
retained under `operator/staging/sprint-26/`. The final audit and hosted
results are recorded on issue #28.
