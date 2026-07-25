"Parley Sprint 8 — the shipped binary as the product (issue #10
 S9-S10; Doc E §4.3 and §5).

 These are the only laws that test glue, and they exist because glue
 that chooses an exit code is not glue. Sprint 7 closed the ecosystem
 loop in the test suite; through bin/parley-main.st it did not work,
 and worse, it exited 0 while doing so. A CI job or a shell script
 checking $? was told a total failure succeeded — fail-WRONG, the one
 failure mode this architecture exists to prevent.

 Protocol decisions pinned here (posted on issue #10 for confirmation):
   - the command composition is CommandLineFixtures
     shippedBinaryCommandIn:args: —
     'cd <abs work> && PARLEY_ROOT=<abs root> gst -q <abs main> -a …'.
     The child's cwd is the fixture working directory (that is what
     makes the working-directory-derived wiring observable), so every
     path in the argv is absolute;
   - the no-backtrace half of the law uses the outputTo: variant,
     which appends a shell redirect to the SAME composed command. That
     is a test-composed tail: ProcessRunner still captures nothing —
     output capture stays out of scope (issue #10) — and the markers
     it searches for are CommandLineFixtures backtraceMarkers;
   - one law drives bin/parley itself, the POSIX sh wrapper, because
     it is the only end-to-end exercise of the leading-'--' strip and
     it is literally the command a user types.

 Every child runs through ProcessRunner — the one process seam — and
 no test spawns a process any other way. Each invocation files in all
 of src/, so these laws cost seconds; that is the honest price of
 testing the product as users run it, accepted at staging.

 RED-phase behaviour, declared on issue #10: these laws DO spawn in
 red, because the law under test IS the child's exit code and landed
 output — no missing class fronts them, and fronting them artificially
 would test the fronting. Against the pre-sprint binary,
 testTheShippedBinarySucceedsAndTheReleaseLands fails on the landed
 release (the child exits 0 and lands nothing: the motivating defect)
 and testTheShippedBinaryFailsWithANonzeroExitCode fails on the exit
 code itself, which is 0 today.

 Every fixture path is under tmp/, unique per test, removed
 recursively in tearDown; the children write only under tmp/ and the
 developer image is never mutated."

Namespace current: Parley.

TestCase subclass: ShippedBinaryTest [
    | fixtureDirs |

    <comment: 'Laws that run bin/parley-main.st and bin/parley as real
child processes: success exits 0 and lands the release, a diagnosed
failure exits nonzero and answers no backtrace.'>

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

    greetingWorkDir: aLabel [
        | path |
        path := self freshDir: aLabel.
        PublishFixtures populateGreetingWorkDirIn: path.
        ^path
    ]

    absolute: aPath [
        ^CommandLineFixtures absolutePathOf: aPath
    ]

    contentsOf: aPath [
        ^(File name: aPath) contents
    ]

    runChild: aCommandString [
        "Every child in this file goes through the one process seam."
        ^ProcessRunner new run: aCommandString
    ]

    "---- S9: the shipped binary succeeds with exit 0 ----"

    testTheShippedBinarySucceedsAndTheReleaseLands [
        | work dest code digest |
        work := self greetingWorkDir: 'bin-publish-work'.
        dest := self freshDir: 'bin-publish-dest'.
        code := self runChild: (CommandLineFixtures
            shippedBinaryCommandIn: work
            args: 'publish ', (self absolute: dest)).
        self assert: code = 0.
        self assert: (PublishFixtures fileNamesIn: dest)
            = (Array
                with: PublishFixtures entryFileName
                with: PublishFixtures archiveFileName).
        digest := Sha256 hexDigestOf:
            (self contentsOf: dest, '/', PublishFixtures archiveFileName).
        self assert: (self contentsOf: dest, '/', PublishFixtures entryFileName)
            = (PublishFixtures greetingEntryWithDigest: digest)
    ]

    "---- S10: the shipped binary fails with a nonzero code ----"

    testTheShippedBinaryFailsWithANonzeroExitCode [
        "The fail-wrong defect, closed. The exact diagnosis line is
         pinned at the object level, where the boundary can be observed
         as a value; here the law is the code the SHELL sees.

         Strengthened by the operator at the Sprint 8 RED review: the
         acceptance scenario S10 requires only 'nonzero', but a missing
         Package.st is a DIAGNOSIS (issue #10 S4, with the ManifestFile
         exception granted at the same review), so the code the binary
         hands the shell is exactly 1 — not merely not-0. Pinning it
         proves the boundary's code survives ObjectMemory quit: and the
         process boundary, which 'nonzero' alone would not. If this
         cannot be made true in GREEN, HALT and report — do not relax
         it back to deny: code = 0."
        | work index code |
        work := self freshDir: 'bin-fail-work'.
        index := self freshDir: 'bin-fail-index'.
        code := self runChild: (CommandLineFixtures
            shippedBinaryCommandIn: work
            args: 'resolve --source ', (self absolute: index)).
        self deny: code = 0.
        self assert: code = 1
    ]

    testAFailingShippedBinaryAnswersADiagnosisAndNotABacktrace [
        "Parley diagnoses; it does not dump. The child's whole output
         is redirected into tmp/ so the law can read what a user would
         see."
        | work index output code text |
        work := self freshDir: 'bin-diagnosis-work'.
        index := self freshDir: 'bin-diagnosis-index'.
        output := (self absolute: work), '/output.txt'.
        code := self runChild: (CommandLineFixtures
            shippedBinaryCommandIn: work
            args: 'resolve --source ', (self absolute: index)
            outputTo: output).
        self deny: code = 0.
        text := self contentsOf: output.
        self deny: text isEmpty
            description: 'a failing command must say something'.
        CommandLineFixtures backtraceMarkers do: [:marker |
            self deny: (CommandLineFixtures does: text include: marker)
                description: 'the shipped binary dumped a backtrace: ', marker]
    ]

    "---- bin/parley: the command a user actually types ----"

    testTheShellWrapperRunsTheProductEndToEnd [
        "bin/parley execs the main script with a leading '--', so this
         is the only end-to-end exercise of the strip — and it runs
         the verb whose wiring was the motivating defect."
        | work dest code |
        work := self greetingWorkDir: 'bin-sh-work'.
        dest := self freshDir: 'bin-sh-dest'.
        code := self runChild: (CommandLineFixtures
            shellWrapperCommandIn: work
            args: 'publish ', (self absolute: dest)).
        self assert: code = 0.
        self assert: (PublishFixtures fileNamesIn: dest)
            = (Array
                with: PublishFixtures entryFileName
                with: PublishFixtures archiveFileName)
    ]
]

Namespace current: Smalltalk.
