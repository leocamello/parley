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

 SPRINT 17 EXTENDS THIS SETTLED FILE — it does not restructure it —
 with the wrapper's location contract (§8 decision 66, Doc E §4.3,
 issue #19 S18-S20). The wrapper had been law-guarded since Sprint 8
 and still shipped its worst defect: PARLEY_ROOT computed from
 dirname $0 without resolving symlinks, so the canonical installation
 — a symlink from a directory on PATH — printed gst's own
 Couldn't open file and exited 0. The settled laws could not see it,
 and the reason is worth recording: they compose PARLEY_ROOT around
 gst run DIRECTLY on bin/parley-main.st (shippedBinaryCommandIn:args:)
 and never enter the wrapper, and the one law that does invoke
 bin/parley (shellWrapperCommandIn:args:) sets no PARLEY_ROOT at all.
 A law that never runs the code cannot guard it.

 RED-phase behaviour of the three new laws, declared on issue #19:
   testTheWrapperStillRunsWhenInvokedDirectly — DECLARED PASS IN RED
     (S20): the ordinary path works today, and the law exists to keep
     it working while S18 is implemented. The guard against
     implementing symlink resolution as compute harder.
   testTheWrapperRunsThroughASymlink and
   testAWrapperThatCannotFindItsMainScriptExitsSeventy both FAIL: the
     first on the exit code and the gst message, the second on both —
     the pre-sprint wrapper overwrites PARLEY_ROOT, so the missing
     main script it is handed is not even reachable.

 Every fixture path is under tmp/, unique per test, removed
 recursively in tearDown; the children write only under tmp/ and the
 developer image is never mutated. The Sprint 17 laws add symlinks
 under tmp/ pointing at the checkout's own bin/parley: they are
 removed as links, never followed, and no fixture ever chmods through
 one — PathFixtures unlock: skips symbolic links precisely so a
 teardown cannot strip the executable bit off the shipped wrapper."

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

    "---- the wrapper's location contract (Sprint 17, §8 decision 66) ----"

    outputOf: aCommandString from: anOutputPath [
        "Private — run a child and answer {exit code. its whole output
         as one String}. Sprint 17's wrapper laws read what the
         TERMINAL showed, because the defect they close is a message
         gst printed and an exit code the wrapper never chose."
        | code |
        code := self runChild: aCommandString.
        ^Array with: code with: (self contentsOf: anOutputPath)
    ]

    linkedWrapperIn: aDirPath named: aBaseName [
        "Private — bin/parley symlinked into a fixture directory, the
         canonical installation: a link from a directory on PATH."
        ^PathFixtures
            symlinkAt: aDirPath, '/', aBaseName
            to: self absoluteWrapperPath
    ]

    testTheWrapperRunsThroughASymlink [
        "S18. THE CANONICAL INSTALLATION, WHICH DID NOT WORK AND SAID IT
         DID. bin/parley computed PARLEY_ROOT from dirname $0 without
         resolving symlinks, so a link from a directory on PATH pointed
         PARLEY_ROOT at the LINK's directory and gst printed
         Couldn't open file … — at exit 0, on the first command a new
         user runs, in the tool whose headline guarantee is that no
         failing command exits 0.

         A symlink to a symlink is asserted beside it because one hop is
         not a contract: package managers and dotfile installers chain
         links routinely, and a wrapper that resolves exactly one hop
         has a bug that only some users meet."
        | work bin direct chained result |
        work := self freshDir: 'bin-symlink-work'.
        bin := self freshDir: 'bin-symlink-bin'.
        direct := self linkedWrapperIn: bin named: 'parley'.
        chained := PathFixtures
            symlinkAt: bin, '/parley-chained'
            to: (self absolute: direct).
        (Array with: direct with: chained) do: [:each |
            result := self outputOf: (PathFixtures
                wrapperCommandAt: (self absolute: each)
                in: work
                args: '--version'
                outputTo: (self absolute: work), '/out.txt')
                from: work, '/out.txt'.
            self assert: (result at: 1) = 0
                description: 'the wrapper at ', each, ' answered exit ',
                    (result at: 1) printString, ': ', (result at: 2).
            self assert: (ExecFixtures linesOf: (result at: 2))
                = (Array with: CommandLine versionLine)
                description: 'the wrapper at ', each, ' printed ',
                    (result at: 2) printString]
    ]

    testAWrapperThatCannotFindItsMainScriptExitsSeventy [
        "S19. The wrapper must CHECK rather than delegate: gst -f
         <missing file> prints its own message and exits 0 (probed,
         3.2.5 — the behaviour §8 decision 45 records for exec, reached
         here by the wrapper), so a wrapper that passed gst's status
         through would report every broken installation as a success.

         70 and not 1: an installation missing its own main script is a
         defect in Parley, which is exactly what 70 means in the settled
         §4.2 taxonomy — untouched here.

         The Given also exercises the second obligation, and is what
         makes the scenario constructible at all: a pre-set PARLEY_ROOT
         must be HONOURED rather than overwritten. Nothing in the
         settled suite depended on that, because the laws that set
         PARLEY_ROOT run gst directly on parley-main.st and never enter
         the wrapper."
        | work emptyRoot result missing |
        work := self freshDir: 'bin-noroot-work'.
        emptyRoot := self freshDir: 'bin-noroot-root'.
        missing := (self absolute: emptyRoot), '/',
            PathFixtures mainScriptRelativePath.
        result := self outputOf: (PathFixtures
            wrapperCommandAt: self absoluteWrapperPath
            in: work
            args: '--version'
            root: (self absolute: emptyRoot)
            outputTo: (self absolute: work), '/out.txt')
            from: work, '/out.txt'.
        self assert: (result at: 1) = PathFixtures wrapperExitCode
            description: 'a wrapper with no main script answered exit ',
                (result at: 1) printString, ': ', (result at: 2).
        self assert: (ExecFixtures linesOf: (result at: 2))
            = (Array with: (PathFixtures wrapperMissingScriptLineFor: missing))
            description: 'the wrapper printed ', (result at: 2) printString.
        self deny: (CommandLineFixtures does: (result at: 2)
            include: PathFixtures gstMissingFileMarker)
            description: 'gst spoke to the operator instead of the wrapper: ',
                (result at: 2)
    ]

    testTheWrapperStillRunsWhenInvokedDirectly [
        "S20 — DECLARED PASS IN RED (issue #19). The guard against
         implementing S18 as compute harder and breaking the ordinary
         path: the wrapper invoked by relative path and by absolute path
         must keep working exactly as it does today. It passes against
         the pre-sprint tree, which is what makes it a guard rather than
         a claim."
        | work out commands |
        work := self freshDir: 'bin-direct-work'.
        out := (self absolute: work), '/out.txt'.
        commands := Array
            with: (PathFixtures
                relativeWrapperCommandWithArgs: '--version'
                outputTo: out)
            with: (PathFixtures
                wrapperCommandAt: self absoluteWrapperPath
                in: work
                args: '--version'
                outputTo: out).
        commands do: [:each |
            | result |
            result := self outputOf: each from: work, '/out.txt'.
            self assert: (result at: 1) = 0
                description: each, ' answered exit ',
                    (result at: 1) printString, ': ', (result at: 2).
            self assert: (ExecFixtures linesOf: (result at: 2))
                = (Array with: CommandLine versionLine)
                description: each, ' printed ', (result at: 2) printString]
    ]

    absoluteWrapperPath [
        ^CommandLineFixtures repoRoot, '/', PathFixtures wrapperPath
    ]
]

Namespace current: Smalltalk.
