"Parley Sprint 0 — acceptance scenarios S1-S10 from GitHub issue #1.
 Each scenario Sn maps to exactly one selector starting with testSn_
 (enforced by the wrap traceability gate)."

Namespace current: Parley.

TestCase subclass: Sprint0AcceptanceTest [
    | gen |

    <comment: 'Acceptance scenarios for the Sprint 0 keystone domain model.'>

    setUp [
        gen := DomainGenerators fromEnvironment
    ]

    v: aString [
        ^Version fromString: aString
    ]

    testS1_zeroPaddedCanonicalPrinting [
        "S1 — '1.2' parses and prints as '1.2.0'."
        self assert: (Version fromString: '1.2') printString = '1.2.0'
    ]

    testS2_malformedInputSignalsVersionFormatError [
        "S2 — malformed inputs signal VersionFormatError; no version answered."
        #('1.0.0-alpha' 'v1.0.0' '1.0.0+build' '') do: [:each |
            self should: [Version fromString: each] raise: VersionFormatError]
    ]

    testS3_numericComparisonAndHash [
        "S3 — 1.2.3 < 1.10.0 numerically; equal versions share = and hash."
        | a b |
        self assert: (self v: '1.2.3') < (self v: '1.10.0').
        a := self v: '2.4.6'.
        b := self v: '2.4.6'.
        self assert: a = b.
        self assert: a hash = b hash
    ]

    testS4_halfOpenRangeBounds [
        "S4 — [1.0.0, 2.0.0): inclusive lower, exclusive upper."
        | r |
        r := VersionRange
            from: (self v: '1.0.0') to: (self v: '2.0.0')
            includeMin: true includeMax: false.
        self assert: (r allows: (self v: '1.0.0')).
        self deny: (r allows: (self v: '2.0.0')).
        self assert: (r allows: (self v: '1.5.0'))
    ]

    testS5_disjointRangeIntersectionIsNil [
        "S5 — [1.0.0, 2.0.0) intersect [3.0.0, 4.0.0) answers nil."
        | a b |
        a := VersionRange
            from: (self v: '1.0.0') to: (self v: '2.0.0')
            includeMin: true includeMax: false.
        b := VersionRange
            from: (self v: '3.0.0') to: (self v: '4.0.0')
            includeMin: true includeMax: false.
        self assert: (a intersect: b) isNil
    ]

    testS6_adjacentRangesCoalesceInConstraintLayer [
        "S6 — [1.0.0, 2.0.0) and [2.0.0, 3.0.0) coalesce into [1.0.0, 3.0.0)."
        | c |
        c := (VersionConstraint from: (self v: '1.0.0') to: (self v: '2.0.0'))
            union: (VersionConstraint from: (self v: '2.0.0') to: (self v: '3.0.0')).
        self assert: c
            = (VersionConstraint from: (self v: '1.0.0') to: (self v: '3.0.0')).
        self assert: c ranges size = 1.
        self assert: c printString = '>=1.0.0 <3.0.0'
    ]

    testS7_caretIsCargoExact [
        "S7 — ^0.4.2 allows exactly >=0.4.2 <0.5.0 and prints expanded."
        | c |
        c := VersionConstraint fromString: '^0.4.2'.
        self assert: (c allows: (self v: '0.4.2')).
        self assert: (c allows: (self v: '0.4.9')).
        self deny: (c allows: (self v: '0.5.0')).
        self deny: (c allows: (self v: '0.4.1')).
        self assert: c printString = '>=0.4.2 <0.5.0'
    ]

    testS8_roundTripIdentity [
        "S8 — printString then fromString: answers an equal constraint."
        1 to: 100 do: [:i |
            | c |
            c := gen nextConstraint.
            self assert: (VersionConstraint fromString: c printString) = c]
    ]

    testS9_normalFormInvariantUnderAlgebra [
        "S9 — every operation leaves ranges sorted, disjoint, non-adjacent."
        1 to: 100 do: [:i |
            | a b |
            a := gen nextConstraint.
            b := gen nextConstraint.
            self assert: (gen isNormalForm: (a union: b)).
            self assert: (gen isNormalForm: (a intersect: b)).
            self assert: (gen isNormalForm: a complement).
            self assert: (gen isNormalForm: (a difference: b))]
    ]

    testS10_lawsHoldAndRunsAreRepeatable [
        "S10 — the algebraic laws hold over seeded random pairs, and two
         generators with the same seed yield identical sequences."
        | g1 g2 |
        g1 := DomainGenerators seed: 424242.
        g2 := DomainGenerators seed: 424242.
        1 to: 100 do: [:i |
            | a b a2 b2 vv both |
            a := g1 nextConstraint.
            b := g1 nextConstraint.
            a2 := g2 nextConstraint.
            b2 := g2 nextConstraint.
            self assert: a = a2.
            self assert: b = b2.
            self assert: (a union: b) = (b union: a).
            self assert: ((a union: b) union: a2) = (a union: (b union: a2)).
            self assert: (a intersect: b) = (b intersect: a).
            self assert: (a union: b) complement
                = (a complement intersect: b complement).
            self assert: (a intersect: b) complement
                = (a complement union: b complement).
            self assert: a complement complement = a.
            self assert: (a union: (a intersect: b)) = a.
            self assert: (a intersect: VersionConstraint any) = a.
            self assert: (a intersect: VersionConstraint none)
                = VersionConstraint none.
            vv := g1 nextVersion.
            self assert: vv = g2 nextVersion.
            both := (a allows: vv) and: [b allows: vv].
            self assert: ((a intersect: b) allows: vv) = both]
    ]
]

Namespace current: Smalltalk.
