# Parley

> *Smalltalk packages, resolved by conversation.*

Parley is a modern, native command-line package manager for [GNU Smalltalk](https://www.gnu.org/software/smalltalk/) 3.2.5, written entirely in Smalltalk.

The language is called Smalltalk — casual conversation. A **parley** is the formal one: a negotiation between independent parties to resolve a conflict. And that is exactly what dependency resolution is — a negotiation between constraints, ending either in agreement (a `Resolution`) or a documented account of why the parties couldn't agree (a `ConflictReport`, rendered as a narrated transcript of the negotiation).

## Status

**Pre-alpha.** Parley is under active development toward its first milestone: the algebraic domain model (`Version`, `VersionRange`, `VersionConstraint`) with a fully axiomatic test suite. Nothing is installable yet.

## Planned commands

```
parley init        Create a new package with a Package.st manifest
parley install     Resolve, fetch, and register dependencies
parley resolve     Resolve dependencies and write the lockfile
parley update      Re-resolve, ignoring the existing lockfile
parley exec        Run a program inside a curated, resolved environment
parley publish     Serialize the manifest into a static index entry
```

## Design highlights

- **Live-object domain.** Every pipeline concept — a version, a constraint, a source, a conflict, an execution scope — is an independent object answering messages. Conflict reports are inspectable derivation trees, not error strings.
- **Static trust boundary.** Authors write executable `Package.st` manifests for ergonomics, but the resolver consumes only static, literals-only index entries. Third-party code is never evaluated to compute a dependency graph.
- **Deterministic by construction.** Byte-stable serialization, day-one lockfiles, and a pure resolver: same inputs produce a byte-identical lockfile, every time.
- **Honest sandboxing.** GNU Smalltalk 3.2.5 cannot host two versions of a class in one image, so Parley doesn't pretend otherwise: `parley exec` launches a clean child `gst` process whose curated package path exposes exactly the resolved set.
- **Tested as laws.** The constraint algebra is verified against mathematical laws (De Morgan, absorption, double complement, membership consistency) over hundreds of seeded random cases per run.

Read more in [docs/design/architecture.md](docs/design/architecture.md) and [docs/design/rationale.md](docs/design/rationale.md).

## Requirements

- [GNU Smalltalk](https://www.gnu.org/software/smalltalk/) **3.2.5** (the stable baseline; `gst --version` should report 3.2.5)
- No other dependencies — Parley is self-contained by design

## Development

```bash
./scripts/verify-sprint.sh              # lint guardrails + full SUnit suite
./scripts/verify-sprint.sh --seed 42    # run the randomized law suites with an explicit seed
```

Verification is the single gate: it runs deterministic lint guardrails first, then the axiomatic SUnit suite against gst 3.2.5. See [CONTRIBUTING.md](CONTRIBUTING.md) for the workflow and [AGENTS.md](AGENTS.md) for the binding engineering rules.

## Documentation

| Document | Contents |
| --- | --- |
| [docs/design/architecture.md](docs/design/architecture.md) | System blueprint and invariants |
| [docs/design/rationale.md](docs/design/rationale.md) | Why the architecture is shaped this way |
| [docs/design/domain-model.md](docs/design/domain-model.md) | `Version`, `VersionRange`, `VersionConstraint` — the keystone set algebra |
| [docs/design/manifest-and-serialization.md](docs/design/manifest-and-serialization.md) | `Package.st` authoring and the literal micro-format |
| [docs/design/resolver.md](docs/design/resolver.md) | The pure resolver, constraint provenance, and conflict narration |

## License

[MIT](LICENSE)
