"Parley Sprint 24 — the argument error belongs to the message boundary.
 Spec: architecture decision 91 and Doc E section 6.

 The declaration law reads the production table. The handling law
 injects the new error through the existing raising-runner seam so it
 cannot pass merely because the table spells the class name.
 DECLARED PASSES IN RED: none. No production behavior is supplied by
 this test file and no settled oracle is changed during RED."

Namespace current: Parley.

TestCase subclass: CommandArgumentBoundaryTest [
    | work |

    <comment: 'Argument construction failures are user-input diagnoses,
never internal defects and never invented process exit statuses.'>

    tearDown [
        work notNil ifTrue: [ExecFixtures removeTree: work]
    ]

    testCommandArgumentErrorIsDeclaredAsAMessageError [
        self assert: ((CommandLineFixtures namesOf:
            CommandLine messageErrorClasses) includes: 'CommandArgumentError')
            description: 'the new error is missing from the message-error boundary'
    ]

    testTheBoundaryPreservesTheArgumentErrorMessageAtExitOne [
        | errorClass runner result |
        errorClass := (Smalltalk at: #Parley)
            hereAt: #CommandArgumentError ifAbsent: [nil].
        self deny: errorClass isNil
            description: 'CommandArgumentError is not implemented'.
        work := SourceFixtures directoryNamed: 's24-argument-boundary'.
        SourceFixtures write: (ExecFixtures quitScriptContentsFor: 0)
            toFile: 'script.st' in: work.
        runner := RaisingRunner raising:
            [errorClass signal: 'command argument contains NUL'].
        result := (CommandLine in: work runner: runner)
            run: #('exec' 'script.st').
        self assert: runner commands size = 1
            description: 'the fixture did not reach the diagnosis boundary'.
        self assert: result exitCode = 1
            description: 'a declared argument error became an internal defect'.
        self assert: result lines = #('command argument contains NUL')
            description: 'the boundary changed the argument diagnosis'
    ]
]

Namespace current: Smalltalk.
