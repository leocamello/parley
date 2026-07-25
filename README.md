# Parley

> *Smalltalk packages, resolved by conversation.*

Parley is a modern, native command-line package manager for [GNU Smalltalk](https://www.gnu.org/software/smalltalk/) 3.2.5, written entirely in Smalltalk.

The language is called Smalltalk — casual conversation. A **parley** is the formal one: a negotiation between independent parties to resolve a conflict. And that is exactly what dependency resolution is — a negotiation between constraints, ending either in agreement (a `Resolution`) or a documented account of why the parties couldn't agree (a `ConflictReport`, rendered as a narrated transcript of the negotiation).

## Status

**Pre-alpha, and the core loop works end to end.** An author can publish a package into an index; a consumer can resolve it, install it, and execute code against it in a curated child image — every step driven through the shipped `bin/parley` binary, and proven that way by the test suite. What is *not* here yet: registry hosting, prerelease versions, yank/retire, and index signing. Interfaces may still move.

## Commands

```
parley init        Create a new package with a Package.st manifest
parley install     Resolve, fetch, and register dependencies
parley resolve     Resolve dependencies and write the lockfile
parley update      Re-resolve, ignoring the existing lockfile
parley exec        Run a program inside a curated, resolved environment
parley publish     Build the archive and land a release in an index
```

`--source <dir>` selects a directory index for the verbs that need one. Parley's state for a project lives beside that project, under `<working-dir>/.parley/`.

### Exit codes

Parley never answers a backtrace, and no failing command ever exits `0`:

| Code | Meaning |
| --- | --- |
| `0` | success |
| `1` | a diagnosis — Parley understood what is wrong with your project and is telling you |
| `2` | usage — the command was not well formed |
| `70` | a defect in **Parley**, not in your project. One line, never a dump. Please report it. |

The split between `1` and `70` is deliberate and law-enforced: a script checking `$?` can tell "your input is wrong" from "the tool is broken".

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

Start at [docs/design/README.md](docs/design/README.md) — it indexes the specs
and maps the Doc A–F letters used throughout the code to their files.

| Document | Contents |
| --- | --- |
| [docs/design/architecture.md](docs/design/architecture.md) | System blueprint, invariants, and the decision log |
| [docs/design/rationale.md](docs/design/rationale.md) | Why the architecture is shaped this way |
| [Doc A — domain-model.md](docs/design/domain-model.md) | `Version`, `VersionRange`, `VersionConstraint` — the keystone set algebra |
| [Doc B — manifest-and-serialization.md](docs/design/manifest-and-serialization.md) | `Package.st` authoring and the literal micro-format |
| [Doc C — resolver.md](docs/design/resolver.md) | The pure resolver, constraint provenance, and conflict narration |
| [Doc D — installer.md](docs/design/installer.md) | `Sha256`, the content-addressed store, and `gst-package` registration |
| [Doc E — execution-and-cli.md](docs/design/execution-and-cli.md) | `ProcessRunner`, `ExecutionScope`, the CLI verbs, and the diagnosis boundary |
| [Doc F — publish-and-sources.md](docs/design/publish-and-sources.md) | The publish pipeline, entry validation, and `GitIndexSource` |
| [docs/sprints/](docs/sprints/) | The delivery record — what each sprint built, with its seed and law count |

## License

[MIT](LICENSE)
