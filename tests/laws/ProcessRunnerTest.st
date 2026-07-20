"Parley Sprint 6 — ProcessRunner real-execution laws (issue #8 S1/S2;
 Doc E §1).

 The runner is the ONE process seam in all of Parley: run: executes a
 command string via the kernel's Smalltalk system: and answers the
 child's exit code, normalized from the raw wait status (status //
 256). The code is an answer, never a signal — its meaning belongs to
 the caller.

 These laws spawn real children (trivial shell commands, no
 filesystem contact). In the red phase every test fails on the
 missing ProcessRunner class before anything could spawn."

Namespace current: Parley.

TestCase subclass: ProcessRunnerTest [

    <comment: 'Real exit-code laws for ProcessRunner: a child exiting
7 answers exactly 7, success answers exactly 0, and the status // 256
normalization holds across distinct codes.'>

    testRunAnswersTheChildsExitCode [
        self assert: (ProcessRunner new run: 'exit 7') = 7
    ]

    testRunAnswersZeroForSuccess [
        self assert: (ProcessRunner new run: 'true') = 0
    ]

    testRunNormalizesDistinctExitCodesExactly [
        self assert: (ProcessRunner new run: 'exit 3') = 3.
        self assert: (ProcessRunner new run: 'exit 1') = 1
    ]
]

Namespace current: Smalltalk.
