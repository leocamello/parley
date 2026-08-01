"Parley Sprint 10 — the lock body/value laws (issue #12; Doc E §4.1
 and §5), the third rejection ground of the lock boundary.

 Sprint 9 gave parley.lock two rejection grounds, and both are
 SYNTACTIC: a file that does not parse, and a file that is not a
 #'parley-lock' 1 artifact. A lock that passes both and has a MALFORMED
 BODY — `#(#'parley-lock' 1 #root 'my-app')`, one hand-edit away —
 reached Resolution fromLockEntry: and died there as a KERNEL
 SystemExceptions.NotFound, answered with exit 70: 'this is a defect in
 Parley, not in your project.' The same sentence, on the same file,
 that the lock boundary exists to abolish (§8 decision 35).

 The §4.2 closed-set law was structurally blind to it, because that law
 enumerates PARLEY error classes and this one is the kernel's. So the
 answer is not another error class: it is validating the SHAPE before
 the constructor sees the value. Resolution fromLockEntry: stays
 trusting and unchanged — it is fed only values this boundary has
 accepted, exactly as LibraryManifest fromIndexEntry: is fed only
 entries the scan validated.

 ONE PROBLEM PER LOCKFILE, first defect found. The operator is
 repairing one file, not auditing it, and the repair — parley update —
 is the same regardless. That is deliberately unlike the directory
 scan, which batches: a scan reports on many files an operator does not
 own, a lock is one file they do.

 The value check is the Doc F §4.1 lesson applied here: a shape check
 never asks whether a string MEANS anything, so a shape-perfect lock
 with a version of 'banana' is still a diagnosis, and the settled
 Version fromString: is what decides — consumed, never re-implemented.

 DECLARED PASSES IN RED (issue #12), two of them:
   testALockParleyWroteItselfAlwaysPasses — the guard that the new
     validation is not over-eager. A validation that rejected valid
     input would be a worse defect than the one being fixed, and the
     guard must run from the first day. It proves the claim against the
     SETTLED WRITER'S OWN OUTPUT (resolve writes the lock, install reads
     it back) rather than a hand-copied literal, because a hand-copied
     oracle only ever proves that the copy was faithful.
   testTheTagCheckStillDecidesBeforeTheBodyCheck — the ordering guard.
     A wrong-tag lock must keep its settled wrong-tag diagnosis; if the
     body check ran first it would answer a body defect about a file
     whose real problem is that it is an index entry.
 Every other law in this file fails against the pre-sprint tree.

 SPRINT 11 (issue #13, §8 decision 42) adds the digest ground: each
 #sha256 must be 64 lowercase hex characters — the shape a sha256
 renders as under §5.4 — validated through SchemaShape isHexDigest:
 (Doc B §7.1). Shape only, never truth: whether a digest matches its
 bytes stays ContentStore>>verifyHash:. The laws of that ground live
 at the bottom of this file; one of them,
 testAnEmptyLockDigestStaysAccepted, is a DECLARED PASS IN RED (issue
 #13) — the guard that the new validation is not over-eager, because
 the settled writer renders an archiveless pin as #sha256 '' and a
 boundary that rejected it would reject Parley's own output. The
 malformedLockRows walk above is NOT extended in red — the walk is a
 settled law that must keep passing, and a row whose rejection does
 not exist yet would fail it; the fold was carried to GREEN at the
 review and the digest row now closes the walk.

 Every fixture path is under tmp/, unique per test, removed recursively
 in tearDown; nothing here spawns and no network is contacted."

Namespace current: Parley.

TestCase subclass: LockSchemaTest [
    | fixtureDirs |

    <comment: 'Laws for the third lock rejection ground: body-shape and
value-shape validation in CLI>>pinnedResolution, before
Resolution fromLockEntry: sees the value. Each violation is one
LockError naming the path, the defect and parley update.'>

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

    lockPathIn: aWorkDir [
        ^aWorkDir, '/parley.lock'
    ]

    contentsOf: aPath [
        ^(File name: aPath) contents
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

    resultOf: anArgvArray in: aWorkDir [
        "Through the composition root, where a diagnosis becomes an exit
         code — a lock problem must be exit 1, never 70."
        ^(CommandLine in: aWorkDir runner: RecordingRunner new)
            run: anArgvArray
    ]

    lockErrorFrom: aBlock [
        "Run aBlock, require it to signal a LockError specifically —
         which is itself the claim that Resolution fromLockEntry: was
         never reached with an unvalidated value, since reaching it is
         what used to answer a KERNEL error instead."
        [aBlock value.
         self assert: false description: 'expected a LockError']
            on: Error
            do: [:e |
                self assert: (e isKindOf: LockError)
                    description: 'expected a LockError, got ',
                        e class name asString.
                ^e].
        ^nil
    ]

    installProblemsIn: aWorkDir index: anIndexDir [
        ^(self lockErrorFrom: [
            (self cliIn: aWorkDir source: (DirectorySource on: anIndexDir))
                run: #('install')]) problems
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

    "---- the body-shape grounds ----"

    testEachBodyShapeViolationIsOnePinnedLockProblem [
        "Every §4.1 shape violation — a missing key, keys out of the
         §5.4 order, an unknown key, a body that does not pair up, a
         non-String #root, a non-Array #packages, a tuple of the wrong
         arity, a missing #sha256 marker, a non-String field — one
         LockError problem each, naming the path, the defect and the
         repair."
        | work index lockPath |
        work := self diamondWorkDir: 'lock-shape-work'.
        index := self freshDir: 'lock-shape-index'.
        lockPath := self lockPathIn: work.
        LockSchemaFixtures malformedLockRows do: [:row |
            | problems |
            LockSchemaFixtures writeLockContents: (row at: 1) in: work.
            problems := self installProblemsIn: work index: index.
            self assert: problems size = 1
                description: 'expected exactly one problem, got ',
                    problems printString.
            self assert: (problems at: 1) = ((row at: 2) value: lockPath)
                description: 'unexpected problem: ', (problems at: 1)]
    ]

    testAMalformedBodyIsALockErrorAndNotAKernelError [
        "THE REPRODUCTION, at the level where the disease was visible: it
         used to be SystemExceptions.NotFound — a kernel error nothing
         in Parley had declared — and the boundary answered it with exit
         70. Now it is a LockError carrying the batched house-style
         message its siblings carry."
        | work index error expected |
        work := self diamondWorkDir: 'lock-kernel-work'.
        index := self freshDir: 'lock-kernel-index'.
        LockSchemaFixtures
            writeLockContents: LockSchemaFixtures malformedBodyLockContents
            in: work.
        error := self lockErrorFrom: [
            (self cliIn: work source: (DirectorySource on: index))
                run: #('install')].
        expected := LockBoundaryFixtures lockErrorMessageFor: (Array with:
            (LockSchemaFixtures missingLockKeyProblemFor:
                (self lockPathIn: work) key: #packages)).
        self assert: error messageText = expected
    ]

    testAMalformedBodyLockIsExitOneAndNeverExitSeventy [
        | work index result |
        work := self diamondWorkDir: 'lock-exit-work'.
        index := self freshDir: 'lock-exit-index'.
        LockSchemaFixtures
            writeLockContents: LockSchemaFixtures malformedBodyLockContents
            in: work.
        result := self resultOf:
            (Array with: 'install' with: '--source' with: index) in: work.
        self assert: result exitCode = 1.
        self assert: result lines = (Array with:
            (LockSchemaFixtures missingLockKeyProblemFor:
                (self lockPathIn: work) key: #packages)).
        self denyBlamesParley: result
    ]

    "---- the value-shape ground (the Doc F §4.1 lesson) ----"

    testAnUnparseableVersionInAShapePerfectLockIsOneProblem [
        | work index problems |
        work := self diamondWorkDir: 'lock-value-work'.
        index := self freshDir: 'lock-value-index'.
        LockSchemaFixtures
            writeLockContents:
                LockSchemaFixtures unparseableVersionLockContents
            in: work.
        problems := self installProblemsIn: work index: index.
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = (LockSchemaFixtures unparseableLockVersionProblemFor:
                (self lockPathIn: work)
                value: LockSchemaFixtures unparseableVersionValue
                package: LockSchemaFixtures unparseableVersionPackage)
    ]

    testTheLockDiagnosisAlwaysNamesThePathAndTheRepair [
        "The settled three-part shape holds for the new ground too: which
         file, what is wrong, what to do. A defect wording that forgot
         the repair would leave the operator with nowhere to go."
        | work index lockPath |
        work := self diamondWorkDir: 'lock-advice-work'.
        index := self freshDir: 'lock-advice-index'.
        lockPath := self lockPathIn: work.
        LockSchemaFixtures malformedLockRows do: [:row |
            | problem |
            LockSchemaFixtures writeLockContents: (row at: 1) in: work.
            problem := (self installProblemsIn: work index: index) at: 1.
            self assert: (CommandLineFixtures does: problem
                include: lockPath).
            self assert: (CommandLineFixtures does: problem
                include: 'parley update')]
    ]

    "---- the two guards (declared passes in red) ----"

    testALockParleyWroteItselfAlwaysPasses [
        "DECLARED PASS IN RED (issue #12) — see the class comment. The
         oracle is the SETTLED WRITER'S OWN OUTPUT: resolve writes the
         lock, install reads it back and must use it. Proving this
         against a hand-copied literal would prove only that the copy
         was faithful."
        | work index resolved installed |
        work := self diamondWorkDir: 'lock-written-work'.
        index := self freshDir: 'lock-written-index'.
        InstallFixtures populateInstallDiamondIn: index.
        resolved := self resultOf:
            (Array with: 'resolve' with: '--source' with: index) in: work.
        self assert: resolved exitCode = 0.
        installed := self resultOf:
            (Array with: 'install' with: '--source' with: index) in: work.
        self assert: installed exitCode = 0.
        self assert: installed lines = CommandLineFixtures diamondPinLines.
        self assert: (self contentsOf: (self lockPathIn: work))
            = ExecFixtures diamondLockString
    ]

    testTheTagCheckStillDecidesBeforeTheBodyCheck [
        "DECLARED PASS IN RED (issue #12) — the ordering guard. An index
         entry in parley.lock has no #packages either, so a body check
         running first would answer a body defect about a file whose
         real problem is that it is the wrong artifact entirely."
        | work index problems |
        work := self diamondWorkDir: 'lock-order-work'.
        index := self freshDir: 'lock-order-index'.
        LockBoundaryFixtures
            writeLockContents: LockBoundaryFixtures wrongTagLockContents
            in: work.
        problems := self installProblemsIn: work index: index.
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = (LockBoundaryFixtures wrongTagLockProblemFor:
                (self lockPathIn: work))
    ]

    "---- the digest ground (Sprint 11, issue #13, §8 decision 42) ----"

    testAMalformedLockDigestIsALockDiagnosis [
        "S10's value half: a lock correct in every shape whose #sha256
         is not 64 lowercase hex is one LockError naming the path, the
         digest and the repair — a shape defect of the operator's file,
         diagnosed at the boundary, never a corruption report from a
         store that was never reached."
        | work index problems |
        work := self diamondWorkDir: 'lock-digest-work'.
        index := self freshDir: 'lock-digest-index'.
        LockSchemaFixtures
            writeLockContents: InspectionFixtures malformedDigestLockString
            in: work.
        problems := self installProblemsIn: work index: index.
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = (InspectionFixtures malformedLockDigestProblemFor:
                (self lockPathIn: work))
    ]

    testAMalformedLockDigestNeverReadsAsCorruption [
        "The settled corruption wording must NOT appear: corruption is
         a store entry that no longer verifies, and the store was
         never reached — decision 42's whole point is that the two
         diagnoses stay distinct."
        | work index result |
        work := self diamondWorkDir: 'lock-digest-exit-work'.
        index := self freshDir: 'lock-digest-exit-index'.
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

    testAnEmptyLockDigestStaysAccepted [
        "DECLARED PASS IN RED (issue #13) — see the class comment. The
         settled writer renders an archiveless pin as #sha256 '', so
         the digest ground must accept the empty string or Parley
         rejects its own output. The pin passes the boundary and the
         verification fast path, and the '' digest reaches the SETTLED
         Installer diagnosis — never a LockError. ASSUMPTION posted on
         issue #13: Doc B §5.3 names only the 64-hex shape, and ''
         is admitted here as the writer's own rendering of absence."
        | work index result |
        work := self freshDir: 'lock-empty-digest-work'.
        index := self freshDir: 'lock-empty-digest-index'.
        ExecFixtures writePackage: (ExecFixtures cOnlyRootContents: '^2.0')
            in: work.
        ExecFixtures writeLock: InspectionFixtures emptyDigestLockString
            in: work.
        result := self resultOf:
            (Array with: 'install' with: '--source' with: index) in: work.
        self assert: result exitCode = 1.
        self assert: result lines = (Array with:
            'c 2.4.0: no published archive - the resolution carries an empty sha256').
        result lines do: [:line |
            self deny: (CommandLineFixtures does: line
                include: 'parley update')
                description: 'the empty digest was rejected at the lock boundary: ', line]
    ]
]

Namespace current: Smalltalk.
