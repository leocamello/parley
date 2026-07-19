"Parley Sprint 3 — decision-pin soundness laws (amended Doc C §3, §5,
 §7; issue #5 S1-S6).

 Deciding pkg -> v records a positive exact-pin term (origin: the
 external #decision incompatibility) into the descent ledger copy BEFORE
 the candidate's dependency edges, so a late edge that contradicts an
 already-decided package collapses through the ordinary recordTerm:
 machinery with full provenance. Both late-edge shapes are pinned here,
 along with the #decision node laws, the pin-vs-edge narration line, the
 randomized post-hoc validity law, and the byte-identity guard proving
 pins never disturb already-sound outcomes."

Namespace current: Parley.

TestCase subclass: SoundnessTest [

    <comment: 'Law suite for decision-pin soundness: late-edge collapse
in both shapes, the #decision external node and its sentence, pin
provenance ordering, the randomized post-hoc soundness law over seeded
generated snapshots, and the settled-bytes regression guard.'>

    version: aString [
        ^Version fromString: aString
    ]

    constraint: aString [
        ^VersionConstraint fromString: aString
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

    assertSound: result root: aManifest snapshot: aSnapshot [
        "The post-hoc law for one case: a Resolution must satisfy every
         root dependency and every selected edge; any failure must be a
         ConflictReport value."
        | problems |
        result isResolution ifFalse: [
            ^self assert: (result isKindOf: ConflictReport)].
        problems := SoundnessFixtures soundnessProblemsOf: result
            root: aManifest snapshot: aSnapshot.
        self assert: problems isEmpty
            description: (problems isEmpty
                ifTrue: ['sound']
                ifFalse: [problems first])
    ]

    "---- the late-edge shapes (S1/S2) ----"

    testLateEdgeRecoverableShapeBacktracksPastThePin [
        "The a 2.0.0 candidate collapses against the b 2.0.0 decision
         pin; the search backtracks and answers a 1.0.0."
        | result |
        result := self resolve: SoundnessFixtures lateEdgeRoot
            against: SoundnessFixtures recoverableLateEdgeSnapshot.
        self assert: result isResolution.
        self assert: (result versionOf: 'a') = (self version: '1.0.0').
        self assert: (result versionOf: 'b') = (self version: '2.0.0').
        self assert: (result sha256Of: 'a') = 'ra10'
    ]

    testLateEdgeUnsatisfiableShapeAnswersAConflictReport [
        "Every a candidate collides with the pin: the answer is a
         ConflictReport whose external leaves include the #decision node
         for b 2.0.0 and the a 2.0.0 -> b ^1.0 dependency edge."
        | result leaves decision edge |
        result := self resolve: SoundnessFixtures lateEdgeRoot
            against: SoundnessFixtures unsatisfiableLateEdgeSnapshot.
        self deny: result isResolution.
        self assert: (result isKindOf: ConflictReport).
        leaves := ResolverFixtures externalLeavesOf: result root.
        decision := leaves detect: [:l | l cause = #decision] ifNone: [nil].
        self deny: decision isNil.
        self assert: decision terms size = 1.
        self assert: decision terms first package = 'b'.
        self assert: decision terms first isPositive.
        self assert: decision terms first constraint
            = (VersionConstraint exactly: (self version: '2.0.0')).
        edge := leaves detect: [:l |
            l cause = #dependency and: [
                (ResolverFixtures in: l terms
                    findPackage: 'a' positive: true
                    constraint: (VersionConstraint exactly:
                        (self version: '2.0.0'))) notNil
                and: [(ResolverFixtures in: l terms
                    findPackage: 'b' positive: false
                    constraint: (self constraint: '^1.0')) notNil]]]
            ifNone: [nil].
        self deny: edge isNil
    ]

    testDecisionPinIsRecordedBeforeTheCandidateEdges [
        "Amended Doc C §5 made mechanical: the pin-vs-edge collapse's
         provenance holds the root term, the decision pin, then the
         offending edge — in exactly that recording order."
        | result collapse |
        result := self resolve: SoundnessFixtures lateEdgeRoot
            against: SoundnessFixtures unsatisfiableLateEdgeSnapshot.
        self assert: (result isKindOf: ConflictReport).
        collapse := result root cause first cause first.
        self assert: collapse isDerived.
        self assert: collapse terms size = 3.
        self assert: (collapse terms conform: [:t | t package = 'b']).
        self assert: (collapse terms at: 1) constraint = VersionConstraint any.
        self assert: (collapse terms at: 2) constraint
            = (VersionConstraint exactly: (self version: '2.0.0')).
        self assert: (collapse terms at: 2) origin cause = #decision.
        self assert: (collapse terms at: 3) constraint = (self constraint: '^1.0').
        self assert: (collapse terms at: 3) origin cause = #dependency
    ]

    "---- the #decision node (S3/S4) ----"

    testDecisionNodeIsExternalWithTheSinglePositiveExactTerm [
        | inc |
        inc := Incompatibility decisionOf: 'b' version: (self version: '2.0.0').
        self assert: inc isExternal.
        self deny: inc isDerived.
        self deny: inc isResolution.
        self assert: inc cause = #decision.
        self assert: inc terms size = 1.
        self assert: inc terms first = (Term package: 'b'
            constraint: (VersionConstraint exactly: (self version: '2.0.0'))
            positive: true).
        self assert: inc positiveTerms size = 1
    ]

    testDecisionSentenceIsPinned [
        self assert: (Incompatibility decisionOf: 'b'
            version: (self version: '2.0.0')) printString
            = 'b 2.0.0 is selected'
    ]

    testPinVsEdgeCollapseLineIsPinned [
        "The single-node sentence of a ledger collapse whose
         contributors are a decision pin and a dependency edge: the
         because-clause carries the decision sentence, then the edge
         sentence, causes before the conclusion."
        | decision edge collapse |
        decision := Incompatibility decisionOf: 'b'
            version: (self version: '2.0.0').
        edge := Incompatibility package: 'a' version: (self version: '2.0.0')
            dependsOn: 'b' constraint: (self constraint: '^1.0').
        collapse := Incompatibility conflictFrom: (Array
            with: (Term package: 'b'
                constraint: (VersionConstraint exactly: (self version: '2.0.0'))
                positive: true origin: decision)
            with: (Term package: 'b'
                constraint: (self constraint: '^1.0')
                positive: true origin: edge)).
        self assert: collapse printString
            = 'because b 2.0.0 is selected and a 2.0.0 depends on b >=1.0.0 <2.0.0, b 2.0.0 and a 2.0.0 are incompatible'
    ]

    "---- the randomized post-hoc soundness law (S5) ----"

    testRandomizedPostHocSoundnessLaw [
        "Amended Doc C §7: every answered Resolution satisfies the
         root's constraints and every dependency edge of every selected
         version. Both fixed late-edge shapes lead as a deterministic
         prefix; then 200 seeded random cases (PARLEY_SEED contract)."
        | gen root case result |
        root := SoundnessFixtures lateEdgeRoot.
        self assertSound: (self resolve: root
                against: SoundnessFixtures recoverableLateEdgeSnapshot)
            root: root
            snapshot: SoundnessFixtures recoverableLateEdgeSnapshot.
        self assertSound: (self resolve: root
                against: SoundnessFixtures unsatisfiableLateEdgeSnapshot)
            root: root
            snapshot: SoundnessFixtures unsatisfiableLateEdgeSnapshot.
        gen := DomainGenerators fromEnvironment.
        1 to: 200 do: [:i |
            case := SoundnessFixtures randomCaseWith: gen.
            result := self resolve: (case at: 1) against: (case at: 2).
            self assertSound: result
                root: (case at: 1) snapshot: (case at: 2)]
    ]

    "---- the settled-bytes guard (S6) ----"

    testPinsLeaveSoundOutcomesByteIdentical [
        "Regression guard on settled bytes: the Sprint 2 satisfiable
         diamond still resolves identically and its lockfile bytes match
         the Sprint 2 S16 pin byte-for-byte. Deliberately green in red
         phase (declared in the review request)."
        | resolution |
        resolution := self resolve: ResolverFixtures diamondRoot
            against: ResolverFixtures satisfiableDiamondSnapshot.
        self assert: resolution isResolution.
        self assert: (self lockBytesFor: resolution)
            = ('#(#''parley-lock'' 1 #root ''my-app'' #packages #(#(''a'' ''1.0.0'' #sha256 ''ab12'') #(''b'' ''1.0.0'' #sha256 ''cd34'') #(''c'' ''2.4.0'' #sha256 ''ef56'')))',
                (String with: Character nl))
    ]
]

Namespace current: Smalltalk.
