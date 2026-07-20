"Parley Sprint 6 — acceptance scenarios S1-S19 from GitHub issue #8
 (as amended by the issue #8 ruling). Each scenario Sn maps to exactly
 one selector starting with testSn_ (enforced by the wrap traceability
 gate).

 The Orchestration Bridge (Doc E): the real ProcessRunner exit-code
 laws (S1-S2), the ExecutionScope pinned child composition, real
 staged registration, real fail-stop and the real curated child
 (S3-S6), the end-to-end 'a package lands in an image' exit criterion
 over a toolchain-BUILT parley-probe star (S7), ManifestFile and
 decision 19 (S8-S9), and the CLI verbs over doubles (S10-S19).

 Real processes appear only where the law under test IS execution
 (S1-S2, S4-S7), always confined to tmp/; every such test touches the
 missing runner class (directly or through the star-building fixture)
 before anything could spawn, so the red phase spawns nothing. The
 developer image is never mutated. Exact wordings, the argv grammar,
 the lock oracles and the fixture scheme are pinned in ExecFixtures
 and posted on issue #8 for confirmation."

Namespace current: Parley.

TestCase subclass: Sprint6AcceptanceTest [
    | fixtureDirs |

    <comment: 'Acceptance scenarios for Sprint 6: ProcessRunner,
ExecutionScope, ExecutionError, ManifestFile, CLI and CliResult —
the process seam, the curated child image, and the package-manager
verbs. Fixture trees live under tmp/ and are removed recursively in
tearDown.'>

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

    diamondEntriesDir: aLabel [
        | path |
        path := self freshDir: aLabel.
        InstallFixtures populateInstallDiamondIn: path.
        ^path
    ]

    workDir: aLabel package: aContentsString [
        | path |
        path := self freshDir: aLabel.
        ExecFixtures writePackage: aContentsString in: path.
        ^path
    ]

    cliIn: aWorkDir source: aSource storeRoot: aStoreRoot target: aTarget runner: aRunner [
        ^CLI in: aWorkDir
            source: aSource
            store: (ContentStore on: aStoreRoot)
            target: aTarget
            runner: aRunner
    ]

    lockContentsIn: aWorkDir [
        ^(File name: aWorkDir, '/parley.lock') contents
    ]

    version: aString [
        ^Version fromString: aString
    ]

    emptySet [
        ^InstalledSet tuples: Dictionary new
    ]

    primeDiamondStore: aStoreRoot [
        | store |
        store := ContentStore on: aStoreRoot.
        store store: InstallFixtures archiveBytesA.
        store store: InstallFixtures archiveBytesB.
        store store: InstallFixtures archiveBytesC24.
        ^store
    ]

    "---- S1/S2: the runner's real exit codes ----"

    testS1_theRunnerAnswersTheChildsExitCode [
        self assert: (ProcessRunner new run: 'exit 7') = 7
    ]

    testS2_theRunnerAnswersSuccessAsZero [
        self assert: (ProcessRunner new run: 'true') = 0
    ]

    "---- S3: the child command line is a pure pinned value ----"

    testS3_theChildCommandLineIsAPurePinnedValue [
        | runner scope |
        runner := RecordingRunner new.
        scope := ExecutionScope on: self emptySet
            target: 'tmp/parley-s3-target'
            runner: runner.
        self assert: (scope childCommandFor: 'tmp/s.st')
            = 'gst -i -I tmp/parley-s3-target/parley.im --no-user-files tmp/s.st'.
        self assert: runner commands = #()
    ]

    "---- S4: register executes the plan for real ----"

    testS4_registerExecutesThePlanForReal [
        | runner starBytes storeRoot store starHash target tuples scope landed |
        runner := ProcessRunner new.
        starBytes := ExecFixtures probeStarBytesLabeled: 's4'.
        storeRoot := self freshStoreRoot: 's4-store'.
        store := ContentStore on: storeRoot.
        starHash := store store: starBytes.
        target := self freshDir: 's4-target'.
        tuples := Dictionary new.
        tuples at: 'parley-probe' put: (Array
            with: (self version: '1.0.0')
            with: starHash
            with: (store pathForHash: starHash)).
        scope := ExecutionScope on: (InstalledSet tuples: tuples)
            target: target
            runner: runner.
        scope register.
        landed := (File name: target, '/parley-probe.star') contents.
        self assert: landed = starBytes.
        self assert: landed
            = (File name: (store pathForHash: starHash)) contents
    ]

    "---- S5: register is fail-stop with a real rejection ----"

    testS5_registerIsFailStopWithARealRejection [
        | runner starBytes storeRoot store garbageHash starHash target tuples scope error expected |
        runner := ProcessRunner new.
        starBytes := ExecFixtures probeStarBytesLabeled: 's5'.
        storeRoot := self freshStoreRoot: 's5-store'.
        store := ContentStore on: storeRoot.
        garbageHash := store store: InstallFixtures archiveBytesA.
        starHash := store store: starBytes.
        target := self freshDir: 's5-target'.
        tuples := Dictionary new.
        tuples at: 'aaa-garbage' put: (Array
            with: (self version: '1.0.0')
            with: garbageHash
            with: (store pathForHash: garbageHash)).
        tuples at: 'parley-probe' put: (Array
            with: (self version: '1.0.0')
            with: starHash
            with: (store pathForHash: starHash)).
        scope := ExecutionScope on: (InstalledSet tuples: tuples)
            target: target
            runner: runner.
        error := nil.
        [scope register.
         self assert: false description: 'expected an ExecutionError']
            on: ExecutionError
            do: [:e | error := e].
        expected := 'gst-package --target-directory ', target, ' ',
            target, '/.parley-staging/aaa-garbage.star'.
        self assert: error command = expected.
        self assert: error exitCode = 1.
        self assert: error messageText
            = (ExecFixtures executionErrorMessageFor: expected code: 1).
        self deny: (File name: target, '/parley-probe.star') exists.
        self deny: (File name: target, '/.parley-staging/parley-probe.star')
            exists
    ]

    "---- S6: run: really launches the curated child ----"

    testS6_runReallyLaunchesTheCuratedChild [
        | runner dir target scope code |
        runner := ProcessRunner new.
        dir := self freshDir: 's6'.
        target := self freshDir: 's6-target'.
        SourceFixtures
            write: (ExecFixtures sentinelScriptContentsFor: dir, '/sentinel.txt')
            toFile: 'witness.st' in: dir.
        scope := ExecutionScope on: self emptySet
            target: target
            runner: runner.
        code := scope run: dir, '/witness.st'.
        self assert: code = 0.
        self assert: (File name: dir, '/sentinel.txt') contents
            = 'curated child ran'
    ]

    "---- S7: a package lands in an image (the sprint's exit) ----"

    testS7_aPackageLandsInAnImage [
        | runner starBytes digest entries work storeRoot target cli rInstall proofPath rExec |
        runner := ProcessRunner new.
        starBytes := ExecFixtures probeStarBytesLabeled: 's7'.
        digest := Sha256 hexDigestOf: starBytes.
        entries := self freshDir: 's7-entries'.
        ExecFixtures populateProbeSourceIn: entries
            bytes: starBytes digest: digest.
        work := self workDir: 's7-work'
            package: ExecFixtures probeRootContents.
        storeRoot := self freshStoreRoot: 's7-store'.
        target := self freshDir: 's7-target'.
        cli := self cliIn: work
            source: (DirectorySource on: entries)
            storeRoot: storeRoot
            target: target
            runner: runner.
        rInstall := cli run: #('install').
        self assert: rInstall exitCode = 0.
        self assert: rInstall lines = #('parley-probe 1.0.0').
        self assert: (self lockContentsIn: work)
            = (ExecFixtures probeLockStringWithDigest: digest).
        self assert: ((ContentStore on: storeRoot) containsHash: digest).
        self assert: (File name: target, '/parley-probe.star') contents
            = starBytes.
        proofPath := work, '/proof.txt'.
        SourceFixtures
            write: (ExecFixtures proofScriptContentsFor: proofPath)
            toFile: 'proof-script.st' in: work.
        rExec := cli run: (Array with: 'exec' with: work, '/proof-script.st').
        self assert: rExec exitCode = 0.
        self assert: rExec lines = #().
        self assert: (File name: proofPath) contents = 'present'
    ]

    "---- S8/S9: ManifestFile ----"

    testS8_manifestFileLoadsPackageSt [
        | dir manifest dep |
        dir := self freshDir: 's8'.
        ExecFixtures writePackage: ExecFixtures minimalManifestContents
            in: dir.
        manifest := ManifestFile load: dir, '/Package.st'.
        self assert: manifest name = 'kernel-json'.
        self assert: manifest version = (self version: '0.3.1').
        self assert: manifest dependencies size = 1.
        dep := manifest dependencies at: 1.
        self assert: dep name = 'kernel-streams'.
        self assert: dep constraint
            = (VersionConstraint fromString: '>=1.0 <2.0')
    ]

    testS9_aDefineLessFileIsAnError [
        | dir path error |
        dir := self freshDir: 's9'.
        path := dir, '/Package.st'.
        ExecFixtures writePackage: ExecFixtures definelessContents
            in: dir.
        error := nil.
        [ManifestFile load: path.
         self assert: false description: 'expected a ManifestError']
            on: ManifestError
            do: [:e | error := e].
        self assert: error problems size = 1.
        self assert: (error problems at: 1)
            = (ExecFixtures defineLessProblemFor: path)
    ]

    "---- S10: init writes the template once ----"

    testS10_initWritesTheTemplateOnce [
        | work cli first second |
        work := self freshDir: 's10-work'.
        cli := self cliIn: work
            source: nil
            storeRoot: 'tmp/parley-s10-store'
            target: 'tmp/parley-s10-target'
            runner: RecordingRunner new.
        first := cli run: #('init').
        self assert: first exitCode = 0.
        self assert: first lines = ExecFixtures initSuccessLines.
        self assert: (File name: work, '/Package.st') contents
            = ExecFixtures initTemplateContents.
        second := cli run: #('init').
        self assert: second exitCode = 1.
        self assert: second lines = ExecFixtures initRefusalLines.
        self assert: (File name: work, '/Package.st') contents
            = ExecFixtures initTemplateContents
    ]

    "---- S11: resolve writes the byte-stable lock ----"

    testS11_resolveWritesTheByteStableLock [
        | work entries cli r1 r2 |
        work := self workDir: 's11-work'
            package: ExecFixtures diamondRootContents.
        entries := self diamondEntriesDir: 's11-entries'.
        cli := self cliIn: work
            source: (DirectorySource on: entries)
            storeRoot: 'tmp/parley-s11-store'
            target: 'tmp/parley-s11-target'
            runner: RecordingRunner new.
        r1 := cli run: #('resolve').
        self assert: r1 exitCode = 0.
        self assert: (self lockContentsIn: work)
            = ExecFixtures diamondLockString.
        r2 := cli run: #('resolve').
        self assert: r2 exitCode = 0.
        self assert: (self lockContentsIn: work)
            = ExecFixtures diamondLockString
    ]

    "---- S12: resolve narrates a conflict ----"

    testS12_resolveNarratesAConflict [
        | work entries manifest report cli result |
        work := self workDir: 's12-work'
            package: (ExecFixtures cOnlyRootContents: '^9.0').
        entries := self diamondEntriesDir: 's12-entries'.
        manifest := Parley define: [:pkg |
            pkg name: 'my-app'; version: '1.0.0'; fileIns: #('App.st');
                dependency: 'c' constraint: '^9.0'].
        report := ResolverFixtures resolve: manifest
            against: (DirectorySource on: entries) snapshot.
        self deny: report isResolution.
        cli := self cliIn: work
            source: (DirectorySource on: entries)
            storeRoot: 'tmp/parley-s12-store'
            target: 'tmp/parley-s12-target'
            runner: RecordingRunner new.
        result := cli run: #('resolve').
        self assert: result exitCode = 1.
        self assert: result lines
            = (ExecFixtures linesOf: report printString).
        self deny: (File name: work, '/parley.lock') exists
    ]

    "---- S13: install runs the full pipeline ----"

    testS13_installRunsTheFullPipeline [
        | work entries storeRoot target runner cli result store expected |
        work := self workDir: 's13-work'
            package: ExecFixtures diamondRootContents.
        entries := self diamondEntriesDir: 's13-entries'.
        storeRoot := self freshStoreRoot: 's13-store'.
        target := 'tmp/parley-s13-target'.
        runner := RecordingRunner new.
        cli := self cliIn: work
            source: (DirectorySource on: entries)
            storeRoot: storeRoot
            target: target
            runner: runner.
        result := cli run: #('install').
        self assert: result exitCode = 0.
        self assert: (self lockContentsIn: work)
            = ExecFixtures diamondLockString.
        store := ContentStore on: storeRoot.
        self assert: (store containsHash: InstallFixtures digestA).
        self assert: (store containsHash: InstallFixtures digestB).
        self assert: (store containsHash: InstallFixtures digestC24).
        self assert: (InstallFixtures starFileCountIn: storeRoot) = 3.
        expected := OrderedCollection new.
        #('a' 'b' 'c')
            with: (Array
                with: InstallFixtures digestA
                with: InstallFixtures digestB
                with: InstallFixtures digestC24)
            do: [:name :digest |
                expected add: 'install -D -m 644 ', storeRoot, '/',
                    digest, '.star ', target,
                    '/.parley-staging/', name, '.star'.
                expected add: 'gst-package --target-directory ',
                    target, ' ', target,
                    '/.parley-staging/', name, '.star'].
        self assert: runner commands = expected asArray
    ]

    "---- S14: the valid-pin fast path ----"

    testS14_theValidPinFastPathTouchesNeitherSnapshotNorFetch [
        | work storeRoot cli result |
        work := self workDir: 's14-work'
            package: ExecFixtures diamondRootContents.
        ExecFixtures writeLock: ExecFixtures diamondLockString in: work.
        storeRoot := self freshStoreRoot: 's14-store'.
        self primeDiamondStore: storeRoot.
        cli := self cliIn: work
            source: SnapshotAndFetchTrapSource new
            storeRoot: storeRoot
            target: 'tmp/parley-s14-target'
            runner: RecordingRunner new.
        result := cli run: #('install').
        self assert: result exitCode = 0
    ]

    "---- S15: a stale pin re-resolves ----"

    testS15_aStalePinReResolves [
        | work entries storeRoot cli result |
        work := self workDir: 's15-work'
            package: (ExecFixtures cOnlyRootContents: '^1.0').
        ExecFixtures writeLock: ExecFixtures diamondLockString in: work.
        entries := self diamondEntriesDir: 's15-entries'.
        ExecFixtures addArchiveC15To: entries.
        storeRoot := self freshStoreRoot: 's15-store'.
        cli := self cliIn: work
            source: (DirectorySource on: entries)
            storeRoot: storeRoot
            target: 'tmp/parley-s15-target'
            runner: RecordingRunner new.
        result := cli run: #('install').
        self assert: result exitCode = 0.
        self assert: (self lockContentsIn: work)
            = ExecFixtures lockPinningC15String
    ]

    "---- S16: cache corruption is fail-stop ----"

    testS16_cacheCorruptionIsFailStop [
        | work storeRoot store runner cli result |
        work := self workDir: 's16-work'
            package: ExecFixtures diamondRootContents.
        ExecFixtures writeLock: ExecFixtures diamondLockString in: work.
        storeRoot := self freshStoreRoot: 's16-store'.
        store := self primeDiamondStore: storeRoot.
        InstallFixtures tamperStoredHash: InstallFixtures digestA
            in: storeRoot.
        runner := RecordingRunner new.
        cli := self cliIn: work
            source: SnapshotAndFetchTrapSource new
            storeRoot: storeRoot
            target: 'tmp/parley-s16-target'
            runner: runner.
        result := cli run: #('install').
        self assert: result exitCode = 1.
        self assert: result lines = (Array with:
            (ExecFixtures corruptionLineFor: InstallFixtures digestA)).
        "not repaired, not deleted, not re-fetched (trap source);
         registration never started"
        self assert: (store containsHash: InstallFixtures digestA).
        self deny: (store verifyHash: InstallFixtures digestA).
        self assert: runner commands = #()
    ]

    "---- S17: update moves the pin that install would keep ----"

    testS17_updateMovesThePinThatInstallWouldKeep [
        | work entries storeRoot cli rInstall rUpdate |
        work := self workDir: 's17-work'
            package: (ExecFixtures cOnlyRootContents: '>=1.0 <3.0').
        ExecFixtures writeLock: ExecFixtures lockPinningC15String in: work.
        entries := self diamondEntriesDir: 's17-entries'.
        ExecFixtures addArchiveC15To: entries.
        storeRoot := self freshStoreRoot: 's17-store'.
        cli := self cliIn: work
            source: (DirectorySource on: entries)
            storeRoot: storeRoot
            target: 'tmp/parley-s17-target'
            runner: RecordingRunner new.
        rInstall := cli run: #('install').
        self assert: rInstall exitCode = 0.
        self assert: (self lockContentsIn: work)
            = ExecFixtures lockPinningC15String.
        rUpdate := cli run: #('update').
        self assert: rUpdate exitCode = 0.
        self assert: (self lockContentsIn: work)
            = ExecFixtures lockPinningC24String
    ]

    "---- S18: exec propagates the child's exit code ----"

    testS18_execPropagatesTheChildsExitCode [
        | runner cli result |
        runner := RecordingRunner answering: 7.
        cli := self cliIn: 'tmp/parley-s18-work'
            source: nil
            storeRoot: 'tmp/parley-s18-store'
            target: 'tmp/parley-s18-target'
            runner: runner.
        result := cli run: #('exec' 'tmp/parley-s18-script.st').
        self assert: result exitCode = 7.
        self assert: result lines = #().
        self assert: runner commands = (Array with:
            'gst -i -I tmp/parley-s18-target/parley.im --no-user-files tmp/parley-s18-script.st')
    ]

    "---- S19: unknown input answers usage ----"

    testS19_unknownInputAnswersUsage [
        | cli noSource |
        cli := self cliIn: 'tmp/parley-s19-work'
            source: SnapshotAndFetchTrapSource new
            storeRoot: 'tmp/parley-s19-store'
            target: 'tmp/parley-s19-target'
            runner: RecordingRunner new.
        #(#('conjure') #('exec')) do: [:argv |
            | result |
            result := cli run: argv.
            self assert: result exitCode = 2.
            self assert: result lines = ExecFixtures usageLines].
        noSource := self cliIn: 'tmp/parley-s19-work'
            source: nil
            storeRoot: 'tmp/parley-s19-store'
            target: 'tmp/parley-s19-target'
            runner: RecordingRunner new.
        #('resolve' 'install' 'update') do: [:verb |
            | result |
            result := noSource run: (Array with: verb).
            self assert: result exitCode = 2.
            self assert: result lines = ExecFixtures usageLines]
    ]
]

Namespace current: Smalltalk.
