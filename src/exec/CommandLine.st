"Parley — CommandLine: the wiring and the diagnosis boundary.
 Spec: docs/design/execution-and-cli.md §4.2; issue #10 S1-S7.

 The wrapper used to hold the wiring AND the flag grammar AND the
 error boundary, and was declared 'glue, excluded from SUnit
 obligations'. That declaration was wrong and it cost: the hardcoded
 file-in list silently missed src/publish/, so the shipped publish
 verb answered a doesNotUnderstand: backtrace — and exited 0. Exit 0
 on a crash is fail-wrong, the one failure mode this architecture
 exists to prevent. Everything the wrapper did except loading,
 printing and exiting now lives here, in an object with laws.

 A COMPOSITION ROOT, not a manager: it holds no domain state, makes
 no domain decision, and answers a value. It never prints and never
 terminates the image — printing and exiting happen in
 bin/parley-main.st alone. It sits ABOVE the settled CLI and hands it
 the verb argv unchanged; the settled argv grammar and usage lines do
 not move.

 The boundary maps every outcome onto exactly four shapes: the verb's
 lines at exit 0; the pinned usage lines at exit 2 (the CLI's own
 answer, passed through); a DECLARED Parley error as its problems — or
 its messageText as one line — at exit 1; and anything else as ONE
 line naming the error class and message text at exit 70
 (EX_SOFTWARE), never a backtrace and never 0. The mapping is
 expressed as on:do: handlers, never an isKindOf: chain: Smalltalk's
 exception system already IS the taxonomy, and re-implementing it as
 branching would silently mis-handle a subclass."

Namespace current: Parley.

