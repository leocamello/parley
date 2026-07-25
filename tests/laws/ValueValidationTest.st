"Parley Sprint 8 — value-shape validation in the DirectorySource scan
 (issue #10 S12-S14; Doc F §4.1 — a declared settled-class exception).

 Shape validation asks whether a field is a string; it never asked
 whether the string MEANS anything. So a #version 'banana' —
 shape-perfect — still escaped the scan as a raw error. That was the
 last place a malformed entry crashed instead of diagnosing, and it
 closes here: with these laws green, a directory source has no
 remaining way to crash on third-party content.

 Protocol decisions pinned here (posted on issue #10 for confirmation):
   - the wordings are CommandLineFixtures
     unparseableVersionProblemFor:value: and
     unparseableConstraintProblemFor:dependency:value:, in the grammar
     of their §4 shape siblings — each names the file and the
     unparseable value, and the constraint one also names the
     dependency it belongs to;
   - ONE problem per file, as always: the first defect a file has is
     the one the operator is told about;
   - validation runs AFTER the §4 shape checks and BEFORE duplicate
     detection, which needs a parsed version to compare — the ordering
     is observable (testAnUnparseableVersionIsNeverAlsoADuplicate);
   - the settled Version fromString: and VersionConstraint fromString:
     are CONSUMED unchanged and stay the single definition of what
     parses. Validation asks them; it never re-implements them.

 DECLARED PASSES IN RED (issue #10), both regression guards on the
 settled §4 shape validation rather than new behaviour:
   - testAShapeDefectIsReportedBeforeAValueDefect — the shape check
     already answers this file's problem today; the law exists to
     pin that the new check does not move ahead of it;
   - testAValueValidDirectoryStillScans — a wholly valid directory
     already scans; the law exists to pin that the new check adds no
     false positive.

 No process is spawned and no fixture leaves tmp/."

Namespace current: Parley.

TestCase subclass: ValueValidationTest [
    | fixtureDirs |

    <comment: 'Laws for value-shape validation in the DirectorySource
scan: an unparseable #version, an unparseable dependency constraint,
their batching alongside every settled problem shape in sorted-filename
order, and the ordering that keeps a value problem from masquerading as
a duplicate.'>

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

    problemsFrom: aBlock [
        "The problems array of the SourceError aBlock signals; fails
         when no error, or a non-SourceError, is signaled — a raw
         error escaping the scan IS the defect these laws close."
        [aBlock value.
         self assert: false description: 'expected a SourceError']
            on: Error
            do: [:e |
                self assert: (e isKindOf: SourceError)
                    description: 'expected a SourceError, got ', e class name.
                ^e problems].
        ^#()
    ]

    scanProblemsIn: aDirPath [
        ^self problemsFrom: [(DirectorySource on: aDirPath) snapshot]
    ]

    versionStringsOf: aCollection [
        ^((aCollection collect: [:each | each printString])
            asSortedCollection: [:a :b | a <= b]) asArray
    ]

    "---- S12: an unparseable #version ----"

    testAnUnparseableVersionIsOneBatchedProblem [
        | dir problems |
        dir := self freshDir: 'vv-version'.
        SourceFixtures write: CommandLineFixtures entryWithUnparseableVersion
            toFile: 'p-1.0.0.st' in: dir.
        problems := self scanProblemsIn: dir.
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = (CommandLineFixtures unparseableVersionProblemFor: 'p-1.0.0.st'
                value: CommandLineFixtures unparseableVersionValue)
    ]

    "---- S13: an unparseable dependency constraint ----"

    testAnUnparseableConstraintIsOneBatchedProblem [
        | dir problems |
        dir := self freshDir: 'vv-constraint'.
        SourceFixtures write: CommandLineFixtures entryWithUnparseableConstraint
            toFile: 'p-1.0.0.st' in: dir.
        problems := self scanProblemsIn: dir.
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = (CommandLineFixtures
                unparseableConstraintProblemFor: 'p-1.0.0.st'
                dependency: 'q'
                value: CommandLineFixtures unparseableConstraintValue)
    ]

    testTheOffendingDependencyIsTheOneNamed [
        "A file whose FIRST dependency parses and whose second does
         not names the second — the problem points at the defect that
         is actually there."
        | dir problems |
        dir := self freshDir: 'vv-second'.
        SourceFixtures
            write: CommandLineFixtures entryWithUnparseableSecondConstraint
            toFile: 'p-1.0.0.st' in: dir.
        problems := self scanProblemsIn: dir.
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = (CommandLineFixtures
                unparseableConstraintProblemFor: 'p-1.0.0.st'
                dependency: 'r'
                value: CommandLineFixtures unparseableConstraintValue)
    ]

    "---- ordering: values are checked before duplicates ----"

    testAnUnparseableVersionIsNeverAlsoADuplicate [
        "Duplicate detection needs a PARSED version to compare, so
         value validation must run first: two files with the same
         unparseable version are two value problems, never one value
         problem and one duplicate."
        | dir problems |
        dir := self freshDir: 'vv-order'.
        SourceFixtures write: CommandLineFixtures entryWithUnparseableVersion
            toFile: 'aa-p.st' in: dir.
        SourceFixtures write: CommandLineFixtures entryWithUnparseableVersion
            toFile: 'bb-p.st' in: dir.
        problems := self scanProblemsIn: dir.
        self assert: problems size = 2.
        self assert: (problems at: 1)
            = (CommandLineFixtures unparseableVersionProblemFor: 'aa-p.st'
                value: CommandLineFixtures unparseableVersionValue).
        self assert: (problems at: 2)
            = (CommandLineFixtures unparseableVersionProblemFor: 'bb-p.st'
                value: CommandLineFixtures unparseableVersionValue)
    ]

    testAShapeDefectIsReportedBeforeAValueDefect [
        "Shape first, value second: a file that violates both answers
         the SHAPE problem — the settled §4 diagnoses are unchanged
         around the new one."
        | dir problems |
        dir := self freshDir: 'vv-shape-first'.
        SourceFixtures write: PublishFixtures entryWithIntegerVersion
            toFile: 'p-1.0.0.st' in: dir.
        problems := self scanProblemsIn: dir.
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = (PublishFixtures scalarKindProblemFor: 'p-1.0.0.st'
                key: #version)
    ]

    "---- S14: every problem kind batches, and clean dirs still scan ----"

    testEveryProblemKindBatchesInSortedFilenameOrder [
        | bad clean problems snap |
        bad := self freshDir: 'vv-batch-bad'.
        CommandLineFixtures populateEveryProblemKindIn: bad.
        problems := self scanProblemsIn: bad.
        self assert: problems = CommandLineFixtures everyProblemKindProblems.
        clean := self freshDir: 'vv-batch-clean'.
        SourceFixtures populateDiamondIn: clean.
        snap := (DirectorySource on: clean) snapshot.
        self assert: (self versionStringsOf: (snap versionsOf: 'c'))
            = #('1.5.0' '2.4.0' '3.0.0')
    ]

    testAValueValidDirectoryStillScans [
        "The new check adds no false positive: a directory whose
         values all parse answers a working snapshot, dependencies
         included."
        | dir snap |
        dir := self freshDir: 'vv-valid'.
        SourceFixtures write: PublishFixtures validEntryP
            toFile: 'p-1.0.0.st' in: dir.
        snap := (DirectorySource on: dir) snapshot.
        self assert: (self versionStringsOf: (snap versionsOf: 'p'))
            = #('1.0.0').
        self assert: (snap dependenciesOf: 'p'
            version: (Version fromString: '1.0.0')) size = 1
    ]
]

Namespace current: Smalltalk.
