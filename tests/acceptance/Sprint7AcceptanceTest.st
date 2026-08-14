"Parley Sprint 7 — acceptance scenarios S1-S18 from GitHub issue #9.
 Each scenario Sn maps to exactly one selector starting with testSn_
 (enforced by the wrap traceability gate).

 Phase 4 opens (Doc F): the schema-shape validation that turns a
 malformed entry into a diagnosis instead of a crash (S1-S3), the
 archive-carrying writer selector (S4-S5), the Publisher pipeline —
 real toolchain build, refusal-first, batched pre-flight, build
 fail-stop (S6-S10), GitIndexSource as a git checkout used as an index
 directory (S11-S14), the CLI publish verb (S15-S17), and the exit
 criterion: author A publishes, author B resolves, installs and
 EXECUTES A's package, including through a GitIndexSource clone —
 the ecosystem loop closes (S18).

 Two scenarios PASS IN RED, both declared on issue #9: S5 (the settled
 writer's output is byte-unchanged — a regression guard, not new
 behavior) and S17 (publish without a directory answers usage — the
 settled CLI already answers usage for unknown shapes).

 Real processes appear only where the law under test IS execution
 (S6, S7, S11, S12, S13, S14, S15, S18), always confined to tmp/;
 every such test touches the missing class (Publisher /
 GitIndexSource) or asserts a not-yet-implemented CLI verb's exit code
 before anything could spawn, so the red phase spawns nothing. Git
 fixtures are local-path repositories built through ProcessRunner with
 per-command committer identity: no network is contacted, ever, and
 the developer's git config is never touched. The developer image is
 never mutated. Exact wordings, byte oracles and the fixture scheme
 are pinned in PublishFixtures and posted on issue #9."

Namespace current: Parley.

