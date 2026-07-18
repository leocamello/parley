# Contributing to Parley

Thanks for your interest in Parley! This project has an unusually strict engineering discipline — it is both a package manager and a demonstration of object-oriented design taken seriously. Please read this page before opening a pull request.

## Ground rules

The binding rules live in [AGENTS.md](AGENTS.md); the system blueprint is [docs/design/architecture.md](docs/design/architecture.md). The short version:

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

Phase 1 runs deterministic lint guardrails (they enforce the hard rules above and fail with exit codes 101–104). Phase 2 runs the SUnit suite via `scripts/run-tests.st`; a pass requires the `PARLEY-VERIFY: PASS` sentinel. Do not invoke `gst` directly to run tests — gst 3.2.5 exits 0 even on parse errors, so the harness is the only trustworthy signal.

Repository hooks live in `.githooks/` and are activated with:

```bash
git config core.hooksPath .githooks
```

The pre-commit hook enforces the active milestone's file scope (see `.parley_sprint_scope`).

## Tests

New domain behavior needs law-based tests, not just examples. The randomized suites (hundreds of cases per run) must use a deterministic seed and report it. See [docs/design/architecture.md](docs/design/architecture.md) §6 for the required law set — including round-trip serialization identity and byte-identical lockfile determinism.

## Commit style

Conventional-commit style messages, e.g. `feat(domain): implement VersionConstraint per design laws`, `fix(resolver): honor bound inclusivity in intersect:`.

## Scope

Prerelease version support, backjumping, the PubGrub strategy, and registry hosting are explicitly deferred — pull requests building them ahead of schedule will be declined. Check the open milestones before starting significant work.
