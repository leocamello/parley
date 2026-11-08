"Sprint 26 / issue #28: isolated copies of the official verification gate.
 Each child checkout contains one healthy test and only the trusted probe
 under examination. It never copies this suite, so invoking the copied
 verifier cannot recursively run the repository's tests. All generated
 code and captured output stay under tmp/ and are removed by the caller."

Namespace current: Parley.

Object subclass: VerifierFixtures [

    <comment: 'Tiny trusted checkouts for the real shell gate and SUnit
runner. Command strings are values; ProcessRunner remains the only
process seam. Child diagnostics are captured rather than printed into
the parent verifier protocol.'>

    VerifierFixtures class >> checkoutNamed: aLabel phase: aPhase [
        <category: 'directories'>
        | root |
        ExecFixtures removeTree: 'tmp/parley-verifier-', aLabel.
        root := SourceFixtures directoryNamed: 'verifier-', aLabel.
        #('scripts' '.parley' 'src' 'src/domain' 'tests' 'tests/laws')
            do: [:relative | Directory create: root, '/', relative].
        #('scripts/verify-sprint.sh' 'scripts/run-tests.st') do: [:relative |
            self write: (File name: relative) contents at: relative in: root].
        self write: 'phase: ', aPhase, SourceFixtures newline
            at: '.parley/scope' in: root.
        self write: (self healthyTestFor: aPhase runtimeText: '')
            at: self healthyPath in: root.
        ^root
    ]

    VerifierFixtures class >> write: aText at: aRelativePath in: aRoot [
        <category: 'directories'>
        SourceFixtures write: aText toFile: aRelativePath in: aRoot
    ]

    VerifierFixtures class >> healthyPath [
        <category: 'probes'>
        ^'tests/laws/AHealthyTest.st'
    ]

    VerifierFixtures class >> healthyTestFor: aPhase runtimeText: aText [
        "The explicit namespace recovers from a preceding malformed
         source file. The single survivor independently passes GREEN
         or fails RED, so disappearance of another test cannot save it."
        <category: 'probes'>
        ^'Namespace current: Parley.
TestCase subclass: HarnessHealthyTest [
    testSurvives [
', aText, '
        self assert: ', (aPhase = 'green' ifTrue: ['true'] ifFalse: ['false']), '
    ]
]
Namespace current: Smalltalk.
'
    ]

    VerifierFixtures class >> malformedTest [
        "The S25 defect: the first selector never compiles, yet
         FileStream fileIn: returns and the old runner marks the file
         loaded. The earlier AHealthyTest leaves exactly one test."
        <category: 'probes'>
        ^'Namespace current: Parley.
TestCase subclass: HarnessOmittedTest [
    testWasOmitted [ self assert: #(locked) size = 1 ]
]
Namespace current: Smalltalk.
'
    ]

    VerifierFixtures class >> malformedSource [
        <category: 'probes'>
        ^'Namespace current: Parley.
Object subclass: HarnessMalformedSource [
    value [ ^#(locked) ]
]
Namespace current: Smalltalk.
'
    ]

    VerifierFixtures class >> loadException [
        <category: 'probes'>
        ^'Error signal: ''harness load-time probe''.', SourceFixtures newline
    ]

    VerifierFixtures class >> runtimeDiagnostics [
        "These are legitimate output from an executing test, after
         loading finished. Neither spelling may poison load integrity."
        <category: 'probes'>
        ^'        Transcript showCr: ''runtime-probe.st:1: parse error''.
        FileStream stderr nextPutAll: ''runtime-probe.st:2: expected true, false or nil'',
            (String with: Character nl).
        FileStream stderr flush.'
    ]

    VerifierFixtures class >> malformedRunner [
        <category: 'probes'>
        ^'| broken | broken := #(locked).', SourceFixtures newline
    ]

    VerifierFixtures class >> runnerWithoutLoadCompletionFor: aPhase [
        "A truncated protocol, not a replacement implementation: every
         old success condition is present but loading never completes.
         This independent fixture keeps missing completion fail-closed."
        <category: 'probes'>
        ^'Transcript showCr: ''PARLEY-SEED: 20260718''.
Transcript showCr: ''PARLEY-LOAD: tests/laws/AHealthyTest.st''.
Transcript showCr: ''PARLEY-TESTFILE: tests/laws/AHealthyTest.st''.
Transcript showCr: ''PARLEY-VERIFY: ',
            (aPhase = 'green'
                ifTrue: ['PASS seed=20260718 run=1 passed=1 failed=0 errors=0']
                ifFalse: ['FAIL seed=20260718 run=1 passed=0 failed=1 errors=0']), '''.
ObjectMemory quit: ', (aPhase = 'green' ifTrue: ['0'] ifFalse: ['1']), '.
'
    ]

    VerifierFixtures class >> commandIn: aRoot phase: aPhase outputTo: anOutputPath [
        <category: 'commands'>
        ^'bash ', (ShellArgument fromString:
            (CommandLineFixtures absolutePathOf: aRoot, '/scripts/verify-sprint.sh')) shellString,
            ' --phase ', (ShellArgument fromString: aPhase) shellString,
            ' --seed 20260718 > ',
            (ShellArgument fromString: anOutputPath) shellString, ' 2>&1'
    ]

    VerifierFixtures class >> runIn: aRoot phase: aPhase [
        <category: 'running'>
        | outputPath code |
        outputPath := CommandLineFixtures absolutePathOf: aRoot, '/output.log'.
        code := ProcessRunner new run:
            (self commandIn: aRoot phase: aPhase outputTo: outputPath).
        ^Array with: code with: (File name: outputPath) contents
    ]
]

Namespace current: Smalltalk.
