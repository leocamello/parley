# Sprint 24 — preserve command arguments across the shell boundary

**Issue:** [#26](https://github.com/leocamello/parley/issues/26) · **Specs:**
architecture decision **91**, Doc E §6, Doc D/F command-argument amendments ·
**Toolchain:** `GNU Smalltalk version 3.2.5`

**Audit record** (`.parley/audit`, produced by `wrap-sprint.sh 24 26`):

```text
sprint: 24
date: 2026-11-07T18:01:32Z
toolchain: GNU Smalltalk version 3.2.5
PARLEY-SEED: 20260718
PARLEY-VERIFY: PASS seed=20260718 run=1169 passed=1169 failed=0 errors=0
```

The traceability gate mapped every issue scenario to an acceptance test. All
122 test files loaded cleanly; all 1169 tests passed. The wrap completed after
the separate full GREEN gate passed at the same seed.

The completed source and tests also passed both workflow invocations in the
pinned `parley-ci:gst-3.2.5` container, as its non-root user with networking
disabled, against an isolated working-tree copy:

```text
PARLEY-VERIFY: PASS seed=20260718 run=1169 passed=1169 failed=0 errors=0
PARLEY-VERIFY: PASS seed=42 run=1169 passed=1169 failed=0 errors=0
```

These are local container results, not hosted GitHub Actions results. Only
the delivery record's audit text and index status were finalized afterward.

## What changed

An existing script named `hello world.st` could pass Parley's file checks,
be split by the shell, and return exit 0 without running. `ShellArgument`
now represents each complete dynamic argument as one POSIX shell word.
It copies and validates its input, preserves ordinary safe tokens, quotes
empty or special-character strings, and provides immutable equality/hash
behavior. `CommandArgumentError` rejects non-strings and NUL; the CLI
reports its message at exit 1 before spawning.

The representation is applied in the five command composers:

- `InstalledSet>>registrationCommandsFor:`: stored archive, target and
  complete staged archive paths.
- `ExecutionScope>>childCommandFor:` and `fileInPrefix`: complete image
  and script paths, with each dependency file-in encoded in its original order.
- `Publisher>>buildCommand`: stage directory and complete package.xml path.
- `GitIndexSource>>refreshCommand`: repository/cache arguments for cold
  clone and warm pull; cold clone also gains its operand separator.
- `SparseIndexSource>>fetchUrl:to:`: URL and destination arguments; curl
  receives the URL through explicit `--url`.

`ProcessRunner>>run:`, stdout redirects, stderr visibility, child exit codes,
the resolver and artifact schemas stay unchanged. The root Package.st adds
the two helper files in loader order, without changing the version. The
new error file initializes the namespace because it sorts before Compat.st
when the packaged code loads into a fresh child image.

## Verification and reviewed tests

The suite grows from 1140 to **1169** tests: 15 argument-value laws, two CLI
boundary laws and one acceptance test for each of S1–S12. The reviewed new
test files are unchanged during GREEN. The shell oracle uses 24 fixed cases
plus 256 seeded generated strings and compares received argument count and
bytes with the original input. Real scenarios cover shipped-binary execution,
dependency load order, archive registration, publish/consume, cold/warm git,
sparse metadata/archive retrieval, and registration output/failure behavior.

RED loaded all 122 test files and reported:

```text
PARLEY-VERIFY: FAIL seed=20260718 run=1169 passed=1138 failed=11 errors=20
```

All 29 new tests failed for the intended missing behavior. The other two
failures were the declared README law-count checks. The first RED attempt
had exposed an absent-path cleanup error in the new execution fixture; it
was corrected before the test set was approved.

## Integration findings and settled updates

- GNU Smalltalk's Symbol inherits from String. The first GREEN gate caught
  `isKindOf: String` accepting symbols; construction now uses the kernel's
  `isString` predicate, which symbols answer false.
- Adding the approved message error changes the declared set from six to
  seven. Besides `CommandLineFixtures>>diagnosedErrorClassNames`, the first
  GREEN gate exposed `Sprint9AcceptanceTest>>testS6_theBoundaryDeclaresSixAndThePartitionHolds`
  as another count consumer. Its size pin changes to seven; complete name
  equality, LockError coverage, and the exhaustive/disjoint partition remain.
  This dependency is recorded on issue #26.
- The declared clone and curl command oracles in `PublishFixtures` and
  `SparseIndexFixtures`, plus Sprint 22's environment-wiring scenario, gain
  the approved `--` and `--url` syntax. Other safe-path command pins retain
  their bytes. README's discovered-law count changes at GREEN's end.
- No new architecture decision was needed during implementation. Independent
  review checked the representation, all composers and preservation of the
  process contracts.

## Bounds and follow-up

This repairs the Parley-to-child argument boundary. It does not change
gst-package's internal shell encoding, XML filename encoding, or guarantee
that every downstream tool accepts tabs/newlines in filenames. No output
capture, registry service or new dependency is introduced.

Sprint 24 executes before the suspended Sprint 23 documentation increment;
historical sprint numbers are retained. Sprint 23 must refresh its discovered
test count, decision count and namespace census before resuming. The CI
migration is a separate maintenance change; a hosted run remains necessary
after publication of the candidate commits.
