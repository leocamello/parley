"Parley Sprint 18 — acceptance scenarios S1-S14 (issue #20).

 THE SPRINT THAT GIVES THE AUTHORING BOUNDARY PARLEY'S VOICE. Package.st
 is EXECUTED, which makes this the one place in Parley where text reaches
 the user's terminal that Parley did not write. Two defects, both on the
 first session's path.

 ONE: a malformed manifest prints ELEVEN LINES OF KERNEL BACKTRACE, FOUR
 OF THEM ABSOLUTE PATHS INTO PARLEY'S OWN SOURCE TREE, above one correct
 sentence. (FOUR, re-probed at the RED review; SIX was the staging plan's
 count and had reached the issue and this suite's comments.) A user reading that concludes Parley crashed. THE TOOL'S OWN
 LAWS DENY BACKTRACES AND PASS, because they assert over the CliResult's
 composed result lines while this text reaches the terminal by another
 route entirely. That gap is why this is a sprint rather than a patch,
 and it is why S1's structural claim is measured on CAPTURED STDOUT AND
 STDERR FROM THE SHIPPED BINARY, separately, and never on result lines.

 TWO: the authoring diagnoses are the only family in the tool that never
 names the file. A four-problem manifest prints four bare lines and no
 header at all. The fix is §8 decision 44's settled shape — a header
 naming the path and the count, then the four sentences BYTE-IDENTICAL
 inside the batch. Added to, never rewritten.

 AND THE CARRIED GAP RIDES ALONG (method finding F13, §8 decision 74):
 ensureDirectory: told an operator a WRITABLE directory could not be
 written, with a remedy that cannot work, whenever a regular file sat at
 <workdir>/.parley. Same defect class — a diagnosis asserting a cause it
 never checked — and its portable half is the law, not the fix: the row
 is driven through a path's four SHAPES rather than two permission bits.

 DECLARED PASSES IN RED (issue #20) — five, each a SETTLED-BEHAVIOUR
 GUARD that passes today and must keep passing, never a new claim:
   testS2_TranscriptIsRestoredAfterANonLocalExitPastTheGateway — trivially
     true while no swap exists, and the worst failure mode in the sprint:
     a leaked swap does not fail loudly, IT SILENCES THE REST OF THE
     PROCESS, which in this suite means a run of laws asserting on output
     they can no longer see and a runner whose own sentinel vanishes.
   testS3_TranscriptIsRestoredOnTheOrdinaryFailurePath — likewise.
   testS11_AValidManifestStillLoadsAndResolves — the guard that the
     capture never becomes a gate on the path it exists to protect.
   testS12_TheUnparseableManifestKeepsItsRouteAndItsStderrLine — the
     settled no manifest defined line naming the path, and the
     toolchain's own line still on STDERR. A capture implementation that
     swallowed stderr breaks this.
   testS13_TheSettledAuthoringLiteralsAreByteIdentical — the settled
     diagnosis set is otherwise untouched.
 Every other scenario here fails against the pre-sprint tree.

 S2 AND S3 DELIBERATELY NAME NO NEW CLASS. They drive the real boundary —
 ManifestFile load: — and assert the binding afterwards, which is what
 makes them pass in red rather than abort on a missing class. The laws
 that exercise Parley.ManifestCapture directly live in
 ManifestCaptureTest and every one of them is an ERROR in red.

 ONE FIXTURE IS NEVER FILED IN INSIDE THE HARNESS. 3.2.5 reports a syntax
 error on stderr at C level and verify-sprint.sh refuses any run whose
 output carries a parser complaint, so the unparseable manifest is driven
 ONLY as a child process with stderr redirected to a capture file this
 test owns (S12). AuthoringFixtures unparseableContents says so where it
 is defined.

 COST, DECLARED: every scenario runs in-image against tmp/ fixtures
 except S1, S12 and S14's shipped half, which spawn the shipped binary
 once each. S8, S9 and S10 build hostile filesystem states with in-image
 chmod (File>>mode: is a real chmod on 3.2.5). No scenario contacts a
 network and none runs git.

 TEARDOWN GOES THROUGH PathFixtures removeTree:, WHICH UNLOCKS FIRST. A
 read-only fixture directory survives the settled recursive remover — on
 POSIX the permission to unlink an entry belongs to the containing
 directory — so it stays on disk, the next run's directoryNamed: finds it,
 and failures appear in suites this sprint never touched."

Namespace current: Parley.

TestCase subclass: Sprint18AcceptanceTest [
    | fixtureDirs previousTranscript |

    <comment: 'The Sprint 18 acceptance scenarios: the re-voiced
file-and-line diagnosis with no backtrace on either captured stream, the
unconditional restoration of the Transcript binding on both failing
paths, the batched authoring diagnosis at every problem count with its
byte-identical sentences, the no-path-free-diagnosis law, the state
root''s four path shapes, the settled behaviour held in place, and the
README.'>

    setUp [
        fixtureDirs := OrderedCollection new.
        previousTranscript := Smalltalk at: #Transcript
    ]

    tearDown [
        "The binding is restored whatever a scenario did, because a leak
         would silence every suite after this one — including the
         runner's own sentinel. It is a safety net; each scenario
         asserts restoration itself, since a net that repaired the defect
         would also hide it."
        previousTranscript isNil ifFalse: [
            Smalltalk at: #Transcript put: previousTranscript].
        fixtureDirs isNil ifTrue: [^self].
        fixtureDirs do: [:each | PathFixtures removeTree: each].
        fixtureDirs := nil
    ]

    tracker [
        ^[:path | fixtureDirs add: path. path]
    ]

    track: aPath [
        fixtureDirs add: aPath.
        ^aPath
    ]

    freshDir: aLabel [
        ^self track: (SourceFixtures directoryNamed: aLabel)
    ]

    workDir: aLabel contents: aContentsString [
        ^AuthoringFixtures workDirTracking: self tracker
            named: aLabel
            contents: aContentsString
    ]

    diamondIndex: aLabel [
        | path |
        path := self freshDir: aLabel.
        InstallFixtures populateInstallDiamondIn: path.
        ^path
    ]

    resolveIn: aWorkDir source: anIndexDir [
        ^(CommandLine in: aWorkDir runner: RecordingRunner new)
            run: (Array with: 'resolve' with: '--source' with: anIndexDir)
    ]

    manifestPathIn: aWorkDir [
        ^AuthoringFixtures manifestPathIn: aWorkDir
    ]

    absolute: aPath [
        ^CommandLineFixtures absolutePathOf: aPath
    ]

    contentsOf: aPath [
        ^PathFixtures contentsOf: aPath
    ]

    exists: aPath [
        ^PathFixtures exists: aPath
    ]

    assertTranscriptRestored: aLabel [
        self assert: (Smalltalk at: #Transcript) == previousTranscript
            description: aLabel,
                ' left Transcript bound to something else - a leaked swap does not fail loudly, it silences the rest of the process'
    ]

    denyBlamesParley: aResult [
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

    "---- S1: a raising manifest answers one line, and nothing else ----"

    testS1_ARaisingManifestAnswersOneLineNamingThePathAndTheLine [
        "THE FIRST DEFECT, driven through the shipped binary with both
         streams captured SEPARATELY — the only instrument that can see
         it, and the reason this is a scenario rather than a line to
         delete.

         Three claims. Exit 1. One Parley-composed line naming the
         manifest path AND the line number the author must open — the
         capture's own frame line carries it and the pre-sprint tool
         threw it away. And no backtrace frame and no Parley source path
         anywhere in the captured bytes.

         THE BOUND IS STATED, AND SO IS EACH KEPT FRAGMENT (§8 decisions
         43 and 62). AuthoringFixtures terminalMarkers is the whole of
         what is denied. primError's Object: prefix reaches stdout at C
         level and carries no frame and no Parley path; the parser's own
         complaint on stderr is deliberately kept and is asserted present
         for the input it belongs to, in S12.

         THE CAPTURED STDOUT IS ASSERTED EXACTLY, NOT BY CONTAINMENT
         (strengthened at the RED review; §8 decision 62 as amended).
         primError emits no trailing newline, so the kept fragment is a
         FRAGMENT rather than a line and, left alone, fuses with the
         diagnosis into a third thing neither composed nor kept.
         ManifestFile terminates it whenever it recovers an anchor, so
         the captured bytes are exactly two lines — the terminated
         fragment, then Parley's sentence — and asserting that shape is
         what makes the ruling CHECKABLE. Substring containment cannot
         tell a terminated fragment from a fused one, which is precisely
         how the fusion survived to this review."
        | work index captures run text path expected result |
        work := self workDir: 's18-1-work'
            contents: AuthoringFixtures raisingContents.
        index := self freshDir: 's18-1-index'.
        captures := AuthoringFixtures captureDirTracking: self tracker
            named: 's18-1-captures'.
        run := AuthoringFixtures runShippedIn: work
            args: (AuthoringFixtures resolveArgsOn: index)
            captures: captures
            label: 's18-1'.
        self assert: (run at: 1) = 1
            description: 'the shipped binary exited ',
                (run at: 1) printString.
        path := self absolute: (self manifestPathIn: work).
        expected := AuthoringFixtures expectedStdoutLinesFor: path.
        text := run at: 2.
        self assert: (ExecFixtures linesOf: text) = expected
            description: 'the captured stdout is ',
                (ExecFixtures linesOf: text) printString,
                ' rather than ', expected printString.
        AuthoringFixtures terminalMarkers do: [:marker |
            self deny: (CommandLineFixtures does: text include: marker)
                description: 'the captured stdout carried ',
                    marker printString.
            self deny: (CommandLineFixtures does: (run at: 3)
                include: marker)
                description: 'the captured stderr carried ',
                    marker printString].
        "The value level, so the shape of what Parley composed is pinned
         and not merely the absence of what it did not."
        result := self resolveIn: work source: index.
        self assert: result exitCode = 1.
        self assert: result lines = (Array with: (AuthoringFixtures
            anchorLineFor: (self manifestPathIn: work)
            line: AuthoringFixtures raisingLineNumber))
            description: 'the value-level diagnosis is ',
                result lines printString.
        self denyBlamesParley: result
    ]

    "---- S2: restoration on a non-local exit past the gateway ----"

    testS2_TranscriptIsRestoredAfterANonLocalExitPastTheGateway [
        "DECLARED PASS IN RED (issue #20) — trivially true while no swap
         exists, and the scenario that matters most once one does.

         The load fails by an error raised PAST the gateway's own
         handlers: ManifestFile signals its own ManifestError from its
         own frame, after the file-in has returned. Nothing but an
         ensure: can put the binding back on that path — and a leak here
         is silent. It does not fail; it makes every later law blind, and
         it takes the runner's PARLEY-VERIFY sentinel with it.

         Restoration is asserted twice: the binding is the object it was,
         and a send through it still reaches the real collector."
        | work escaped |
        work := self workDir: 's18-2-work'
            contents: AuthoringFixtures raisingContents.
        escaped := false.
        [ManifestFile load: (self manifestPathIn: work)]
            on: ManifestError
            do: [:e |
                escaped := true.
                self assertTranscriptRestored: 'a failing load, inside the handler'.
                e return: nil].
        self assert: escaped
            description: 'the failing load signaled nothing - the boundary is swallowing the authoring failure'.
        self assertTranscriptRestored: 'a failing load'.
        Transcript showCr: ''.
        self assert: (Smalltalk at: #Transcript) class
            == previousTranscript class
            description: 'a send through the restored Transcript did not reach the real collector'
    ]

    "---- S3: restoration on the ordinary failure path ----"

    testS3_TranscriptIsRestoredOnTheOrdinaryFailurePath [
        "DECLARED PASS IN RED (issue #20). The ordinary failure: a
         manifest whose declarations do not validate. The gateway
         catches, load: signals the batch, and the binding must be back
         before CommandLine composes a single line — because composing is
         printing, one frame later.

         Driven separately from S2 because the two unwind differently and
         an implementation can restore on one and leak on the other."
        | work escaped |
        work := self workDir: 's18-3-work'
            contents: AuthoringFixtures fourProblemContents.
        escaped := false.
        [ManifestFile load: (self manifestPathIn: work)]
            on: ManifestError
            do: [:e |
                escaped := true.
                self assertTranscriptRestored: 'an invalid manifest, inside the handler'.
                e return: nil].
        self assert: escaped
            description: 'the invalid manifest signaled nothing'.
        self assertTranscriptRestored: 'an invalid manifest'
    ]

    "---- S4: four problems, one batch ----"

    testS4_AFourProblemManifestAnswersOneBatchNamingThePath [
        "THE SECOND DEFECT, closed. Today: four bare lines and no header
         at all, in the only diagnosis family in the tool that never
         names the file the author must open."
        | work result path expected |
        work := self workDir: 's18-4-work'
            contents: AuthoringFixtures fourProblemContents.
        path := self manifestPathIn: work.
        result := self resolveIn: work source: (self freshDir: 's18-4-index').
        expected := (Array with: (AuthoringFixtures batchHeaderFor: path
            count: 4)), AuthoringFixtures fourProblemProblems.
        self assert: result exitCode = 1
            description: 'the four-problem manifest answered exit ',
                result exitCode printString.
        self assert: result lines = expected
            description: 'the batch answered ', result lines printString.
        self denyBlamesParley: result
    ]

    "---- S5: the sentences are byte-identical to hand-written oracles ----"

    testS5_TheProblemSentencesInsideTheBatchAreByteIdentical [
        "The sentences are ADDED TO, never rewritten: the path goes
         AROUND them. The oracle is typed out in AuthoringFixtures,
         read off the settled builder's source — never obtained from the
         composer that produced it, which would prove only that the code
         equals itself.

         Both four-problem manifests are driven, because the four
         literals issue #20 names cannot come from one file: the settled
         builder reports a version as missing OR as invalid, never both.
         Between them the two cover all four."
        | rows |
        rows := Array
            with: (Array with: 's18-5-invalid'
                with: AuthoringFixtures fourProblemContents
                with: AuthoringFixtures fourProblemProblems)
            with: (Array with: 's18-5-missing'
                with: AuthoringFixtures missingVersionContents
                with: AuthoringFixtures missingVersionProblems).
        rows do: [:row |
            | work result oracle |
            work := self workDir: (row at: 1) contents: (row at: 2).
            oracle := row at: 3.
            result := self resolveIn: work
                source: (self freshDir: (row at: 1), '-index').
            "The parentheses are load-bearing: = and + are both binary and
             evaluate left to right (see the same note in
             AuthoringDiagnosisTest)."
            self assert: result lines size = (oracle size + 1)
                description: (row at: 1), ' answered ',
                    result lines printString.
            1 to: oracle size do: [:i |
                self assert: (result lines at: i + 1) = (oracle at: i)
                    description: (row at: 1), ' problem ', i printString,
                        ' is ', (result lines at: i + 1) printString]]
    ]

    "---- S6: one problem answers the batch shape too ----"

    testS6_ASingleProblemManifestAnswersTheBatchShape [
        "A file gets ONE shape, not two (§8 decision 44). A bare line for
         N=1 is how a shape acquires a second form nobody declared — and
         it is the form that leaves the commonest single-problem
         manifest with no path on the screen."
        | work result path |
        work := self workDir: 's18-6-work'
            contents: AuthoringFixtures oneProblemContents.
        path := self manifestPathIn: work.
        result := self resolveIn: work source: (self freshDir: 's18-6-index').
        self assert: result exitCode = 1.
        self assert: result lines
            = ((Array with: (AuthoringFixtures batchHeaderFor: path
                count: 1)), AuthoringFixtures oneProblemProblems)
            description: 'the single-problem manifest answered ',
                result lines printString.
        self denyBlamesParley: result
    ]

    "---- S7: no authoring diagnosis without a path ----"

    testS7_NoAuthoringDiagnosisReachesTheOperatorWithoutAPath [
        "The law, over the whole authoring family, driven from the same
         enumeration the law suite uses so the two cannot drift apart.

         THE CLAIM IS ABOUT THE DIAGNOSIS, NOT EVERY LINE, and the bound
         is stated (§8 decision 43): a batch's problem sentences stay
         byte-identical and none of them names the file, which is the
         point of batching rather than re-toning. What is asserted is
         that the diagnosis a verb DELIVERS opens with the manifest path.
         What holds the rest of the batch in place is S5."
        | drivers |
        drivers := AuthoringFixtures familyDriversTracking: self tracker.
        self assert: (((drivers collect: [:row | row at: 1])
            asSortedCollection: [:a :b | a <= b]) asArray)
                = AuthoringFixtures familyLabels
            description: 'the family and its declared labels disagree'.
        drivers do: [:row |
            | result first |
            result := (row at: 3) value.
            self assert: result exitCode = 1
                description: (row at: 1), ' answered exit ',
                    result exitCode printString.
            self deny: result lines isEmpty
                description: (row at: 1), ' answered no lines'.
            first := result lines at: 1.
            self assert: (first startsWith: (row at: 2), ': ')
                description: (row at: 1), ' does not open with ',
                    (row at: 2), ': ', first.
            self denyBlamesParley: result]
    ]

    "---- S8: a regular file at .parley names itself ----"

    testS8_ARegularFileAtTheStateRootNamesThatPath [
        "METHOD FINDING F13, §8 DECISION 74. Today: exit 1 — so no law
         failed and Sprint 17's headline criterion held — with the line
         <workdir>: could not be written - check its permissions and try
         again about a directory test -w reports WRITABLE, and a remedy
         that cannot work. Decision 58 forbids exactly that, and it was
         broken by the newest row in the table Sprint 17 built.

         The working directory's writability is asserted FIRST, because
         it is the whole point: the pre-sprint sentence was false about a
         state nothing had checked."
        | work index parley result |
        work := self track: (CommandLineFixtures
            diamondRootWorkDirNamed: 's18-8-work').
        index := self diamondIndex: 's18-8-index'.
        parley := CommandLineFixtures parleyDirIn: work.
        SourceFixtures write: 'not a directory' toFile: '.parley' in: work.
        self assert: (PathGuard isWritableDirectory: work)
            description: 'the fixture working directory is not writable - the scenario would be the parent case'.
        result := self resolveIn: work source: index.
        self assert: result exitCode = 1
            description: 'the wrong-type state root answered exit ',
                result exitCode printString.
        self assert: result lines
            = (Array with: (StateRootFixtures wrongTypeLineFor: parley))
            description: 'the refusal answered ', result lines printString.
        self deny: (result lines includes:
            (PathFixtures unwritableLineFor: work))
            description: 'the refusal still claims the working directory could not be written'.
        self denyBlamesParley: result
    ]

    "---- S9: the same shape, one level down ----"

    testS9_ARegularFileAtThePackagesTargetNamesThatPath [
        "The second half of F13, and the reason S8 alone is not enough: a
         fix that distinguished only the first state would pass S8 and
         leave this one answering a sentence about .parley, which IS a
         writable directory here."
        | work index packages result |
        work := self track: (CommandLineFixtures
            diamondRootWorkDirNamed: 's18-9-work').
        index := self diamondIndex: 's18-9-index'.
        Directory create: (CommandLineFixtures parleyDirIn: work).
        packages := StateRootFixtures packagesPathIn: work.
        SourceFixtures write: 'not a directory' toFile: 'packages'
            in: (CommandLineFixtures parleyDirIn: work).
        self assert: (PathGuard isWritableDirectory:
            (CommandLineFixtures parleyDirIn: work))
            description: 'the fixture .parley is not a writable directory - the scenario would be a different state'.
        result := self resolveIn: work source: index.
        self assert: result exitCode = 1.
        self assert: result lines
            = (Array with: (StateRootFixtures wrongTypeLineFor: packages))
            description: 'the refusal answered ', result lines printString.
        self denyBlamesParley: result
    ]

    "---- S10: the row is driven through a path's shape-space ----"

    testS10_TheStateRootRowIsDrivenThroughFourPathShapes [
        "THE PORTABLE HALF OF F13, and the reason the fix alone would not
         have been enough. Sprint 17 made the ERROR CLASS total through
         PathGuard's broad translation and left the hostile states its
         laws drive a list of exactly two — unreadable and unwritable. A
         PATH IS NOT TWO THINGS.

         Four shapes: ABSENT (created, the verb proceeds), ALREADY A
         DIRECTORY (accepted), A REGULAR FILE (refused, naming that
         path), and A WRONG-TYPE OR UNWRITABLE PARENT (refused, naming
         the parent — Sprint 17's rule, which survives for the state it
         was written for). Each answers its own declared sentence.

         Driven from the same enumeration BoundaryTableTest uses, so the
         suite has one shape-space and not two."
        | drivers |
        drivers := StateRootFixtures shapeDriversTracking: self tracker.
        self assert: (StateRootFixtures shapesOf: drivers)
            = StateRootFixtures sortedDeclaredShapes
            description: 'the drivers and the declared shapes disagree'.
        drivers do: [:row |
            | expected result |
            expected := row at: 5.
            result := (row at: 4) value.
            expected isNil
                ifTrue: [
                    self assert: result exitCode = 0
                        description: (row at: 2),
                            ' must proceed, and answered exit ',
                            result exitCode printString, ': ',
                            result lines printString]
                ifFalse: [
                    self assert: result exitCode = 1
                        description: (row at: 2), ' answered exit ',
                            result exitCode printString.
                    self assert: result lines = (Array with: expected)
                        description: (row at: 2), ' answered ',
                            result lines printString].
            self denyBlamesParley: result]
    ]

    "---- S11: a valid manifest is untouched ----"

    testS11_AValidManifestStillLoadsAndResolves [
        "DECLARED PASS IN RED (issue #20) — the guard that the capture
         never becomes a gate on the path it exists to protect, and the
         one that proves the capture is DISCARDED on success: a manifest
         that loaded cleanly has nothing to report even if the toolchain
         muttered on the way, so nothing captured may appear in the
         verb's lines and the byte-stable lock must not move.

         STRENGTHENED BY THE OPERATOR AT THE RED REVIEW. As first
         written this law asserted all three of its claims on the
         CliResult — including 'nothing captured is printed', which
         result lines CANNOT SEE. That is this sprint's own thesis
         broken inside this sprint's own tests: result lines is exactly
         the instrument that let eleven lines of kernel text ship past
         laws denying backtraces, and the success path is the one place
         no other law captures a stream. So the success path is now
         driven through the SHIPPED BINARY with both streams captured
         separately, and both are asserted EXACTLY: one composed line on
         stdout, nothing at all on stderr.

         IT REMAINS A DECLARED PASS IN RED — probed: a dependency-free
         resolve writes exactly 47 bytes to stdout and 0 to stderr today.
         What it now forbids is a GREEN that makes the success path
         noisier than it found it. The named risk is the termination
         clause of §8 decision 62: its predicate is THE ANCHOR WAS
         FOUND, never 'the capture is non-empty' — a manifest that
         printed on its own behalf leaves a non-empty capture and NO
         dangling residue, so the weaker predicate emits a stray blank
         line here, at exit 0, where nothing else would catch it."
        | work index captures run result |
        work := self workDir: 's18-11-work'
            contents: AuthoringFixtures validContents.
        index := self freshDir: 's18-11-index'.
        result := self resolveIn: work source: index.
        self assert: result exitCode = 0
            description: 'a valid manifest answered exit ',
                result exitCode printString, ': ',
                result lines printString.
        self assert: result lines
            = (Array with: ExecFixtures noDependenciesLine)
            description: 'the successful resolve answered ',
                result lines printString.
        self assert: (self contentsOf: work, '/parley.lock')
            = ExecFixtures emptyLockString
            description: 'the byte-stable lock moved'.
        self assertTranscriptRestored: 'a successful load'.
        "The terminal, on the instrument that can see it."
        captures := AuthoringFixtures captureDirTracking: self tracker
            named: 's18-11-captures'.
        run := AuthoringFixtures runShippedIn: work
            args: (AuthoringFixtures resolveArgsOn: index)
            captures: captures
            label: 's18-11'.
        self assert: (run at: 1) = 0
            description: 'the shipped binary exited ',
                (run at: 1) printString, ' on a valid manifest'.
        self assert: (ExecFixtures linesOf: (run at: 2))
            = (Array with: ExecFixtures noDependenciesLine)
            description: 'the successful run printed ',
                (ExecFixtures linesOf: (run at: 2)) printString,
                ' rather than its one composed line'.
        self assert: (run at: 3) isEmpty
            description: 'the successful run wrote to stderr: ',
                (run at: 3) printString
    ]

    "---- S12: the unparseable manifest's route ----"

    testS12_TheUnparseableManifestKeepsItsRouteAndItsStderrLine [
        "DECLARED PASS IN RED (issue #20), and the law a capture
         implementation that swallowed stderr breaks.

         Parley cannot distinguish an unparseable Package.st from one
         that never sent define: (Doc B §2.2): on the parse path fileIn:
         returns normally, nothing is recorded and the capture is empty.
         Both answer the same settled line naming the path, that literal
         is NOT re-toned because it is true of both, and the information
         separating them is already on the operator's terminal — on
         stderr, unsuppressed, naming the author's file and line.

         Driven as a CHILD PROCESS and never in-image: 3.2.5 reports the
         syntax error on stderr at C level, verify-sprint.sh captures the
         suite's own stderr, and the red gate refuses any run whose
         output carries a parser complaint. The child's stderr goes to a
         file this test owns."
        | work index captures run |
        work := self workDir: 's18-12-work'
            contents: AuthoringFixtures unparseableContents.
        index := self freshDir: 's18-12-index'.
        captures := AuthoringFixtures captureDirTracking: self tracker
            named: 's18-12-captures'.
        run := AuthoringFixtures runShippedIn: work
            args: (AuthoringFixtures resolveArgsOn: index)
            captures: captures
            label: 's18-12'.
        self assert: (run at: 1) = 1
            description: 'the unparseable manifest exited ',
                (run at: 1) printString.
        self assert: (CommandLineFixtures does: (run at: 2)
            include: (ExecFixtures defineLessProblemFor:
                (self absolute: (self manifestPathIn: work))))
            description: 'the settled line naming the path is not on stdout'.
        self assert: (AuthoringFixtures does: (run at: 3)
            carryTheKeptStderrFragmentFor: (self manifestPathIn: work))
            description: 'the toolchain line naming the author''s file and line was suppressed'
    ]

    "---- S13: the settled diagnosis set is otherwise untouched ----"

    testS13_TheSettledAuthoringLiteralsAreByteIdentical [
        "DECLARED PASS IN RED (issue #20). The settled literals and the
         pinned fixture methods do not move by one byte: the sentences
         inside the batch, the define-less line, the missing-manifest
         line, and the vocabulary error's own message with its
         suggestion. This sprint adds a path AROUND them.

         The fixture methods are compared against hand-written text, and
         the vocabulary message against the settled reflected oracle —
         which is the one place a second copy would be wrong, because S4
         of Sprint 9 requires that message VERBATIM and a pinned copy
         would prove only that copying works."
        | defineless missing |
        defineless := ExecFixtures defineLessProblemFor: '/p/Package.st'.
        self assert: defineless
            = '/p/Package.st: no manifest defined - the file never sent Parley define:'
            description: 'the define-less literal moved: ', defineless.
        missing := CommandLineFixtures missingManifestProblemFor:
            '/p/Package.st'.
        self assert: missing
            = '/p/Package.st: missing or unreadable Package.st - run parley init to write one'
            description: 'the missing-manifest literal moved: ', missing.
        self assert: AuthoringFixtures fourProblemProblems
            = (Array
                with: 'missing required field name'
                with: 'invalid version ''nope'''
                with: 'fileIns must declare at least one file to load'
                with: 'invalid constraint ''garbage'' for dependency ''demo''')
            description: 'a settled builder sentence moved: ',
                AuthoringFixtures fourProblemProblems printString.
        self assert: (CommandLineFixtures
            does: LockBoundaryFixtures vocabularyTypoProblem
            include: LockBoundaryFixtures vocabularySuggestionText)
            description: 'the vocabulary error lost its suggestion'
    ]

    "---- S14: the README documents both, and the drift law holds ----"

    testS14_TheReadmeDocumentsTheAuthoringDiagnosticsAndBothFragments [
        "The README is guarded by a law rather than by good intentions
         (Sprint 15). What a stranger must be able to read here: that a
         broken Package.st is answered by a line naming the file and the
         line, that several problems come as one batch naming the file,
         and — because §8 decision 62 states what it cannot capture
         rather than chasing it — both fragments the toolchain writes at
         C level, the receiver prefix and the parser's own complaint.

         A stated limitation that is not written down where users read is
         not stated at all; that is decision 45's standard, and this is
         the third artifact it lands in after Doc B §2.2 and the law's
         own comment.

         THE LAW PRINTS THE LABEL AND NEVER THE MARKER, and that is
         mechanical rather than tidy: one marker is the phrase
         verify-sprint.sh greps the suite's own output for, so a failure
         description carrying it would make the gate refuse the run
         instead of reporting this law."
        | readme |
        readme := PublishLayoutFixtures readmeSource.
        AuthoringFixtures readmeMarkers do: [:row |
            self assert: (CommandLineFixtures does: readme
                include: (row at: 2))
                description: 'the README does not document ',
                    (row at: 1)]
    ]
]

Namespace current: Smalltalk.
