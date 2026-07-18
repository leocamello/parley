"Parley Sprint 0 — VersionRange laws: bounds, allows:, intersect:,
 coalescesWith: (exact adjacency rule), structural equality.
 Spec: docs/design/domain-model.md §2."

Namespace current: Parley.

TestCase subclass: VersionRangeTest [
    | gen |

    <comment: 'Axiomatic laws for the VersionRange span object.'>

    setUp [
        gen := DomainGenerators fromEnvironment
    ]

    v: aString [
        ^Version fromString: aString
    ]

    halfOpenFrom: loString to: hiString [
        ^VersionRange
            from: (self v: loString)
            to: (self v: hiString)
            includeMin: true
            includeMax: false
    ]

    testAllowsHonorsInclusiveLowerBound [
        | r |
        r := self halfOpenFrom: '1.0.0' to: '2.0.0'.
        self assert: (r allows: (self v: '1.0.0')).
        self assert: (r allows: (self v: '1.5.0')).
        self deny: (r allows: (self v: '0.9.9'))
    ]

    testAllowsHonorsExclusiveUpperBound [
        | r |
        r := self halfOpenFrom: '1.0.0' to: '2.0.0'.
        self deny: (r allows: (self v: '2.0.0')).
        self deny: (r allows: (self v: '2.0.1'))
    ]

    testAllowsHonorsExclusiveLowerBound [
        | r |
        r := VersionRange
            from: (self v: '1.0.0') to: (self v: '2.0.0')
            includeMin: false includeMax: true.
        self deny: (r allows: (self v: '1.0.0')).
        self assert: (r allows: (self v: '1.0.1')).
        self assert: (r allows: (self v: '2.0.0'))
    ]

    testNilBoundsMeanUnbounded [
        | r |
        r := VersionRange from: nil to: nil includeMin: false includeMax: false.
        self assert: (r allows: (self v: '0.0.0')).
        self assert: (r allows: (self v: '9.9.9')).
        r := VersionRange
            from: (self v: '1.0.0') to: nil includeMin: true includeMax: false.
        self assert: (r allows: (self v: '9.9.9')).
        self deny: (r allows: (self v: '0.9.9'))
    ]

    testDegenerateRangeAllowsExactlyItsVersion [
        | r |
        r := VersionRange
            from: (self v: '1.2.3') to: (self v: '1.2.3')
            includeMin: true includeMax: true.
        self assert: (r allows: (self v: '1.2.3')).
        self deny: (r allows: (self v: '1.2.2')).
        self deny: (r allows: (self v: '1.2.4'))
    ]

    testConstructionSignalsOnInvertedBounds [
        self
            should: [
                VersionRange
                    from: (self v: '2.0.0') to: (self v: '1.0.0')
                    includeMin: true includeMax: true]
            raise: Error
    ]

    testConstructionSignalsOnEqualBoundsWithOpenEnd [
        self
            should: [
                VersionRange
                    from: (self v: '1.0.0') to: (self v: '1.0.0')
                    includeMin: true includeMax: false]
            raise: Error.
        self
            should: [
                VersionRange
                    from: (self v: '1.0.0') to: (self v: '1.0.0')
                    includeMin: false includeMax: true]
            raise: Error
    ]

    testIntersectOverlappingRanges [
        | a b r |
        a := self halfOpenFrom: '1.0.0' to: '3.0.0'.
        b := self halfOpenFrom: '2.0.0' to: '4.0.0'.
        r := a intersect: b.
        self assert: r = (self halfOpenFrom: '2.0.0' to: '3.0.0')
    ]

    testIntersectDisjointRangesAnswersNil [
        | a b |
        a := self halfOpenFrom: '1.0.0' to: '2.0.0'.
        b := self halfOpenFrom: '3.0.0' to: '4.0.0'.
        self assert: (a intersect: b) isNil.
        self assert: (b intersect: a) isNil
    ]

    testIntersectTouchingAtExclusiveBoundIsNil [
        | a b |
        a := self halfOpenFrom: '1.0.0' to: '2.0.0'.
        b := self halfOpenFrom: '2.0.0' to: '3.0.0'.
        self assert: (a intersect: b) isNil
    ]

    testIntersectTouchingAtInclusiveBoundsIsDegenerate [
        | a b r |
        a := VersionRange
            from: (self v: '1.0.0') to: (self v: '2.0.0')
            includeMin: true includeMax: true.
        b := self halfOpenFrom: '2.0.0' to: '3.0.0'.
        r := a intersect: b.
        self assert: r notNil.
        self assert: (r allows: (self v: '2.0.0')).
        self deny: (r allows: (self v: '1.9.9')).
        self deny: (r allows: (self v: '2.0.1'))
    ]

    testIntersectResolvesInclusivityByAndOnEqualBounds [
        | a b r |
        a := VersionRange
            from: (self v: '1.0.0') to: (self v: '2.0.0')
            includeMin: true includeMax: true.
        b := self halfOpenFrom: '1.0.0' to: '2.0.0'.
        r := a intersect: b.
        self assert: r = (self halfOpenFrom: '1.0.0' to: '2.0.0')
    ]

    testNilBoundAlwaysLosesInIntersection [
        | a b r |
        a := VersionRange from: nil to: nil includeMin: false includeMax: false.
        b := self halfOpenFrom: '1.0.0' to: '2.0.0'.
        r := a intersect: b.
        self assert: r = b
    ]

    testCoalescesWithOverlappingRange [
        | a b |
        a := self halfOpenFrom: '1.0.0' to: '3.0.0'.
        b := self halfOpenFrom: '2.0.0' to: '4.0.0'.
        self assert: (a coalescesWith: b).
        self assert: (b coalescesWith: a)
    ]

    testCoalescesWithExactlyAdjacentRange [
        "[1,2) and [2,3] touch at 2 with an inclusive touching bound."
        | a b |
        a := self halfOpenFrom: '1.0.0' to: '2.0.0'.
        b := VersionRange
            from: (self v: '2.0.0') to: (self v: '3.0.0')
            includeMin: true includeMax: true.
        self assert: (a coalescesWith: b).
        self assert: (b coalescesWith: a)
    ]

    testDoesNotCoalesceWhenBothTouchingBoundsAreOpen [
        "[1,2) and (2,3] leave 2.0.0 in neither — no coalescing."
        | a b |
        a := self halfOpenFrom: '1.0.0' to: '2.0.0'.
        b := VersionRange
            from: (self v: '2.0.0') to: (self v: '3.0.0')
            includeMin: false includeMax: true.
        self deny: (a coalescesWith: b).
        self deny: (b coalescesWith: a)
    ]

    testDoesNotCoalesceAcrossAGap [
        | a b |
        a := self halfOpenFrom: '1.0.0' to: '2.0.0'.
        b := self halfOpenFrom: '3.0.0' to: '4.0.0'.
        self deny: (a coalescesWith: b).
        self deny: (b coalescesWith: a)
    ]

    testStructuralEqualityAndHash [
        | a b |
        a := self halfOpenFrom: '1.0.0' to: '2.0.0'.
        b := self halfOpenFrom: '1.0.0' to: '2.0.0'.
        self assert: a = b.
        self assert: a hash = b hash.
        self deny: a = (VersionRange
            from: (self v: '1.0.0') to: (self v: '2.0.0')
            includeMin: true includeMax: true).
        self deny: a = (self halfOpenFrom: '1.0.0' to: '2.0.1')
    ]

    testValidRangeIsNotEmpty [
        self deny: (self halfOpenFrom: '1.0.0' to: '2.0.0') isEmpty
    ]

    testRandomizedIntersectionMembershipConsistency [
        1 to: 200 do: [:i |
            | a b r v inBoth |
            a := gen nextRange.
            b := gen nextRange.
            r := a intersect: b.
            1 to: 5 do: [:j |
                v := gen nextVersion.
                inBoth := (a allows: v) and: [b allows: v].
                r isNil
                    ifTrue: [self deny: inBoth]
                    ifFalse: [self assert: (r allows: v) = inBoth]]]
    ]

    testRandomizedIntersectionIsCommutative [
        1 to: 200 do: [:i |
            | a b r1 r2 |
            a := gen nextRange.
            b := gen nextRange.
            r1 := a intersect: b.
            r2 := b intersect: a.
            r1 isNil
                ifTrue: [self assert: r2 isNil]
                ifFalse: [self assert: r1 = r2]]
    ]
]

Namespace current: Smalltalk.
