"Parley — Sprint 14 laws for Parley.SparseIndexSource (issue #16,
 Doc F §7, §8 decisions 50 and 51): the pre-fetch closure, the
 seededWith: protocol, the curl grounds declared closed, the listing
 boundary, the cache layout, freshness across snapshots, and the
 metadata/archive split.

 EVERY URL IS A file:// ABSOLUTE PATH. No law contacts a network,
 ever — the transport is a process seam precisely so this is provable
 rather than promised. Fetch counts are read from recorded command
 lines (CountingProcessRunner), never inferred from timing, the lock,
 or the cache's contents.

 DECLARED PASSES IN RED (issue #16): NONE in this file. Every law
 either messages Parley.SparseIndexSource — which does not exist
 against the pre-sprint tree, so construction fails before any
 process is spawned — or sends seededWith: to a settled source,
 which does not answer it yet.

 Every fixture path is under tmp/, unique per test, removed
 RECURSIVELY in tearDown (base trees and caches are nested); the
 developer image is never mutated."

Namespace current: Parley.

TestCase subclass: SparseIndexSourceTest [
    | fixtureDirs |

    <comment: 'Laws for SparseIndexSource: the decision-50 closure
(reach, count, fixpoint, lock seeding), the decision-51 seeding
protocol on all three sources, the closed curl grounds, the
malformed-listing boundary, the S10 cache-layout prohibition, listing
freshness and the metadata/archive split.'>

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

    baseTree: aLabel [
        ^self track: (SparseIndexFixtures baseTreeNamed: aLabel)
    ]

    sourceOverTree: aBasePath cache: aCacheDir seeds: someNames runner: aRunner [
        "A SparseIndexSource over the tree's file:// URL, seeded —
         the closure laws construct the source directly and hand the
         seeds as values (Doc F §7.5): no law needs a working
         directory, a Package.st or a parley.lock to exercise the
         walk."
        ^(SparseIndexSource
            base: (SparseIndexFixtures baseUrlFor: aBasePath)
            cache: aCacheDir
            runner: aRunner) seededWith: someNames
    ]

    problemsOf: aBlock [
        "The problems array of the SourceError aBlock signals; fails
         when no error, or a non-SourceError, is signaled."
        [aBlock value.
         self assert: false description: 'expected a SourceError']
            on: Error
            do: [:e |
                self assert: (e isKindOf: SourceError)
                    description: 'expected a SourceError, got ', e class name.
                ^e problems].
        ^#()
    ]

    "---- the closure (decision 50) ----"

    testTheClosureReachesATransitiveDependency [
        "root -> root-dep -> deep: deep appears in no seed, only in
         root-dep's fetched entry, and the snapshot must describe it."
        | base cache snapshot deps |
        base := self baseTree: 'sis-reach-base'.
        cache := self freshDir: 'sis-reach-cache'.
        SparseIndexFixtures populateTwoLevelTreeIn: base.
        snapshot := (self sourceOverTree: base cache: cache
            seeds: #('root-dep') runner: ProcessRunner new) snapshot.
        self assert: (snapshot versionsOf: 'root-dep') size = 1.
        self assert: (snapshot versionsOf: 'deep') size = 1.
        self assert: ((snapshot versionsOf: 'deep') includes:
            (Version fromString: '1.0.0')).
        deps := snapshot dependenciesOf: 'root-dep'
            version: (Version fromString: '1.0.0').
        self assert: deps size = 1.
        self assert: deps first name = 'deep'
    ]

    testAnUnreachablePackageIsNeverFetched [
        "The wire-efficiency half of the ruling: a package no seed
         and no fetched entry names must never appear in any recorded
         curl command line."
        | base cache runner snapshot |
        base := self baseTree: 'sis-count-base'.
        cache := self freshDir: 'sis-count-cache'.
        SparseIndexFixtures populateTwoLevelTreeIn: base.
        SparseIndexFixtures addUnrelatedTo: base.
        runner := CountingProcessRunner new.
        snapshot := (self sourceOverTree: base cache: cache
            seeds: #('root-dep') runner: runner) snapshot.
        self assert: (snapshot versionsOf: 'deep') size = 1.
        self assert: (snapshot versionsOf: 'unrelated') isEmpty.
        self assert: (SparseIndexFixtures count: 'unrelated'
            in: runner commands) = 0
            description: 'a curl invocation named a package the closure cannot reach'
    ]

    testTheClosureSeededFromPinsReachesEveryPinnedName [
        "A pin the manifest has dropped is still a pin the tool must
         describe: the seed set is a union, and the lock's half
         arrives by the same message."
        | base cache snapshot |
        base := self baseTree: 'sis-pins-base'.
        cache := self freshDir: 'sis-pins-cache'.
        SparseIndexFixtures populateTwoLevelTreeIn: base.
        SparseIndexFixtures addLegacyTo: base.
        snapshot := (self sourceOverTree: base cache: cache
            seeds: #('root-dep' 'legacy') runner: ProcessRunner new)
                snapshot.
        self assert: (snapshot versionsOf: 'legacy') size = 1.
        self assert: (snapshot versionsOf: 'deep') size = 1
    ]

    testAMetadataCycleTerminatesAtFixpoint [
        "cyc-a <-> cyc-b: the walk reaches fixpoint rather than
         approaching it forever, and each package is fetched ONCE —
         counted, never inferred."
        | base cache runner snapshot |
        base := self baseTree: 'sis-cycle-base'.
        cache := self freshDir: 'sis-cycle-cache'.
        SparseIndexFixtures populateCycleTreeIn: base.
        runner := CountingProcessRunner new.
        snapshot := (self sourceOverTree: base cache: cache
            seeds: #('cyc-a') runner: runner) snapshot.
        self assert: (snapshot versionsOf: 'cyc-a') size = 1.
        self assert: (snapshot versionsOf: 'cyc-b') size = 1.
        self assert: (SparseIndexFixtures count: 'cyc-a/versions.st'
            in: runner commands) = 1.
        self assert: (SparseIndexFixtures count: 'cyc-b/versions.st'
            in: runner commands) = 1.
        self assert: (SparseIndexFixtures count: 'cyc-a-1.0.0.st'
            in: runner commands) = 1.
        self assert: (SparseIndexFixtures count: 'cyc-b-1.0.0.st'
            in: runner commands) = 1
    ]

    "---- the seeding protocol (decision 51) ----"

    testSeededWithPerformsNoIO [
        "The seeds are values: a source seeded against a runner that
         signals on any spawn answers without spawning."
        | source seeded |
        source := SparseIndexSource
            base: 'file:///nowhere'
            cache: 'tmp/parley-sis-noio-cache'
            runner: TrapRunner new.
        seeded := source seededWith: #('anything').
        self deny: seeded isNil
    ]

    testSeededWithAnswersANewInstanceHoldingTheSeeds [
        "The holding: shape (Doc C §2.2 precedent): an operation
         answers a new value; the receiver is unchanged and still
         holds ITS seeds — none.

         STRENGTHENED AT THE RED REVIEW (operator amendment). As
         written, this law asserted only non-identity, which its own
         selector over-promises: an implementation that ignored the
         seeds and answered `self copy` passed it, and so did one that
         mutated the receiver AND answered a new instance. Both are
         exactly the defects decision 51 rules out, and the seeds are
         the whole mechanism the ruling turns on, so the law now
         asserts both halves of its name.

         THE ORDER IS LOAD-BEARING. The receiver is snapshotted FIRST,
         while the cache is still cold: the two instances share a
         cache by construction, so once the seeded copy has walked its
         closure the inner DirectorySource would scan entries the
         receiver never fetched, and a receiver-unchanged assertion
         made afterwards would read the copy's work as the receiver's.
         Cold receiver first, seeded copy second."
        | base cache runner source seeded |
        base := self baseTree: 'sis-new-base'.
        cache := self freshDir: 'sis-new-cache'.
        SparseIndexFixtures populateTwoLevelTreeIn: base.
        runner := CountingProcessRunner new.
        source := SparseIndexSource
            base: (SparseIndexFixtures baseUrlFor: base)
            cache: cache
            runner: runner.
        seeded := source seededWith: #('root-dep').
        self deny: seeded == source
            description: 'seededWith: mutated its receiver instead of answering a new instance'.
        self assert: (source snapshot versionsOf: 'root-dep') isEmpty
            description: 'the receiver acquired the seeds it was asked to answer a new instance for'.
        self assert: runner commands isEmpty
            description: 'the unchanged receiver fetched something'.
        self assert: ((seeded snapshot versionsOf: 'root-dep') isEmpty) not
            description: 'the answered instance does not hold the seeds - seededWith: dropped them'.
        self assert: ((seeded snapshot versionsOf: 'deep') isEmpty) not
            description: 'the answered instance holds the seeds but its closure did not walk them'
    ]

    testANeverSeededSourceAnswersAnEmptySnapshot [
        "An empty seed set closes over nothing: the ordinary
         undescribed-name state of decision 47, not an error — and
         nothing is fetched, proved on the recording."
        | base cache runner snapshot |
        base := self baseTree: 'sis-unseeded-base'.
        cache := self freshDir: 'sis-unseeded-cache'.
        SparseIndexFixtures populateTwoLevelTreeIn: base.
        runner := CountingProcessRunner new.
        snapshot := (SparseIndexSource
            base: (SparseIndexFixtures baseUrlFor: base)
            cache: cache
            runner: runner) snapshot.
        self assert: (snapshot versionsOf: 'root-dep') isEmpty.
        self assert: runner commands isEmpty
            description: 'a never-seeded source fetched something'
    ]

    testDirectorySourceAnswersSelfToSeededWith [
        "Not a stub: a source that reads its whole index genuinely
         has nothing to do with the information, and answering self
         is what lets every call site send the message
         unconditionally."
        | index source |
        index := self freshDir: 'sis-dirself-index'.
        InstallFixtures populateInstallDiamondIn: index.
        source := DirectorySource on: index.
        self assert: (source seededWith: #('a' 'zz')) == source
    ]

    testGitIndexSourceAnswersSelfToSeededWith [
        "The same, on the second scanning source — construction is
         pathname-passive and the TrapRunner proves seededWith: runs
         no process."
        | source |
        source := GitIndexSource
            repo: 'tmp/parley-sis-gitself-repo'
            cache: 'tmp/parley-sis-gitself-cache'
            runner: TrapRunner new.
        self assert: (source seededWith: #('a')) == source
    ]

    testASettledScanIsUnchangedThroughSeededWith [
        "A settled scan re-run through seededWith:: the snapshot's
         observables are exactly the direct scan's — what keeps the
         message on the protocol rather than on one class."
        | index direct seeded |
        index := self freshDir: 'sis-scanlaw-index'.
        InstallFixtures populateInstallDiamondIn: index.
        direct := (DirectorySource on: index) snapshot.
        seeded := ((DirectorySource on: index) seededWith: #('c'))
            snapshot.
        #('a' 'b' 'c') do: [:name |
            self assert: (seeded versionsOf: name) asArray
                = (direct versionsOf: name) asArray]
    ]

    "---- the curl grounds, declared closed ----"

    testAListingMissForASeededNameIsAnEmptyCandidateSet [
        "curl exit 37 (file:// miss, probed against the toolchain) is
         a MISS: an undescribed name, decision 47's ordinary state —
         never an error."
        | base cache snapshot |
        base := self baseTree: 'sis-miss-base'.
        cache := self freshDir: 'sis-miss-cache'.
        SparseIndexFixtures populateTwoLevelTreeIn: base.
        snapshot := (self sourceOverTree: base cache: cache
            seeds: #('root-dep' 'ghost') runner: ProcessRunner new)
                snapshot.
        self assert: (snapshot versionsOf: 'ghost') isEmpty.
        self assert: (snapshot versionsOf: 'root-dep') size = 1
    ]

    testExitTwentyTwoIsAMissNotAnError [
        "The second declared miss ground: 22 is -f on an HTTP error
         response. Unproducible over file://, so the runner double
         answers it — spawning nothing, so no listing lands and every
         seed is a miss."
        | cache snapshot |
        cache := self freshDir: 'sis-h22-cache'.
        snapshot := ((SparseIndexSource
            base: 'file:///nowhere'
            cache: cache
            runner: (RecordingRunner answering: 22))
                seededWith: #('root-dep')) snapshot.
        self assert: (snapshot versionsOf: 'root-dep') isEmpty
    ]

    testAnUndeclaredCurlExitIsOnePinnedProblem [
        "Anything outside {0, 37, 22} is a transport failure: one
         SourceError problem carrying the exact command line and exit
         code — the GitIndexSource precedent verbatim."
        | cache baseUrl problems command |
        cache := self freshDir: 'sis-fail-cache'.
        baseUrl := 'file:///nowhere'.
        problems := self problemsOf: [
            ((SparseIndexSource
                base: baseUrl
                cache: cache
                runner: (RecordingRunner answering: 9))
                    seededWith: #('root-dep')) snapshot].
        command := SparseIndexFixtures
            curlCommandFor: (SparseIndexFixtures
                listingUrlFor: baseUrl name: 'root-dep')
            to: (SparseIndexFixtures
                cachedListingPathIn: cache for: 'root-dep').
        self assert: problems asArray = (Array with:
            (SparseIndexFixtures curlFailureProblemFor: command code: 9))
    ]

    testAnEntryAListingNamesButLacksIsAnIndexDefect [
        "The S7/S8 ruled distinction, entry half: the index made a
         claim it did not keep — one problem naming BOTH files,
         batched, never the ordinary miss."
        | base cache problems |
        base := self baseTree: 'sis-holey-base'.
        cache := self freshDir: 'sis-holey-cache'.
        SparseIndexFixtures populateAbsentEntryTreeIn: base.
        problems := self problemsOf: [
            (self sourceOverTree: base cache: cache
                seeds: #('holey') runner: ProcessRunner new) snapshot].
        self assert: problems asArray = (Array with:
            (SparseIndexFixtures missingEntryProblemFor: 'holey'
                version: '2.0.0'))
    ]

    "---- the listing boundary (the fourth deserialization boundary) ----"

    listingProblemsFor: aListingText label: aLabel [
        "Drive one malformed listing through the closure and answer
         the batched problems."
        | base cache |
        base := self baseTree: aLabel, '-base'.
        cache := self freshDir: aLabel, '-cache'.
        SparseIndexFixtures writeListing: aListingText
            for: 'bad' in: base.
        ^self problemsOf: [
            (self sourceOverTree: base cache: cache
                seeds: #('bad') runner: ProcessRunner new) snapshot]
    ]

    testAnUnreadableListingIsOnePinnedProblem [
        self assert: (self listingProblemsFor:
                SparseIndexFixtures unreadableListingText
                label: 'sis-unread') asArray
            = (Array with:
                (SparseIndexFixtures unreadableListingProblemFor: 'bad'))
    ]

    testAWrongTagListingIsOnePinnedProblem [
        self assert: (self listingProblemsFor:
                SparseIndexFixtures wrongTagListingText
                label: 'sis-wrongtag') asArray
            = (Array with:
                (SparseIndexFixtures wrongTagListingProblemFor: 'bad'
                    tag: '#''parley-lock'''))
    ]

    testAMissingVersionsKeyIsOnePinnedProblem [
        self assert: (self listingProblemsFor:
                SparseIndexFixtures missingVersionsListingText
                label: 'sis-nokey') asArray
            = (Array with:
                (SparseIndexFixtures missingVersionsKeyProblemFor: 'bad'))
    ]

    testANonStringMemberIsOnePinnedProblem [
        self assert: (self listingProblemsFor:
                SparseIndexFixtures nonStringMemberListingText
                label: 'sis-nonstring') asArray
            = (Array with:
                (SparseIndexFixtures nonStringMemberProblemFor: 'bad'
                    value: '42'))
    ]

    testAnUnparseableVersionIsOnePinnedProblem [
        self assert: (self listingProblemsFor:
                SparseIndexFixtures unparseableVersionListingText
                label: 'sis-badver') asArray
            = (Array with:
                (SparseIndexFixtures unparseableVersionProblemFor: 'bad'
                    value: 'abc'))
    ]

    testMalformedListingsBatchInSortedFilenameOrder [
        "Two offending listings, one SourceError, sorted-filename
         order (§4 conventions) — beside each other exactly as
         malformed entries batch."
        | base cache problems |
        base := self baseTree: 'sis-batch-base'.
        cache := self freshDir: 'sis-batch-cache'.
        SparseIndexFixtures
            writeListing: SparseIndexFixtures unreadableListingText
            for: 'zz-late' in: base.
        SparseIndexFixtures
            writeListing: SparseIndexFixtures missingVersionsListingText
            for: 'aa-early' in: base.
        problems := self problemsOf: [
            (self sourceOverTree: base cache: cache
                seeds: #('zz-late' 'aa-early')
                runner: ProcessRunner new) snapshot].
        self assert: problems asArray = (Array
            with: (SparseIndexFixtures
                missingVersionsKeyProblemFor: 'aa-early')
            with: (SparseIndexFixtures
                unreadableListingProblemFor: 'zz-late'))
    ]

    "---- the cache layout (S10 — a prohibition, not an implication) ----"

    testAListingNeverEntersTheScannedEntriesDirectory [
        "After a full closure the cache holds both listings and
         entries; the inner DirectorySource scans CLEAN, because
         listings are cached beside the entries directory, never in
         it. The settled wrong-tag scan wording (pinned byte-for-byte
         by two settled laws) would fire on any violation — so a
         second snapshot over the same cache proving clean is what
         keeps the layout honest."
        | base cache source entriesDir names |
        base := self baseTree: 'sis-layout-base'.
        cache := self freshDir: 'sis-layout-cache'.
        SparseIndexFixtures populateTwoLevelTreeIn: base.
        source := self sourceOverTree: base cache: cache
            seeds: #('root-dep') runner: ProcessRunner new.
        source snapshot.
        self assert: (File name: (SparseIndexFixtures
                cachedListingPathIn: cache for: 'root-dep')) exists
            description: 'the fetched listing was not cached'.
        entriesDir := File name:
            (SparseIndexFixtures entriesDirIn: cache).
        self assert: entriesDir exists.
        names := (entriesDir files
            collect: [:each | each stripPath]) asSortedCollection asArray.
        self assert: names = #('deep-1.0.0.st' 'root-dep-1.0.0.st')
            description: 'the scanned entries directory holds more than the fetched entries'.
        "the second snapshot scans the populated cache: still clean"
        self assert: ((source snapshot versionsOf: 'deep') size = 1)
    ]

    "---- freshness across snapshots (S15, the §3 growth precedent) ----"

    testAListingIsReFetchedEverySnapshotAndACachedEntryIsNot [
        "The one property nothing holding its tree still can see: a
         listing is the one mutable artifact (a publish appends), so
         it is re-fetched every snapshot; a release is immutable, so
         a cached entry is never fetched again. Counted."
        | base cache runner source first second |
        base := self baseTree: 'sis-fresh-base'.
        cache := self freshDir: 'sis-fresh-cache'.
        SparseIndexFixtures populateTwoLevelTreeIn: base.
        runner := CountingProcessRunner new.
        source := self sourceOverTree: base cache: cache
            seeds: #('root-dep') runner: runner.
        first := source snapshot.
        self assert: (first versionsOf: 'deep') size = 1.
        SparseIndexFixtures growDeepIn: base.
        second := source snapshot.
        self assert: ((second versionsOf: 'deep') includes:
                (Version fromString: '1.1.0'))
            description: 'the second snapshot does not offer the published version - the listing was not re-fetched'.
        self assert: (SparseIndexFixtures count: 'deep/versions.st'
                in: runner commands) = 2
            description: 'the listing was not fetched once per snapshot'.
        self assert: (SparseIndexFixtures count: 'deep-1.1.0.st'
                in: runner commands) = 1
            description: 'the new entry was not fetched exactly once'.
        self assert: (SparseIndexFixtures count: 'deep-1.0.0.st'
                in: runner commands) = 1
            description: 'a cached entry was fetched again - releases are immutable'
    ]

    "---- the metadata/archive split (S11, source half) ----"

    testArchivesAreUntouchedUntilFetchAndACacheHitSpawnsNothing [
        "Resolution consumed listings and entries only; the archive
         is fetched at fetch:version:, once — a cache-hit archive is
         not re-fetched."
        | base cache runner source bytes fetched starCount |
        base := self baseTree: 'sis-split-base'.
        cache := self freshDir: 'sis-split-cache'.
        bytes := 'opaque sparse archive bytes'.
        SparseIndexFixtures publish: 'solo' version: '1.0.0'
            dependencies: #() archiveBytes: bytes in: base.
        runner := CountingProcessRunner new.
        source := self sourceOverTree: base cache: cache
            seeds: #('solo') runner: runner.
        source snapshot.
        self assert: (SparseIndexFixtures count: '.star'
                in: runner commands) = 0
            description: 'an archive was fetched before or during resolution'.
        fetched := source fetch: 'solo'
            version: (Version fromString: '1.0.0').
        self assert: fetched = bytes.
        starCount := SparseIndexFixtures count: '.star'
            in: runner commands.
        self assert: starCount = 1.
        source fetch: 'solo' version: (Version fromString: '1.0.0').
        self assert: (SparseIndexFixtures count: '.star'
                in: runner commands) = starCount
            description: 'a cache-hit archive was re-fetched'
    ]
]

Namespace current: Smalltalk.
