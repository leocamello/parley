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

**Phase exits reached.** Sprint 4 closed read-only package management (`parley
resolve` in all but the CLI). Sprint 6 closed the orchestration bridge: a
toolchain-built star resolved, locked, installed, registered, and its class
proven visible inside the curated child process — a package lands in an image.

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
