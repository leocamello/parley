"Parley — ExecutionScope: the honest bundle exec for 3.2.5.
 Spec: docs/design/execution-and-cli.md §2; architecture §5; §8
 decision 16; issue #8 S3-S6.
 The single home of invocation logic, over three immutably held
 collaborators. registrationCommands is exactly the installed set's
 Doc D §4 staged plan — a pure value, executed here and never
 recomposed. register is fail-stop: the first nonzero exit signals
 one ExecutionError naming the command and code; later commands are
 not attempted (an execution failure is environmental; retrying the
 rest teaches nothing and can half-register an environment).
 Registration is re-runnable: both plan lines overwrite identical
 files harmlessly. childCommandFor: is the pinned curated-child
 composition; run: sends it through the runner and answers the
 child's exit code — a nonzero child is the script's own business,
 an answer, never an ExecutionError. No value equality (=/hash) —
 the decision-23 precedent."

Namespace current: Parley.

Object subclass: ExecutionScope [
    | installedSet target runner fileIns |

    <comment: 'The process-level sandbox: holds an InstalledSet, a
target directory and a ProcessRunner immutably. register executes the
staged registration plan fail-stop; run: launches the curated child
gst whose image directory is the target, so exactly the registered
star set is visible to its PackageLoader. Class-side construction;
zero public setters.'>

    ExecutionScope class >> on: anInstalledSet target: aTargetDir runner: aProcessRunner [
        "Answer a scope over anInstalledSet, registering into and
         running against aTargetDir, spawning only through
         aProcessRunner.

         THE SETTLED CONSTRUCTOR, UNCHANGED FOR EVERY SETTLED CALLER,
         and it answers a scope with NO extra file-ins — which is what
         makes the pinned child composition byte-identical when no path
         pins exist (Sprint 21)."
        <category: 'instance creation'>
        ^self
            on: anInstalledSet
            target: aTargetDir
            runner: aProcessRunner
            fileIns: #()
    ]

    ExecutionScope class >> on: anInstalledSet target: aTargetDir runner: aProcessRunner fileIns: someFilePaths [
        "The same, plus source files the child must file in AHEAD of
         the script (Sprint 21, §8 decision 68): the fileIns of every
         #path pin, in dependency order, read fresh at exec time.

         They arrive as a VALUE the CLI composed. This class does not
         read the lock, does not read a sibling's Package.st and does
         not decide what belongs here — deciding what to load is the
         verb's business, exactly as deciding whether there is anything
         to run is (§8 decision 56's split)."
        <category: 'instance creation'>
        ^self new
            setInstalledSet: anInstalledSet
            target: aTargetDir
            runner: aProcessRunner
            fileIns: someFilePaths
    ]

    setInstalledSet: anInstalledSet target: aTargetDir runner: aProcessRunner fileIns: someFilePaths [
        "Private — initialization from the class-side constructor."
        <category: 'private'>
        installedSet := anInstalledSet.
        target := aTargetDir.
        runner := aProcessRunner.
        fileIns := someFilePaths
    ]

    registrationCommands [
        "The Doc D §4 staged plan for the target — exactly the
         installed set's pure value, never recomposed here."
        <category: 'registration'>
        ^installedSet registrationCommandsFor: target
    ]

    register [
        "Execute the plan in its order (sorted package-name order,
         each package's staging line immediately before its
         registration line) through the runner. Fail-stop: the first
         nonzero exit signals one ExecutionError naming the exact
         command line and code; later commands are not attempted.

         THE PLAN LINES ARE PLUMBING, AND THEIR CHATTER IS DISCARDED
         HERE (§8 decision 63, Sprint 19). gst-package echoes its own
         /usr/bin/install -c copy line to stdout — text on the
         operator's terminal that Parley did not write, probed pre-RED
         as originating at THIS child and not in Installer, which
         composes no command line at all.

         THE REDIRECT IS APPENDED AS THE LINE IS RUN, NEVER INTO THE
         PLAN. registrationCommands stays the pure value Doc D §4 pins
         and two settled laws assert line by line, and the
         ExecutionError below names the PLAN line — the operator is told
         which command failed, not which shell tail Parley appended for
         its own convenience. The exit code is still checked and
         fail-stop is unchanged: SILENCING CHATTER MUST NEVER SILENCE
         FAILURE, and gst-package's own diagnostics are on stderr, which
         this redirect does not touch."
        <category: 'registration'>
        self registrationCommands do: [:command |
            | code |
            code := runner run: (self silenced: command).
            code = 0 ifFalse: [
                ^ExecutionError signalCommand: command exitCode: code]]
    ]

    silenced: aCommandString [
        "Private — aCommandString with the stdout redirect appended
         (§8 decision 63).

         STDOUT ONLY, AND THE ABSENCE OF A STDERR REDIRECT IS THE WHOLE
         BOUND. A tail carrying 2>&1 would discard the child's
         diagnostics along with its chatter, which is the fail-wrong
         this project exists to prevent.

         THE LITERAL HAS A SECOND DEFINITION IN Publisher, AND THAT IS
         STATED RATHER THAN HIDDEN. Doc E §1 gives the redirect to each
         composer at its own point of execution, and the two composers
         share no home that is not the process seam — which decisions 63
         and 77 both leave untouched, because a seam that knew about
         redirects would be a seam that shapes what it runs. What keeps
         the two from drifting is that both are pinned against ONE test
         oracle, ChatterFixtures stdoutRedirectTail, by laws that fail
         the moment either moves."
        <category: 'private-registration'>
        ^aCommandString, ' > /dev/null'
    ]

    childCommandFor: aScriptPath [
        "The pinned curated-child composition (Doc E §2.2): the image
         lives in the target, so the child's PackageLoader sees
         exactly the target's registered stars; -i rebuilds from the
         kernel so no state leaks; --no-user-files excludes ~/.st
         customizations.

         -g (--no-gc-message) SUPPRESSES THE IMAGE REBUILD'S CHATTER AT
         THE SOURCE (§8 decision 77, Sprint 19). The rebuild wrote
         'Global garbage collection... done' to the child's stderr, and
         that child is BOTH the plumbing and the author's program on one
         stream — so the redirect this class appends to a registration
         line is exactly wrong here: it would discard the script's own
         error output, and telling the two apart would mean buffering,
         which roadmap §3 defers by name. A flag that stops the text
         being written buffers nothing and redirects nothing. Probed on
         this exact shape: stderr 55 bytes to 19 — the script's own line
         and nothing else — stdout byte-identical, exit code unchanged,
         so decision 45's pass-through is untouched."
        <category: 'running'>
        ^'gst -g -i -I ', target, '/parley.im --no-user-files ',
            self fileInPrefix, aScriptPath
    ]

    fileInPrefix [
        "Private — the path-supplied sources the child files in AHEAD of
         the script, each followed by a space, or the empty string when
         there are none (Sprint 21, §8 decision 68).

         gst files in every .st argument in order, so putting the
         sibling's own sources first is the whole mechanism: edit the
         sibling, re-run exec, and the change is picked up WITH NO
         PUBLISH. The ruled-out alternative — rebuild and re-register
         the sibling's star per run — is publish-per-edit in mechanism,
         the precise cost this feature exists to abolish.

         WHEN THERE ARE NO PATH PINS THIS ANSWERS '' AND THE PINNED
         COMPOSITION IS BYTE-IDENTICAL, which is what keeps the settled
         child-command law from moving."
        <category: 'private-running'>
        | out |
        fileIns isEmpty ifTrue: [^''].
        out := WriteStream on: String new.
        fileIns do: [:each | out nextPutAll: each; nextPut: Character space].
        ^out contents
    ]

    run: aScriptPath [
        "Launch the curated child on aScriptPath and answer its exit
         code — a value, never a signal."
        <category: 'running'>
        ^runner run: (self childCommandFor: aScriptPath)
    ]
]

Namespace current: Smalltalk.
