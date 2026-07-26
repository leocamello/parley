"Parley Sprint 10 — acceptance scenarios S1-S12 from GitHub issue #12.
 Each scenario Sn maps to exactly one selector starting with testSn_
 (enforced by the wrap traceability gate).

 The milestone: RETIREMENT, and the boundary that guards it. An index
 can say 'this release should not be used any more' — a retired release
 stays fetchable, so a build that already pinned it keeps working, and
 is excluded from fresh resolution, carrying a reason the owner wrote
 (S1, S2). The signal is an index-level record found by its TAG, never
 its filename (S3), several merge (S4), a malformed one is a batched
 diagnosis and not a crash (S5), retiring everything is a conflict and
 not a crash (S6), and the resolver cannot observe any of it (S7) —
 which is what keeps it a pure function and what a future
 PubGrubStrategy inherits for free. GitIndexSource gains all of it
 without a line changing (S8).

 The second half is what makes the first half safe. A retirement record
 is a THIRD operator-editable file Parley reads, and Sprint 9's
 close-out found the closed-set law structurally blind to malformed
 operator files (§8 decision 35): a malformed-body parley.lock still
 exited 70 blaming Parley. Adding a new boundary while that reasoning
 was unfixed would ship the same defect a third time. So the lock body
 and value checks (S9, S10) and the deserialization-boundary law (S11)
 land here as a prerequisite, and S12 is the sprint's exit criterion
 over every operator-editable input the tool has.

 DECLARED PASSES IN RED (issue #12): NONE in this file, and two of the
 twelve are worth saying why out loud.
   S6 was anticipated to pass (because #noVersions is settled
     behaviour) and does not: it is written against the new
     IndexSnapshot releases:retirements: constructor and a real
     retirement-bearing directory, so it asserts the conflict shape
     RETIREMENT produces rather than the one an empty index already
     produced.
   S2 passed in red as first written, and the RED run said so: install
     is law-bound not to consult the index on the fast path, so 'a
     retired release still installs from its lock' holds even against a
     Parley that cannot read a retirement-bearing index AT ALL. The
     scenario's own Given — 'the S1 index' — was therefore decoration.
     It now also asserts that the index still describes 0.3.2 (Doc C
     §2.1), which is the claim the Given was making all along, and it
     fails in red like the rest.
   The declared passes in red for this sprint are the guards in the law
     suites (RetirementTest
     testASnapshotWithoutRetirementsIsUnchanged, DirectorySourceTest
     testADirectoryWithNoRetirementRecordsScansExactlyAsBefore,
     LockSchemaTest testALockParleyWroteItselfAlwaysPasses and
     testTheTagCheckStillDecidesBeforeTheBodyCheck, and
     BoundaryCoverageTest testTheEnumerationSeesTheRealSenders), each
     declared in its own class comment.

 S8 runs real git against a LOCAL fixture repository built under tmp/
 with the committer identity supplied per command, and S12 spawns
 bin/parley-main.st through ProcessRunner — the one process seam — once
 per corpus row, because gst's own dump reaches a TERMINAL and no
 value-level law can see one. No test contacts a network, ever.

 Every fixture path is under tmp/, unique per test, removed recursively
 in tearDown; children write only under tmp/; the developer image is
 never mutated."

Namespace current: Parley.

TestCase subclass: Sprint10AcceptanceTest [
    | fixtureDirs |

    <comment: 'Acceptance scenarios for Sprint 10: the retirement
schema and its snapshot semantics, the scan''s tag dispatch, the
resolver purity proof, git inheritance, the lock body/value boundary,
the deserialization-boundary drift law, and the no-exit-70 corpus over
every operator-editable file.'>

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

    absentDir: aLabel [
        ^self track: (SourceFixtures missingPathNamed: aLabel)
    ]

    jsonWorkDir: aLabel [
        ^self track: (RetirementFixtures jsonRootWorkDirNamed: aLabel)
    ]

    diamondWorkDir: aLabel [
        ^self track: (CommandLineFixtures diamondRootWorkDirNamed: aLabel)
    ]

    retiredIndex: aLabel [
        | path |
        path := self freshDir: aLabel.
        RetirementFixtures populateRetiredIndexIn: path.
        ^path
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

    version: aString [
        ^Version fromString: aString
    ]

    versionStringsIn: aSnapshot of: aName [
        ^(((aSnapshot versionsOf: aName)
            collect: [:each | each printString]) asSortedCollection)
                asArray
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

    runChild: aCommandString [
        "Every child goes through the one process seam."
        ^ProcessRunner new run: aCommandString
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
        self deny: (CommandLineFixtures does: aText
            include: LockBoundaryFixtures undiagnosedLinePrefix)
            description: 'the shipped binary blamed Parley: ', aText.
        CommandLineFixtures backtraceMarkers do: [:marker |
            self deny: (CommandLineFixtures does: aText include: marker)
                description: 'the shipped binary dumped a backtrace: ', marker]
    ]

    sourceProblemsFrom: aBlock [
        [aBlock value.
         self assert: false description: 'expected a SourceError']
            on: Error
            do: [:e |
                self assert: (e isKindOf: SourceError)
                    description: 'expected a SourceError, got ',
                        e class name asString.
                ^e problems].
        ^#()
    ]

    "---- S1: a retired release is excluded from fresh resolution ----"

    testS1_aRetiredReleaseIsExcludedFromFreshResolution [
        "kernel-json ^0.3.0 allows both 0.3.1 and 0.3.2, and 0.3.2 is
         the higher — so only retirement can explain 0.3.1 being
         pinned."
        | work index result |
        work := self jsonWorkDir: 's10-1-work'.
        index := self retiredIndex: 's10-1-index'.
        result := self resolveIn: work source: index.
        self assert: result exitCode = 0.
        self assert: result lines = RetirementFixtures json031PinLines.
        self assert: (self contentsOf: (self lockPathIn: work))
            = RetirementFixtures lockPinningJson031String
    ]

    "---- S2: a retired release is still installable from an existing lock ----"

    testS2_aRetiredReleaseIsStillInstallableFromAnExistingLock [
        "Retirement excludes from FRESH RESOLUTION, never from fetch: a
         build that already resolved keeps working. Three things are
         asserted, and each earns its place.

         That install SUCCEEDS on the retired pin, and that it did so
         through the LOCK PATH — the settled snapshot-and-fetch trap
         double signals if either is touched, with the store primed so a
         cache hit is all install needs. Without it a green could come
         from the source having quietly re-resolved.

         And that the retirement-bearing index is STILL READABLE and
         still describes 0.3.2 (Doc C §2.1: dependenciesOf:version: and
         sha256For:version: answer for a retired release). That
         assertion is what gives this scenario discriminating power:
         install is law-bound not to consult the index on the fast path,
         so the first two halves hold even against a Parley that cannot
         read the index at all — which is exactly what a pre-Sprint-10
         Parley is, since its scan rejects the unknown tag. A Given that
         no assertion can establish is decoration."
        | work index result trapped snapshot |
        work := self jsonWorkDir: 's10-2-work'.
        index := self retiredIndex: 's10-2-index'.
        RetirementFixtures primeJson032StoreIn: work.
        ExecFixtures writeLock: RetirementFixtures lockPinningJson032String
            in: work.
        result := self installIn: work source: index.
        self assert: result exitCode = 0.
        self assert: result lines = RetirementFixtures json032PinLines.
        self assert: (self contentsOf: (self lockPathIn: work))
            = RetirementFixtures lockPinningJson032String.
        trapped := (CLI
            in: work
            source: SnapshotAndFetchTrapSource new
            store: (ContentStore on: (CommandLineFixtures storeRootIn: work))
            target: (CommandLineFixtures targetDirIn: work)
            runner: RecordingRunner new) run: #('install').
        self assert: trapped exitCode = 0
            description: 'the retired pin was not served by the lock path'.
        self assert: trapped lines = RetirementFixtures json032PinLines.
        snapshot := (DirectorySource on: index) snapshot.
        self assert: (snapshot sha256For: 'kernel-json'
            version: (self version: '0.3.2'))
                = RetirementFixtures digestJson032
            description: 'the index that retired 0.3.2 no longer describes it'
    ]

    "---- S3: the record is found by its tag, not its filename ----"

    testS3_theRetirementRecordIsFoundByItsTagNotItsFilename [
        "The record is named kernel-json-0.3.2.st — exactly what an
         entry for a release this index really holds would be called —
         and the entries are named nothing in particular."
        | index snapshot |
        index := self freshDir: 's10-3-index'.
        RetirementFixtures populateDisguisedIndexIn: index.
        snapshot := (DirectorySource on: index) snapshot.
        self assert: (self versionStringsIn: snapshot of: 'kernel-json')
            = (Array with: '0.3.1').
        self assert: (snapshot sha256For: 'kernel-json'
            version: (self version: '0.3.1'))
                = RetirementFixtures digestJson031.
        self assert: (snapshot sha256For: 'kernel-json'
            version: (self version: '0.3.2'))
                = RetirementFixtures digestJson032
    ]

    "---- S4: several retirement records merge ----"

    testS4_severalRetirementRecordsMerge [
        | index snapshot |
        index := self freshDir: 's10-4-index'.
        RetirementFixtures populateTwoRecordIndexIn: index.
        snapshot := (DirectorySource on: index) snapshot.
        self assert: (self versionStringsIn: snapshot of: 'kernel-json')
            = (Array with: '0.3.1').
        self assert: (self versionStringsIn: snapshot of: 'kernel-old')
            = (Array with: '1.1.0')
    ]

    "---- S5: a malformed record is a batched diagnosis ----"

    testS5_aMalformedRetirementRecordIsABatchedDiagnosis [
        "A retirement record is index content like any other: one
         SourceError, both files named, sorted-filename order, each with
         its own defect."
        | index problems |
        index := self freshDir: 's10-5-index'.
        RetirementFixtures populateMalformedMixIn: index.
        problems := self sourceProblemsFrom: [
            (DirectorySource on: index) snapshot].
        self assert: problems asArray
            = RetirementFixtures malformedMixProblems
    ]

    "---- S6: retiring every version is a conflict, not a crash ----"

    testS6_retiringEveryVersionIsAConflictNotACrash [
        "A value, never an exception, and never an empty-collection
         error. Asserted twice: the conflict SHAPE at the value level
         (the ordinary #noVersions leaf), and the exit code an operator
         sees."
        | outcome leaves work index result |
        outcome := ResolverFixtures
            resolve: RetirementFixtures jsonRootManifest
            against: RetirementFixtures snapshotWithBothJsonRetired.
        self deny: outcome isResolution.
        leaves := ResolverFixtures externalLeavesOf: outcome root.
        self deny: (leaves detect: [:each | each cause = #noVersions]
            ifNone: [nil]) isNil
            description: 'the conflict is not the ordinary #noVersions shape'.
        work := self jsonWorkDir: 's10-6-work'.
        index := self freshDir: 's10-6-index'.
        RetirementFixtures populateEveryVersionRetiredIn: index.
        result := self resolveIn: work source: index.
        self assert: result exitCode = 1.
        self deny: result lines isEmpty.
        self deny: (self exists: (self lockPathIn: work))
            description: 'a conflict wrote a lockfile'.
        self denyBlamesParley: result
    ]

    "---- S7: the resolver is provably unchanged ----"

    testS7_theResolverIsProvablyUnchanged [
        "THE PURITY PROOF. The same root resolved against two snapshots
         that differ only in HOW 0.3.2 is missing: retired in the one
         the real directory answers, simply ABSENT in the hand-built
         twin. The two Resolutions must be IDENTICAL — asserting only
         'the retired version was not picked' would pass against a
         resolver that branches on retirement, which is the one
         implementation this sprint exists to prevent."
        | index retired absent retirementOutcome absentOutcome |
        index := self retiredIndex: 's10-7-index'.
        retired := (DirectorySource on: index) snapshot.
        absent := RetirementFixtures snapshotWithoutJson032.
        retirementOutcome := ResolverFixtures
            resolve: RetirementFixtures jsonRootManifest against: retired.
        absentOutcome := ResolverFixtures
            resolve: RetirementFixtures jsonRootManifest against: absent.
        self assert: retirementOutcome isResolution.
        self assert: absentOutcome isResolution.
        self assert: retirementOutcome = absentOutcome
            description: 'the resolver answered differently for a retired release than for an absent one'
    ]

    "---- S8: retirement reaches a git index source untouched ----"

    testS8_retirementReachesAGitIndexSourceUntouched [
        "GitIndexSource holds an inner DirectorySource and inherits
         retirement with no change of its own. Real git, a LOCAL fixture
         repository, no network."
        | work repo result |
        work := self jsonWorkDir: 's10-8-work'.
        repo := self track: (RetirementFixtures retiredRepoNamed:
            's10-8-repo').
        result := (CommandLine in: work runner: ProcessRunner new)
            run: (Array with: 'resolve' with: '--git' with: repo).
        self assert: result exitCode = 0.
        self assert: result lines = RetirementFixtures json031PinLines.
        self assert: (self contentsOf: (self lockPathIn: work))
            = RetirementFixtures lockPinningJson031String
    ]

    "---- S9: a malformed-body lock is a diagnosis, exit 1 ----"

    testS9_aMalformedBodyLockIsADiagnosis [
        "The Sprint 9 close-out reproduction: right tag, right format
         version, no #packages. It used to die inside
         Resolution fromLockEntry: as a KERNEL error and be answered
         with exit 70 — the same sentence, on the same file, that the
         lock boundary exists to abolish."
        | work index result |
        work := self diamondWorkDir: 's10-9-work'.
        index := self freshDir: 's10-9-index'.
        LockSchemaFixtures
            writeLockContents: LockSchemaFixtures malformedBodyLockContents
            in: work.
        result := self installIn: work source: index.
        self assert: result exitCode = 1.
        self assert: result lines = (Array with:
            (LockSchemaFixtures missingLockKeyProblemFor:
                (self lockPathIn: work) key: #packages)).
        self denyBlamesParley: result
    ]

    "---- S10: an unparseable version in a shape-perfect lock ----"

    testS10_anUnparseableVersionInAShapePerfectLockIsTheSameDiagnosis [
        "Correct in every key, order and tuple arity, and one version
         means nothing: a shape check never asks whether a string MEANS
         anything, and the settled Version fromString: is what decides."
        | work index result |
        work := self diamondWorkDir: 's10-10-work'.
        index := self freshDir: 's10-10-index'.
        LockSchemaFixtures
            writeLockContents:
                LockSchemaFixtures unparseableVersionLockContents
            in: work.
        result := self installIn: work source: index.
        self assert: result exitCode = 1.
        self assert: result lines = (Array with:
            (LockSchemaFixtures unparseableLockVersionProblemFor:
                (self lockPathIn: work)
                value: LockSchemaFixtures unparseableVersionValue
                package: LockSchemaFixtures unparseableVersionPackage)).
        self denyBlamesParley: result
    ]

    "---- S11: every reader sender is a declared boundary (drift law) ----"

    testS11_everyReaderSenderIsADeclaredBoundary [
        "The enumeration is proved non-vacuous first (3.2.5's
         File>>files never recurses, so a src/ walk written the obvious
         way sees nothing), then every sender must appear in the table,
         then the same comparison is run against a table with a row
         REMOVED and must report the gap — a drift law that has never
         demonstrated detecting drift is a law about nothing."
        | senders undeclared mutantGap |
        senders := LockSchemaFixtures readerSenderClassNames.
        self deny: senders isEmpty
            description: 'the src/ walk found no sender of ',
                LockSchemaFixtures readerSendSource.
        self assert: (senders includes: 'DirectorySource')
            description: 'the fixture is wrong: the scan does not send the reader'.
        self assert: (senders includes: 'CLI')
            description: 'the fixture is wrong: the lock read does not send the reader'.
        undeclared := LockSchemaFixtures undeclaredSendersIn:
            CommandLine deserializationBoundaries.
        self assert: undeclared isEmpty
            description: undeclared printString,
                ' send the reader in src/ but are not declared boundaries'.
        mutantGap := LockSchemaFixtures undeclaredSendersIn:
            (LockSchemaFixtures tableWithout: 'DirectorySource'
                in: CommandLine deserializationBoundaries).
        self assert: (mutantGap includes: 'DirectorySource')
            description: 'the drift law does not detect a removed row'
    ]

    "---- S12: no operator file reaches exit 70 ----"

    testS12_noOperatorFileReachesExitSeventy [
        "THE SPRINT'S EXIT CRITERION, over every operator-editable input
         the tool has: three lock grounds, two index-artifact kinds,
         three Package.st kinds. Each is driven through a real verb at
         the value level AND as a real bin/parley-main.st child process,
         because gst's own dump reaches a TERMINAL and no value-level
         law can see one. None answers exit 70, none prints a backtrace,
         none blames Parley."
        | rows |
        rows := self corpusRows.
        self assert: (((rows collect: [:row | row at: 1])
            asSortedCollection: [:a :b | a <= b]) asArray)
                = ((LockSchemaFixtures operatorFileCorpusLabels
                    asSortedCollection: [:a :b | a <= b]) asArray)
            description: 'the corpus and its declared labels disagree'.
        rows do: [:row |
            | label work index result output code |
            label := row at: 1.
            work := row at: 2.
            index := row at: 3.
            result := self resultOf:
                (Array with: (row at: 4) with: '--source' with: index)
                in: work.
            self assert: result exitCode = 1
                description: label, ' is not a diagnosis at exit 1'.
            self deny: result lines isEmpty
                description: label, ' answered no lines'.
            self denyBlamesParley: result.
            output := (self absolute: work), '/output.txt'.
            code := self runChild: (CommandLineFixtures
                shippedBinaryCommandIn: work
                args: (row at: 4), ' --source ', (self absolute: index)
                outputTo: output).
            self assert: code = 1
                description: label, ' exited ', code printString,
                    ' through the shipped binary'.
            self denyBacktraceIn: (self contentsOf: output)]
    ]

    corpusRows [
        "Private — one row per operator-editable input: the label, a
         working directory, an index directory and the verb that reads
         the file. Built here rather than in the fixture because every
         row owns tmp/ paths this test tracks for teardown."
        | rows |
        rows := OrderedCollection new.
        rows add: (self lockRow: 'malformed-body lock'
            contents: LockSchemaFixtures malformedBodyLockContents
            label: 's10-12-body').
        rows add: (self lockRow: 'unparseable lock'
            contents: LockBoundaryFixtures unparseableLockContents
            label: 's10-12-parse').
        rows add: (self lockRow: 'wrong-tag lock'
            contents: LockBoundaryFixtures wrongTagLockContents
            label: 's10-12-tag').
        rows add: (self indexRow: 'malformed entry'
            contents: PublishFixtures entryMissingSummary
            file: 'entry.st' label: 's10-12-entry').
        rows add: (self indexRow: 'malformed retirement record'
            contents: RetirementFixtures recordWithShortTuple
            file: 'retired.st' label: 's10-12-record').
        rows add: (Array
            with: 'vocabulary typo'
            with: (self track: (LockBoundaryFixtures
                vocabularyTypoWorkDirNamed: 's10-12-typo-work'))
            with: (self freshDir: 's10-12-typo-index')
            with: 'resolve').
        rows add: (Array
            with: 'invalid declarations'
            with: (self track: (LockBoundaryFixtures
                invalidDeclarationWorkDirNamed: 's10-12-invalid-work'))
            with: (self freshDir: 's10-12-invalid-index')
            with: 'resolve').
        rows add: (Array
            with: 'missing Package.st'
            with: (self freshDir: 's10-12-missing-work')
            with: (self freshDir: 's10-12-missing-index')
            with: 'resolve').
        ^rows asArray
    ]

    lockRow: aLabel contents: aContentsString label: aDirLabel [
        "Private — a corpus row whose operator file is parley.lock; the
         index is empty because the lock is read before any source is
         consulted."
        | work |
        work := self diamondWorkDir: aDirLabel, '-work'.
        LockSchemaFixtures writeLockContents: aContentsString in: work.
        ^Array
            with: aLabel
            with: work
            with: (self freshDir: aDirLabel, '-index')
            with: 'install'
    ]

    indexRow: aLabel contents: aContentsString file: aBaseName label: aDirLabel [
        "Private — a corpus row whose operator file is an index
         artifact; the working directory's own Package.st is valid, so
         the only thing that can fail is the index."
        | index |
        index := self freshDir: aDirLabel, '-index'.
        SourceFixtures write: aContentsString toFile: aBaseName in: index.
        ^Array
            with: aLabel
            with: (self diamondWorkDir: aDirLabel, '-work')
            with: index
            with: 'resolve'
    ]
]

Namespace current: Smalltalk.
