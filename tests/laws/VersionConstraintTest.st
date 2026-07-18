"Parley Sprint 0 — VersionConstraint laws: the set algebra (AGENTS.md §7
 laws 1-8), the caret table, canonical rendering, the fromString: grammar,
 and randomized round-trip identity.
 Spec: docs/design/domain-model.md §3 and §5."

Namespace current: Parley.

TestCase subclass: VersionConstraintTest [
    | gen |

    <comment: 'Axiomatic laws for the VersionConstraint keystone.'>

    setUp [
        gen := DomainGenerators fromEnvironment
    ]

    v: aString [
        ^Version fromString: aString
    ]

    assertNormalForm: aConstraint [
        self assert: (gen isNormalForm: aConstraint)
    ]

    "---- law 1: commutativity ----"

    testLaw1CommutativityRandomized [
        1 to: 200 do: [:i |
            | a b |
            a := gen nextConstraint.
            b := gen nextConstraint.
            self assert: (a union: b) = (b union: a).
            self assert: (a intersect: b) = (b intersect: a)]
    ]

    "---- law 2: associativity ----"

    testLaw2AssociativityRandomized [
        1 to: 200 do: [:i |
            | a b c |
            a := gen nextConstraint.
            b := gen nextConstraint.
            c := gen nextConstraint.
            self assert: ((a union: b) union: c) = (a union: (b union: c)).
            self assert: ((a intersect: b) intersect: c)
                = (a intersect: (b intersect: c))]
    ]

    "---- law 3: De Morgan ----"

    testLaw3DeMorganRandomized [
        1 to: 200 do: [:i |
            | a b |
            a := gen nextConstraint.
            b := gen nextConstraint.
            self assert: (a union: b) complement
                = (a complement intersect: b complement).
            self assert: (a intersect: b) complement
                = (a complement union: b complement)]
    ]

    "---- law 4: double complement ----"

    testLaw4DoubleComplementRandomized [
        1 to: 200 do: [:i |
            | a |
            a := gen nextConstraint.
            self assert: a complement complement = a]
    ]

    testComplementOfExtremes [
        self assert: VersionConstraint any complement = VersionConstraint none.
        self assert: VersionConstraint none complement = VersionConstraint any
    ]

    "---- law 5: absorption ----"

    testLaw5AbsorptionRandomized [
        1 to: 200 do: [:i |
            | a b |
            a := gen nextConstraint.
            b := gen nextConstraint.
            self assert: (a union: (a intersect: b)) = a]
    ]

    "---- law 6: identity / annihilator ----"

    testLaw6IdentityAndAnnihilatorRandomized [
        1 to: 200 do: [:i |
            | a |
            a := gen nextConstraint.
            self assert: (a intersect: VersionConstraint any) = a.
            self assert: (a intersect: VersionConstraint none)
                = VersionConstraint none]
    ]

    "---- law 7: normalization invariant after every operation ----"

    testLaw7NormalizationInvariantRandomized [
        1 to: 200 do: [:i |
            | a b |
            a := gen nextConstraint.
            b := gen nextConstraint.
            self assertNormalForm: a.
            self assertNormalForm: b.
            self assertNormalForm: (a union: b).
            self assertNormalForm: (a intersect: b).
            self assertNormalForm: a complement.
            self assertNormalForm: (a difference: b)]
    ]

    "---- law 8: membership consistency ----"

    testLaw8MembershipConsistencyRandomized [
        1 to: 200 do: [:i |
            | a b both v |
            a := gen nextConstraint.
            b := gen nextConstraint.
            1 to: 5 do: [:j |
                v := gen nextVersion.
                both := (a allows: v) and: [b allows: v].
                self assert: ((a intersect: b) allows: v) = both.
                self assert: ((a union: b) allows: v)
                    = ((a allows: v) or: [b allows: v]).
                self assert: (a complement allows: v) = (a allows: v) not]]
    ]

    "---- structural identity of the normal form ----"

    testEqualDenotationsAreStructurallyIdentical [
        | a b |
        a := (VersionConstraint from: (self v: '1.0.0') to: (self v: '2.0.0'))
            union: (VersionConstraint from: (self v: '2.0.0') to: (self v: '3.0.0')).
        b := VersionConstraint from: (self v: '1.0.0') to: (self v: '3.0.0').
        self assert: a = b.
        self assert: a hash = b hash
    ]

    testAnyAndNoneAreLegalInstances [
        self assert: VersionConstraint none isEmpty.
        self deny: VersionConstraint none isAny.
        self assert: VersionConstraint any isAny.
        self deny: VersionConstraint any isEmpty.
        self assert: (VersionConstraint any allows: (self v: '5.5.5')).
        self deny: (VersionConstraint none allows: (self v: '5.5.5'))
    ]

    testExactPinIsDegenerateRange [
        | c |
        c := VersionConstraint exactly: (self v: '1.2.3').
        self assert: (c allows: (self v: '1.2.3')).
        self deny: (c allows: (self v: '1.2.2')).
        self deny: (c allows: (self v: '1.2.4'))
    ]

    testAtLeastAndLessThanBounds [
        | c |
        c := VersionConstraint atLeast: (self v: '1.0.0').
        self assert: (c allows: (self v: '1.0.0')).
        self assert: (c allows: (self v: '9.9.9')).
        self deny: (c allows: (self v: '0.9.9')).
        c := VersionConstraint lessThan: (self v: '1.0.0').
        self deny: (c allows: (self v: '1.0.0')).
        self assert: (c allows: (self v: '0.9.9'))
    ]

    testFromToIsHalfOpen [
        | c |
        c := VersionConstraint from: (self v: '1.0.0') to: (self v: '2.0.0').
        self assert: (c allows: (self v: '1.0.0')).
        self assert: (c allows: (self v: '1.9.9')).
        self deny: (c allows: (self v: '2.0.0'))
    ]

    "---- derived operations stay derived (semantics checks) ----"

    testDifferenceMembershipRandomized [
        1 to: 200 do: [:i |
            | a b d v |
            a := gen nextConstraint.
            b := gen nextConstraint.
            d := a difference: b.
            1 to: 5 do: [:j |
                v := gen nextVersion.
                self assert: (d allows: v)
                    = ((a allows: v) and: [(b allows: v) not])]]
    ]

    testIsSubsetOfRandomized [
        1 to: 200 do: [:i |
            | a b v |
            a := gen nextConstraint.
            b := gen nextConstraint.
            self assert: (a isSubsetOf: a).
            self assert: (VersionConstraint none isSubsetOf: a).
            self assert: (a isSubsetOf: VersionConstraint any).
            self assert: ((a intersect: b) isSubsetOf: a).
            (a isSubsetOf: b) ifTrue: [
                1 to: 5 do: [:j |
                    v := gen nextVersion.
                    (a allows: v) ifTrue: [self assert: (b allows: v)]]]]
    ]

    "---- caret table (§3.4), every row, via the string grammar ----"

    assertCaret: input allowsFrom: loString upTo: hiString [
        | c |
        c := VersionConstraint fromString: input.
        self assert: (c allows: (self v: loString)).
        self deny: (c allows: (self v: hiString)).
        self assert: c = (VersionConstraint
            from: (self v: loString) to: (self v: hiString))
    ]

    testCaretRow1MajorMinorPatch [
        self assertCaret: '^1.2.3' allowsFrom: '1.2.3' upTo: '2.0.0'
    ]

    testCaretRow2MajorMinor [
        self assertCaret: '^1.2' allowsFrom: '1.2.0' upTo: '2.0.0'
    ]

    testCaretRow3MajorOnly [
        self assertCaret: '^1' allowsFrom: '1.0.0' upTo: '2.0.0'
    ]

    testCaretRow4ZeroMajor [
        self assertCaret: '^0.2.3' allowsFrom: '0.2.3' upTo: '0.3.0'
    ]

    testCaretRow5ZeroMajorZeroMinor [
        self assertCaret: '^0.0.3' allowsFrom: '0.0.3' upTo: '0.0.4'
    ]

    testCaretRow6ZeroZero [
        self assertCaret: '^0.0' allowsFrom: '0.0.0' upTo: '0.1.0'
    ]

    testCaretRow7ZeroOnly [
        self assertCaret: '^0' allowsFrom: '0.0.0' upTo: '1.0.0'
    ]

    testCompatibleWithMatchesCaretForFullVersions [
        self assert: (VersionConstraint compatibleWith: (self v: '1.2.3'))
            = (VersionConstraint fromString: '^1.2.3').
        self assert: (VersionConstraint compatibleWith: (self v: '0.2.3'))
            = (VersionConstraint fromString: '^0.2.3').
        self assert: (VersionConstraint compatibleWith: (self v: '0.0.3'))
            = (VersionConstraint fromString: '^0.0.3')
    ]

    "---- canonical rendering (§3.5), every rule ----"

    testRenderRule1NoneAndAny [
        self assert: VersionConstraint none printString = 'none'.
        self assert: VersionConstraint any printString = '*'
    ]

    testRenderRule2DegenerateRange [
        self assert: (VersionConstraint exactly: (self v: '1.2.3')) printString
            = '=1.2.3'
    ]

    testRenderRule3SingleRangeComparatorPairs [
        self assert: (VersionConstraint
                from: (self v: '1.0.0') to: (self v: '2.0.0')) printString
            = '>=1.0.0 <2.0.0'.
        self assert: (VersionConstraint atLeast: (self v: '1.0.0')) printString
            = '>=1.0.0'.
        self assert: (VersionConstraint lessThan: (self v: '2.0.0')) printString
            = '<2.0.0'.
        self assert: (VersionConstraint fromString: '>0.4.2') printString
            = '>0.4.2'.
        self assert: (VersionConstraint fromString: '<=3.0.0') printString
            = '<=3.0.0'
    ]

    testRenderRule4MultipleRangesJoinedByUnionBars [
        | c |
        c := (VersionConstraint lessThan: (self v: '1.0.0'))
            union: (VersionConstraint atLeast: (self v: '2.0.0')).
        self assert: c printString = '<1.0.0 || >=2.0.0'
    ]

    testRenderRule5CaretSugarNeverRoundTrips [
        self assert: (VersionConstraint fromString: '^0.4.2') printString
            = '>=0.4.2 <0.5.0'
    ]

    testRenderRule5VersionsRenderCanonically [
        self assert: (VersionConstraint fromString: '>=1') printString
            = '>=1.0.0'
    ]

    "---- fromString: grammar (§3.6) ----"

    testParseStar [
        self assert: (VersionConstraint fromString: '*') = VersionConstraint any
    ]

    testParseBareVersionMeansExact [
        self assert: (VersionConstraint fromString: '1.2.3')
            = (VersionConstraint exactly: (self v: '1.2.3'))
    ]

    testParseExplicitEquals [
        self assert: (VersionConstraint fromString: '=1.2.3')
            = (VersionConstraint exactly: (self v: '1.2.3'))
    ]

    testParseComparatorsWithinClauseAreIntersected [
        self assert: (VersionConstraint fromString: '>=1.0.0 <2.0.0')
            = (VersionConstraint from: (self v: '1.0.0') to: (self v: '2.0.0'))
    ]

    testParseUnionBarsUnionClauses [
        | expected |
        expected := (VersionConstraint lessThan: (self v: '1.0.0'))
            union: (VersionConstraint atLeast: (self v: '2.0.0')).
        self assert: (VersionConstraint fromString: '<1.0.0 || >=2.0.0')
            = expected
    ]

    testParseAcceptsEverythingPrintOnEmits [
        "Total round-trip: the printed form of none must be readable too."
        self assert: (VersionConstraint fromString: 'none')
            = VersionConstraint none
    ]

    testParseContradictoryClauseIsNone [
        self assert: (VersionConstraint fromString: '>=2.0.0 <1.0.0')
            = VersionConstraint none
    ]

    testParseRejectsMalformedInput [
        self should: [VersionConstraint fromString: '']
            raise: ConstraintFormatError.
        self should: [VersionConstraint fromString: '>=']
            raise: ConstraintFormatError.
        self should: [VersionConstraint fromString: '^']
            raise: ConstraintFormatError.
        self should: [VersionConstraint fromString: 'banana']
            raise: ConstraintFormatError.
        self should: [VersionConstraint fromString: '>=x']
            raise: ConstraintFormatError.
        self should: [VersionConstraint fromString: '1.0.0-alpha']
            raise: ConstraintFormatError.
        self should: [VersionConstraint fromString: '1.0.0 ||']
            raise: ConstraintFormatError
    ]

    testRandomizedRoundTripIdentity [
        1 to: 200 do: [:i |
            | c |
            c := gen nextConstraint.
            self assert: (VersionConstraint fromString: c printString) = c]
    ]
]

Namespace current: Smalltalk.
