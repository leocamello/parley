"Parley Sprint 24 — real execution argument acceptance (S3-S6, S12).
 S3-S6 drive the shipped shell wrapper. S12 executes the registration
 plan through a real runner. Each scenario is expected to fail in RED:
 unquoted paths currently split words or start an unterminated quote."

Namespace current: Parley.

TestCase subclass: Sprint24ExecutionAcceptanceTest [
    | fixtureDirs |

    <comment: 'Command argument preservation at the shipped execution
boundary, dependency/fileIn order, and registration stream/failure
contracts with paths containing spaces or apostrophes.'>

    setUp [ fixtureDirs := OrderedCollection new ]

    tearDown [
        fixtureDirs isNil ifTrue: [^self].
        fixtureDirs do: [:each | ExecFixtures removeTree: each].
        fixtureDirs := nil
    ]

    freshDir: aLabel [
        | path |
        path := 'tmp/parley-', aLabel.
        fixtureDirs add: path.
        "These fixtures create no read-only directories or symlinks.
         Use the recursive remover that tolerates an absent path."
        ExecFixtures removeTree: path.
        ^SourceFixtures directoryNamed: aLabel
    ]

    resolveIn: aWorkDir captures: aCaptureDir [
        | answer |
        answer := ExecutionArgumentFixtures runIn: aWorkDir
            argv: #('resolve') captures: aCaptureDir label: 'resolve'.
        self assert: (answer at: 1) = 0
            description: 'fixture resolve must succeed before execution'.
        self assert: (answer at: 3) = ''
            description: 'fixture resolve must have no stderr'
    ]

    probeStarBytes [
        "Track the settled builder's scratch before it starts, so a
         failed archive build is still cleaned by this test's teardown."
        #('tmp/parley-s24-12-probe-star-src' 'tmp/parley-s24-12-probe-star-out')
            do: [:each |
                fixtureDirs add: each.
                ExecFixtures removeTree: each].
        ^ExecFixtures probeStarBytesLabeled: 's24-12-probe'
    ]

    testS3_SpacedScriptRunsExactlyOnceThroughTheShippedBinary [
        | work captures answer |
        work := self freshDir: 's24-3-work'.
        captures := self freshDir: 's24-3-captures'.
        ExecFixtures writePackage: ExecFixtures noDependencyRootContents in: work.
        SourceFixtures
            write: (ExecutionArgumentFixtures scriptSaying: 'S24-SPACED-SCRIPT-RAN' exit: 0)
            toFile: 'hello world.st' in: work.
        self resolveIn: work captures: captures.
        answer := ExecutionArgumentFixtures runIn: work
            argv: #('exec' 'hello world.st') captures: captures label: 'exec'.
        self assert: (answer at: 1) = 0.
        self assert: (answer at: 2) = ('S24-SPACED-SCRIPT-RAN', SourceFixtures newline)
            description: 'the existing script must emit its sentinel exactly once'.
        self assert: (answer at: 3) = ''
    ]

    testS4_ApostropheAndSpaceScriptPropagatesExplicitExitSeven [
        | work captures answer |
        work := self freshDir: 's24-4-work'.
        captures := self freshDir: 's24-4-captures'.
        ExecFixtures writePackage: ExecFixtures noDependencyRootContents in: work.
        SourceFixtures
            write: (ExecutionArgumentFixtures scriptSaying: 'S24-EXIT-SEVEN-RAN' exit: 7)
            toFile: 'author''s script.st' in: work.
        self resolveIn: work captures: captures.
        answer := ExecutionArgumentFixtures runIn: work
            argv: #('exec' 'author''s script.st') captures: captures label: 'exec'.
        self assert: (answer at: 1) = 7
            description: 'exec must preserve the explicit child exit code'.
        self assert: (answer at: 2) = ('S24-EXIT-SEVEN-RAN', SourceFixtures newline).
        self assert: (answer at: 3) = ''
    ]

    testS5_ProjectRootWithSpaceAndApostropheExecutesSuccessfully [
        | work captures answer |
        work := self freshDir: 's24-5-author''s project'.
        captures := self freshDir: 's24-5-captures'.
        ExecFixtures writePackage: ExecFixtures noDependencyRootContents in: work.
        SourceFixtures
            write: (ExecutionArgumentFixtures scriptSaying: 'S24-PROJECT-ROOT-RAN' exit: 0)
            toFile: 'run.st' in: work.
        self resolveIn: work captures: captures.
        answer := ExecutionArgumentFixtures runIn: work
            argv: #('exec' 'run.st') captures: captures label: 'exec'.
        self assert: (answer at: 1) = 0.
        self assert: (answer at: 2) = ('S24-PROJECT-ROOT-RAN', SourceFixtures newline).
        self assert: (answer at: 3) = ''
    ]

    testS6_SpacedPathSourcesKeepDependencyAndDeclaredFileInOrder [
        | work captures base composite answer |
        work := self freshDir: 's24-6-work'.
        captures := self freshDir: 's24-6-captures'.
        base := self freshDir: 's24-6-base space'.
        composite := self freshDir: 's24-6-composite space'.
        ExecFixtures writePackage: ExecutionArgumentFixtures orderedRootContents in: work.
        ExecFixtures writePackage: ExecutionArgumentFixtures orderedBaseContents in: base.
        ExecFixtures writePackage: ExecutionArgumentFixtures orderedCompositeContents in: composite.
        SourceFixtures write: ExecutionArgumentFixtures orderedBaseSource
            toFile: 'Z Base.st' in: base.
        SourceFixtures write: ExecutionArgumentFixtures orderedFirstSource
            toFile: 'Z First.st' in: composite.
        SourceFixtures write: ExecutionArgumentFixtures orderedSecondSource
            toFile: 'A Second.st' in: composite.
        SourceFixtures write: 'Transcript showCr: S24ArgumentSecond token.
ObjectMemory quit: 0', SourceFixtures newline toFile: 'run.st' in: work.
        self resolveIn: work captures: captures.
        answer := ExecutionArgumentFixtures runIn: work
            argv: #('exec' 'run.st') captures: captures label: 'exec'.
        self assert: (answer at: 1) = 0.
        self assert: (answer at: 2) = ('base:first:second', SourceFixtures newline)
            description: 'load the dependency first and retain Z First before A Second'.
        self assert: (answer at: 3) = ''
    ]

    testS12_SpacedRegistrationSuppressesStdoutShowsStderrAndStopsOnFailure [
        | store target captures bytes badBytes tuples runner scope error expected |
        store := self freshDir: 's24-12-store space'.
        target := self freshDir: 's24-12-target space'.
        captures := self freshDir: 's24-12-captures'.
        bytes := self probeStarBytes.
        badBytes := InstallFixtures archiveBytesA.
        SourceFixtures write: bytes toFile: 'probe.star' in: store.
        SourceFixtures write: badBytes toFile: 'bad.star' in: store.
        SourceFixtures write: bytes toFile: 'later.star' in: store.
        tuples := Dictionary new.
        tuples at: 'parley-probe' put: (Array with: (Version fromString: '1.0.0')
            with: (Sha256 hexDigestOf: bytes) with: store, '/probe.star').
        tuples at: 'z-garbage' put: (Array with: (Version fromString: '1.0.0')
            with: (Sha256 hexDigestOf: badBytes) with: store, '/bad.star').
        tuples at: 'zz-never' put: (Array with: (Version fromString: '1.0.0')
            with: (Sha256 hexDigestOf: bytes) with: store, '/later.star').
        runner := ExecutionArgumentRecordingRunner capturingIn: captures.
        scope := ExecutionScope on: (InstalledSet tuples: tuples)
            target: target runner: runner.
        error := nil.
        [scope register.
         self assert: false description: 'expected the invalid archive to be rejected']
            on: ExecutionError do: [:each | error := each].
        self assert: runner commands size = 4
            description: 'register the first package, reject the second, never run the third'.
        expected := 'gst-package --target-directory ''tmp/parley-s24-12-target space'' ''tmp/parley-s24-12-target space/.parley-staging/z-garbage.star'''.
        self assert: error exitCode = 1.
        self assert: error command = expected.
        self assert: error messageText
            = (ExecFixtures executionErrorMessageFor: expected code: 1).
        self assert: runner commands last = (expected, ' > /dev/null').
        self assert: (File name: target, '/parley-probe.star') contents = bytes.
        self assert: (File name: target, '/.parley-staging/z-garbage.star') exists.
        self deny: (File name: target, '/z-garbage.star') exists.
        self deny: (File name: target, '/.parley-staging/zz-never.star') exists.
        self assert: runner stdout = ''
            description: 'successful plumbing must not leak its installation chatter'.
        self assert: (runner stderr indexOfSubCollection: 'gst-package:') > 0
            description: 'the rejecting child diagnostic must remain visible on stderr'
    ]
]

Namespace current: Smalltalk.
