"Parley Sprint 24 — execution argument fixtures (S3-S6, S12).
 The outer harness uses the kernel's existing shell escaping only for
 ordinary space/apostrophe fixture paths. It never consumes the new
 production encoder, so a broken encoder cannot repair its own oracle.
 Every child is launched through ProcessRunner; captures are test-only."

Namespace current: Parley.

Object subclass: ExecutionArgumentFixtures [

    <comment: 'Shipped-wrapper execution and ordered path-package
fixtures for Sprint 24. All caller-owned paths live under tmp/.'>

    ExecutionArgumentFixtures class >> runIn: aWorkDir argv: arguments captures: aCaptureDir label: aLabel [
        "Drive the actual bin/parley entry point, pinning source
         configuration and capturing its two streams independently."
        | outPath errPath command code |
        outPath := CommandLineFixtures absolutePathOf:
            aCaptureDir, '/', aLabel, '.out'.
        errPath := CommandLineFixtures absolutePathOf:
            aCaptureDir, '/', aLabel, '.err'.
        command := WriteStream on: String new.
        command
            nextPutAll: 'cd ';
            nextPutAll: (CommandLineFixtures absolutePathOf: aWorkDir) withShellEscapes;
            nextPutAll: ' && ';
            nextPutAll: EnvFixtures pinnedEmptyPrefix;
            nextPutAll: 'PARLEY_ROOT=';
            nextPutAll: CommandLineFixtures repoRoot withShellEscapes;
            nextPut: Character space;
            nextPutAll: (CommandLineFixtures repoRoot, '/bin/parley') withShellEscapes.
        arguments do: [:each |
            command nextPut: Character space;
                nextPutAll: each withShellEscapes].
        command nextPutAll: ' > '; nextPutAll: outPath withShellEscapes;
            nextPutAll: ' 2> '; nextPutAll: errPath withShellEscapes.
        code := ProcessRunner new run: command contents.
        ^Array with: code
            with: (File name: outPath) contents
            with: (File name: errPath) contents
    ]

    ExecutionArgumentFixtures class >> scriptSaying: aSentinel exit: anExitCode [
        ^'Transcript showCr: ''', aSentinel, '''.
ObjectMemory quit: ', anExitCode printString, SourceFixtures newline
    ]

    ExecutionArgumentFixtures class >> orderedRootContents [
        ^'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''0.1.0'';
        fileIns: #(''App.st'');
        dependency: ''alpha-composite'' path: ''../parley-s24-6-composite space'' ]',
            SourceFixtures newline
    ]

    ExecutionArgumentFixtures class >> orderedCompositeContents [
        "Both package and source order oppose alphabetical order."
        ^'Parley define: [:pkg |
    pkg
        name: ''alpha-composite'';
        version: ''1.0.0'';
        fileIns: #(''Z First.st'' ''A Second.st'');
        dependency: ''zeta-base'' path: ''../parley-s24-6-base space'' ]',
            SourceFixtures newline
    ]

    ExecutionArgumentFixtures class >> orderedBaseContents [
        ^'Parley define: [:pkg |
    pkg
        name: ''zeta-base'';
        version: ''1.0.0'';
        fileIns: #(''Z Base.st'') ]', SourceFixtures newline
    ]

    ExecutionArgumentFixtures class >> orderedBaseSource [
        ^'Object subclass: S24ArgumentBase [
    S24ArgumentBase class >> token [ ^''base'' ]
]', SourceFixtures newline
    ]

    ExecutionArgumentFixtures class >> orderedFirstSource [
        ^'S24ArgumentBase subclass: S24ArgumentFirst [
    S24ArgumentFirst class >> token [ ^super token, '':first'' ]
]', SourceFixtures newline
    ]

    ExecutionArgumentFixtures class >> orderedSecondSource [
        ^'S24ArgumentFirst subclass: S24ArgumentSecond [
    S24ArgumentSecond class >> token [ ^super token, '':second'' ]
]', SourceFixtures newline
    ]
]

Object subclass: ExecutionArgumentRecordingRunner [
    | commands stdoutPath stderrPath |

    <comment: 'Test-only real runner that records commands and captures
their streams outside a shell group. Grouping preserves an inner stdout
discard, so the test observes the production redirect rather than
overriding it. ProcessRunner remains the only process-spawning seam.'>

    ExecutionArgumentRecordingRunner class >> capturingIn: aDirectory [
        ^self new initializeIn: aDirectory
    ]

    initializeIn: aDirectory [
        <category: 'private'>
        commands := OrderedCollection new.
        stdoutPath := aDirectory, '/plumbing.out'.
        stderrPath := aDirectory, '/plumbing.err'.
        SourceFixtures write: '' toFile: 'plumbing.out' in: aDirectory.
        SourceFixtures write: '' toFile: 'plumbing.err' in: aDirectory.
        ^self
    ]

    run: aCommand [
        commands add: aCommand.
        ^ProcessRunner new run: '{ ', aCommand, '; } >> ',
            stdoutPath withShellEscapes, ' 2>> ', stderrPath withShellEscapes
    ]

    commands [ ^commands asArray ]
    stdout [ ^(File name: stdoutPath) contents ]
    stderr [ ^(File name: stderrPath) contents ]
]

Namespace current: Smalltalk.
