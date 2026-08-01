"Parley Sprint 11 — acceptance scenarios S1-S13 from GitHub issue #13.
 Each scenario Sn maps to exactly one selector starting with testSn_
 (enforced by the wrap traceability gate).

 The milestone: THE TOOL LEARNS TO ANSWER QUESTIONS. Ten sprints built
 a package manager that resolves, installs, executes, publishes and
 can retire a release — and it cannot say why a package is pinned,
 what the graph looks like, or whether the project is still healthy.
 Three inspection verbs close that: why walks the pinned graph in
 reverse and narrates each chain from the root (S1-S3), tree renders
 the graph forward (S4), and check delivers a truthful health verdict
 — lock validity, pin satisfaction, and retirement, which is Sprint
 10's unread retirementReasonFor:version: finally reaching a human
 (S5-S7, §8 decision 37 discharged).

 Two proofs bound what the verbs ARE (Doc E §4.1): they change nothing
 — byte-identity of every file, no process spawned (S8) — and they
 never enter the resolver, because the graph comes from the lock plus
 the snapshot via the settled IndexSnapshot dependenciesOf:version:,
 never from a re-resolution that would explain a world the operator is
 not running (S9, §8 decision 40).

 The second half closes the gaps this sprint makes cheap: the lock's
 #sha256 and the entry's #archive digest gain a shape check — 64
 lowercase hex — through ONE predicate in the new SchemaShape, whose
 admission rule (Doc B §7.1) is exactly the two-caller trigger Sprint
 10 named: CLI and DirectorySource each kept a private string
 predicate, and the third caller ends the duplication (S10-S12, §8
 decisions 41-42). And the drift law's textual anchor is hardened
 against a line-split sender, with its claim bounded in writing to
 what a textual search can prove (S13, §8 decision 43 and the
 decision-38 correction).

 DECLARED PASSES IN RED (issue #13): NONE in this file. The declared
 passes for this sprint are the guards in the law suites
 (InspectionVerbTest testResolveStillTripsTheResolverTrap,
 testAnInspectionVerbWithoutASourceAnswersUsage and
 testAWrongArityInspectionVerbAnswersUsage, and LockSchemaTest
 testAnEmptyLockDigestStaysAccepted), each declared in its own class
 comment.

 No scenario spawns bin/parley-main.st and none runs git — the first
 sprint in four with no child process in its acceptance set. S8's
 recording runner is the proof that stays true. No test contacts a
 network, ever.

 Every fixture path is under tmp/, unique per test, removed
 recursively in tearDown; the developer image is never mutated."

Namespace current: Parley.

TestCase subclass: Sprint11AcceptanceTest [
    | fixtureDirs |

    <comment: 'Acceptance scenarios for Sprint 11: the why/tree/check
inspection verbs, the read-only and resolver-purity proofs, the
SchemaShape predicate dedup, hex-digest validation at the lock and
#archive boundaries, and the hardened line-split drift law.'>

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

    pinnedWorkDir: aLabel [
        ^self track: (InspectionFixtures pinnedInspectionWorkDirNamed: aLabel)
    ]

    inspectionIndex: aLabel [
        | path |
        path := self freshDir: aLabel.
        InspectionFixtures populateInspectionIndexIn: path.
        ^path
    ]

    lockPathIn: aWorkDir [
        ^aWorkDir, '/parley.lock'
    ]

    resultOf: anArgvArray in: aWorkDir [
        ^(CommandLine in: aWorkDir runner: RecordingRunner new)
            run: anArgvArray
    ]

    whyOf: aName in: aWorkDir source: anIndexDir [
        ^self resultOf: (Array
            with: 'why' with: aName
            with: '--source' with: anIndexDir) in: aWorkDir
    ]

    treeIn: aWorkDir source: anIndexDir [
        ^self resultOf: (Array
            with: 'tree' with: '--source' with: anIndexDir) in: aWorkDir
    ]

    checkIn: aWorkDir source: anIndexDir [
        ^self resultOf: (Array
            with: 'check' with: '--source' with: anIndexDir) in: aWorkDir
    ]

    trapCliIn: aWorkDir source: anIndexDir [
        "The S9 double on the verb's REAL path: everything a real CLI
         is, except that resolveAndLock: signals."
        ^ResolverTrapCLI
            in: aWorkDir
            source: (DirectorySource on: anIndexDir)
            store: (ContentStore on: (CommandLineFixtures storeRootIn: aWorkDir))
            target: (CommandLineFixtures targetDirIn: aWorkDir)
            runner: RecordingRunner new
    ]

    problemsFrom: aBlock [
        "Evaluate the block expecting a SourceError; answer its
         batched problems."
        | caught |
        caught := nil.
        aBlock on: SourceError do: [:e | caught := e].
        self deny: caught isNil
            description: 'expected a SourceError and none was signalled'.
        ^caught problems
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

    "---- S1-S3: why ----"

    testS1_WhyExplainsADiamond [
        "Two chains, sorted and byte-stable, each hop naming the
         constraint that demanded the next."
        | work index result |
        work := self pinnedWorkDir: 's11-s1-work'.
        index := self inspectionIndex: 's11-s1-index'.
        result := self whyOf: 'kernel-c' in: work source: index.
        self assert: result exitCode = 0.
        self assert: result lines = InspectionFixtures whyKernelCLines
    ]

    testS2_WhyOnARootOnlyDependencyIsOneChain [
        | work index result |
        work := self pinnedWorkDir: 's11-s2-work'.
        index := self inspectionIndex: 's11-s2-index'.
        result := self whyOf: 'kernel-a' in: work source: index.
        self assert: result exitCode = 0.
        self assert: result lines = InspectionFixtures whyKernelALines
    ]

    testS3_WhyOnAnUnpinnedPackageIsADiagnosis [
        "The operator's question about a package they do not have —
         never a defect, never exit 70."
        | work index result |
        work := self pinnedWorkDir: 's11-s3-work'.
        index := self inspectionIndex: 's11-s3-index'.
        result := self whyOf: 'kernel-nonexistent' in: work source: index.
        self assert: result exitCode = 1.
        self assert: result lines = (Array with:
            (InspectionFixtures notPinnedLineFor: 'kernel-nonexistent')).
        self denyBlamesParley: result
    ]

    "---- S4: tree ----"

    testS4_TreeRendersThePinnedGraph [
        "Root first, two-space indent per level, name and version per
         node, children sorted, the shared node marked as a repeat at
         its second site."
        | work index result |
        work := self pinnedWorkDir: 's11-s4-work'.
        index := self inspectionIndex: 's11-s4-index'.
        result := self treeIn: work source: index.
        self assert: result exitCode = 0.
        self assert: result lines = InspectionFixtures treeLines.
        self assert: ((result lines at: result lines size)
            endsWith: InspectionFixtures repeatMarker)
            description: 'the shared node is not marked at its second site'
    ]

    "---- S5-S7: check ----"

    testS5_CheckAnswersOneHealthyLine [
        | work index result |
        work := self pinnedWorkDir: 's11-s5-work'.
        index := self inspectionIndex: 's11-s5-index'.
        result := self checkIn: work source: index.
        self assert: result exitCode = 0.
        self assert: result lines
            = (Array with: InspectionFixtures healthyLine)
    ]

    testS6_CheckReportsAStalePin [
        "The PinVerification problems as lines — the settled value
         consumed, never re-worded."
        | work index result |
        work := self freshDir: 's11-s6-work'.
        index := self freshDir: 's11-s6-index'.
        InstallFixtures populateInstallDiamondIn: index.
        ExecFixtures writePackage: (ExecFixtures cOnlyRootContents: '^2.0')
            in: work.
        ExecFixtures writeLock: ExecFixtures lockPinningC15String in: work.
        result := self checkIn: work source: index.
        self assert: result exitCode = 1.
        self assert: result lines = (Array with:
            'lock pins ''c'' at 1.5.0 outside the manifest constraint >=2.0.0 <3.0.0')
    ]

    testS7_CheckReportsARetiredPinWithTheAuthorsReason [
        "Sprint 10's retirement schema reaching a human for the first
         time (§8 decision 37): the author's reason travels VERBATIM."
        | work index result |
        work := self track:
            (RetirementFixtures jsonRootWorkDirNamed: 's11-s7-work').
        index := self freshDir: 's11-s7-index'.
        RetirementFixtures populateRetiredIndexIn: index.
        ExecFixtures writeLock: RetirementFixtures lockPinningJson032String
            in: work.
        result := self checkIn: work source: index.
        self assert: result exitCode = 1.
        self assert: result lines
            = (Array with: InspectionFixtures retiredJson032Line).
        self assert: (CommandLineFixtures does: (result lines at: 1)
            include: RetirementFixtures json032Reason)
            description: 'the author''s reason did not travel verbatim'
    ]

    "---- S8: the inspection verbs change nothing ----"

    testS8_TheInspectionVerbsChangeNothing [
        "Byte-identity of the whole working directory and the whole
         index, proved by digesting every file before and after — 'no
         exception was raised' proves nothing about writes. The
         recording runner proves no process was spawned."
        | work index runner before beforeIndex line result |
        work := self pinnedWorkDir: 's11-s8-work'.
        index := self inspectionIndex: 's11-s8-index'.
        runner := RecordingRunner new.
        before := InspectionFixtures digestTreeOf: work.
        beforeIndex := InspectionFixtures digestTreeOf: index.
        line := CommandLine in: work runner: runner.
        result := line run: (Array
            with: 'why' with: 'kernel-c' with: '--source' with: index).
        self assert: result exitCode = 0.
        result := line run: (Array
            with: 'tree' with: '--source' with: index).
        self assert: result exitCode = 0.
        result := line run: (Array
            with: 'check' with: '--source' with: index).
        self assert: result exitCode = 0.
        self assert: (InspectionFixtures digestTreeOf: work) = before
            description: 'an inspection verb changed the working directory'.
        self assert: (InspectionFixtures digestTreeOf: index) = beforeIndex
            description: 'an inspection verb changed the index'.
        self assert: runner commands isEmpty
            description: 'an inspection verb spawned: ', runner commands printString
    ]

    "---- S9: why and tree never enter the resolver ----"

    testS9_WhyAndTreeNeverEnterTheResolver [
        "A CLI whose resolveAndLock: signals — and both verbs succeed
         through it, proving the graph came from the lock plus the
         snapshot, not from a re-resolution (§8 decision 40). The
         guard that the trap sits on the verb's REAL path is
         InspectionVerbTest testResolveStillTripsTheResolverTrap."
        | work index cli result |
        work := self pinnedWorkDir: 's11-s9-work'.
        index := self inspectionIndex: 's11-s9-index'.
        cli := self trapCliIn: work source: index.
        result := cli run: #('why' 'kernel-c').
        self assert: result exitCode = 0.
        self assert: result lines = InspectionFixtures whyKernelCLines.
        result := cli run: #('tree').
        self assert: result exitCode = 0.
        self assert: result lines = InspectionFixtures treeLines
    ]

    "---- S10-S11: the digest grounds ----"

    testS10_AMalformedLockDigestIsALockDiagnosisNotACorruptionReport [
        "One LockError naming the path and the malformed digest — and
         the settled corruption wording does NOT appear, because the
         store was never reached (§8 decision 42)."
        | work index result |
        work := self track:
            (CommandLineFixtures diamondRootWorkDirNamed: 's11-s10-work').
        index := self freshDir: 's11-s10-index'.
        LockSchemaFixtures
            writeLockContents: InspectionFixtures malformedDigestLockString
            in: work.
        result := self resultOf:
            (Array with: 'install' with: '--source' with: index) in: work.
        self assert: result exitCode = 1.
        self assert: result lines = (Array with:
            (InspectionFixtures malformedLockDigestProblemFor:
                (self lockPathIn: work))).
        result lines do: [:line |
            self deny: (CommandLineFixtures does: line
                include: 'store corruption')
                description: 'the digest defect read as corruption: ', line].
        self denyBlamesParley: result
    ]

    testS11_AMalformedEntryDigestIsABatchedScanProblem [
        "One SourceError whose problems include the pinned digest
         defect, batched in sorted-filename order with any other scan
         problem — the digest ground joins the batch, it does not
         preempt it."
        | dir problems |
        dir := self freshDir: 's11-s11-index'.
        SourceFixtures write: InspectionFixtures badDigestEntryContents
            toFile: 'aa-bad.st' in: dir.
        SourceFixtures write: '#(#''parley-index'' 1 #name)'
            toFile: 'zz-bad.st' in: dir.
        problems := self problemsFrom: [(DirectorySource on: dir) snapshot].
        self assert: problems size = 2.
        self assert: (problems at: 1)
            = (InspectionFixtures badDigestProblemFor: 'aa-bad.st').
        self assert: ((problems at: 2) startsWith: 'zz-bad.st: ')
    ]

    "---- S12: one predicate, two validators ----"

    testS12_OnePredicateTwoValidators [
        "The corpus verdicts hold through SchemaShape — the ONE
         definition both validators consume — and neither validator
         implements the predicate itself: the duplication is gone,
         provable by the single definition (Doc B §7.1)."
        InspectionFixtures hexDigestCorpus do: [:row |
            self assert: (SchemaShape isHexDigest: (row at: 1)) = (row at: 2)
                description: 'isHexDigest: misjudged ', (row at: 1) printString].
        InspectionFixtures stringCorpus do: [:row |
            self assert: (SchemaShape isString: (row at: 1)) = (row at: 2)
                description: 'isString: misjudged ', (row at: 1) printString].
        self deny: (CLI includesSelector: #isLockString:)
            description: 'CLI still carries its private string predicate'.
        self deny: (DirectorySource includesSelector: #isSchemaString:)
            description: 'DirectorySource still carries its private string predicate'.
        self deny: (DirectorySource includesSelector: #isSchemaStringArray:)
            description: 'DirectorySource still carries its private string-array predicate'
    ]

    "---- S13: the drift law survives a line-split sender ----"

    testS13_TheDriftLawSurvivesALineSplitSender [
        "A fixture source in which 'IndexEntryReader' and 'readFrom:'
         are split across two lines is still reported as a sender —
         and the settled pinned-answer guard still holds against the
         real src/ (§8 decision 43; claim bounded per the decision-38
         correction: this is a textual search, hardened against
         whitespace, nothing stronger)."
        | root found |
        root := self freshDir: 's11-s13-src'.
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
]

Namespace current: Smalltalk.
