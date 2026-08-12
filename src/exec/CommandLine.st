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
            with: (Array with: '--index' with: SparseIndexSource
                with: #indexSourceOn:)
    ]

    CommandLine class >> unsearchableFlag [
        "The one declared source flag whose transport cannot answer
         parley search (§8 decision 80).

         A sparse index publishes one listing per package at
         <base>/<name>/… and NO catalogue, and a base URL cannot be
         enumerated over the transport — so the names such a source can
         reach are exactly the seeded closure and nothing else. That is
         a property of the BACKEND, declared here beside the flag that
         builds it, and never a new PackageSource protocol selector,
         which would change three settled sources to record a property
         of one."
        <category: 'source flags'>
        ^'--index'
    ]

    CommandLine class >> canSearch: aPackageSource [
        "Whether a search can be answered over aPackageSource.

         KEYED OFF sourceFlags, the declaration the wiring already
         holds: the class comes from the row rather than from a literal
         here, so this predicate and the builder can never disagree
         about what --index constructs. It is a TABLE LOOKUP, not an
         isKindOf: chain and not a respondsTo:, which is a kind-check
         spelled differently.

         The table itself does not grow a column: SourceFlagTest holds
         every row to exactly three, and a fourth would be an undeclared
         change to the one row shape this suite pins."
        <category: 'source flags'>
        | row |
        aPackageSource isNil ifTrue: [^true].
        row := self sourceFlagRowNamed: self unsearchableFlag.
        row isNil ifTrue: [^true].
        ^(aPackageSource class == (row at: 2)) not
    ]

    CommandLine class >> sourceFlagRowNamed: aFlag [
        "Private — the declared row for aFlag, or nil when the table
         declares none."
        <category: 'source flags'>
        self sourceFlags do: [:row |
            (row at: 1) = aFlag ifTrue: [^row]].
        ^nil
    ]

    CommandLine class >> searchableFlagNames [
        "Every declared flag whose transport CAN answer a search —
         derived by subtraction from the one table, so a fourth source
         joins this list by joining that one."
        <category: 'source flags'>
        ^self sourceFlagNames reject: [:each | each = self unsearchableFlag]
    ]

    "---- the declared publish layouts (Doc F §8.1, §8 decision 53) ----"

    CommandLine class >> publishLayouts [
        "The layout -> spec table for publish: each row is the name the
         operator states and the Publisher layout spec it selects.

         THE LAYOUT IS STATED, NEVER INFERRED (§8 decision 53). Reading
         the destination to guess would make an EMPTY directory
         ambiguous — a brand-new index, the commonest case, is exactly
         the one with no evidence to read — and would turn a mistyped
         path into a successful publish into the wrong shape rather
         than an error. That is the same failure publish already
         refuses when it declines to CREATE a destination that is not
         there, and the same one the flag grammar refuses when --source
         with --git is a usage error instead of a silent preference. An
         unrecognized value is a usage error at exit 2, never a
         fallback.

         A DECLARATION CONSUMED TWICE, exactly as sourceFlags is: the
         wiring looks a row up by name, and the drift law drives a real
         publish through every row — so a layout can never be lawful
         and unreachable, which is the defect GitIndexSource shipped
         with for a whole sprint.

         The spec belongs to the Publisher, where the methods it names
         live; this table declares which layouts EXIST, and asking for
         the spec rather than restating it is what keeps the two from
         drifting apart. flat is first because it is the default."
        <category: 'publish layouts'>
        ^Array
            with: (Array with: 'flat' with: Publisher flatLayout)
            with: (Array with: 'sparse' with: Publisher sparseLayout)
    ]

    "---- the declared usage reasons (Doc E §4, §8 decision 81) ----"

    CommandLine class >> usageReasons [
        "WHY a usage error happened, as a DECLARED TABLE: each row is a
         ground and the sentence that names it. Six rows, consumed
         twice — the composition reads them and a drift law reads the
         same rows — exactly as sourceFlags, publishLayouts, verbRows
         and deserializationBoundaries are.

         FOUR GROUNDS ARE THE VERB GRAMMAR'S and two are decided outside
         it: both source flags, refused here before any verb exists, and
         an unrecognized --layout, refused inside publish after a row
         already matched. NEITHER OF THOSE TWO COMPOSES ITS OWN
         SENTENCE, and the shipped code shows why: usageResult used to
         obtain its answer by running the settled CLI on an EMPTY argv,
         so an operator who typed two source flags would have been told
         `no verb given` — a false statement about their argv, produced
         by the economy rather than by anyone's intent. Composing at the
         site that refuses would replace one wrong sentence with two
         wordings no law can see.

         THE FLAG AND LAYOUT LISTS ARE COMPOSED FROM THEIR OWN TABLES,
         never typed here: a fourth source or a third layout must not be
         able to drift out of the sentence that offers it.

         The rows are built in groups of at most five: 3.2.5's Array
         answers no with: longer than that (see CLI class >> verbRows)."
        <category: 'usage reasons'>
        ^(Array
            with: (Array with: #noVerb
                with: [:subject | 'no verb given'])
            with: (Array with: #unknownVerb
                with: [:subject | subject, ' is not a parley verb'])
            with: (Array with: #wrongArguments
                with: [:subject | subject, ' does not take those arguments'])
            with: (Array with: #needsIndex
                with: [:subject | subject, ' needs an index - give ',
                    (self list: self sourceFlagNames conjunction: 'or')])
            with: (Array with: #bothSourceFlags
                with: [:subject |
                    (self list: self sourceFlagNames conjunction: 'and'),
                        ' are mutually exclusive - give one'])),
            (Array with: (Array with: #unknownLayout
                with: [:subject | subject, ' is not an index layout - give ',
                    (self list: self publishLayoutNames conjunction: 'or')]))
    ]

    CommandLine class >> usageReasonFor: aGroundSymbol subject: aSubject [
        "The declared sentence for one ground. A ground with no row is a
         defect in the caller, not a sentence to invent."
        <category: 'usage reasons'>
        self usageReasons do: [:row |
            (row at: 1) = aGroundSymbol
                ifTrue: [^(row at: 2) value: aSubject]].
        ^self error: 'no declared usage reason for ',
            aGroundSymbol printString
    ]

    CommandLine class >> list: someStrings conjunction: aWord [
        "Private — someStrings as English: comma-separated, the last two
         joined by aWord. Two items take no comma."
        <category: 'usage reasons'>
        | out |
        out := WriteStream on: String new.
        1 to: someStrings size do: [:i |
            i = 1 ifFalse: [
                i = someStrings size
                    ifTrue: [out nextPutAll: ' ', aWord, ' ']
                    ifFalse: [out nextPutAll: ', ']].
            out nextPutAll: (someStrings at: i)].
        ^out contents
    ]

    CommandLine class >> publishLayoutNames [
        "Every layout the table declares, derived from it so a sentence
         offering the layouts cannot name a set the wiring does not."
        <category: 'publish layouts'>
        ^self publishLayouts collect: [:row | row at: 1]
    ]

    "---- the version answer (Doc E §4.2, issue #17 S12/S13) ----"

    CommandLine class >> versionFlag [
        "The one valueless flag Parley recognizes, declared here so the
         grammar has exactly one exception and it has a name."
        <category: 'version'>
        ^'--version'
    ]

    CommandLine class >> versionLine [
        "What parley --version prints: the tool, then its version from
         the single definition on the authoring gateway. Only the tool
         name is spelled here; the version is never restated."
        <category: 'version'>
        ^'parley ', Parley version
    ]

    CommandLine class >> helpFlags [
        "The accepted spellings of ONE question (§8 decision 57,
         Sprint 16). A user who guesses any of the three has asked the
         same thing, so all three answer the same lines at the same exit
         code — declared here, once, exactly as versionFlag declares its
         own single spelling, so the grammar keeps one exception per
         flag and each exception has a name."
        <category: 'help'>
        ^#('--help' '-h' 'help')
    ]

    CommandLine class >> publishLayoutFlag [
        "The flag that states the layout. A VALUED flag rather than a
         bare --sparse switch is deliberate: valueOf:in: already reads
         --flag <value> pairs, so the settled argv grammar needs no new
         shape."
        <category: 'publish layouts'>
        ^'--layout'
    ]

    CommandLine class >> defaultPublishLayout [
        "The layout publish writes when the flag is absent: flat, so
         every settled publish keeps its byte-identical output."
        <category: 'publish layouts'>
        ^self publishLayoutNamed: 'flat'
    ]

    CommandLine class >> publishLayoutNamed: aName [
        "The declared row for aName, or nil when the table declares
         none — which the caller answers as usage, never as a
         fallback."
        <category: 'publish layouts'>
        self publishLayouts do: [:row |
            (row at: 1) = aName ifTrue: [^row]].
        ^nil
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
         the new schema is covered the moment it exists — and, from
         Sprint 14, the SparseIndexSource listing read (Doc F §7.2),
         and from Sprint 15 the Publisher's read of the listing it is
         about to rewrite (Doc F §8.2): publishing into an index that
         already holds the package means loading its versions.st
         first, which makes the producer a boundary exactly as the
         consumer is. The same file kind, read from opposite ends of
         the ecosystem, each naming it the way ITS operator can act
         on.
         From Sprint 19 the FIFTH sender is Configuration, reading the
         operator's own parley.config.st under the new
         #'parley-config' 1 schema (Doc B §5.7): a file at the project
         root that an operator writes by hand is a deserialization
         boundary by exactly the argument this table was built on.
         ManifestFile is
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
        ^(Array
            with: (Array with: CLI with: 'parley.lock')
            with: (Array with: DirectorySource
                with: 'index entries and retirement records')
            with: (Array with: ManifestFile with: 'Package.st')),
            (Array with: (Array with: SparseIndexSource
                with: 'version listings')
                with: (Array with: Publisher
                    with: 'version listings')
                with: (Array with: Configuration
                    with: 'parley.config.st'))
    ]

    "---- the declared path boundaries (Doc E §4.1, §8 decisions 59/60/72) ----"

    CommandLine class >> pathBoundaries [
        "EVERY FILE BOUNDARY IN THE TOOL: each row is the path role an
         operator would call it by, its DIRECTION, and the declared
         error it must answer.

         WHY A TABLE RATHER THAN TWELVE FIXES. ManifestFile said
         missing or unreadable Package.st from Sprint 8 while its
         predicate tested exists alone — eight sprints of a right
         sentence over a missing predicate, invisible because reviewers
         read the sentence and nothing in this repository could compare
         a sentence against a check. This is what a reviewer reads to
         find the THIRTEENTH boundary, and the laws over it drive every
         row through the hostile state its direction defines and
         through the mirror of that state.

         A DECLARATION CONSUMED TWICE, exactly as sourceFlags,
         publishLayouts and deserializationBoundaries are: the laws
         iterate it, and the drivers are asserted against it first, so
         a row added without a driver fails the suite rather than
         quietly widening the claim.

         TEN ROWS AN OPERATOR REACHES BY RUNNING A VERB, and three the
         tool reaches on its own behalf. The wiring state directory,
         the archive cache and the index cache are rows like any other;
         what they lack is a remedy sentence of their OWN, because an
         operator does not choose where the content store lives.

         THE THIRTEENTH ROW ARRIVED WITH THE TABLE'S FULL DISCIPLINE
         (§8 decision 65, Sprint 19). parley.config.st is a new
         operator-editable file, and the cheapest moment to give a new
         boundary the diagnosis every other boundary earned is the
         sprint that introduces it — the only moment when nothing has
         shipped depending on the wrong behaviour. Its carrier is
         ExecutionError by decision 72's precedent applied a second
         time: the settled carrier for a filesystem precondition in the
         '<path>: ...' grammar, at the composition root, and A CARRIER
         RATHER THAN AN ATTRIBUTION — a malformed configuration has
         nothing to do with executing anything. The alternatives fail on
         their own stated grounds: SourceError batches for a project
         where this is one file with one defect, and LockError's checked
         remedy names parley update, which cannot repair a config.

         THE WIRING STATE DIRECTORY'S ERROR IS A CARRIER, NOT AN
         ATTRIBUTION (§8 decision 72). CommandLine creates
         <workdir>/.parley and <workdir>/.parley/packages once a verb
         is known to run, which makes it the FIRST write every verb
         performs — so in a working directory the operator cannot
         write, it is what fails first, for init as much as for
         resolve. ExecutionError carries that refusal because Sprint 16
         already gave it the job of carrying a filesystem precondition
         in the settled '<path>: ...' grammar and because
         .parley/packages is ExecutionScope's own target — NOT because
         the failure has anything to do with executing something. An
         init refused in a read-only directory does not. A class name
         silently doing duty as a blame label would be the same defect
         as a diagnosis claiming more than it checked (decision 43).

         The publish STAGE is deliberately absent. It is created inside
         the destination and only after that destination's own precheck
         has passed, so it has no reachable hostile state of its own —
         and a row nothing can drive is documentation, which is the
         shape this table exists to replace.

         THE FOURTH COLUMN IS HOW THE ROW IS GUARDED (§8 decision 73).
         Every row PRECHECKS through PathGuard; #guarded rows also
         route the operation through its translating seam.
         Package.st (read) is #prechecked — precheck yes, translate no
         — and that is a ruling rather than an omission: ManifestFile
         files the AUTHOR'S OWN PROGRAM in, and a broad translation
         around that block would relabel a vocabulary typo or a
         division by zero as an I/O failure, which is §8 decision 52's
         discriminator and Sprint 18's boundary. It is a column and not
         a comment because Sprint 8's ManifestFile defect was a right
         sentence over a missing predicate that survived eight sprints,
         and it survived because the reasoning lived where nothing
         could compare it against the code.

         3.2.5's Array class >> with: stops at five arguments, so the
         rows are concatenated rather than passed."
        <category: 'path boundaries'>
        ^(Array
            with: (Array with: 'Package.st (read)' with: #read
                with: ManifestError with: #prechecked)
            with: (Array with: 'Package.st (write)' with: #write
                with: ManifestError with: #guarded)
            with: (Array with: 'parley.lock (read)' with: #read
                with: LockError with: #guarded)
            with: (Array with: 'parley.lock (write)' with: #write
                with: LockError with: #guarded)
            with: (Array with: 'the exec script (read)' with: #read
                with: ExecutionError with: #guarded)),
            (Array
                with: (Array with: 'the source directory (read)' with: #read
                    with: SourceError with: #guarded)
                with: (Array with: 'the index entry (read)' with: #read
                    with: SourceError with: #guarded)
                with: (Array with: 'the star archive (read)' with: #read
                    with: SourceError with: #guarded)
                with: (Array with: 'the publish destination (write)'
                    with: #write with: PublishError with: #guarded)
                with: (Array with: 'the wiring state directory (write)'
                    with: #write with: ExecutionError with: #guarded)),
            (Array
                with: (Array with: 'the archive cache (write)' with: #write
                    with: InstallError with: #guarded)
                with: (Array with: 'the index cache (write)' with: #write
                    with: SourceError with: #guarded)
                with: (Array with: 'parley.config.st (read)' with: #read
                    with: ExecutionError with: #guarded))
    ]

    CommandLine class >> wrongTypeStateDirectoryTail [
        "THE STATE-ROOT ROW'S SECOND DECLARED SENTENCE (§8 decision 74,
         Sprint 18; Doc E §4.1). The row keeps its role, its direction,
         its declared error and its guarding — what it gains is a
         sentence for the state ensureDirectory: could not previously
         tell apart, and it is declared HERE, beside the table a reviewer
         reads to find the next boundary, rather than inline at the one
         site that composes it.

         IT NAMES A CAUSE THAT WAS CHECKED AND A REMEDY THAT WORKS
         (§8 decision 58). The predicate is exactly `the path exists and
         is not a directory`, which is what `not a directory` says; and
         the path is the operator's own file, so removing it is a repair
         they can perform — unlike `check its permissions`, which was
         advice about a directory whose permissions were already fine.
         The shape is the one the parley.lock row carries: cause, dash,
         remedy, after a path the line opens with."
        <category: 'path boundaries'>
        ^'not a directory - remove it and try again'
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
        | args choice |
        args := self withoutLeadingMarker: anArgvArray.
        "The two question flags are answered ahead of verb dispatch and
         BEFORE any state directory is created (§8 decision 57): asking
         a tool what it is or how to use it is not running a command in
         a project, so neither needs a working directory and neither may
         leave one behind. They are also answered before the
         CONFIGURATION is read, for the same reason and one more: a
         question must not fail on a file it does not need."
        (self isVersionRequest: args) ifTrue: [^self versionResult].
        (self isHelpRequest: args) ifTrue: [^self helpResult].
        "The source flags are mutually exclusive: both given is a usage
         error, because silently preferring one would make a typo look
         like a working command. Checked before anything is created or
         built, so a usage error touches nothing."
        (self sourceRowsIn: args) size > 1 ifTrue: [
            ^self usageResultFor: #bothSourceFlags subject: ''].
        "THE PRECEDENCE DECISION, AND IT IS THIS ONE LINE (§8 decision
         64; Doc E §4.2). An explicit flag always wins, and the
         configuration is then NEVER CONSULTED — not per key, not for the
         keys the argv left absent, not at all. Filling each absent key
         from the file independently would pass every law that drives a
         flag against a file declaring the SAME key, and would wire
         --git from the file alongside an explicit --source, which the
         settled mutually-exclusive grammar above answers with the usage
         lines: recording a source would break overriding it, on the
         first command anyone types after writing the file.
         It happens BEFORE the usage determination, because a malformed
         configuration must be diagnosed as a broken file and not as an
         operator who forgot a flag; and BEFORE createStateDirectories,
         because a refused command leaves the filesystem as it found
         it."
        choice := self sourceChoiceIn: args.
        "AND NO OTHER USAGE ERROR CREATES PROJECT STATE EITHER (§8
         decision 57, second half). The question flags were placed above
         createStateDirectories because state created by a question is
         state created by a question, and that reason covers every argv
         that never reaches a verb — which the shipped ordering did not
         honour: parley, parley nonsense and parley resolve each created
         <cwd>/.parley/packages before answering the usage they were
         always going to answer, so typing parley in any directory to
         see what it does left a directory behind. A command that
         refuses to run leaves the filesystem as it found it, which is
         the rule publish already follows when it declines to create a
         destination it refuses (Doc F §1)."
        (self answersUsageFor: args withSource: choice notNil)
            ifTrue: [
                | verbArgv |
                verbArgv := self verbArgvIn: args.
                ^self usageResultFor: (CLI usageGroundFor: verbArgv
                    withSource: choice notNil)
                    subject: (CLI usageSubjectFor: verbArgv)].
        self createStateDirectories.
        ^(self cliWithSource: (self sourceFromChoice: choice))
            run: (self verbArgvIn: args)
    ]

    sourceChoiceIn: anArgvArray [
        "Private — WHICH source this invocation uses, as a (row, value)
         pair, or nil when it uses none. THE ONE PLACE PRECEDENCE IS
         DECIDED, and the reason Configuration decides none: it reads a
         file and answers values, and choosing between a value and a
         flag is wiring.

         It is a pair rather than a built source because the two must
         happen at different moments: the CHOICE is needed before the
         usage determination, and building a --git or --index source
         creates its cache root under .parley/, which cannot happen
         until createStateDirectories has run (3.2.5's Directory create:
         is not recursive)."
        <category: 'private-wiring'>
        | rows |
        rows := self sourceRowsIn: anArgvArray.
        rows isEmpty ifFalse: [
            ^Array with: rows first
                with: (self valueOf: (rows first at: 1) in: anArgvArray)].
        ^self configuredChoice
    ]

    configuredChoice [
        "Private — the row the project's configuration records, with its
         value, or nil when it records none or there is no file.

         The declared table is asked in its own order, which is Doc B
         §5.7's fixed key order: a file may record at most one source,
         and the read boundary refuses one that records two, so the
         first non-nil value is the only non-nil value."
        <category: 'private-wiring'>
        | config |
        config := Configuration in: workingDir.
        self class sourceFlags do: [:row |
            | value |
            value := config valueFor: (row at: 1).
            value isNil ifFalse: [^Array with: row with: value]].
        ^nil
    ]

    sourceFromChoice: aChoice [
        "Private — the source a choice builds, nil when there is none.
         The row says which message builds it, so adding a source is
         adding a row and a builder — never a branch here, and never a
         second branch for the configured case: a flag and a file that
         name the same source build the same object."
        <category: 'private-wiring'>
        aChoice isNil ifTrue: [^nil].
        ^self perform: ((aChoice at: 1) at: 3) with: (aChoice at: 2)
    ]

    answersUsageFor: anArgvArray withSource: aBoolean [
        "Private — whether this argv answers usage rather than running a
         verb, asked of the SETTLED CLI's own determination so the two
         can never disagree about what a verb is. Duplicating the verb
         grammar here would be the drift sourceFlags, publishLayouts and
         deserializationBoundaries each exist to prevent.

         It is a function of the argv and of whether a source WILL BE
         WIRED — never of the source OBJECT, which is deliberate:
         building a --git or --index source creates its cache root under
         .parley/, so the build must stay BELOW createStateDirectories,
         and a determination that needed the built source could not run
         above it. From Sprint 19 the availability half comes from the
         CHOICE rather than from the argv alone, because a project that
         records its index in parley.config.st has a source without
         naming one on the command line."
        <category: 'private-grammar'>
        ^(CLI verbRowFor: (self verbArgvIn: anArgvArray)
            withSource: aBoolean) isNil
    ]

    isVersionRequest: anArgvArray [
        "Private — ONE DECLARED SPECIAL CASE, and deliberately not a
         new grammar class.

         The settled grammar reads --flag <value> pairs, and
         valueOf:in: treats a TRAILING flag as not a flag: it travels
         on to the settled CLI, which answers usage at exit 2. Several
         settled laws rest on exactly that. --version carries no value,
         and teaching the grammar that valueless flags are flags would
         silently change what every one of those laws is testing
         without touching a line of them — they would keep passing and
         would no longer be about the same thing.

         So the shape is recognized here, once, and narrowly: the whole
         argv is the flag and nothing else. Anything longer travels on
         as the unknown shape it is."
        <category: 'private-grammar'>
        ^anArgvArray size = 1
            and: [(anArgvArray at: 1) = self class versionFlag]
    ]

    isHelpRequest: anArgvArray [
        "Private — the SECOND declared special case, recognized exactly
         as narrowly as the first: the whole argv is one of the three
         accepted spellings and nothing else. Anything longer travels on
         to the settled CLI as the unknown shape it is, and a TRAILING
         --help on a verb stays a usage error, because the settled
         valueOf:in: treats a trailing flag as not a flag and several
         settled laws rest on exactly that. Teaching the grammar that
         valueless flags are flags would silently change what every one
         of those laws is testing without touching a line of them."
        <category: 'private-grammar'>
        ^anArgvArray size = 1
            and: [self class helpFlags includes: (anArgvArray at: 1)]
    ]

    helpResult [
        "Private — THE BLOCK ALONE, at exit 0.

         Exit 0 is the whole point of §8 decision 57: the text was
         already printed for --help, but at exit 2, so the first command
         a new user types failed any set -e script or CI smoke check
         while --version beside it succeeded.

         IT NO LONGER TAKES THE USAGE ANSWER WHOLESALE, and the comment
         that recorded that as a feature is gone with it (§8 decision
         79). `The question and the usage error can never print two
         different texts` was true and became the wrong economy the
         moment a usage error started naming what was wrong: --help
         would have inherited `no verb given`, asserting a fault in a
         request that has none, which is the very thing decision 57
         exists to prevent.

         THE SHARED ARTIFACT IS THE BLOCK, NOT THE ANSWER. Both compose
         CLI class >> usageBlock, so the two can still never disagree
         about what the tool offers; neither is derived from the other's
         finished answer, so neither can inherit the other's claim about
         what just happened."
        <category: 'private'>
        ^CliResult lines: CLI usageBlock exitCode: 0
    ]

    versionResult [
        "Private — one line naming the tool and its version, exit 0.
         The version half comes from Parley version, which is its one
         definition (issue #17 S13)."
        <category: 'private'>
        ^CliResult lines: (Array with: self class versionLine) exitCode: 0
    ]

    usageResultFor: aGroundSymbol subject: aSubject [
        "Private — the ground's declared reason line, then the settled
         block, exit 2.

         It composes from the CLASS-SIDE declarations rather than by
         running a source-less CLI on an empty argv, which is how this
         method used to obtain its lines: that trick shared the whole
         ANSWER where only the BLOCK is shared, so under decision 79 it
         would have answered `no verb given` to an operator who gave a
         verb and two source flags."
        <category: 'private'>
        ^CliResult
            lines: (CLI usageLinesFor: aGroundSymbol subject: aSubject)
            exitCode: 2
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

    indexSourceOn: aBaseUrl [
        "Private — the '--index <base>' builder (Sprint 14): the --git
         convention applied to the second remote source. The cache
         lives under the working directory, keyed through the settled
         Sha256 of the base URL — any URL becomes one deterministic
         filesystem-safe name. The cache ROOT is created here; the
         layout inside it is the source's own business, at its one I/O
         moment."
        <category: 'private-wiring'>
        self ensureDirectory: self indexCacheRoot.
        ^SparseIndexSource
            base: aBaseUrl
            cache: (self indexCachePathFor: aBaseUrl)
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
        "Private — create aPath when it is absent; silent otherwise.

         THE EARLIEST WRITE OF ALL (§8 decision 72, Sprint 17). These
         directories appear once a verb is known to run (decision 57),
         which makes this the FIRST write every verb performs — so in a
         working directory the operator cannot write, this is what
         fails first, for resolve, init and everything else. It answered
         FileError: Permission denied at exit 70, naming nothing.

         It is the wiring-state-directory row of the boundary table,
         direction write, declared error ExecutionError. THAT CLASS IS
         THE CARRIER, NOT AN ATTRIBUTION: Sprint 16 gave ExecutionError
         the job of carrying a filesystem precondition in the settled
         '<path>: ...' grammar, and .parley/packages is
         ExecutionScope's own target, so no settled class fits better
         and no new one is warranted. An init refused in a read-only
         directory has nothing to do with executing anything.

         The refusal names the PARENT — the directory the creation
         failed in. Told their project directory could not be written
         an operator can act; told <workdir>/.parley could not be
         written they are reading a name Parley invented.

         AND NAMING THE PARENT CONFLATED TWO STATES (§8 decision 74,
         Sprint 18 — method finding F13). The rule above is right for the
         state it was written for and FALSE for one it never considered:
         when aPath EXISTS AND IS NOT A DIRECTORY — a regular file at
         <workdir>/.parley, or at <workdir>/.parley/packages with
         .parley writable — the create fails for a reason that has
         nothing to do with the parent, and the refusal said
         <workdir>: could not be written - check its permissions and try
         again about a directory test -w reports WRITABLE, with a remedy
         that cannot work. That is §8 decision 58's standard broken by
         the newest row in the table Sprint 17 built, and it stayed
         invisible because the exit code was right: 1, then as now.

         SO THE STATES ARE DISTINGUISHED BY PREDICATE BEFORE ANYTHING IS
         COMPOSED, and the wrong-type state names THE OFFENDING PATH
         ITSELF with a cause that was checked and a remedy that works —
         the shape the parley.lock row already carries. The parent-naming
         rule survives underneath it, for the state it was written for.

         THE SPLIT LIVES HERE RATHER THAN AT A CALL SITE, AND THAT IS THE
         RULING RATHER THAN A CONVENIENCE. This method has FOUR callers —
         the git cache root, the index cache root, <workdir>/.parley and
         <workdir>/.parley/packages — so a split written into
         createStateDirectories, or repeated per path, would leave a
         regular file at <workdir>/.parley/index answering the identical
         false sentence under --index with no law over it. Totality over
         the SITES the rule must reach is the same obligation as totality
         over the STATES a path can take (F13's own clause), and one
         method that every caller goes through is the only shape that
         gets both by construction."
        <category: 'private-wiring'>
        (PathGuard isDirectory: aPath) ifTrue: [^aPath].
        (PathGuard exists: aPath) ifTrue: [
            ^ExecutionError new signal: (PathGuard lineFor: aPath
                saying: self class wrongTypeStateDirectoryTail)].
        ^PathGuard ensureDirectory: aPath
            ifRefused: [:path |
                ExecutionError new signal: (PathGuard
                    unwritableLineFor: (PathGuard parentOf: path))]
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

    indexCacheRoot [
        <category: 'private-wiring'>
        ^self parleyDir, '/index'
    ]

    indexCachePathFor: aBaseUrl [
        <category: 'private-wiring'>
        ^self indexCacheRoot, '/', (Sha256 hexDigestOf: aBaseUrl)
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
