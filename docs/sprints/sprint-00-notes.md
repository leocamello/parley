# Sprint 0 Notes — Keystone Domain Model

## What was built

- `src/compat/Compat.st` — creates the `Parley` namespace (guarded) and adds
  `Collection>>ifEmpty:` / `ifEmpty:ifNotEmpty:` in method category
  `*parley-compat`, matching ANSI/Pharo semantics. No other polyfill was
  needed by a concrete use site this sprint.
- `src/domain/Version.st` — `Parley.VersionFormatError` and `Parley.Version`:
  1–3 component parsing with zero-padding, rejection of prerelease/build
  tags, `v`-prefixes, whitespace, empty components and non-digits; full
  comparison protocol; `=` and `hash` together; canonical three-component
  `printOn:`.
- `src/domain/VersionRange.st` — `Parley.VersionRange`: four-slot state with
  `nil` = unbounded (open inclusivity normalized to `false` on `nil`
  bounds); `allows:`, `intersect:` (nil on disjoint; AND inclusivity on
  equal bounds; nil bounds always lose), `coalescesWith:` with the exact
  adjacency rule; construction signals on provably empty spans; structural
  `=`/`hash`; §3.5 single-range rendering.
- `src/domain/VersionConstraint.st` — `Parley.ConstraintFormatError` and
  `Parley.VersionConstraint`: the two-level normal form with the single
  `normalizing:` construction funnel; all class-side constructors including
  Cargo-exact caret; `intersect:` and `complement` as the two primitives,
  `difference:`/`isSubsetOf:` kept derived; the full `fromString:` grammar
  with `||`; canonical `printOn:` (the wire form).
- Test suite (written first, in the red phase): `tests/support/DomainGenerators.st`
  (seeded Park–Miller LCG; components in 0..9; random constraint algebra;
  the normal-form checker), `tests/laws/{Version,VersionRange,VersionConstraint}Test.st`
  (laws 1–8, caret table, rendering rules, grammar, round-trip), and
  `tests/acceptance/Sprint0AcceptanceTest.st` (`testS1_`–`testS10_`).

## Spec ambiguities and their resolution

1. **`'none'` is parseable.** The §3.6 grammar does not list `'none'`, but
   §3.5 rule 1 prints it and §3.6 states the parser MUST accept everything
   `printOn:` emits (total round-trip). Resolution: `fromString: 'none'`
   answers `VersionConstraint none`.
2. **Caret component-count sensitivity.** Rows `^0` and `^0.0` depend on how
   many components were written, which a three-component `Version` cannot
   carry. Resolution: the parser passes the written component count to the
   caret expansion (leftmost nonzero written component is the boundary; all
   written zeros → the last written component). `compatibleWith:` is defined
   as caret with three components, making `compatibleWith: 0.0.0` equal to
   Cargo's `^0.0.0` → `[0.0.0, 0.0.1)`. The caret table is tested through
   `fromString:`; `compatibleWith:` is asserted against the unambiguous
   three-component rows.
3. **Empty-span signal class.** Spec §2.2 says construction "signals" on a
   provably empty span without naming an exception class. Resolution: a
   plain `Error` with a descriptive message; tests assert `raise: Error`.

## Verification audit

```
sprint: 0
date: 2026-07-18T23:50:28Z
toolchain: GNU Smalltalk version 3.2.5
PARLEY-SEED: 20260718
PARLEY-VERIFY: PASS seed=20260718 run=87 passed=87 failed=0 errors=0
```

Repeatability: two runs with `--seed 20260718` produced identical
`PARLEY-VERIFY` lines; the suite also passes with `--seed 1` and
`--seed 987654321`.

## Toolchain

```
GNU Smalltalk version 3.2.5
```
