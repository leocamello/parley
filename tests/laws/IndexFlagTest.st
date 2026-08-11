"Parley Sprint 14 — the --index flag, the cache, and both drift laws
 (issue #16; Doc F §7.4, Doc E §4.2).

 THE TWO TABLES EACH GAIN A ROW, AND EACH ROW IS FORCED BY THE LAW THAT
 WATCHES ITS TABLE. The sourceFlags drift law (SourceFlagTest) fails
 the moment SparseIndexSource ships in src/source/ with no flag row —
 that is the law doing precisely what Sprint 9 built it for. The
 deserializationBoundaries drift law (BoundaryCoverageTest) fails the
 moment SparseIndexSource sends IndexEntryReader readFrom: with no
 fourth row — decision 38's exact-enumeration guard, unchanged. This
 file does not duplicate those laws; it asserts the CONTENT the grown
 tables must declare, directly against the tables, and the wiring the
 new row must produce. The settled fixtures that pin the OLD tables
 (LockBoundaryFixtures sourceFlagNames, LockSchemaFixtures
 boundaryClassNames, ExecFixtures usageLines) are re-pinned in GREEN
 together with the CommandLine change — the Sprint 11/12/13 precedent —
 so nothing here reads them for the new rows.

 THE CACHE IS THE WORKING DIRECTORY'S, never the process cwd — the
 --git convention (Doc E §4.2) applied to the second remote source:
 <workingDir>/.parley/index/<sha256 of the base URL>/, listings beside
 a flat entries/ directory the inner DirectorySource scans.

 DECLARED PASSES IN RED (issue #16):
   testIndexAndSourceTogetherAreAUsageError and
   testIndexAndGitTogetherAreAUsageErrorInEitherOrder — the pre-sprint
     grammar also answers usage for these argvs, but for an unrelated
     reason: '--index' is not a flag yet, so the argv reaches the
     settled CLI as an unknown shape. Their discriminating power
     arrives with the wiring laws in this file: once --index is a real
     flag, the ONLY thing keeping them true is the mutual-exclusion
     rule. The Sprint 9 declaration, verbatim, for the third flag.
 Every other law in this file fails against the pre-sprint tree: the
 table laws demand rows that do not exist, the wiring laws demand a
 class that does not exist, and the usage law demands a flags: line
 the settled CommandLine does not print.

 The wiring laws run real curl against local file:// trees under tmp/,
 through ProcessRunner — the one process seam. No network is contacted,
 ever. Every fixture path is under tmp/, unique per test, removed
 recursively in tearDown; the developer image is never mutated."

Namespace current: Parley.

TestCase subclass: IndexFlagTest [
    | fixtureDirs |

    <comment: 'Laws for the third sourceFlags row and the fourth
deserializationBoundaries row: --index wires a SparseIndexSource whose
cache lands under the working directory, the grown tables declare the
new rows, the fourth boundary diagnoses its malformed input at exit 1,
--index with --source or --git is a usage error, and the usage flags:
lines name the flag while the verbs: line is unchanged.'>

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

    baseTree: aLabel [
        ^self track: (SparseIndexFixtures baseTreeNamed: aLabel)
    ]

    rootDepWorkDir: aLabel [
        ^self track: (SparseIndexFixtures workDirNamed: aLabel
            declaring: 'root-dep' constraint: '^1.0')
    ]

    contentsOf: aPath [
        ^(File name: aPath) contents
    ]

    exists: aPath [
        ^(File name: aPath) exists
    ]

    "---- the grown flag table (asserted directly, not through the
          settled oracles, which re-pin in GREEN) ----"

    testTheFlagTableDeclaresTheIndexFlag [
        "Three rows: the two settled flags and --index building
         SparseIndexSource. Asserted against the table itself; the
         SourceFlagTest drift law independently forces the class to
         appear once it ships."
        self assert: (LockBoundaryFixtures flagNamesIn:
            CommandLine sourceFlags)
                = #('--git' '--index' '--source').
        self assert: (LockBoundaryFixtures namesOfSourceClassesIn:
            CommandLine sourceFlags)
                = #('DirectorySource' 'GitIndexSource' 'SparseIndexSource')
    ]

    "---- the grown boundary table and its per-boundary law ----"

    testTheFourthBoundaryRowIsDeclared [
        "SparseIndexSource is the fourth sender of IndexEntryReader
         readFrom: (Doc F §7.2), so it is the fourth row, and the row
         names the operator-editable file it reads. A row that cannot
         name the operator's file is not a boundary; it is a reader.

         The enumeration gained Publisher at Sprint 15 (issue #17): the
         producer reads the same listing this source does, so it is the
         fifth row. Re-pinned in GREEN with the CommandLine change, the
         Sprint 11/12/13/14 precedent — this law's own claim, that the
         FOURTH row is SparseIndexSource paired with its file, is
         unchanged and still asserted below."
        | rows sparseRows |
        rows := CommandLine deserializationBoundaries.
        "Re-pinned again in Sprint 19's GREEN, the same precedent this
         comment already records: Configuration reads parley.config.st
         through the settled reader, so the table gained a sixth row.
         This law's own claim is unchanged."
        self assert: (LockSchemaFixtures namesOfBoundaryClassesIn: rows)
            = LockSchemaFixtures boundaryClassNames.
        sparseRows := rows select: [:row |
            (row at: 1) name asString = 'SparseIndexSource'].
        self assert: sparseRows size = 1.
        self assert: ((sparseRows at: 1) at: 2) = 'version listings'
    ]

    testTheSparseBoundaryDiagnosesItsMalformedInput [
        "The fourth row's malformed-input law, the table's contract
         (Doc F §7.2): a malformed listing reached through a real verb
         is a diagnosis at exit 1 blaming nobody but the file — never
         exit 70, never a backtrace. BoundaryCoverageTest's iteration
         gains its SparseIndexSource driver in GREEN with the row; this
         is the law that exists from RED."
        | base work result |
        base := self baseTree: 'iflag-boundary-base'.
        work := self rootDepWorkDir: 'iflag-boundary-work'.
        SparseIndexFixtures
            writeListing: SparseIndexFixtures wrongTagListingText
            for: 'root-dep' in: base.
        result := (CommandLine in: work runner: ProcessRunner new)
            run: (Array with: 'resolve' with: '--index'
                with: (SparseIndexFixtures baseUrlFor: base)).
        self assert: result exitCode = 1
            description: 'the sparse boundary did not answer a diagnosis at exit 1'.
        self deny: result lines isEmpty.
        result lines do: [:line |
            self deny: (CommandLineFixtures does: line
                include: LockBoundaryFixtures undiagnosedLinePrefix)
                description: 'the diagnosis blames Parley: ', line.
            CommandLineFixtures backtraceMarkers do: [:marker |
                self deny: (CommandLineFixtures does: line include: marker)
                    description: 'the diagnosis dumped a backtrace: ', line]]
    ]

    "---- the wiring ----"

    testIndexWiresASparseIndexSourceAndResolvesThroughIt [
        "resolve --index <base> against the two-level file:// tree:
         exit 0, the sorted pin lines, and a lock pinning the
         transitive dependency the operator never named."
        | base work result |
        base := self baseTree: 'iflag-wire-base'.
        work := self rootDepWorkDir: 'iflag-wire-work'.
        SparseIndexFixtures populateTwoLevelTreeIn: base.
        result := (CommandLine in: work runner: ProcessRunner new)
            run: (Array with: 'resolve' with: '--index'
                with: (SparseIndexFixtures baseUrlFor: base)).
        self assert: result exitCode = 0.
        self assert: result lines = #('deep 1.0.0' 'root-dep 1.0.0').
        self assert: (self exists: work, '/parley.lock')
            description: 'resolve wrote no lock'.
        self assert: (CommandLineFixtures does:
            (self contentsOf: work, '/parley.lock') include: '''deep'' ''1.0.0''')
            description: 'the lock does not pin the transitive dependency'
    ]

    testTheIndexCacheIsTheWorkingDirectorys [
        "The cache lands at <work>/.parley/index/<sha256 of the base
         URL>/ — derived from the WORKING directory, never the process
         cwd, keyed through the settled Sha256 exactly as the git
         checkout is — with the listings directory beside the flat
         entries directory the inner DirectorySource scans."
        | base work baseUrl cache |
        base := self baseTree: 'iflag-cache-base'.
        work := self rootDepWorkDir: 'iflag-cache-work'.
        SparseIndexFixtures populateTwoLevelTreeIn: base.
        baseUrl := SparseIndexFixtures baseUrlFor: base.
        cache := SparseIndexFixtures indexCachePathIn: work
            forBase: baseUrl.
        (CommandLine in: work runner: ProcessRunner new)
            run: (Array with: 'resolve' with: '--index' with: baseUrl).
        self assert: (self exists: cache)
            description: 'no cache at ', cache.
        self assert: (self exists:
            (SparseIndexFixtures cachedEntryPathIn: cache
                for: 'root-dep' version: '1.0.0'))
            description: 'the cache does not hold the fetched entries'.
        self assert: (self exists:
            (SparseIndexFixtures cachedListingPathIn: cache
                for: 'root-dep'))
            description: 'the cache does not hold the fetched listings'.
        self deny: (self exists: SparseIndexFixtures cwdIndexCacheRoot)
            description: 'a cache was created beside the process cwd'
    ]

    "---- mutual exclusion (the Sprint 9 rule, third flag) ----"

    testIndexAndSourceTogetherAreAUsageError [
        "DECLARED PASS IN RED (issue #16) — see the class comment. Both
         given is a usage error, exit 2, because silently preferring
         one would make a typo look like a working command. The runner
         is a TrapRunner: if anything reached the process seam the
         boundary would answer 70 instead of 2, so 'no source is
         built' is proved rather than assumed."
        | base work index result |
        base := self baseTree: 'iflag-both-base'.
        work := self rootDepWorkDir: 'iflag-both-work'.
        index := self freshDir: 'iflag-both-index'.
        result := (CommandLine in: work runner: TrapRunner new)
            run: (Array with: 'resolve' with: '--index'
                with: (SparseIndexFixtures baseUrlFor: base)
                with: '--source') , (Array with: index).
        self assert: result exitCode = 2.
        self deny: (self exists: work, '/parley.lock')
            description: 'a usage error resolved something'.
        self deny: (self exists: (SparseIndexFixtures indexCacheRootIn: work))
            description: 'a usage error built a source'
    ]

    testIndexAndGitTogetherAreAUsageErrorInEitherOrder [
        "DECLARED PASS IN RED (issue #16) — see the class comment. The
         exclusion is a property of the pair, not of the order they
         happen to appear in."
        | base work repo result |
        base := self baseTree: 'iflag-order-base'.
        work := self rootDepWorkDir: 'iflag-order-work'.
        repo := self freshDir: 'iflag-order-repo'.
        result := (CommandLine in: work runner: TrapRunner new)
            run: (Array with: 'resolve' with: '--git' with: repo
                with: '--index') ,
                (Array with: (SparseIndexFixtures baseUrlFor: base)).
        self assert: result exitCode = 2.
        result := (CommandLine in: work runner: TrapRunner new)
            run: (Array with: 'resolve' with: '--index'
                with: (SparseIndexFixtures baseUrlFor: base)
                with: '--git') , (Array with: repo).
        self assert: result exitCode = 2
    ]

    "---- the usage lines ----"

    testTheUsageLinesNameTheIndexFlag [
        "The usage answer gains the --index header alternative and a
         flags: line for it, while the verbs: line is byte-identical to
         the settled one — no verb moves this sprint. ExecFixtures
         usageLines re-pins in GREEN with the CommandLine change; the
         NEW lines are pinned here, in the sprint's own fixture."
        | work result |
        work := self freshDir: 'iflag-usage-work'.
        result := (CommandLine in: work runner: TrapRunner new)
            run: (Array with: 'frobnicate').
        self assert: result exitCode = 2.
        self assert: (result lines at: 1)
            = SparseIndexFixtures usageHeaderLine
            description: 'the usage header does not offer --index'.
        self assert: (result lines includes:
            SparseIndexFixtures indexFlagUsageLine)
            description: 'no flags: line describes --index'.
        self assert: (result lines at: 2) = (ExecFixtures usageLines at: 2)
            description: 'the verbs: line moved, and no verb moves this sprint'
    ]
]

Namespace current: Smalltalk.
