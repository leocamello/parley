"Parley Sprint 9 — the two blame boundaries (issue #11; Doc E §3,
 §4.1 and §5).

 Sprint 8 made the binary tell the truth about WHETHER it failed. These
 laws make it tell the truth about WHOSE FAULT it was. Nothing here
 changes what a message says — the settled reader's positioned parse
 error and the settled ManifestVocabularyError's suggestion are both
 already perfect diagnoses. What changes is who is blamed for them:
 both are the operator's own file, and both were answered with exit 70,
 'this is a defect in Parley, not in your project'.

 THE LOCK BOUNDARY (Doc E §4.1). parley.lock is read on the install
 fast path. A lockfile that does not parse, or that parses but is not a
 #'parley-lock' 1 artifact, is one LockError naming the lock path, the
 reader's OWN message and the repair. The reader's message names a
 character position; on a hand-edited file that position is the
 operator's only handle, so it travels verbatim. The repair named is
 parley update, and it is true by construction rather than by
 assertion: update is the one verb that never reads the lock, which
 testUpdateNeverReadsTheLockAndRepairsIt proves directly.

 THE AUTHORING BOUNDARY (Doc E §3). A Package.st sending a selector
 outside the manifest vocabulary is the author's typo, and the
 vocabulary error already says so beautifully. It becomes one
 ManifestError problem carrying that message UNCHANGED — reclassified,
 never rewritten.

 DECLARED PASSES IN RED (issue #11), four of them:
   testTheVocabularyDiagnosisKeepsItsSuggestion — a fixture-correctness
     guard, not a behaviour law: it asserts that the vocabulary error
     the oracle SIGNALS really does carry the suggestion S4 names, so
     the identity law above cannot pass against an oracle that lost it.
     It needs no new behaviour and must run from the first day, exactly
     as the Sprint 8 undiagnosed-list guard does.
   testUpdateNeverReadsTheLockAndRepairsIt — update already ignores the
     lock; the law's job is to keep it that way, because the lock
     diagnosis's advice would otherwise become a lie. It must run from
     the first day the advice exists.
   testResolveIsUnaffectedByACorruptLock — same ground for resolve,
     which also never reads a lock.
   testAValidLockIsStillTheFastPath — the guard that the new boundary
     is not over-eager: a good lock must keep working exactly as it
     did.

 THE WIDENED ARM (§8 decision 34, ruled at the RED review). The
 authoring boundary covers the builder's own batched ManifestError as
 well as the vocabulary error, because the probe showed the untreated
 case is worse than reported: version: 'banana' printed a backtrace and
 then told the author their file never sent define: — a provable lie
 about a file that did. The batch is re-signaled INTACT: an author
 fixes a Package.st per edit-run cycle, not per error.

 Every fixture path is under tmp/, unique per test, removed recursively
 in tearDown; the developer image is never mutated and no network is
 contacted. Exactly ONE law here spawns —
 testAnInvalidDeclarationNeverDumpsThroughTheShippedBinary, through
 ProcessRunner, because gst's own dump reaches a TERMINAL and no
 value-level law can see one. Every other runner in this file is a
 double."

Namespace current: Parley.

TestCase subclass: LockBoundaryTest [
    | fixtureDirs |

    <comment: 'Laws for the lock-validation boundary in
CLI>>pinnedResolution and the authoring-error boundary in
ManifestFile load:: a corrupt parley.lock and a vocabulary typo are
each the operator''s diagnosis at exit 1, never a defect in Parley at
exit 70.'>

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

    diamondWorkDir: aLabel [
        ^self track: (CommandLineFixtures diamondRootWorkDirNamed: aLabel)
    ]

    typoWorkDir: aLabel [
        ^self track: (LockBoundaryFixtures vocabularyTypoWorkDirNamed: aLabel)
    ]

    contentsOf: aPath [
        ^(File name: aPath) contents
    ]

    lockPathIn: aWorkDir [
        ^aWorkDir, '/parley.lock'
    ]

    cliIn: aWorkDir source: aSource [
        "The settled CLI over doubles — the level at which the LockError
         object itself is observable, before the boundary turns it into
         lines."
        ^CLI
            in: aWorkDir
            source: aSource
            store: (ContentStore on: (CommandLineFixtures storeRootIn: aWorkDir))
            target: (CommandLineFixtures targetDirIn: aWorkDir)
            runner: RecordingRunner new
    ]

    installProblemsFrom: aBlock [
        "Run aBlock, require it to signal a LockError, and answer its
         problems."
        [aBlock value.
         self assert: false description: 'expected a LockError']
            on: Error
            do: [:e |
                self assert: (e isKindOf: LockError)
                    description: 'expected a LockError, got ', e class name.
                ^e problems].
        ^#()
    ]

    lockErrorFrom: aBlock [
        [aBlock value.
         self assert: false description: 'expected a LockError']
            on: Error
            do: [:e | ^e].
        ^nil
    ]

    resultOf: anArgvArray in: aWorkDir [
        "Through the composition root, where the diagnosis becomes an
         exit code — a lock problem must be exit 1, never 70."
        ^(CommandLine in: aWorkDir runner: RecordingRunner new)
            run: anArgvArray
    ]

    denyBlamesParley: aResult [
        "No line of a diagnosis ever opens with the exit-70 shape, and
         no line is ever a 3.2.5 dump."
        self deny: aResult exitCode = 70.
        aResult lines do: [:line |
            self deny: (CommandLineFixtures does: line
                include: LockBoundaryFixtures undiagnosedLinePrefix)
                description: 'the diagnosis blames Parley: ', line.
            CommandLineFixtures backtraceMarkers do: [:marker |
                self deny: (CommandLineFixtures does: line include: marker)
                    description: 'the diagnosis dumped a backtrace: ', line]]
    ]

    "---- the lock boundary: the LockError object itself ----"

    testAnUnparseableLockSignalsOneLockError [
        | work index problems |
        work := self diamondWorkDir: 'lock-unparseable-work'.
        index := self freshDir: 'lock-unparseable-index'.
        LockBoundaryFixtures
            writeLockContents: LockBoundaryFixtures unparseableLockContents
            in: work.
        problems := self installProblemsFrom: [
            (self cliIn: work source: (DirectorySource on: index))
                run: #('install')].
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = (LockBoundaryFixtures unparseableLockProblemFor:
                (self lockPathIn: work))
    ]

    testAWrongTagLockSignalsOneLockError [
        "It parses — the settled reader owns both schemas and accepts a
         #'parley-index' artifact happily. parley.lock is simply not
         where an index entry belongs, and only the boundary can say so."
        | work index problems |
        work := self diamondWorkDir: 'lock-wrongtag-work'.
        index := self freshDir: 'lock-wrongtag-index'.
        LockBoundaryFixtures
            writeLockContents: LockBoundaryFixtures wrongTagLockContents
            in: work.
        problems := self installProblemsFrom: [
            (self cliIn: work source: (DirectorySource on: index))
                run: #('install')].
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = (LockBoundaryFixtures wrongTagLockProblemFor:
                (self lockPathIn: work))
    ]

    testAnUnsupportedLockFormatVersionSignalsOneLockError [
        "The reader's forward-evolution point, reached through the lock:
         IndexEntryFormatError is the other half of the boundary, and it
         must be diagnosed exactly as the parse error is."
        | work index problems |
        work := self diamondWorkDir: 'lock-version-work'.
        index := self freshDir: 'lock-version-index'.
        LockBoundaryFixtures
            writeLockContents:
                LockBoundaryFixtures unsupportedVersionLockContents
            in: work.
        problems := self installProblemsFrom: [
            (self cliIn: work source: (DirectorySource on: index))
                run: #('install')].
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = (LockBoundaryFixtures unsupportedVersionLockProblemFor:
                (self lockPathIn: work))
    ]

    testAMalformedBodyLockIsTheThirdRejectionGround [
        "Sprint 10 (issue #12; Doc E §4.1, §8 decision 35). The two
         grounds above are SYNTACTIC; this file passes both — right tag,
         right format version — and has no #packages. It used to reach
         Resolution fromLockEntry: and die there as a KERNEL
         SystemExceptions.NotFound at exit 70: the same sentence, on the
         same file, that this boundary exists to abolish. The law lives
         here because the claim belongs to this class: one LockError,
         one problem, the settled three-part shape."
        | work index problems |
        work := self diamondWorkDir: 'lock-body-work'.
        index := self freshDir: 'lock-body-index'.
        LockSchemaFixtures
            writeLockContents: LockSchemaFixtures malformedBodyLockContents
            in: work.
        problems := self installProblemsFrom: [
            (self cliIn: work source: (DirectorySource on: index))
                run: #('install')].
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = (LockSchemaFixtures missingLockKeyProblemFor:
                (self lockPathIn: work) key: #packages)
    ]

    testTheLockErrorCarriesTheBatchedHouseStyleMessage [
        "LockError carries problems exactly as its batched siblings do —
         which is why the Sprint 8 boundary absorbs it with no new
         mechanism."
        | work index error expected |
        work := self diamondWorkDir: 'lock-message-work'.
        index := self freshDir: 'lock-message-index'.
        LockBoundaryFixtures
            writeLockContents: LockBoundaryFixtures unparseableLockContents
            in: work.
        error := self lockErrorFrom: [
            (self cliIn: work source: (DirectorySource on: index))
                run: #('install')].
        expected := LockBoundaryFixtures lockErrorMessageFor: (Array with:
            (LockBoundaryFixtures unparseableLockProblemFor:
                (self lockPathIn: work))).
        self assert: error messageText = expected
    ]

    testTheLockDiagnosisNamesTheRepairThatWorks [
        "Three things, and each earns its place: the lock PATH (which
         file to open), the reader's own message (WHERE in it), and
         parley update (what to do). The advice is proved true by
         testUpdateNeverReadsTheLockAndRepairsIt."
        | work index problems problem |
        work := self diamondWorkDir: 'lock-advice-work'.
        index := self freshDir: 'lock-advice-index'.
        LockBoundaryFixtures
            writeLockContents: LockBoundaryFixtures unparseableLockContents
            in: work.
        problems := self installProblemsFrom: [
            (self cliIn: work source: (DirectorySource on: index))
                run: #('install')].
        problem := problems at: 1.
        self assert: (CommandLineFixtures does: problem
            include: (self lockPathIn: work)).
        self assert: (CommandLineFixtures does: problem
            include: 'position 1').
        self assert: (CommandLineFixtures does: problem
            include: 'parley update')
    ]

    "---- the lock boundary, observed at the diagnosis boundary ----"

    testACorruptLockIsExitOneAndNeverExitSeventy [
        | work index result |
        work := self diamondWorkDir: 'lock-exit-work'.
        index := self freshDir: 'lock-exit-index'.
        LockBoundaryFixtures
            writeLockContents: LockBoundaryFixtures unparseableLockContents
            in: work.
        result := self resultOf:
            (Array with: 'install' with: '--source' with: index) in: work.
        self assert: result exitCode = 1.
        self assert: result lines = (Array with:
            (LockBoundaryFixtures unparseableLockProblemFor:
                (self lockPathIn: work))).
        self denyBlamesParley: result
    ]

    testLockErrorIsDeclaredDiagnosedByTheBoundary [
        "The declaration and the handling are built from one list, so
         the boundary cannot claim one set and handle another."
        self assert: (CommandLine diagnosedErrorClasses includes: LockError).
        self assert: (CommandLineFixtures diagnosedErrorClassNames
            includes: 'LockError')
    ]

    "---- the repair the diagnosis names (declared pass in red) ----"

    testUpdateNeverReadsTheLockAndRepairsIt [
        "DECLARED PASS IN RED (issue #11). update already ignores any
         existing lock — that is the settled Doc E §4.1 contract. The
         law exists because Sprint 9 makes a diagnosis ADVISE it: if
         update ever started reading the lock, the advice would become a
         lie and the operator would have no way out at all. It must run
         from the first day the advice exists."
        | work index result |
        work := self diamondWorkDir: 'lock-update-work'.
        index := self freshDir: 'lock-update-index'.
        InstallFixtures populateInstallDiamondIn: index.
        LockBoundaryFixtures
            writeLockContents: LockBoundaryFixtures unparseableLockContents
            in: work.
        result := self resultOf:
            (Array with: 'update' with: '--source' with: index) in: work.
        self assert: result exitCode = 0.
        self assert: result lines = CommandLineFixtures diamondPinLines.
        self assert: (self contentsOf: (self lockPathIn: work))
            = ExecFixtures diamondLockString
    ]

    testResolveIsUnaffectedByACorruptLock [
        "DECLARED PASS IN RED (issue #11), same ground: resolve reads no
         lock either, and the boundary must not give it one."
        | work index result |
        work := self diamondWorkDir: 'lock-resolve-work'.
        index := self freshDir: 'lock-resolve-index'.
        InstallFixtures populateInstallDiamondIn: index.
        LockBoundaryFixtures
            writeLockContents: LockBoundaryFixtures wrongTagLockContents
            in: work.
        result := self resultOf:
            (Array with: 'resolve' with: '--source' with: index) in: work.
        self assert: result exitCode = 0.
        self assert: (self contentsOf: (self lockPathIn: work))
            = ExecFixtures diamondLockString
    ]

    testAValidLockIsStillTheFastPath [
        "DECLARED PASS IN RED (issue #11): the guard that the new
         boundary is not over-eager. A good lock must keep being read
         and used exactly as it was — a validation that rejected valid
         input would be a worse defect than the one being fixed."
        | work index result |
        work := self diamondWorkDir: 'lock-valid-work'.
        index := self freshDir: 'lock-valid-index'.
        InstallFixtures populateInstallDiamondIn: index.
        ExecFixtures writeLock: ExecFixtures diamondLockString in: work.
        result := self resultOf:
            (Array with: 'install' with: '--source' with: index) in: work.
        self assert: result exitCode = 0.
        self assert: result lines = CommandLineFixtures diamondPinLines.
        self assert: (self contentsOf: (self lockPathIn: work))
            = ExecFixtures diamondLockString
    ]

    "---- the authoring boundary ----"

    testAVocabularyTypoIsOneManifestErrorProblem [
        "ManifestFile load: answers the author's own diagnosis. The
         message is the vocabulary error's, character for character:
         the oracle is obtained by signaling that error, not by copying
         its text, so the law is an identity and cannot drift.

         AMENDED IN SPRINT 18 GREEN, approved at the RED review and
         BOUNDED TO ADDING THE HEADER (issue #20; Doc E §3.1, §8 decision
         44). The authoring problems are now emitted inside the settled
         per-file batch, so the diagnosis names the file the author must
         open. The vocabulary message itself does not move by one byte —
         that is still asserted as an identity against the signaled
         error — and the identity is now checked at its position INSIDE
         the batch. The selector keeps its name: the vocabulary error is
         still exactly one manifest problem, and the header is the path
         around it rather than a second problem with the file."
        | work problems |
        work := self typoWorkDir: 'authoring-typo-work'.
        problems := [(ManifestFile load: work, '/Package.st').
            self assert: false description: 'expected a ManifestError'.
            #()]
                on: Error
                do: [:e |
                    self assert: (e isKindOf: ManifestError)
                        description: 'expected a ManifestError, got ',
                            e class name.
                    e return: e problems].
        self assert: problems size = 2
            description: 'the batch answered ', problems printString.
        self assert: (problems at: 1)
            = (AuthoringFixtures batchHeaderFor: work, '/Package.st'
                count: 1)
            description: 'the header is ', (problems at: 1) printString.
        self assert: (problems at: 2)
            = LockBoundaryFixtures vocabularyTypoProblem
    ]

    testTheVocabularyDiagnosisKeepsItsSuggestion [
        "S4 names the suggestion explicitly: the message is reclassified,
         never rewritten, so the 'Did you mean #name:?' the author
         actually needs survives the reclassification intact."
        self assert: (CommandLineFixtures
            does: LockBoundaryFixtures vocabularyTypoProblem
            include: LockBoundaryFixtures vocabularySuggestionText)
    ]

    testAVocabularyTypoIsExitOneAndNeverExitSeventy [
        "AMENDED IN SPRINT 18 GREEN, bounded to adding the header: the
         operator's lines are the batch, and the vocabulary message
         inside it is byte-identical."
        | work index result |
        work := self typoWorkDir: 'authoring-exit-work'.
        index := self freshDir: 'authoring-exit-index'.
        result := self resultOf:
            (Array with: 'resolve' with: '--source' with: index) in: work.
        self assert: result exitCode = 1.
        self assert: result lines
            = ((Array with: (AuthoringFixtures
                batchHeaderFor: work, '/Package.st' count: 1)),
                (Array with: LockBoundaryFixtures vocabularyTypoProblem))
            description: 'the typo answered ', result lines printString.
        self denyBlamesParley: result
    ]

    "---- the widened arm: a declaration that fails validation ----"

    testAnInvalidDeclarationKeepsItsWholeProblemBatch [
        "The second arm of the granted exception (§8 decision 34): a
         Package.st that DID send define: but whose declarations fail
         validation. The builder's own ManifestError is re-signaled with
         every problem intact — never flattened to one line, and never
         the define-less diagnosis, which was a provable lie about a
         file that did send define:.

         AMENDED IN SPRINT 18 GREEN, bounded to adding the header: the
         batch is now headed by a problem naming the path and the count,
         and every sentence the builder composed is still present,
         byte-identical, in its own order. WHOLE means whole — the
         assertion is still an equality against the settled oracle, with
         the header prepended and nothing else changed."
        | work index result |
        work := self track: (LockBoundaryFixtures
            invalidDeclarationWorkDirNamed: 'authoring-invalid-work').
        index := self freshDir: 'authoring-invalid-index'.
        result := self resultOf:
            (Array with: 'resolve' with: '--source' with: index) in: work.
        self assert: result exitCode = 1.
        self assert: result lines
            = ((Array with: (AuthoringFixtures
                batchHeaderFor: work, '/Package.st'
                count: LockBoundaryFixtures invalidDeclarationProblems size)),
                LockBoundaryFixtures invalidDeclarationProblems)
            description: 'the invalid declarations answered ',
                result lines printString.
        self deny: (result lines includes:
            (ExecFixtures defineLessProblemFor: work, '/Package.st'))
            description: 'the file did send define: — reporting otherwise is a lie'.
        self denyBlamesParley: result
    ]

    testAnInvalidDeclarationNeverDumpsThroughTheShippedBinary [
        "The §4.2 no-backtrace invariant, over the same input, as a real
         child process. This is the only law in this file that spawns:
         the whole point of the widened arm is that gst's own dump
         reached the user's terminal, and a value-level law cannot see
         a terminal."
        | work index output code text |
        work := self track: (LockBoundaryFixtures
            invalidDeclarationWorkDirNamed: 'authoring-binary-work').
        index := self freshDir: 'authoring-binary-index'.
        output := (CommandLineFixtures absolutePathOf: work), '/output.txt'.
        code := ProcessRunner new run: (CommandLineFixtures
            shippedBinaryCommandIn: work
            args: 'resolve --source ',
                (CommandLineFixtures absolutePathOf: index)
            outputTo: output).
        self assert: code = 1.
        text := self contentsOf: output.
        self deny: text isEmpty
            description: 'a failing command must say something'.
        CommandLineFixtures backtraceMarkers do: [:marker |
            self deny: (CommandLineFixtures does: text include: marker)
                description: 'the shipped binary dumped a backtrace: ', marker]
    ]

    testAVocabularyTypoIsNotReportedAsAMissingDefine [
        "The failure this boundary replaces, named so it cannot come
         back. Before Sprint 9 the typo aborted the filed-in statement,
         define: never ran, and load: reported the define-less problem —
         a true sentence about the wrong thing. The author must be told
         about the typo, not about a define: they did write."
        | work index result |
        work := self typoWorkDir: 'authoring-define-work'.
        index := self freshDir: 'authoring-define-index'.
        result := self resultOf:
            (Array with: 'resolve' with: '--source' with: index) in: work.
        self deny: (result lines includes:
            (ExecFixtures defineLessProblemFor: work, '/Package.st'))
    ]
]

Namespace current: Smalltalk.
