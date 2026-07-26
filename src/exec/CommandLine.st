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

 The source flags are a DECLARED TABLE (Sprint 9), not a chain:
 sourceFlags maps each flag to the class it builds and the message that
 builds one, the wiring is built from it, and the source drift law
 reads the same rows — so a source can never again be lawful and
 unreachable, as GitIndexSource was for a whole sprint. --source and
 --git are mutually exclusive; both given is a usage error, because
 silently preferring one would make a typo look like a working command.

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
         each contributes its problems as the lines. LockError joined
         them at Sprint 9 (Doc E §4.1): it carries problems exactly as
         the others do, so the boundary absorbs it with no new
         mechanism — the handler below is derived from this list, and
         adding a name to it IS the change."
        <category: 'diagnosis'>
        ^(Array
            with: ManifestError
            with: SourceError
            with: InstallError
            with: PublishError), (Array with: LockError)
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

    "---- the declared source flag table (Doc E §4.2) ----"

    CommandLine class >> sourceFlags [
        "The flag -> source table: each row is the flag, the
         PackageSource class it builds, and the message that builds one.
         A table LOOKUP, never an isKindOf: chain — the flag selects a
         row, and the row says what to build and how.

         It is a DECLARATION consumed twice: the wiring below is built
         from it, and the source drift law reads the same rows, so the
         wiring and the law cannot disagree. GitIndexSource was built,
         lawful and unreachable for a whole sprint because nothing
         constructed it; Sprint 8's bin/ drift law could not see that,
         because it covers DIRECTORIES and src/source/ was named. A
         directory and a flag are two different reachability questions.

         The third column exists because the two sources' construction
         protocols genuinely differ — a directory needs a path, a git
         index needs a repo, a cache and the process seam — and neither
         settled class is touched to pretend otherwise."
        <category: 'source flags'>
        ^Array
            with: (Array with: '--source' with: DirectorySource
                with: #directorySourceOn:)
            with: (Array with: '--git' with: GitIndexSource
                with: #gitSourceOn:)
    ]

    "---- the declared deserialization boundaries (Doc E §4.2) ----"

    CommandLine class >> deserializationBoundaries [
        "Every point where Parley reads a file the OPERATOR can edit:
         each row is the class that reads it and the file it reads.

         WHY THIS ENUMERATION EXISTS, and why it is not a widened
         neighbour (§8 decision 35). The §4.2 closed set quantifies over
         Error subclasses defined in the Parley namespace, and a KERNEL
         error raised inside a verb is outside it entirely — which is
         exactly how a malformed-body parley.lock survived Sprint 9 with
         every law green, dying inside a constructor and answered with
         exit 70. Enumerating more error classes could not have caught
         that and will not catch the next one. The invariant that
         carries the weight is per BOUNDARY: validate shape before
         handing the value to a constructor, and answer a diagnosis at
         exit 1 on malformed content.

         The anchor is mechanical: IndexEntryReader readFrom: is the
         single literals-only parser, so every sender of it in src/ is a
         deserialization boundary by construction, and the drift law
         reads src/ and requires every sender to appear here. The two
         senders are the CLI's parley.lock read (§4.1) and the
         DirectorySource scan (Doc F §4/§4.1/§4.2) — which from Sprint
         10 also reads retirement records through that same sender, so
         the new schema is covered the moment it exists. ManifestFile is
         declared alongside them because it reads an operator-editable
         file by a DIFFERENT mechanism (file-in, not the reader) and is
         precisely the boundary a reader-anchored enumeration would
         otherwise miss.

         A DECLARATION CONSUMED TWICE, as sourceFlags and
         diagnosedErrorClasses are: the drift law compares it against
         src/, and the per-boundary laws ITERATE it, so a row added
         without a malformed-input law fails the suite rather than
         quietly widening the claim. The second column is what makes a
         row a boundary rather than a reader: a row that cannot name the
         operator's file does not belong here."
        <category: 'deserialization boundaries'>
        ^Array
            with: (Array with: CLI with: 'parley.lock')
            with: (Array with: DirectorySource
                with: 'index entries and retirement records')
            with: (Array with: ManifestFile with: 'Package.st')
    ]

    CommandLine class >> sourceFlagNames [
        "Every flag the table declares — the grammar's own vocabulary,
         derived from the table so the parser cannot know a flag the
         table does not."
        <category: 'source flags'>
        ^self sourceFlags collect: [:row | row at: 1]
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
        "The source flags are mutually exclusive: both given is a usage
         error, because silently preferring one would make a typo look
         like a working command. Checked before anything is created or
         built, so a usage error touches nothing."
        (self sourceRowsIn: args) size > 1 ifTrue: [^self usageResult].
        self createStateDirectories.
        ^(self cliWithSourceIn: args) run: (self verbArgvIn: args)
    ]

    usageResult [
        "Private — the usage answer for a flag-grammar violation. It is
         the SETTLED CLI's own answer, obtained by handing a source-less
         CLI the argv it already answers usage for, so the flag grammar
         and the verb grammar can never print two different usages."
        <category: 'private'>
        ^(self cliWithSource: nil) run: #()
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

    valueOf: aFlag in: anArgvArray [
        "Private — the argument following aFlag, nil when the flag is
         absent or carries no value (a trailing flag is not a flag: it
         travels on to the settled CLI, which answers usage)."
        <category: 'private-grammar'>
        1 to: anArgvArray size - 1 do: [:i |
            (anArgvArray at: i) = aFlag ifTrue: [^anArgvArray at: i + 1]].
        ^nil
    ]

    sourceRowsIn: anArgvArray [
        "Private — every table row whose flag appears in anArgvArray
         with a value. Empty is the ordinary case (the verbs that need
         no source still run); more than one is the mutual-exclusion
         usage error."
        <category: 'private-grammar'>
        ^self class sourceFlags select: [:row |
            (self valueOf: (row at: 1) in: anArgvArray) notNil]
    ]

    verbArgvIn: anArgvArray [
        "Private — every argument the flag grammar did not consume, in
         order: the verb argv, handed to the settled CLI unchanged. The
         flags it consumes are the table's, so a flag can never be
         parsed here that the table does not declare."
        <category: 'private-grammar'>
        | argv i flags |
        flags := self class sourceFlagNames.
        argv := OrderedCollection new.
        i := 1.
        [i <= anArgvArray size] whileTrue: [
            ((flags includes: (anArgvArray at: i))
                and: [i < anArgvArray size])
                    ifTrue: [i := i + 2]
                    ifFalse: [argv add: (anArgvArray at: i). i := i + 1]].
        ^argv asArray
    ]

    "---- the wiring ----"

    cliWithSourceIn: anArgvArray [
        "Private — the settled CLI over the real collaborators, its
         source built from whichever flag the argv carries."
        <category: 'private-wiring'>
        ^self cliWithSource: (self sourceIn: anArgvArray)
    ]

    cliWithSource: aPackageSource [
        "Private — the settled CLI over the real collaborators. The
         store and target are derived from the WORKING DIRECTORY and
         never from the process cwd: that is what makes the wiring
         law-testable, and what keeps a user's state beside the project
         they ran the command for. aPackageSource may be nil — the
         verbs that need none still run."
        <category: 'private-wiring'>
        ^CLI
            in: workingDir
            source: aPackageSource
            store: (ContentStore on: self storePath)
            target: self targetPath
            runner: runner
    ]

    sourceIn: anArgvArray [
        "Private — the source the argv's flag builds, nil when no flag
         is present. The row says which message builds it, so adding a
         source is adding a row and a builder — never a branch here."
        <category: 'private-wiring'>
        | rows row |
        rows := self sourceRowsIn: anArgvArray.
        rows isEmpty ifTrue: [^nil].
        row := rows first.
        ^self
            perform: (row at: 3)
            with: (self valueOf: (row at: 1) in: anArgvArray)
    ]

    directorySourceOn: aDirPath [
        "Private — the '--source <dir>' builder."
        <category: 'private-wiring'>
        ^DirectorySource on: aDirPath
    ]

    gitSourceOn: aRepoPath [
        "Private — the '--git <repo>' builder (Sprint 9). The checkout
         lives under the working directory like every other piece of
         Parley state, and its name is the settled Sha256 of the repo
         location: any repo string — a path, a URL, anything git clone
         accepts — becomes one deterministic filesystem-safe name, so
         no escaping layer has to be invented. The cache ROOT is created
         here; the checkout itself must not exist, because an absent
         cache is what tells the settled GitIndexSource to clone."
        <category: 'private-wiring'>
        self ensureDirectory: self gitCacheRoot.
        ^GitIndexSource
            repo: aRepoPath
            cache: (self gitCachePathFor: aRepoPath)
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

    gitCacheRoot [
        <category: 'private-wiring'>
        ^self parleyDir, '/git'
    ]

    gitCachePathFor: aRepoPath [
        <category: 'private-wiring'>
        ^self gitCacheRoot, '/', (Sha256 hexDigestOf: aRepoPath)
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
