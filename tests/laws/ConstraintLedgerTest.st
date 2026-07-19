"Parley Sprint 2 — ConstraintLedger laws (Doc C §4: never intersect
 anonymously).

 recordTerm: answers nil while the running intersection stays satisfiable
 and the collapse Incompatibility (built from the accumulation's
 contributing terms — hard ban 6) the moment it empties. Untouched
 packages default to VersionConstraint any / no terms. Copies share
 immutable accumulation values but grow independently (copy-on-descend)."

Namespace current: Parley.

TestCase subclass: ConstraintLedgerTest [

    <comment: 'Law suite for the provenance-preserving constraint ledger:
nil-then-collapse recording, defaults, accumulation value semantics and
copy-on-descend independence.'>

    constraint: aString [
        ^VersionConstraint fromString: aString
    ]

    term: aName constraint: aString [
        ^Term package: aName constraint: (self constraint: aString) positive: true
    ]

    testRecordTermAnswersNilWhileSatisfiable [
        | ledger |
        ledger := ConstraintLedger new.
        self assert: (ledger recordTerm:
            (self term: 'kernel-c' constraint: '>=1.0 <3.0')) isNil.
        self assert: (ledger recordTerm:
            (self term: 'kernel-c' constraint: '^2.0')) isNil.
        self assert: (ledger constraintFor: 'kernel-c')
            = (self constraint: '>=2.0 <3.0')
    ]

    testRecordTermAnswersCollapseIncompatibilityWithBothContributingTerms [
        | ledger first second collapse found |
        first := self term: 'kernel-c' constraint: '>=1.0 <2.0'.
        second := self term: 'kernel-c' constraint: '>=2.0 <3.0'.
        ledger := ConstraintLedger new.
        self assert: (ledger recordTerm: first) isNil.
        collapse := ledger recordTerm: second.
        self deny: collapse isNil.
        self assert: (collapse isKindOf: Incompatibility).
        self assert: collapse terms size = 2.
        found := ResolverFixtures in: collapse terms
            findPackage: 'kernel-c' positive: true
            constraint: (self constraint: '>=1.0 <2.0').
        self deny: found isNil.
        found := ResolverFixtures in: collapse terms
            findPackage: 'kernel-c' positive: true
            constraint: (self constraint: '>=2.0 <3.0').
        self deny: found isNil
    ]

    testCollapseCarriesTheOriginIncompatibilitiesAsItsCause [
        "Provenance rides along: when the recorded terms carry origin
         edges, the collapse node's cause is exactly the parent pair."
        | edgeA edgeB ledger collapse |
        edgeA := Incompatibility package: 'a' version: (Version fromString: '1.0.0')
            dependsOn: 'c' constraint: (self constraint: '^1.0').
        edgeB := Incompatibility package: 'b' version: (Version fromString: '1.0.0')
            dependsOn: 'c' constraint: (self constraint: '^2.0').
        ledger := ConstraintLedger new.
        ledger recordTerm: (Term package: 'c'
            constraint: (self constraint: '^1.0') positive: true origin: edgeA).
        collapse := ledger recordTerm: (Term package: 'c'
            constraint: (self constraint: '^2.0') positive: true origin: edgeB).
        self assert: collapse isDerived.
        self assert: collapse cause size = 2.
        self assert: (collapse cause includes: edgeA).
        self assert: (collapse cause includes: edgeB)
    ]

    testUntouchedPackageDefaults [
        | ledger |
        ledger := ConstraintLedger new.
        self assert: (ledger constraintFor: 'never-seen') = VersionConstraint any.
        self assert: (ledger termsFor: 'never-seen') isEmpty
    ]

    testTermsForAnswersTheContributingTermsInRecordingOrder [
        | ledger first second terms |
        first := self term: 'kernel-c' constraint: '>=1.0 <3.0'.
        second := self term: 'kernel-c' constraint: '^2.0'.
        ledger := ConstraintLedger new.
        ledger recordTerm: first.
        ledger recordTerm: second.
        terms := (ledger termsFor: 'kernel-c') asOrderedCollection.
        self assert: terms size = 2.
        self assert: terms first = first.
        self assert: terms last = second
    ]

    testCopyOnDescendCopiesGrowIndependently [
        | parent child |
        parent := ConstraintLedger new.
        parent recordTerm: (self term: 'kernel-c' constraint: '>=1.0 <3.0').
        child := parent copy.
        child recordTerm: (self term: 'kernel-c' constraint: '^2.0').
        self assert: (child constraintFor: 'kernel-c')
            = (self constraint: '>=2.0 <3.0').
        self assert: (parent constraintFor: 'kernel-c')
            = (self constraint: '>=1.0 <3.0')
            description: 'the parent ledger must be untouched by the copy'.
        self assert: (parent termsFor: 'kernel-c') size = 1.
        self assert: (child termsFor: 'kernel-c') size = 2
    ]

    testCopyOnDescendNewPackagesStayInTheCopy [
        | parent child |
        parent := ConstraintLedger new.
        parent recordTerm: (self term: 'kernel-a' constraint: '^1.0').
        child := parent copy.
        child recordTerm: (self term: 'kernel-b' constraint: '^1.0').
        self assert: (parent constraintFor: 'kernel-b') = VersionConstraint any.
        self assert: (parent termsFor: 'kernel-b') isEmpty.
        self assert: (child constraintFor: 'kernel-b') = (self constraint: '^1.0')
    ]

    testUndecidedPackagesGivenAPartialAssignment [
        | ledger partial undecided |
        ledger := ConstraintLedger new.
        ledger recordTerm: (self term: 'kernel-a' constraint: '^1.0').
        ledger recordTerm: (self term: 'kernel-b' constraint: '^1.0').
        partial := Dictionary new.
        partial at: 'kernel-a' put: (Version fromString: '1.2.0').
        undecided := ledger undecidedPackagesGiven: partial.
        self assert: (undecided includes: 'kernel-b').
        self deny: (undecided includes: 'kernel-a')
    ]
]

Namespace current: Smalltalk.
