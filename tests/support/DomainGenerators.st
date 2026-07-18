"Parley Sprint 0 — seeded random generators for the axiomatic law suites.

 Deterministic by construction: a private Park–Miller linear congruential
 generator guarantees the same seed yields a bit-for-bit identical sequence
 on every run. The seed is read from the PARLEY_SEED environment variable
 (injected by scripts/verify-sprint.sh).

 Version components are drawn from 0..9 on purpose — small so that
 collisions and range adjacency occur frequently (domain-model.md §5)."

Namespace current: Parley.

Object subclass: DomainGenerators [
    | state |

    <comment: 'Seeded pseudo-random generators for Version, VersionRange and
VersionConstraint test data, plus the normal-form invariant check used by
the law suites. Deterministic under a fixed seed.'>

    DomainGenerators class >> seed: anInteger [
        "Answer a generator whose sequence is fully determined by anInteger."
        ^self new initSeed: anInteger
    ]

    DomainGenerators class >> fromEnvironment [
        "Answer a generator seeded from PARLEY_SEED (harness-injected),
         falling back to the documented default seed."
        | raw |
        raw := Smalltalk getenv: 'PARLEY_SEED'.
        (raw isNil or: [raw isEmpty]) ifTrue: [raw := '20260718'].
        ^self seed: raw asInteger
    ]

    initSeed: anInteger [
        "Private — establish the LCG state. Never zero."
        state := (anInteger abs \\ 2147483646) + 1
    ]

    nextInteger: n [
        "Answer a pseudo-random integer in 0 .. n-1."
        state := state * 16807 \\ 2147483647.
        ^state \\ n
    ]

    nextBoolean [
        ^(self nextInteger: 2) = 1
    ]

    nextComponent [
        "Version components stay in 0..9 so collisions and adjacency
         occur frequently."
        ^self nextInteger: 10
    ]

    nextVersion [
        ^Version
            major: self nextComponent
            minor: self nextComponent
            patch: self nextComponent
    ]

    nextRange [
        "Answer a random non-empty VersionRange; either bound may be nil
         (unbounded)."
        | lo hi incLo incHi swap |
        lo := (self nextInteger: 5) = 0 ifTrue: [nil] ifFalse: [self nextVersion].
        hi := (self nextInteger: 5) = 0 ifTrue: [nil] ifFalse: [self nextVersion].
        incLo := self nextBoolean.
        incHi := self nextBoolean.
        lo isNil ifTrue: [incLo := false].
        hi isNil ifTrue: [incHi := false].
        (lo notNil and: [hi notNil]) ifTrue: [
            lo > hi ifTrue: [swap := lo. lo := hi. hi := swap].
            (lo = hi and: [(incLo and: [incHi]) not])
                ifTrue: [incLo := true. incHi := true]].
        ^VersionRange from: lo to: hi includeMin: incLo includeMax: incHi
    ]

    nextPrimitiveConstraint [
        "Answer one of the primitive constraint shapes."
        | pick v lo hi swap |
        pick := self nextInteger: 7.
        v := self nextVersion.
        pick = 0 ifTrue: [^VersionConstraint any].
        pick = 1 ifTrue: [^VersionConstraint none].
        pick = 2 ifTrue: [^VersionConstraint exactly: v].
        pick = 3 ifTrue: [^VersionConstraint atLeast: v].
        pick = 4 ifTrue: [^VersionConstraint lessThan: v].
        pick = 5 ifTrue: [
            lo := v.
            hi := self nextVersion.
            lo > hi ifTrue: [swap := lo. lo := hi. hi := swap].
            lo = hi ifTrue: [^VersionConstraint exactly: lo].
            ^VersionConstraint from: lo to: hi].
        ^VersionConstraint compatibleWith: v
    ]

    nextConstraint [
        "Answer a constraint built by random algebra over random primitive
         constraints (domain-model.md §5)."
        ^self nextConstraintDepth: 3
    ]

    nextConstraintDepth: depth [
        | pick |
        (depth <= 0 or: [(self nextInteger: 3) = 0])
            ifTrue: [^self nextPrimitiveConstraint].
        pick := self nextInteger: 3.
        pick = 0 ifTrue: [
            ^(self nextConstraintDepth: depth - 1)
                union: (self nextConstraintDepth: depth - 1)].
        pick = 1 ifTrue: [
            ^(self nextConstraintDepth: depth - 1)
                intersect: (self nextConstraintDepth: depth - 1)].
        ^(self nextConstraintDepth: depth - 1) complement
    ]

    lower: aRange precedes: otherRange [
        "True when aRange's lower bound sorts at or before otherRange's
         (a nil min sorts first)."
        aRange min isNil ifTrue: [^true].
        otherRange min isNil ifTrue: [^false].
        ^aRange min <= otherRange min
    ]

    isNormalForm: aConstraint [
        "True when aConstraint's internal ranges are sorted by lower bound
         and pairwise disjoint and non-adjacent (domain-model.md §3.1)."
        | rs |
        rs := aConstraint ranges.
        1 to: rs size - 1 do: [:i |
            (self lower: (rs at: i) precedes: (rs at: i + 1)) ifFalse: [^false]].
        1 to: rs size do: [:i |
            i + 1 to: rs size do: [:j |
                ((rs at: i) coalescesWith: (rs at: j)) ifTrue: [^false]]].
        ^true
    ]
]

Namespace current: Smalltalk.
