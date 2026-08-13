"Parley Sprint 16 — the v1.0 readiness laws (issue #18; Doc E
 §4.1/§4.2, §8 decisions 56, 57 and 58, beside the settled 31, 44, 45,
 46, 49, 52 and 55).

 NONE OF THESE IS A MISSING FEATURE. Every law below reproduces a state
 in which the shipped tool disagreed with itself, found by walking the
 product by hand before cutting the tag rather than by reading the gap
 list — two of the four were already ranked, and both rankings were
 reached by reasoning over the errors somebody could name instead of by
 probing the runtime (method finding F11, fired twice more).

 EACH FIX HAS AN OVER-NARROWING TWIN, AND THE TWIN IS A SEPARATE LAW.
 The precondition must not become a gate that inspects or judges the
 child (the pass-through guard); refusing an UNREADABLE lock must not
 become refusing every lock problem (the corrupt-lock guard) nor
 refusing an ABSENT one (the missing-lock guard, which is the one the
 obvious predicate breaks, because File>>isFile answers false for a
 path that is simply not there); one declared question flag must not
 become a valueless-flag grammar (the trailing-flag guard); and
 checking the held-pins line must not become deleting it (the
 holding-really-was-the-reason guard, on BOTH verbs). A pair that
 cannot pass together is a halt-and-ask, not a trade.

 THE TOOLCHAIN FACTS THESE LAWS REST ON WERE PROBED, NOT ASSUMED
 (3.2.5, at RED): File>>exists answers TRUE for a directory;
 File>>isFile answers false for a directory AND for an absent path;
 File>>isReadable answers false for a file whose permissions deny the
 reader; File>>contents on a directory signals a KERNEL
 SystemExceptions.WrongClass carrying a raw integer, outside every
 handler written for the declared boundary errors; and gst answers exit
 0 both for a script argument that does not exist (printing
 gst: Couldn't open file) and for one that is a directory (printing
 nothing at all).

 DECLARED PASSES IN RED (issue #18) — each is a SETTLED-BEHAVIOUR
 GUARD that passes today and must keep passing, never a new claim:
   testAScriptThatRunsStillPassesItsExitCodeThrough — §8 decision 45,
     unchanged. The guard against the precondition becoming a gate.
   testACorruptLockStillLeavesResolveAtExitZero — Doc E §4.1,
     unchanged. The guard against refusing every lock problem.
   testAnAbsentLockIsStillAbsentRatherThanUnreadable — the settled
     missing-lock line on a lockless project. The guard the naive
     readability predicate breaks first.
   testTheSettledTrailingFlagGrammarDoesNotMove and
   testTheHelpFlagWithAnArgumentIsUsage — the settled valueOf:in:
     behaviour, asserted beside the flag that could have changed it.
   testAConflictHoldingDidCauseStillBlamesHolding and
   testSelectiveUpdateStillBlamesHoldingWhenHoldingIsTheReason — the
     settled Sprint 12/13 held-pins narration, restated here beside
     their twins so the pair has to move together.
   testTheHeldPinsLineHasOneDefinitionSharedByBothVerbs — the settled
     Sprint 13 shared-diagnosis precedent. Both verbs already answer
     one wording; what this sprint changes is WHEN either is entitled
     to say it, and a change made at two sites is exactly how a shared
     sentence drifts apart. The law exists to fail if it does.
 Every other law fails against the pre-sprint tree.

 Every fixture path is under tmp/, unique per test, removed recursively
 in tearDown; the developer image is never mutated; NOTHING in this
 file spawns (every runner is a RecordingRunner or a TrapRunner) and no
 network is contacted."

Namespace current: Parley.

TestCase subclass: ReadinessTest [
    | fixtureDirs |

    <comment: 'Laws for the four readiness fixes: the exec script
precondition with its no-spawn assertion and pass-through guard, the
lock readability check with its corrupt-lock and absent-lock guards and
its all-verbs sameness law, the question flags with the settled
trailing-flag grammar held unchanged and no usage error creating
project state, and the checked held-pins line on both add and
update <pkg> with its over-narrowing guard on each.'>

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

    heldConflictIndex: aLabel [
        | path |
        path := self freshDir: aLabel.
        SelectiveUpdateFixtures populateHeldConflictIndexIn: path.
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

    lockIn: aWorkDir [
        ^self contentsOf: (ReadinessFixtures lockPathIn: aWorkDir)
    ]

    snapshotOf: anIndexDir [
        ^(DirectorySource on: anIndexDir) snapshot
    ]

    denyBlamesParley: aResult [
        "No readiness diagnosis blames Parley, dumps a backtrace, or
         puts a kernel class name on the operator's screen — which is
         precisely what the shipped lock defect did."
        self deny: aResult exitCode = 70
            description: 'the diagnosis answered exit 70: ',
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

    "---- the exec script precondition (§8 decision 56) ----"

    testAMissingScriptIsRefusedAndNothingIsSpawned [
        "exit 1, ONE line naming the path, and the runner never asked
         to run anything — because 'it exited 1' is satisfied equally
         well by a spawn that happened to fail, and the claim here is
         that Parley decided before the process seam was reached."
        | work runner script result |
        work := self freshDir: 'ready-exec-missing'.
        script := ReadinessFixtures missingScriptPathIn: work.
        self deny: (self exists: script)
            description: 'the missing-script fixture exists'.
        runner := RecordingRunner new.
        result := self resultOf: (Array with: 'exec' with: script)
            in: work runner: runner.
        self assert: result exitCode = 1
            description: 'a missing script answered exit ',
                result exitCode printString.
        self assert: result lines
            = (Array with: (ReadinessFixtures execRefusalLineFor: script))
            description: 'the refusal answered ', result lines printString.
        self assert: runner commands = #()
            description: 'the refusal spawned ', runner commands printString.
        self denyBlamesParley: result
    ]

    testADirectoryScriptIsRefusedAndNothingIsSpawned [
        "The worse of the two shipped shapes: a directory EXISTS, so
         every check written against existence passed it through, and
         the child answered exit 0 in complete silence."
        | work runner script result |
        work := self freshDir: 'ready-exec-dir'.
        script := ReadinessFixtures makeDirectoryScriptIn: work.
        self assert: (self exists: script)
            description: 'the directory fixture was not created'.
        runner := RecordingRunner new.
        result := self resultOf: (Array with: 'exec' with: script)
            in: work runner: runner.
        self assert: result exitCode = 1
            description: 'a directory script answered exit ',
                result exitCode printString.
        self assert: result lines
            = (Array with: (ReadinessFixtures execRefusalLineFor: script)).
        self assert: runner commands = #()
            description: 'the refusal spawned ', runner commands printString.
        self denyBlamesParley: result
    ]

    testAScriptThatRunsStillPassesItsExitCodeThrough [
        "DECLARED PASS IN RED (issue #18) — §8 decision 45, unchanged,
         and the guard that the precondition did not become a gate that
         inspects, wraps or judges the child. The script EXISTS, so the
         precondition has nothing to say; the runner's code comes back
         untouched, the CLI contributes no lines of its own, and the
         pinned child command is composed exactly as it always was."
        | work runner script result |
        work := self freshDir: 'ready-exec-passthrough'.
        script := ReadinessFixtures writeQuitThreeScriptIn: work.
        self assert: (self exists: script)
            description: 'the pass-through fixture was not written'.
        runner := RecordingRunner answering: 7.
        result := self resultOf: (Array with: 'exec' with: script)
            in: work runner: runner.
        self assert: result exitCode = 7
            description: 'the child code did not pass through: ',
                result exitCode printString.
        self assert: result lines = #()
            description: 'exec contributed lines of its own: ',
                result lines printString.
        self assert: runner commands size = 1
            description: 'the child was not composed once: ',
                runner commands printString.
        self assert: (CommandLineFixtures does: (runner commands at: 1)
            include: script)
            description: 'the composed command does not name the script'
    ]

    "---- the lock readability check (§8 decision 56) ----"

    testEveryLockReadingVerbAnswersTheOneIdenticalLine [
        "ONE defect, ONE sentence, wherever it is met. This is a SHARED
         change — the boundary is read through by six settled verbs —
         so the law that matters is sameness, not any one verb's
         answer. Each verb runs against its own copy of the state,
         because a verb that repaired the lock would make the next one
         pass for the wrong reason."
        | index argvs expected |
        index := self toolsIndex: 'ready-lock-verbs-index'.
        argvs := (Array
            with: (Array with: 'check' with: '--source' with: index)
            with: (Array with: 'tree' with: '--source' with: index)
            with: (Array with: 'why' with: 'tool-a' with: '--source'
                with: index)
            with: (Array with: 'install' with: '--source' with: index))
            , (Array with: (Array with: 'update' with: 'tool-a'
                    with: '--source' with: index)
                with: (Array with: 'add' with: 'tool-x' with: '^1.0'
                    with: '--source' with: index)).
        expected := OrderedCollection new.
        argvs doWithIndex: [:argv :i |
            | work result |
            work := self track: (ReadinessFixtures
                unreadableLockWorkDirNamed: 'ready-lock-verb-',
                    i printString).
            result := self resultOf: argv in: work.
            self assert: result exitCode = 1
                description: argv printString, ' answered exit ',
                    result exitCode printString, ': ',
                    result lines printString.
            self assert: result lines size = 1
                description: argv printString, ' answered ',
                    result lines printString.
            self assert: result lines
                = (Array with: (ReadinessFixtures unreadableLockProblemFor:
                    (ReadinessFixtures lockPathIn: work)))
                description: argv printString, ' answered ',
                    result lines printString.
            self denyBlamesParley: result.
            expected add: (result lines at: 1)].
        self assert: expected size = argvs size
            description: 'not every verb was exercised'
    ]

    testResolveRefusesAnUnreadableLockRatherThanAnsweringZero [
        "resolve ignores a CORRUPT lock because it is about to
         overwrite it. It cannot overwrite a directory, so answering 0
         would claim a lock it did not write — the fail-wrong this
         whole boundary exists to prevent. And it cannot rely on
         seedNames to surface the defect: that catch names LockError by
         construction and defers to the boundary, so resolve owes its
         own check (the Sprint 14 add shape — a settled caller whose
         meaning changes without a line of its code changing)."
        | index work result |
        index := self toolsIndex: 'ready-lock-resolve-index'.
        work := self track: (ReadinessFixtures
            unreadableLockWorkDirNamed: 'ready-lock-resolve-work').
        result := self resultOf: (Array with: 'resolve' with: '--source'
            with: index) in: work.
        self assert: result exitCode = 1
            description: 'resolve answered exit ',
                result exitCode printString, ': ', result lines printString.
        self assert: result lines
            = (Array with: (ReadinessFixtures unreadableLockProblemFor:
                (ReadinessFixtures lockPathIn: work))).
        self denyBlamesParley: result
    ]

    testPlainUpdateRefusesAnUnreadableLockItCannotRewrite [
        "update never READS the lock, which is why a corrupt one leaves
         it alone. It does WRITE one, and that write cannot succeed
         against a directory either — so decision 56's every verb
         includes this one, for exactly the reason it includes resolve."
        | index work result |
        index := self toolsIndex: 'ready-lock-update-index'.
        work := self track: (ReadinessFixtures
            unreadableLockWorkDirNamed: 'ready-lock-update-work').
        result := self resultOf: (Array with: 'update' with: '--source'
            with: index) in: work.
        self assert: result exitCode = 1
            description: 'plain update answered exit ',
                result exitCode printString, ': ', result lines printString.
        self assert: result lines
            = (Array with: (ReadinessFixtures unreadableLockProblemFor:
                (ReadinessFixtures lockPathIn: work))).
        self denyBlamesParley: result
    ]

    testACorruptLockStillLeavesResolveAtExitZero [
        "DECLARED PASS IN RED (issue #18) — the settled Doc E §4.1
         behaviour, and the guard that stops the readability check from
         being implemented as refuse every lock problem. A readable but
         unparseable lock is IGNORED by resolve, which rewrites it; the
         assertion is on the artifact, because exit 0 alone would also
         be answered by a verb that left the corruption in place."
        | index work result |
        index := self toolsIndex: 'ready-lock-corrupt-index'.
        work := self track: (ReadinessFixtures
            corruptLockWorkDirNamed: 'ready-lock-corrupt-work').
        result := self resultOf: (Array with: 'resolve' with: '--source'
            with: index) in: work.
        self assert: result exitCode = 0
            description: 'resolve no longer ignores a corrupt lock: ',
                result lines printString.
        self assert: (self lockIn: work)
            = ReadinessFixtures toolAResolvedLockString
            description: 'resolve did not rewrite the corrupt lock'
    ]

    testAnAbsentLockIsStillAbsentRatherThanUnreadable [
        "DECLARED PASS IN RED (issue #18) — and the guard the obvious
         predicate breaks FIRST. 3.2.5's File>>isFile answers false for
         a path that is simply not there just as it does for a
         directory, so a readability check written as one predicate
         turns every lockless project into a lock defect. Absence has a
         settled diagnosis of its own, and it names resolve — the verb
         that writes a FIRST lock — not update."
        | index work |
        index := self toolsIndex: 'ready-lock-absent-index'.
        #('check' 'tree') do: [:verb |
            | work2 result |
            work2 := self track: (ReadinessFixtures
                toolAWorkDirNamed: 'ready-lock-absent-', verb).
            self deny: (self exists: (ReadinessFixtures lockPathIn: work2))
                description: 'the lockless fixture has a lock'.
            result := self resultOf: (Array with: verb with: '--source'
                with: index) in: work2.
            self assert: result exitCode = 1
                description: verb, ' answered exit ',
                    result exitCode printString.
            self assert: result lines
                = (Array with: InspectionFixtures missingLockLine)
                description: verb, ' answered ', result lines printString].
        work := self track: (ReadinessFixtures
            toolAWorkDirNamed: 'ready-lock-absent-resolve').
        self assert: (self resultOf: (Array with: 'resolve'
            with: '--source' with: index) in: work) exitCode = 0
            description: 'resolve on a lockless project no longer succeeds'
    ]

    "---- the question flags (§8 decision 57) ----"

    testEveryHelpSpellingAnswersTheUsageLinesAtExitZero [
        "Asking a tool how to use it is not an error. The three
         spellings are ONE question: a user who guesses any of them has
         asked the same thing, so they are asserted against EACH OTHER
         rather than against three literals."
        | work first |
        work := self freshDir: 'ready-help-spellings'.
        first := nil.
        ReadinessFixtures helpSpellings do: [:spelling |
            | result |
            result := self resultOf: (Array with: spelling)
                in: work runner: TrapRunner new.
            self assert: result exitCode = 0
                description: spelling, ' answered exit ',
                    result exitCode printString.
            first isNil
                ifTrue: [first := result lines]
                ifFalse: [
                    self assert: result lines = first
                        description: spelling,
                            ' answered different lines: ',
                            result lines printString]].
        self assert: first = ExecFixtures usageLines
            description: 'the question flags answered ', first printString
    ]

    testTheUsageLinesDidNotMove [
        "STRENGTHENED AT SPRINT 20's RED, never deleted and never
         weakened (issue #22, §8 decisions 79 and 81).

         It asserted `help lines = usage lines`, and under decision 79
         that claim GOES FALSE: a usage error now names what was wrong
         on line one, while --help is a question and has nothing to
         apologise for. The relationship the equality was really
         protecting survives and is now stated directly - the usage
         error's TAIL IS EXACTLY THE HELP BLOCK, and its first line is
         the reason - which pins the shared text AND the added line in
         one assertion where the old form pinned only equality.

         It locates the block by its START rather than by an offset, so
         a further line arriving above it fails here loudly instead of
         silently changing what this law is about."
        | work help usage tail |
        work := self freshDir: 'ready-help-samelines'.
        help := self resultOf: (Array with: ReadinessFixtures helpFlag)
            in: work runner: TrapRunner new.
        usage := self resultOf: #() in: work runner: TrapRunner new.
        self assert: help exitCode = 0.
        self assert: usage exitCode = 2.
        self assert: usage lines size = (help lines size + 1)
            description: 'the usage answer is ', usage lines size printString,
                ' lines beside a block of ', help lines size printString.
        tail := usage lines copyFrom: 2 to: usage lines size.
        self assert: tail = help lines
            description: 'the usage answer''s tail is not the help block: ',
                tail printString.
        self assert: usage lines first = GrammarFixtures noVerbReason
            description: 'the usage answer opens with ',
                usage lines first printString
    ]

    testTheHelpFlagSurvivesTheLeadingMarker [
        "bin/parley execs gst -f <main> -- <argv>, so the argv really
         does arrive with a leading marker. The special case is
         recognized after the settled strip and nowhere else."
        | result |
        result := self resultOf: (Array with: '--'
            with: ReadinessFixtures helpFlag)
            in: (self freshDir: 'ready-help-marker')
            runner: TrapRunner new.
        self assert: result exitCode = 0.
        self assert: result lines = ExecFixtures usageLines
    ]

    testTheHelpFlagCreatesNoStateDirectories [
        "Asking a tool how to use it is not running a command in a
         project: it needs no working directory, and a .parley/ created
         by a question is state created by a question. The same law
         --version already carries, and the reason both are recognized
         before createStateDirectories."
        | work |
        work := self freshDir: 'ready-help-nostate'.
        ReadinessFixtures helpSpellings do: [:spelling |
            self assert: (self resultOf: (Array with: spelling)
                in: work runner: TrapRunner new) exitCode = 0.
            self deny: (self exists:
                (CommandLineFixtures parleyDirIn: work))
                description: spelling, ' created the .parley state directory']
    ]

    testTheHelpFlagWithAnArgumentIsUsage [
        "DECLARED PASS IN RED (issue #18). ONE declared shape and one
         only: the whole argv is the flag and nothing else. Anything
         longer travels on to the settled CLI as the unknown shape it
         is — the --version precedent, held to a second flag."
        self assert: (self resultOf: (Array with: ReadinessFixtures helpFlag
            with: 'extra')
            in: (self freshDir: 'ready-help-extra')
            runner: TrapRunner new) exitCode = 2
    ]

    testTheSettledTrailingFlagGrammarDoesNotMove [
        "DECLARED PASS IN RED (issue #18) — THE LAW THAT MAKES --help A
         SPECIAL CASE RATHER THAN A GRAMMAR. valueOf:in: treats a
         TRAILING flag as not a flag, so it travels to the CLI, which
         answers usage. If valueless flags became grammar these would
         keep passing and would silently be about something else, so
         they are asserted here beside the flag that could have changed
         them."
        | work |
        work := self freshDir: 'ready-help-trailing'.
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

    testNoUsageErrorCreatesProjectState [
        "A command that refuses to run leaves the filesystem as it
         found it — the rule publish already follows when it declines
         to create a destination it refuses, and the rule every other
         refusal in Doc E follows. Each argv gets its own EMPTY
         directory, because the claim is about what the run created and
         not about what was there.

         THE PRE-DECLARED DOUBLE FLIP (§8 decision 83). resolve left the
         driven list: a bare resolve is no longer a usage error, so it
         is no longer a case this law can be about. The CLAIM is
         unchanged and survives over the argvs that still ARE usage
         errors — it says nothing weaker about them than it did.

         THE SECOND HALF IS WHY THIS IS A FLIP AND NOT A DELETION, and
         it is the guard that stops resolve being quietly re-acquired
         by a later reader who sees a two-element list and assumes an
         omission. A flagless resolve over an INDEX-NEEDING manifest
         refuses at exit 1 — and it creates the state directory on the
         way, DELIBERATELY, because it is a verb that ran and read the
         manifest rather than a grammar that intercepted the argv.
         resolve is the declared refuses-after-state member; asserting
         its state as absent would assert the opposite of the ruling."
        | work moved |
        ReadinessFixtures stateCreatingUsageArgvs doWithIndex: [:argv :i |
            | result |
            work := self freshDir: 'ready-nostate-', i printString.
            result := self resultOf: argv in: work runner: TrapRunner new.
            self assert: result exitCode = 2
                description: argv printString, ' answered exit ',
                    result exitCode printString.
            self deny: (self exists:
                (CommandLineFixtures parleyDirIn: work))
                description: argv printString,
                    ' created the .parley state directory'].
        work := self freshDir: 'ready-nostate-moved'.
        ExecFixtures writePackage: PathDepFixtures indexNeedingRootContents
            in: work.
        moved := self resultOf: PathDepFixtures flaglessResolveArgv
            in: work runner: TrapRunner new.
        self assert: moved exitCode = 1
            description: 'a flagless resolve answered exit ',
                moved exitCode printString, ': ', moved lines printString.
        self assert: moved lines = (Array with: (PathDepFixtures
            needsIndexRefusalFor: (Array with:
                PathDepFixtures indexNeedingName)))
            description: 'a flagless resolve answered ', moved lines printString.
        self assert: (self exists: (CommandLineFixtures parleyDirIn: work))
            description: 'the refuses-after-state member created no state'
    ]

    "---- the checked held-pins line (§8 decision 58) ----"

    addAbsentPackageIn: aWorkDir source: anIndexDir [
        ^self resultOf: (Array
                with: 'add' with: ReadinessFixtures absentPackageName
                with: ReadinessFixtures absentPackageConstraint
                with: '--source' with: anIndexDir)
            in: aWorkDir
    ]

    testAConflictHoldingDidNotCauseDoesNotBlameHolding [
        "A diagnosis that names a cause has MADE A CLAIM, and this tool
         only makes claims it has checked. The commonest way to reach
         this path is a typo'd package name, where holding is
         irrelevant and parley update cannot help — and the shipped
         tool led with it, putting the real cause on line 2.

         The guard that stops the fixture from proving nothing: the
         UNHELD resolution must fail too, or holding really would have
         been the reason."
        | work index held outcome unheld result |
        work := self track: (ManifestEditFixtures
            toolBWorkDirNamed: 'ready-held-absent-work').
        index := self toolsIndex: 'ready-held-absent-index'.
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
        result := self addAbsentPackageIn: work source: index.
        self assert: result exitCode = 1
            description: 'the add answered exit ', result exitCode printString.
        self deny: (result lines includes: ReadinessFixtures heldPinsLine)
            description: 'the held-pins line was asserted unchecked: ',
                result lines printString.
        self assert: result lines
            = (ExecFixtures linesOf: outcome printString)
            description: 'the narration is not the resolver own value: ',
                result lines printString.
        self denyBlamesParley: result
    ]

    testAConflictHoldingDidCauseStillBlamesHolding [
        "DECLARED PASS IN RED (issue #18) — the settled Sprint 13
         behaviour, restated beside its twin so the pair has to move
         together. The obvious implementation of the law above is to
         delete the line; this is what makes that a failure rather than
         a simplification. The guard: the UNHELD resolution must
         SUCCEED, which is exactly what makes holding the reason."
        | work index held outcome unheld result |
        work := self track: (ManifestEditFixtures
            heldConflictWorkDirNamed: 'ready-held-cause-work').
        index := self heldConflictIndex: 'ready-held-cause-index'.
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
        self assert: result lines
            = ((Array with: ReadinessFixtures heldPinsLine),
                (ExecFixtures linesOf: outcome printString))
            description: 'the checked line was dropped: ',
                result lines printString
    ]

    testSelectiveUpdateDoesNotBlameHoldingForAnUnsatisfiableConstraint [
        "One rule, both verbs — the Sprint 13 precedent that a shared
         diagnosis must not drift apart. tool-b is really pinned and
         really held, so the verb really does narrow the world; the
         constraint is satisfied by no release of tool-b at all, so
         holding was never the reason."
        | work index held outcome unheld result |
        work := self track: (ReadinessFixtures
            unsatisfiableToolsWorkDirNamed: 'ready-held-update-work').
        index := self toolsIndex: 'ready-held-update-index'.
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
            = (ExecFixtures linesOf: outcome printString).
        self denyBlamesParley: result
    ]

    testSelectiveUpdateStillBlamesHoldingWhenHoldingIsTheReason [
        "DECLARED PASS IN RED (issue #18) — the settled Sprint 12
         behaviour, restated beside its twin for the same reason as the
         add pair: the two must move together or one of them has been
         over-narrowed."
        | work index held outcome result |
        work := self track: (SelectiveUpdateFixtures
            heldConflictWorkDirNamed: 'ready-held-selheld-work').
        index := self heldConflictIndex: 'ready-held-selheld-index'.
        held := SelectiveUpdateFixtures heldVersionsIn: work
            except: 'app-x'.
        outcome := ResolverFixtures
            resolve: SelectiveUpdateFixtures heldConflictRootManifest
            against: ((self snapshotOf: index) holding: held).
        self deny: outcome isResolution
            description: 'the fixture does not conflict under holding'.
        result := self resultOf: (Array with: 'update' with: 'app-x'
            with: '--source' with: index) in: work.
        self assert: result exitCode = 1.
        self assert: result lines
            = ((Array with: SelectiveUpdateFixtures heldPinsLine),
                (ExecFixtures linesOf: outcome printString))
            description: 'the checked line was dropped: ',
                result lines printString
    ]

    testTheHeldPinsLineHasOneDefinitionSharedByBothVerbs [
        "The Sprint 13 precedent, asserted rather than trusted: one
         shared diagnosis serving two verbs, and a wording that drifts
         apart between them is exactly the defect that precedent exists
         to prevent. Both lines are read off the RUNNING verbs and
         compared with each other."
        | addWork updateWork index addResult updateResult |
        index := self heldConflictIndex: 'ready-held-shared-index'.
        addWork := self track: (ManifestEditFixtures
            heldConflictWorkDirNamed: 'ready-held-shared-add').
        updateWork := self track: (SelectiveUpdateFixtures
            heldConflictWorkDirNamed: 'ready-held-shared-update').
        addResult := self resultOf: (Array
                with: 'add' with: 'app-x' with: '^1.0'
                with: '--source' with: index)
            in: addWork.
        updateResult := self resultOf: (Array with: 'update' with: 'app-x'
            with: '--source' with: index) in: updateWork.
        self assert: addResult exitCode = 1.
        self assert: updateResult exitCode = 1.
        self assert: (addResult lines at: 1) = (updateResult lines at: 1)
            description: 'the two verbs answer different held-pins lines: ',
                (addResult lines at: 1) printString, ' vs ',
                (updateResult lines at: 1) printString.
        self assert: (addResult lines at: 1)
            = ReadinessFixtures heldPinsLine
            description: 'the shared line is not the settled wording'
    ]

    "---- the README, under the settled Sprint 15 drift law ----"

    testTheReadmeDocumentsTheExecPrecondition [
        "The precondition and §8 decision 45's consumer constraint are
         neighbours and are easy to confuse, so the README must carry
         BOTH: Parley refuses a script that is not there, and Parley
         still makes no claim about a script that ran."
        | readme |
        readme := PublishLayoutFixtures readmeSource.
        ReadinessFixtures execPreconditionMarkers do: [:marker |
            self assert: (CommandLineFixtures does: readme include: marker)
                description: 'the README does not document ',
                    marker printString].
        PublishLayoutFixtures execConstraintMarkers do: [:marker |
            self assert: (CommandLineFixtures does: readme include: marker)
                description: 'the README dropped the settled exec constraint marker: ',
                    marker printString]
    ]

    testTheReadmeDocumentsEveryHelpSpelling [
        "--help appears wherever --version does, in all three
         spellings, because a user who guesses one of them has asked
         the same question and the README is where they check."
        | readme |
        readme := PublishLayoutFixtures readmeSource.
        ReadinessFixtures helpDocumentationMarkers do: [:marker |
            self assert: (CommandLineFixtures does: readme include: marker)
                description: 'the README does not document ',
                    marker printString]
    ]
]

Namespace current: Smalltalk.
