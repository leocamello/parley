"Parley Sprint 11 — laws for the inspection verbs (issue #13; Doc E
 §4.1 'The three inspection verbs' and §5).

 Three verbs that READ AND EXPLAIN, never change anything: why, tree
 and check. All three load the manifest, read parley.lock through the
 §4.1 validated boundary, and take the source's snapshot — they are
 allowed to consult the index precisely because none of them is
 install, whose fast path is law-bound not to (§8 decision 37). None
 writes a file, spawns a process, or mutates the store.

 WHERE THE GRAPH COMES FROM (§8 decision 40). why and tree walk the
 LOCK PLUS THE SNAPSHOT, never the ConstraintLedger — the ledger is
 transient and Resolution keeps no edges. Re-resolving to rebuild
 provenance would explain a world the operator is not running. The
 edges come from the settled IndexSnapshot>>dependenciesOf:version:;
 the root's own edges come from its manifest. The purity law below
 proves it with a resolver trap on the verb's REAL path.

 check IS THE PLACE RETIREMENT FINALLY REACHES THE OPERATOR (§8
 decision 37 named it): Sprint 10's retirementReasonFor:version: was
 written, tested and read by nothing in src/ until this verb. A
 retired pin is a PROBLEM, not a warning — check exists to be run in
 CI, and an exit code that ignores a retirement would make the verb
 useless for the one job it has.

 DECLARED PASSES IN RED (issue #13):
   testResolveStillTripsTheResolverTrap — the trap-correctness guard:
     ResolverTrapCLI overrides resolveAndLock:, the one funnel through
     which resolve reaches the resolver, so resolve signals through it
     TODAY. Without this guard the purity law could pass against a
     trap that sits on no path at all — a double that cannot spring
     proves nothing.
   testAnInspectionVerbWithoutASourceAnswersUsage — in red the argv is
     simply unknown, and unknown argv already answers usage; the law
     earns its keep in green, where it pins that the three verbs are
     SOURCE-REQUIRING rather than merely known.
   testAWrongArityInspectionVerbAnswersUsage — the same ground: wrong
     arity is unknown argv today and must STAY usage once the verbs
     exist, which is exactly what the law pins.
 Every other law here fails against the pre-sprint tree: the verbs do
 not exist, so each answers the usage lines at exit 2 where a
 rendering at exit 0 or a diagnosis at exit 1 is asserted.

 Every fixture path is under tmp/, unique per test, removed
 recursively in tearDown; nothing here spawns (recording runners
 everywhere) and no network is contacted."

Namespace current: Parley.

TestCase subclass: InspectionVerbTest [
    | fixtureDirs |

    <comment: 'Laws for parley why, parley tree and parley check: the
pinned renderings over the inspection diamond, the check verdicts in
order (lock exists and validates, PinVerification holds, nothing
pinned is retired), the read-only proof, the resolver-purity proof,
and the argv grammar rows.'>

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

    "---- why ----"

    testWhyExplainsTheDiamondChains [
        | work index result |
        work := self pinnedWorkDir: 'ivt-why-diamond-work'.
        index := self inspectionIndex: 'ivt-why-diamond-index'.
        result := self whyOf: 'kernel-c' in: work source: index.
        self assert: result exitCode = 0.
        self assert: result lines = InspectionFixtures whyKernelCLines
    ]

    testWhyOnARootOnlyDependencyIsOneChain [
        | work index result |
        work := self pinnedWorkDir: 'ivt-why-root-work'.
        index := self inspectionIndex: 'ivt-why-root-index'.
        result := self whyOf: 'kernel-a' in: work source: index.
        self assert: result exitCode = 0.
        self assert: result lines = InspectionFixtures whyKernelALines
    ]

    testWhyOnAnUnpinnedPackageIsADiagnosis [
        "The operator's question about a package they do not have —
         exit 1 naming it, never a defect and never exit 70."
        | work index result |
        work := self pinnedWorkDir: 'ivt-why-absent-work'.
        index := self inspectionIndex: 'ivt-why-absent-index'.
        result := self whyOf: 'kernel-nonexistent' in: work source: index.
        self assert: result exitCode = 1.
        self assert: result lines = (Array with:
            (InspectionFixtures notPinnedLineFor: 'kernel-nonexistent'))
    ]

    "---- tree ----"

    testTreeRendersThePinnedGraph [
        | work index result |
        work := self pinnedWorkDir: 'ivt-tree-work'.
        index := self inspectionIndex: 'ivt-tree-index'.
        result := self treeIn: work source: index.
        self assert: result exitCode = 0.
        self assert: result lines = InspectionFixtures treeLines
    ]

    "---- check, verdict by verdict and in order ----"

    testCheckAnswersOneHealthyLine [
        | work index result |
        work := self pinnedWorkDir: 'ivt-check-healthy-work'.
        index := self inspectionIndex: 'ivt-check-healthy-index'.
        result := self checkIn: work source: index.
        self assert: result exitCode = 0.
        self assert: result lines
            = (Array with: InspectionFixtures healthyLine)
    ]

    testCheckReportsAMissingLock [
        "The first verdict: no lock at all. The repair is resolve —
         the verb that writes a FIRST lock — not update, the repair
         for a corrupt one."
        | work index result |
        work := self track:
            (InspectionFixtures inspectionWorkDirNamed: 'ivt-check-nolock-work').
        index := self inspectionIndex: 'ivt-check-nolock-index'.
        result := self checkIn: work source: index.
        self assert: result exitCode = 1.
        self assert: result lines
            = (Array with: InspectionFixtures missingLockLine)
    ]

    testCheckReportsAnInvalidLock [
        "The lock read is the settled §4.1 boundary, consumed
         unchanged: an unparseable lock is the settled LockError
         diagnosis at exit 1, never exit 70."
        | work index result |
        work := self track:
            (InspectionFixtures inspectionWorkDirNamed: 'ivt-check-badlock-work').
        index := self inspectionIndex: 'ivt-check-badlock-index'.
        LockBoundaryFixtures
            writeLockContents: LockBoundaryFixtures unparseableLockContents
            in: work.
        result := self checkIn: work source: index.
        self assert: result exitCode = 1.
        self assert: result lines = (Array with:
            (LockBoundaryFixtures unparseableLockProblemFor:
                (self lockPathIn: work)))
    ]

    testCheckReportsAStalePin [
        "The second verdict: the PinVerification problems as lines —
         the settled value consumed, never re-worded."
        | work index result |
        work := self freshDir: 'ivt-check-stale-work'.
        index := self freshDir: 'ivt-check-stale-index'.
        InstallFixtures populateInstallDiamondIn: index.
        ExecFixtures writePackage: (ExecFixtures cOnlyRootContents: '^2.0')
            in: work.
        ExecFixtures writeLock: ExecFixtures lockPinningC15String in: work.
        result := self checkIn: work source: index.
        self assert: result exitCode = 1.
        self assert: result lines = (Array with:
            'lock pins ''c'' at 1.5.0 outside the manifest constraint >=2.0.0 <3.0.0')
    ]

    testCheckReportsARetiredPin [
        "The third verdict, and the sprint's point: the unread
         accessor finally read. The author's reason travels VERBATIM."
        | work index result |
        work := self track:
            (RetirementFixtures jsonRootWorkDirNamed: 'ivt-check-retired-work').
        index := self freshDir: 'ivt-check-retired-index'.
        RetirementFixtures populateRetiredIndexIn: index.
        ExecFixtures writeLock: RetirementFixtures lockPinningJson032String
            in: work.
        result := self checkIn: work source: index.
        self assert: result exitCode = 1.
        self assert: result lines
            = (Array with: InspectionFixtures retiredJson032Line)
    ]

    testCheckIsHealthyAgainstTheLiveIndexControl [
        "The control: the SAME pinned release against the live index
         is healthy — so the retired verdict above can only have come
         from the retirement record."
        | work index result |
        work := self track:
            (RetirementFixtures jsonRootWorkDirNamed: 'ivt-check-live-work').
        index := self freshDir: 'ivt-check-live-index'.
        RetirementFixtures populateLiveIndexIn: index.
        ExecFixtures writeLock: RetirementFixtures lockPinningJson032String
            in: work.
        result := self checkIn: work source: index.
        self assert: result exitCode = 0.
        self assert: result lines
            = (Array with: InspectionFixtures healthyLine)
    ]

    "---- the purity proof (§8 decision 40) ----"

    testResolveStillTripsTheResolverTrap [
        "DECLARED PASS IN RED (issue #13) — the trap-correctness
         guard: resolve reaches the resolver through resolveAndLock:
         TODAY, so the trap provably sits on the real path. A double
         that cannot spring proves nothing."
        | work index sprung |
        work := self pinnedWorkDir: 'ivt-trap-guard-work'.
        index := self inspectionIndex: 'ivt-trap-guard-index'.
        sprung := false.
        [(self trapCliIn: work source: index) run: #('resolve')]
            on: Error
            do: [:e |
                sprung := true.
                self assert: e messageText = ResolverTrapCLI trapMessage].
        self assert: sprung
            description: 'resolve never reached resolveAndLock: — the trap sits on no path'
    ]

    testWhyAndTreeNeverEnterTheResolver [
        "The graph comes from the lock plus the snapshot: both verbs
         succeed through a CLI that CANNOT resolve."
        | work index cli result |
        work := self pinnedWorkDir: 'ivt-purity-work'.
        index := self inspectionIndex: 'ivt-purity-index'.
        cli := self trapCliIn: work source: index.
        result := cli run: #('why' 'kernel-c').
        self assert: result exitCode = 0.
        self assert: result lines = InspectionFixtures whyKernelCLines.
        result := cli run: #('tree').
        self assert: result exitCode = 0.
        self assert: result lines = InspectionFixtures treeLines
    ]

    "---- the read-only proof ----"

    testTheInspectionVerbsChangeNothing [
        "Byte-identity of the whole working directory and the whole
         index, proved by digesting every file before and after — 'no
         exception was raised' proves nothing about writes. The
         recording runner proves no process was spawned."
        | work index runner before beforeIndex line result |
        work := self pinnedWorkDir: 'ivt-readonly-work'.
        index := self inspectionIndex: 'ivt-readonly-index'.
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

    "---- the argv grammar ----"

    testTheUsageNamesTheInspectionVerbs [
        "The verbs: line of the pinned usage answer must name all
         three. Asserted against the CLI's OWN answer, not against
         ExecFixtures usageLines — that settled fixture is re-pinned
         in GREEN together with the CLI change, because re-pinning it
         in red would fail every settled usage law first."
        | result |
        result := self resultOf: #() in: (self freshDir: 'ivt-usage-work').
        self assert: result exitCode = 2.
        self assert: (GrammarFixtures verbsRowIn: result lines)
            = InspectionFixtures usageVerbsLine
    ]

    testAnInspectionVerbWithoutASourceAnswersUsage [
        "DECLARED PASS IN RED (issue #13) — see the class comment. All
         three verbs take the source's snapshot, so all three are
         source-requiring: without a flag they answer the usage lines
         at exit 2, exactly as resolve does."
        | work |
        work := self freshDir: 'ivt-nosource-work'.
        (Array
            with: (Array with: #('why' 'kernel-c') with: 'why')
            with: (Array with: #('tree') with: 'tree')
            with: (Array with: #('check') with: 'check')) do: [:row |
                | result |
                result := self resultOf: (row at: 1) in: work.
                self assert: result exitCode = 2.
                self assert: result lines = (GrammarFixtures
                    usageAnswerFor: #needsIndex subject: (row at: 2))
                    description: (row at: 1) printString, ' answered ',
                        result lines printString]
    ]

    testAWrongArityInspectionVerbAnswersUsage [
        "DECLARED PASS IN RED (issue #13) — see the class comment.
         why without a package, tree and check with a stray argument:
         unknown argv, the settled usage answer — and it must stay
         that way once the verbs exist."
        | work index |
        work := self pinnedWorkDir: 'ivt-arity-work'.
        index := self inspectionIndex: 'ivt-arity-index'.
        (Array
            with: (Array
                with: (Array with: 'why' with: '--source' with: index)
                with: 'why')
            with: (Array
                with: (Array with: 'tree' with: 'extra'
                    with: '--source' with: index)
                with: 'tree')
            with: (Array
                with: (Array with: 'check' with: 'extra'
                    with: '--source' with: index)
                with: 'check')) do: [:row |
                    | result |
                    result := self resultOf: (row at: 1) in: work.
                    self assert: result exitCode = 2.
                    self assert: result lines = (GrammarFixtures
                        usageAnswerFor: #wrongArguments subject: (row at: 2))
                        description: (row at: 1) printString, ' answered ',
                            result lines printString]
    ]
]

Namespace current: Smalltalk.
