"Parley Sprint 18 — the laws of the authoring diagnosis (issue #20 S4,
 S5, S6, S7, S12; Doc B §2.2, Doc E §3.1, §8 decisions 44, 62 and 43).

 TWO CLAIMS, AND THEY ARE MEASURED ON DIFFERENT INSTRUMENTS. That
 difference is the whole reason this sprint exists rather than a patch.

 THE FIRST CLAIM IS ABOUT WHAT PARLEY SAYS: every authoring diagnosis
 names the path, by being BATCHED rather than re-toned. ManifestBuilder's
 problems are the only diagnosis family in the tool that never names the
 file the author must open; they are now emitted inside the settled
 per-file batch — a header naming the path and the problem count, then
 one line per problem, EACH PROBLEM SENTENCE BYTE-IDENTICAL to its
 settled literal. A single-problem manifest answers the batch shape too:
 §8 decision 44 gives a file one shape, not two, and a bare line for N=1
 is how a shape acquires a second form nobody declared. That claim is
 measured on the CliResult, where Parley's own composition lives.

 THE SECOND CLAIM IS ABOUT WHAT REACHES THE TERMINAL AT ALL: no
 backtrace frame, no kernel class, no Parley source path. It CANNOT be
 measured on result lines, and asserting it there is precisely the defect
 this sprint exists to close — eleven lines of kernel text shipped past
 laws that deny backtraces because they assert over the CliResult's
 composed lines while that text reaches the terminal by another route
 entirely. So it is measured on CAPTURED STDOUT AND STDERR FROM THE
 SHIPPED BINARY, separately, which is §8 decision 62 extending decision
 73's bound onto a wider instrument without amending it.

 THE ORACLES ARE HAND-WRITTEN, and that is a rule rather than a habit
 (S5). The four problem sentences are typed out in
 AuthoringFixtures fourProblemProblems, read off the settled
 ManifestBuilder's source, never obtained from the composer that produced
 them: an oracle taken from the code under test proves only that the code
 equals itself.

 THE UNPARSEABLE MANIFEST IS DRIVEN ONLY THROUGH A CHILD PROCESS, and
 the reason is mechanical rather than stylistic. 3.2.5 reports a syntax
 error on stderr at C level; verify-sprint.sh captures the suite's own
 stderr and refuses any run whose output carries a parser complaint. A
 fixture filed in IN-IMAGE would therefore fail the gate in both phases
 without any law failing. It is driven through the shipped binary with
 stderr redirected to a file the test owns — which is also the only
 instrument that can see the fragment S12 asserts is still there.

 DECLARED PASS IN RED (issue #20) — one:
   testTheUnparseableManifestKeepsTheToolchainsParserLine — S12's route.
     The settled no manifest defined line already names the path, and
     the parser's own line is already on stderr, so this passes today.
     It is here because it is the law a capture implementation that
     swallowed stderr would break, and it must keep passing.
 Every other law here fails against the pre-sprint tree.

 RED CLASSIFICATION (method finding F14): every law here is a FAILURE
 rather than an ERROR — each names only settled classes, so its body
 runs, its drivers execute and its assertions are reached and are false.
 None is fronted by a missing class.

 COST, DECLARED: two laws spawn the shipped binary, one child each; every
 other law runs in-image against tmp/ fixtures. Nothing here contacts a
 network and nothing runs git."

Namespace current: Parley.

TestCase subclass: AuthoringDiagnosisTest [
    | fixtureDirs |

    <comment: 'Laws for the authoring boundary''s diagnoses: the batch
shape including N=1, byte-identity against hand-written oracles, the
no-path-free-diagnosis law over the whole authoring family, and the
marker-absence law measured on captured stdout and stderr from the
shipped binary with its bound and both kept fragments stated.'>

    setUp [
        fixtureDirs := OrderedCollection new
    ]

    tearDown [
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

    emptyIndex: aLabel [
        ^self track: (SourceFixtures directoryNamed: aLabel)
    ]

    workDir: aLabel contents: aContentsString [
        ^AuthoringFixtures workDirTracking: self tracker
            named: aLabel
            contents: aContentsString
    ]

    resolveIn: aWorkDir source: anIndexDir [
        ^(CommandLine in: aWorkDir runner: RecordingRunner new)
            run: (Array with: 'resolve' with: '--source' with: anIndexDir)
    ]

    "---- S4 and S6: the batch shape, at every problem count ----"

    testAFourProblemManifestAnswersOneBatch [
        "S4. One batch: a header naming the path and 4 problem(s), then
         the four problems, at exit 1. The count in the header is the
         count of PROBLEMS — the header is not one of the things wrong
         with the manifest."
        | work result path expected |
        work := self workDir: 'authoring-batch-four'
            contents: AuthoringFixtures fourProblemContents.
        path := AuthoringFixtures manifestPathIn: work.
        result := self resolveIn: work
            source: (self emptyIndex: 'authoring-batch-four-index').
        expected := (Array with: (AuthoringFixtures batchHeaderFor: path
            count: AuthoringFixtures fourProblemProblems size)),
                AuthoringFixtures fourProblemProblems.
        self assert: result exitCode = 1
            description: 'the four-problem manifest answered exit ',
                result exitCode printString, ': ',
                result lines printString.
        self assert: result lines = expected
            description: 'the batch answered ', result lines printString
    ]

    testASingleProblemManifestAnswersTheBatchShapeToo [
        "S6. A file gets ONE shape, not two (§8 decision 44). A bare
         line for N=1 is how a shape acquires a second form nobody
         declared — and it is the form that would leave the commonest
         single-problem manifest with no path on the screen."
        | work result path expected |
        work := self workDir: 'authoring-batch-one'
            contents: AuthoringFixtures oneProblemContents.
        path := AuthoringFixtures manifestPathIn: work.
        result := self resolveIn: work
            source: (self emptyIndex: 'authoring-batch-one-index').
        expected := (Array with: (AuthoringFixtures batchHeaderFor: path
            count: 1)), AuthoringFixtures oneProblemProblems.
        self assert: result exitCode = 1
            description: 'the one-problem manifest answered exit ',
                result exitCode printString.
        self assert: result lines = expected
            description: 'the single-problem batch answered ',
                result lines printString.
        self assert: result lines size = 2
            description: 'a one-problem batch is a header and one problem, not ',
                result lines size printString, ' lines'
    ]

    testTheHeaderNamesThePathAndTheCount [
        "The header's two obligations, asserted on the header itself
         rather than on the array around it: it OPENS WITH the path — the
         settled grammar every other file diagnosis in the tool uses —
         and it carries the problem count in the settled house spelling,
         N problem(s)."
        | work result path header |
        work := self workDir: 'authoring-header'
            contents: AuthoringFixtures fourProblemContents.
        path := AuthoringFixtures manifestPathIn: work.
        result := self resolveIn: work
            source: (self emptyIndex: 'authoring-header-index').
        self deny: result lines isEmpty
            description: 'the batch answered no lines at all'.
        header := result lines at: 1.
        self assert: (header startsWith: path, ': ')
            description: 'the header does not open with the path: ', header.
        self assert: (CommandLineFixtures does: header
            include: '4 problem(s)')
            description: 'the header does not carry the count: ', header.
        self assert: (PathFixtures pathPartOf: header) = path
            description: 'the header names ',
                (PathFixtures pathPartOf: header) printString
    ]

    "---- S5: byte-identity against hand-written oracles ----"

    testTheProblemSentencesAreByteIdenticalToHandWrittenOracles [
        "S5, and the reason the oracle is typed out rather than
         computed: the sentences are ADDED TO, never rewritten. An
         author fixes a Package.st per edit-run cycle and the four
         sentences already say the right thing about each field, so the
         path is put AROUND them.

         BOTH four-problem manifests are driven, because the four
         literals issue #20 names cannot come from one file: the settled
         builder reports a version as missing OR as invalid and never as
         both. Between them the two manifests cover all four."
        | rows |
        rows := Array
            with: (Array with: 'invalid version'
                with: AuthoringFixtures fourProblemContents
                with: AuthoringFixtures fourProblemProblems
                with: 'authoring-oracle-invalid')
            with: (Array with: 'missing version'
                with: AuthoringFixtures missingVersionContents
                with: AuthoringFixtures missingVersionProblems
                with: 'authoring-oracle-missing').
        rows do: [:row |
            | work result oracle |
            work := self workDir: (row at: 4) contents: (row at: 2).
            oracle := row at: 3.
            result := self resolveIn: work
                source: (self emptyIndex: (row at: 4), '-index').
            "The parentheses are load-bearing: = and + are both binary
             and evaluate left to right, so oracle size + 1 without them
             reads as (result lines size = oracle size) + 1 and the law
             ERRORS on false + 1 instead of failing on its own claim."
            self assert: result lines size = (oracle size + 1)
                description: (row at: 1), ' answered ',
                    result lines printString.
            1 to: oracle size do: [:i |
                self assert: (result lines at: i + 1) = (oracle at: i)
                    description: (row at: 1), ' problem ', i printString,
                        ' is ', (result lines at: i + 1) printString,
                        ' rather than ', (oracle at: i) printString].
            "The same claim from the other direction, asserted in this
             law rather than in one of its own: membership is satisfied
             by the pre-sprint bare lines, so a law of its own would
             pass in red and be an undeclared pass (finding F10). Here it
             adds what position-wise equality does not — a re-toning
             that also reordered would satisfy neither."
            oracle do: [:sentence |
                self assert: (result lines includes: sentence)
                    description: (row at: 1), ' does not carry ',
                        sentence printString, ' verbatim: ',
                        result lines printString]]
    ]

    "---- S7: no diagnosis without a path ----"

    testNoAuthoringDiagnosisReachesTheOperatorWithoutNamingAPath [
        "S7, over the whole authoring family.

         THE CLAIM IS ABOUT THE DIAGNOSIS, NOT ABOUT EVERY LINE, and the
         bound is stated rather than left to the law's silence (§8
         decision 43). A batch's problem sentences stay byte-identical
         and none of them names the file — that is the point of batching
         rather than re-toning. So what the law asserts is that the
         diagnosis a verb DELIVERS opens with the manifest path: its
         first line, in the settled grammar. What stops the rest of the
         batch from being anything at all is the byte-identity law
         above, which pins every sentence.

         The family's membership is asserted against its declared labels
         first, so a driver added or dropped fails here rather than
         quietly changing what the law quantifies over."
        | drivers |
        drivers := AuthoringFixtures familyDriversTracking: self tracker.
        self assert: (((drivers collect: [:row | row at: 1])
            asSortedCollection: [:a :b | a <= b]) asArray)
                = AuthoringFixtures familyLabels
            description: 'the family drivers and their declared labels disagree: ',
                (drivers collect: [:row | row at: 1]) printString.
        drivers do: [:row |
            | label path result first |
            label := row at: 1.
            path := row at: 2.
            result := (row at: 3) value.
            self assert: result exitCode = 1
                description: label, ' answered exit ',
                    result exitCode printString.
            self deny: result lines isEmpty
                description: label, ' answered no lines'.
            first := result lines at: 1.
            self assert: (first startsWith: path, ': ')
                description: label,
                    ' delivers a diagnosis that does not open with ',
                    path, ': ', first.
            self deny: (PathFixtures pathPartOf: first) isEmpty
                description: label, ' names no path: ', first]
    ]

    "---- S1 and the structural claim, on the instrument that can see it ----"

    testTheShippedBinaryPutsNoBacktraceOnEitherStream [
        "THE MARKER-ABSENCE LAW (§8 decision 62). Measured
         on the bytes the shipped binary really writes, never on the
         CliResult's composed lines — asserting over result lines is
         exactly what let eleven lines of kernel text, four of them
         absolute paths into Parley's own source tree, ship past laws
         that deny backtraces.

         THE BOUND IS STATED, AND SO ARE BOTH KEPT FRAGMENTS (decision
         43). This law denies AuthoringFixtures terminalMarkers and
         nothing else. Two fragments are deliberately outside that set:

           - primError's receiver prefix on STDOUT — Object: followed by
             the receiver — is a STATED BOUNDED LIMITATION. It is
             written at C level, no in-image rebinding reaches it, it
             carries no backtrace frame and no Parley source path, and
             this law passes over it BY THIS STATED BOUND rather than by
             accident. It arrives WITHOUT a trailing newline, so
             ManifestFile TERMINATES it whenever it recovers an anchor
             (§8 decision 62 as amended at the RED review) — otherwise
             the fragment fuses with the diagnosis into a third thing
             neither composed nor kept.

           - the C-level parser complaint on STDERR is DELIBERATELY
             KEPT. A raising manifest is not a syntax error, so it must
             not appear for THIS input; S12 asserts it is still present
             for the unparseable one.

         THE TWO STREAMS ARE CAPTURED AND ASSERTED SEPARATELY, IN ONE
         LAW, and both halves matter for opposite reasons: a merged
         capture cannot tell the fragment Parley KEEPS on stderr from the
         frames it must REMOVE from stdout — that confusion is how output
         capture came to be deferred as one thing — while a stderr law of
         its own would pass against the pre-sprint tree, where stderr is
         already empty for this input, and would be an undeclared pass
         (finding F10).

         What Parley itself composed is asserted here too, so a green
         that removed the diagnosis along with the dump fails rather than
         looking like a success. That half stays CONTAINMENT on purpose:
         this law's subject is marker ABSENCE, and its presence check is
         the guard that the dump was not removed by removing the
         diagnosis. The exact two-line shape the termination buys is
         S1's claim, asserted there against
         AuthoringFixtures expectedStdoutLinesFor:, and one exact oracle
         is enough — two would be the same claim in two places, which is
         how two artifacts come to disagree with nothing comparing them."
        | work index captures run text |
        work := self workDir: 'authoring-stdout'
            contents: AuthoringFixtures raisingContents.
        index := self emptyIndex: 'authoring-stdout-index'.
        captures := AuthoringFixtures captureDirTracking: self tracker
            named: 'authoring-stdout-captures'.
        run := AuthoringFixtures runShippedIn: work
            args: (AuthoringFixtures resolveArgsOn: index)
            captures: captures
            label: 'raising'.
        self assert: (run at: 1) = 1
            description: 'the shipped binary exited ',
                (run at: 1) printString.
        text := run at: 2.
        self deny: text isEmpty
            description: 'a failing command must say something'.
        AuthoringFixtures terminalMarkers do: [:marker |
            self deny: (CommandLineFixtures does: text include: marker)
                description: 'the terminal carried ', marker printString].
        self assert: (CommandLineFixtures does: text
            include: (AuthoringFixtures
                anchorLineFor: (CommandLineFixtures absolutePathOf: work),
                    '/Package.st'
                line: AuthoringFixtures raisingLineNumber))
            description: 'the captured stdout does not carry the re-voiced diagnosis'.
        "The stderr half, asserted on its own capture."
        text := run at: 3.
        AuthoringFixtures terminalMarkers do: [:marker |
            self deny: (CommandLineFixtures does: text include: marker)
                description: 'stderr carried ', marker printString].
        self deny: (AuthoringFixtures does: text
            carryTheKeptStderrFragmentFor:
                (AuthoringFixtures manifestPathIn: work))
            description: 'stderr complained about a manifest that parses'
    ]

    testTheUnparseableManifestKeepsTheToolchainsParserLine [
        "DECLARED PASS IN RED (issue #20) — S12's route, and the law a
         capture implementation that swallowed stderr would break.

         Parley cannot distinguish an unparseable Package.st from one
         that never sent define: (Doc B §2.2): on the parse path fileIn:
         returns normally, nothing is recorded and the capture is empty.
         Both therefore answer the settled no manifest defined line
         naming the path, that literal is NOT re-toned because it is
         true of both, and the information separating them is already on
         the operator's terminal — on stderr, unsuppressed, naming the
         author's file and the line. This law is what holds it there.

         It is the only law in this file that drives the unparseable
         fixture, and it drives it as a CHILD PROCESS: filed in-image,
         the parser's complaint would land in the suite's own stderr and
         verify-sprint.sh would refuse the run in either phase."
        | work index captures run |
        work := self workDir: 'authoring-unparseable'
            contents: AuthoringFixtures unparseableContents.
        index := self emptyIndex: 'authoring-unparseable-index'.
        captures := AuthoringFixtures captureDirTracking: self tracker
            named: 'authoring-unparseable-captures'.
        run := AuthoringFixtures runShippedIn: work
            args: (AuthoringFixtures resolveArgsOn: index)
            captures: captures
            label: 'unparseable'.
        self assert: (run at: 1) = 1
            description: 'the unparseable manifest exited ',
                (run at: 1) printString.
        self assert: (CommandLineFixtures does: (run at: 2)
            include: (ExecFixtures defineLessProblemFor:
                (CommandLineFixtures absolutePathOf: work), '/Package.st'))
            description: 'the settled define-less line is not on stdout'.
        self assert: (AuthoringFixtures does: (run at: 3)
            carryTheKeptStderrFragmentFor:
                (AuthoringFixtures manifestPathIn: work))
            description: 'the toolchain line naming the author''s file and line was suppressed on stderr'
    ]
]

Namespace current: Smalltalk.
