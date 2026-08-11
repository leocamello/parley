"Parley Sprint 19 — the plumbing-chatter laws (issue #21 S1, S2, S4,
 S5; Doc E §1, §2.1, §2.2, §8 decisions 63 and 77).

 WHAT THESE LAWS MEASURE, AND WHY IT IS NOT WHAT THE SCENARIOS MEASURE.
 S1, S2 and S4 are measured on CAPTURED STDOUT AND STDERR FROM THE
 SHIPPED BINARY, separately, because that is the only instrument that
 can see text Parley did not write. This file measures the other half:
 the COMPOSITION. A composed line is a value, and a value can be pinned
 exactly, cheaply, and without spawning anything — so the shipped runs
 answer 'what reached the terminal' and these laws answer 'what Parley
 asked the shell to do'. Neither substitutes for the other: a redirect
 composed correctly and never executed would pass these and fail the
 scenarios, and a child silenced by accident of an empty index would
 pass the scenarios and fail these.

 THE REDIRECT IS APPENDED AT EXECUTION, AND THAT IS THE RULING RATHER
 THAN AN IMPLEMENTATION CHOICE (issue #21, pre-RED). The registration
 plan stays the pure value Doc D §4 pins — two settled laws assert its
 six lines byte-for-byte — and a failing line's ExecutionError names the
 PLAN line, so the settled diagnosis is byte-identical too. The same
 shape governs publish: the runner receives the silenced line, the
 PublishError names the composed one.

 SILENCING CHATTER MUST NEVER SILENCE FAILURE (§8 decision 63). The tail
 redirects STDOUT ONLY. gst-package reports its own failures on stderr —
 probed: a non-archive answers gst-package: Invalid argument there, at
 exit 1 — so a tail carrying 2>&1 would swallow the diagnosis with the
 noise. testTheRedirectDiscardsStdoutAndTouchesNoStderr denies exactly
 that, over the bytes the runner actually received.

 exec IS NOT A REDIRECT (§8 decision 77). Its one child is both the
 plumbing and the author's program on one stream, so the GC message is
 stopped at the source by -g in the pinned composition. Nothing is
 buffered and no stream is thrown away, which is why the deferred
 output-capture row is untouched.

 THE RED PHASE, LAW BY LAW — ERROR/FAILURE (F14) and, for each FAILURE,
 the assertion that produces it (F15). Every law here is a FAILURE and
 none is an ERROR: every class it names is settled and exists.
   testThePublishBuildChildIsRunSilenced — assertion 1: the recorded
     command is the bare composed line, without the tail.
   testThePublishDiagnosisNamesTheComposedLineUnchanged — PASSES in red,
     declared: the settled diagnosis is byte-identical today and must
     stay so. It is the half a careless redirect breaks, which is why it
     is a law and not an assumption.
   testEveryRegistrationLineIsRunSilenced — its one assertion: the
     recorded lines are the plan's own, without the tail.
   testTheRegistrationPlanValueIsUnchangedByTheSilencing — PASSES in
     red, declared, for the same reason as the publish diagnosis: it
     pins what must NOT move.
   testAFailingRegistrationIsStillDiagnosedByItsPlanLine — PASSES in
     red, declared: the settled fail-stop diagnosis names the plan line
     today and must keep doing so once the executed line differs from
     the named one.
   testTheChildCommandCarriesTheNoGcMessageFlag — assertion 1: the
     composed child command has no -g.
   testTheRedirectDiscardsStdoutAndTouchesNoStderr — assertion 2. The
     first is a non-empty guard over the recorded lines, because a law
     whose whole body is a do: loop passes vacuously over an empty
     collection; the failure is the endsWith: on the one line publish
     really ran.

 Three declared passes in red, all of them GUARDS OVER WHAT MUST NOT
 MOVE rather than claims about what this sprint adds. They are reported
 by selector, with these reasons.

 Every fixture path is under tmp/, unique per test, removed recursively
 in tearDown through PathFixtures removeTree:, which unlocks first.
 Nothing here spawns: every runner is a RecordingRunner."

Namespace current: Parley.

TestCase subclass: PlumbingChatterTest [
    | fixtureDirs |

    <comment: 'Laws for the composed plumbing lines: the stdout redirect
appended at execution by Publisher and by ExecutionScope>>register, the
plan value and both settled diagnoses held byte-identical underneath
it, the -g flag in the pinned child composition, and the bound that the
tail touches no stderr.'>

    setUp [
        fixtureDirs := OrderedCollection new
    ]

    tearDown [
        fixtureDirs isNil ifTrue: [^self].
        fixtureDirs do: [:each | PathFixtures removeTree: each].
        fixtureDirs := nil
    ]

    tracker [
        ^[:path | fixtureDirs add: path. path]
    ]

    track: aPath [
        fixtureDirs add: aPath.
        ^aPath
    ]

    freshDir: aLabel [
        ^self track: (SourceFixtures directoryNamed: aLabel)
    ]

    silenced: aCommandString [
        ^aCommandString, ChatterFixtures stdoutRedirectTail
    ]

    "---- publish: the build child ----"

    publisherIn: aWorkDir to: aDestDir runner: aRunner [
        ^Publisher manifest: PublishFixtures greetingManifest
            in: aWorkDir
            to: aDestDir
            runner: aRunner
    ]

    greetingWorkDir: aLabel [
        "The settled greeting project, populated through the settled
         fixture: the manifest declares TWO fileIns and publish's
         pre-flight refuses a working directory missing either, which
         would answer a different problem than the one these laws are
         about."
        | work |
        work := self freshDir: aLabel.
        PublishFixtures populateGreetingWorkDirIn: work.
        ^work
    ]

    commandsFromPublishing: aWorkDir to: aDestDir [
        "Private — the command lines a publish asks the runner to run,
         with a RECORDING runner in place of the toolchain.

         THE PublishError IS EXPECTED AND IGNORED, and that is a stated
         bound rather than a swallow: a recording runner answers 0
         without building anything, so publish goes on to land an
         archive that was never created and refuses. What these laws
         measure is the line Parley COMPOSED AND RAN, which is already
         recorded by then; what happens after the build is the settled
         pipeline's business and has its own laws."
        | runner |
        runner := RecordingRunner new.
        [(self publisherIn: aWorkDir to: aDestDir runner: runner) publish]
            on: PublishError do: [:e | e return: nil].
        ^runner commands
    ]

    testThePublishBuildChildIsRunSilenced [
        "THE ONE CHILD publish SPAWNS, and the five lines it echoes are
         the sprint's opening defect. What the runner receives is the
         composed line with the declared tail; nothing else changes."
        | work dest commands |
        work := self greetingWorkDir: 'chatter-pub-work'.
        dest := self freshDir: 'chatter-pub-dest'.
        commands := self commandsFromPublishing: work to: dest.
        self assert: commands
            = (Array with: (self silenced:
                (PublishFixtures buildCommandFor: dest)))
            description: 'publish ran ', commands printString
    ]

    testThePublishDiagnosisNamesTheComposedLineUnchanged [
        "SILENCING CHATTER MUST NEVER SILENCE FAILURE, and it must not
         garble the failure either. A DECLARED PASS IN RED: this pins
         what must NOT move. The operator is told which command failed
         and with what code, in the settled wording, and the shell tail
         Parley appended for its own convenience is not part of that
         sentence — it is not something the operator typed or can act
         on."
        | work dest problems expected |
        work := self greetingWorkDir: 'chatter-pubfail-work'.
        dest := self freshDir: 'chatter-pubfail-dest'.
        expected := PublishFixtures
            buildFailureProblemFor: (PublishFixtures buildCommandFor: dest)
            code: 2.
        problems := nil.
        [(self publisherIn: work to: dest
            runner: (RecordingRunner answering: 2)) publish]
                on: PublishError
                do: [:e | problems := e problems. e return: nil].
        self deny: problems isNil
            description: 'a failing build was not refused'.
        self assert: problems = (Array with: expected)
            description: 'publish answered ', problems printString
    ]

    "---- register: the plan lines ----"

    setOf: someNames in: aStoreRoot [
        "Private — an InstalledSet over names with fabricated hashes, so
         the plan has several lines without any archive existing: these
         laws measure COMPOSITION and never spawn."
        | tuples |
        tuples := Dictionary new.
        someNames do: [:name |
            tuples at: name put: (Array
                with: (Version fromString: '1.0.0')
                with: name, '-hash'
                with: aStoreRoot, '/', name, '-hash.star')].
        ^InstalledSet tuples: tuples
    ]

    scopeOver: someNames target: aTarget runner: aRunner [
        ^ExecutionScope
            on: (self setOf: someNames in: 'tmp/parley-chatter-store')
            target: aTarget
            runner: aRunner
    ]

    testEveryRegistrationLineIsRunSilenced [
        "THE install -c ECHO ORIGINATES HERE, probed pre-RED: Installer
         composes no command line at all, and Parley's own staging line
         is silent — the echo is gst-package's own, from the registration
         child. Every plan line is silenced, not only the registering
         one: a rule that silenced some lines would be an enumeration of
         the ones that happened to talk today."
        | target runner scope expected |
        target := 'tmp/parley-chatter-reg-target'.
        runner := RecordingRunner new.
        scope := self scopeOver: #('alpha' 'beta') target: target
            runner: runner.
        expected := scope registrationCommands
            collect: [:line | self silenced: line].
        scope register.
        self assert: runner commands = expected asArray
            description: 'register ran ', runner commands printString
    ]

    testTheRegistrationPlanValueIsUnchangedByTheSilencing [
        "A DECLARED PASS IN RED, and the reason the redirect is appended
         at EXECUTION rather than in the composition: the plan is a pure
         value Doc D §4 pins and two settled laws assert line by line.
         Silencing is a property of running a line, not of the plan."
        | target scope set |
        target := 'tmp/parley-chatter-plan-target'.
        set := self setOf: #('alpha' 'beta') in: 'tmp/parley-chatter-store'.
        scope := ExecutionScope on: set target: target
            runner: RecordingRunner new.
        self assert: scope registrationCommands
            = (set registrationCommandsFor: target)
            description: 'the plan is no longer the installed set''s own'.
        scope registrationCommands do: [:line |
            self deny: (CommandLineFixtures does: line
                include: ChatterFixtures stdoutRedirectTail)
                description: 'the plan value carries the redirect: ', line]
    ]

    testAFailingRegistrationIsStillDiagnosedByItsPlanLine [
        "A DECLARED PASS IN RED. Once the executed line differs from the
         composed one, a diagnosis assembled from the wrong one is a
         one-character change away — and it would tell the operator to
         look at a command they never wrote. Fail-stop is unchanged: the
         first nonzero exit signals, and later lines are not attempted."
        | target scope error expected |
        target := 'tmp/parley-chatter-regfail-target'.
        scope := self scopeOver: #('alpha') target: target
            runner: (RecordingRunner answering: 1).
        expected := ExecFixtures
            executionErrorMessageFor: scope registrationCommands first
            code: 1.
        error := nil.
        [scope register] on: ExecutionError
            do: [:e | error := e. e return: nil].
        self deny: error isNil
            description: 'a failing registration was not refused'.
        self assert: error messageText = expected
            description: 'register answered ', error messageText printString
    ]

    "---- exec: the flag, not a redirect ----"

    testTheChildCommandCarriesTheNoGcMessageFlag [
        "§8 decision 77. The composition is pinned EXACTLY here as well
         as in the settled ExecutionScopeTest, because this is the law
         that states WHY the flag is there: it stops the image rebuild's
         chatter being written at all, which is the one route that
         touches neither the script's stdout nor its stderr.

         The absence of a redirect is asserted too. A -g that arrived
         alongside a stream redirect would silence the author's own
         error output, which is decision 45's territory and the deferred
         output-capture row's actual subject."
        | scope command |
        scope := ExecutionScope on: (InstalledSet tuples: Dictionary new)
            target: 'tmp/parley-chatter-exec-target'
            runner: RecordingRunner new.
        command := scope childCommandFor: 'tmp/chatter.st'.
        self assert: command
            = 'gst -g -i -I tmp/parley-chatter-exec-target/parley.im --no-user-files tmp/chatter.st'
            description: 'exec composes ', command printString.
        self deny: (CommandLineFixtures does: command
            include: ChatterFixtures stdoutRedirectTail)
            description: 'the exec child carries a redirect: ', command.
        self deny: (CommandLineFixtures does: command include: '2>')
            description: 'the exec child redirects stderr: ', command
    ]

    "---- the bound: stdout only ----"

    testTheRedirectDiscardsStdoutAndTouchesNoStderr [
        "THE BOUND, MEASURED ON THE BYTES THE RUNNER RECEIVED rather than
         on the declared tail alone (§8 decision 43's standard: a law
         states its bound). A child's chatter is discarded; a child's
         FAILURE reaches the terminal, because gst-package writes its
         diagnostics to stderr and this tail never touches stderr."
        | work dest commands |
        work := self greetingWorkDir: 'chatter-bound-work'.
        dest := self freshDir: 'chatter-bound-dest'.
        commands := self commandsFromPublishing: work to: dest.
        self deny: commands isEmpty
            description: 'no plumbing line was run at all'.
        commands do: [:line |
            self assert: (line endsWith: ChatterFixtures stdoutRedirectTail)
                description: 'a plumbing line is not silenced: ', line.
            self deny: (CommandLineFixtures does: line include: '2>')
                description: 'a plumbing line redirects stderr: ', line]
    ]
]

Namespace current: Smalltalk.
