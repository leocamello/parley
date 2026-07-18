# Parley Design — The Keystone Domain Model & Set Algebra

> **Scope:** `Version`, `VersionRange`, `VersionConstraint`, and the two-level normal form. This is the Sprint 0 implementation target. All classes live in the `Parley` namespace; all follow structural immutability (zero public setters; class-side construction; operations answer new instances).

---

## 1. `Version`

An immutable value object for `major.minor.patch`.

### 1.1 Grammar & Parsing

- Accepted: one to three dot-separated non-negative decimal integer components. Missing components default to `0`: `'1'` → `1.0.0`, `'1.2'` → `1.2.0`.
- **Rejected with a clear error:** prerelease tags (`-alpha`), build metadata (`+build5`), leading `v`, whitespace, empty components, non-digits. The error message names the offending input and states that prerelease/build tags are unsupported in this version of Parley.
- Rationale: prerelease ordering is a bug farm; it is deferred *whole*, not half-built. `Version` comparison is the single change site if ever revisited.

### 1.2 Protocol

```smalltalk
Version class >> fromString: aString      "parse or signal VersionFormatError"
Version class >> major: a minor: b patch: c

"instance side"
major  minor  patch                       "accessors (read-only)"
< <= > >= = hash                          "= and hash ALWAYS together"
printOn: aStream                          "canonical: '1.2.3' — always three components"
```

Ordering is lexicographic on `(major, minor, patch)`. Canonical printing always emits all three components (`'1.0'` parses, but prints back as `'1.0.0'`).

---

## 2. `VersionRange`

One contiguous span of versions.

### 2.1 State

| ivar | meaning |
| --- | --- |
| `min` | lower bound `Version`, or `nil` = unbounded below |
| `max` | upper bound `Version`, or `nil` = unbounded above |
| `includeMin` | `true` = closed lower bound |
| `includeMax` | `true` = closed upper bound |

Explicit open/closed bounds are required: `>=1.0 <2.0` is half-open, and there is no "version just below 2.0.0" to fake it with.

### 2.2 Protocol

```smalltalk
VersionRange class >> from: lo to: hi includeMin: aBool includeMax: aBool
    "lo/hi may be nil; signals on a provably empty span (e.g. min > max,
     or min = max with either bound open)"

allows: aVersion          "bound checks honoring inclusivity"
intersect: aRange         "answers a VersionRange, or nil when disjoint"
coalescesWith: aRange     "true when overlapping OR exactly adjacent
                           (e.g. [1,2) and [2,3] touch at 2)"
isEmpty
= / hash                  "structural equality on all four ivars"
printOn: aStream          "see §3.5 rendering rules"
```

`allows:` reference implementation shape:

```smalltalk
allows: aVersion [
    (min notNil and: [
        includeMin ifTrue: [aVersion < min] ifFalse: [aVersion <= min]])
            ifTrue: [^false].
    (max notNil and: [
        includeMax ifTrue: [aVersion > max] ifFalse: [aVersion >= max]])
            ifTrue: [^false].
    ^true
]
```

`intersect:` takes the greater lower bound and lesser upper bound (a bound with `nil` always loses), resolving inclusivity by AND when bounds are equal; answers `nil` when the result is provably empty.

**Adjacency definition (used by normalization):** two ranges coalesce when they overlap, or when one's `max` equals the other's `min` and at least one of the touching bounds is inclusive. `[1,2)` and `[2,3]` coalesce into `[1,3]`; `[1,2)` and `(2,3]` do NOT (version 2.0.0 is in neither).

---

## 3. `VersionConstraint` — The Keystone

### 3.1 The Two-Level Normal Form

**NOT** a subclass hierarchy (`ExactConstraint`/`RangeConstraint`/`UnionConstraint` yields an N×N double-dispatch matrix for `intersect:`/`union:` and makes equality undecidable without normalization anyway) and **not** an interval tree (real constraints hold 1–2 ranges; trees are unwarranted machinery).

> **Invariant (assert in tests after every operation):** a `VersionConstraint` holds a sorted `Array` of disjoint, non-adjacent `VersionRange`s, ordered by lower bound (a `nil` min sorts first). All construction passes through `normalizing:`. Two constraints denoting the same version set are structurally identical.

Consequences:
- `=` is element-wise range comparison; `hash` follows.
- An exact pin is the degenerate range `[v, v]` (both bounds inclusive).
- `any` = one fully unbounded range; `none` = the empty array. Both are legal instances — never represent them as `nil`.
- `printOn:` renders one canonical form (§3.5), consumed directly by conflict explanations and serialization.

### 3.2 Construction

```smalltalk
VersionConstraint class >> any
VersionConstraint class >> none
VersionConstraint class >> exactly: aVersion
VersionConstraint class >> atLeast: aVersion            "[v, ∞)"
VersionConstraint class >> lessThan: aVersion           "(-∞, v)"
VersionConstraint class >> from: lo to: hi              "[lo, hi)  — half-open default"
VersionConstraint class >> compatibleWith: aVersion     "caret — §3.4"
VersionConstraint class >> fromString: aString          "§3.6 grammar"
VersionConstraint class >> normalizing: aRangeCollection
    "THE single construction funnel: sort by lower bound, drop empties,
     coalesce overlapping/adjacent ranges, answer canonical instance"
```

