# Sprint Record

Parley is built in sprints, each a delivery slice run through the five-stage
pipeline (requirements → architecture → RED → GREEN → WRAP) described in
[`.github/copilot-instructions.md`](../../.github/copilot-instructions.md).
Every completed sprint leaves an audit record here: what was built, which
ambiguities were hit and how they were resolved, and the exact seed, law
count, and toolchain version the suite passed with.

The law count is cumulative — the whole suite runs every sprint, so each
number is the total axiomatic laws green at that sprint's close.

| Sprint | Milestone | Issue | Commit | Laws |
| --- | --- | --- | --- | --- |
| [00](sprint-00-notes.md) | The algebraic domain model — `Version`, `VersionRange`, `VersionConstraint`, compat layer | [#1](https://github.com/leocamello/parley/issues/1) | `13d16da` | 87 |
| [01](sprint-01-notes.md) | Manifest authoring & byte-stable serialization — `ManifestBuilder`, `IndexEntryWriter`/`Reader` | [#3](https://github.com/leocamello/parley/issues/3) | `ba0fcb2` | 148 |
| [02](sprint-02-notes.md) | The pure resolution engine — `Term`, `Incompatibility`, `ConstraintLedger`, `Resolver`, lockfile schema | [#4](https://github.com/leocamello/parley/issues/4) | `68b516d` | 203 |
| [03](sprint-03-notes.md) | Trustworthy resolution — decision-pin soundness, `ApplicationManifest`, `PinVerification` | [#5](https://github.com/leocamello/parley/issues/5) | `77923af` | 233 |
| [04](sprint-04-notes.md) | The first real source — `DirectorySource`, end-to-end resolve-on-disk | [#6](https://github.com/leocamello/parley/issues/6) | `046c438` | 263 |
| [05](sprint-05-notes.md) | The Installer — `Sha256`, `ContentStore`, `Installer`, the registration plan | [#7](https://github.com/leocamello/parley/issues/7) | `7c48f9a` | 308 |
| [06](sprint-06-notes.md) | `ExecutionScope` + CLI — the process seam, the curated child image, all five verbs | [#8](https://github.com/leocamello/parley/issues/8) | `af8782d` | 356 |
| [07](sprint-07-notes.md) | Publish + `GitIndexSource` — `Publisher`, the second real source, the ecosystem loop | [#9](https://github.com/leocamello/parley/issues/9) | `09d2307` | 409 |
| [08](sprint-08-notes.md) | The diagnosis boundary — `CommandLine`, exit codes that never lie, the law-guarded binary | [#10](https://github.com/leocamello/parley/issues/10) | `4ef95a5` | 461 |
| [09](sprint-09-notes.md) | The blame boundary — `LockError`, the authoring boundary in `define:`, every source reachable | [#11](https://github.com/leocamello/parley/issues/11) | `f48ac59` | 500 |
| [10](sprint-10-notes.md) | Retirement — the `#'parley-retired'` schema, the snapshot filter, lock body-shape validation | [#12](https://github.com/leocamello/parley/issues/12) | `c15c2c5` | 539 |
| [11](sprint-11-notes.md) | The inspection verbs — `why`/`tree`/`check`, `SchemaShape`, the hex-digest grounds | [#13](https://github.com/leocamello/parley/issues/13) | `1a8a251` | 585 |
| [12](sprint-12-notes.md) | Selective `update <pkg>` — `IndexSnapshot>>holding:`, move one and hold the rest | [#14](https://github.com/leocamello/parley/issues/14) | `a899ca8` | 612 |
| [13](sprint-13-notes.md) | `parley add` — `ManifestEditor`, one clause inserted and never a re-render | [#15](https://github.com/leocamello/parley/issues/15) | `d9b6fad` | 662 |
| [14](sprint-14-notes.md) | The sparse-index client — `SparseIndexSource`, the pre-fetch closure, `seededWith:` | [#16](https://github.com/leocamello/parley/issues/16) | `d54b490` | 709 |
| [15](sprint-15-notes.md) | Publishing into a sparse index — `--layout`, the listing write, `--version`, the v1.0 line | [#17](https://github.com/leocamello/parley/issues/17) | `87a9e34` | 756 |

**Phase exits reached.** Sprint 4 closed read-only package management (`parley
resolve` in all but the CLI). Sprint 6 closed the orchestration bridge: a
toolchain-built star resolved, locked, installed, registered, and its class
proven visible inside the curated child process — a package lands in an image.
Sprint 7 closed the ecosystem loop: author A publishes, author B resolves,
installs and executes A's package. Sprint 8 closed it *through the shipped
binary* — the same loop driven end to end by real `bin/parley-main.st` child
processes, with exit codes that distinguish "your input is wrong" from "the
tool is broken" and never answer `0` on a failure.

## Naming

Files are `sprint-NN-notes.md`, zero-padded, so they sort correctly past
sprint 9. `wrap-sprint.sh` writes and stages this path automatically at
Stage 5; the sprint number it is invoked with selects the file.

Notes from sprints 0–6 were written when these files lived at the repository
root as `SPRINT<N>-NOTES.md` and the harness state lived at
`.parley_verification_audit`. Those in-text references are left exactly as
written — an audit record states what was true when it was recorded, and
rewriting it to match a later layout would make it false. The current paths
are `docs/sprints/` and `.parley/audit`.

## Related

- [`docs/design/`](../design/) — the canonical specs (Docs A–F) each sprint implements.
- The milestone issue for each sprint carries its numbered acceptance
  scenarios `S1..Sn`; `wrap-sprint.sh` refuses to wrap unless every scenario
  has a matching `testSn_*` selector under `tests/acceptance/`.
