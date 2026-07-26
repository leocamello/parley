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