Object subclass: CommandLine [
    | workingDir runner |

    <comment: 'The composition root of one Parley invocation: the
working directory (Package.st, parley.lock and the .parley/ state
beneath it) and the one process seam, held immutably. run: answers a
CliResult — it strips a leading ''--'', parses the flag grammar, wires
the real collaborators, sends CLI run:, and maps anything that escapes
to a diagnosis. Class-side construction; zero public setters; no value
equality (the decision-23 precedent).'>

    CommandLine class >> in: aWorkingDir runner: aProcessRunner [
        "Answer a command line over aWorkingDir and the one process
         seam. Pathname-passive: nothing is read, written or spawned
         here — the state directories are created by run:."
        <category: 'instance creation'>
        ^self new setWorkingDir: aWorkingDir runner: aProcessRunner
    ]

    "---- the declared error taxonomy (Doc E §4.2) ----"

    CommandLine class >> batchedErrorClasses [
        "The declared Parley errors that carry a batch of problems:
         each contributes its problems as the lines."
        <category: 'diagnosis'>
        ^Array
            with: ManifestError
            with: SourceError
            with: InstallError
            with: PublishError
    ]

    CommandLine class >> messageErrorClasses [
        "The declared Parley errors that carry only a messageText: it
         contributes as a single line. Execution failure is
         environmental and fail-stop, so it batches nothing."
        <category: 'diagnosis'>
        ^Array with: ExecutionError
    ]

    CommandLine class >> diagnosedErrorClasses [
        "Every declared Parley error the boundary maps to exit 1. The
         closed-set law reads the boundary's declaration from here, and
         the handlers below are built from the same two lists, so the
         boundary can never claim one set and handle another."
        <category: 'diagnosis'>
        ^self batchedErrorClasses, self messageErrorClasses
    ]

    CommandLine class >> batchedErrors [
        <category: 'diagnosis'>
        ^self exceptionSetOf: self batchedErrorClasses
    ]

    CommandLine class >> messageErrors [
        <category: 'diagnosis'>
        ^self exceptionSetOf: self messageErrorClasses
    ]

    CommandLine class >> exceptionSetOf: anArrayOfClasses [
        "Private — the declared classes folded into one ExceptionSet,
         so a handler is derived from a declaration and never written
         beside it."
        <category: 'private'>
        | set |
        set := anArrayOfClasses first.
        2 to: anArrayOfClasses size do: [:i |
            set := set, (anArrayOfClasses at: i)].
        ^set
    ]

    setWorkingDir: aWorkingDir runner: aProcessRunner [
        "Private — initialization from the class-side constructor."
        <category: 'private'>
        workingDir := aWorkingDir.
        runner := aProcessRunner
    ]

    "---- running ----"

    run: anArgvArray [
        "Answer the CliResult of one invocation. No Parley command
         ever answers a backtrace, and no failing command ever exits 0:
         a declared Parley error is a diagnosis at exit 1, and anything
         else is a defect in Parley at exit 70 — distinct from 1 so a
         script can tell 'your input is wrong' from 'the tool is
         broken'. Classification is by HANDLING: the innermost handler
         that names an error's class or one of its superclasses wins,
         which is what makes a subclass of a declared error a diagnosis
         without being named anywhere."
        <category: 'running'>
        ^[[[self dispatch: anArgvArray]
            on: self class batchedErrors
            do: [:e | CliResult lines: e problems exitCode: 1]]
                on: self class messageErrors
                do: [:e |
                    CliResult
                        lines: (Array with: e messageText)
                        exitCode: 1]]
                    on: Error
                    do: [:e |
                        CliResult
                            lines: (Array with: (self undiagnosedLineFor: e))
                            exitCode: 70]
    ]

    dispatch: anArgvArray [
        "Private — the whole of the old wrapper's logic: strip a
         leading '--', wire the real collaborators from the flag
         grammar, and hand the remaining arguments to the settled CLI
         unchanged."
        <category: 'private'>
        | args |
        args := self withoutLeadingMarker: anArgvArray.
        self createStateDirectories.
        ^(self cliWithSourceIn: args) run: (self verbArgvIn: args)
    ]

    "---- the flag grammar ----"

    withoutLeadingMarker: anArgvArray [
        "Private — bin/parley execs 'gst -f <main> -- <argv>', so the
         argv can arrive with a leading '--'. It is stripped here, and
         only here: the settled CLI never sees it."
        <category: 'private-grammar'>
        (anArgvArray isEmpty not and: [(anArgvArray at: 1) = '--'])
            ifTrue: [^anArgvArray copyFrom: 2 to: anArgvArray size].
        ^anArgvArray
    ]

    sourceDirIn: anArgvArray [
        "Private — the '--source <dir>' argument, nil when the flag is
         absent (the verbs that need no source still run)."
        <category: 'private-grammar'>
        1 to: anArgvArray size - 1 do: [:i |
            (anArgvArray at: i) = '--source'
                ifTrue: [^anArgvArray at: i + 1]].
        ^nil
    ]

    verbArgvIn: anArgvArray [
        "Private — every argument the flag grammar did not consume, in
         order: the verb argv, handed to the settled CLI unchanged."
        <category: 'private-grammar'>
        | argv i |
        argv := OrderedCollection new.
        i := 1.
        [i <= anArgvArray size] whileTrue: [
            ((anArgvArray at: i) = '--source'
                and: [i < anArgvArray size])
                    ifTrue: [i := i + 2]
                    ifFalse: [argv add: (anArgvArray at: i). i := i + 1]].
        ^argv asArray
    ]

    "---- the wiring ----"

    cliWithSourceIn: anArgvArray [
        "Private — the settled CLI over the real collaborators. The
         store and target are derived from the WORKING DIRECTORY and
         never from the process cwd: that is what makes the wiring
         law-testable, and what keeps a user's state beside the project
         they ran the command for."
        <category: 'private-wiring'>
        | sourceDir |
        sourceDir := self sourceDirIn: anArgvArray.
        ^CLI
            in: workingDir
            source: (sourceDir isNil
                ifTrue: [nil]
                ifFalse: [DirectorySource on: sourceDir])
            store: (ContentStore on: self storePath)
            target: self targetPath
            runner: runner
    ]

    createStateDirectories [
        "Private — the run's one construction moment. Construction
         stays pathname-passive; the state directories appear when a
         command actually runs."
        <category: 'private-wiring'>
        self ensureDirectory: self parleyDir.
        self ensureDirectory: self targetPath
    ]

    ensureDirectory: aPath [
        "Private — create aPath when it is absent; silent otherwise."
        <category: 'private-wiring'>
        (File name: aPath) exists ifFalse: [Directory create: aPath]
    ]

    parleyDir [
        <category: 'private-wiring'>
        ^workingDir, '/.parley'
    ]

    storePath [
        <category: 'private-wiring'>
        ^self parleyDir, '/store'
    ]

    targetPath [
        <category: 'private-wiring'>
        ^self parleyDir, '/packages'
    ]

    "---- the undiagnosed shape ----"

    undiagnosedLineFor: anError [
        "Private — ONE line naming the error's class and its message
         text, and saying whose defect it is. Never a backtrace:
         Parley diagnoses, it does not dump. 3.2.5's Class>>name
         answers a Symbol, so it is rendered asString; the messageText
         fallback exists because the boundary itself must never be the
         thing that breaks."
        <category: 'private'>
        | text |
        text := anError messageText ifNil: ['(no message text)'].
        ^'internal error: ', anError class name asString, ': ', text,
            ' - this is a defect in Parley, not in your project'
    ]
]

Namespace current: Smalltalk.
