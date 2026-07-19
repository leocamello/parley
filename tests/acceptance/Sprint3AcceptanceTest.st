"Parley Sprint 3 — acceptance scenarios S1-S13 from GitHub issue #5.
 Each scenario Sn maps to exactly one selector starting with testSn_
 (enforced by the wrap traceability gate).

 S2/S4 fixture note (posted on issue #5 for confirmation): the
 unsatisfiable shape keeps BOTH a versions, each depending on b '^1.0'.
 With a {2.0.0} only, the smallest-domain tie-break decides a BEFORE b
 and the failure surfaces as a plain #noVersions with no #decision node
 anywhere in the cause tree; amended Doc C §7 requires the late edge to
 land on an already-decided package, so a's domain must exceed b's."

Namespace current: Parley.

TestCase subclass: Sprint3AcceptanceTest [

    <comment: 'Acceptance scenarios for Sprint 3: decision-pin
soundness and its narration, the randomized post-hoc soundness law,
ApplicationManifest, the lock read-back path, and pin verification.'>

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

    lockWith: entries [
        | triples |
        triples := Dictionary new.
        entries do: [:e |
            triples at: (e at: 1) put: (Array
                with: (Version fromString: (e at: 2))
                with: (e at: 3))].
        ^Resolution root: 'my-app' triples: triples
    ]

    baselineLock [
        ^self lockWith: #(#('a' '1.4.0' 'ha14') #('b' '2.1.0' 'hb21'))
    ]

    testS1_lateEdgeRecoverableShapeBacktracks [
        | result |
        result := self resolve: SoundnessFixtures lateEdgeRoot
            against: SoundnessFixtures recoverableLateEdgeSnapshot.
        self assert: result isResolution.
        self assert: (result versionOf: 'a') = (self version: '1.0.0').
        self assert: (result versionOf: 'b') = (self version: '2.0.0')
    ]

    testS2_lateEdgeUnsatisfiableShapeAnswersConflictReport [
        | result leaves decision edge |
        result := self resolve: SoundnessFixtures lateEdgeRoot
            against: SoundnessFixtures unsatisfiableLateEdgeSnapshot.
        self deny: result isResolution.
        self assert: (result isKindOf: ConflictReport).
        leaves := ResolverFixtures externalLeavesOf: result root.
        decision := leaves detect: [:l | l cause = #decision] ifNone: [nil].
        self deny: decision isNil
            description: 'the #decision node for b 2.0.0 must be a leaf'.
        self assert: decision terms first package = 'b'.
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
            description: 'the a 2.0.0 -> b ^1.0 edge must be a leaf'
    ]

    testS3_decisionIncompatibilityIsFirstClassExternalNode [
        | inc |
        inc := Incompatibility decisionOf: 'b' version: (self version: '2.0.0').
        self assert: inc isExternal.
        self deny: inc isDerived.
        self assert: inc cause = #decision.
        self assert: inc terms size = 1.
        self assert: inc terms first = (Term package: 'b'
            constraint: (VersionConstraint exactly: (self version: '2.0.0'))
            positive: true).
        self assert: inc printString = 'b 2.0.0 is selected'
    ]

    testS4_pinVsEdgeProofNarratesTheDecisionInTheBecauseClause [
        | report nl expected |
        report := self resolve: SoundnessFixtures lateEdgeRoot
            against: SoundnessFixtures unsatisfiableLateEdgeSnapshot.
        self assert: (report isKindOf: ConflictReport).
        nl := String with: Character nl.
        expected :=
            'because my-app 1.0.0 depends on b * and b 2.0.0 is selected and a 2.0.0 depends on b >=1.0.0 <2.0.0, my-app 1.0.0 and b 2.0.0 and a 2.0.0 are incompatible', nl,
            'because my-app 1.0.0 depends on b * and b 2.0.0 is selected and a 1.0.0 depends on b >=1.0.0 <2.0.0, my-app 1.0.0 and b 2.0.0 and a 1.0.0 are incompatible', nl,
            'because my-app 1.0.0 and b 2.0.0 and a 2.0.0 are incompatible and my-app 1.0.0 and b 2.0.0 and a 1.0.0 are incompatible, a * is incompatible', nl,
            'because a * is incompatible, b * is incompatible'.
        self assert: report printString = expected
    ]

    testS5_randomizedPostHocSoundnessLaw [
        | gen resolutions conflicts |
        gen := DomainGenerators fromEnvironment.
        resolutions := 0.
        conflicts := 0.
        1 to: 200 do: [:i |
            | case result problems |
            case := SoundnessFixtures randomCaseWith: gen.
            result := self resolve: (case at: 1) against: (case at: 2).
            result isResolution
                ifTrue: [
                    resolutions := resolutions + 1.
                    problems := SoundnessFixtures
                        soundnessProblemsOf: result
                        root: (case at: 1)
                        snapshot: (case at: 2).
                    self assert: problems isEmpty
                        description: (problems isEmpty
                            ifTrue: ['sound']
                            ifFalse: [problems first])]
                ifFalse: [
                    conflicts := conflicts + 1.
                    self assert: (result isKindOf: ConflictReport)]].
        self assert: resolutions > 0
            description: 'the generator produced no solvable shapes'.
        self assert: conflicts > 0
            description: 'the generator produced no unsolvable shapes'
    ]

    testS6_soundResolutionsAreUndisturbedByPins [
        | resolution |
        resolution := self resolve: ResolverFixtures diamondRoot
            against: ResolverFixtures satisfiableDiamondSnapshot.
        self assert: resolution isResolution.
        self assert: (resolution versionOf: 'a') = (self version: '1.0.0').
        self assert: (resolution versionOf: 'b') = (self version: '1.0.0').
        self assert: (resolution versionOf: 'c') = (self version: '2.4.0').
        self assert: (self lockBytesFor: resolution)
            = ('#(#''parley-lock'' 1 #root ''my-app'' #packages #(#(''a'' ''1.0.0'' #sha256 ''ab12'') #(''b'' ''1.0.0'' #sha256 ''cd34'') #(''c'' ''2.4.0'' #sha256 ''ef56'')))',
                (String with: Character nl))
    ]

    testS7_applicationManifestAssociatesManifestWithLock [
        | lib lock app bare |
        lib := ResolverFixtures diamondRoot.
        lock := ResolverFixtures resolve: lib
            against: ResolverFixtures satisfiableDiamondSnapshot.
        app := ApplicationManifest manifest: lib lock: lock.
        self assert: app hasLock.
        self assert: app lock = lock.
        self assert: app name = lib name.
        self assert: app version = lib version.
        self assert: app dependencies = lib dependencies.
        self assert: app fileIns = lib fileIns.
        bare := ApplicationManifest manifest: lib.
        self deny: bare hasLock.
        self assert: bare lock isNil
    ]

    testS8_lockReadBackRoundTripsToTheResolution [
        | resolution parsed rebuilt |
        resolution := self resolve: ResolverFixtures diamondRoot
            against: ResolverFixtures satisfiableDiamondSnapshot.
        parsed := IndexEntryReader readFrom:
            (ReadStream on: (self lockBytesFor: resolution)).
        rebuilt := Resolution fromLockEntry: parsed.
        self assert: rebuilt = resolution.
        self assert: rebuilt rootName = 'my-app'
    ]

    testS9_validPinsVerify [
        | verdict |
        verdict := PinVerification
            of: (ResolverFixtures rootWith: #(#('a' '^1.0') #('b' '^2.0')))
            lock: self baselineLock.
        self assert: verdict isValid.
        self assert: verdict problems isEmpty
    ]

    testS10_violatedPinFailsVerificationNamingTheViolation [
        | verdict |
        verdict := PinVerification
            of: (ResolverFixtures rootWith: #(#('a' '^2.0') #('b' '^2.0')))
            lock: self baselineLock.
        self deny: verdict isValid.
        self assert: verdict problems size = 1.
        self assert: verdict problems first
            = 'lock pins ''a'' at 1.4.0 outside the manifest constraint >=2.0.0 <3.0.0'
    ]

    testS11_missingPinFailsVerificationNamingThePackage [
        | verdict |
        verdict := PinVerification
            of: (ResolverFixtures rootWith:
                #(#('a' '^1.0') #('b' '^2.0') #('c' '^1.0')))
            lock: self baselineLock.
        self deny: verdict isValid.
        self assert: verdict problems size = 1.
        self assert: verdict problems first
            = 'manifest dependency ''c'' (>=1.0.0 <2.0.0) is missing from the lock'
    ]

    testS12_extraTransitivePinsAreExpectedAndValid [
        | verdict |
        verdict := PinVerification
            of: (ResolverFixtures rootWith: #(#('a' '^1.0')))
            lock: (self lockWith:
                #(#('a' '1.4.0' 'ha14') #('x' '3.0.0' 'hx30'))).
        self assert: verdict isValid.
        self assert: verdict problems isEmpty
    ]

    testS13_verificationIsAPureValueWithBatchedProblems [
        "Built from hand-built values only: no snapshot, no resolver,
         no I/O — one verdict value carrying both problems at once."
        | verdict |
        verdict := PinVerification
            of: (ResolverFixtures rootWith: #(#('a' '^2.0') #('c' '^1.0')))
            lock: self baselineLock.
        self deny: verdict isValid.
        self assert: verdict problems size = 2.
        self assert: (verdict problems at: 1)
            = 'lock pins ''a'' at 1.4.0 outside the manifest constraint >=2.0.0 <3.0.0'.
        self assert: (verdict problems at: 2)
            = 'manifest dependency ''c'' (>=1.0.0 <2.0.0) is missing from the lock'
    ]
]

Namespace current: Smalltalk.