TestCase subclass: Sprint7AcceptanceTest [
    | fixtureDirs |

    <comment: 'Acceptance scenarios for Sprint 7: schema-shape
validation in the DirectorySource scan, IndexEntryWriter
write:archive:sha256:on:, Publisher and PublishError, GitIndexSource,
and the CLI publish verb — the ecosystem loop. Fixture trees live
under tmp/ and are removed recursively in tearDown.'>

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

    freshStoreRoot: aLabel [
        ^self track: (InstallFixtures storeRootNamed: aLabel)
    ]

    absentPath: aLabel [
        ^self track: (PublishFixtures absentPathNamed: aLabel)
    ]

    greetingWorkDir: aLabel [
        | path |
        path := self freshDir: aLabel.
        PublishFixtures populateGreetingWorkDirIn: path.
        ^path
    ]

    version: aString [
        ^Version fromString: aString
    ]

    contentsOf: aPath [
        ^(File name: aPath) contents
    ]

    versionStringsOf: aCollection [
        ^((aCollection collect: [:each | each printString])
            asSortedCollection: [:a :b | a <= b]) asArray
    ]

    cliIn: aWorkDir source: aSource storeRoot: aStoreRoot target: aTarget runner: aRunner [
        ^CLI in: aWorkDir
            source: aSource
            store: (ContentStore on: aStoreRoot)
            target: aTarget
            runner: aRunner
    ]

    sourceProblemsFrom: aBlock [
        [aBlock value.
         self assert: false description: 'expected a SourceError']
            on: Error
            do: [:e |
                self assert: (e isKindOf: SourceError)
                    description: 'expected a SourceError, got ', e class name.
                ^e problems].
        ^#()
    ]

    publishProblemsFrom: aBlock [
        [aBlock value.
         self assert: false description: 'expected a PublishError']
            on: Error
            do: [:e |
                self assert: (e isKindOf: PublishError)
                    description: 'expected a PublishError, got ', e class name.
                ^e problems].
        ^#()
    ]

    lockStringOf: aResolution [
        | stream |
        stream := WriteStream on: String new.
        IndexEntryWriter writeLock: aResolution on: stream.
        ^stream contents
    ]

    "---- S1: a missing schema key is a diagnosis, not a crash ----"

    testS1_aMissingSchemaKeyIsADiagnosis [
        | dir problems |
        dir := self freshDir: 's1-entries'.
        SourceFixtures write: PublishFixtures entryMissingSummary
            toFile: 'p-1.0.0.st' in: dir.
        problems := self sourceProblemsFrom: [
            (DirectorySource on: dir) snapshot].
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = (PublishFixtures missingKeyProblemFor: 'p-1.0.0.st'
                key: #summary)
    ]

    "---- S2: a malformed #archive shape is a diagnosis ----"

    testS2_aMalformedArchiveShapeIsADiagnosis [
        | dir problems |
        dir := self freshDir: 's2-entries'.
        SourceFixtures write: PublishFixtures entryWithMalformedArchive
            toFile: 'p-1.0.0.st' in: dir.
        problems := self sourceProblemsFrom: [
            (DirectorySource on: dir) snapshot].
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = (PublishFixtures archiveKindProblemFor: 'p-1.0.0.st')
    ]

    "---- S3: shape problems batch; clean directories still scan ----"

    testS3_shapeProblemsBatchAndCleanDirectoriesStillScan [
        | bad clean problems snap |
        bad := self freshDir: 's3-bad'.
        SourceFixtures write: PublishFixtures entryMissingSummary
            toFile: 'aa-missing.st' in: bad.
        SourceFixtures write: PublishFixtures entryWithMalformedArchive
            toFile: 'mm-archive.st' in: bad.
        SourceFixtures write: PublishFixtures validEntryP
            toFile: 'zz-valid.st' in: bad.
        problems := self sourceProblemsFrom: [
            (DirectorySource on: bad) snapshot].
        self assert: problems size = 2.
        self assert: (problems at: 1)
            = (PublishFixtures missingKeyProblemFor: 'aa-missing.st'
                key: #summary).
        self assert: (problems at: 2)
            = (PublishFixtures archiveKindProblemFor: 'mm-archive.st').
        clean := self freshDir: 's3-clean'.
        SourceFixtures populateDiamondIn: clean.
        snap := (DirectorySource on: clean) snapshot.
        self assert: (self versionStringsOf: (snap versionsOf: 'c'))
            = #('1.5.0' '2.4.0' '3.0.0')
    ]

    "---- S4: the writer emits the published entry ----"

    testS4_theWriterEmitsThePublishedEntry [
        | stream |
        stream := WriteStream on: String new.
        IndexEntryWriter
            write: PublishFixtures templateManifest
            archive: PublishFixtures templateArchiveFileName
            sha256: PublishFixtures archiveDigest
            on: stream.
        self assert: stream contents
            = PublishFixtures templateArchiveEntryString
    ]

    "---- S5: the settled writer output is byte-unchanged (passes in red) ----"

    testS5_theSettledWriterOutputIsByteUnchanged [
        | stream |
        stream := WriteStream on: String new.
        IndexEntryWriter write: PublishFixtures templateManifest
            on: stream.
        self assert: stream contents = PublishFixtures templateEntryString
    ]

    "---- S6: publish builds a real archive and lands the release ----"

    testS6_publishBuildsARealArchiveAndLandsTheRelease [
        | work dest publisher digest starBytes |
        work := self greetingWorkDir: 's6-work'.
        dest := self freshDir: 's6-dest'.
        publisher := Publisher
            manifest: PublishFixtures greetingManifest
            in: work
            to: dest
            runner: ProcessRunner new.
        self assert: publisher packageXml
            = PublishFixtures greetingPackageXml.
        digest := publisher publish.
        starBytes := self contentsOf: dest, '/',
            PublishFixtures archiveFileName.
        self assert: digest = (Sha256 hexDigestOf: starBytes).
        self assert: (self contentsOf: dest, '/', PublishFixtures entryFileName)
            = (PublishFixtures greetingEntryWithDigest: digest).
        self deny: (File name: (PublishFixtures stageDirIn: dest)) exists.
        self assert: (PublishFixtures fileNamesIn: dest)
            = (Array
                with: PublishFixtures entryFileName
                with: PublishFixtures archiveFileName)
    ]

    "---- S7: the published directory resolves ----"

    testS7_thePublishedDirectoryResolves [
        | work dest digest snap |
        work := self greetingWorkDir: 's7-work'.
        dest := self freshDir: 's7-dest'.
        digest := (Publisher
            manifest: PublishFixtures greetingManifest
            in: work
            to: dest
            runner: ProcessRunner new) publish.
        snap := (DirectorySource on: dest) snapshot.
        self assert: (self versionStringsOf:
            (snap versionsOf: 'kernel-greeting')) = #('1.0.0').
        self assert: (snap sha256For: 'kernel-greeting'
            version: (self version: '1.0.0')) = digest.
        self assert: (snap dependenciesOf: 'kernel-greeting'
            version: (self version: '1.0.0')) isEmpty
    ]

    "---- S8: republishing refuses first ----"

    testS8_republishingRefusesFirst [
        | work dest runner before problems |
        work := self greetingWorkDir: 's8-work'.
        dest := self freshDir: 's8-dest'.
        SourceFixtures write: 'already published'
            toFile: PublishFixtures entryFileName in: dest.
        before := PublishFixtures fileNamesIn: dest.
        runner := RecordingRunner new.
        problems := self publishProblemsFrom: [
            (Publisher
                manifest: PublishFixtures greetingManifest
                in: work
                to: dest
                runner: runner) publish].
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = (PublishFixtures refusalProblemFor: 'kernel-greeting'
                version: '1.0.0' in: dest).
        self assert: runner commands = #().
        self assert: (PublishFixtures fileNamesIn: dest) = before.
        self assert: (self contentsOf: dest, '/', PublishFixtures entryFileName)
            = 'already published'
    ]

    "---- S9: missing fileIns batch before anything happens ----"

    testS9_missingFileInsBatchBeforeAnythingHappens [
        | work dest runner problems |
        work := self freshDir: 's9-work'.
        dest := self freshDir: 's9-dest'.
        runner := RecordingRunner new.
        problems := self publishProblemsFrom: [
            (Publisher
                manifest: PublishFixtures absentFileInsManifest
                in: work
                to: dest
                runner: runner) publish].
        self assert: problems size = 2.
        self assert: (problems at: 1)
            = (PublishFixtures missingFileInProblemFor: 'Alpha.st' in: work).
        self assert: (problems at: 2)
            = (PublishFixtures missingFileInProblemFor: 'Zebra.st' in: work).
        self assert: runner commands = #().
        self assert: (PublishFixtures fileNamesIn: dest) = #()
    ]

    "---- S10: a failed build is fail-stop ----"

    testS10_aFailedBuildIsFailStop [
        | work dest runner problems |
        work := self greetingWorkDir: 's10-work'.
        dest := self freshDir: 's10-dest'.
        runner := RecordingRunner answering: 2.
        problems := self publishProblemsFrom: [
            (Publisher
                manifest: PublishFixtures greetingManifest
                in: work
                to: dest
                runner: runner) publish].
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = (PublishFixtures buildFailureProblemFor:
                (PublishFixtures buildCommandFor: dest) code: 2).
        self deny: (File name: dest, '/', PublishFixtures archiveFileName)
            exists.
        self deny: (File name: dest, '/', PublishFixtures entryFileName)
            exists
    ]

    "---- S11: the first snapshot clones ----"

    testS11_theFirstSnapshotClones [
        | repo cache source snap control |
        repo := self absentPath: 's11-repo'.
        cache := self absentPath: 's11-cache'.
        source := GitIndexSource repo: repo cache: cache
            runner: ProcessRunner new.
        PublishFixtures buildDiamondRepoAt: repo.
        self deny: (File name: cache) exists.
        snap := source snapshot.
        self assert: (File name: cache) exists.
        control := (DirectorySource on: repo) snapshot.
        #('a' 'b' 'c') do: [:name |
            self assert: (self versionStringsOf: (snap versionsOf: name))
                = (self versionStringsOf: (control versionsOf: name))].
        self assert: (snap sha256For: 'c' version: (self version: '2.4.0'))
            = InstallFixtures digestC24
    ]

    "---- S12: a later snapshot sees upstream growth ----"

    testS12_aLaterSnapshotSeesUpstreamGrowth [
        | repo cache source first second |
        repo := self absentPath: 's12-repo'.
        cache := self absentPath: 's12-cache'.
        source := GitIndexSource repo: repo cache: cache
            runner: ProcessRunner new.
        PublishFixtures buildDiamondRepoAt: repo.
        first := source snapshot.
        self assert: (first versionsOf: 'd') isEmpty.
        PublishFixtures growDiamondRepoAt: repo.
        second := source snapshot.
        self assert: (self versionStringsOf: (second versionsOf: 'd'))
            = #('1.0.0')
    ]

    "---- S13: a git failure is one SourceError ----"

    testS13_aGitFailureIsOneSourceError [
        | repo cache source problems |
        repo := self absentPath: 's13-repo'.
        cache := self absentPath: 's13-cache'.
        source := GitIndexSource repo: repo cache: cache
            runner: ProcessRunner new.
        problems := self sourceProblemsFrom: [source snapshot].
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = (PublishFixtures
                gitFailureProblemFor: (PublishFixtures cloneCommandFor: repo
                    cache: cache)
                code: 128)
    ]

    "---- S14: fetch reads the checkout, never git ----"

    testS14_fetchReadsTheCheckoutNeverGit [
        | repo cache source bytes |
        repo := self absentPath: 's14-repo'.
        cache := self absentPath: 's14-cache'.
        source := GitIndexSource repo: repo cache: cache
            runner: ProcessRunner new.
        PublishFixtures buildArchiveRepoAt: repo.
        source snapshot.
        PublishFixtures moveArchiveUpstreamAt: repo.
        bytes := source fetch: 'f' version: (self version: '1.0.0').
        self assert: bytes = PublishFixtures checkoutArchiveBytes.
        self deny: bytes = PublishFixtures movedArchiveBytes
    ]

    "---- S15: the publish verb succeeds ----"

    testS15_thePublishVerbSucceeds [
        | work dest cli result digest |
        work := self greetingWorkDir: 's15-work'.
        dest := self freshDir: 's15-dest'.
        cli := self cliIn: work
            source: nil
            storeRoot: 'tmp/parley-s15-store'
            target: 'tmp/parley-s15-target'
            runner: ProcessRunner new.
        result := cli run: (Array with: 'publish' with: dest).
        self assert: result exitCode = 0.
        self assert: result lines = (Array with:
            (PublishFixtures publishSuccessLineFor: 'kernel-greeting'
                version: '1.0.0')).
        digest := Sha256 hexDigestOf:
            (self contentsOf: dest, '/', PublishFixtures archiveFileName).
        self assert: (self contentsOf: dest, '/', PublishFixtures entryFileName)
            = (PublishFixtures greetingEntryWithDigest: digest)
    ]

    "---- S16: the publish verb surfaces problems ----"

    testS16_thePublishVerbSurfacesProblems [
        | work dest runner cli result |
        work := self greetingWorkDir: 's16-work'.
        dest := self freshDir: 's16-dest'.
        SourceFixtures write: 'already published'
            toFile: PublishFixtures entryFileName in: dest.
        runner := RecordingRunner new.
        cli := self cliIn: work
            source: nil
            storeRoot: 'tmp/parley-s16-store'
            target: 'tmp/parley-s16-target'
            runner: runner.
        result := cli run: (Array with: 'publish' with: dest).
        self assert: result exitCode = 1.
        self assert: result lines = (Array with:
            (PublishFixtures refusalProblemFor: 'kernel-greeting'
                version: '1.0.0' in: dest)).
        self assert: runner commands = #()
    ]

    "---- S17: publish without a directory answers usage (passes in red) ----"

    testS17_publishWithoutADirectoryAnswersUsage [
        | cli result |
        cli := self cliIn: 'tmp/parley-s17-work'
            source: nil
            storeRoot: 'tmp/parley-s17-store'
            target: 'tmp/parley-s17-target'
            runner: RecordingRunner new.
        result := cli run: #('publish').
        self assert: result exitCode = 2.
        self assert: result lines = (GrammarFixtures
            usageAnswerFor: #wrongArguments subject: 'publish')
            description: 'publish without a directory answered ',
                result lines printString
    ]

    "---- S18: the ecosystem loop closes (the sprint's exit) ----"

    testS18_theEcosystemLoopCloses [
        | runner authorWork index cliA rPublish digest bWork bStore bTarget cliB
          rInstall proofPath rExec repo cache gitSource gitSnap dirOutcome gitOutcome |
        runner := ProcessRunner new.
        "author A publishes"
        authorWork := self greetingWorkDir: 's18-author'.
        index := self freshDir: 's18-index'.
        cliA := self cliIn: authorWork
            source: nil
            storeRoot: (self freshStoreRoot: 's18-author-store')
            target: (self freshDir: 's18-author-target')
            runner: runner.
        rPublish := cliA run: (Array with: 'publish' with: index).
        self assert: rPublish exitCode = 0.
        self assert: rPublish lines = (Array with:
            (PublishFixtures publishSuccessLineFor: 'kernel-greeting'
                version: '1.0.0')).
        digest := Sha256 hexDigestOf:
            (self contentsOf: index, '/', PublishFixtures archiveFileName).
        "author B installs and executes"
        bWork := self freshDir: 's18-consumer'.
        ExecFixtures writePackage: PublishFixtures greetingRootContents
            in: bWork.
        bStore := self freshStoreRoot: 's18-consumer-store'.
        bTarget := self freshDir: 's18-consumer-target'.
        cliB := self cliIn: bWork
            source: (DirectorySource on: index)
            storeRoot: bStore
            target: bTarget
            runner: runner.
        rInstall := cliB run: #('install').
        self assert: rInstall exitCode = 0.
        self assert: rInstall lines = #('kernel-greeting 1.0.0').
        self assert: ((ContentStore on: bStore) containsHash: digest).
        proofPath := bWork, '/proof.txt'.
        SourceFixtures
            write: (PublishFixtures greetingProofScriptContentsFor: proofPath)
            toFile: 'proof-script.st' in: bWork.
        "workdir-relative argv (Sprint 22: the script resolves against
         the working directory, never the process cwd)"
        rExec := cliB run: (Array with: 'exec' with: 'proof-script.st').
        self assert: rExec exitCode = 0.
        self assert: (self contentsOf: proofPath) = 'present'.
        "the same index, resolved through a GitIndexSource clone"
        repo := self absentPath: 's18-repo'.
        cache := self absentPath: 's18-cache'.
        gitSource := GitIndexSource repo: repo cache: cache runner: runner.
        PublishFixtures buildRepoAt: repo fromIndex: index.
        gitSnap := gitSource snapshot.
        dirOutcome := ResolverFixtures
            resolve: PublishFixtures greetingRootManifest
            against: (DirectorySource on: index) snapshot.
        gitOutcome := ResolverFixtures
            resolve: PublishFixtures greetingRootManifest
            against: gitSnap.
        self assert: dirOutcome isResolution.
        self assert: gitOutcome isResolution.
        self assert: (gitOutcome versionOf: 'kernel-greeting')
            = (self version: '1.0.0').
        self assert: (gitOutcome sha256Of: 'kernel-greeting') = digest.
        self assert: (self lockStringOf: gitOutcome)
            = (self lockStringOf: dirOutcome)
    ]
]

Namespace current: Smalltalk.
