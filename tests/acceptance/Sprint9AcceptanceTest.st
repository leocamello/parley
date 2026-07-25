"Parley Sprint 9 — acceptance scenarios S1-S12 from GitHub issue #11.
 Each scenario Sn maps to exactly one selector starting with testSn_
 (enforced by the wrap traceability gate).

 The milestone: the blame boundary. Sprint 8 made the binary tell the
 truth about WHETHER it failed; this sprint makes it tell the truth
 about WHOSE FAULT it was, and makes every source Parley ships
 reachable from the binary.

 Three escapes close here, and all three are the same disease: a
 message that is a perfect diagnosis of the OPERATOR's file, delivered
 with the blame pointed at Parley. The lock read (S1-S3), the author's
 own Package.st (S4-S5), and — a reachability escape rather than a
 blame one — a source class nothing constructs (S8-S11). With them
 closed, Doc E §4.2's strong claim becomes true again: every Parley
 error class is either diagnosed at exit 1 or provably never signaled
 out of a verb, and S7 proves the second half mechanically rather than
 asserting it.

 DECLARED PASSES IN RED (issue #11):
   testS3_updateRepairsWhatInstallRefuses — update already ignores any
     existing lock (the settled Doc E §4.1 contract). It passes in red
     and must: Sprint 9 makes a diagnosis ADVISE parley update, and if
     update ever started reading the lock the advice would become a lie.
     The law is what keeps the advice true.
   testS10_sourceAndGitTogetherAreAUsageError — the pre-sprint grammar
     also answers usage for this argv, but for an unrelated reason:
     '--git' is not a flag yet, so the argv reaches the settled CLI as
     an unknown shape. Its discriminating power arrives with S8: once
     --git is a real flag, the ONLY thing keeping S10 true is the
     mutual-exclusion rule. Declared honestly rather than dressed up.
 Every other scenario fails against the pre-sprint tree.

 S5 and S12 spawn gst running bin/parley-main.st through
 ProcessRunner — the one process seam — and S8, S9 and S12 run real git
 against LOCAL fixture repositories built under tmp/, with the
 committer identity supplied per command. No test contacts a network,
 ever. These spawn in red too, because the law under test IS the
 child's exit code and landed output; fronting them artificially would
 test the fronting.

 Every fixture path is under tmp/, unique per test, removed recursively
 in tearDown; children write only under tmp/; the developer image is
 never mutated."

Namespace current: Parley.

TestCase subclass: Sprint9AcceptanceTest [
    | fixtureDirs |

    <comment: 'Acceptance scenarios for Sprint 9: the lock-validation
boundary, the authoring-error boundary, the restored strong closed-set
claim, the --git flag and its working-directory cache, the source
drift law, and the ecosystem loop closing through the binary over
git.'>

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

    greetingWorkDir: aLabel [
        | path |
        path := self freshDir: aLabel.
        PublishFixtures populateGreetingWorkDirIn: path.
        ^path
    ]

    diamondRepo: aLabel [
        ^self track: (LockBoundaryFixtures diamondRepoNamed: aLabel)
    ]

    absolute: aPath [
        ^CommandLineFixtures absolutePathOf: aPath
    ]

    contentsOf: aPath [
        ^(File name: aPath) contents
    ]

    exists: aPath [
        ^(File name: aPath) exists
    ]

    lockPathIn: aWorkDir [
        ^aWorkDir, '/parley.lock'
    ]

    resultOf: anArgvArray in: aWorkDir [
        ^(CommandLine in: aWorkDir runner: RecordingRunner new)
            run: anArgvArray
    ]

    runChild: aCommandString [
        "Every child goes through the one process seam."
        ^ProcessRunner new run: aCommandString
    ]

    isClass: aClass coveredBy: aCollectionOfClasses [
        ^(aCollectionOfClasses
            detect: [:each | aClass == each or: [aClass inheritsFrom: each]]
            ifNone: [nil]) notNil
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

    denyBacktraceIn: aText [
        self deny: aText isEmpty
            description: 'a failing command must say something'.
        CommandLineFixtures backtraceMarkers do: [:marker |
            self deny: (CommandLineFixtures does: aText include: marker)
                description: 'the shipped binary dumped a backtrace: ', marker]
    ]

    classNameOfErrorFrom: aBlock [
        "The class of the error aBlock signals, as a String; fails the
         test when it signals nothing."
        [aBlock value.
         self assert: false
             description: 'the driver signaled nothing — it does not reach the signal site']
            on: Error
            do: [:e | ^e class name asString].
        ^'(nothing)'
    ]

    "---- S1: an unparseable lock is a diagnosis, exit 1 ----"

    testS1_anUnparseableLockIsADiagnosis [
        | work index result |
        work := self diamondWorkDir: 's9-1-work'.
        index := self freshDir: 's9-1-index'.
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

    "---- S2: a wrong-tag lock is the same diagnosis ----"

    testS2_aWrongTagLockIsTheSameDiagnosis [
        | work index result |
        work := self diamondWorkDir: 's9-2-work'.
        index := self freshDir: 's9-2-index'.
        LockBoundaryFixtures
            writeLockContents: LockBoundaryFixtures wrongTagLockContents
            in: work.
        result := self resultOf:
            (Array with: 'install' with: '--source' with: index) in: work.
        self assert: result exitCode = 1.
        self assert: result lines = (Array with:
            (LockBoundaryFixtures wrongTagLockProblemFor:
                (self lockPathIn: work))).
        self denyBlamesParley: result
    ]

    "---- S3: update repairs what install refuses ----"

    testS3_updateRepairsWhatInstallRefuses [
        "DECLARED PASS IN RED (issue #11) — see the class comment. The
         diagnosis of S1 advises parley update; this is the proof that
         the advice is true, and the guard that keeps it true."
        | work index result |
        work := self diamondWorkDir: 's9-3-work'.
        index := self freshDir: 's9-3-index'.
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

    "---- S4: a vocabulary typo is the author's diagnosis, exit 1 ----"

    testS4_aVocabularyTypoIsTheAuthorsDiagnosis [
        | work index result |
        work := self typoWorkDir: 's9-4-work'.
        index := self freshDir: 's9-4-index'.
        result := self resultOf:
            (Array with: 'resolve' with: '--source' with: index) in: work.
        self assert: result exitCode = 1.
        self assert: result lines size = 1.
        self assert: (result lines at: 1)
            = LockBoundaryFixtures vocabularyTypoProblem.
        self assert: (CommandLineFixtures does: (result lines at: 1)
            include: LockBoundaryFixtures vocabularySuggestionText).
        self denyBlamesParley: result
    ]

    "---- S5: both diagnoses survive the shipped binary ----"

    testS5_bothDiagnosesSurviveTheShippedBinary [
        | lockWork lockIndex lockOut lockCode typoWork typoIndex typoOut
          typoCode |
        "the corrupt lock, as a real child process"
        lockWork := self diamondWorkDir: 's9-5-lock-work'.
        lockIndex := self freshDir: 's9-5-lock-index'.
        LockBoundaryFixtures
            writeLockContents: LockBoundaryFixtures unparseableLockContents
            in: lockWork.
        lockOut := (self absolute: lockWork), '/output.txt'.
        lockCode := self runChild: (CommandLineFixtures
            shippedBinaryCommandIn: lockWork
            args: 'install --source ', (self absolute: lockIndex)
            outputTo: lockOut).
        self assert: lockCode = 1.
        self denyBacktraceIn: (self contentsOf: lockOut).
        "the vocabulary typo, as a real child process"
        typoWork := self typoWorkDir: 's9-5-typo-work'.
        typoIndex := self freshDir: 's9-5-typo-index'.
        typoOut := (self absolute: typoWork), '/output.txt'.
        typoCode := self runChild: (CommandLineFixtures
            shippedBinaryCommandIn: typoWork
            args: 'resolve --source ', (self absolute: typoIndex)
            outputTo: typoOut).
        self assert: typoCode = 1.
        self denyBacktraceIn: (self contentsOf: typoOut)
    ]

    "---- S6: the boundary declares six, and the partition holds ----"

    testS6_theBoundaryDeclaresSixAndThePartitionHolds [
        | parleyErrors diagnosed undiagnosed |
        parleyErrors := CommandLineFixtures parleyErrorClasses.
        self deny: parleyErrors isEmpty.
        diagnosed := CommandLine diagnosedErrorClasses.
        undiagnosed := CommandLineFixtures undiagnosedErrorClassNames.
        self assert: diagnosed size = 6.
        self assert: (CommandLineFixtures namesOf: diagnosed)
            = CommandLineFixtures diagnosedErrorClassNames.
        self assert: ((CommandLineFixtures namesOf: diagnosed)
            includes: 'LockError').
        self assert: (self isClass: LockError coveredBy: diagnosed).
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

    "---- S7: the strong claim, mechanically ----"

    testS7_theStrongClaimHoldsMechanically [
        "Every declared-undiagnosed class, signaled inside the verb that
         can reach its signal site, is answered as a DIAGNOSIS at exit 1
         and never as the exit-70 shape.

         Each row carries two blocks, and the pair is what makes the law
         non-vacuous. The RAW block proves the fixture input really does
         reach that class's signal site — a law that raised the error by
         hand would prove nothing about whether a verb can leak one. The
         VERB block then drives the same input through a real verb and
         the law reads the answer the operator would get."
        | constraintIndex versionIndex parseWork parseIndex formatWork
          formatIndex typoWork typoIndex constraintWork versionWork rows |
        constraintWork := self diamondWorkDir: 's9-7-constraint-work'.
        constraintIndex := self freshDir: 's9-7-constraint-index'.
        SourceFixtures write: CommandLineFixtures entryWithUnparseableConstraint
            toFile: 'p-1.0.0.st' in: constraintIndex.
        versionWork := self diamondWorkDir: 's9-7-version-work'.
        versionIndex := self freshDir: 's9-7-version-index'.
        SourceFixtures write: CommandLineFixtures entryWithUnparseableVersion
            toFile: 'p-1.0.0.st' in: versionIndex.
        parseWork := self diamondWorkDir: 's9-7-parse-work'.
        parseIndex := self freshDir: 's9-7-parse-index'.
        LockBoundaryFixtures
            writeLockContents: LockBoundaryFixtures unparseableLockContents
            in: parseWork.
        formatWork := self diamondWorkDir: 's9-7-format-work'.
        formatIndex := self freshDir: 's9-7-format-index'.
        LockBoundaryFixtures
            writeLockContents:
                LockBoundaryFixtures unsupportedVersionLockContents
            in: formatWork.
        typoWork := self typoWorkDir: 's9-7-typo-work'.
        typoIndex := self freshDir: 's9-7-typo-index'.
        rows := (Array
            with: (Array with: 'ConstraintFormatError'
                with: [VersionConstraint fromString: 'banana']
                with: [self resolveIn: constraintWork source: constraintIndex])
            with: (Array with: 'VersionFormatError'
                with: [Version fromString: 'banana']
                with: [self resolveIn: versionWork source: versionIndex])
            with: (Array with: 'IndexEntryParseError'
                with: [IndexEntryReader readFrom: (ReadStream on:
                    LockBoundaryFixtures unparseableLockContents)]
                with: [self installIn: parseWork source: parseIndex])
            with: (Array with: 'IndexEntryFormatError'
                with: [IndexEntryReader readFrom: (ReadStream on:
                    LockBoundaryFixtures unsupportedVersionLockContents)]
                with: [self installIn: formatWork source: formatIndex])),
            (Array with: (Array with: 'ManifestVocabularyError'
                with: [ManifestBuilder new
                    perform: LockBoundaryFixtures vocabularyTypoSelector asSymbol
                    with: 'x']
                with: [self resolveIn: typoWork source: typoIndex])).
        "the drivers cover exactly the declared undiagnosed list"
        self assert: (((rows collect: [:row | row at: 1])
            asSortedCollection: [:a :b | a <= b]) asArray)
                = CommandLineFixtures undiagnosedErrorClassNames.
        rows do: [:row |
            | result |
            self assert: (self classNameOfErrorFrom: (row at: 2))
                = (row at: 1)
                description: 'the driver for ', (row at: 1),
                    ' does not reach its signal site'.
            result := (row at: 3) value.
            self assert: result exitCode = 1
                description: (row at: 1),
                    ' is not answered as a diagnosis at exit 1'.
            self denyBlamesParley: result]
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

    "---- S8: --git wires a real GitIndexSource ----"

    testS8_gitWiresARealGitIndexSource [
        | work repo result |
        work := self diamondWorkDir: 's9-8-work'.
        repo := self diamondRepo: 's9-8-repo'.
        result := (CommandLine in: work runner: ProcessRunner new)
            run: (Array with: 'resolve' with: '--git' with: repo).
        self assert: result exitCode = 0.
        self assert: result lines = CommandLineFixtures diamondPinLines.
        self assert: (self contentsOf: (self lockPathIn: work))
            = ExecFixtures diamondLockString
    ]

    "---- S9: the git cache is the working directory's ----"

    testS9_theGitCacheIsTheWorkingDirectorys [
        | work repo cache |
        work := self diamondWorkDir: 's9-9-work'.
        repo := self diamondRepo: 's9-9-repo'.
        cache := LockBoundaryFixtures gitCachePathIn: work forRepo: repo.
        (CommandLine in: work runner: ProcessRunner new)
            run: (Array with: 'resolve' with: '--git' with: repo).
        self assert: (self exists: cache)
            description: 'no checkout at ', cache.
        self assert: (self exists: cache, '/a-1.0.0.st').
        self deny: (self exists: LockBoundaryFixtures cwdGitCacheRoot)
            description: 'a checkout was created beside the process cwd'
    ]

    "---- S10: --source and --git together are a usage error ----"

    testS10_sourceAndGitTogetherAreAUsageError [
        "DECLARED PASS IN RED (issue #11) — see the class comment. The
         TrapRunner is what makes 'no source is built' a proof: anything
         reaching the process seam would answer 70, not 2."
        | work index repo result |
        work := self diamondWorkDir: 's9-10-work'.
        index := self freshDir: 's9-10-index'.
        repo := self freshDir: 's9-10-repo'.
        InstallFixtures populateInstallDiamondIn: index.
        result := (CommandLine in: work runner: TrapRunner new)
            run: (Array with: 'resolve' with: '--source' with: index
                with: '--git') , (Array with: repo).
        self assert: result exitCode = 2.
        self assert: result lines = ExecFixtures usageLines.
        self deny: (self exists: (self lockPathIn: work))
            description: 'a usage error resolved something'.
        self deny: (self exists: (LockBoundaryFixtures gitCacheRootIn: work))
            description: 'a usage error built a source'
    ]

    "---- S11: every shipped source is reachable (drift law) ----"

    testS11_everyShippedSourceIsReachable [
        | shipped wired |
        shipped := LockBoundaryFixtures shippedSourceClassNames.
        self deny: shipped isEmpty.
        self assert: (shipped includes: 'GitIndexSource')
            description: 'the fixture is wrong: src/source/GitIndexSource.st does not exist'.
        wired := LockBoundaryFixtures namesOfSourceClassesIn:
            CommandLine sourceFlags.
        shipped do: [:each |
            self assert: (wired includes: each)
                description: each,
                    ' is shipped in ', LockBoundaryFixtures sourceDirectory,
                    ' but no flag builds it']
    ]

    "---- S12: the loop closes through the binary over git ----"

    testS12_theLoopClosesThroughTheBinaryOverGit [
        | authorWork index publishCode repo consumerWork installCode digest
          proofPath execCode |
        "author A publishes, as a real child process"
        authorWork := self greetingWorkDir: 's9-12-author'.
        index := self freshDir: 's9-12-index'.
        publishCode := self runChild: (CommandLineFixtures
            shippedBinaryCommandIn: authorWork
            args: 'publish ', (self absolute: index)).
        self assert: publishCode = 0.
        digest := Sha256 hexDigestOf:
            (self contentsOf: index, '/', PublishFixtures archiveFileName).
        "A's index becomes a git repository"
        repo := self track:
            (LockBoundaryFixtures indexRepoNamed: 's9-12-repo'
                fromIndex: index).
        "author B installs A's package over git, as a real child process"
        consumerWork := self track:
            (CommandLineFixtures consumerWorkDirNamed: 's9-12-consumer').
        installCode := self runChild: (CommandLineFixtures
            shippedBinaryCommandIn: consumerWork
            args: 'install --git ', (self absolute: repo)).
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