### 3.3 Algebra Protocol

| Message | Semantics | Implementation |
| --- | --- | --- |
| `allows: v` | membership | any range allows → true |
| `intersect: c` | ∩ | pairwise `VersionRange>>intersect:` over both range lists, then `normalizing:`. Naive O(n·m) is ACCEPTED — real n,m are 1–2; do not optimize |
| `union: c` | ∪ | concatenate both lists, `normalizing:` (sort + coalesce) |
| `complement` | ¬ | walk the gaps: emit a range before the first, between consecutive, and after the last, flipping bound inclusivity at each edge. `any complement = none`; `none complement = any` |
| `difference: c` | derived | `self intersect: c complement` |
| `isSubsetOf: c` | derived | `(self difference: c) isEmpty` |
| `isEmpty` | | ranges array is empty |
| `isAny` | | one range, both bounds nil |

The whole algebra rests on two primitives (`intersect:`, `complement`) plus normalization. Keep derived operations derived — do not hand-implement them.

### 3.4 Caret Semantics (Cargo-exact)

The leftmost nonzero component is the breaking-change boundary:

| Input | Expansion |
| --- | --- |
| `^1.2.3` | `[1.2.3, 2.0.0)` |
| `^1.2` | `[1.2.0, 2.0.0)` |
| `^1` | `[1.0.0, 2.0.0)` |
| `^0.2.3` | `[0.2.3, 0.3.0)` |
| `^0.0.3` | `[0.0.3, 0.0.4)` |
| `^0.0` | `[0.0.0, 0.1.0)` |
| `^0` | `[0.0.0, 1.0.0)` |

Parley itself is pre-1.0 software: it eats this dog food immediately.

### 3.5 Canonical Rendering (`printOn:`)

This IS the wire form (serialization rule; [manifest-and-serialization.md](manifest-and-serialization.md)). Rules, in order:

1. `none` → `'none'`. `isAny` → `'*'`.
2. A degenerate range `[v, v]` → `'=1.2.3'`.
3. Any other single range → comparator pair, minimal: `min` side `>=1.0.0` (inclusive) or `>1.0.0` (exclusive), omitted when `nil`; `max` side `<2.0.0` / `<=2.0.0`, omitted when `nil`; joined by one space. E.g. `'>=1.0.0 <2.0.0'`, `'>0.4.2'`, `'<=3.0.0'`.
4. Multiple ranges joined by `' || '` in normal-form order: `'<1.0.0 || >=2.0.0'`.
5. Versions render canonically (always three components). Sugar never round-trips: `^0.4.2` prints as `'>=0.4.2 <0.5.0'` — correct; sugar belongs at authoring time, normal form at rest.

### 3.6 Constraint String Grammar (`fromString:`)

```
constraint  := '*' | clause ( '||' clause )*
clause      := caret | comparators | bareVersion
caret       := '^' version                  (expansion per §3.4)
comparators := comparator ( WS comparator )+  | comparator
comparator  := ( '>=' | '>' | '<=' | '<' | '=' ) version
bareVersion := version                      (means exact: '=v')
version     := 1–3 dot-separated integers   (per §1.1)
```

Comparators within a clause are ANDed (intersected); `||` unions clauses. The parser MUST accept everything `printOn:` emits (total round-trip: `fromString:` ∘ `printString` = identity on constraints — add this as a randomized law). Malformed input signals `ConstraintFormatError` naming the offending token.

---

## 4. `Term`, `Incompatibility`, `Dependency` (definitions owned here; behavior specified in [resolver.md](resolver.md))

- **`Term`** — immutable `(package, VersionConstraint, isPositive)`. `negated` flips polarity; the constraint-level negation of a positive term's meaning is `constraint complement`.
- **`Incompatibility`** — immutable set of `Term`s + `cause`. External causes: `#dependency` (an edge read from an index entry), `#noVersions` (empty candidate set). Derived cause: the parent `Incompatibility` pair it was proved from. `printOn:` renders the human sentence for THIS node; full-tree narration lives in `ConflictReport` ([resolver.md](resolver.md)).
- **`Dependency`** — `(packageName, VersionConstraint)`; `satisfiedBy: aVersion` delegates to `constraint allows:`.

---

## 5. SUnit Requirements for This Doc

All laws from laws 1–8 in [architecture.md](architecture.md) §6 apply to these classes, plus:

- Caret expansion table (§3.4) as explicit example tests — every row.
- Rendering rules (§3.5) as explicit example tests — every rule.
- Randomized `fromString:` ∘ `printString` = identity.
- `Version` rejection tests: `'1.0.0-alpha'`, `'1.0.0+build'`, `'v1.0.0'`, `''`, `'1..2'` all signal `VersionFormatError`.
- The randomized generator: versions with components in `0..9` (small on purpose — collisions and adjacency must occur frequently), constraints built by random algebra over random primitive constraints, deterministic seed.
