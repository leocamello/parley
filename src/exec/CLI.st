"Parley — CLI: the package-manager verbs over everything beneath.
 Spec: docs/design/execution-and-cli.md §4; issue #8 S10-S19.
 An orchestration answering a value: run: dispatches the MVP argv
 grammar (init | resolve | install | update | exec <script>) and
 answers an immutable CliResult. The CLI never prints, never
 terminates the image, and never touches a process except through the
 scope's runner. Its own I/O is confined to the working directory's
 Package.st (init template, ManifestFile load) and parley.lock
 (settled reader/writer).

 install is the lockfile fast path (Doc E §4.1): a valid pin is used
 WITHOUT consuming the source's snapshot; invalid or absent resolves
 fresh and rewrites the lock; then hash-vs-cache (a stored-but-
 unverifiable pin is a fail-stop corruption report — the store never
 repairs itself), then the settled Installer (cache hits skip fetch),
 then ExecutionScope register. update ignores any existing lock:
 install keeps a valid pin; update is the verb that moves it. All
 wordings pinned in RED (issue #8)."

Namespace current: Parley.

Object subclass: CLI [
    | workingDir source store target runner |

    <comment: 'The command-line orchestration over five injected
collaborators: the working directory (Package.st and parley.lock), a
PackageSource (nil for verbs that need none), a ContentStore, the
target directory and a ProcessRunner. run: answers a CliResult value;
every effect flows through the settled objects beneath. Class-side
construction; zero public setters.'>

    CLI class >> in: aWorkingDir source: aPackageSource store: aContentStore target: aTargetDir runner: aProcessRunner [
        "Answer a CLI over the injected collaborators; aPackageSource
         may be nil for verbs that need no source."
        <category: 'instance creation'>
        ^self new
            setWorkingDir: aWorkingDir
            source: aPackageSource
            store: aContentStore
            target: aTargetDir
            runner: aProcessRunner
    ]

    setWorkingDir: aWorkingDir source: aPackageSource store: aContentStore target: aTargetDir runner: aProcessRunner [
        "Private — initialization from the class-side constructor."
        <category: 'private'>
        workingDir := aWorkingDir.
        source := aPackageSource.
        store := aContentStore.
        target := aTargetDir.
        runner := aProcessRunner
    ]

    "---- dispatch ----"

    run: anArgvArray [
        "Dispatch the argv and answer a CliResult. Unknown input, a
         missing exec script, wrong arity, or a source-requiring verb
         without a source answers the usage lines, exit 2."
        <category: 'running'>
        | verb |
        anArgvArray isEmpty ifTrue: [^self usage].
        verb := anArgvArray at: 1.
        (verb = 'init' and: [anArgvArray size = 1])
            ifTrue: [^self init].
        (verb = 'exec' and: [anArgvArray size = 2])
            ifTrue: [^self exec: (anArgvArray at: 2)].
        (anArgvArray size = 1 and: [source notNil]) ifTrue: [
            verb = 'resolve' ifTrue: [^self resolve].
            verb = 'install' ifTrue: [^self install].
            verb = 'update' ifTrue: [^self update]].
        ^self usage
    ]

    "---- the verbs ----"

    init [
        "Write the Doc B §2 template Package.st; refuse (one line,
         exit 1) when the file already exists."
        <category: 'verbs'>
        | file stream |
        file := File name: self packagePath.
        file exists ifTrue: [
            ^CliResult
                lines: (Array with: 'Package.st already exists - refusing to overwrite')
                exitCode: 1].
        stream := file writeStream.
        [stream nextPutAll: self templateContents] ensure: [stream close].
        ^CliResult lines: (Array with: 'wrote Package.st') exitCode: 0
    ]

    resolve [
        "Load the manifest, resolve against the source's snapshot,
         write the byte-stable lock on success (exit 0) or answer the
         conflict narration (exit 1) — a conflict is a value, never an
         exception."
        <category: 'verbs'>
        | outcome |
        outcome := self resolveAndLock: self loadManifest.
        outcome isResolution ifFalse: [^self reportConflict: outcome].
        ^self reportPins: outcome
    ]

    install [
        "The lockfile fast path, then the Sprint 5 pipeline, then
         registration (Doc E §4.1)."
        <category: 'verbs'>
        ^self installResolution: self pinnedOrFreshResolution
    ]

    update [
        "Ignore any existing lock: resolve fresh, rewrite the lock,
         then install and register as install does. install keeps a
         valid pin; update is the verb that moves it."
        <category: 'verbs'>
        ^self installResolution: (self resolveAndLock: self loadManifest)
    ]

    exec: aScriptPath [
        "Run the script in the curated child; the CliResult carries
         the child's exit code and no lines of the CLI's own (the
         child already streamed to the terminal)."
        <category: 'verbs'>
        | code |
        code := (ExecutionScope
            on: (InstalledSet tuples: Dictionary new)
            target: target
            runner: runner) run: aScriptPath.
        ^CliResult lines: #() exitCode: code
    ]

    "---- the install pipeline ----"

    installResolution: anOutcome [
        "Private — the shared install tail: conflict report,
         hash-vs-cache fail-stop, Installer, register."
        <category: 'private'>
        | corrupt set |
        anOutcome isResolution ifFalse: [^self reportConflict: anOutcome].
        corrupt := self corruptHashIn: anOutcome.
        corrupt notNil ifTrue: [^self reportCorruption: corrupt].
        set := [(Installer source: source store: store) install: anOutcome]
            on: InstallError
            do: [:e | ^CliResult lines: e problems exitCode: 1].
        [(ExecutionScope on: set target: target runner: runner) register]
            on: ExecutionError
            do: [:e | ^CliResult lines: (Array with: e messageText) exitCode: 1].
        ^self reportPins: anOutcome
    ]

    pinnedOrFreshResolution [
        "Private — the fast path: a valid pin is used without
         consuming the source's snapshot; invalid or absent resolves
         fresh and rewrites the lock."
        <category: 'private'>
        | manifest pinned |
        manifest := self loadManifest.
        pinned := self pinnedResolution.
        (pinned notNil
            and: [(PinVerification of: manifest lock: pinned) isValid])
            ifTrue: [^pinned].
        ^self resolveAndLock: manifest
    ]

    pinnedResolution [
        "Private — the lock's Resolution through the settled reader,
         nil when no lock exists."
        <category: 'private'>
        | file |
        file := File name: self lockPath.
        file exists ifFalse: [^nil].
        ^Resolution fromLockEntry:
            (IndexEntryReader readFrom: (ReadStream on: file contents))
    ]

    resolveAndLock: aManifest [
        "Private — resolve fresh against the source's snapshot; a
         Resolution rewrites the lock, a ConflictReport writes
         nothing."
        <category: 'private'>
        | outcome |
        outcome := (Resolver strategy: BacktrackingStrategy new)
            resolve: aManifest against: source snapshot.
        outcome isResolution ifTrue: [self writeLock: outcome].
        ^outcome
    ]

    corruptHashIn: aResolution [
        "Private — the first pinned hash the store contains but cannot
         verify, in sorted package-name order; nil when clean. An
         absent hash is the installer's business (it will fetch), and
         '' is never a store key."
        <category: 'private'>
        aResolution packageNames do: [:name |
            | sha |
            sha := aResolution sha256Of: name.
            ((store containsHash: sha)
                and: [(store verifyHash: sha) not]) ifTrue: [^sha]].
        ^nil
    ]

    "---- collaborating paths and values ----"

    loadManifest [
        "Private — the working directory's own Package.st through
         ManifestFile (decision 19)."
        <category: 'private'>
        ^ManifestFile load: self packagePath
    ]

    packagePath [
        "Private — the manifest the CLI reads and init writes."
        <category: 'private'>
        ^workingDir, '/Package.st'
    ]

    lockPath [
        <category: 'private'>
        ^workingDir, '/parley.lock'
    ]

    writeLock: aResolution [
        "Private — the byte-stable lock through the settled writer."
        <category: 'private'>
        | stream |
        stream := (File name: self lockPath) writeStream.
        [IndexEntryWriter writeLock: aResolution on: stream]
            ensure: [stream close]
    ]

    "---- results ----"

    usage [
        "Private — the pinned usage lines, exit 2."
        <category: 'private'>
        ^CliResult
            lines: (Array
                with: 'usage: parley <verb>'
                with: 'verbs: init | resolve | install | update | exec <script> | publish <dir>')
            exitCode: 2
    ]

    reportPins: aResolution [
        "Private — one '<name> <version>' line per resolved pin in
         sorted package-name order, exit 0."
        <category: 'private'>
        ^CliResult
            lines: (aResolution packageNames collect: [:name |
                name, ' ', (aResolution versionOf: name) printString])
            exitCode: 0
    ]

    reportConflict: aReport [
        "Private — the narration, one line per sentence, exit 1."
        <category: 'private'>
        ^CliResult lines: (self linesOf: aReport printString) exitCode: 1
    ]

    reportCorruption: aHexString [
        "Private — the pinned fail-stop corruption line, exit 1;
         detection only, the store never repairs itself."
        <category: 'private'>
        ^CliResult
            lines: (Array with: 'store corruption: ', aHexString,
                ' no longer matches its content address - the store never repairs itself')
            exitCode: 1
    ]

    linesOf: aString [
        "Private — aString split at newlines, as an Array."
        <category: 'private'>
        | lines stream |
        lines := OrderedCollection new.
        stream := ReadStream on: aString.
        [stream atEnd] whileFalse: [
            lines add: (stream upTo: Character nl)].
        ^lines asArray
    ]

    templateContents [
        "Private — the Doc B §2 template, byte-exact (pinned in RED)."
        <category: 'private'>
        ^'"Package.st"
Parley define: [:pkg |
    pkg
        name: ''kernel-json'';
        version: ''0.3.1'';
        summary: ''A JSON reader/writer speaking pure message sends'';
        author: ''Leonardo'';
        license: ''MIT'';
        fileIns: #(''Reader.st'' ''Writer.st'' ''Extensions.st'');
        dependency: ''kernel-streams'' constraint: ''>=1.0 <2.0'';
        dependency: ''kernel-strings'' constraint: ''^0.4.2'' ]',
            (String with: Character nl)
    ]
]

Namespace current: Smalltalk.
