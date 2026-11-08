# Contributing to Parley

Thanks for your interest in Parley! This project has an unusually strict engineering discipline — it is both a package manager and a demonstration of object-oriented design taken seriously. Please read this page before opening a pull request.

## Ground rules

[AGENTS.md](AGENTS.md) and [.github/copilot-instructions.md](.github/copilot-instructions.md) prescribe the workflow for coding agents; human contributors follow this page and the engineering constraints below. The system blueprint is [docs/design/architecture.md](docs/design/architecture.md).

- **Target GNU Smalltalk 3.2.5.** Every change must execute cleanly against it (`gst --version` must report 3.2.5).
- **No third-party dependencies, ever** — Parley depends only on the 3.2.5 kernel and the bundled `gst-package` tooling.
- **Never evaluate third-party content.** Static artifacts (index entries, lockfiles) are read only by the literals-only reader; nothing reaches the compiler.
- **Structural immutability.** Zero public setters in the domain model; class-side constructors validate and normalize; operations answer new instances.
- All Parley classes live in the `Parley` namespace; kernel polyfills live only in the `*parley-compat` method category.
- If a design question is not answered by the design docs, **open an issue and ask** — do not invent architecture.

## Development workflow

There is exactly one verification gate:

```bash
./scripts/verify-sprint.sh              # lint guardrails + axiomatic SUnit suite
./scripts/verify-sprint.sh --seed 42    # explicit seed for the randomized law suites
```

Phase 1 runs deterministic lint guardrails (they enforce the hard rules above and fail with exit codes 101–104, plus the toolchain check at 105). Phase 2 runs the SUnit suite via `scripts/run-tests.st`. Both RED and GREEN require complete, silent loading before accepting the suite's result; GREEN additionally requires exit 0 and `PARLEY-VERIFY: PASS`. Do not invoke `gst` directly to run tests — gst 3.2.5 can report compiler errors and still return normally.

The runner flushes stdout and stderr before `PARLEY-LOAD-END`. Before that boundary, only its seed/load/file protocol lines, blank lines and the kernel's initial `Loading package SUnit` notice are allowed; source and test files must not print while loading. Unexpected output is retained in the gate's failure report. `PARLEY-TESTFILE` records that file-in returned, not that compilation succeeded, so the gate checks both the load output and the test-file census. Tests may intentionally print diagnostics after loading; those messages do not invalidate load integrity. Missing or duplicate load completion always refuses the run.

Repository hooks live in `.githooks/` and are activated with:

```bash
git config core.hooksPath .githooks
```

The pre-commit hook enforces the active milestone's file scope (see `.parley/scope`).

## Tests

New domain behavior needs law-based tests, not just examples. The randomized suites (hundreds of cases per run) must use a deterministic seed and report it. See [docs/design/architecture.md](docs/design/architecture.md) §6 for the required law set — including round-trip serialization identity and byte-identical lockfile determinism.

## Commit style

Conventional-commit style messages, e.g. `feat(domain): implement VersionConstraint per design laws`, `fix(resolver): honor bound inclusivity in intersect:`.

## Scope

Prerelease version support, backjumping, the PubGrub strategy, and registry hosting are explicitly deferred — pull requests building them ahead of schedule will be declined. Check the open milestones before starting significant work.
