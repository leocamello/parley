"Parley Sprint 16 — acceptance scenarios S1-S17 (issue #18).

 THE SPRINT THAT MAKES v1.0 FIT TO CUT. The product is code-complete and
 uncut, and it was walked end to end by hand before the tag: publish,
 init, add, resolve, check, tree, why, install, exec, and every refusal
 path a first user meets. The happy path is clean and the diagnoses
 are, with four exceptions, exactly right. NONE OF THE FOUR IS A
 MISSING FEATURE. Every one is the tool disagreeing with itself, and
 every one is on a path a new user reaches in their first session.

 ONE SENTENCE GOVERNS THE WHOLE SPRINT (§8 decision 58, generalized):
 a diagnosis that names a cause has MADE A CLAIM, and this tool only
 makes claims it has checked. It is why the held-pins line is now
 earned rather than guessed; it is also why decision 56 exists, because
 a boundary that validates what a file SAYS has already claimed the
 file could be read.

 EACH FIX HAS AN OVER-NARROWING TWIN, AND THE TWIN IS A SEPARATE
 SCENARIO — S3 beside S1/S2, S6 beside S5, S13 beside S12 — because a
 guard folded into the scenario it guards cannot fail independently of
 it. A pair that cannot pass together is a halt-and-ask, not a trade.

 DECLARED PASSES IN RED (issue #18), each a SETTLED-BEHAVIOUR GUARD
 that passes today and must keep passing, never a new claim:
   testS3_AScriptThatExistsStillRunsAndPassesItsExitCodeThrough — §8
     decision 45, unchanged: the precondition must not become a gate
     that inspects, wraps or judges the child.
   testS6_AReadableButCorruptLockStillLeavesResolveAtExitZero — the
     settled Doc E §4.1 behaviour: the guard that stops refuse an
     unreadable lock from being implemented as refuse every lock
     problem.
   testS11_TheSettledUsageErrorGrammarDoesNotMove — the settled
     valueOf:in: trailing-flag behaviour: the guard that keeps one
     declared special case from becoming a grammar.
   testS13_AConflictHoldingDidCauseStillSaysSo — the settled Sprint 13
     narration: the guard that stops S12 from being implemented as
     deleting the line.
 Every other scenario fails against the pre-sprint tree.

 COST, DECLARED: S1-S2, S4-S7, S10-S14 and S17 run in-image against
 tmp/ fixtures with recording and trap runners and spawn NOTHING. S3
 spawns one real curated child. S8 and S9 spawn the shipped binary
 (four child processes between them, which is what it costs to prove a
 question flag through the product the user actually types). S16 runs
 the real toolchain — gst-package builds the fixture archive, the
 installer fetches and hash-verifies it, the registration plan runs and
 a curated child proves the class visible. No scenario contacts a
 network, and none runs git.

 Every fixture path is under tmp/, unique per test, removed recursively
 in tearDown — recursively matters more than usual here, because a
 directory-shaped parley.lock and a directory handed to exec are two of
 the fixtures. The developer image is never mutated."

Namespace current: Parley.

TestCase subclass: Sprint16AcceptanceTest [
    | fixtureDirs |

    <comment: 'The Sprint 16 acceptance scenarios: the exec script
precondition with its no-spawn assertion and pass-through guard, the
lock readability check with its corrupt-lock guard and its all-verbs
sameness law, the question flags at exit 0 through the shipped binary
with the settled usage grammar held unchanged, no usage error creating
project state, the checked held-pins line on both verbs with its
over-narrowing guard, the README drift laws, and the first session run
end to end so it cannot regress.'>

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

    toolsIndex: aLabel [
        | path |
        path := self freshDir: aLabel.
        SelectiveUpdateFixtures populateToolsIndexIn: path.
        ^path
    ]

    resultOf: anArgvArray in: aWorkDir runner: aRunner [
        ^(CommandLine in: aWorkDir runner: aRunner) run: anArgvArray
    ]

    resultOf: anArgvArray in: aWorkDir [
        ^self resultOf: anArgvArray in: aWorkDir runner: RecordingRunner new
    ]

    exists: aPath [
        ^(File name: aPath) exists
    ]

    contentsOf: aPath [
        ^(File name: aPath) contents
    ]

    snapshotOf: anIndexDir [
        ^(DirectorySource on: anIndexDir) snapshot
    ]

    denyBlamesParley: aResult [
        "No diagnosis this sprint answers blames Parley, dumps a
         backtrace, or puts a kernel class name on screen. The last of
         those is not hypothetical: the shipped lock defect printed
         WrongClass and a raw integer."
        self deny: aResult exitCode = 70
            description: 'the command answered exit 70: ',
                aResult lines printString.
        aResult lines do: [:line |
            self deny: (CommandLineFixtures does: line
                include: LockBoundaryFixtures undiagnosedLinePrefix)
                description: 'the diagnosis blames Parley: ', line.
            self deny: (CommandLineFixtures does: line
                include: ReadinessFixtures kernelErrorMarker)
                description: 'the diagnosis names a kernel error: ', line.
            CommandLineFixtures backtraceMarkers do: [:marker |
                self deny: (CommandLineFixtures does: line include: marker)
                    description: 'the diagnosis dumped a backtrace: ', line]]
    ]

    shippedBinaryOutputIn: aWorkDir args: anArgsString labelled: aLabel [
        "Run the SHIPPED binary and answer an Array of two elements: the
         exit code, and the child's whole output as lines. The child
         writes to a capture file under the fixture directory — the
         redirect is a test-composed shell tail, and ProcessRunner
         still captures nothing."
        | outPath code |
        outPath := (CommandLineFixtures absolutePathOf: aWorkDir),
            '/', aLabel, '.txt'.
        code := ProcessRunner new run: (CommandLineFixtures
            shippedBinaryCommandIn: aWorkDir
            args: anArgsString
            outputTo: outPath).
        ^Array with: code
            with: (ExecFixtures linesOf: (self contentsOf: outPath))
    ]

    "---- S1: exec refuses a script that is not there ----"

    testS1_ExecRefusesAScriptThatIsNotThere [
        "exit 1, ONE line naming the path in the settled missing-file
         grammar, and NO PROCESS SPAWNED — asserted on a recording
         runner, because it exited 1 is satisfied equally well by a
         spawn that happened to fail, and the claim is that Parley
         decided before the process seam was reached.

         What shipped: exit 0, and the child printing
         gst: Couldn't open file. §8 decision 45's documented consumer
         constraint — end the script with an explicit quit — is
         unavailable precisely here, because a file that does not exist
         cannot carry a guard."
        | work script runner result |
        work := self freshDir: 's16-s1-work'.
        ExecFixtures writePackage: ExecFixtures noDependencyRootContents
            in: work.
        script := ReadinessFixtures missingScriptPathIn: work.
        self deny: (self exists: script)
            description: 'the missing-script fixture exists'.
        runner := RecordingRunner new.
        result := self resultOf: (Array with: 'exec' with: script)
            in: work runner: runner.
        self assert: result exitCode = 1
            description: 'parley exec on a missing script answered exit ',
                result exitCode printString.
        self assert: result lines
            = (Array with: (ReadinessFixtures execRefusalLineFor: script))
            description: 'the refusal answered ', result lines printString.
        self assert: runner commands = #()
            description: 'the refusal spawned ', runner commands printString.
        self denyBlamesParley: result
    ]

    "---- S2: exec refuses a script that is a directory ----"

    testS2_ExecRefusesAScriptThatIsADirectory [
        "The same refusal, and the WORSE of the two shipped shapes: a
         directory EXISTS, so every check written against existence
         waved it through, and the child answered exit 0 printing
         nothing at all."
        | work script runner result |
        work := self freshDir: 's16-s2-work'.
        ExecFixtures writePackage: ExecFixtures noDependencyRootContents
            in: work.
        script := ReadinessFixtures makeDirectoryScriptIn: work.
        self assert: (self exists: script)
            description: 'the directory fixture was not created'.
        runner := RecordingRunner new.
        result := self resultOf: (Array with: 'exec' with: script)
            in: work runner: runner.
        self assert: result exitCode = 1
            description: 'parley exec on a directory answered exit ',
                result exitCode printString.
        self assert: result lines
            = (Array with: (ReadinessFixtures execRefusalLineFor: script))
            description: 'the refusal answered ', result lines printString.
        self assert: runner commands = #()
            description: 'the refusal spawned ', runner commands printString.
        self denyBlamesParley: result
    ]

    "---- S3: a script that exists still runs, and its code passes ----"

    testS3_AScriptThatExistsStillRunsAndPassesItsExitCodeThrough [
        "DECLARED PASS IN RED (issue #18) — §8 decision 45, UNCHANGED,
         and the guard against over-narrowing: the precondition must
         not become a gate that inspects, wraps or judges the child.
         This one really launches the curated child, because a
         pass-through proved against a double proves the double.

         The script calls ObjectMemory quit: 3, so 3 is what the tool
         must answer — and the CLI contributes no lines of its own,
         since the child already streamed to the terminal."
        | work script result |
        work := self freshDir: 's16-s3-work'.
        ExecFixtures writePackage: ExecFixtures noDependencyRootContents
            in: work.
        script := ReadinessFixtures writeQuitThreeScriptIn: work.
        self assert: (self exists: script)
            description: 'the pass-through fixture was not written'.
        result := self resultOf: (Array with: 'exec' with: script)
            in: work runner: ProcessRunner new.
        self assert: result exitCode = 3
            description: 'the child exit code did not pass through: ',
                result exitCode printString.
        self assert: result lines = #()
            description: 'exec contributed lines of its own: ',
                result lines printString
    ]

    "---- S4: a directory-shaped lock is named, not blamed on Parley ----"

    testS4_ADirectoryShapedLockIsNamedNotBlamedOnParley [
        "exit 1, ONE LockError line naming parley.lock and the repair,
         and NO backtrace and NO kernel text — asserted by denying the
         settled backtrace markers and the substring WrongClass.

         What shipped: exit 70 and
         internal error: WrongClass: Invalid argument
         -9223372036854771711: must be a SmallInteger - this is a
         defect in Parley, not in your project. A kernel integer on the
         operator's screen, a lie about whose fault it is, and the
         offending file never named."
        | index work result |
        index := self toolsIndex: 's16-s4-index'.
        work := self track: (ReadinessFixtures
            unreadableLockWorkDirNamed: 's16-s4-work').
        result := self resultOf: (Array with: 'check' with: '--source'
            with: index) in: work.
        self assert: result exitCode = 1
            description: 'check answered exit ', result exitCode printString,
                ': ', result lines printString.
        self assert: result lines size = 1
            description: 'check answered ', result lines printString.
        self assert: result lines
            = (Array with: (ReadinessFixtures unreadableLockProblemFor:
                (ReadinessFixtures lockPathIn: work)))
            description: 'check answered ', result lines printString.
        self denyBlamesParley: result
    ]

    "---- S5: resolve refuses an unreadable lock ----"

    testS5_ResolveRefusesAnUnreadableLockRatherThanAnsweringZero [
        "resolve ignores a CORRUPT lock because it is about to
         overwrite it. It cannot overwrite a directory, so answering 0
         would claim a lock it did not write.

         And it cannot rely on seeding to surface the defect: seedNames
         catches LockError by construction, deferring to the boundary
         that owns the diagnosis, so resolve owes its own check. The
         Sprint 14 add shape — a settled caller whose meaning changes
         without a line of its code changing."
        | index work result |
        index := self toolsIndex: 's16-s5-index'.
        work := self track: (ReadinessFixtures
            unreadableLockWorkDirNamed: 's16-s5-work').
        result := self resultOf: (Array with: 'resolve' with: '--source'
            with: index) in: work.
        self assert: result exitCode = 1
            description: 'resolve answered exit ',
                result exitCode printString, ': ', result lines printString.
        self assert: result lines
            = (Array with: (ReadinessFixtures unreadableLockProblemFor:
                (ReadinessFixtures lockPathIn: work)))
            description: 'resolve answered ', result lines printString.
        self denyBlamesParley: result
    ]

    "---- S6: a readable but corrupt lock still leaves resolve at 0 ----"

    testS6_AReadableButCorruptLockStillLeavesResolveAtExitZero [
        "DECLARED PASS IN RED (issue #18) — the settled Doc E §4.1
         behaviour, UNCHANGED, and the guard that stops S5 from being
         implemented as refuse every lock problem. The assertion is on
         the artifact: exit 0 alone would also be answered by a verb
         that left the corruption in place."
        | index work result |
        index := self toolsIndex: 's16-s6-index'.
        work := self track: (ReadinessFixtures
            corruptLockWorkDirNamed: 's16-s6-work').
        result := self resultOf: (Array with: 'resolve' with: '--source'
            with: index) in: work.
        self assert: result exitCode = 0
            description: 'resolve no longer ignores a corrupt lock: ',
                result lines printString.
        self assert: (self contentsOf: (ReadinessFixtures lockPathIn: work))
            = ReadinessFixtures toolAResolvedLockString
            description: 'resolve did not rewrite the corrupt lock'
    ]

    "---- S7: every lock-reading verb answers the same line ----"

    testS7_TheOtherLockReadingVerbsAnswerTheSameSingleLine [
        "ONE defect, ONE sentence, wherever it is met. All four verbs
         run against the SAME working directory — none of them repairs
         a lock, and update <pkg> refuses before it writes — so the
         claim is literal byte-identity between the four answers rather
         than four answers that merely look alike."
        | index work argvs first |
        index := self toolsIndex: 's16-s7-index'.
        work := self track: (ReadinessFixtures
            unreadableLockWorkDirNamed: 's16-s7-work').
        argvs := Array
            with: (Array with: 'check' with: '--source' with: index)
            with: (Array with: 'why' with: 'tool-a' with: '--source'
                with: index)
            with: (Array with: 'tree' with: '--source' with: index)
            with: (Array with: 'update' with: 'tool-a' with: '--source'
                with: index).
        first := nil.
        argvs do: [:argv |
            | result |
            result := self resultOf: argv in: work.
            self assert: result exitCode = 1
                description: argv printString, ' answered exit ',
                    result exitCode printString, ': ',
                    result lines printString.
            self assert: result lines size = 1
                description: argv printString, ' answered ',
                    result lines printString.
            first isNil
                ifTrue: [first := result lines at: 1]
                ifFalse: [
                    self assert: (result lines at: 1) = first
                        description: argv printString,
                            ' answered a different line: ',
                            (result lines at: 1) printString].
            self denyBlamesParley: result].
        self assert: first
            = (ReadinessFixtures unreadableLockProblemFor:
                (ReadinessFixtures lockPathIn: work))
            description: 'the shared line is ', first printString
    ]

    "---- S8: --help answers the usage lines at exit 0 ----"

    testS8_TheHelpFlagAnswersTheUsageLinesAtExitZero [
        "Through the SHIPPED BINARY, because the whole defect is about
         what happens when a new user types the first command they
         type. Exit 0 and the pinned usage lines, byte-identical to
         what parley with no argv prints today: --help adds no line to
         the usage block and moves none of it.

         Exit 0 is the whole point of §8 decision 57. The text was
         already printed; it exited 2, so the first command a new user
         types failed any set -e script or CI smoke check while
         --version beside it succeeded."
        | work answer |
        work := self freshDir: 's16-s8-work'.
        answer := self shippedBinaryOutputIn: work
            args: ReadinessFixtures helpFlag
            labelled: 'help'.
        self assert: (answer at: 1) = 0
            description: 'the shipped binary answered exit ',
                (answer at: 1) printString, ': ', (answer at: 2) printString.
        self assert: (answer at: 2) = ExecFixtures usageLines
            description: 'parley --help printed ', (answer at: 2) printString.
        CommandLineFixtures backtraceMarkers do: [:marker |
            (answer at: 2) do: [:line |
                self deny: (CommandLineFixtures does: line include: marker)
                    description: 'parley --help printed a backtrace']].

        "OPERATOR AMENDMENT (Sprint 16 RED review): and through
         bin/parley itself, which is what a user and a CI smoke check
         actually type. The helper above spawns the main script with
         3.2.5's -a; the wrapper execs it with -f ... -- instead, so
         the exit code the ruling is ABOUT travels a different path
         than the one asserted above. testTheHelpFlagSurvivesTheLeading
         Marker proves the strip in-image and the settled
         testTheShellWrapperRunsTheProductEndToEnd proves the wrapper
         for a verb; exit 0 for the QUESTION through the wrapper is the
         composition neither of them makes, and it is the whole claim
         of §8 decision 57."
        self assert: (ProcessRunner new run: (CommandLineFixtures
            shellWrapperCommandIn: work
            args: ReadinessFixtures helpFlag)) = 0
            description: 'bin/parley --help did not answer exit 0'
    ]

    "---- S9: -h and help are the same question ----"

    testS9_TheShortFlagAndTheBareVerbAreTheSameQuestion [
        "A user who guesses any of the three spellings has asked the
         same thing. Asserted against the --help OUTPUT rather than
         against a second literal, so the three cannot drift apart even
         if the usage block later moves."
        | work reference |
        work := self freshDir: 's16-s9-work'.
        reference := self shippedBinaryOutputIn: work
            args: ReadinessFixtures helpFlag
            labelled: 'reference'.
        self assert: (reference at: 1) = 0
            description: 'the reference run answered exit ',
                (reference at: 1) printString.
        (Array with: ReadinessFixtures shortHelpFlag
            with: ReadinessFixtures helpVerb) doWithIndex: [:spelling :i |
                | answer |
                answer := self shippedBinaryOutputIn: work
                    args: spelling
                    labelled: 'spelling-', i printString.
                self assert: (answer at: 1) = 0
                    description: 'parley ', spelling, ' answered exit ',
                        (answer at: 1) printString, ': ',
                        (answer at: 2) printString.
                self assert: (answer at: 2) = (reference at: 2)
                    description: 'parley ', spelling, ' printed ',
                        (answer at: 2) printString]
    ]

    "---- S10: --help creates no state directories ----"

    testS10_TheHelpFlagCreatesNoStateDirectories [
        "The same law --version already carries, and the reason both
         are recognized before createStateDirectories: asking a tool
         how to use it is not running a command in a project, so a
         .parley/ appearing because someone asked for help is state
         created by a question."
        | work |
        work := self freshDir: 's16-s10-work'.
        ReadinessFixtures helpSpellings do: [:spelling |
            | result |
            result := self resultOf: (Array with: spelling)
                in: work runner: TrapRunner new.
            self assert: result exitCode = 0
                description: spelling, ' answered exit ',
                    result exitCode printString.
            self deny: (self exists:
                (CommandLineFixtures parleyDirIn: work))
                description: spelling,
                    ' created the .parley state directory']
    ]

    "---- S11: the settled usage-error grammar does not move ----"

    testS11_TheSettledUsageErrorGrammarDoesNotMove [
        "DECLARED PASS IN RED (issue #18) — the guard that keeps one
         declared special case from becoming a grammar. Failing to say
         what you want is an error even though asking for help is not,
         and a TRAILING flag is not a flag: it travels to the settled
         CLI, which answers usage. If valueless flags became grammar
         these would keep passing and would silently be about something
         else."
        | work |
        work := self freshDir: 's16-s11-work'.
        ReadinessFixtures usageErrorRows do: [:row |
            | result |
            result := self resultOf: (row at: 1) in: work
                runner: TrapRunner new.
            self assert: result exitCode = 2
                description: (row at: 1) printString, ' answered exit ',
                    result exitCode printString.
            self assert: result lines = (GrammarFixtures
                usageAnswerFor: (row at: 2) subject: (row at: 3))
                description: (row at: 1) printString, ' answered ',
                    result lines printString]
    ]

    "---- S12: a conflict holding did not cause does not blame it ----"

    testS12_AConflictHoldingDidNotCauseDoesNotBlameHolding [
        "The commonest error there is — a typo'd package name — and the
         shipped tool led with
         the other pins were held at their locked versions - run parley
         update to move everything, an instruction that cannot help,
         printed ABOVE the real cause. A sentence naming a cause
         asserts that cause.

         The guard that stops the fixture from proving nothing: the
         UNHELD resolution must fail too, or holding really would have
         been the reason and the line would be earned."
        | work index held outcome unheld result |
        work := self track: (ManifestEditFixtures
            toolBWorkDirNamed: 's16-s12-work').
        index := self toolsIndex: 's16-s12-index'.
        held := ManifestEditFixtures heldVersionsIn: work.
        self deny: held isEmpty
            description: 'nothing is held - the scenario would be vacuous'.
        outcome := ResolverFixtures
            resolve: ReadinessFixtures rootAfterAddingAbsentPackage
            against: ((self snapshotOf: index) holding: held).
        self deny: outcome isResolution
            description: 'the fixture does not conflict under holding'.
        unheld := ResolverFixtures
            resolve: ReadinessFixtures rootAfterAddingAbsentPackage
            against: (self snapshotOf: index).
        self deny: unheld isResolution
            description: 'the fixture resolves unheld - holding WOULD be the reason'.
        result := self resultOf: (Array
                with: 'add' with: ReadinessFixtures absentPackageName
                with: ReadinessFixtures absentPackageConstraint
                with: '--source' with: index)
            in: work.
        self assert: result exitCode = 1
            description: 'the add answered exit ', result exitCode printString.
        self deny: (result lines includes: ReadinessFixtures heldPinsLine)
            description: 'the held-pins line was asserted unchecked: ',
                result lines printString.
        self assert: result lines
            = (ExecFixtures linesOf: outcome printString)
            description: 'the answer is not the settled narration alone: ',
                result lines printString.
        self denyBlamesParley: result
    ]

    "---- S13: a conflict holding did cause still says so ----"

    testS13_AConflictHoldingDidCauseStillSaysSo [
        "DECLARED PASS IN RED (issue #18) — the settled Sprint 13
         behaviour, and the guard that stops S12 from being implemented
         as deleting the line. The held-pins line is PRESENT and FIRST,
         followed by the settled narration.

         The guard that makes it real: the UNHELD resolution must
         SUCCEED, which is exactly what makes holding the reason."
        | work index held outcome unheld result |
        work := self track: (ManifestEditFixtures
            heldConflictWorkDirNamed: 's16-s13-work').
        index := self freshDir: 's16-s13-index'.
        SelectiveUpdateFixtures populateHeldConflictIndexIn: index.
        held := ManifestEditFixtures heldVersionsIn: work.
        outcome := ResolverFixtures
            resolve: ManifestEditFixtures heldConflictRootManifestAfterAdd
            against: ((self snapshotOf: index) holding: held).
        self deny: outcome isResolution
            description: 'the fixture does not conflict under holding'.
        unheld := ResolverFixtures
            resolve: ManifestEditFixtures heldConflictRootManifestAfterAdd
            against: (self snapshotOf: index).
        self assert: unheld isResolution
            description: 'the fixture does not resolve unheld - holding is NOT the reason'.
        result := self resultOf: (Array
                with: 'add' with: 'app-x' with: '^1.0'
                with: '--source' with: index)
            in: work.
        self assert: result exitCode = 1.
        self assert: (result lines at: 1) = ReadinessFixtures heldPinsLine
            description: 'the checked line was dropped: ',
                result lines printString.
        self assert: result lines
            = ((Array with: ReadinessFixtures heldPinsLine),
                (ExecFixtures linesOf: outcome printString))
            description: 'the answer is ', result lines printString
    ]

    "---- S14: update <pkg> obeys the same rule ----"

    testS14_SelectiveUpdateObeysTheSameRule [
        "One rule, both verbs — the Sprint 13 precedent that a shared
         diagnosis must not drift apart. tool-b is really pinned and
         really held, so the verb really does narrow the world; ^9.0 is
         satisfied by no release of tool-b at all, so holding was never
         the reason and the line must be absent here too."
        | work index held outcome unheld result |
        work := self track: (ReadinessFixtures
            unsatisfiableToolsWorkDirNamed: 's16-s14-work').
        index := self toolsIndex: 's16-s14-index'.
        held := SelectiveUpdateFixtures heldVersionsIn: work
            except: 'tool-a'.
        self deny: held isEmpty
            description: 'nothing is held - the scenario would be vacuous'.
        outcome := ResolverFixtures
            resolve: ReadinessFixtures unsatisfiableToolsManifest
            against: ((self snapshotOf: index) holding: held).
        self deny: outcome isResolution
            description: 'the fixture does not conflict under holding'.
        unheld := ResolverFixtures
            resolve: ReadinessFixtures unsatisfiableToolsManifest
            against: (self snapshotOf: index).
        self deny: unheld isResolution
            description: 'the fixture resolves unheld - holding WOULD be the reason'.
        result := self resultOf: (Array with: 'update' with: 'tool-a'
            with: '--source' with: index) in: work.
        self assert: result exitCode = 1
            description: 'update tool-a answered exit ',
                result exitCode printString.
        self deny: (result lines includes: ReadinessFixtures heldPinsLine)
            description: 'the held-pins line was asserted unchecked: ',
                result lines printString.
        self assert: result lines
            = (ExecFixtures linesOf: outcome printString)
            description: 'the answer is not the settled narration alone: ',
                result lines printString.
        self denyBlamesParley: result
    ]

    "---- S15: the README describes the tool that exists ----"

    testS15_TheReadmeDescribesTheToolThatExists [
        "The settled Sprint 15 verb drift law still passes — every verb
         the CLI's OWN usage line declares appears in the README, read
         live from the running tool — and the two new behaviours are
         documented: the exec precondition BESIDE the settled §8
         decision 45 consumer constraint rather than instead of it, and
         --help wherever --version appears."
        | verbs readme undocumented |
        verbs := PublishLayoutFixtures verbsIn: (GrammarFixtures
            verbsRowIn: (self resultOf: #() in: (self freshDir: 's16-s15-work')
                runner: TrapRunner new) lines).
        self deny: verbs isEmpty
            description: 'no verbs were extracted - the scenario would be vacuous'.
        readme := PublishLayoutFixtures readmeSource.
        undocumented := verbs reject: [:verb |
            CommandLineFixtures does: readme include: 'parley ', verb].
        self assert: undocumented isEmpty
            description: undocumented printString,
                ' are verbs the CLI offers and the README does not name'.
        PublishLayoutFixtures execConstraintMarkers do: [:marker |
            self assert: (CommandLineFixtures does: readme include: marker)
                description: 'the README dropped the settled exec constraint marker: ',
                    marker printString].
        ReadinessFixtures execPreconditionMarkers do: [:marker |
            self assert: (CommandLineFixtures does: readme include: marker)
                description: 'the README does not document the exec precondition: ',
                    marker printString].
        ReadinessFixtures helpDocumentationMarkers do: [:marker |
            self assert: (CommandLineFixtures does: readme include: marker)
                description: 'the README does not document ', marker printString]
    ]

    "---- S17: a command that refuses to run leaves the filesystem
          alone ----"

    testS17_ACommandThatRefusesToRunLeavesTheFilesystemAlone [
        "Each argv runs in its own FRESH, EMPTY directory, because the
         claim is about what the run created and not about what was
         already there. Found the hard way: a bare parley run from the
         repository root during the readiness audit created
         .parley/packages there and broke two settled laws — the tool
         contaminating its own checkout, caught by the suite rather
         than by anyone noticing.

         A command that refuses to run must leave the filesystem as it
         found it: the rule publish already follows when it declines to
         create a destination it refuses, and the rule every other
         refusal in Doc E follows."
        ReadinessFixtures stateCreatingUsageArgvs doWithIndex: [:argv :i |
            | work result |
            work := self freshDir: 's16-s17-work-', i printString.
            result := self resultOf: argv in: work runner: TrapRunner new.
            self assert: result exitCode = 2
                description: argv printString, ' answered exit ',
                    result exitCode printString.
            self assert: (result lines copyFrom: 2 to: result lines size)
                = ExecFixtures usageLines
                description: argv printString, ' answered ',
                    result lines printString.
            self deny: (self exists:
                (CommandLineFixtures parleyDirIn: work))
                description: argv printString,
                    ' created the .parley state directory']
    ]

    "---- S16: the first session, end to end ----"

    testS16_TheFirstSessionEndToEndWithEveryDiagnosisOnTheWay [
        "THE SPRINT'S EXIT CRITERION: the walk that found the four
         defects, run as a law so it cannot regress. An empty
         directory, a real toolchain-built package in a real index, and
         the commands a first user types in the order they type them —
         --help, init, a typo'd exec, add, resolve, check, and finally
         an exec that really runs.

         Every command answers an exit code that matches what happened,
         every failure names its file, no command answers a backtrace
         or a kernel integer, and the only .parley/ that exists is the
         one init and the verbs created — never one beside the process
         cwd, and never one created by the question that opened the
         session."
        | work index starBytes digest results help init typo add resolve check proofPath exec |
        work := self freshDir: 's16-s16-work'.
        index := self freshDir: 's16-s16-index'.
        starBytes := ExecFixtures probeStarBytesLabeled: 's16-s16'.
        digest := Sha256 hexDigestOf: starBytes.
        ExecFixtures populateProbeSourceIn: index
            bytes: starBytes digest: digest.
        results := OrderedCollection new.

        "1. the question that opens the session creates nothing."
        help := self resultOf: (Array with: ReadinessFixtures helpFlag)
            in: work runner: ProcessRunner new.
        results add: help.
        self assert: help exitCode = 0
            description: 'parley --help answered exit ',
                help exitCode printString.
        self assert: help lines = ExecFixtures usageLines.
        self deny: (self exists: (CommandLineFixtures parleyDirIn: work))
            description: 'the opening question created project state'.

        "2. init writes the starter manifest."
        init := self resultOf: #('init') in: work runner: ProcessRunner new.
        results add: init.
        self assert: init exitCode = 0
            description: 'parley init answered exit ',
                init exitCode printString.
        self assert: init lines = ExecFixtures initSuccessLines.
        self assert: (self contentsOf: work, '/Package.st')
            = ExecFixtures initTemplateContents
            description: 'init did not write the settled skeleton'.

        "3. the typo every first session contains."
        typo := self resultOf: (Array with: 'exec'
            with: (ReadinessFixtures missingScriptPathIn: work))
            in: work runner: RecordingRunner new.
        results add: typo.
        self assert: typo exitCode = 1
            description: 'parley exec on a typo answered exit ',
                typo exitCode printString.
        self assert: typo lines
            = (Array with: (ReadinessFixtures execRefusalLineFor:
                (ReadinessFixtures missingScriptPathIn: work)))
            description: 'the typo answered ', typo lines printString.

        "4. add declares the dependency and moves the project onto it."
        add := self resultOf: (Array
                with: 'add' with: 'parley-probe' with: '^1.0'
                with: '--source' with: index)
            in: work runner: ProcessRunner new.
        results add: add.
        self assert: add exitCode = 0
            description: 'parley add answered exit ',
                add exitCode printString, ': ', add lines printString.
        self assert: add lines = CommandLineFixtures probePinLines.

        "5. resolve rewrites the same byte-stable lock."
        resolve := self resultOf: (Array with: 'resolve' with: '--source'
            with: index) in: work runner: ProcessRunner new.
        results add: resolve.
        self assert: resolve exitCode = 0
            description: 'parley resolve answered exit ',
                resolve exitCode printString, ': ', resolve lines printString.
        self assert: (self contentsOf: work, '/parley.lock')
            = (ReadinessFixtures initSessionLockWithDigest: digest)
            description: 'the lock is not the byte-stable oracle'.

        "6. check reports a healthy project."
        check := self resultOf: (Array with: 'check' with: '--source'
            with: index) in: work runner: ProcessRunner new.
        results add: check.
        self assert: check exitCode = 0
            description: 'parley check answered exit ',
                check exitCode printString, ': ', check lines printString.

        "7. and a script that really exists really runs, against the
         environment the session just built."
        proofPath := work, '/proof.txt'.
        SourceFixtures write: (ExecFixtures proofScriptContentsFor: proofPath)
            toFile: 'good.st' in: work.
        exec := self resultOf: (Array with: 'exec' with: work, '/good.st')
            in: work runner: ProcessRunner new.
        results add: exec.
        self assert: exec exitCode = 0
            description: 'parley exec answered exit ',
                exec exitCode printString.
        self assert: (self contentsOf: proofPath) = 'present'
            description: 'the curated child cannot see the added class'.

        "Nothing on the way blamed Parley, dumped a backtrace or put a
         kernel integer on screen; the project state lives beside the
         project and nowhere else."
        results do: [:each | self denyBlamesParley: each].
        self assert: (self exists: (CommandLineFixtures parleyDirIn: work))
            description: 'the verbs created no project state at all'.
        self deny: (self exists: CommandLineFixtures cwdStoreRoot)
            description: 'the session created a store beside the process cwd'.
        self deny: (self exists: CommandLineFixtures cwdTargetDir)
            description: 'the session created a target beside the process cwd'
    ]
]

Namespace current: Smalltalk.
