# Security Policy

## Supported versions

| Version | Supported |
| --- | --- |
| 1.0.x | yes |

## Reporting a vulnerability

Please report suspected vulnerabilities privately through GitHub's
[private vulnerability reporting](https://github.com/leocamello/parley/security/advisories/new)
on this repository, rather than in a public issue. Reports are
acknowledged within a week; a fix, an advisory, or a reasoned
assessment follows as quickly as the finding allows.

## What counts

Parley's security model is small and explicit, which makes violations
of it easy to state:

- **Third-party code must never be evaluated.** The resolver and every
  consumer of third-party package information operate exclusively on
  static index entries read by a literals-only parser. Any input that
  reaches `Behavior>>evaluate:`, the compiler, or any `doIt` pathway
  from an index entry, a lockfile, a version listing, a retirement
  record or a configuration file is a vulnerability, whatever the
  content looks like.
- **Archives must not bypass verification.** A `.star` archive is
  fetched only after resolution and is hash-verified against its
  entry's digest before it is stored or registered. Any path that
  registers unverified bytes is a vulnerability.
- **A failing command must never exit `0`.** An input that produces a
  success exit code alongside a failure is treated with the same
  severity as the two invariants above, because tooling downstream
  trusts the code.

The one deliberate non-boundary is also stated: your own `Package.st`
is executable Smalltalk that you own — evaluating it on your machine
is the authoring model, not a sandbox, and reports about arbitrary
code execution from a file the operator wrote themselves are outside
the model.
