"Parley Sprint 9 — the source flag table and the second drift law
 (issue #11; Doc E §4.2 and Doc F §3).

 GitIndexSource has been built, lawful and completely unusable since
 Sprint 7: no flag builds one, so no user can reach it. Sprint 8's bin/
 drift law covers DIRECTORIES, and src/source/ IS named by the
 wrapper — the law was structurally silent about a class inside it that
 nothing constructs. Directories and flags are two different
 reachability questions, and the honest fix is a second law over the
 flag table rather than a wider claim from the first.

 The table is a DECLARATION, consumed twice: the wiring is built from
 it and the drift law reads the same rows, so the wiring and the law
 cannot disagree. This is Sprint 8's diagnosedErrorClasses construction
 applied to sources. It is a table LOOKUP, never an isKindOf: chain:
 the flag selects a row, and the row says which class to build and how.

 testEveryShippedSourceClassAppearsInTheFlagTable MUST FAIL against the
 pre-sprint table, exactly as Sprint 8's wrapper drift law had to fail
 against the pre-sprint wrapper. A drift law that passes on the tree
 that motivated it is not a law; it is a decoration.

 DECLARED PASSES IN RED (issue #11):
   testTheFixtureEnumerationSeesTheShippedSources — it checks the
     fixture's own enumeration against the checkout and needs no new
     behaviour. It is the guard that keeps the drift law from passing
     vacuously over an empty collection, which is precisely how the
     Sprint 8 src/ drift law nearly shipped broken (File>>files answers
     no subdirectories). It must run from the first day.
   testSourceStillWiresADirectorySource and
   testAVerbNeedingNoSourceStillRunsWithNoFlag — the regression guards
     that generalising the grammar from one hardcoded flag into a table
     moved neither the settled flag nor the no-flag case.
   testSourceAndGitTogetherAreAUsageError and
   testGitAndSourceTogetherAreAUsageErrorInEitherOrder — the pre-sprint
     grammar also answers usage for these argvs, but for an unrelated
     reason: '--git' is not a flag yet, so the argv reaches the settled
     CLI as an unknown shape. Their discriminating power arrives with
     the git laws below: once --git is a real flag, the ONLY thing
     keeping them true is the mutual-exclusion rule. Declared honestly
     rather than dressed up as red.

 The git laws run REAL git against LOCAL fixture repositories under
 tmp/, through ProcessRunner — the one process seam — with the
 committer identity supplied per command. No network is contacted,
 ever. Every fixture path is under tmp/, unique per test, removed
 recursively in tearDown; the developer image is never mutated."

Namespace current: Parley.

TestCase subclass: SourceFlagTest [
    | fixtureDirs |

    <comment: 'Laws for CommandLine class >> sourceFlags: every shipped
*Source class appears in it, --git wires a real GitIndexSource whose
checkout lands under the working directory, and --source and --git
together are a usage error.'>

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

    diamondRepo: aLabel [
        ^self track: (LockBoundaryFixtures diamondRepoNamed: aLabel)
    ]

    contentsOf: aPath [
        ^(File name: aPath) contents
    ]

    exists: aPath [
        ^(File name: aPath) exists
    ]

    "---- S11: every shipped source is reachable from the binary ----"

    testEveryShippedSourceClassAppearsInTheFlagTable [
        "The law that would have caught GitIndexSource. It must fail
         against the pre-sprint table, which has no --git row and no
         table at all."
        | shipped wired |
        shipped := LockBoundaryFixtures shippedSourceClassNames.
        self deny: shipped isEmpty
            description: 'the fixture enumerated no source classes — a drift law over an empty collection proves nothing'.
        wired := LockBoundaryFixtures namesOfSourceClassesIn:
            CommandLine sourceFlags.
        shipped do: [:each |
            self assert: (wired includes: each)
                description: each,
                    ' is shipped in ', LockBoundaryFixtures sourceDirectory,
                    ' but no flag builds it — a source can never be lawful and unreachable']
    ]

    testTheFixtureEnumerationSeesTheShippedSources [
        "DECLARED PASS IN RED (issue #11). The guard on the guard: the
         drift law above is only as good as what it enumerates, and an
         enumeration that answers nothing passes vacuously. Probed
         against the toolchain: (File name: 'src/source') files answers
         the three regular files of that directory, so files IS the
         right selector here — unlike the Sprint 8 src/ law, which
         enumerates DIRECTORIES and needs namesDo:."
        | shipped |
        shipped := LockBoundaryFixtures shippedSourceClassNames.
        self assert: shipped = LockBoundaryFixtures sourceClassNames.
        self assert: (shipped includes: 'GitIndexSource')
            description: 'the fixture is wrong: src/source/GitIndexSource.st does not exist'.
        self assert: (shipped includes: 'DirectorySource').
        self deny: (shipped includes: 'SourceError')
            description: 'an error class is not a source'
    ]

    "---- the table is a declaration, not a chain ----"

    testTheFlagTableDeclaresTheDocumentedFlags [
        self assert: (LockBoundaryFixtures flagNamesIn: CommandLine sourceFlags)
            = LockBoundaryFixtures sourceFlagNames.
        self assert: (LockBoundaryFixtures namesOfSourceClassesIn:
            CommandLine sourceFlags)
                = LockBoundaryFixtures sourceClassNames
    ]

    testEveryFlagTableRowIsAFlagAClassAndABuilder [
        "One row shape, so the wiring reads the table rather than
         branching on what it finds there."
        | work commandLine |
        work := self freshDir: 'flag-shape-work'.
        commandLine := CommandLine in: work runner: TrapRunner new.
        self deny: CommandLine sourceFlags isEmpty.
        CommandLine sourceFlags do: [:row |
            self assert: row size = 3.
            self assert: (row at: 1) isString.
            self assert: ((row at: 1) startsWith: '--')
                description: 'a source flag must look like a flag: ', (row at: 1).
            self assert: ((row at: 2) isKindOf: Class)
                description: 'the second column names the source class to build'.
            self assert: (row at: 3) isSymbol
                description: 'the third column names the builder message'.
            self assert: (commandLine respondsTo: (row at: 3))
                description: 'nothing builds ', (row at: 2) name asString]
    ]

    "---- S8/S9: --git wires a real GitIndexSource ----"

    testGitWiresAGitIndexSourceAndResolvesThroughIt [
        | work repo result |
        work := self diamondWorkDir: 'flag-git-work'.
        repo := self diamondRepo: 'flag-git-repo'.
        result := (CommandLine in: work runner: ProcessRunner new)
            run: (Array with: 'resolve' with: '--git' with: repo).
        self assert: result exitCode = 0.
        self assert: result lines = CommandLineFixtures diamondPinLines.
        self assert: (self contentsOf: work, '/parley.lock')
            = ExecFixtures diamondLockString
    ]

    testTheGitCacheIsTheWorkingDirectorys [
        "The checkout lands at <work>/.parley/git/<sha256 of the repo
         location> — derived from the WORKING directory, never the
         process cwd, and keyed through the settled Sha256 so any repo
         string becomes one deterministic filesystem-safe name and no
         escaping layer is invented."
        | work repo cache |
        work := self diamondWorkDir: 'flag-cache-work'.
        repo := self diamondRepo: 'flag-cache-repo'.
        cache := LockBoundaryFixtures gitCachePathIn: work forRepo: repo.
        (CommandLine in: work runner: ProcessRunner new)
            run: (Array with: 'resolve' with: '--git' with: repo).
        self assert: (self exists: cache)
            description: 'no checkout at ', cache.
        self assert: (self exists: cache, '/a-1.0.0.st')
            description: 'the checkout does not hold the repository''s entries'.
        self deny: (self exists: LockBoundaryFixtures cwdGitCacheRoot)
            description: 'a checkout was created beside the process cwd'
    ]

    testASecondGitResolveReusesTheSameCheckout [
        "The cache key is a pure function of the repo location, so the
         second invocation finds the first one's checkout and the
         settled GitIndexSource pulls instead of cloning."
        | work repo cache |
        work := self diamondWorkDir: 'flag-recache-work'.
        repo := self diamondRepo: 'flag-recache-repo'.
        cache := LockBoundaryFixtures gitCachePathIn: work forRepo: repo.
        (CommandLine in: work runner: ProcessRunner new)
            run: (Array with: 'resolve' with: '--git' with: repo).
        (CommandLine in: work runner: ProcessRunner new)
            run: (Array with: 'resolve' with: '--git' with: repo).
        self assert: (self exists: cache).
        self assert: (PublishFixtures fileNamesIn:
            (LockBoundaryFixtures gitCacheRootIn: work)) size = 1
    ]

    "---- S10: --source and --git together are a usage error ----"

    testSourceAndGitTogetherAreAUsageError [
        "Both given is a usage error, exit 2, because silently
         preferring one would make a typo look like a working command.
         The runner is a TrapRunner: if anything reached the process
         seam — a clone, a registration — the boundary would answer 70
         instead of 2, so 'no source is built' is proved rather than
         assumed."
        | work index repo result |
        work := self diamondWorkDir: 'flag-both-work'.
        index := self freshDir: 'flag-both-index'.
        repo := self freshDir: 'flag-both-repo'.
        InstallFixtures populateInstallDiamondIn: index.
        result := (CommandLine in: work runner: TrapRunner new)
            run: (Array with: 'resolve' with: '--source' with: index
                with: '--git') , (Array with: repo).
        self assert: result exitCode = 2.
        self assert: result lines = (GrammarFixtures
            usageAnswerFor: #bothSourceFlags subject: '')
            description: 'two source flags answered ', result lines printString.
        self deny: (self exists: work, '/parley.lock')
            description: 'a usage error resolved something'.
        self deny: (self exists: (LockBoundaryFixtures gitCacheRootIn: work))
            description: 'a usage error built a source'
    ]

    testGitAndSourceTogetherAreAUsageErrorInEitherOrder [
        "The exclusion is a property of the pair, not of the order they
         happen to appear in."
        | work index repo result |
        work := self diamondWorkDir: 'flag-order-work'.
        index := self freshDir: 'flag-order-index'.
        repo := self freshDir: 'flag-order-repo'.
        result := (CommandLine in: work runner: TrapRunner new)
            run: (Array with: 'resolve' with: '--git' with: repo
                with: '--source') , (Array with: index).
        self assert: result exitCode = 2.
        self assert: result lines = (GrammarFixtures
            usageAnswerFor: #bothSourceFlags subject: '')
            description: 'two source flags answered ', result lines printString
    ]

    "---- the settled flag does not move ----"

    testSourceStillWiresADirectorySource [
        "DECLARED PASS IN RED (issue #11): the regression guard that
         generalising one hardcoded flag into a table left the settled
         flag exactly where it was."
        | work index result |
        work := self diamondWorkDir: 'flag-source-work'.
        index := self freshDir: 'flag-source-index'.
        InstallFixtures populateInstallDiamondIn: index.
        result := (CommandLine in: work runner: RecordingRunner new)
            run: (Array with: 'resolve' with: '--source' with: index).
        self assert: result exitCode = 0.
        self assert: result lines = CommandLineFixtures diamondPinLines.
        self assert: (self contentsOf: work, '/parley.lock')
            = ExecFixtures diamondLockString
    ]

    testAVerbNeedingNoSourceStillRunsWithNoFlag [
        "DECLARED PASS IN RED (issue #11): absent flags still wire nil,
         and the verbs that need no source still run."
        | work result |
        work := self freshDir: 'flag-none-work'.
        result := (CommandLine in: work runner: RecordingRunner new)
            run: #('init').
        self assert: result exitCode = 0.
        self assert: result lines = ExecFixtures initSuccessLines
    ]
]

Namespace current: Smalltalk.
