"Parley Sprint 2 — acceptance scenarios S1-S17 from GitHub issue #4.
 Each scenario Sn maps to exactly one selector starting with testSn_
 (enforced by the wrap traceability gate)."

Namespace current: Parley.

TestCase subclass: Sprint2AcceptanceTest [

    <comment: 'Acceptance scenarios for Sprint 2: the pure resolution
engine — provenance, backtracking, conflict narration — and the
lockfile schema.'>

    constraint: aString [
        ^VersionConstraint fromString: aString
    ]

    version: aString [
        ^Version fromString: aString
    ]

    resolve: aManifest against: aSnapshot [
        ^ResolverFixtures resolve: aManifest against: aSnapshot
    ]

    lockBytesFor: aResolution [
        | stream |
        stream := WriteStream on: String new.
        IndexEntryWriter writeLock: aResolution on: stream.
        ^stream contents
    ]

    docCDerivedNode [
        "The Doc C §3 example node built from its two dependency edges."
        | extA extB |
        extA := Incompatibility package: 'kernel-a' version: (self version: '1.2.0')
            dependsOn: 'kernel-c' constraint: (self constraint: '>=1.0 <2.0').
        extB := Incompatibility package: 'kernel-b' version: (self version: '2.0.0')
            dependsOn: 'kernel-c' constraint: (self constraint: '>=2.0 <3.0').
        ^Incompatibility conflictFrom: (Array
            with: (Term package: 'kernel-c'
                constraint: (self constraint: '>=1.0 <2.0')
                positive: true origin: extA)
            with: (Term package: 'kernel-c'
                constraint: (self constraint: '>=2.0 <3.0')
                positive: true origin: extB))
    ]

    testS1_termIsAnImmutablePolarityCarryingValue [
        | t n other |
        t := Term package: 'kernel-c'
            constraint: (self constraint: '>=1.0 <2.0') positive: true.
        n := t negated.
        self assert: (n isKindOf: Term).
        self deny: n == t.
        self assert: n package = 'kernel-c'.
        self assert: n constraint = (self constraint: '>=1.0 <2.0').
        self deny: n isPositive.
        self assert: t isPositive
            description: 'the original term must be unchanged'.
        other := Term package: 'kernel-c'
            constraint: (self constraint: '>=1.0 <2.0') positive: true.
        self assert: t = other.
        self assert: t hash = other hash
    ]

    testS2_externalDependencyIncompatibilityFromIndexEdge [
        | inc |
        inc := Incompatibility package: 'kernel-a' version: (self version: '1.2.0')
            dependsOn: 'kernel-c' constraint: (self constraint: '>=1.0 <2.0').
        self assert: inc isExternal.
        self deny: inc isDerived.
        self assert: inc cause = #dependency.
        self assert: inc terms size = 2.
        self deny: (ResolverFixtures in: inc terms
            findPackage: 'kernel-a' positive: true
            constraint: (VersionConstraint exactly: (self version: '1.2.0'))) isNil.
        self deny: (ResolverFixtures in: inc terms
            findPackage: 'kernel-c' positive: false
            constraint: (self constraint: '>=1.0 <2.0')) isNil
    ]

    testS3_externalNoVersionsIncompatibility [
        | blamed inc |
        blamed := Array
            with: (Term package: 'a' constraint: VersionConstraint any positive: true)
            with: (Term package: 'a' constraint: (self constraint: '^9.0') positive: true).
        inc := Incompatibility noVersionsOf: 'a'
            matching: (self constraint: '^9.0')
            blamedOn: blamed.
        self assert: inc isExternal.
        self assert: inc cause = #noVersions.
        self assert: inc terms asOrderedCollection = blamed asOrderedCollection
    ]

    testS4_derivedIncompatibilitiesFormWalkableDerivationTree [
        | node leaves |
        node := self docCDerivedNode.
        self assert: node isDerived.
        self deny: node isExternal.
        self assert: node cause size = 2.
        leaves := ResolverFixtures externalLeavesOf: node.
        self assert: leaves size = 2.
        self assert: (leaves conform: [:l | l isExternal and: [l cause = #dependency]])
    ]

    testS5_singleNodeNarrationIsCanonical [
        self assert: self docCDerivedNode printString
            = 'because kernel-a 1.2.0 depends on kernel-c >=1.0.0 <2.0.0 and kernel-b 2.0.0 depends on kernel-c >=2.0.0 <3.0.0, kernel-a 1.2.0 and kernel-b 2.0.0 are incompatible'
    ]

    testS6_recordTermAnswersNilThenCollapseWithProvenance [
        | ledger first second collapse |
        first := Term package: 'kernel-c'
            constraint: (self constraint: '>=1.0 <2.0') positive: true.
        second := Term package: 'kernel-c'
            constraint: (self constraint: '>=2.0 <3.0') positive: true.
        ledger := ConstraintLedger new.
        self assert: (ledger recordTerm: first) isNil.
        collapse := ledger recordTerm: second.
        self assert: (collapse isKindOf: Incompatibility).
        self assert: collapse terms size = 2.
        self deny: (ResolverFixtures in: collapse terms
            findPackage: 'kernel-c' positive: true
            constraint: (self constraint: '>=1.0 <2.0')) isNil.
        self deny: (ResolverFixtures in: collapse terms
            findPackage: 'kernel-c' positive: true
            constraint: (self constraint: '>=2.0 <3.0')) isNil
    ]

    testS7_copyOnDescendLedgerCopiesAreIndependent [
        | parent child |
        parent := ConstraintLedger new.
        parent recordTerm: (Term package: 'kernel-c'
            constraint: (self constraint: '>=1.0 <3.0') positive: true).
        child := parent copy.
        child recordTerm: (Term package: 'kernel-c'
            constraint: (self constraint: '^2.0') positive: true).
        self assert: (child constraintFor: 'kernel-c')
            = (self constraint: '>=2.0 <3.0').
        self assert: (parent constraintFor: 'kernel-c')
            = (self constraint: '>=1.0 <3.0').
        self assert: (parent termsFor: 'kernel-c') size = 1
    ]

    testS8_ledgerDefaults [
        | ledger |
        ledger := ConstraintLedger new.
        self assert: (ledger constraintFor: 'untouched') = VersionConstraint any.
        self assert: (ledger termsFor: 'untouched') isEmpty
    ]

    testS9_trivialResolutionPicksHighestAllowedVersions [
        | result |
        result := self resolve: ResolverFixtures trivialRoot
            against: ResolverFixtures trivialSnapshot.
        self assert: result isResolution.
        self assert: (result versionOf: 'kernel-a') = (self version: '1.2.0').
        self assert: (result sha256Of: 'kernel-a') = 'aa12'.
        self assert: result packageNames size = 1.
        self deny: (result packageNames includes: 'my-app')
    ]

    testS10_determinismByteIdenticalLockfile [
        | r1 r2 |
        r1 := self resolve: ResolverFixtures diamondRoot
            against: ResolverFixtures satisfiableDiamondSnapshot.
        r2 := self resolve: ResolverFixtures diamondRoot
            against: ResolverFixtures satisfiableDiamondSnapshot.
        self assert: r1 = r2.
        self assert: (self lockBytesFor: r1) = (self lockBytesFor: r2)
    ]

    testS11_satisfiableDiamondResolvesThroughIntersection [
        | result |
        result := self resolve: ResolverFixtures diamondRoot
            against: ResolverFixtures satisfiableDiamondSnapshot.
        self assert: result isResolution.
        self assert: (result versionOf: 'a') = (self version: '1.0.0').
        self assert: (result versionOf: 'b') = (self version: '1.0.0').
        self assert: (result versionOf: 'c') = (self version: '2.4.0')
    ]

    testS12_unsatisfiableDiamondAnswersConflictReportBlamingBothEdges [
        | result leaves edgeA edgeB |
        result := self resolve: ResolverFixtures diamondRoot
            against: ResolverFixtures unsatisfiableDiamondSnapshot.
        self deny: result isResolution.
        self assert: (result isKindOf: ConflictReport).
        leaves := ResolverFixtures externalLeavesOf: result root.
        edgeA := leaves detect: [:l |
            l cause = #dependency and: [
                (ResolverFixtures in: l terms
                    findPackage: 'c' positive: false
                    constraint: (self constraint: '^1.0')) notNil]]
            ifNone: [nil].
        edgeB := leaves detect: [:l |
            l cause = #dependency and: [
                (ResolverFixtures in: l terms
                    findPackage: 'c' positive: false
                    constraint: (self constraint: '^2.0')) notNil]]
            ifNone: [nil].
        self deny: edgeA isNil.
        self deny: edgeB isNil
    ]

    testS13_backtrackingRecoversFromGreedyFailure [
        | result |
        result := self resolve: ResolverFixtures backtrackingRoot
            against: ResolverFixtures backtrackingSnapshot.
        self assert: result isResolution.
        self assert: (result versionOf: 'a') = (self version: '1.0.0').
        self assert: (result versionOf: 'b') = (self version: '1.0.0')
    ]

    testS14_smallestDomainFirstSelectionIsObservable [
        | result leaves noVersions |
        result := self resolve: ResolverFixtures domainOrderRoot
            against: ResolverFixtures domainOrderSnapshot.
        self deny: result isResolution.
        leaves := ResolverFixtures externalLeavesOf: result root.
        noVersions := leaves detect: [:l | l cause = #noVersions] ifNone: [nil].
        self deny: noVersions isNil.
        self deny: (ResolverFixtures in: noVersions terms
            findPackage: 'a' positive: true
            constraint: VersionConstraint any) isNil
            description: 'the root''s contributing term must be blamed'.
        self deny: (ResolverFixtures in: noVersions terms
            findPackage: 'a' positive: true
            constraint: (self constraint: '^9.0')) isNil
            description: 'b 1.0.0''s contributing term must be blamed'
    ]

    testS15_conflictReportNarratesRecursivelyAndAnswersLiveMessages [
        | report nl expected |
        report := self resolve: ResolverFixtures diamondRoot
            against: ResolverFixtures unsatisfiableDiamondSnapshot.
        nl := String with: Character nl.
        expected :=
            'because a 1.0.0 depends on c >=1.0.0 <2.0.0 and b 1.0.0 depends on c >=2.0.0 <3.0.0, a 1.0.0 and b 1.0.0 are incompatible', nl,
            'because a 1.0.0 and b 1.0.0 are incompatible, b >=1.0.0 <2.0.0 is incompatible', nl,
            'because b >=1.0.0 <2.0.0 is incompatible, a >=1.0.0 <2.0.0 is incompatible'.
        self assert: report printString = expected.
        self assert: (report root isKindOf: Incompatibility).
        self assert: report isDerived.
        self deny: report isExternal.
        self assert: report cause = report root cause.
        self assert: report terms = report root terms
    ]

    testS16_canonicalLockfileBytes [
        | resolution expected |
        resolution := self resolve: ResolverFixtures diamondRoot
            against: ResolverFixtures satisfiableDiamondSnapshot.
        expected := '#(#''parley-lock'' 1 #root ''my-app'' #packages #(#(''a'' ''1.0.0'' #sha256 ''ab12'') #(''b'' ''1.0.0'' #sha256 ''cd34'') #(''c'' ''2.4.0'' #sha256 ''ef56'')))',
            (String with: Character nl).
        self assert: (self lockBytesFor: resolution) = expected
    ]

    testS17_lockArtifactsReadBackResolutionNeverFetches [
        | resolution parsed packages trapped |
        resolution := self resolve: ResolverFixtures diamondRoot
            against: ResolverFixtures satisfiableDiamondSnapshot.
        parsed := IndexEntryReader readFrom:
            (ReadStream on: (self lockBytesFor: resolution)).
        self assert: (parsed at: 1) = #'parley-lock'.
        packages := parsed at: 6.
        self assert: packages size = resolution packageNames size.
        packages do: [:entry |
            self assert: (resolution versionOf: (entry at: 1))
                = (Version fromString: (entry at: 2)).
            self assert: (resolution sha256Of: (entry at: 1)) = (entry at: 4)].
        trapped := self resolve: ResolverFixtures diamondRoot
            against: (FetchTrapSnapshot around:
                ResolverFixtures satisfiableDiamondSnapshot).
        self assert: trapped isResolution.
        self assert: trapped = resolution
    ]
]

Namespace current: Smalltalk.
