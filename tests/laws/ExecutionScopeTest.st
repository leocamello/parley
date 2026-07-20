"Parley Sprint 6 — ExecutionScope laws (issue #8 S3-S6; Doc E §2).

 The scope is the single home of invocation logic: registrationCommands
 is exactly the installed set's Doc D §4 staged plan (a pure value);
 register executes the plan through the runner and is fail-stop — the
 first nonzero exit signals one ExecutionError naming the exact command
 line and code, later commands never run; childCommandFor: is the
 pinned pure composition; run: sends it through the runner and answers
 the child's exit code as a value.

 Real processes appear only where the law under test IS execution
 (register and run: with a real ProcessRunner); every such test touches
 the missing runner class first, so the red phase spawns nothing. All
 fixture paths live under tmp/ and are removed recursively in tearDown
 (targets grow .parley-staging/ and parley.im)."

Namespace current: Parley.

TestCase subclass: ExecutionScopeTest [
    | fixtureDirs |

    <comment: 'Laws for ExecutionScope: the pinned child composition,
plan delegation, real staged registration with real fail-stop, and the
real curated child run.'>

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

    version: aString [
        ^Version fromString: aString
    ]

    emptySet [
        ^InstalledSet tuples: Dictionary new
    ]

    setWith: aName hash: aHash store: aStore [
        | tuples |
        tuples := Dictionary new.
        tuples at: aName put: (Array
            with: (self version: '1.0.0')
            with: aHash
            with: (aStore pathForHash: aHash)).
        ^InstalledSet tuples: tuples
    ]

    "---- S3: the pinned pure composition ----"

    testChildCommandForIsThePinnedComposition [
        | runner scope |
        runner := RecordingRunner new.
        scope := ExecutionScope on: self emptySet
            target: 'tmp/parley-scopecmd-target'
            runner: runner.
        self assert: (scope childCommandFor: 'tmp/s.st')
            = 'gst -i -I tmp/parley-scopecmd-target/parley.im --no-user-files tmp/s.st'.
        self assert: runner commands = #()
    ]

    testChildCommandForComposesFromBothPaths [
        | scope |
        scope := ExecutionScope on: self emptySet
            target: 'tmp/parley-other-target'
            runner: RecordingRunner new.
        self assert: (scope childCommandFor: 'tmp/parley-w/script.st')
            = 'gst -i -I tmp/parley-other-target/parley.im --no-user-files tmp/parley-w/script.st'
    ]

    "---- the plan is the installed set's, untouched ----"

    testRegistrationCommandsAreExactlyTheInstalledSetsPlan [
        | tuples set runner scope |
        tuples := Dictionary new.
        tuples at: 'beta' put: (Array
            with: (self version: '1.0.0')
            with: 'bb'
            with: 'tmp/parley-plan-store/bb.star').
        tuples at: 'alpha' put: (Array
            with: (self version: '2.0.0')
            with: 'aa'
            with: 'tmp/parley-plan-store/aa.star').
        set := InstalledSet tuples: tuples.
        runner := RecordingRunner new.
        scope := ExecutionScope on: set
            target: 'tmp/parley-plan-target'
            runner: runner.
        self assert: scope registrationCommands
            = (set registrationCommandsFor: 'tmp/parley-plan-target').
        self assert: scope registrationCommands size = 4.
        self assert: runner commands = #()
    ]

    "---- S4: register executes the staged plan for real ----"

    testRegisterExecutesTheStagedPlanForRealAndIsReRunnable [
        | runner starBytes storeRoot store starHash target scope landed |
        runner := ProcessRunner new.
        starBytes := ExecFixtures probeStarBytesLabeled: 'scopereg'.
        storeRoot := self freshStoreRoot: 'scopereg-store'.
        store := ContentStore on: storeRoot.
        starHash := store store: starBytes.
        target := self freshDir: 'scopereg-target'.
        scope := ExecutionScope
            on: (self setWith: 'parley-probe' hash: starHash store: store)
            target: target
            runner: runner.
        scope register.
        landed := (File name: target, '/parley-probe.star') contents.
        self assert: landed = starBytes.
        self assert: landed
            = (File name: (store pathForHash: starHash)) contents.
        "re-runnable (Doc E §2.1): executing the same plan again is
         harmless and leaves the same bytes"
        scope register.
        self assert: (File name: target, '/parley-probe.star') contents
            = starBytes
    ]

    "---- S5: register is fail-stop on the first real rejection ----"

    testRegisterIsFailStopOnTheFirstRejectedRegistration [
        | runner starBytes storeRoot store garbageHash starHash target tuples scope error expected |
        runner := ProcessRunner new.
        starBytes := ExecFixtures probeStarBytesLabeled: 'scopefail'.
        storeRoot := self freshStoreRoot: 'scopefail-store'.
        store := ContentStore on: storeRoot.
        garbageHash := store store: InstallFixtures archiveBytesA.
        starHash := store store: starBytes.
        target := self freshDir: 'scopefail-target'.
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
        "the pair's staging line DID run - the failure landed on the
         gst-package registration line"
        self assert: (File name: target, '/.parley-staging/aaa-garbage.star')
            exists.
        "the garbage never registered, and later commands never ran"
        self deny: (File name: target, '/aaa-garbage.star') exists.
        self deny: (File name: target, '/.parley-staging/parley-probe.star')
            exists.
        self deny: (File name: target, '/parley-probe.star') exists
    ]

    "---- S6: run: really launches the curated child ----"

    testRunReallyLaunchesTheCuratedChild [
        | runner dir target scope code |
        runner := ProcessRunner new.
        dir := self freshDir: 'scoperun'.
        target := self freshDir: 'scoperun-target'.
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

    testRunAnswersANonzeroChildAsAValue [
        | runner dir target scope |
        runner := ProcessRunner new.
        dir := self freshDir: 'scopequit'.
        target := self freshDir: 'scopequit-target'.
        SourceFixtures
            write: (ExecFixtures quitScriptContentsFor: 5)
            toFile: 'quit.st' in: dir.
        scope := ExecutionScope on: self emptySet
            target: target
            runner: runner.
        self assert: (scope run: dir, '/quit.st') = 5
    ]

    testRunComposesThroughTheRunner [
        | runner scope |
        runner := RecordingRunner answering: 4.
        scope := ExecutionScope on: self emptySet
            target: 'tmp/parley-compose-target'
            runner: runner.
        self assert: (scope run: 'tmp/compose.st') = 4.
        self assert: runner commands = (Array with:
            'gst -i -I tmp/parley-compose-target/parley.im --no-user-files tmp/compose.st')
    ]
]

Namespace current: Smalltalk.
