"Parley Sprint 24 — real transport fixtures for S7-S11.

 Every path is beneath a per-scenario tmp/ root. Git setup is local,
 with per-command identity; no network or developer configuration is
 changed. Fixture shell arguments use the kernel's withShellEscapes
 ONLY for these controlled space/apostrophe paths. That independent
 setup mechanism is never an oracle for ShellArgument or a production
 command. These fixtures deliberately make no tab/newline claim for
 gst-package, whose internal filename encoding has a separate limit."

Namespace current: Parley.

Object subclass: TransportArgumentFixtures [

    <comment: 'Stateless fixture setup for real registration,
publication, git clone/pull and file-URL sparse transport. The
production commands are exercised unchanged through ProcessRunner.'>

    TransportArgumentFixtures class >> freshRootNamed: aLabel [
        <category: 'paths'>
        | relative |
        relative := 'tmp/parley-', aLabel.
        ExecFixtures removeTree: relative.
        ^CommandLineFixtures absolutePathOf:
            (SourceFixtures directoryNamed: aLabel)
    ]

    TransportArgumentFixtures class >> directory: aName in: aParent [
        <category: 'paths'>
        | path |
        path := aParent, '/', aName.
        Directory create: path.
        ^path
    ]

    TransportArgumentFixtures class >> fixtureWord: aString [
        "Independent harness quoting for the controlled fixture
         names; never compare this answer with a production command."
        <category: 'private-process setup'>
        ^aString withShellEscapes
    ]

    TransportArgumentFixtures class >> probeArchiveLabeled: aLabel [
        "Reuse the settled real archive builder, with cleanup also
         guaranteed when its build or read fails."
        <category: 'archive fixtures'>
        | source output |
        source := 'tmp/parley-', aLabel, '-star-src'.
        output := 'tmp/parley-', aLabel, '-star-out'.
        ExecFixtures removeTree: source.
        ExecFixtures removeTree: output.
        ^[ExecFixtures probeStarBytesLabeled: aLabel]
            ensure: [
                ExecFixtures removeTree: source.
                ExecFixtures removeTree: output]
    ]

    TransportArgumentFixtures class >> runSetup: aCommand [
        <category: 'private-process setup'>
        | code |
        code := ProcessRunner new run: aCommand.
        code = 0 ifFalse: [
            self error: 'transport fixture setup failed with exit ',
                code printString, ': ', aCommand].
        ^code
    ]

    TransportArgumentFixtures class >> commitIn: aRepo message: aWord [
        <category: 'git fixtures'>
        | prefix |
        prefix := 'git -C ', (self fixtureWord: aRepo), ' '.
        self runSetup: prefix, 'add -A'.
        ^self runSetup: prefix, PublishFixtures gitIdentity,
            ' -c commit.gpgsign=false commit -q -m ',
            (self fixtureWord: aWord)
    ]

    TransportArgumentFixtures class >> diamondRepositoryAt: aRepo [
        <category: 'git fixtures'>
        self runSetup: 'git init -q ', (self fixtureWord: aRepo).
        InstallFixtures populateInstallDiamondIn: aRepo.
        self commitIn: aRepo message: 'diamond'.
        ^aRepo
    ]

    TransportArgumentFixtures class >> clone: aRepo to: aCache [
        "S10 starts with an already-populated cache, independently of
         the production cold-clone path exercised by S9."
        <category: 'git fixtures'>
        ^self runSetup: 'git clone --quiet -- ',
            (self fixtureWord: aRepo), ' ', (self fixtureWord: aCache)
    ]

    TransportArgumentFixtures class >> growRepositoryAt: aRepo [
        <category: 'git fixtures'>
        SourceFixtures write: SourceFixtures lateEntryDContents
            toFile: 'd-1.0.0.st' in: aRepo.
        ^self commitIn: aRepo message: 'grow'
    ]

    TransportArgumentFixtures class >> fileUrlFor: anAbsolutePath [
        "URI encoding belongs to the fixture URL, not shell argument
         encoding. Only these controlled path characters need escaping."
        <category: 'sparse fixtures'>
        | out |
        out := WriteStream on: String new.
        out nextPutAll: 'file://'.
        anAbsolutePath do: [:each |
            each = Character space
                ifTrue: [out nextPutAll: '%20']
                ifFalse: [each = (Character value: 39)
                    ifTrue: [out nextPutAll: '%27']
                    ifFalse: [out nextPut: each]]].
        ^out contents
    ]
]

Object subclass: TransportCaptureRunner [
    | stdoutPath stderrPath |

    <comment: 'A real runner with separately captured stdout/stderr
for a single transport invocation. It delegates all spawning to
ProcessRunner and does not rewrite the command under test.'>

    TransportCaptureRunner class >> in: aRoot [
        <category: 'instance creation'>
        ^self new setRoot: aRoot
    ]

    setRoot: aRoot [
        <category: 'private'>
        stdoutPath := aRoot, '/transport-stdout.txt'.
        stderrPath := aRoot, '/transport-stderr.txt'
    ]

    run: aCommand [
        <category: 'runner protocol'>
        ^ProcessRunner new run: '( ', aCommand, ' ) > ',
            (TransportArgumentFixtures fixtureWord: stdoutPath),
            ' 2> ', (TransportArgumentFixtures fixtureWord: stderrPath)
    ]

    stdoutContents [
        <category: 'accessing'>
        ^(File name: stdoutPath) contents
    ]

    stderrContents [
        <category: 'accessing'>
        ^(File name: stderrPath) contents
    ]
]

Namespace current: Smalltalk.
