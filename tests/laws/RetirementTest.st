"Parley Sprint 10 — the retirement laws (issue #12; Doc B §5.5,
 Doc C §2.1/§7 and Doc F §4.2/§6).

 A retired release stays FETCHABLE and is EXCLUDED FROM FRESH
 RESOLUTION. Those are two claims, and this file asserts them together
 wherever it can, because either one alone is a different (and wrong)
 feature: excluding it from fetch breaks builds that already resolved,
 and offering it to fresh resolution is the problem retirement exists
 to solve.

 THE DESIGN'S HEART IS WHERE THE FILTER LIVES. It is in the SNAPSHOT,
 not in the search: versionsOf: excludes retired versions, so the
 resolver selects only from what it is offered and needs no special
 case anywhere. testTheResolverCannotObserveRetirement is what makes
 that a proof rather than a claim — it resolves the same root twice,
 once against a snapshot where 0.3.2 is RETIRED and once against one
 where 0.3.2 is simply ABSENT, and asserts the two Resolutions are
 IDENTICAL (and render byte-identical locks). Asserting only 'the
 retired version was not picked' would pass against an implementation
 that branches on retirement inside the strategy, which is exactly the
 implementation this sprint is shaped to prevent. Filtering at the
 snapshot is also what hands a future PubGrubStrategy retirement
 semantics for free.

 THE SCAN'S HALF (Doc F §4.2). The index now holds two kinds of
 artifact, and which is which is decided by the TAG THE READER ALREADY
 VALIDATED — never by the filename. testTheScanDispatchesOnTagNeverOnFilename
 names the retirement record 'kernel-json-0.3.2.st', a filename that
 looks exactly like an entry for a release the index really holds: if
 any part of the scan dispatches on a filename, that law fails. A
 malformed record is index content like any other, so it is one
 batched problem in sorted-filename order beside malformed entries —
 a diagnosis, not a crash.

 GitIndexSource is NOT touched this sprint and
 testGitIndexSourceInheritsRetirementUntouched proves it: retirement
 arrives through its inner DirectorySource, over a real local clone.

 DECLARED PASS IN RED (issue #12):
   testASnapshotWithoutRetirementsIsUnchanged — the regression guard.
     It consumes ONLY the settled releases: constructor and the settled
     accessors, so it passes from the first day and must: the whole
     compatibility argument for an additive third tag rests on an index
     with no retirements behaving exactly as it did before, and a guard
     that only starts running in green would never have watched the
     change that could break it.
 Every other law in this file fails against the pre-sprint tree.

 SPRINT 12 ADDS THE NARROWING LAWS HERE (issue #14; Doc C §2.2). The
 holding: filter and the retirement filter are the same accessor's
 behavior — versionsOf: is where both live — and held-beats-retired is
 literally a law about their interaction, so the laws share this file
 rather than starting a parallel snapshot suite. The four additions
 (the new-value law, the describing-accessors law, held-beats-retired,
 and the OPERATOR-AMENDED describability law of §8 decision 47) all
 consume IndexSnapshot>>holding:, which does not exist against the
 pre-sprint tree, so each fails in RED as a doesNotUnderstand — a
 valid red, not a pass.

 Every fixture path is under tmp/, unique per test, removed recursively
 in tearDown; the developer image is never mutated. Exactly ONE law
 here spawns — testGitIndexSourceInheritsRetirementUntouched, through
 ProcessRunner against a LOCAL fixture repository, because the law
 under test IS the delegation through a real clone. No network, ever."

Namespace current: Parley.

TestCase subclass: RetirementTest [
    | fixtureDirs |

    <comment: 'Laws for the retirement schema: the snapshot accessors
that exclude a retired release from fresh resolution while still
answering for it, the proof that the resolver cannot observe
retirement, the scan''s tag dispatch and retirement-record validation,
and GitIndexSource inheriting all of it untouched.'>

    setUp [
        fixtureDirs := OrderedCollection new
    ]

    tearDown [
        fixtureDirs isNil ifTrue: [^self].
        fixtureDirs do: [:each | ExecFixtures removeTree: each].
        fixtureDirs := nil
    ]

    track: aPath [
        fixtureDirs add: aPath.
        ^aPath
    ]

    freshDir: aLabel [
        ^self track: (SourceFixtures directoryNamed: aLabel)
    ]

    absentDir: aLabel [
        "A tmp/ path that must NOT exist yet — an absent cache is what
         tells the settled GitIndexSource to clone — tracked so tearDown
         removes the checkout it grows."
        ^self track: (SourceFixtures missingPathNamed: aLabel)
    ]

    version: aString [
        ^Version fromString: aString
    ]

    versionStringsIn: aSnapshot of: aName [
        "The snapshot's versions as sorted printStrings — the shape a
         law can compare without depending on scan order."
        ^(((aSnapshot versionsOf: aName)
            collect: [:each | each printString]) asSortedCollection)
                asArray
    ]

    resolve: aManifest against: aSnapshot [
        ^ResolverFixtures resolve: aManifest against: aSnapshot
    ]

    lockStringOf: aResolution [
        "The settled byte-stable writer's own output — the second half
         of the purity proof: identical Resolutions must also render
         identical locks."
        | stream |
        stream := WriteStream on: String new.
        IndexEntryWriter writeLock: aResolution on: stream.
        ^stream contents
    ]

    sourceProblemsFrom: aBlock [
        "Run aBlock, require it to signal a SourceError, and answer its
         problems."
        [aBlock value.
         self assert: false description: 'expected a SourceError']
            on: Error
            do: [:e |
                self assert: (e isKindOf: SourceError)
                    description: 'expected a SourceError, got ',
                        e class name asString.
                ^e problems].
        ^#()
    ]

    "---- the snapshot: excluded from resolution, still fetchable ----"

    testVersionsOfExcludesARetiredReleaseWhileTheRestStillAnswers [
        "The two halves, asserted together, because either alone is the
         wrong feature."
        | snapshot deps |
        snapshot := RetirementFixtures snapshotWithDependentRetiredJson032.
        self assert: (self versionStringsIn: snapshot of: 'kernel-json')
            = (Array with: '0.3.1').
        self assert: (snapshot sha256For: 'kernel-json'
            version: (self version: '0.3.2'))
                = RetirementFixtures digestJson032.
        deps := snapshot dependenciesOf: 'kernel-json'
            version: (self version: '0.3.2').
        self assert: deps size = 1.
        self assert: (deps first) name = 'kernel-streams'
    ]

    testRetirementReasonAnswersTheAuthorsReasonAndNilOtherwise [
        "The reason is carried so consumers can surface it, and used by
         nothing inside resolution."
        | snapshot |
        snapshot := RetirementFixtures snapshotWithRetiredJson032.
        self assert: (snapshot retirementReasonFor: 'kernel-json'
            version: (self version: '0.3.2'))
                = RetirementFixtures json032Reason.
        self assert: (snapshot retirementReasonFor: 'kernel-json'
            version: (self version: '0.3.1')) isNil.
        self assert: (snapshot retirementReasonFor: 'kernel-ghost'
            version: (self version: '1.0.0')) isNil
    ]

    testResolutionSelectsTheNextLowerVersionWhenTheHighestIsRetired [
        | outcome |
        outcome := self resolve: RetirementFixtures jsonRootManifest
            against: RetirementFixtures snapshotWithRetiredJson032.
        self assert: outcome isResolution.
        self assert: (outcome versionOf: 'kernel-json') printString
            = '0.3.1'.
        self assert: (outcome sha256Of: 'kernel-json')
            = RetirementFixtures digestJson031
    ]

    testTheResolverCannotObserveRetirement [
        "THE PURITY PROOF. Same root, two snapshots that differ only in
         HOW 0.3.2 is missing — retired in one, absent in the other. The
         resolver must be unable to tell them apart, which is what keeps
         it a pure function of (manifest, snapshot) and what a future
         strategy inherits for free."
        | retired absent |
        retired := self resolve: RetirementFixtures jsonRootManifest
            against: RetirementFixtures snapshotWithRetiredJson032.
        absent := self resolve: RetirementFixtures jsonRootManifest
            against: RetirementFixtures snapshotWithoutJson032.
        self assert: retired isResolution.
        self assert: absent isResolution.
        self assert: retired = absent
            description: 'the resolver answered a different value for a retired release than for an absent one'.
        self assert: (self lockStringOf: retired)
            = (self lockStringOf: absent)
    ]

    testRetiringEveryVersionIsAConflictNeverACrash [
        "An empty candidate set is the settled #noVersions conflict — a
         value, never an exception, and never an empty-collection
         error."
        | outcome leaves noVersions |
        outcome := self resolve: RetirementFixtures jsonRootManifest
            against: RetirementFixtures snapshotWithBothJsonRetired.
        self deny: outcome isResolution.
        leaves := ResolverFixtures externalLeavesOf: outcome root.
        noVersions := leaves
            detect: [:each | each cause = #noVersions]
            ifNone: [nil].
        self deny: noVersions isNil
            description: 'the conflict is not the ordinary #noVersions shape'
    ]

    testASnapshotWithoutRetirementsIsUnchanged [
        "DECLARED PASS IN RED (issue #12) — see the class comment. The
         additive-tag compatibility argument rests on this, and it
         consumes only settled API, so it runs from the first day."
        | snapshot outcome |
        snapshot := RetirementFixtures snapshotWithNoRetirements.
        self assert: (self versionStringsIn: snapshot of: 'kernel-json')
            = (Array with: '0.3.1' with: '0.3.2').
        outcome := self resolve: RetirementFixtures jsonRootManifest
            against: snapshot.
        self assert: outcome isResolution.
        self assert: (outcome versionOf: 'kernel-json') printString
            = '0.3.2'
    ]

    "---- the scan: tag dispatch and record validation ----"

    testAnIndexHoldingEntriesAndARecordScansIntoBoth [
        | index snapshot |
        index := self freshDir: 'retire-scan-index'.
        RetirementFixtures populateRetiredIndexIn: index.
        snapshot := (DirectorySource on: index) snapshot.
        self assert: (self versionStringsIn: snapshot of: 'kernel-json')
            = (Array with: '0.3.1').
        self assert: (snapshot sha256For: 'kernel-json'
            version: (self version: '0.3.2'))
                = RetirementFixtures digestJson032.
        self assert: (snapshot retirementReasonFor: 'kernel-json'
            version: (self version: '0.3.2'))
                = RetirementFixtures json032Reason
    ]

    testTheScanDispatchesOnTagNeverOnFilename [
        "The retirement record is named kernel-json-0.3.2.st — exactly
         what an entry for a release this index really holds would be
         called — and the entries are named nothing in particular. If
         any part of the scan looks at a filename, this fails."
        | index snapshot |
        index := self freshDir: 'retire-disguise-index'.
        RetirementFixtures populateDisguisedIndexIn: index.
        snapshot := (DirectorySource on: index) snapshot.
        self assert: (self versionStringsIn: snapshot of: 'kernel-json')
            = (Array with: '0.3.1').
        self assert: (snapshot sha256For: 'kernel-json'
            version: (self version: '0.3.1'))
                = RetirementFixtures digestJson031.
        self assert: (snapshot sha256For: 'kernel-json'
            version: (self version: '0.3.2'))
                = RetirementFixtures digestJson032
    ]

    testSeveralRetirementRecordsMerge [
        | index snapshot |
        index := self freshDir: 'retire-merge-index'.
        RetirementFixtures populateTwoRecordIndexIn: index.
        snapshot := (DirectorySource on: index) snapshot.
        self assert: (self versionStringsIn: snapshot of: 'kernel-json')
            = (Array with: '0.3.1').
        self assert: (self versionStringsIn: snapshot of: 'kernel-old')
            = (Array with: '1.1.0')
    ]

    testARetirementForAReleaseTheIndexDoesNotHoldIsAcceptedSilently [
        "An index owner may retire ahead of a deletion, so a retirement
         naming an unpublished release is not a scan problem."
        | index snapshot |
        index := self freshDir: 'retire-ghost-index'.
        RetirementFixtures populateUnknownRetirementIndexIn: index.
        snapshot := (DirectorySource on: index) snapshot.
        self assert: (self versionStringsIn: snapshot of: 'kernel-json')
            = (Array with: '0.3.1').
        self assert: (self versionStringsIn: snapshot of: 'kernel-ghost')
            isEmpty
    ]

    testEachMalformedRecordKindIsOnePinnedProblem [
        "Every rejection ground of the new schema, one problem each,
         naming the file and the defect — never a crash on operator
         content."
        | index |
        index := self freshDir: 'retire-malformed-index'.
        RetirementFixtures malformedRecordRows do: [:row |
            | problems |
            SourceFixtures write: (row at: 1)
                toFile: 'record.st' in: index.
            problems := self sourceProblemsFrom: [
                (DirectorySource on: index) snapshot].
            self assert: problems size = 1
                description: 'expected exactly one problem, got ',
                    problems printString.
            self assert: (problems at: 1) = ((row at: 2) value: 'record.st')
                description: 'unexpected problem: ', (problems at: 1)]
    ]

    testAMalformedRecordBatchesWithAMalformedEntryInSortedOrder [
        "A retirement record is index content like any other: its
         problems join the same one SourceError, in sorted-filename
         order, beside the settled entry problems."
        | index problems |
        index := self freshDir: 'retire-batch-index'.
        RetirementFixtures populateMalformedMixIn: index.
        problems := self sourceProblemsFrom: [
            (DirectorySource on: index) snapshot].
        self assert: problems asArray
            = RetirementFixtures malformedMixProblems
    ]

    "---- the Sprint 12 narrowing laws (Doc C §2.2, §8 decision 46) ----"

    testHoldingAnswersANewSnapshotAndLeavesTheReceiverAlone [
        "THE NEW-VALUE LAW (the S9 half). holding: is a derivation in
         the shape VersionConstraint established: an operation
         answering a new instance (Architecture §1.5). The narrowed
         snapshot offers exactly the held version for the held name;
         the RECEIVER still offers every version afterwards; and
         unheld packages are unaffected in both. A mutating
         implementation would pass most of this sprint's laws and
         violate structural immutability — so immutability is
         asserted, never assumed."
        | snapshot held narrowed |
        snapshot := ResolverFixtures satisfiableDiamondSnapshot.
        held := Dictionary new.
        held at: 'c' put: (self version: '1.5.0').
        narrowed := snapshot holding: held.
        self assert: (self versionStringsIn: narrowed of: 'c')
            = (Array with: '1.5.0')
            description: 'the narrowed snapshot does not offer exactly the held version'.
        self assert: (self versionStringsIn: snapshot of: 'c')
            = (Array with: '1.5.0' with: '2.4.0' with: '3.0.0')
            description: 'holding: mutated its receiver'.
        self assert: (self versionStringsIn: narrowed of: 'a')
            = (Array with: '1.0.0').
        self assert: (self versionStringsIn: snapshot of: 'a')
            = (Array with: '1.0.0')
    ]

    testHoldingLeavesTheDescribingAccessorsUntouched [
        "A held pin must still describe itself (Doc C §2.2):
         dependenciesOf:version: and sha256For:version: answer through
         the narrowing unchanged — for the held name, for the versions
         narrowing removed from offer, and for unheld packages."
        | snapshot held narrowed deps |
        snapshot := ResolverFixtures satisfiableDiamondSnapshot.
        held := Dictionary new.
        held at: 'c' put: (self version: '1.5.0').
        narrowed := snapshot holding: held.
        self assert: (narrowed sha256For: 'c' version: (self version: '1.5.0'))
            = (snapshot sha256For: 'c' version: (self version: '1.5.0')).
        self assert: (narrowed sha256For: 'c' version: (self version: '2.4.0'))
            = (snapshot sha256For: 'c' version: (self version: '2.4.0'))
            description: 'narrowing stopped describing a version it removed from offer'.
        deps := narrowed dependenciesOf: 'a' version: (self version: '1.0.0').
        self assert: deps size = 1.
        self assert: deps first name = 'c'
    ]

    testAHeldPinThatIsRetiredIsStillOffered [
        "HELD BEATS RETIRED (§8 decision 46 — a RULING, not an
         oversight). The §2.1 retirement filter answers what a FRESH
         resolution may pick; a held pin is not being picked, it is
         being KEPT. So the narrowed snapshot offers the retired held
         version anyway — while the same receiver, unheld, still
         excludes it, and the retirement reason still answers through
         the narrowing so check can keep reporting it."
        | snapshot held narrowed |
        snapshot := RetirementFixtures snapshotWithRetiredJson032.
        held := Dictionary new.
        held at: 'kernel-json' put: (self version: '0.3.2').
        narrowed := snapshot holding: held.
        self assert: (self versionStringsIn: narrowed of: 'kernel-json')
            = (Array with: '0.3.2')
            description: 'the retirement filter overrode the held pin'.
        self assert: (self versionStringsIn: snapshot of: 'kernel-json')
            = (Array with: '0.3.1')
            description: 'holding: disturbed the receiver''s retirement filter'.
        self assert: (narrowed retirementReasonFor: 'kernel-json'
            version: (self version: '0.3.2'))
                = RetirementFixtures json032Reason
            description: 'the retirement reason stopped answering through the narrowing'
    ]

    testHoldingOffersNothingForAVersionTheSnapshotCannotDescribe [
        "OPERATOR AMENDMENT at the Sprint 12 red review (§8 decision 47,
         Doc C §2.2). 'Offers exactly the held version' is bounded by a
         release the snapshot HOLDS A RECORD FOR. When the index no
         longer publishes the held version at all — the state an index
         owner leaves behind by DELETING an old entry, which this
         sprint's own S8 fixture is built on — narrowing must offer
         NOTHING for that name rather than a version it cannot
         describe.

         The defect this forbids is not cosmetic: sha256For: answers ''
         and dependenciesOf: answers #() for a release the snapshot
         never saw, so offering it lets a selective update write a lock
         tuple with an EMPTY DIGEST — a file the Sprint 11 lock
         boundary rejects. update would have manufactured the
         corruption check exists to catch.

         This is not a retreat from held-beats-retired above, and one
         property separates them: a RETIRED release is still fully
         described, so it can be kept; a DELETED one is not described
         at all, so it cannot. Held-beats-retired governs what may be
         PICKED; this law governs what can be WRITTEN DOWN."
        | snapshot held narrowed |
        snapshot := ResolverFixtures satisfiableDiamondSnapshot.
        held := Dictionary new.
        held at: 'c' put: (self version: '9.9.9').
        narrowed := snapshot holding: held.
        self assert: (self versionStringsIn: narrowed of: 'c') isEmpty
            description: 'narrowing offered a version the snapshot cannot describe'.
        self assert: (narrowed sha256For: 'c' version: (self version: '9.9.9'))
            = ''
            description: 'the undescribed held version acquired a digest'.
        self assert: (self versionStringsIn: snapshot of: 'c')
            = (Array with: '1.5.0' with: '2.4.0' with: '3.0.0')
            description: 'holding: mutated its receiver'.
        self deny: (self resolve: ResolverFixtures diamondRoot
            against: narrowed) isResolution
            description: 'a deleted held pin resolved instead of conflicting - the lock would carry an empty digest'
    ]

    testGitIndexSourceInheritsRetirementUntouched [
        "The delegation, over a REAL local clone: GitIndexSource holds an
         inner DirectorySource and gains retirement without a line of
         its own changing. If this needs an edit to GitIndexSource, the
         delegation was broken, not the class incomplete."
        | repo cache snapshot |
        repo := self track: (RetirementFixtures retiredRepoNamed:
            'retire-git-repo').
        cache := self absentDir: 'retire-git-cache'.
        snapshot := (GitIndexSource repo: repo cache: cache
            runner: ProcessRunner new) snapshot.
        self assert: (self versionStringsIn: snapshot of: 'kernel-json')
            = (Array with: '0.3.1').
        self assert: (snapshot sha256For: 'kernel-json'
            version: (self version: '0.3.2'))
                = RetirementFixtures digestJson032
    ]
]

Namespace current: Smalltalk.
