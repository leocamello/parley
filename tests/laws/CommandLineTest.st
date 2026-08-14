"Parley Sprint 8 — CommandLine: the wiring and the diagnosis boundary
 (issue #10 S1-S6; Doc E §4.2).

 The wrapper used to hold the wiring AND the flag grammar AND the error
 boundary, and was declared 'glue, excluded from SUnit obligations'.
 That declaration was wrong and it cost: the hardcoded file-in list
 silently missed src/publish/, so the shipped publish verb answered a
 doesNotUnderstand: backtrace — and exited 0. Everything the wrapper
 did except loading, printing and exiting now lives in an object with
 laws.

 Protocol decisions pinned here (posted on issue #10 for confirmation):
   - constructor: CommandLine in: aWorkingDir runner: aProcessRunner —
     two collaborators held immutably, class-side construction, zero
     public setters, NO value equality (the decision-23 precedent);
     construction is pathname-passive (no I/O, no process);
   - run: anArgvArray answers a CliResult and nothing else: it never
     prints and never terminates the image. Printing and exiting are
     bin/parley-main.st's job alone;
   - the flag grammar: a leading '--' is stripped, '--source <dir>'
     wires a DirectorySource over <dir> (absent => nil), and every
     remaining argument is the verb argv handed to the settled CLI
     UNCHANGED — the settled argv grammar and usage lines do not move;
   - the wiring: store at <workingDir>/.parley/store, target at
     <workingDir>/.parley/packages, both derived from the WORKING
     DIRECTORY and never from the process cwd (CommandLineFixtures
     storeRootIn:/targetDirIn:);
   - the boundary: success => the verb's lines and exit 0; usage =>
     the pinned lines and exit 2; a DECLARED Parley error
     (ManifestError, SourceError, InstallError, ExecutionError,
     PublishError) => its problems, or its messageText as one line,
     and exit 1; anything else => ONE line naming the error class and
     message text (CommandLineFixtures internalErrorLineFor:message:)
     and exit 70. Never a backtrace, and never 0;
   - CommandLine class >> diagnosedErrorClasses answers the declared
     set, so the closed-set law (S7) can hold the boundary to its own
     declaration rather than to a copy of it.

 The boundary is probed through a runner double that SIGNALS
 (RaisingRunner): 'exec' reaches the one process seam, so a double
 there puts an arbitrary error on the boundary's doorstep. That is the
 only honest way to observe the exit-1 / exit-70 split, and it is how
 the subclass case is constructed — an isKindOf: or class-identity
 chain over exception classes could not pass
 testASubclassOfADeclaredErrorIsDiagnosedByHandling.

 Real processes appear only where the law under test IS the wiring
 reaching the real toolchain (publish and install); every other law
 uses a double. Every fixture path is under tmp/, unique per test, and
 removed recursively in tearDown; the developer image is never
 mutated."

Namespace current: Parley.

TestCase subclass: CommandLineTest [
    | fixtureDirs |

    <comment: 'Laws for CommandLine: pathname-passive construction, no
value equality, the leading-double-dash strip, the --source grammar,
the working-directory-derived store and target, and every shape of the
diagnosis boundary.'>

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

    commandLineIn: aWorkDir runner: aRunner [
        ^CommandLine in: aWorkDir runner: aRunner
    ]

    execResultIn: aWorkDir runner: aRunner [
        "Run 'exec <script>' — the shortest verb path that reaches the
         one process seam, so the runner double's signal lands on the
         boundary.

         THE SCRIPT IS WRITTEN FIRST (Sprint 16, sanctioned at the RED
         review of issue #18). From Doc E §4.1 and §8 decision 56 the
         verb refuses a script that is not an existing regular readable
         file BEFORE any process is spawned, so a law that handed the
         runner a path nobody ever wrote would answer the precondition
         instead of reaching the boundary. It never reached it for the
         right reason before either: these laws claim the boundary sees
         what the seam raises, and a path that does not exist could not
         have proved that.

         THE ARGV IS THE WORKDIR-RELATIVE SPELLING from Sprint 22: the
         precondition resolves the script against the WORKING
         DIRECTORY, never the process cwd (the exec-cwd family re-pin,
         issue #24 C1), and the script is written exactly where the
         resolution will look."
        SourceFixtures write: (ExecFixtures quitScriptContentsFor: 0)
            toFile: 'script.st' in: aWorkDir.
        ^(self commandLineIn: aWorkDir runner: aRunner)
            run: (Array with: 'exec' with: 'script.st')
    ]

    resultOfRaising: aBlock in: aWorkDir [
        ^self execResultIn: aWorkDir runner: (RaisingRunner raising: aBlock)
    ]

    contentsOf: aPath [
        ^(File name: aPath) contents
    ]

    "---- construction: pathname-passive, immutable, no value equality ----"

    testConstructionTouchesNothing [
        "A CommandLine can be built over paths that do not exist yet:
         no directory is created, no file is read, no process runs."
        | work commandLine runner |
        work := self absentPath: 'cl-passive-work'.
        runner := TrapRunner new.
        commandLine := self commandLineIn: work runner: runner.
        self deny: commandLine isNil.
        self deny: (File name: work) exists.
        self deny: (File name: (CommandLineFixtures parleyDirIn: work)) exists
    ]

    testCommandLinesCarryNoValueEquality [
        "The decision-23 precedent: a composition root is not a value."
        | work a b |
        work := self absentPath: 'cl-equality-work'.
        a := self commandLineIn: work runner: RecordingRunner new.
        b := self commandLineIn: work runner: RecordingRunner new.
        self assert: a = a.
        self deny: a = b
    ]

    "---- the flag grammar ----"

    testALeadingDoubleDashIsStripped [
        "bin/parley execs 'gst -f <main> -- <argv>', so the argv can
         arrive with a leading '--'. It is stripped here, and only
         here: the settled CLI never sees it."
        | work result |
        work := self freshDir: 'cl-dashdash-work'.
        result := (self commandLineIn: work runner: RecordingRunner new)
            run: #('--' 'init').
        self assert: result exitCode = 0.
        self assert: result lines = ExecFixtures initSuccessLines.
        self assert: (self contentsOf: work, '/Package.st')
            = ExecFixtures initTemplateContents
    ]

    testTheVerbArgvReachesTheSettledCliUnchanged [
        "--source is consumed by the flag grammar and everything else
         is handed on verbatim — an unknown verb still answers the
         settled usage lines, unchanged by this sprint."
        | work result |
        work := self freshDir: 'cl-passthrough-work'.
        result := (self commandLineIn: work runner: RecordingRunner new)
            run: #('frobnicate' '--source' 'tmp/parley-nowhere').
        self assert: result exitCode = 2.
        self assert: result lines = (GrammarFixtures
            usageAnswerFor: #unknownVerb subject: 'frobnicate')
            description: 'an unknown verb answered ', result lines printString
    ]

    testASourceRequiringVerbWithoutASourceIsUsageAtExitTwo [
        "Doc E §4.2's third usage ground, which no other law covered:
         '--source' absent wires nil, and the composition root must
         hand that nil ON to the settled CLI rather than invent a
         source or crash — the CLI already answers usage, exit 2. Added
         by the operator at the Sprint 8 RED review.

         DRIVEN THROUGH install FROM SPRINT 21 (§8 decisions 83, 84).
         The ground is unchanged and so is the wiring claim, but resolve
         is no longer a source-requiring verb, so a law about a
         SOURCE-REQUIRING verb has to drive one that still is: install
         is the mirror's remaining member and the bound decision 83
         named.

         RESOLVE'S NEW ANSWER IS PINNED HERE TOO, over the SAME
         directory, because that is the stronger evidence for this law's
         own ground: the nil is still handed on, and the verb — not the
         grammar — composes the declared refusal naming the flags. A
         composition root that invented a source could not produce that
         sentence, and one that crashed could not produce a result at
         all."
        | work result moved |
        work := self track:
            (CommandLineFixtures diamondRootWorkDirNamed: 'cl-nosource-work').
        result := (self commandLineIn: work runner: RecordingRunner new)
            run: #('install').
        self assert: result exitCode = 2.
        self assert: result lines = (GrammarFixtures
            usageAnswerFor: #needsIndex subject: 'install')
            description: 'a source-less install answered ', result lines printString.
        self deny: (File name: work, '/parley.lock') exists.
        moved := (self commandLineIn: work runner: RecordingRunner new)
            run: #('resolve').
        self assert: moved exitCode = 1
            description: 'a source-less resolve answered exit ',
                moved exitCode printString, ': ', moved lines printString.
        "the two names ExecFixtures diamondRootContents DECLARES; c is
         transitive and the refusal names what the manifest declares"
        self assert: moved lines = (Array with: (PathDepFixtures
            needsIndexRefusalFor: (Array with: 'a' with: 'b')))
            description: 'a source-less resolve answered ', moved lines printString.
        self deny: (File name: work, '/parley.lock') exists
    ]

    "---- S2: --source wires a real DirectorySource ----"

    testResolveWiresTheSourceAndLocksInTheWorkingDirectory [
        | work index result |
        work := self track:
            (CommandLineFixtures diamondRootWorkDirNamed: 'cl-resolve-work').
        index := self freshDir: 'cl-resolve-index'.
        "the INSTALL diamond, not the source diamond: ExecFixtures
         diamondLockString embeds the true digests, and SourceFixtures
         populateDiamondIn: writes the 'ab12'/'cd34'/'ef56'
         placeholders — the oracle and that fixture can never agree.
         This is the pairing CliTest>>diamondEntriesDir: has used since
         Sprint 6. Corrected by the operator mid-Sprint 8, from the
         agent's report; the mistake was the reviewer's."
        InstallFixtures populateInstallDiamondIn: index.
        result := (self commandLineIn: work runner: RecordingRunner new)
            run: (Array with: 'resolve' with: '--source' with: index).
        self assert: result exitCode = 0.
        self assert: result lines = CommandLineFixtures diamondPinLines.
        self assert: (self contentsOf: work, '/parley.lock')
            = ExecFixtures diamondLockString.
        "the lock lands in the WORKING directory, never beside the cwd"
        self deny: (File name: 'parley.lock') exists
    ]

    "---- S3: the store and target are the working directory's ----"

    testInstallWiresTheStoreAndTargetUnderTheWorkingDirectory [
        | work index commandLine starBytes digest result store |
        work := self track:
            (CommandLineFixtures probeRootWorkDirNamed: 'cl-install-work').
        index := self freshDir: 'cl-install-index'.
        "build the CommandLine first: construction is pathname-passive,
         and in the red phase the missing class fronts the toolchain
         star build below, so the red run spawns nothing here"
        commandLine := self commandLineIn: work runner: ProcessRunner new.
        starBytes := ExecFixtures probeStarBytesLabeled: 'cl-install'.
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
        "nothing is created beside the process's cwd"
        self deny: (File name: CommandLineFixtures cwdStoreRoot) exists.
        self deny: (File name: CommandLineFixtures cwdTargetDir) exists
    ]

    "---- S1: the wiring reaches a real Publisher (the shipped defect) ----"

    testPublishReachesARealPublisher [
        | work dest result digest |
        work := self freshDir: 'cl-publish-work'.
        PublishFixtures populateGreetingWorkDirIn: work.
        dest := self freshDir: 'cl-publish-dest'.
        result := (self commandLineIn: work runner: ProcessRunner new)
            run: (Array with: 'publish' with: dest).
        self assert: result exitCode = 0.
        self assert: result lines = (Array with:
            (PublishFixtures publishSuccessLineFor: 'kernel-greeting'
                version: '1.0.0')).
        digest := Sha256 hexDigestOf:
            (self contentsOf: dest, '/', PublishFixtures archiveFileName).
        self assert: (self contentsOf: dest, '/', PublishFixtures entryFileName)
            = (PublishFixtures greetingEntryWithDigest: digest)
    ]

    "---- the boundary: declared Parley errors are diagnoses, exit 1 ----"

    testABatchedParleyErrorBecomesItsProblemsAtExitOne [
        | work result |
        work := self freshDir: 'cl-batched-work'.
        result := self resultOfRaising:
            [SourceError signalProblems: #('one' 'two')] in: work.
        self assert: result exitCode = 1.
        self assert: result lines = #('one' 'two')
    ]

    testEveryDeclaredBatchedErrorIsDiagnosedTheSameWay [
        "One shape for every problem-carrying declared error — the
         boundary classifies by handling, not by class.

         LockError joined them at Sprint 9 (issue #11): it carries
         problems exactly as its four siblings do, which is precisely
         why the boundary absorbs it with NO new mechanism — the
         batched-error handler is derived from the declared list, so
         adding a name to that list is the whole change."
        | work |
        work := self freshDir: 'cl-declared-work'.
        ((Array
            with: [ManifestError signalProblems: #('manifest problem')]
            with: [SourceError signalProblems: #('source problem')]
            with: [InstallError signalProblems: #('install problem')]
            with: [PublishError signalProblems: #('publish problem')]),
            (Array with: [LockError signalProblems: #('lock problem')]))
                with: #(#('manifest problem') #('source problem')
                        #('install problem') #('publish problem')
                        #('lock problem'))
                do: [:raise :expected |
                    | result |
                    result := self resultOfRaising: raise in: work.
                    self assert: result exitCode = 1.
                    self assert: result lines = expected]
    ]

    testAnExecutionErrorContributesItsMessageTextAsOneLine [
        "ExecutionError carries no problems — it is fail-stop and
         environmental — so its messageText is the single line."
        | work result expected |
        work := self freshDir: 'cl-execerror-work'.
        expected := ExecFixtures executionErrorMessageFor: 'some command'
            code: 3.
        result := self resultOfRaising:
            [ExecutionError signalCommand: 'some command' exitCode: 3]
            in: work.
        self assert: result exitCode = 1.
        self assert: result lines = (Array with: expected)
    ]

    testASubclassOfADeclaredErrorIsDiagnosedByHandling [
        "on:do:, never isKindOf: — and never a class-identity chain
         either: a SUBCLASS of a declared error must be diagnosed at
         exit 1, carrying its problems, without being named anywhere."
        | work result |
        work := self freshDir: 'cl-subclass-work'.
        self deny: (CommandLine diagnosedErrorClasses
            includes: DerivedSourceError).
        self assert: (DerivedSourceError inheritsFrom: SourceError).
        result := self resultOfRaising:
            [DerivedSourceError signalProblems:
                (Array with: CommandLineFixtures derivedSourceProblem)]
            in: work.
        self assert: result exitCode = 1.
        self assert: result lines
            = (Array with: CommandLineFixtures derivedSourceProblem)
    ]

    "---- the boundary: anything else is exit 70, one line ----"

    testAnUndeclaredErrorIsOneLineAtExitSeventy [
        | work result |
        work := self freshDir: 'cl-undeclared-work'.
        result := self resultOfRaising:
            [Error new signal: CommandLineFixtures plainErrorMessage]
            in: work.
        self assert: result exitCode = 70.
        self assert: result lines size = 1.
        self assert: (result lines at: 1) = CommandLineFixtures plainErrorLine.
        self deny: result exitCode = 0.
        self deny: result exitCode = 1
    ]

    testAnUndeclaredErrorNeverAnswersABacktrace [
        "One line, naming the class and the message text — nothing
         that looks like a 3.2.5 dump."
        | work result |
        work := self freshDir: 'cl-nobacktrace-work'.
        result := self resultOfRaising:
            [ZeroDivide new signal: 'divided by zero'] in: work.
        self assert: result exitCode = 70.
        self assert: result lines size = 1.
        CommandLineFixtures backtraceMarkers do: [:marker |
            self deny: (CommandLineFixtures does: (result lines at: 1)
                include: marker)
                description: 'the exit-70 line looks like a backtrace: ', marker]
    ]

    "---- the boundary: usage, and never exit 0 on a failure ----"

    testUsageIsThePinnedLinesAtExitTwo [
        | work result |
        work := self freshDir: 'cl-usage-work'.
        result := (self commandLineIn: work runner: RecordingRunner new)
            run: #().
        self assert: result exitCode = 2.
        self assert: result lines
            = (GrammarFixtures usageAnswerFor: #noVerb subject: '')
            description: 'an empty argv answered ', result lines printString
    ]

    testNoFailingOutcomeAnswersExitZero [
        "The three failing shapes are nonzero AND distinct: 1 says
         'your input is wrong', 70 says 'the tool is broken', 2 says
         'you asked wrongly'."
        | work usage diagnosed undiagnosed |
        work := self freshDir: 'cl-nonzero-work'.
        usage := (self commandLineIn: work runner: RecordingRunner new)
            run: #('frobnicate').
        diagnosed := self resultOfRaising:
            [SourceError signalProblems: #('a source problem')] in: work.
        undiagnosed := self resultOfRaising:
            [Error new signal: CommandLineFixtures plainErrorMessage]
            in: work.
        self deny: usage exitCode = 0.
        self deny: diagnosed exitCode = 0.
        self deny: undiagnosed exitCode = 0.
        self assert: usage exitCode = 2.
        self assert: diagnosed exitCode = 1.
        self assert: undiagnosed exitCode = 70
    ]

    "---- S4: a missing Package.st is a diagnosis, not an escape ----"

    testAMissingPackageStIsADiagnosisAtExitOne [
        "The second half of the motivating defect. See
         CommandLineFixtures missingManifestProblemFor: — this law
         rests on the third settled-class exception requested on
         issue #10 (ManifestFile must check the path: 3.2.5's fileIn:
         signals a kernel FileError on a missing file, which the
         boundary would otherwise diagnose at 70, not 1)."
        | work index result |
        work := self freshDir: 'cl-nomanifest-work'.
        index := self freshDir: 'cl-nomanifest-index'.
        result := (self commandLineIn: work runner: RecordingRunner new)
            run: (Array with: 'resolve' with: '--source' with: index).
        self assert: result exitCode = 1.
        self assert: result lines = (Array with:
            (CommandLineFixtures missingManifestProblemFor:
                work, '/Package.st'))
    ]
]

Namespace current: Smalltalk.
