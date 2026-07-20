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
    | installedSet target runner |

    <comment: 'The process-level sandbox: holds an InstalledSet, a
target directory and a ProcessRunner immutably. register executes the
staged registration plan fail-stop; run: launches the curated child
gst whose image directory is the target, so exactly the registered
star set is visible to its PackageLoader. Class-side construction;
zero public setters.'>

    ExecutionScope class >> on: anInstalledSet target: aTargetDir runner: aProcessRunner [
        "Answer a scope over anInstalledSet, registering into and
         running against aTargetDir, spawning only through
         aProcessRunner."
        <category: 'instance creation'>
        ^self new
            setInstalledSet: anInstalledSet
            target: aTargetDir
            runner: aProcessRunner
    ]

    setInstalledSet: anInstalledSet target: aTargetDir runner: aProcessRunner [
        "Private — initialization from the class-side constructor."
        <category: 'private'>
        installedSet := anInstalledSet.
        target := aTargetDir.
        runner := aProcessRunner
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
         command line and code; later commands are not attempted."
        <category: 'registration'>
        self registrationCommands do: [:command |
            | code |
            code := runner run: command.
            code = 0 ifFalse: [
                ^ExecutionError signalCommand: command exitCode: code]]
    ]

    childCommandFor: aScriptPath [
        "The pinned curated-child composition (Doc E §2.2): the image
         lives in the target, so the child's PackageLoader sees
         exactly the target's registered stars; -i rebuilds from the
         kernel so no state leaks; --no-user-files excludes ~/.st
         customizations."
        <category: 'running'>
        ^'gst -i -I ', target, '/parley.im --no-user-files ', aScriptPath
    ]

    run: aScriptPath [
        "Launch the curated child on aScriptPath and answer its exit
         code — a value, never a signal."
        <category: 'running'>
        ^runner run: (self childCommandFor: aScriptPath)
    ]
]

Namespace current: Smalltalk.
