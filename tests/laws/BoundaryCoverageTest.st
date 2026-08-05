"Parley Sprint 10 — the deserialization-boundary laws (issue #12;
 Doc E §4.2 'The deserialization-boundary law' and §5).

 WHY THIS ENUMERATION AND NOT A WIDER ONE. Doc E §4.2's closed set
 quantifies over Error subclasses defined in the Parley namespace, and
 a KERNEL error raised inside a verb is outside it entirely — which is
 exactly how a malformed-body parley.lock survived Sprint 9 with every
 law green (§8 decision 35). Enumerating more error classes could not
 have caught that and will not catch the next one. The invariant that
 carries the weight is per BOUNDARY: every point where Parley reads a
 file the operator can edit validates shape before handing the value to
 a constructor, and answers a diagnosis at exit 1 on malformed content.

 THE ANCHOR IS MECHANICAL. IndexEntryReader readFrom: is the single
 literals-only parser, so every sender of it in src/ is a
 deserialization boundary by construction.
 CommandLine class >> deserializationBoundaries declares them, and the
 drift law reads src/ and requires every sender to appear in the table.
 ManifestFile is declared alongside the two senders because it reads an
 operator-editable file by a DIFFERENT mechanism — file-in, not the
 reader — and is precisely the boundary a reader-anchored enumeration
 would otherwise miss.

 THE TABLE IS A DECLARATION CONSUMED TWICE, exactly as sourceFlags and
 diagnosedErrorClasses are: the drift law compares it against src/, and
 testEachDeclaredBoundaryDiagnosesItsMalformedInput ITERATES it, so a
 row added without a malformed-input driver fails the law rather than
 quietly widening the claim.

 THE DRIFT LAW DEMONSTRATES DRIFT. Sprint 8's lesson is that a drift
 law which has never failed on purpose is a law about nothing, so
 testTheDriftLawDetectsARemovedRow runs the SAME comparison against a
 table with a row removed and requires it to report the gap. And the
 enumeration itself is a trap: 3.2.5's File>>files answers regular
 files only and never recurses, so a src/ walk written the obvious way
 sees NOTHING and the law passes vacuously. The fixture uses namesDo:
 at both levels, and testTheEnumerationSeesTheRealSenders holds it to
 what the toolchain actually answers.

 DECLARED PASS IN RED (issue #12):
   testTheEnumerationSeesTheRealSenders — a fixture-correctness guard,
     not a behaviour law: it asserts the src/ walk really finds the two
     senders, so no other law in this file can pass vacuously. It reads
     only the checkout and must run from the first day, exactly as the
     Sprint 8 undiagnosed-list guard does.
 Every other law here fails against the pre-sprint tree.

 Every fixture path is under tmp/, unique per test, removed recursively
 in tearDown; nothing here spawns and no network is contacted."

Namespace current: Parley.

TestCase subclass: BoundaryCoverageTest [
    | fixtureDirs |

    <comment: 'Laws for CommandLine class >> deserializationBoundaries:
the drift law over the senders of IndexEntryReader readFrom: in src/,
its must-fail-on-removal proof, the class/file pairing the table
declares, and one malformed-input law per declared boundary.'>

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

    resultOf: anArgvArray in: aWorkDir [
        ^(CommandLine in: aWorkDir runner: RecordingRunner new)
            run: anArgvArray
    ]

    resolveIn: aWorkDir source: anIndexDir [
        ^self resultOf:
            (Array with: 'resolve' with: '--source' with: anIndexDir)
            in: aWorkDir
    ]

    installIn: aWorkDir source: anIndexDir [
        ^self resultOf:
            (Array with: 'install' with: '--source' with: anIndexDir)
            in: aWorkDir
    ]

    denyBlamesParley: aResult [
        self deny: aResult exitCode = 70.
        aResult lines do: [:line |
            self deny: (CommandLineFixtures does: line
                include: LockBoundaryFixtures undiagnosedLinePrefix)
                description: 'the diagnosis blames Parley: ', line.
            CommandLineFixtures backtraceMarkers do: [:marker |
                self deny: (CommandLineFixtures does: line include: marker)
                    description: 'the diagnosis dumped a backtrace: ', line]]
    ]

    "---- the enumeration itself (declared pass in red) ----"

    testTheEnumerationSeesTheRealSenders [
        "DECLARED PASS IN RED (issue #12) — see the class comment. It
         reads only the checkout, and it is what stops every other law
         in this file from passing vacuously over an empty walk."
        | senders |
        senders := LockSchemaFixtures readerSenderFileNames.
        self deny: senders isEmpty
            description: 'the src/ walk found no sender of ',
                LockSchemaFixtures readerSendSource,
                ' — File>>files does not recurse; the walk must use namesDo:'.
        self assert: senders
            = LockSchemaFixtures probeSenderFileNames
            description: 'the src/ walk answered ', senders printString.
        self assert: LockSchemaFixtures readerSenderClassNames
            = (Array with: 'CLI' with: 'DirectorySource'
                with: 'Publisher' with: 'SparseIndexSource')
    ]

    testTheEnumerationSurvivesALineSplitSender [
        "Sprint 11, S13's law half (issue #13; §8 decision 43, Doc E
         §4.2). The Sprint 10 walk matched 'IndexEntryReader readFrom:'
         as contiguous text on ONE stripped line, so a sender split
         across a line break — legal Smalltalk, one reformat away —
         vanished from the enumeration and took the drift law's
         coverage with it. The hardened walk normalizes whitespace
         before matching. The oracle is a fabricated src/ tree under
         tmp/ holding one line-split sender and one quiet file, walked
         through the SAME code path as the real enumeration —
         parameterized by root and subdirectory list, with the settled
         readerSenderFileNames delegating to it, which the guard
         restated below is what proves. BOUNDED CLAIM (decision 38
         corrected): this is a TEXTUAL search; reflective sender
         enumeration does not exist on 3.2.5 (whichSelectorsReferTo:
         searches literals, not sends), so a sender assembled by
         perform: or split by a comment between the words stays
         invisible — the law claims whitespace-robustness, nothing
         stronger."
        | root found |
        root := self freshDir: 'boundary-linesplit-src'.
        InspectionFixtures populateLineSplitTreeIn: root.
        found := LockSchemaFixtures
            readerSenderFileNamesUnder: root
            subdirectories: InspectionFixtures lineSplitSubdirectoryNames.
        self assert: found = InspectionFixtures lineSplitSenderFileNames
            description: 'the hardened walk answered ', found printString.
        self assert: LockSchemaFixtures readerSenderFileNames
            = LockSchemaFixtures probeSenderFileNames
            description: 'the settled enumeration no longer answers the probe oracle'
    ]

    "---- the drift law, and the proof that it detects drift ----"

    testEverySenderOfTheReaderIsADeclaredBoundary [
        | undeclared |
        undeclared := LockSchemaFixtures undeclaredSendersIn:
            CommandLine deserializationBoundaries.
        self assert: undeclared isEmpty
            description: undeclared printString,
                ' send ', LockSchemaFixtures readerSendSource,
                ' in src/ but are not declared deserialization boundaries'
    ]

    testTheDriftLawDetectsARemovedRow [
        "The same comparison, run against a table with the
         DirectorySource row removed. If this passes, the law above is
         about nothing."
        | mutant undeclared |
        mutant := LockSchemaFixtures
            tableWithout: 'DirectorySource'
            in: CommandLine deserializationBoundaries.
        undeclared := LockSchemaFixtures undeclaredSendersIn: mutant.
        self assert: (undeclared includes: 'DirectorySource')
            description: 'the drift law does not detect a removed row — it proves nothing'
    ]

    "---- the table's own shape ----"

    testTheTableNamesTheOperatorFileOfEachBoundary [
        "A row that cannot name the operator's file is not a boundary,
         it is a reader. The pairing is asserted, not only the names."
        | table |
        table := CommandLine deserializationBoundaries.
        self assert: (LockSchemaFixtures namesOfBoundaryClassesIn: table)
            = LockSchemaFixtures boundaryClassNames.
        self assert: (LockSchemaFixtures boundaryFilesIn: table)
            = LockSchemaFixtures boundaryPairings
    ]

    "---- one malformed-input law per declared boundary ----"

    testEachDeclaredBoundaryDiagnosesItsMalformedInput [
        "The table ITERATED: every declared boundary is handed a
         malformed operator file through a real verb and must answer a
         diagnosis at exit 1, blaming nobody but the file. The driver
         names are asserted against the declared names first, so a row
         added without a driver fails here rather than widening the
         claim silently."
        | lockWork lockIndex indexWork badIndex authorWork authorIndex sparseWork sparseBase publishWork publishDest rows |
        lockWork := self diamondWorkDir: 'boundary-lock-work'.
        lockIndex := self freshDir: 'boundary-lock-index'.
        LockSchemaFixtures
            writeLockContents: LockSchemaFixtures malformedBodyLockContents
            in: lockWork.
        indexWork := self diamondWorkDir: 'boundary-index-work'.
        badIndex := self freshDir: 'boundary-index-index'.
        SourceFixtures write: RetirementFixtures recordWithShortTuple
            toFile: 'retired.st' in: badIndex.
        authorWork := self track: (LockBoundaryFixtures
            invalidDeclarationWorkDirNamed: 'boundary-author-work').
        authorIndex := self freshDir: 'boundary-author-index'.
        sparseWork := self track: (SparseIndexFixtures
            workDirNamed: 'boundary-sparse-work'
            declaring: 'root-dep' constraint: '^1.0').
        sparseBase := self track: (SparseIndexFixtures
            baseTreeNamed: 'boundary-sparse-base').
        SparseIndexFixtures
            writeListing: SparseIndexFixtures wrongTagListingText
            for: 'root-dep' in: sparseBase.
        "The fifth boundary (Sprint 15): the Publisher reads the
         listing it is about to rewrite, so a malformed versions.st in
         the DESTINATION is driven through the real publish verb."
        publishWork := self track: (PublishLayoutFixtures
            workDirNamed: 'boundary-publish-work' version: '1.0.0').
        publishDest := self freshDir: 'boundary-publish-dest'.
        PublishLayoutFixtures
            writeListing: SparseIndexFixtures wrongTagListingText
            in: publishDest.
        rows := (Array
            with: (Array with: 'CLI'
                with: [self installIn: lockWork source: lockIndex])
            with: (Array with: 'DirectorySource'
                with: [self resolveIn: indexWork source: badIndex])
            with: (Array with: 'ManifestFile'
                with: [self resolveIn: authorWork source: authorIndex])
            with: (Array with: 'SparseIndexSource'
                with: [(CommandLine in: sparseWork
                        runner: ProcessRunner new)
                    run: (Array with: 'resolve' with: '--index'
                        with: (SparseIndexFixtures
                            baseUrlFor: sparseBase))])),
            (Array with: (Array with: 'Publisher'
                with: [(CommandLine in: publishWork
                        runner: RecordingRunner new)
                    run: (PublishLayoutFixtures
                        publishArgvTo: publishDest layout: 'sparse')])).
        self assert: (((rows collect: [:row | row at: 1])
            asSortedCollection: [:a :b | a <= b]) asArray)
                = (LockSchemaFixtures namesOfBoundaryClassesIn:
                    CommandLine deserializationBoundaries)
            description: 'the drivers and the declared boundaries disagree'.
        rows do: [:row |
            | result |
            result := (row at: 2) value.
            self assert: result exitCode = 1
                description: 'the ', (row at: 1),
                    ' boundary did not answer a diagnosis at exit 1'.
            self deny: result lines isEmpty
                description: 'the ', (row at: 1),
                    ' boundary answered no lines'.
            self denyBlamesParley: result]
    ]
]

Namespace current: Smalltalk.
