"Parley Sprint 24 — argument preservation at the shell and CLI boundaries.
 Spec: architecture decision 91; scenarios S1 and S2.

 S1 observes raw bytes and argument count in a real shell child, not
 a second copy of the production encoder. S2 drives a NUL-bearing
 source URL through the real CLI with a recording runner: a failure
 after the runner was called is too late, even if it exits 1.

 DECLARED PASSES IN RED: none. The argument value is absent and the
 existing sparse composer passes the invalid URL to its runner.
 Every filesystem artifact belongs to tmp/ and is removed on failure."

Namespace current: Parley.

TestCase subclass: Sprint24ArgumentAcceptanceTest [
    | work |

    <comment: 'S1-S2: one shell word preserves every valid argument;
an unrepresentable URL is refused before the process seam is called.'>

    tearDown [
        work notNil ifTrue: [ExecFixtures removeTree: work]
    ]

    testS1_TheShellReceivesExactlyOneArgumentWithTheOriginalBytes [
        ShellArgumentFixtures assertRoundTripsFor: self
    ]

    testS2_ANulArgumentIsDiagnosedBeforeAnyChildIsInvoked [
        | runner result url |
        work := SourceFixtures directoryNamed: 's24-nul-url'.
        ExecFixtures writePackage:
            (ExecFixtures cOnlyRootContents: '^1.0') in: work.
        runner := RecordingRunner new.
        url := 'file:///unused/', (String with: (Character value: 0)),
            'index'.
        result := (CommandLine in: work runner: runner)
            run: (Array with: 'resolve' with: '--index' with: url).
        self assert: runner commands isEmpty
            description: 'an unrepresentable argument reached the process seam'.
        self assert: result exitCode = 1
            description: 'invalid argument input must be an exit-1 diagnosis'.
        self assert: result lines = #('command argument contains NUL')
            description: 'the NUL diagnosis must name the argument defect, not a failed child'
    ]
]

Namespace current: Smalltalk.
