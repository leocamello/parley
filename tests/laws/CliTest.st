"Parley Sprint 6 — CLI verb laws (issue #8 S10-S19; Doc E §4).

 The CLI is an orchestration answering a value: run: dispatches the
 argv and answers an immutable CliResult (lines - an Array of Strings
 - and exitCode). It never prints, never terminates the image, and
 never touches a process except through the scope's runner — every
 test here uses recording/trap doubles; no real process is ever
 spawned by this suite.

 Pinned decisions exercised here (wordings in ExecFixtures, posted on
 issue #8): the two usage lines with exit 2 (empty argv, unknown verb,
 exec without script, source-requiring verb with a nil source); init's
 Doc B §2 template bytes, success line and refusal line; resolve/
 install/update reporting one '<name> <version>' line per pin in
 sorted name order on exit 0; conflict narration lines verbatim with
 exit 1 and no lock written; the corruption fail-stop line naming the
 first corrupt hash in sorted package order; exec answering the
 child's code with no lines of the CLI's own. The CLI reads Package.st
 and parley.lock in its working directory."

Namespace current: Parley.

TestCase subclass: CliTest [
    | fixtureDirs |

    <comment: 'Verb laws for CLI and CliResult: usage shapes, init,
resolve (lock oracle + conflict narration), install (full pipeline,
fast path, staleness, corruption fail-stop), update pin movement, and
exec propagation — all over doubles, spawning nothing.'>

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

    primeDiamondStore: aStoreRoot [
        | store |
        store := ContentStore on: aStoreRoot.
        store store: InstallFixtures archiveBytesA.
        store store: InstallFixtures archiveBytesB.
        store store: InstallFixtures archiveBytesC24.
        ^store
    ]

    stagedPlanFor: aTargetDir storeRoot: aStoreRoot [
        "The expected recorded registration plan for the resolved
         diamond: two lines per package, pair-adjacent, staging first,
         in sorted package-name order (Doc D §4)."
        | expected |
        expected := OrderedCollection new.
        #('a' 'b' 'c')
            with: (Array
                with: InstallFixtures digestA
                with: InstallFixtures digestB
                with: InstallFixtures digestC24)
            do: [:name :digest |
                expected add: 'install -D -m 644 ', aStoreRoot, '/',
                    digest, '.star ', aTargetDir,
                    '/.parley-staging/', name, '.star'.
                expected add: 'gst-package --target-directory ',
                    aTargetDir, ' ', aTargetDir,
                    '/.parley-staging/', name, '.star'].
        ^expected asArray
    ]

    "---- S19 and the argv grammar: usage, exit 2 ----"

    testEmptyArgvAnswersUsage [
        | cli result |
        cli := self cliIn: 'tmp/parley-cli-usage-work'
            source: nil
            storeRoot: 'tmp/parley-cli-usage-store'
            target: 'tmp/parley-cli-usage-target'
            runner: RecordingRunner new.
        result := cli run: #().
        self assert: result exitCode = 2.
        self assert: result lines = ExecFixtures usageLines
    ]

    testAnUnknownVerbAnswersUsage [
        | cli result |
        cli := self cliIn: 'tmp/parley-cli-usage-work'
            source: nil
            storeRoot: 'tmp/parley-cli-usage-store'
            target: 'tmp/parley-cli-usage-target'
            runner: RecordingRunner new.
        result := cli run: #('conjure').
        self assert: result exitCode = 2.
        self assert: result lines = ExecFixtures usageLines
    ]

    testExecWithoutAScriptAnswersUsage [
        | cli runner result |
        runner := RecordingRunner new.
        cli := self cliIn: 'tmp/parley-cli-usage-work'
            source: nil
            storeRoot: 'tmp/parley-cli-usage-store'
            target: 'tmp/parley-cli-usage-target'
            runner: runner.
        result := cli run: #('exec').
        self assert: result exitCode = 2.
        self assert: result lines = ExecFixtures usageLines.
        self assert: runner commands = #()
    ]

    testSourceRequiringVerbsWithoutASourceAnswerUsage [
        | cli |
        cli := self cliIn: 'tmp/parley-cli-usage-work'
            source: nil
            storeRoot: 'tmp/parley-cli-usage-store'
            target: 'tmp/parley-cli-usage-target'
            runner: RecordingRunner new.
        #('resolve' 'install' 'update') do: [:verb |
            | result |
            result := cli run: (Array with: verb).
            self assert: result exitCode = 2.
            self assert: result lines = ExecFixtures usageLines]
    ]

    "---- S10: init ----"

    testInitWritesTheDocBTemplate [
        | work cli result |
        work := self freshDir: 'cli-init'.
        cli := self cliIn: work
            source: nil
            storeRoot: 'tmp/parley-cli-init-store'
            target: 'tmp/parley-cli-init-target'
            runner: RecordingRunner new.
        result := cli run: #('init').
        self assert: result exitCode = 0.
        self assert: result lines = ExecFixtures initSuccessLines.
        self assert: (File name: work, '/Package.st') contents
            = ExecFixtures initTemplateContents
    ]

    testInitRefusesToOverwriteAndLeavesTheFileUnchanged [
        | work cli result |
        work := self freshDir: 'cli-init-refuse'.
        ExecFixtures writePackage: 'custom author bytes' in: work.
        cli := self cliIn: work
            source: nil
            storeRoot: 'tmp/parley-cli-init-refuse-store'
            target: 'tmp/parley-cli-init-refuse-target'
            runner: RecordingRunner new.
        result := cli run: #('init').
        self assert: result exitCode = 1.
        self assert: result lines = ExecFixtures initRefusalLines.
        self assert: (File name: work, '/Package.st') contents
            = 'custom author bytes'
    ]

    "---- S11/S12: resolve ----"

    testResolveWritesTheByteStableLockTwice [
        | work entries cli r1 r2 |
        work := self workDir: 'cli-resolve'
            package: ExecFixtures diamondRootContents.
        entries := self diamondEntriesDir: 'cli-resolve-entries'.
        cli := self cliIn: work
            source: (DirectorySource on: entries)
            storeRoot: 'tmp/parley-cli-resolve-store'
            target: 'tmp/parley-cli-resolve-target'
            runner: RecordingRunner new.
        r1 := cli run: #('resolve').
        self assert: r1 exitCode = 0.
        self assert: r1 lines = #('a 1.0.0' 'b 1.0.0' 'c 2.4.0').
        self assert: (self lockContentsIn: work)
            = ExecFixtures diamondLockString.
        r2 := cli run: #('resolve').
        self assert: r2 exitCode = 0.
        self assert: r2 lines = #('a 1.0.0' 'b 1.0.0' 'c 2.4.0').
        self assert: (self lockContentsIn: work)
            = ExecFixtures diamondLockString
    ]

    testResolveNarratesAConflictAndWritesNoLock [
        | work entries manifest report cli result |
        work := self workDir: 'cli-conflict'
            package: (ExecFixtures cOnlyRootContents: '^9.0').
        entries := self diamondEntriesDir: 'cli-conflict-entries'.
        manifest := Parley define: [:pkg |
            pkg name: 'my-app'; version: '1.0.0'; fileIns: #('App.st');
                dependency: 'c' constraint: '^9.0'].
        report := ResolverFixtures resolve: manifest
            against: (DirectorySource on: entries) snapshot.
        self deny: report isResolution.
        cli := self cliIn: work
            source: (DirectorySource on: entries)
            storeRoot: 'tmp/parley-cli-conflict-store'
            target: 'tmp/parley-cli-conflict-target'
            runner: RecordingRunner new.
        result := cli run: #('resolve').
        self assert: result exitCode = 1.
        self assert: result lines
            = (ExecFixtures linesOf: report printString).
        self deny: (File name: work, '/parley.lock') exists
    ]

    "---- S13: install runs the full pipeline ----"

    testInstallRunsResolveFetchStoreAndRegister [
        | work entries storeRoot target runner cli result store |
        work := self workDir: 'cli-install'
            package: ExecFixtures diamondRootContents.
        entries := self diamondEntriesDir: 'cli-install-entries'.
        storeRoot := self freshStoreRoot: 'cli-install-store'.
        target := 'tmp/parley-cli-install-target'.
        runner := RecordingRunner new.
        cli := self cliIn: work
            source: (DirectorySource on: entries)
            storeRoot: storeRoot
            target: target
            runner: runner.
        result := cli run: #('install').
        self assert: result exitCode = 0.
        self assert: result lines = #('a 1.0.0' 'b 1.0.0' 'c 2.4.0').
        self assert: (self lockContentsIn: work)
            = ExecFixtures diamondLockString.
        store := ContentStore on: storeRoot.
        self assert: (store containsHash: InstallFixtures digestA).
        self assert: (store containsHash: InstallFixtures digestB).
        self assert: (store containsHash: InstallFixtures digestC24).
        self assert: (InstallFixtures starFileCountIn: storeRoot) = 3.
        self assert: runner commands
            = (self stagedPlanFor: target storeRoot: storeRoot)
    ]

    "---- S14: the valid-pin fast path ----"

    testInstallFastPathConsumesNeitherSnapshotNorFetch [
        | work storeRoot runner cli result |
        work := self workDir: 'cli-fastpath'
            package: ExecFixtures diamondRootContents.
        ExecFixtures writeLock: ExecFixtures diamondLockString in: work.
        storeRoot := self freshStoreRoot: 'cli-fastpath-store'.
        self primeDiamondStore: storeRoot.
        runner := RecordingRunner new.
        cli := self cliIn: work
            source: SnapshotAndFetchTrapSource new
            storeRoot: storeRoot
            target: 'tmp/parley-cli-fastpath-target'
            runner: runner.
        result := cli run: #('install').
        self assert: result exitCode = 0.
        self assert: result lines = #('a 1.0.0' 'b 1.0.0' 'c 2.4.0').
        self assert: (self lockContentsIn: work)
            = ExecFixtures diamondLockString.
        self assert: runner commands
            = (self stagedPlanFor: 'tmp/parley-cli-fastpath-target'
                storeRoot: storeRoot)
    ]

    "---- S15: a stale pin re-resolves ----"

    testInstallReResolvesAStalePin [
        | work entries storeRoot cli result |
        work := self workDir: 'cli-stale'
            package: (ExecFixtures cOnlyRootContents: '^1.0').
        ExecFixtures writeLock: ExecFixtures diamondLockString in: work.
        entries := self diamondEntriesDir: 'cli-stale-entries'.
        ExecFixtures addArchiveC15To: entries.
        storeRoot := self freshStoreRoot: 'cli-stale-store'.
        cli := self cliIn: work
            source: (DirectorySource on: entries)
            storeRoot: storeRoot
            target: 'tmp/parley-cli-stale-target'
            runner: RecordingRunner new.
        result := cli run: #('install').
        self assert: result exitCode = 0.
        self assert: result lines = #('c 1.5.0').
        self assert: (self lockContentsIn: work)
            = ExecFixtures lockPinningC15String
    ]

    "---- S16: cache corruption is fail-stop ----"

    testInstallFailStopsOnStoreCorruption [
        | work storeRoot store runner cli result |
        work := self workDir: 'cli-corrupt'
            package: ExecFixtures diamondRootContents.
        ExecFixtures writeLock: ExecFixtures diamondLockString in: work.
        storeRoot := self freshStoreRoot: 'cli-corrupt-store'.
        store := self primeDiamondStore: storeRoot.
        InstallFixtures tamperStoredHash: InstallFixtures digestA
            in: storeRoot.
        runner := RecordingRunner new.
        cli := self cliIn: work
            source: SnapshotAndFetchTrapSource new
            storeRoot: storeRoot
            target: 'tmp/parley-cli-corrupt-target'
            runner: runner.
        result := cli run: #('install').
        self assert: result exitCode = 1.
        self assert: result lines = (Array with:
            (ExecFixtures corruptionLineFor: InstallFixtures digestA)).
        "detection only: not repaired, not deleted, not re-fetched
         (the trap source proves no fetch), register never ran"
        self assert: (store containsHash: InstallFixtures digestA).
        self deny: (store verifyHash: InstallFixtures digestA).
        self assert: runner commands = #().
        self assert: (self lockContentsIn: work)
            = ExecFixtures diamondLockString
    ]

    "---- S17: update moves the pin install keeps ----"

    testUpdateMovesThePinThatInstallKeeps [
        | work entries storeRoot cli rInstall rUpdate |
        work := self workDir: 'cli-update'
            package: (ExecFixtures cOnlyRootContents: '>=1.0 <3.0').
        ExecFixtures writeLock: ExecFixtures lockPinningC15String in: work.
        entries := self diamondEntriesDir: 'cli-update-entries'.
        ExecFixtures addArchiveC15To: entries.
        storeRoot := self freshStoreRoot: 'cli-update-store'.
        cli := self cliIn: work
            source: (DirectorySource on: entries)
            storeRoot: storeRoot
            target: 'tmp/parley-cli-update-target'
            runner: RecordingRunner new.
        rInstall := cli run: #('install').
        self assert: rInstall exitCode = 0.
        self assert: rInstall lines = #('c 1.5.0').
        self assert: (self lockContentsIn: work)
            = ExecFixtures lockPinningC15String.
        rUpdate := cli run: #('update').
        self assert: rUpdate exitCode = 0.
        self assert: rUpdate lines = #('c 2.4.0').
        self assert: (self lockContentsIn: work)
            = ExecFixtures lockPinningC24String
    ]

    "---- S18: exec propagates the child's exit code ----"

    testExecPropagatesTheChildsExitCodeThroughTheScope [
        | runner cli result |
        runner := RecordingRunner answering: 7.
        cli := self cliIn: 'tmp/parley-cli-exec-work'
            source: nil
            storeRoot: 'tmp/parley-cli-exec-store'
            target: 'tmp/parley-cli-exec-target'
            runner: runner.
        result := cli run: #('exec' 'tmp/parley-cli-exec-script.st').
        self assert: result exitCode = 7.
        self assert: result lines = #().
        self assert: runner commands = (Array with:
            'gst -i -I tmp/parley-cli-exec-target/parley.im --no-user-files tmp/parley-cli-exec-script.st')
    ]
]

Namespace current: Smalltalk.
