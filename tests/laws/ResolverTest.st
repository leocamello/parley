"Parley Sprint 2 — Resolver laws (Doc C §5-§7; AGENTS.md §7 laws 11-12).

 The resolver is a pure function of (root manifest, immutable snapshot):
 same inputs always answer the identical Resolution and byte-identical
 lockfile. Resolution answers values, never search-loop exceptions.
 Failed resolutions answer live ConflictReport derivation trees whose
 narrated proofs render stably (pinned here)."

Namespace current: Parley.

TestCase subclass: ResolverTest [

    <comment: 'Law suite for the pure resolution engine: determinism and
byte-identical lockfiles, both diamond shapes, backtracking-exists,
smallest-domain-first observability, purity, and derivation-tree
inspection with pinned narration.'>

    resolve: aManifest against: aSnapshot [
        ^ResolverFixtures resolve: aManifest against: aSnapshot
    ]

    lockBytesFor: aResolution [
        | stream |
        stream := WriteStream on: String new.
        IndexEntryWriter writeLock: aResolution on: stream.
        ^stream contents
    ]

    constraint: aString [
        ^VersionConstraint fromString: aString
    ]

    "---- resolution values ----"

    testTrivialResolutionPicksTheHighestAllowedVersion [
        | result |
        result := self resolve: ResolverFixtures trivialRoot
            against: ResolverFixtures trivialSnapshot.
        self assert: result isResolution.
        self assert: (result versionOf: 'kernel-a')
            = (Version fromString: '1.2.0').
        self assert: (result sha256Of: 'kernel-a') = 'aa12'.
        self assert: result packageNames asOrderedCollection
            = (OrderedCollection with: 'kernel-a')
    ]

    testSatisfiableDiamondResolvesThroughTheIntersection [
        | result |
        result := self resolve: ResolverFixtures diamondRoot
            against: ResolverFixtures satisfiableDiamondSnapshot.
        self assert: result isResolution.
        self assert: (result versionOf: 'a') = (Version fromString: '1.0.0').
        self assert: (result versionOf: 'b') = (Version fromString: '1.0.0').
        self assert: (result versionOf: 'c') = (Version fromString: '2.4.0')
    ]

    testResolutionEqualityAndHashRideTogether [
        | r1 r2 |
        r1 := self resolve: ResolverFixtures trivialRoot
            against: ResolverFixtures trivialSnapshot.
        r2 := self resolve: ResolverFixtures trivialRoot
            against: ResolverFixtures trivialSnapshot.
        self assert: r1 = r2.
        self assert: r1 hash = r2 hash
    ]

    testResolverDeterminismLaw [
        "Law 11: same manifest + same snapshot => identical Resolution
         and byte-identical lockfile."
        | r1 r2 |
        r1 := self resolve: ResolverFixtures diamondRoot
            against: ResolverFixtures satisfiableDiamondSnapshot.
        r2 := self resolve: ResolverFixtures diamondRoot
            against: ResolverFixtures satisfiableDiamondSnapshot.
        self assert: r1 = r2.
        self assert: (self lockBytesFor: r1) = (self lockBytesFor: r2)
    ]

    testBacktrackingRecoversFromTheGreedyPick [
        | result |
        result := self resolve: ResolverFixtures backtrackingRoot
            against: ResolverFixtures backtrackingSnapshot.
        self assert: result isResolution.
        self assert: (result versionOf: 'a') = (Version fromString: '1.0.0').
        self assert: (result versionOf: 'b') = (Version fromString: '1.0.0')
    ]

    testResolutionNeverTouchesTheFetchPath [
        "Purity: the metadata/archive split — resolution completes against
         a snapshot double whose fetch path signals a test failure."
        | result |
        result := self resolve: ResolverFixtures diamondRoot
            against: (FetchTrapSnapshot around:
                ResolverFixtures satisfiableDiamondSnapshot).
        self assert: result isResolution.
        self assert: (result versionOf: 'c') = (Version fromString: '2.4.0')
    ]

    "---- conflict values & the derivation tree (law 12) ----"

    testUnsatisfiableDiamondAnswersAConflictReportValue [
        | result |
        result := self resolve: ResolverFixtures diamondRoot
            against: ResolverFixtures unsatisfiableDiamondSnapshot.
        self deny: result isResolution.
        self assert: (result isKindOf: ConflictReport)
    ]

    testConflictTreeExternalLeavesBlameBothDependencyEdges [
        | report leaves edgeOnC |
        report := self resolve: ResolverFixtures diamondRoot
            against: ResolverFixtures unsatisfiableDiamondSnapshot.
        leaves := ResolverFixtures externalLeavesOf: report root.
        edgeOnC := [:depender :constraintString |
            leaves detect: [:l |
                l cause = #dependency
                    and: [(ResolverFixtures in: l terms
                            findPackage: depender positive: true
                            constraint: (VersionConstraint exactly:
                                (Version fromString: '1.0.0'))) notNil
                        and: [(ResolverFixtures in: l terms
                                findPackage: 'c' positive: false
                                constraint: (self constraint: constraintString)) notNil]]]
                ifNone: [nil]].
        self deny: (edgeOnC value: 'a' value: '^1.0') isNil.
        self deny: (edgeOnC value: 'b' value: '^2.0') isNil
    ]

    testSmallestDomainFirstIsObservableInTheNoVersionsLeaf [
        "b (domain size 1) is decided before a (domain size 3), so the
         #noVersions leaf for a blames both the root's term and the
         term imposed by b 1.0.0."
        | report leaves noVersions |
        report := self resolve: ResolverFixtures domainOrderRoot
            against: ResolverFixtures domainOrderSnapshot.
        self deny: report isResolution.
        leaves := ResolverFixtures externalLeavesOf: report root.
        noVersions := leaves detect: [:l | l cause = #noVersions] ifNone: [nil].
        self deny: noVersions isNil.
        self deny: (ResolverFixtures in: noVersions terms
            findPackage: 'a' positive: true
            constraint: VersionConstraint any) isNil.
        self deny: (ResolverFixtures in: noVersions terms
            findPackage: 'a' positive: true
            constraint: (self constraint: '^9.0')) isNil
    ]

    testConflictReportAnswersLiveTreeMessagesWithoutRendering [
        | report |
        report := self resolve: ResolverFixtures diamondRoot
            against: ResolverFixtures unsatisfiableDiamondSnapshot.
        self assert: (report root isKindOf: Incompatibility).
        self assert: report isDerived.
        self deny: report isExternal.
        self assert: report cause = report root cause.
        self assert: report terms = report root terms.
        self deny: report isResolution
    ]

    testPinnedConflictNarration [
        "Law 12: the narrated proof renders stably — causes before the
         conclusion, one derived node per line, post-order."
        | report nl expected |
        report := self resolve: ResolverFixtures diamondRoot
            against: ResolverFixtures unsatisfiableDiamondSnapshot.
        nl := String with: Character nl.
        expected :=
            'because a 1.0.0 depends on c >=1.0.0 <2.0.0 and b 1.0.0 depends on c >=2.0.0 <3.0.0, a 1.0.0 and b 1.0.0 are incompatible', nl,
            'because a 1.0.0 and b 1.0.0 are incompatible, b >=1.0.0 <2.0.0 is incompatible', nl,
            'because b >=1.0.0 <2.0.0 is incompatible, a >=1.0.0 <2.0.0 is incompatible'.
        self assert: report printString = expected
    ]
]

Namespace current: Smalltalk.
