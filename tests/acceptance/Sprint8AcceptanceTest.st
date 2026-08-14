"Parley Sprint 8 — acceptance scenarios S1-S15 from GitHub issue #10.
 Each scenario Sn maps to exactly one selector starting with testSn_
 (enforced by the wrap traceability gate).

 The milestone: the diagnosis boundary — the binary is the product.
 Sprint 7 closed the ecosystem loop in the test suite; through the
 shipped binary it did not work, and it exited 0 while failing. This
 sprint puts the wiring and the boundary into an object with laws
 (S1-S6), makes both drifts mechanically impossible (S7-S8), tests the
 shipped binary as a real child process (S9-S10, S15), and closes the
 two Sprint 7 ruled gaps (S11-S14).

 Declared passes in red: NONE. Every scenario here fails against the
 pre-sprint tree. Three LAW tests pass in red as regression guards and
 are declared on issue #10 (ValueValidationTest's shape-before-value
 and value-valid-directory-still-scans, and DiagnosisBoundaryTest's
 undiagnosed-list-names-real-classes); no acceptance scenario does.

 S9, S10 and S15 spawn gst running bin/parley-main.st through
 ProcessRunner — the one process seam — and no test spawns a process
 any other way. They spawn in red too, because the law under test IS
 the child's exit code and landed output; each invocation files in all
 of src/, which is the accepted cost of testing the product as users
 run it. Their command lines are composed with absolute paths (the
 child's cwd is the fixture working directory) and pinned in
 CommandLineFixtures.

 Every fixture path is under tmp/, unique per test, removed
 recursively in tearDown; children write only under tmp/; the
 developer image is never mutated; no network is contacted."

Namespace current: Parley.

TestCase subclass: Sprint8AcceptanceTest [
    | fixtureDirs |

    <comment: 'Acceptance scenarios for Sprint 8: CommandLine wiring
and the diagnosis boundary, the two drift laws, the shipped binary as
a real child process, the Publisher destination check, value-shape
validation in the DirectorySource scan, and the ecosystem loop closing
through the product.'>

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

    absentPath: aLabel [
        ^self track: (PublishFixtures absentPathNamed: aLabel)
    ]

    greetingWorkDir: aLabel [
        | path |
        path := self freshDir: aLabel.
        PublishFixtures populateGreetingWorkDirIn: path.
        ^path
    ]

    absolute: aPath [
        ^CommandLineFixtures absolutePathOf: aPath
    ]

    contentsOf: aPath [
        ^(File name: aPath) contents
    ]

    version: aString [
        ^Version fromString: aString
    ]

    versionStringsOf: aCollection [
        ^((aCollection collect: [:each | each printString])
            asSortedCollection: [:a :b | a <= b]) asArray
    ]

    commandLineIn: aWorkDir runner: aRunner [
        ^CommandLine in: aWorkDir runner: aRunner
    ]

    execResultIn: aWorkDir runner: aRunner [
        "THE SCRIPT IS WRITTEN FIRST (Sprint 16, sanctioned at the RED
         review of issue #18): from Doc E §4.1 and §8 decision 56 exec
         refuses a path that is not an existing regular readable file
         before any process is spawned, so S5 and S6 need a real script
         to reach the seam the boundary is being observed through. The
         argv is the workdir-relative spelling from Sprint 22: the
         precondition resolves it against the WORKING DIRECTORY, never
         the process cwd (the exec-cwd family re-pin, issue #24 C1)."
        SourceFixtures write: (ExecFixtures quitScriptContentsFor: 0)
            toFile: 'script.st' in: aWorkDir.
        ^(self commandLineIn: aWorkDir runner: aRunner)
            run: (Array with: 'exec' with: 'script.st')
    ]

    runChild: aCommandString [
        ^ProcessRunner new run: aCommandString
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

    isClass: aClass coveredBy: aCollectionOfClasses [
        ^(aCollectionOfClasses
            detect: [:each | aClass == each or: [aClass inheritsFrom: each]]
            ifNone: [nil]) notNil
    ]

    "---- S1: the wiring reaches Publisher (the shipped defect) ----"

    testS1_theWiringReachesTheRealPublisher [
        | work dest result digest |
        work := self greetingWorkDir: 's8-1-work'.
        dest := self freshDir: 's8-1-dest'.
        result := (self commandLineIn: work runner: ProcessRunner new)
            run: (Array with: 'publish' with: dest).
        self assert: result exitCode = 0.
        self assert: result lines = (Array with:
            (PublishFixtures publishSuccessLineFor: 'kernel-greeting'
                version: '1.0.0')).
        self assert: (PublishFixtures fileNamesIn: dest)
            = (Array
                with: PublishFixtures entryFileName
                with: PublishFixtures archiveFileName).
        digest := Sha256 hexDigestOf:
            (self contentsOf: dest, '/', PublishFixtures archiveFileName).
        self assert: (self contentsOf: dest, '/', PublishFixtures entryFileName)
            = (PublishFixtures greetingEntryWithDigest: digest)
    ]

    "---- S2: the wiring reaches a source; the lock lands in the work dir ----"

    testS2_theWiringReachesASourceAndLocksInTheWorkingDirectory [
        | work index result |
        work := self track:
            (CommandLineFixtures diamondRootWorkDirNamed: 's8-2-work').
        index := self freshDir: 's8-2-index'.
        "the INSTALL diamond: ExecFixtures diamondLockString embeds the
         true digests (see the law twin in CommandLineTest). Corrected
         by the operator mid-Sprint 8."
        InstallFixtures populateInstallDiamondIn: index.
        result := (self commandLineIn: work runner: RecordingRunner new)
            run: (Array with: 'resolve' with: '--source' with: index).
        self assert: result exitCode = 0.
        self assert: result lines = CommandLineFixtures diamondPinLines.
        self assert: (self contentsOf: work, '/parley.lock')
            = ExecFixtures diamondLockString.
        self deny: (File name: 'parley.lock') exists
    ]

    "---- S3: the store and target are the working directory's ----"

    testS3_theStoreAndTargetAreTheWorkingDirectorys [
        | work index commandLine starBytes digest result store |
        work := self track:
            (CommandLineFixtures probeRootWorkDirNamed: 's8-3-work').
        index := self freshDir: 's8-3-index'.
        "construction is pathname-passive, so building the CommandLine
         first fronts the toolchain star build in the red phase"
        commandLine := self commandLineIn: work runner: ProcessRunner new.
        starBytes := ExecFixtures probeStarBytesLabeled: 's8-3'.
        digest := Sha256 hexDigestOf: starBytes.
        ExecFixtures populateProbeSourceIn: index
            bytes: starBytes digest: digest.
        result := commandLine
            run: (Array with: 'install' with: '--source' with: index).
        self assert: result exitCode = 0.
        self assert: result lines = CommandLineFixtures probePinLines.
        store := ContentStore on: (CommandLineFixtures storeRootIn: work).
        self assert: (store containsHash: digest).
        self assert: (self contentsOf:
            (CommandLineFixtures targetDirIn: work), '/parley-probe.star')
                = starBytes.
        self deny: (File name: CommandLineFixtures cwdStoreRoot) exists.
        self deny: (File name: CommandLineFixtures cwdTargetDir) exists
    ]

    "---- S4: a declared Parley error is a diagnosis, exit 1 ----"

    testS4_aDeclaredParleyErrorIsADiagnosis [
        "A working directory with no Package.st. See
         CommandLineFixtures missingManifestProblemFor: — the exit-1
         ManifestError this scenario requires rests on a third
         settled-class exception requested on issue #10, because
         3.2.5's fileIn: signals a kernel FileError on a missing file."
        | work index result |
        work := self freshDir: 's8-4-work'.
        index := self freshDir: 's8-4-index'.
        result := (self commandLineIn: work runner: RecordingRunner new)
            run: (Array with: 'resolve' with: '--source' with: index).
        self assert: result exitCode = 1.
        self assert: result lines = (Array with:
            (CommandLineFixtures missingManifestProblemFor:
                work, '/Package.st'))
    ]

    "---- S5: an undeclared error is exit 70, never 0 ----"

    testS5_anUndeclaredErrorIsExitSeventy [
        | work result |
        work := self freshDir: 's8-5-work'.
        result := self execResultIn: work
            runner: (RaisingRunner raising:
                [Error new signal: CommandLineFixtures plainErrorMessage]).
        self assert: result exitCode = 70.
        self assert: result lines size = 1.
        self assert: (result lines at: 1) = CommandLineFixtures plainErrorLine.
        self deny: result exitCode = 0.
        self deny: result exitCode = 1.
        CommandLineFixtures backtraceMarkers do: [:marker |
            self deny: (CommandLineFixtures does: (result lines at: 1)
                include: marker)]
    ]

    "---- S6: no failing outcome ever answers exit 0 ----"

    testS6_noFailingOutcomeAnswersExitZero [
        | work index usage diagnosed undiagnosed |
        work := self freshDir: 's8-6-work'.
        index := self freshDir: 's8-6-index'.
        usage := (self commandLineIn: work runner: RecordingRunner new)
            run: #('frobnicate').
        diagnosed := (self commandLineIn: work runner: RecordingRunner new)
            run: (Array with: 'resolve' with: '--source' with: index).
        undiagnosed := self execResultIn: work
            runner: (RaisingRunner raising:
                [Error new signal: CommandLineFixtures plainErrorMessage]).
        self deny: usage exitCode = 0.
        self deny: diagnosed exitCode = 0.
        self deny: undiagnosed exitCode = 0.
        self assert: usage exitCode = 2.
        self assert: diagnosed exitCode = 1.
        self assert: undiagnosed exitCode = 70
    ]

    "---- S7: the boundary is a closed set (drift law) ----"

    testS7_theBoundaryIsAClosedSet [
        | parleyErrors diagnosed undiagnosed |
        parleyErrors := CommandLineFixtures parleyErrorClasses.
        self deny: parleyErrors isEmpty.
        diagnosed := CommandLine diagnosedErrorClasses.
        undiagnosed := CommandLineFixtures undiagnosedErrorClassNames.
        self assert: (CommandLineFixtures namesOf: diagnosed)
            = CommandLineFixtures diagnosedErrorClassNames.
        parleyErrors do: [:each |
            | isCovered isNamed |
            isCovered := self isClass: each coveredBy: diagnosed.
            isNamed := undiagnosed includes:
                (CommandLineFixtures nameOf: each).
            self assert: (isCovered or: [isNamed])
                description: (CommandLineFixtures nameOf: each),
                    ' is accounted for by neither list'.
            self deny: (isCovered and: [isNamed])
                description: (CommandLineFixtures nameOf: each),
                    ' is claimed by both lists']
    ]

    "---- S8: the wrapper names every src/ directory (drift law) ----"

    testS8_theWrapperNamesEverySrcDirectory [
        | source names |
        source := CommandLineFixtures wrapperSource.
        names := CommandLineFixtures srcSubdirectoryNames.
        self deny: names isEmpty.
        names do: [:each |
            self assert: (CommandLineFixtures does: source
                include: 'src/', each)
                description: CommandLineFixtures wrapperPath,
                    ' does not name src/', each]
    ]

    "---- S9: the shipped binary succeeds with exit 0 ----"

    testS9_theShippedBinarySucceedsWithExitZero [
        | work dest code |
        work := self greetingWorkDir: 's8-9-work'.
        dest := self freshDir: 's8-9-dest'.
        code := self runChild: (CommandLineFixtures
            shippedBinaryCommandIn: work
            args: 'publish ', (self absolute: dest)).
        self assert: code = 0.
        self assert: (PublishFixtures fileNamesIn: dest)
            = (Array
                with: PublishFixtures entryFileName
                with: PublishFixtures archiveFileName)
    ]

    "---- S10: the shipped binary fails with a nonzero code ----"

    testS10_theShippedBinaryFailsWithANonzeroCode [
        | work index code |
        work := self freshDir: 's8-10-work'.
        index := self freshDir: 's8-10-index'.
        code := self runChild: (CommandLineFixtures
            shippedBinaryCommandIn: work
            args: 'resolve --source ', (self absolute: index)).
        self deny: code = 0
    ]

    "---- S11: publishing into a missing destination is one problem ----"

    testS11_publishingIntoAMissingDestinationIsOneProblem [
        | work dest runner problems |
        work := self greetingWorkDir: 's8-11-work'.
        dest := self absentPath: 's8-11-dest'.
        runner := RecordingRunner new.
        problems := self publishProblemsFrom: [
            (Publisher
                manifest: PublishFixtures greetingManifest
                in: work
                to: dest
                runner: runner) publish].
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = (CommandLineFixtures missingDestinationProblemFor: dest).
        self assert: runner commands = #().
        self deny: (File name: dest) exists
    ]

    "---- S12: an unparseable #version is one batched problem ----"

    testS12_anUnparseableVersionIsOneBatchedProblem [
        | dir problems |
        dir := self freshDir: 's8-12-entries'.
        SourceFixtures write: CommandLineFixtures entryWithUnparseableVersion
            toFile: 'p-1.0.0.st' in: dir.
        problems := self sourceProblemsFrom: [
            (DirectorySource on: dir) snapshot].
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = (CommandLineFixtures unparseableVersionProblemFor: 'p-1.0.0.st'
                value: CommandLineFixtures unparseableVersionValue)
    ]

    "---- S13: an unparseable constraint is one batched problem ----"

    testS13_anUnparseableConstraintIsOneBatchedProblem [
        | dir problems |
        dir := self freshDir: 's8-13-entries'.
        SourceFixtures write: CommandLineFixtures entryWithUnparseableConstraint
            toFile: 'p-1.0.0.st' in: dir.
        problems := self sourceProblemsFrom: [
            (DirectorySource on: dir) snapshot].
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = (CommandLineFixtures
                unparseableConstraintProblemFor: 'p-1.0.0.st'
                dependency: 'q'
                value: CommandLineFixtures unparseableConstraintValue)
    ]

    "---- S14: value problems batch with the settled and shape ones ----"

    testS14_valueProblemsBatchWithTheSettledAndShapeProblems [
        | bad clean problems snap |
        bad := self freshDir: 's8-14-bad'.
        CommandLineFixtures populateEveryProblemKindIn: bad.
        problems := self sourceProblemsFrom: [
            (DirectorySource on: bad) snapshot].
        self assert: problems size = 5.
        self assert: problems = CommandLineFixtures everyProblemKindProblems.
        clean := self freshDir: 's8-14-clean'.
        SourceFixtures populateDiamondIn: clean.
        snap := (DirectorySource on: clean) snapshot.
        self assert: (self versionStringsOf: (snap versionsOf: 'c'))
            = #('1.5.0' '2.4.0' '3.0.0')
    ]

    "---- S15: the ecosystem loop closes through the shipped binary ----"

    testS15_theEcosystemLoopClosesThroughTheShippedBinary [
        | authorWork index publishCode consumerWork installCode digest
          proofPath execCode |
        "author A publishes, as a real child process"
        authorWork := self greetingWorkDir: 's8-15-author'.
        index := self freshDir: 's8-15-index'.
        publishCode := self runChild: (CommandLineFixtures
            shippedBinaryCommandIn: authorWork
            args: 'publish ', (self absolute: index)).
        self assert: publishCode = 0.
        self assert: (PublishFixtures fileNamesIn: index)
            = (Array
                with: PublishFixtures entryFileName
                with: PublishFixtures archiveFileName).
        digest := Sha256 hexDigestOf:
            (self contentsOf: index, '/', PublishFixtures archiveFileName).
        "author B installs A's package, as a real child process"
        consumerWork := self track:
            (CommandLineFixtures consumerWorkDirNamed: 's8-15-consumer').
        installCode := self runChild: (CommandLineFixtures
            shippedBinaryCommandIn: consumerWork
            args: 'install --source ', (self absolute: index)).
        self assert: installCode = 0.
        self assert: ((ContentStore on:
            (CommandLineFixtures storeRootIn: consumerWork))
                containsHash: digest).
        "author B executes a proof script, as a real child process"
        proofPath := (self absolute: consumerWork), '/proof.txt'.
        SourceFixtures
            write: (PublishFixtures greetingProofScriptContentsFor: proofPath)
            toFile: 'proof-script.st' in: consumerWork.
        execCode := self runChild: (CommandLineFixtures
            shippedBinaryCommandIn: consumerWork
            args: 'exec ', (self absolute: consumerWork), '/proof-script.st').
        self assert: execCode = 0.
        self assert: (self contentsOf: proofPath) = 'present'
    ]
]

Namespace current: Smalltalk.
