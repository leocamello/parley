"Sprint 26 / issue #28: the official gate must reject incomplete loading
 in both phases. Each child runs a tiny trusted checkout, never this suite.
 S1/S2 isolate the vanished-selector defect with exactly one surviving test.
 S5/S6 and S10 are declared old-gate passes: ordinary GREEN, ordinary RED,
 and the already-enforced unvisited-test census remain meaningful.
 S7 rejects the old whole-output phrase scan; runtime output is legitimate.
 S8 also requires the runner's actual diagnostic to survive formatting.
 Cost: sixteen child verifier invocations, each with at most one test."

Namespace current: Parley.

TestCase subclass: Sprint26AcceptanceTest [
    | fixtureDirs |

    setUp [ fixtureDirs := OrderedCollection new ]

    tearDown [
        fixtureDirs isNil ifTrue: [^self].
        fixtureDirs do: [:each | ExecFixtures removeTree: each].
        fixtureDirs := nil
    ]

    checkout: aLabel phase: aPhase [
        | root |
        root := VerifierFixtures checkoutNamed: aLabel, '-', aPhase phase: aPhase.
        fixtureDirs add: root.
        ^root
    ]

    assert: aResult includes: aFragment [
        "Never include child output in failure descriptions: it carries
         nested protocol markers and deliberate compiler diagnostics."
        self assert: (CommandLineFixtures does: (aResult at: 2) include: aFragment)
            description: 'child output omitted the required evidence'
    ]

    assertRejected: aResult [
        self deny: (aResult at: 1) = 0
            description: 'the gate accepted an incomplete load'.
        self assert: aResult includes: '<execution_feedback status="FAILED"'.
        self deny: (CommandLineFixtures does: (aResult at: 2)
            include: 'Verification passed.')
            description: 'a refused load reported GREEN success'.
        self deny: (CommandLineFixtures does: (aResult at: 2)
            include: 'Red gate satisfied:')
            description: 'a refused load reported RED success'
    ]

    assertAccepted: aResult phase: aPhase [
        self assert: (aResult at: 1) = 0
            description: 'the gate refused a clean runnable suite'.
        aPhase = 'green'
            ifTrue: [
                self assert: aResult includes: 'Verification passed.'.
                self assert: aResult includes: 'run=1 passed=1 failed=0 errors=0']
            ifFalse: [
                self assert: aResult includes: 'Red gate satisfied:'.
                self assert: aResult includes: 'run=1 passed=0 failed=1 errors=0']
    ]

    assertMalformedTestRejectedIn: aPhase label: aLabel [
        | root result path |
        root := self checkout: aLabel phase: aPhase.
        path := 'tests/laws/ZBrokenTest.st'.
        VerifierFixtures write: VerifierFixtures malformedTest at: path in: root.
        result := VerifierFixtures runIn: root phase: aPhase.
        self assertRejected: result.
        self assert: result includes: path.
        self assert: result includes: 'expected true, false or nil'
    ]

    testS1_GreenRejectsAMalformedTestDespiteThePassingSurvivor [
        self assertMalformedTestRejectedIn: 'green' label: 's1'
    ]

    testS2_RedRejectsAMalformedTestDespiteTheFailingSurvivor [
        self assertMalformedTestRejectedIn: 'red' label: 's2'
    ]

    testS3_BothPhasesRejectMalformedSource [
        #('green' 'red') do: [:phase |
            | root result path |
            root := self checkout: 's3' phase: phase.
            path := 'src/domain/BrokenSource.st'.
            VerifierFixtures write: VerifierFixtures malformedSource at: path in: root.
            result := VerifierFixtures runIn: root phase: phase.
            self assertRejected: result.
            self assert: result includes: path.
            self assert: result includes: 'expected true, false or nil']
    ]

    testS4_BothPhasesRejectAnExceptionWhileLoading [
        #('green' 'red') do: [:phase |
            | root result path |
            root := self checkout: 's4' phase: phase.
            path := 'tests/laws/ZRaisingTest.st'.
            VerifierFixtures write: VerifierFixtures loadException at: path in: root.
            result := VerifierFixtures runIn: root phase: phase.
            self assertRejected: result.
            self assert: result includes: path.
            self assert: result includes: 'harness load-time probe']
    ]

    testS5_CleanGreenRunsAndPassesOneTest [
        | root |
        root := self checkout: 's5' phase: 'green'.
        self assertAccepted: (VerifierFixtures runIn: root phase: 'green') phase: 'green'
    ]

    testS6_CleanRedRunsAndAcceptsOneAssertionFailure [
        | root |
        root := self checkout: 's6' phase: 'red'.
        self assertAccepted: (VerifierFixtures runIn: root phase: 'red') phase: 'red'
    ]

    testS7_BothPhasesAllowDiagnosticTextDuringTestExecution [
        #('green' 'red') do: [:phase |
            | root result |
            root := self checkout: 's7' phase: phase.
            VerifierFixtures write: (VerifierFixtures healthyTestFor: phase
                runtimeText: VerifierFixtures runtimeDiagnostics)
                at: VerifierFixtures healthyPath in: root.
            result := VerifierFixtures runIn: root phase: phase.
            self assertAccepted: result phase: phase.
            self assert: result includes: 'runtime-probe.st:1: parse error'.
            self assert: result includes: 'runtime-probe.st:2: expected true, false or nil']
    ]

    testS8_BothPhasesRejectAndExplainAMalformedRunner [
        #('green' 'red') do: [:phase |
            | root result |
            root := self checkout: 's8' phase: phase.
            VerifierFixtures write: VerifierFixtures malformedRunner
                at: 'scripts/run-tests.st' in: root.
            result := VerifierFixtures runIn: root phase: phase.
            self assertRejected: result.
            self assert: result includes: 'scripts/run-tests.st'.
            self assert: result includes: 'expected true, false or nil']
    ]

    testS9_BothPhasesRequireLoadCompletionBeforeTrustingTheResult [
        #('green' 'red') do: [:phase |
            | root result |
            root := self checkout: 's9' phase: phase.
            VerifierFixtures write: (VerifierFixtures runnerWithoutLoadCompletionFor: phase)
                at: 'scripts/run-tests.st' in: root.
            result := VerifierFixtures runIn: root phase: phase.
            self assertRejected: result]
    ]

    testS10_BothPhasesStillRefuseATestOutsideTheLoadDirectories [
        #('green' 'red') do: [:phase |
            | root result |
            root := self checkout: 's10' phase: phase.
            Directory create: root, '/tests/unvisited'.
            VerifierFixtures write: '"A trusted fixture outside the runner''s directory list."'
                at: 'tests/unvisited/OmittedTest.st' in: root.
            result := VerifierFixtures runIn: root phase: phase.
            self assertRejected: result.
            self assert: result includes: '1 of 2 test files']
    ]
]

Namespace current: Smalltalk.
