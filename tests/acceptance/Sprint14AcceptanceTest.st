"Parley Sprint 14 - acceptance scenarios S1-S16 from GitHub issue #16.
 Each scenario Sn maps to exactly one selector starting with testSn_
 (enforced by the wrap traceability gate).

 The milestone: THE SPARSE INDEX CLIENT. Both settled sources demand
 the whole index before resolution begins - right for a directory,
 defensible for a git clone, the wrong shape for a registry. A client
 should fetch the packages a resolution can reach and nothing else.
 What gated it was a ruling, and the ruling is made twice over: §8
 decision 50, the one I/O moment may be a CLOSURE, never a callback -
 snapshot walks the seeds to fixpoint and answers one complete
 immutable IndexSnapshot before resolution begins, so lazy fetching
 inside IndexSnapshot is disqualified by name; and §8 decision 51, the
 seeds arrive as VALUES through seededWith: - the CLI supplies them,
 because the source must never read Package.st or parley.lock.

 S2 AND S15 ARE THE SCENARIOS DECISION 50 EXISTS FOR. An
 implementation that fetches the whole index passes S1 and fails S2;
 one that caches listings forever passes S1-S14 and fails S15. Both
 are proved by READING THE RECORDED CURL COMMAND LINES - counted,
 never inferred from timing, the lock, or the cache contents.

 S7 VS S8 IS A RULED DISTINCTION, NOT A NUANCE. A missing listing is
 decision 47 undescribed-name state - the ordinary #noVersions
 conflict. A missing entry that a listing NAMES is an index defect -
 one SourceError problem naming both files. Doc F §7.3 rules them
 different; collapsing them into one path is a defect.

 S16 IS THE SCENARIO THAT COULD HAVE SHIPPED GREEN. CLI add:constraint:
 snapshots BEFORE it edits Package.st, so the added name is in neither
 file the seed set is otherwise built from. Unseeded, the closure
 never fetches the new name, decision 47 makes the miss an empty
 candidate set, and add fails EVERY time with a #noVersions conflict
 that blames the package while atomically restoring the file - which
 no scanning source could ever notice. Exit 0 is therefore a
 sufficient assertion here, and the selector says what it guards.

 DECLARED PASSES IN RED (issue #16): NONE in this file. Every selector
 carries at least one assertion the pre-sprint tree cannot satisfy:
 S1, S2, S4, S5, S7-S11, S13, S14 and S16 hand '--index' to the
 settled grammar, which answers usage at exit 2 where they demand 0 or
 1 (S13 additionally demands the grown flag table and usage lines, so
 its exclusivity sub-assertions - which do pass in red for the
 unrelated unknown-flag reason, exactly as the two declared law-file
 passes do - cannot carry the selector); S3, S12 and S15 construct
 Parley.SparseIndexSource, which does not exist; and S6 demands a
 four-tag rejection sentence from a reader that today names three.

 S11, S14 and S16 build a real .star through the toolchain and spawn
 real registration commands; every fetch is real curl against file://
 absolute paths under tmp/. No scenario contacts a network and none
 runs git. Every fixture path is under tmp/, unique per test, removed
 recursively in tearDown; the developer image is never mutated."

Namespace current: Parley.

TestCase subclass: Sprint14AcceptanceTest [
    | fixtureDirs |

    <comment: 'Acceptance scenarios for Sprint 14: the decision-50
closure over seeds the CLI hands through seededWith:, the
parley-listing schema at the settled reader, the closed curl grounds,
the S7/S8 ruled distinction, the cache layout that keeps listings out
of the scanned entries directory, the metadata/archive split, listing
freshness, determinism in messages IndexSnapshot already answers, the
--index flag with its working-directory cache, and the offline
end-to-end exit criterion.'>

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

    rootDepWorkDir: aLabel [
        ^self track: (SparseIndexFixtures workDirNamed: aLabel
            declaring: 'root-dep' constraint: '^1.0')
    ]

    contentsOf: aPath [
        ^(File name: aPath) contents
    ]

    exists: aPath [
        ^(File name: aPath) exists
    ]

    version: aString [
        ^Version fromString: aString
    ]

    sourceOverTree: aBasePath cache: aCacheDir seeds: someNames runner: aRunner [
        ^(SparseIndexSource
            base: (SparseIndexFixtures baseUrlFor: aBasePath)
            cache: aCacheDir
            runner: aRunner) seededWith: someNames
    ]

    runIn: aWorkDir argv: anArgvArray runner: aRunner [
        ^(CommandLine in: aWorkDir runner: aRunner) run: anArgvArray
    ]

    resolveIn: aWorkDir base: aBasePath runner: aRunner [
        ^self runIn: aWorkDir
            argv: (Array with: 'resolve' with: '--index'
                with: (SparseIndexFixtures baseUrlFor: aBasePath))
            runner: aRunner
    ]

    installIn: aWorkDir base: aBasePath runner: aRunner [
        ^self runIn: aWorkDir
            argv: (Array with: 'install' with: '--index'
                with: (SparseIndexFixtures baseUrlFor: aBasePath))
            runner: aRunner
    ]

    "---- S1: the closure reaches a package the operator never named ----"

    testS1_TheClosureReachesAPackageTheOperatorNeverNamed [
        "root-dep depends on deep; the manifest declares only
         root-dep. Exit 0, both pinned, and deep - named in no file
         the operator wrote - was fetched by the closure. The whole
         ruling in one scenario."
        | base work result lock |
        base := self baseTree: 's14-s1-base'.
        work := self rootDepWorkDir: 's14-s1-work'.
        SparseIndexFixtures populateTwoLevelTreeIn: base.
        result := self resolveIn: work base: base runner: ProcessRunner new.
        self assert: result exitCode = 0.
        self assert: result lines = #('deep 1.0.0' 'root-dep 1.0.0').
        lock := self contentsOf: work, '/parley.lock'.
        self assert: (CommandLineFixtures does: lock
            include: '''deep'' ''1.0.0''')
            description: 'the lock does not pin the package the closure reached'.
        self assert: (CommandLineFixtures does: lock
            include: '''root-dep'' ''1.0.0''')
    ]

    "---- S2: and it fetches nothing else, proved by counting ----"

    testS2_AndItFetchesNothingElseProvedByCounting [
        "The same tree with an unrelated package no manifest reaches:
         no curl invocation names it - asserted against the RECORDED
         command lines, never inferred from timing or from the lock.
         Wire efficiency is the reason this shape exists; an
         implementation that fetched the whole index passes S1 and
         fails here."
        | base work runner result |
        base := self baseTree: 's14-s2-base'.
        work := self rootDepWorkDir: 's14-s2-work'.
        SparseIndexFixtures populateTwoLevelTreeIn: base.
        SparseIndexFixtures addUnrelatedTo: base.
        runner := CountingProcessRunner new.
        result := self resolveIn: work base: base runner: runner.
        self assert: result exitCode = 0.
        self assert: (SparseIndexFixtures count: 'unrelated'
            in: (SparseIndexFixtures curlCommandsIn: runner commands)) = 0
            description: 'the closure fetched a package no manifest reaches'.
        self deny: (SparseIndexFixtures curlCommandsIn: runner commands)
            isEmpty
            description: 'nothing was fetched at all - the count above proves nothing'
    ]

    "---- S3: a metadata cycle terminates ----"

    testS3_AMetadataCycleTerminates [
        "cyc-a depends on cyc-b and cyc-b on cyc-a: snapshot answers,
         each artifact is fetched ONCE (counted), and the fixpoint is
         reached rather than approached forever."
        | base cache runner source snapshot curls |
        base := self baseTree: 's14-s3-base'.
        cache := self freshDir: 's14-s3-cache'.
        SparseIndexFixtures populateCycleTreeIn: base.
        runner := CountingProcessRunner new.
        source := self sourceOverTree: base cache: cache
            seeds: #('cyc-a') runner: runner.
        snapshot := source snapshot.
        self assert: (snapshot versionsOf: 'cyc-a') size = 1.
        self assert: (snapshot versionsOf: 'cyc-b') size = 1.
        curls := SparseIndexFixtures curlCommandsIn: runner commands.
        self assert: (SparseIndexFixtures count: 'cyc-a/versions.st'
            in: curls) = 1.
        self assert: (SparseIndexFixtures count: 'cyc-b/versions.st'
            in: curls) = 1.
        self assert: (SparseIndexFixtures count: 'cyc-a-1.0.0.st'
            in: curls) = 1.
        self assert: (SparseIndexFixtures count: 'cyc-b-1.0.0.st'
            in: curls) = 1
    ]

    "---- S4: the closure is seeded from the lock as well ----"

    testS4_TheClosureIsSeededFromTheLockAsWellAsTheManifest [
        "A lock pinning legacy, which the current Package.st no longer
         declares: check --index fetches legacy listing and entry and
         reports on it - a pin the manifest has dropped is still a pin
         the tool must be able to describe. The proof is the RECORDED
         curls naming legacy; the healthy line alone could not carry
         it, because a name the snapshot never reached also answers no
         retirement."
        | base work runner result curls |
        base := self baseTree: 's14-s4-base'.
        work := self rootDepWorkDir: 's14-s4-work'.
        SparseIndexFixtures populateTwoLevelTreeIn: base.
        SparseIndexFixtures addLegacyTo: base.
        SparseIndexFixtures writeLock: (SparseIndexFixtures lockPinning:
            (Array with: #('deep' '1.0.0') with: #('legacy' '1.0.0')
                with: #('root-dep' '1.0.0')))
            in: work.
        runner := CountingProcessRunner new.
        result := self runIn: work
            argv: (Array with: 'check' with: '--index'
                with: (SparseIndexFixtures baseUrlFor: base))
            runner: runner.
        self assert: result exitCode = 0.
        self assert: result lines
            = (Array with: InspectionFixtures healthyLine).
        curls := SparseIndexFixtures curlCommandsIn: runner commands.
        self assert: (SparseIndexFixtures count: 'legacy/versions.st'
            in: curls) = 1
            description: 'the dropped pin did not seed the closure'.
        self assert: (SparseIndexFixtures count: 'legacy-1.0.0.st'
            in: curls) = 1
            description: 'the pinned entry was never fetched'
    ]

    "---- S5: a malformed listing is one batched problem, per kind ----"

    assertMalformedListing: aText problem: aProblem label: aLabel [
        "One kind: the listing text stands where root-dep listing
         must, resolve --index answers exactly the one pinned problem
         at exit 1 - no backtrace, no blame on Parley."
        | base work result |
        base := self baseTree: 's14-s5-', aLabel, '-base'.
        work := self rootDepWorkDir: 's14-s5-', aLabel, '-work'.
        SparseIndexFixtures writeListing: aText for: 'root-dep' in: base.
        result := self resolveIn: work base: base runner: ProcessRunner new.
        self assert: result exitCode = 1
            description: aLabel, ' did not exit 1'.
        self assert: result lines = (Array with: aProblem)
            description: aLabel, ' is not the one pinned problem'
    ]

    testS5_AMalformedListingIsOneBatchedProblemPerKind [
        "Each ground separately: unreadable, wrong tag, missing
         #versions, non-String member, unparseable version."
        self assertMalformedListing:
                SparseIndexFixtures unreadableListingText
            problem: (SparseIndexFixtures
                unreadableListingProblemFor: 'root-dep')
            label: 'unreadable'.
        self assertMalformedListing:
                SparseIndexFixtures wrongTagListingText
            problem: (SparseIndexFixtures
                wrongTagListingProblemFor: 'root-dep'
                tag: #'parley-lock' printString)
            label: 'wrongtag'.
        self assertMalformedListing:
                SparseIndexFixtures missingVersionsListingText
            problem: (SparseIndexFixtures
                missingVersionsKeyProblemFor: 'root-dep')
            label: 'missingkey'.
        self assertMalformedListing:
                SparseIndexFixtures nonStringMemberListingText
            problem: (SparseIndexFixtures
                nonStringMemberProblemFor: 'root-dep'
                value: 42 printString)
            label: 'nonstring'.
        self assertMalformedListing:
                SparseIndexFixtures unparseableVersionListingText
            problem: (SparseIndexFixtures
                unparseableVersionProblemFor: 'root-dep'
                value: 'abc')
            label: 'unparseable'
    ]

    "---- S6: the whitelist grew, and its sentence grew with it ----"

    testS6_TheReadersWhitelistGrewAndItsSentenceGrewWithIt [
        "The rejection names EVERY tag this Parley reads, because it is
         rendered from formatTags and is the only place an operator
         learns what a build accepts (Doc B §7).

         RE-PINNED AT SPRINT 19'S RED, AND THE RE-PIN IS THE LAW WORKING
         (declared on issue #21). #'parley-config' joined the whitelist
         as a declared settled-class exception — the reader enforces the
         whitelist inside readFrom:, so the operator's own configuration
         file is unreadable without it — and Doc B §7 requires the
         sentence to grow IN THE SAME CHANGE. This literal is what makes
         that requirement bite: a widening that left the sentence behind
         fails here, which is exactly what happened at Sprint 14 and is
         why the law exists. Four tags became five."
        | expected |
        expected := 'unknown format tag #''parley-mystery'': this Parley reads #''parley-index'', #''parley-lock'', #''parley-retired'', #''parley-listing'' and #''parley-config'' artifacts'.
        [IndexEntryReader readFrom:
            (ReadStream on: '#(#''parley-mystery'' 1)').
         self assert: false description: 'expected an IndexEntryFormatError']
            on: Error
            do: [:e |
                self assert: (e isKindOf: IndexEntryFormatError)
                    description: 'expected an IndexEntryFormatError, got ',
                        e class name.
                self assert: e messageText = expected]
    ]

    "---- S7: a listing miss for a declared name is ordinary ----"

    testS7_AListingMissForADeclaredNameIsAnOrdinaryEmptyCandidateSet [
        "ghost is declared and the base publishes no ghost directory:
         exit 1 with the settled #noVersions ConflictReport narration -
         NOT a SourceError, not a crash. A name the closure cannot
         reach is indistinguishable from one the index does not
         publish (decision 47)."
        | base work result named |
        base := self baseTree: 's14-s7-base'.
        work := self track: (SparseIndexFixtures workDirNamed: 's14-s7-work'
            declaring: 'ghost' constraint: '^1.0').
        SparseIndexFixtures populateTwoLevelTreeIn: base.
        result := self resolveIn: work base: base runner: ProcessRunner new.
        self assert: result exitCode = 1.
        named := result lines select: [:line |
            CommandLineFixtures does: line include: 'no version of ghost'].
        self deny: named isEmpty
            description: 'no line carries the #noVersions narration for ghost'.
        result lines do: [:line |
            self deny: (CommandLineFixtures does: line
                include: LockBoundaryFixtures undiagnosedLinePrefix)
                description: 'the miss blames Parley: ', line.
            self deny: (CommandLineFixtures does: line include: 'curl')
                description: 'the miss leaked the transport: ', line]
    ]

    "---- S8: an entry a listing names and does not have ----"

    testS8_AnEntryAListingNamesAndDoesNotHaveIsAnIndexDefect [
        "holey listing declares 1.0.0 and 2.0.0; only the 1.0.0 entry
         exists. One SourceError problem naming BOTH files, batched.
         The distinction from S7 is the point: the index made a claim
         it did not keep."
        | base work result |
        base := self baseTree: 's14-s8-base'.
        work := self track: (SparseIndexFixtures workDirNamed: 's14-s8-work'
            declaring: 'holey' constraint: '^1.0').
        SparseIndexFixtures populateAbsentEntryTreeIn: base.
        result := self resolveIn: work base: base runner: ProcessRunner new.
        self assert: result exitCode = 1.
        self assert: result lines = (Array with:
            (SparseIndexFixtures missingEntryProblemFor: 'holey'
                version: '2.0.0'))
    ]

    "---- S9: an undeclared curl exit is a transport failure ----"

    testS9_AnUndeclaredCurlExitIsATransportFailureNamedExactly [
        "A runner answering an exit outside the declared grounds: one
         pinned SourceError problem carrying the EXACT command line
         and exit code - the GitIndexSource transport-failure
         precedent verbatim. Exit 1, never 70."
        | base work baseUrl cache command result |
        base := self baseTree: 's14-s9-base'.
        work := self rootDepWorkDir: 's14-s9-work'.
        SparseIndexFixtures populateTwoLevelTreeIn: base.
        baseUrl := SparseIndexFixtures baseUrlFor: base.
        cache := SparseIndexFixtures indexCachePathIn: work forBase: baseUrl.
        command := SparseIndexFixtures
            curlCommandFor: (SparseIndexFixtures listingUrlFor: baseUrl
                name: 'root-dep')
            to: (SparseIndexFixtures cachedListingPathIn: cache
                for: 'root-dep').
        result := self runIn: work
            argv: (Array with: 'resolve' with: '--index' with: baseUrl)
            runner: (RecordingRunner answering: 9).
        self assert: result exitCode = 1.
        self assert: result lines = (Array with:
            (SparseIndexFixtures curlFailureProblemFor: command code: 9))
    ]

    "---- S10: a listing never enters the scanned entries directory ----"

    testS10_AListingNeverEntersTheScannedEntriesDirectory [
        "After a full closure the cache holds listings AND entries;
         the inner DirectorySource scan is clean and the settled scan
         wording never fires. Two settled laws pin the wording that
         would fire if a listing sat in the scan, so this scenario is
         what keeps the cache layout honest - proved again by a second
         resolve over the already-populated cache."
        | base work baseUrl cache entryFiles result |
        base := self baseTree: 's14-s10-base'.
        work := self rootDepWorkDir: 's14-s10-work'.
        SparseIndexFixtures populateTwoLevelTreeIn: base.
        baseUrl := SparseIndexFixtures baseUrlFor: base.
        result := self resolveIn: work base: base runner: ProcessRunner new.
        self assert: result exitCode = 0.
        cache := SparseIndexFixtures indexCachePathIn: work forBase: baseUrl.
        self assert: (self exists:
            (SparseIndexFixtures cachedListingPathIn: cache for: 'root-dep'))
            description: 'no cached listing - the layout claim below is vacuous'.
        entryFiles := PublishFixtures fileNamesIn:
            (SparseIndexFixtures entriesDirIn: cache).
        self assert: (entryFiles includes: 'root-dep-1.0.0.st').
        self assert: (entryFiles includes: 'deep-1.0.0.st').
        entryFiles do: [:each |
            self deny: each = SparseIndexFixtures listingFileName
                description: 'a listing sits in the scanned entries directory'].
        result := self resolveIn: work base: base runner: ProcessRunner new.
        self assert: result exitCode = 0
            description: 'the scan over the populated cache is not clean'
    ]

    "---- S11: the metadata/archive split holds across the seam ----"

    testS11_TheMetadataArchiveSplitHoldsAcrossTheSeam [
        "No .star is fetched before or during resolution;
         fetch:version: fetches it at install time; the settled hash
         verification passes on the fetched bytes; and a second
         install spawns nothing for a cache-hit archive."
        | starBytes digest base work runner result curls starCount |
        starBytes := ExecFixtures probeStarBytesLabeled: 's14-s11'.
        digest := Sha256 hexDigestOf: starBytes.
        base := self baseTree: 's14-s11-base'.
        work := self track: (SparseIndexFixtures workDirNamed: 's14-s11-work'
            declaring: 'parley-probe' constraint: '^1.0').
        SparseIndexFixtures populateProbeTreeIn: base bytes: starBytes.
        runner := CountingProcessRunner new.
        result := self resolveIn: work base: base runner: runner.
        self assert: result exitCode = 0.
        curls := SparseIndexFixtures curlCommandsIn: runner commands.
        self assert: (SparseIndexFixtures count: '.star' in: curls) = 0
            description: 'an archive was fetched during resolution'.
        result := self installIn: work base: base runner: runner.
        self assert: result exitCode = 0.
        self assert: ((ContentStore on: (CommandLineFixtures
            storeRootIn: work)) containsHash: digest)
            description: 'the fetched archive did not hash-verify into the store'.
        curls := SparseIndexFixtures curlCommandsIn: runner commands.
        starCount := SparseIndexFixtures count: '.star' in: curls.
        self assert: starCount = 1
            description: 'expected exactly one archive fetch at install time'.
        result := self installIn: work base: base runner: runner.
        self assert: result exitCode = 0.
        curls := SparseIndexFixtures curlCommandsIn: runner commands.
        self assert: (SparseIndexFixtures count: '.star' in: curls) = 1
            description: 'a cache-hit archive was fetched again'
    ]

    "---- S12: determinism, in messages the class already answers ----"

    testS12_DeterminismInMessagesTheClassAlreadyAnswers [
        "The same tree resolved twice: byte-identical lockfiles; and a
         second snapshot agrees with the first on versionsOf:,
         dependenciesOf:version: and sha256For:version: for every name
         in the closure. Stated this way deliberately: IndexSnapshot
         has no value equality and this sprint does not add it
         (decision 23)."
        | base workA workB cache source first second v |
        base := self baseTree: 's14-s12-base'.
        workA := self rootDepWorkDir: 's14-s12-work-a'.
        workB := self rootDepWorkDir: 's14-s12-work-b'.
        SparseIndexFixtures populateTwoLevelTreeIn: base.
        self assert: (self resolveIn: workA base: base
            runner: ProcessRunner new) exitCode = 0.
        self assert: (self resolveIn: workB base: base
            runner: ProcessRunner new) exitCode = 0.
        self assert: (self contentsOf: workA, '/parley.lock')
            = (self contentsOf: workB, '/parley.lock')
            description: 'the same tree did not answer a byte-identical lock'.
        cache := self freshDir: 's14-s12-cache'.
        source := self sourceOverTree: base cache: cache
            seeds: #('root-dep') runner: ProcessRunner new.
        first := source snapshot.
        second := source snapshot.
        v := self version: '1.0.0'.
        #('deep' 'root-dep') do: [:name |
            self assert: (first versionsOf: name)
                = (second versionsOf: name).
            self assert: (first dependenciesOf: name version: v) printString
                = (second dependenciesOf: name version: v) printString.
            self assert: (first sha256For: name version: v)
                = (second sha256For: name version: v)]
    ]

    "---- S13: the flag, the cache, and the drift law ----"

    testS13_TheFlagTheCacheAndTheDriftLaw [
        "--index builds a SparseIndexSource with its cache at
         <work>/.parley/index/<sha256 of the base URL>/ and nothing
         beside the process cwd; the sourceFlags table carries the
         third row (the drift law in SourceFlagTest independently
         forces it); --index with --source or --git is a usage error
         at exit 2; and the usage flags: lines name it while the
         verbs: line is unchanged."
        | base work baseUrl result usage |
        base := self baseTree: 's14-s13-base'.
        work := self rootDepWorkDir: 's14-s13-work'.
        SparseIndexFixtures populateTwoLevelTreeIn: base.
        baseUrl := SparseIndexFixtures baseUrlFor: base.
        self assert: (LockBoundaryFixtures flagNamesIn:
            CommandLine sourceFlags)
                = #('--git' '--index' '--source').
        result := self runIn: work
            argv: (Array with: 'resolve' with: '--index' with: baseUrl)
            runner: ProcessRunner new.
        self assert: result exitCode = 0.
        self assert: (self exists:
            (SparseIndexFixtures indexCachePathIn: work forBase: baseUrl))
            description: 'no cache under the working directory'.
        self deny: (self exists: SparseIndexFixtures cwdIndexCacheRoot)
            description: 'a cache was created beside the process cwd'.
        usage := self runIn: work
            argv: (Array with: 'resolve' with: '--index' with: baseUrl
                with: '--source') , (Array with: base)
            runner: TrapRunner new.
        self assert: usage exitCode = 2.
        self assert: (usage lines at: 1)
            = SparseIndexFixtures usageHeaderLine.
        self assert: (usage lines includes:
            SparseIndexFixtures indexFlagUsageLine)
            description: 'no flags: line describes --index'.
        self assert: (usage lines at: 2) = (ExecFixtures usageLines at: 2)
            description: 'the verbs: line moved, and no verb moves this sprint'.
        usage := self runIn: work
            argv: (Array with: 'resolve' with: '--git' with: base
                with: '--index') , (Array with: baseUrl)
            runner: TrapRunner new.
        self assert: usage exitCode = 2
    ]

    "---- S14: end to end, offline (the sprint's exit criterion) ----"

    testS14_EndToEndOfflineAPackageLandsInAnImageFromASparseIndex [
        "resolve, install and exec against a file:// sparse base with
         a real toolchain-built star: the lock is written, the archive
         is fetched and hash-verified into the store, the registration
         plan runs, and a curated child proves the class visible. A
         project resolves, locks, installs and registers against an
         index it never downloaded in full - asserted, not described."
        | starBytes digest base work runner result proofPath |
        starBytes := ExecFixtures probeStarBytesLabeled: 's14-s14'.
        digest := Sha256 hexDigestOf: starBytes.
        base := self baseTree: 's14-s14-base'.
        work := self track: (SparseIndexFixtures workDirNamed: 's14-s14-work'
            declaring: 'parley-probe' constraint: '^1.0').
        SparseIndexFixtures populateProbeTreeIn: base bytes: starBytes.
        runner := ProcessRunner new.
        result := self resolveIn: work base: base runner: runner.
        self assert: result exitCode = 0.
        self assert: result lines = CommandLineFixtures probePinLines.
        result := self installIn: work base: base runner: runner.
        self assert: result exitCode = 0.
        self assert: ((ContentStore on: (CommandLineFixtures
            storeRootIn: work)) containsHash: digest).
        self assert: (self contentsOf: (CommandLineFixtures
            targetDirIn: work), '/parley-probe.star') = starBytes.
        proofPath := work, '/proof.txt'.
        SourceFixtures
            write: (ExecFixtures proofScriptContentsFor: proofPath)
            toFile: 'proof-script.st' in: work.
        result := self runIn: work
            argv: (Array with: 'exec' with: work, '/proof-script.st')
            runner: runner.
        self assert: result exitCode = 0.
        self assert: (self contentsOf: proofPath) = 'present'
            description: 'the curated child cannot see the installed class'
    ]

    "---- S15: a listing is re-fetched every snapshot; entries not ----"

    testS15_AListingIsReFetchedEverySnapshotAndACachedEntryIsNot [
        "The GitIndexSource upstream-growth precedent applied to the
         second remote source, and the one property nothing else in
         this table can see: an implementation that cached listings
         forever passes S1-S14 unchanged and fails here. A new version
         published after the first snapshot is OFFERED by the second -
         the listing really was re-fetched - while every entry already
         cached is not fetched again. Counted, never inferred."
        | base cache runner source curls |
        base := self baseTree: 's14-s15-base'.
        cache := self freshDir: 's14-s15-cache'.
        SparseIndexFixtures populateTwoLevelTreeIn: base.
        runner := CountingProcessRunner new.
        source := self sourceOverTree: base cache: cache
            seeds: #('root-dep') runner: runner.
        source snapshot.
        SparseIndexFixtures growDeepIn: base.
        self assert: ((source snapshot versionsOf: 'deep')
            includes: (self version: '1.1.0'))
            description: 'the second snapshot does not offer the new version'.
        curls := SparseIndexFixtures curlCommandsIn: runner commands.
        self assert: (SparseIndexFixtures count: 'deep/versions.st'
            in: curls) = 2
            description: 'the listing was not re-fetched by the second snapshot'.
        self assert: (SparseIndexFixtures count: 'deep-1.1.0.st'
            in: curls) = 1
            description: 'the new entry was not fetched exactly once'.
        self assert: (SparseIndexFixtures count: 'deep-1.0.0.st'
            in: curls) = 1
            description: 'a cached entry was fetched again'
    ]

    "---- S16: add --index seeds the name it is adding ----"

    testS16_AddSeedsTheNameItIsAdding [
        "THE REGRESSION THIS LAW EXISTS FOR IS EXACT AND TOTAL:
         CLI add:constraint: snapshots BEFORE it edits Package.st, so
         the added name is in neither file the seed set is otherwise
         built from. Unseeded, the closure never fetches the added
         name's listing, decision 47 makes the miss an empty candidate
         set,
         and the verb fails EVERY time with a #noVersions conflict
         that blames the package while atomically restoring the file -
         a regression no scanning source could ever notice. Exit 0 is
         therefore a sufficient assertion, and it is asserted with the
         edit and the pin so a pass says the seed reached the closure."
        | starBytes base work result |
        starBytes := ExecFixtures probeStarBytesLabeled: 's14-s16'.
        base := self baseTree: 's14-s16-base'.
        work := self freshDir: 's14-s16-work'.
        SparseIndexFixtures populateProbeTreeIn: base bytes: starBytes.
        ExecFixtures writePackage: ExecFixtures initTemplateContents
            in: work.
        result := self runIn: work
            argv: (Array with: 'add' with: 'parley-probe' with: '^1.0'
                with: '--index'
                with: (SparseIndexFixtures baseUrlFor: base))
            runner: ProcessRunner new.
        self assert: result exitCode = 0
            description: 'add --index failed - the added name was not seeded'.
        self assert: (CommandLineFixtures does:
            (self contentsOf: work, '/Package.st')
            include: 'dependency: ''parley-probe'' constraint: ''^1.0''')
            description: 'Package.st did not gain the clause'.
        self assert: (CommandLineFixtures does:
            (self contentsOf: work, '/parley.lock')
            include: '''parley-probe'' ''1.0.0''')
            description: 'the lock does not pin the added package'
    ]
]

Namespace current: Smalltalk.
