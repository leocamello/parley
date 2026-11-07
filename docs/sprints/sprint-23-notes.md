# Sprint 23 — the documentation increment

**Issue:** [#25](https://github.com/leocamello/parley/issues/25).

**Implemented:** 2026-11-07, after Sprint 24.

**Specification:** architecture §8 decisions 88–90.

**Toolchain:** GNU Smalltalk version 3.2.5.

**Suite:** 1169 → 1195 laws, all 129 test files loaded.

## Delivered

The README shrinks from 447 to 181 lines. Its sixty-second path-dependency
walk is byte-identical, as is the method tally: 32 defect findings, 18
mechanism, 14 luck, six confirmations. Its law count is 1195. The command
table retains every verb; detailed execution, publication, authoring and
development guidance moves into seven pages under `docs/guide/`.

Architecture §8 gains a numeric index over all 91 decisions and explicit
anchors. Every original decision paragraph remains byte-identical and in
its original order. Four Mermaid diagrams explain the pipeline, trust
boundary, source composition and configuration precedence. Four rationale
entries explain the existing choices. CONTRIBUTING clarifies the roles of
agent instructions and human contribution guidance.

The only production edit is `Parley class >> releaseFiles`: the guide index
joins the release manifest in a sixth Array group. No class, dependency,
wire format or runtime behavior is added. The version constant, root
manifest and CHANGELOG remain at `1.0.0`.

## RED review and GREEN corrections

Seventeen acceptance selectors and three law families (nine selectors)
cover the documentation set, diagram declarations and decision index.
Their fixtures include deliberately missing pages, contradictory diagram
declarations and missing/duplicate decision rows. Diagram checks establish
the declared class-name relationships; they cannot establish explanatory
quality or arrow semantics, which require independent review.

The operator approved six genuine passes in RED: S5, S6, S10, S15, S16 and
S17. Fixture-only cases were kept atomic. The initial RED gate reported
`run=1195 passed=1171 failed=24 errors=0`. A full consumer inventory identified
seven further settled selectors whose documentation moved, beyond the two
original release-hardening movers. Their exact amendment was approved on
issue #25 before GREEN. The amended RED gate reported
`run=1195 passed=1164 failed=31 errors=0`: exactly those seven additional
failures, with all six declared passes unchanged. Nine other inventoried
settled consumers retained their README claims.

The first GREEN gate reported 1190 passes, four failures and one error.
It caught a removed status marker, an uppercase prose word interpreted as a
diagram class declaration, and a mechanical precedence error in a reviewed
test newly reaching its real-page falsifier. The status marker was restored
and the diagram caption corrected. The test's sole GREEN change was:

```smalltalk
self assert: removed size = (names size - 1).
```

Without parentheses, Smalltalk sends subtraction to the Boolean comparison
result. Independent review confirmed that this correction preserves the
reviewed exact-cardinality assertion and its missing-page negative control.
The original test fingerprints and correction record are retained in the
operator evidence. No test was removed, renamed or weakened.

The corrected GREEN gate and final wrap passed. The wrap audit records:

```text
sprint: 23
date: 2026-11-07T22:56:09Z
toolchain: GNU Smalltalk version 3.2.5
PARLEY-SEED: 20260718
PARLEY-VERIFY: PASS seed=20260718 run=1195 passed=1195 failed=0 errors=0
```

## Independent review and documented workflow preflight

A separate reviewer compared all 91 index summaries to their rulings,
checked paragraph and hero preservation, and rendered and visually inspected
all four diagrams. The final captions match the rendered inputs. Existing
local Mermaid/Chrome tooling was used with network requests blocked; no
project dependency was installed. The review found no remaining
documentation blocker.

An isolated candidate checkout passed 33 recorded workflow steps and 12
supplemental snippet steps on GNU Smalltalk 3.2.5. These exercised the README
hero and live sibling edit, installation symlink and explicit root, both
publication layouts and archive consumers, Bash completion, configuration
precedence and refusal paths, offline and locked cases, explicit CI exits,
spaced script names, dev-only dependency omission, the path-to-archive
transition, and the manual runtime commands. Conditional Smalltalk fragments
were embedded in complete locally authored fixtures. Static lock and
configuration literals were read as data, never evaluated.

The 45 steps used a committed baseline plus the prepared candidate overlay;
they are not described as tests of a final published SHA. Remote git/HTTP
hosting and Zsh completion were not exercised. The interactive runtime
example was supplied through stdin, not a physical terminal. Final committed
checkout and hosted verification evidence belongs on issue #25.

## Carried gap and close-out boundary

Review prompted a real probe of a same-version dependency path change.
`resolve --locked` returned success, retained the old lock path, and a later
execution read the old source. [Issue #27](https://github.com/leocamello/parley/issues/27)
records the reproduction and expected-contract question for the next Gate C;
it is unscheduled. The analogous archive-digest case is not claimed as
tested. The guide now describes the version-only guard and advises resolving
without `--locked` after a path change, then reviewing the refreshed lock
before execution. This sprint does not alter that behavior.

The consumer-inventory correction is recorded here without adding an
operator-authored method finding or changing the tally. The delivery index,
roadmap and these notes precede the final verification so the delivery-record
drift law sees them. `.parley/audit` is the wrap's authoritative timestamp,
toolchain and sentinel record; issue #25 carries traceability, final commit
identifiers and hosted results. No release tag or version bump is part of
this increment.
