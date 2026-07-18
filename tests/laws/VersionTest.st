"Parley Sprint 0 — Version laws: parsing, rejection, comparison, printing.
 Spec: docs/design/domain-model.md §1 and §5."

Namespace current: Parley.

TestCase subclass: VersionTest [
    | gen |

    <comment: 'Axiomatic laws for the Version value object.'>

    setUp [
        gen := DomainGenerators fromEnvironment
    ]

    testParsingThreeComponents [
        | v |
        v := Version fromString: '1.2.3'.
        self assert: v major = 1.
        self assert: v minor = 2.
        self assert: v patch = 3
    ]

    testParsingPadsMissingComponents [
        | v |
        v := Version fromString: '1'.
        self assert: v major = 1.
        self assert: v minor = 0.
        self assert: v patch = 0.
        v := Version fromString: '1.2'.
        self assert: v major = 1.
        self assert: v minor = 2.
        self assert: v patch = 0
    ]

    testParsingZeroComponents [
        | v |
        v := Version fromString: '0.0.0'.
        self assert: v major = 0.
        self assert: v minor = 0.
        self assert: v patch = 0
    ]

    testRejectsPrereleaseTag [
        self should: [Version fromString: '1.0.0-alpha'] raise: VersionFormatError
    ]

    testRejectsBuildMetadata [
        self should: [Version fromString: '1.0.0+build'] raise: VersionFormatError
    ]

    testRejectsLeadingV [
        self should: [Version fromString: 'v1.0.0'] raise: VersionFormatError
    ]

    testRejectsEmptyString [
        self should: [Version fromString: ''] raise: VersionFormatError
    ]

    testRejectsEmptyComponent [
        self should: [Version fromString: '1..2'] raise: VersionFormatError
    ]

    testRejectsWhitespace [
        self should: [Version fromString: ' 1.0.0'] raise: VersionFormatError.
        self should: [Version fromString: '1.0.0 '] raise: VersionFormatError
    ]

    testRejectsNonDigits [
        self should: [Version fromString: '1.a.0'] raise: VersionFormatError.
        self should: [Version fromString: 'banana'] raise: VersionFormatError
    ]

    testRejectsTooManyComponents [
        self should: [Version fromString: '1.2.3.4'] raise: VersionFormatError
    ]

    testNumericNotLexicographicComparison [
        | small big |
        small := Version fromString: '1.2.3'.
        big := Version fromString: '1.10.0'.
        self assert: small < big.
        self deny: big < small
    ]

    testCanonicalPrintingAlwaysThreeComponents [
        self assert: (Version fromString: '1') printString = '1.0.0'.
        self assert: (Version fromString: '1.2') printString = '1.2.0'.
        self assert: (Version fromString: '1.2.3') printString = '1.2.3'
    ]

    testEqualityAndHashTogether [
        | a b |
        a := Version fromString: '1.2.3'.
        b := Version major: 1 minor: 2 patch: 3.
        self assert: a = b.
        self assert: a hash = b hash.
        self deny: a = (Version fromString: '1.2.4')
    ]

    testRandomizedComparisonMatchesTupleOrder [
        1 to: 200 do: [:i |
            | a b expectedLess |
            a := gen nextVersion.
            b := gen nextVersion.
            expectedLess := a major < b major
                or: [a major = b major
                    and: [a minor < b minor
                        or: [a minor = b minor and: [a patch < b patch]]]].
            self assert: (a < b) = expectedLess.
            self assert: (b > a) = expectedLess.
            self assert: (a >= b) = expectedLess not.
            self assert: (b <= a) = expectedLess not]
    ]

    testRandomizedEqualityConsistency [
        1 to: 200 do: [:i |
            | a b same |
            a := gen nextVersion.
            b := gen nextVersion.
            same := (a major = b major)
                and: [(a minor = b minor) and: [a patch = b patch]].
            self assert: (a = b) = same.
            same ifTrue: [self assert: a hash = b hash].
            self assert: ((a < b) or: [(a > b) or: [a = b]]).
            self deny: ((a < b) and: [a > b])]
    ]

    testRandomizedPrintParseIdentity [
        1 to: 200 do: [:i |
            | v |
            v := gen nextVersion.
            self assert: (Version fromString: v printString) = v]
    ]
]

Namespace current: Smalltalk.
