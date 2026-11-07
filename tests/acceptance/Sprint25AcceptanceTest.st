"Parley Sprint 25 — locked pin identity, acceptance S1-S12 (issue #27).
 The six lock-writing routes share one guard. Each refusal checks its
 own diagnosis, both project files and the absence of install processes;
 another failure with exit 1 cannot satisfy the scenario. S1 exercises
 the shipped wrapper and the source actually loaded after repair.

 DECLARED RED PASSES: S10, S11 and S12. They preserve unchanged pin
 identity and the source-free install fast path. All other cases expose
 same-version provenance differences, rather than a version-only change
 the old guard already detects. No real archive is needed by a refused
 write: the guard must run before installation. Unlocked resolve controls
 prove the changed declarations are resolvable without fetching archives."

Namespace current: Parley.

TestCase subclass: Sprint25AcceptanceTest [
    | fixtureDirs |

    setUp [ fixtureDirs := OrderedCollection new ]

    tearDown [
        fixtureDirs isNil ifTrue: [^self].
        fixtureDirs do: [:each | PathFixtures removeTree: each].
        fixtureDirs := nil
    ]

    track: aPath [ fixtureDirs add: aPath. ^aPath ]

    freshDir: aLabel [
        ^self track: (SourceFixtures directoryNamed: aLabel)
    ]

    rootOn: aPath extra: anExtraClause [
        ^'Parley define: [:pkg |
    pkg name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''kernel-text'' path: ', aPath printString,
            anExtraClause, ' ]', SourceFixtures newline
    ]

    indexClauseFor: aName [
        ^'; dependency: ', aName printString, ' constraint: ''=1.0.0'''
    ]

    indexRootFor: aName version: aVersionString [
        ^'Parley define: [:pkg |
    pkg name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ', aName printString,
            ' constraint: ', ('=', aVersionString) printString,
            ' ]', SourceFixtures newline
    ]

    entryFor: aName version: aVersionString digest: aDigest url: aURL summary: aSummary [
        "An independent literal fixture; metadata reads do not require
         the archive bytes. Only resolve is used for unlocked controls."
        ^'#(#''parley-index'' 1 #name ', aName printString,
            ' #version ', aVersionString printString,
            ' #summary ', aSummary printString,
            ' #author '''' #license '''' #fileIns #(''X.st'') #dependencies #()',
            ' #archive #(', aURL printString, ' #sha256 ',
            aDigest printString, '))', SourceFixtures newline
    ]

    writeEntryFor: aName version: aVersionString digest: aDigest in: anIndex [
        SourceFixtures write: (self entryFor: aName version: aVersionString
            digest: aDigest url: 'fixture.star' summary: 'fixture')
            toFile: aName, '-', aVersionString, '.st' in: anIndex
    ]

    pathWorld: aLabel extra: anExtraClause [
        | first second firstPath secondPath work index |
        first := self track: (PathDepFixtures textSiblingNamed: aLabel, '-first'
            version: '1.2.0' answering: 'first source').
        second := self track: (PathDepFixtures textSiblingNamed: aLabel, '-second'
            version: '1.2.0' answering: 'second source').
        firstPath := PathDepFixtures declaredPathFor: aLabel, '-first'.
        secondPath := PathDepFixtures declaredPathFor: aLabel, '-second'.
        work := self track: (PathDepFixtures workDirNamed: aLabel, '-work'
            contents: (self rootOn: firstPath extra: anExtraClause)).
        index := self freshDir: aLabel, '-index'.
        ^Dictionary new
            at: #work put: work;
            at: #index put: index;
            at: #first put: first;
            at: #second put: second;
            at: #firstPath put: firstPath;
            at: #secondPath put: secondPath;
            yourself
    ]

    invoke: someArguments in: aWorld runner: aRunner [
        ^PathDepFixtures resultOf: someArguments
            in: (aWorld at: #work) runner: aRunner
    ]

    resolveIn: aWorld [
        | result |
        result := self invoke: (Array with: 'resolve' with: '--source'
            with: (aWorld at: #index)) in: aWorld runner: RecordingRunner new.
        self assert: result exitCode = 0 description: result lines printString.
        ^result
    ]

    movePathIn: aWorld extra: anExtraClause [
        ExecFixtures writePackage: (self rootOn: (aWorld at: #secondPath)
            extra: anExtraClause) in: (aWorld at: #work)
    ]

    captureProjectIn: aWorld [
        aWorld at: #manifestBefore put:
            (ManifestEditFixtures packageContentsIn: (aWorld at: #work)).
        aWorld at: #lockBefore put:
            (PathDepFixtures lockTextIn: (aWorld at: #work))
    ]

    assertProjectUnchangedIn: aWorld [
        self assert: (ManifestEditFixtures packageContentsIn: (aWorld at: #work))
            = (aWorld at: #manifestBefore)
            description: 'the locked command changed Package.st'.
        self assert: (PathDepFixtures lockTextIn: (aWorld at: #work))
            = (aWorld at: #lockBefore)
            description: 'the locked command changed parley.lock'
    ]

    pathDescription: aPath [ ^'#path ', aPath printString ]
    digestDescription: aDigest [ ^'#sha256 ', aDigest printString ]

    pathRefusalIn: aWorld [
        ^LockedPinFixtures provenanceRefusalFor: 'kernel-text'
            pinned: (self pathDescription: (aWorld at: #firstPath))
            would: (self pathDescription: (aWorld at: #secondPath))
    ]

    assertResult: aResult refuses: aLine in: aWorld runner: aRunner [
        self assert: aResult exitCode = 1 description: aResult lines printString.
        self assert: aResult lines = (Array with: aLine)
            description: aResult lines printString.
        self assertProjectUnchangedIn: aWorld.
        self assert: aRunner commands = #()
            description: 'a refused lock change reached install or registration'
    ]

    lockedArguments: aVerbArguments in: aWorld [
        ^aVerbArguments, (Array with: '--source' with: (aWorld at: #index)
            with: '--locked')
    ]

    assertUnlockedPathMovesIn: aWorld [
        | lock |
        self resolveIn: aWorld.
        lock := PathDepFixtures lockTextIn: (aWorld at: #work).
        self deny: lock = (aWorld at: #lockBefore).
        self assert: (CommandLineFixtures does: lock include:
            (PathDepFixtures pathTupleFor: 'kernel-text' version: '1.2.0'
                path: (aWorld at: #secondPath)))
            description: 'unlocked resolution did not select the declared new path'
    ]

    binary: someArguments in: aWorld [
        "Only fixture-owned simple paths reach this settled wrapper
         composer. Capture the real command boundary, not a CLI double."
        | output code |
        output := CommandLineFixtures absolutePathOf:
            (aWorld at: #work), '/binary-output.txt'.
        code := ProcessRunner new run:
            (CommandLineFixtures shellWrapperCommandIn: (aWorld at: #work)
                args: someArguments), ' > ', output, ' 2>&1'.
        ^Array with: code with: (File name: output) contents
    ]

    writeProbeIn: aWorld [
        SourceFixtures write: 'Transcript showCr: KernelText shout.
ObjectMemory quit: 0.
' toFile: 'probe.st' in: (aWorld at: #work)
    ]

    testS1_SameVersionPathChangeRefusesThroughTheShippedBinary [
        | world answer |
        world := self pathWorld: 's25-1' extra: ''.
        self writeProbeIn: world.
        answer := self binary: 'resolve' in: world.
        self assert: answer first = 0 description: answer last.
        answer := self binary: 'exec probe.st' in: world.
        self assert: answer first = 0 description: answer last.
        self assert: answer last = ('first source', SourceFixtures newline).
        self movePathIn: world extra: ''.
        self captureProjectIn: world.
        answer := self binary: 'resolve --locked' in: world.
        self assert: answer first = 1 description: answer last.
        self assert: answer last = ((self pathRefusalIn: world), SourceFixtures newline)
            description: answer last.
        self assertProjectUnchangedIn: world.
        answer := self binary: 'resolve' in: world.
        self assert: answer first = 0 description: answer last.
        self deny: (PathDepFixtures lockTextIn: (world at: #work))
            = (world at: #lockBefore).
        answer := self binary: 'exec probe.st' in: world.
        self assert: answer first = 0 description: answer last.
        self assert: answer last = ('second source', SourceFixtures newline)
    ]

    testS2_SameVersionArchiveDigestChangeRefuses [
        | world runner result expected |
        world := self pathWorld: 's25-2' extra: ''.
        ExecFixtures writePackage: (self indexRootFor: 'kernel-text' version: '1.2.0')
            in: (world at: #work).
        self writeEntryFor: 'kernel-text' version: '1.2.0'
            digest: LockedPinFixtures digestA in: (world at: #index).
        self resolveIn: world.
        self writeEntryFor: 'kernel-text' version: '1.2.0'
            digest: LockedPinFixtures digestB in: (world at: #index).
        self captureProjectIn: world.
        runner := RecordingRunner new.
        result := self invoke: (self lockedArguments: #('resolve') in: world)
            in: world runner: runner.
        expected := LockedPinFixtures provenanceRefusalFor: 'kernel-text'
            pinned: (self digestDescription: LockedPinFixtures digestA)
            would: (self digestDescription: LockedPinFixtures digestB).
        self assertResult: result refuses: expected in: world runner: runner.
        self resolveIn: world.
        self assert: (CommandLineFixtures does:
            (PathDepFixtures lockTextIn: (world at: #work))
            include: LockedPinFixtures digestB)
    ]

    testS3_SameVersionPathToArchiveRefuses [
        | world runner result expected |
        world := self pathWorld: 's25-3' extra: ''.
        self writeEntryFor: 'kernel-text' version: '1.2.0'
            digest: LockedPinFixtures digestA in: (world at: #index).
        self resolveIn: world.
        ExecFixtures writePackage: (self indexRootFor: 'kernel-text' version: '1.2.0')
            in: (world at: #work).
        self captureProjectIn: world.
        runner := RecordingRunner new.
        result := self invoke: (self lockedArguments: #('resolve') in: world)
            in: world runner: runner.
        expected := LockedPinFixtures provenanceRefusalFor: 'kernel-text'
            pinned: (self pathDescription: (world at: #firstPath))
            would: (self digestDescription: LockedPinFixtures digestA).
        self assertResult: result refuses: expected in: world runner: runner.
        self resolveIn: world.
        self assert: (CommandLineFixtures does:
            (PathDepFixtures lockTextIn: (world at: #work))
            include: LockedPinFixtures digestA)
    ]

    testS4_SameVersionArchiveToPathRefuses [
        | world runner result expected |
        world := self pathWorld: 's25-4' extra: ''.
        self writeEntryFor: 'kernel-text' version: '1.2.0'
            digest: LockedPinFixtures digestA in: (world at: #index).
        ExecFixtures writePackage: (self indexRootFor: 'kernel-text' version: '1.2.0')
            in: (world at: #work).
        self resolveIn: world.
        self movePathIn: world extra: ''.
        self captureProjectIn: world.
        runner := RecordingRunner new.
        result := self invoke: (self lockedArguments: #('resolve') in: world)
            in: world runner: runner.
        expected := LockedPinFixtures provenanceRefusalFor: 'kernel-text'
            pinned: (self digestDescription: LockedPinFixtures digestA)
            would: (self pathDescription: (world at: #secondPath)).
        self assertResult: result refuses: expected in: world runner: runner.
        self assertUnlockedPathMovesIn: world
    ]

    testS5_FullUpdateRefusesSameVersionPathChangeBeforeInstallation [
        | world runner result |
        world := self pathWorld: 's25-5' extra: ''.
        self resolveIn: world.
        self movePathIn: world extra: ''.
        self captureProjectIn: world.
        runner := RecordingRunner new.
        result := self invoke: (self lockedArguments: #('update') in: world)
            in: world runner: runner.
        self assertResult: result refuses: (self pathRefusalIn: world)
            in: world runner: runner.
        self assertUnlockedPathMovesIn: world
    ]

    testS6_SelectiveUpdateRefusesAnotherPinsSameVersionPathChange [
        | world runner result extra |
        extra := self indexClauseFor: 'kernel-z'.
        world := self pathWorld: 's25-6' extra: extra.
        self writeEntryFor: 'kernel-z' version: '1.0.0'
            digest: LockedPinFixtures digestA in: (world at: #index).
        self resolveIn: world.
        self movePathIn: world extra: extra.
        self captureProjectIn: world.
        runner := RecordingRunner new.
        result := self invoke: (self lockedArguments: #('update' 'kernel-z') in: world)
            in: world runner: runner.
        self assertResult: result refuses: (self pathRefusalIn: world)
            in: world runner: runner.
        self assertUnlockedPathMovesIn: world
    ]

    testS7_InstallFreshRouteRefusesTheEarlierPathDifference [
        "The missing later name makes PinVerification fail, so this
         exercises install's writer route rather than its fast path."
        | world runner result |
        world := self pathWorld: 's25-7' extra: ''.
        self writeEntryFor: 'kernel-z' version: '1.0.0'
            digest: LockedPinFixtures digestA in: (world at: #index).
        self resolveIn: world.
        self movePathIn: world extra: (self indexClauseFor: 'kernel-z').
        self captureProjectIn: world.
        runner := RecordingRunner new.
        result := self invoke: (self lockedArguments: #('install') in: world)
            in: world runner: runner.
        self assertResult: result refuses: (self pathRefusalIn: world)
            in: world runner: runner.
        self assertUnlockedPathMovesIn: world
    ]

    testS8_AddRestoresTheManifestAfterAPathProvenanceRefusal [
        | world runner result |
        world := self pathWorld: 's25-8' extra: ''.
        self writeEntryFor: 'kernel-z' version: '1.0.0'
            digest: LockedPinFixtures digestA in: (world at: #index).
        self resolveIn: world.
        self movePathIn: world extra: ''.
        self captureProjectIn: world.
        runner := RecordingRunner new.
        result := self invoke:
            (self lockedArguments: #('add' 'kernel-z' '=1.0.0') in: world)
            in: world runner: runner.
        self assertResult: result refuses: (self pathRefusalIn: world)
            in: world runner: runner.
        self movePathIn: world extra: (self indexClauseFor: 'kernel-z').
        self assertUnlockedPathMovesIn: world
    ]

    testS9_RemoveRestoresTheManifestAfterAnEarlierPathRefusal [
        | world runner result extra |
        extra := self indexClauseFor: 'kernel-z'.
        world := self pathWorld: 's25-9' extra: extra.
        self writeEntryFor: 'kernel-z' version: '1.0.0'
            digest: LockedPinFixtures digestA in: (world at: #index).
        self resolveIn: world.
        self movePathIn: world extra: extra.
        self captureProjectIn: world.
        runner := RecordingRunner new.
        result := self invoke: (self lockedArguments: #('remove' 'kernel-z') in: world)
            in: world runner: runner.
        self assertResult: result refuses: (self pathRefusalIn: world)
            in: world runner: runner.
        self movePathIn: world extra: ''.
        self assertUnlockedPathMovesIn: world
    ]

    testS10_SourceEditsAtTheSamePathKeepTheLockCurrent [
        | world answer |
        world := self pathWorld: 's25-10' extra: ''.
        self writeProbeIn: world.
        answer := self binary: 'resolve' in: world.
        self assert: answer first = 0 description: answer last.
        self captureProjectIn: world.
        SourceFixtures write: (PathDepFixtures textSourceAnswering: 'edited source')
            toFile: 'KernelText.st' in: (world at: #first).
        answer := self binary: 'resolve --locked' in: world.
        self assert: answer first = 0 description: answer last.
        self assertProjectUnchangedIn: world.
        answer := self binary: 'exec probe.st' in: world.
        self assert: answer first = 0 description: answer last.
        self assert: answer last = ('edited source', SourceFixtures newline).
        self assertProjectUnchangedIn: world
    ]

    testS11_ArchiveLocationAndSummaryAreNotLockIdentity [
        | world runner result |
        world := self pathWorld: 's25-11' extra: ''.
        ExecFixtures writePackage: (self indexRootFor: 'kernel-text' version: '1.2.0')
            in: (world at: #work).
        self writeEntryFor: 'kernel-text' version: '1.2.0'
            digest: LockedPinFixtures digestA in: (world at: #index).
        self resolveIn: world.
        self captureProjectIn: world.
        SourceFixtures write: (self entryFor: 'kernel-text' version: '1.2.0'
            digest: LockedPinFixtures digestA url: 'relocated.star'
            summary: 'edited description') toFile: 'kernel-text-1.2.0.st'
            in: (world at: #index).
        runner := RecordingRunner new.
        result := self invoke: (self lockedArguments: #('resolve') in: world)
            in: world runner: runner.
        self assert: result exitCode = 0 description: result lines printString.
        self assert: result lines = #('kernel-text 1.2.0').
        self assertProjectUnchangedIn: world.
        self assert: runner commands = #()
    ]

    testS12_CurrentInstallKeepsItsSourceFreeFastPath [
        "A nonempty path lock is valid by the settled presence rule.
         The mode must not turn this non-writing route into resolution."
        | world runner cli result work |
        world := self pathWorld: 's25-12' extra: ''.
        self resolveIn: world.
        self captureProjectIn: world.
        work := world at: #work.
        runner := RecordingRunner new.
        cli := (CLI in: work source: SnapshotAndFetchTrapSource new
            store: (ContentStore on: (CommandLineFixtures storeRootIn: work))
            target: (CommandLineFixtures targetDirIn: work) runner: runner)
            withModes: #(#locked).
        result := cli run: #('install').
        self assert: result exitCode = 0 description: result lines printString.
        self assert: result lines = #('kernel-text 1.2.0').
        self assertProjectUnchangedIn: world.
        self assert: runner commands = #()
    ]
]

Namespace current: Smalltalk.
