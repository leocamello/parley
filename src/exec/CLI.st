"Parley — CLI: the package-manager verbs over everything beneath.
 Spec: docs/design/execution-and-cli.md §4; issue #8 S10-S19.
 An orchestration answering a value: run: dispatches the argv
 grammar (init | resolve | install | update [<pkg>] |
 add <pkg> <constraint> | exec <script> |
 publish <dir> | why <pkg> | tree | check) and answers an immutable
 CliResult. The CLI never
 prints, never terminates the image, and never touches a process
 except through the scope's runner. Its own I/O is confined to the
 working directory's Package.st (init template, ManifestFile load)
 and parley.lock (settled reader/writer); publish's I/O belongs to
 the Publisher, confined to its destination.

 publish (Doc F §5, Sprint 7 — the declared CLI exception): load the
 manifest, run the Publisher pipeline, answer one success line naming
 the package and version on exit 0, or the PublishError's problems on
 exit 1. It needs no source collaborator.

 install is the lockfile fast path (Doc E §4.1): a valid pin is used
 WITHOUT consuming the source's snapshot; invalid or absent resolves
 fresh and rewrites the lock; then hash-vs-cache (a stored-but-
 unverifiable pin is a fail-stop corruption report — the store never
 repairs itself), then the settled Installer (cache hits skip fetch),
 then ExecutionScope register. update ignores any existing lock:
 install keeps a valid pin; update is the verb that moves it. All
 wordings pinned in RED (issue #8).

 update <pkg> (Doc E §4.1, Sprint 12 — the second declared exception
 on this class): moves ONE package and leaves the rest of the lock
 where it is, by resolving the ordinary way against a snapshot
 narrowed to hold every other pin (IndexSnapshot>>holding:, Doc C
 §2.2). The resolver is untouched — a selective update is a normal
 resolution of a smaller world. Its three diagnoses are all exit 1;
 already-newest is a success with a line saying so; install and
 register run exactly as update does. Wordings pinned in RED
 (issue #14).

 add <pkg> <constraint> (Doc B §2.1, Doc E §4.1, Sprint 13 — the third
 declared exception on this class): declares a new dependency in
 Package.st and moves the project to it in one operation. The edit is a
 TEXTUAL INSERTION into a cascade the settled ManifestEditor
 recognizes, verified by re-loading through ManifestFile load:, and
 rolled back on any refusal — because Package.st is executable
 Smalltalk the author owns and Parley never re-renders what it did not
 write (§8 decision 49). It then resolves against a snapshot holding
 EVERY existing pin (Doc C §2.2, the third application after
 retirement and selective update), rewrites the lock byte-stably, and
 installs and registers exactly as update does.

 add is ATOMIC: every diagnosis restores the original Package.st and
 the lock as it stood, so a failed add leaves a project byte-identical
 to how it started. Its four diagnoses are all exit 1; adding what is
 already declared identically is an idempotent success. Wordings
 pinned in RED (issue #15).

 The deleted-held-pin diagnosis is SHARED by add and update <pkg>: a
 pin the index no longer publishes narrated as an ordinary version
 conflict, which is sound under §8 decision 47 and misleading, because
 the real defect is a missing index entry."

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

    CLI class >> row: aGuardBlock verb: aSelector args: anIndexArray [
        "Private — one dispatch row: a pure guard on (argv, has-source),
         the verb selector it selects, and the argv indices its
         arguments come from."
        <category: 'dispatch'>
        ^Array with: aGuardBlock with: aSelector with: anIndexArray
    ]

    CLI class >> verbRows [
        "The argv grammar as a DECLARED TABLE (Doc E §4, Sprint 16 —
         the fourth declared settled-class exception on this class).
         Each row is a guard, the verb it selects, and where that verb's
         arguments sit in the argv. The grammar itself is unchanged, verb
         for verb and arity for arity; only its spelling moved.

         A DECLARATION CONSUMED TWICE, exactly as sourceFlags,
         publishLayouts and deserializationBoundaries are: run: performs
         the matching row's verb, and verbRowFor:withSource: answers
         whether any row matched AT ALL — which is the usage
         determination, and which CommandLine needs BEFORE it creates a
         state directory, because a command that refuses to run must
         leave the filesystem as it found it (§8 decision 57). Two
         parallel lists that happened to agree today would buy nothing
         the first time a verb was added to only one of them.

         Row order is the settled chain's order and stays significant
         only where guards could overlap; publish's two shapes are
         disjoint by arity. publish <dir> --layout <name> reads its own
         flag because CommandLine consumes only the SOURCE flags, so the
         layout arrives in the verb argv (Doc F §8.1); an unrecognized
         value is usage inside the verb, never a fallback."
        <category: 'dispatch'>
        ^(Array
            with: (self row: [:a :s | a size = 1 and: [(a at: 1) = 'init']]
                verb: #init args: #())
            with: (self row: [:a :s | a size = 2 and: [(a at: 1) = 'exec']]
                verb: #exec: args: #(2))
            with: (self row: [:a :s | a size = 2 and: [(a at: 1) = 'publish']]
                verb: #publish: args: #(2))
            with: (self row: [:a :s | a size = 4
                    and: [(a at: 1) = 'publish'
                    and: [(a at: 3) = CommandLine publishLayoutFlag]]]
                verb: #publish:layoutNamed: args: #(2 4))
            with: (self row: [:a :s | s and: [a size = 2
                    and: [(a at: 1) = 'why']]]
                verb: #why: args: #(2))),
        (Array
            with: (self row: [:a :s | s and: [a size = 2
                    and: [(a at: 1) = 'update']]]
                verb: #update: args: #(2))
            with: (self row: [:a :s | s and: [a size = 3
                    and: [(a at: 1) = 'add']]]
                verb: #add:constraint: args: #(2 3))
            with: (self row: [:a :s | s and: [a size = 1
                    and: [(a at: 1) = 'resolve']]]
                verb: #resolve args: #())
            with: (self row: [:a :s | s and: [a size = 1
                    and: [(a at: 1) = 'install']]]
                verb: #install args: #())
            with: (self row: [:a :s | s and: [a size = 1
                    and: [(a at: 1) = 'update']]]
                verb: #update args: #())),
        (Array
            with: (self row: [:a :s | s and: [a size = 1
                    and: [(a at: 1) = 'tree']]]
                verb: #tree args: #())
            with: (self row: [:a :s | s and: [a size = 1
                    and: [(a at: 1) = 'check']]]
                verb: #check args: #()))
    ]

    CLI class >> verbRowFor: anArgvArray withSource: aBoolean [
        "The row anArgvArray selects, or nil when it selects no verb at
         all — an empty argv, an unknown verb, wrong arity, or a
         source-requiring verb with no source. NIL IS THE USAGE
         DETERMINATION, and it is the same one run: makes.

         PURE, AND THAT IS PART OF THE CONTRACT: a function of the argv
         and of whether a source was wired, reading no file, creating
         nothing and spawning nothing. CommandLine asks it before any
         state directory exists, and a determination that touched the
         filesystem would be doing the verb's work before the verb."
        <category: 'dispatch'>
        anArgvArray isEmpty ifTrue: [^nil].
        self verbRows do: [:row |
            ((row at: 1) value: anArgvArray value: aBoolean)
                ifTrue: [^row]].
        ^nil
    ]

    run: anArgvArray [
        "Dispatch the argv and answer a CliResult. Unknown input, a
         missing exec script, wrong arity, or a source-requiring verb
         without a source answers the usage lines, exit 2.

         The dispatch is expressed in terms of the SELECTION, so the
         usage determination has exactly one definition and CommandLine
         can ask for it before it creates anything (see verbRows)."
        <category: 'running'>
        | row |
        row := self class verbRowFor: anArgvArray withSource: source notNil.
        row isNil ifTrue: [^self usage].
        ^self perform: (row at: 2)
            withArguments: ((row at: 3) collect: [:i | anArgvArray at: i])
    ]

    "---- the verbs ----"

    init [
        "Write the Doc B §2 template Package.st; refuse (one line,
         exit 1) when the file already exists."
        <category: 'verbs'>
        (PathGuard exists: self packagePath) ifTrue: [
            ^CliResult
                lines: (Array with: 'Package.st already exists - refusing to overwrite')
                exitCode: 1].
        self writePackage: self templateContents.
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

    update: aName [
        "Move ONE package and leave the rest of the lock where it is
         (Doc E §4.1, Sprint 12): resolve the ordinary way against the
         source's snapshot narrowed to hold every OTHER pin at its
         locked version (Doc C §2.2), rewrite the lock byte-stably,
         then install and register exactly as update does. Pins that
         did not move are byte-identical — the property that makes the
         diff reviewable.

         The three diagnoses, all exit 1: no lock (the inspection
         verbs' line — there is nothing to hold selectively when
         nothing is pinned, and the repair is resolve, the verb that
         writes a FIRST lock); a package not pinned (one line, the why
         precedent and the why wording); and held pins making the move
         impossible — the settled ConflictReport narration PRECEDED by
         one line naming that the other pins were held, because the
         resolver answered truthfully about a world with few candidates
         but cannot know why the world was small (provenance stays at
         the CLI, §8 decision 46). A conflict writes nothing.

         Already at the newest version its constraints allow is a
         SUCCESS with a line saying so, exit 0, the lock rewritten to
         identical bytes — the resolve-with-no-dependencies precedent:
         a verb that prints nothing reads as a verb that did nothing."
        <category: 'verbs'>
        | pinned held unheld narrowed deleted manifest outcome result |
        pinned := self pinnedResolution.
        pinned isNil ifTrue: [^self reportMissingLock].
        (pinned packageNames includes: aName) ifFalse: [
            ^CliResult
                lines: (Array with: aName printString,
                    ' is not pinned in parley.lock')
                exitCode: 1].
        held := self heldVersionsOf: pinned except: aName.
        "The unheld snapshot is kept rather than re-taken: holding:
         answers a NEW value and leaves the receiver answering every
         version (the Doc C §2.2 purity law), so the same snapshot
         serves the narrowed resolution and the decision-58 check below
         without consuming the source twice."
        unheld := self seededSource snapshot.
        narrowed := unheld holding: held.
        deleted := self deletedHeldPinLineIn: held against: narrowed.
        deleted notNil ifTrue: [
            ^CliResult lines: (Array with: deleted) exitCode: 1].
        manifest := self loadManifest.
        outcome := (Resolver strategy: BacktrackingStrategy new)
            resolve: manifest against: narrowed.
        outcome isResolution ifFalse: [
            ^CliResult
                lines: (self conflictLinesFor: outcome
                    manifest: manifest unheld: unheld)
                exitCode: 1].
        self writeLock: outcome.
        result := self installResolution: outcome.
        (result exitCode = 0
            and: [(outcome versionOf: aName) = (pinned versionOf: aName)])
            ifTrue: [
                ^CliResult
                    lines: (Array with: (self alreadyNewestLineFor: aName
                        version: (outcome versionOf: aName)))
                    exitCode: 0].
        ^result
    ]

    add: aName constraint: aConstraintString [
        "Declare a new dependency in Package.st and move the project to
         it in one operation (Doc E §4.1, Sprint 13).

         The edit is a textual insertion into a cascade the settled
         ManifestEditor recognizes, because Package.st is executable
         Smalltalk the author owns and the manifest is a lossy
         projection of it: re-rendering the file from the model would
         silently substitute a different program that happens to build
         an equal manifest, and would damage the most careful authors
         worst (§8 decision 49). It is then VERIFIED SEMANTICALLY —
         re-loaded through the settled ManifestFile load: and compared
         against the manifest loaded before — because Parley already
         owns the reader that decides what a Package.st means.

         Resolution runs against a snapshot holding EVERY existing pin
         (Doc C §2.2): adding one dependency is not a licence to move
         the ones already there, for the reason update <pkg> does not
         move them. Then the lock is rewritten byte-stably and install
         and register run exactly as update does.

         The verb is ATOMIC. Every refusal below, every failed reload
         and every failed resolution restores the original Package.st
         and the lock as it stood, so a failed add leaves the project
         byte-identical to how it started. The alternative — a manifest
         naming a dependency the lock does not pin — is exactly the
         state PinVerification exists to call broken, and it would have
         been manufactured by the tool.

         Its four diagnoses, all exit 1 and none of them exit 70: no
         Package.st (the settled missing-manifest line, §8 decision 31 —
         signaled by load: so the sentence keeps one definition); a
         shape the editor cannot recognize (one line naming the file and
         THE EXACT TEXT TO PASTE); already declared with a DIFFERENT
         constraint (one line naming the existing one — changing a
         constraint is an edit, and a verb that silently overwrote one
         would be a different verb wearing this name); and a held pin
         the index no longer publishes, the diagnosis shared with
         update <pkg>. A conflict under the held pins answers the
         settled ConflictReport narration preceded by the held-pins
         line, exactly as update <pkg> answers it.

         Already declared with the IDENTICAL constraint is a success
         with a line saying so, exit 0, the file and lock byte-identical
         — and the pipeline still runs (§8 decision 48: the report may
         narrow, the contract may not). Idempotence is what makes add
         safe to put in a script. The comparison is TEXTUAL: add never
         parses a constraint itself, which leaves the settled
         ManifestBuilder the single judge of a spelling and keeps
         ConstraintFormatError's declared ground — never signaled out of
         a verb — true."
        <category: 'verbs'>
        | original editor declared before pinned held unheld narrowed deleted lock after |
        (PathGuard isReadableFile: self packagePath) ifFalse: [
            "The settled missing-manifest diagnosis, defined once in
             ManifestFile: load: signals it and the boundary answers
             exit 1. It never returns. The predicate is decision 56's
             rather than plain existence (Sprint 17): a Package.st that
             exists and cannot be read reached File>>contents below and
             died there, and the sentence ManifestFile already carries
             covers both states."
            ^self loadManifest].
        original := self packageContents.
        editor := ManifestEditor on: original.
        editor isRecognized ifFalse: [
            ^CliResult
                lines: (Array with: (self unrecognizedManifestLineFor: aName
                    constraint: aConstraintString))
                exitCode: 1].
        declared := editor constraintFor: aName.
        (declared notNil and: [declared ~= aConstraintString]) ifTrue: [
            ^CliResult
                lines: (Array with: (self alreadyDeclaredLineFor: aName
                    constraint: declared))
                exitCode: 1].
        before := self loadManifest.
        pinned := self pinnedResolution.
        held := self heldVersionsOf: pinned except: nil.
        unheld := (self seededSourceAdding: aName) snapshot.
        narrowed := unheld holding: held.
        deleted := self deletedHeldPinLineIn: held against: narrowed.
        deleted notNil ifTrue: [
            ^CliResult lines: (Array with: deleted) exitCode: 1].
        lock := self lockContents.
        declared notNil ifTrue: [
            | idempotent |
            idempotent := self addResolving: before against: narrowed
                unheld: unheld restoring: original lock: lock.
            idempotent exitCode = 0 ifFalse: [^idempotent].
            ^CliResult
                lines: (Array with: (self alreadyDeclaredSuccessLineFor: aName
                    constraint: aConstraintString))
                exitCode: 0].
        self writePackage: (editor
            textWithDependency: aName constraint: aConstraintString).
        after := [self loadManifest]
            on: ManifestError
            do: [:e |
                self restore: original lock: lock.
                ^CliResult lines: e problems exitCode: 1].
        (self manifest: after adds: aName to: before) ifFalse: [
            self restore: original lock: lock.
            ^CliResult
                lines: (Array with: self editVerificationLine)
                exitCode: 1].
        ^self addResolving: after against: narrowed
            unheld: unheld restoring: original lock: lock
    ]

    exec: aScriptPath [
        "Run the script in the curated child; the CliResult carries
         the child's exit code and no lines of the CLI's own (the
         child already streamed to the terminal).

         THE SCRIPT IS A PRECONDITION PARLEY CHECKS ITSELF, BEFORE ANY
         PROCESS IS SPAWNED (Doc E §4.1, §8 decision 56, Sprint 16 —
         the declared settled-class exception on this class). It is not
         a retreat from §8 decision 45, which stands unchanged: the
         child's exit code is still a faithful pass-through and Parley
         still never claims to know whether a script that RAN
         succeeded. It is the boundary BEFORE that one, and what makes
         it necessary rather than tidy is that decision 45's documented
         consumer constraint — a script whose success matters ends with
         an explicit ObjectMemory quit: — is unavailable precisely
         here: a file that does not exist cannot carry a guard, so
         without this check no discipline an operator could adopt would
         make parley exec typo.st fail."
        <category: 'verbs'>
        | code |
        self requireRunnableScript: aScriptPath.
        code := (ExecutionScope
            on: (InstalledSet tuples: Dictionary new)
            target: target
            runner: runner) run: aScriptPath.
        ^CliResult lines: #() exitCode: code
    ]

    requireRunnableScript: aScriptPath [
        "Private — §8 decision 56's second application: a boundary that
         is about to hand a path to a process begins by requiring that
         path to be a regular readable file, and answers its own
         declared error naming it when it is not.

         The shipped tool had no such boundary and 3.2.5 does not
         supply one: gst answers exit 0 for a script argument that does
         not exist, printing gst: Couldn't open file, and exit 0 for a
         DIRECTORY argument printing nothing at all — a silent success
         for work that never ran, in the one verb whose whole contract
         is exit-code truthfulness.

         The error is an ExecutionError, so the §4.2 boundary answers
         it as one line at exit 1 with no new mechanism, and the
         diagnosis stays inside the declared taxonomy like every other
         '<path>: ...' sentence in the tool. Its command and exitCode
         slots stay nil, which is the honest record: no command was
         composed and no child had an exit code.

         Deciding whether there is anything to run is the VERB's
         business, not ExecutionScope's — the scope composes and runs
         the curated child, and pushing the check down would make it
         answer questions about the filesystem."
        <category: 'private'>
        (PathGuard isReadableFile: aScriptPath) ifTrue: [^self].
        ^ExecutionError new signal: (self unrunnableScriptLineFor: aScriptPath)
    ]

    unrunnableScriptLineFor: aScriptPath [
        "Private — the exec precondition refusal (pinned in RED, issue
         #18), in the settled '<path>: ...' grammar every other
         missing-file diagnosis uses. The tail states the CONSEQUENCE
         rather than a remedy: nothing Parley could suggest fixes a path
         only the operator knows the right spelling of, and a remedy it
         had not checked would be the §8 decision 58 defect committed in
         the sprint that fixes it. What the operator needs is the fact
         that no work happened."
        <category: 'private'>
        ^aScriptPath, ': missing or unreadable script - nothing was run'
    ]

    publish: aDestDir [
        "Publish into the destination index directory in the DEFAULT
         layout — flat, which is what publish always wrote and what it
         still writes when no --layout is stated (§8 decision 53)."
        <category: 'verbs'>
        ^self publish: aDestDir layout: CommandLine defaultPublishLayout
    ]

    publish: aDestDir layoutNamed: aLayoutName [
        "Publish into aDestDir in the STATED layout. An unrecognized
         name is a usage error at exit 2 and never a silent fallback:
         a fallback would publish into the wrong shape and call it
         success, which is the failure §8 decision 53 refuses. The
         table decides; this verb never branches on the name.

         Usage is answered BEFORE the manifest is loaded — a mistyped
         layout is wrong whatever the project looks like."
        <category: 'verbs'>
        | row |
        row := CommandLine publishLayoutNamed: aLayoutName.
        row isNil ifTrue: [^self usage].
        ^self publish: aDestDir layout: row
    ]

    publish: aDestDir layout: aLayoutRow [
        "Publish the working directory's own package into the
         destination index directory (Doc F §5): load the manifest,
         then run the Publisher pipeline in the row's layout. Success
         is one line naming the package and version, exit 0; a
         PublishError's problems become the lines, exit 1. No source
         collaborator is required — publishing produces index entries,
         it does not consume them."
        <category: 'verbs'>
        | manifest |
        manifest := self loadManifest.
        [(Publisher
            manifest: manifest
            in: workingDir
            to: aDestDir
            layout: (aLayoutRow at: 2)
            runner: runner) publish]
                on: PublishError
                do: [:e | ^CliResult lines: e problems exitCode: 1].
        ^CliResult
            lines: (Array with: 'published ', manifest name, ' ',
                manifest version printString)
            exitCode: 0
    ]

    "---- the inspection verbs (Doc E §4.1, Sprint 11) ----"

    why: aName [
        "The dependent chains that put aName in the lock: one line per
         chain, root first, arrow-joined, each hop naming the
         constraint that demanded the next, chains sorted so the
         output is byte-stable. A package not in the lock is a
         one-line diagnosis at exit 1 — the operator's question about
         a package they do not have, never a defect.

         The graph comes from the LOCK PLUS THE SNAPSHOT (§8 decision
         40), never the resolver: the ledger is transient, and a fresh
         resolution may legitimately pick a different set than the
         lock pins. The root's own edges come from its manifest; every
         other node's from the settled dependenciesOf:version:."
        <category: 'verbs'>
        | resolution manifest chains |
        resolution := self pinnedResolution.
        resolution isNil ifTrue: [^self reportMissingLock].
        (resolution packageNames includes: aName) ifFalse: [
            ^CliResult
                lines: (Array with: aName printString,
                    ' is not pinned in parley.lock')
                exitCode: 1].
        manifest := self loadManifest.
        chains := OrderedCollection new.
        self collectChainsTo: aName
            from: manifest dependencies
            chain: manifest name, ' ', manifest version printString
            visited: (Set with: manifest name)
            resolution: resolution
            snapshot: self seededSource snapshot
            into: chains.
        ^CliResult
            lines: (chains asSortedCollection: [:a :b | a <= b]) asArray
            exitCode: 0
    ]

    tree [
        "The pinned graph root-down: one line per node, two-space
         indent per level, each node '<name> <version>', children
         sorted by name so the output is byte-stable. A package
         reached more than once is rendered at each site with repeats
         marked and not re-expanded, so the output cannot mislead
         about depth. Same graph source as why (§8 decision 40)."
        <category: 'verbs'>
        | resolution manifest lines |
        resolution := self pinnedResolution.
        resolution isNil ifTrue: [^self reportMissingLock].
        manifest := self loadManifest.
        lines := OrderedCollection new.
        lines add: manifest name, ' ', manifest version printString.
        self addTreeLinesFor: manifest dependencies
            depth: 1
            seen: (Set with: manifest name)
            resolution: resolution
            snapshot: self seededSource snapshot
            into: lines.
        ^CliResult lines: lines asArray exitCode: 0
    ]

    check [
        "The verb spelling of the pin fast path, and the place
         retirement finally reaches the operator (§8 decision 37): in
         order, whether parley.lock exists and validates, whether
         PinVerification holds, and which pinned releases the index
         now marks retired — the author's reason travelling VERBATIM
         through the settled retirementReasonFor:version:. All good is
         one confirmation line at exit 0; anything wrong is the
         problems as lines at exit 1 — a retired pin is a PROBLEM, not
         a warning: check exists to be run in CI, and an exit code
         that ignored retirement would make the verb useless for the
         one job it has."
        <category: 'verbs'>
        | resolution manifest snapshot problems |
        resolution := self pinnedResolution.
        resolution isNil ifTrue: [^self reportMissingLock].
        manifest := self loadManifest.
        problems := OrderedCollection new.
        problems addAll:
            (PinVerification of: manifest lock: resolution) problems.
        snapshot := self seededSource snapshot.
        resolution packageNames do: [:name |
            | version reason |
            version := resolution versionOf: name.
            reason := snapshot retirementReasonFor: name version: version.
            reason notNil ifTrue: [
                problems add: 'lock pins ', name printString,
                    ' at ', version printString,
                    ', which the index has retired: ', reason]].
        problems isEmpty ifTrue: [
            ^CliResult
                lines: (Array with: 'parley.lock is healthy - pins satisfy Package.st and nothing pinned is retired')
                exitCode: 0].
        ^CliResult lines: problems asArray exitCode: 1
    ]

    collectChainsTo: aTarget from: someDependencies chain: aChainString visited: aVisitedSet resolution: aResolution snapshot: aSnapshot into: aCollection [
        "Private — the reverse walk rendered forward: extend
         aChainString along every pinned edge, recording each chain
         that reaches aTarget. Only pinned edges are walked — the verb
         explains the lock, not the index — and a node already on the
         current chain is never re-entered, so a cyclic lock cannot
         hang the walk."
        <category: 'private-inspection'>
        someDependencies do: [:dep |
            | name version rendered nextVisited |
            name := dep name.
            ((aResolution packageNames includes: name)
                and: [(aVisitedSet includes: name) not]) ifTrue: [
                version := aResolution versionOf: name.
                rendered := aChainString, ' -> ', name, ' ',
                    version printString,
                    ' (', dep constraint printString, ')'.
                name = aTarget
                    ifTrue: [aCollection add: rendered]
                    ifFalse: [
                        nextVisited := aVisitedSet copy.
                        nextVisited add: name.
                        self collectChainsTo: aTarget
                            from: (aSnapshot dependenciesOf: name
                                version: version)
                            chain: rendered
                            visited: nextVisited
                            resolution: aResolution
                            snapshot: aSnapshot
                            into: aCollection]]]
    ]

    addTreeLinesFor: someDependencies depth: aDepth seen: aSeenSet resolution: aResolution snapshot: aSnapshot into: aCollection [
        "Private — the forward walk: children sorted by name, indented
         two spaces per level; a node already rendered anywhere is
         marked as a repeat and not re-expanded."
        <category: 'private-inspection'>
        | sorted |
        sorted := someDependencies asSortedCollection:
            [:a :b | a name <= b name].
        sorted do: [:dep |
            | name version line |
            name := dep name.
            (aResolution packageNames includes: name) ifTrue: [
                version := aResolution versionOf: name.
                line := (String new: aDepth * 2 withAll: Character space),
                    name, ' ', version printString.
                (aSeenSet includes: name)
                    ifTrue: [aCollection add: line, ' (repeat)']
                    ifFalse: [
                        aSeenSet add: name.
                        aCollection add: line.
                        self addTreeLinesFor:
                                (aSnapshot dependenciesOf: name
                                    version: version)
                            depth: aDepth + 1
                            seen: aSeenSet
                            resolution: aResolution
                            snapshot: aSnapshot
                            into: aCollection]]]
    ]

    reportMissingLock [
        "Private — an inspection verb on a lockless project: exit 1,
         and the repair is resolve — the verb that writes a FIRST lock
         — not update, which is the repair for a corrupt one."
        <category: 'private-inspection'>
        ^CliResult
            lines: (Array with: 'parley.lock is missing - run parley resolve to write it')
            exitCode: 1
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

    "---- add's shared machinery (Doc B §2.1, Doc C §2.2) ----"

    addResolving: aManifest against: aSnapshot unheld: anUnheldSnapshot restoring: anOriginalText lock: aLockText [
        "Private — add's tail: resolve against the narrowed world,
         rewrite the lock byte-stably, then install and register exactly
         as update does.

         ANY nonzero outcome restores the project first. A conflict
         answers the settled ConflictReport narration, preceded by the
         held-pins line only when the check below has earned it — the
         resolver answered truthfully about a world with few candidates
         but cannot know WHY the world was small, and the verb had that
         context (§8 decision 46) only if holding really was the
         reason (§8 decision 58)."
        <category: 'private-add'>
        | outcome result |
        outcome := (Resolver strategy: BacktrackingStrategy new)
            resolve: aManifest against: aSnapshot.
        outcome isResolution ifFalse: [
            self restore: anOriginalText lock: aLockText.
            ^CliResult
                lines: (self conflictLinesFor: outcome
                    manifest: aManifest unheld: anUnheldSnapshot)
                exitCode: 1].
        self writeLock: outcome.
        result := self installResolution: outcome.
        result exitCode = 0
            ifFalse: [self restore: anOriginalText lock: aLockText].
        ^result
    ]

    conflictLinesFor: aReport manifest: aManifest unheld: anUnheldSnapshot [
        "Private — the conflict answer SHARED by add and update <pkg>
         (§8 decision 58, Sprint 16 — the declared settled-class
         exception on this class). One diagnosis, one wording, two
         callers: the Sprint 13 precedent, and a wording that drifted
         apart between them is the defect that precedent exists to
         prevent.

         A REMEDY LINE IS ASSERTED ONLY WHEN IT HAS BEEN CHECKED. Both
         verbs resolve against a snapshot holding the existing pins, and
         both used to print the held-pins line whenever that resolution
         failed. Nothing checked whether holding was the reason, and the
         commonest way to reach this path is a typo'd package name —
         where holding is irrelevant, parley update cannot help, and the
         instruction was printed ABOVE the real cause. A sentence naming
         a cause asserts that cause, and this tool only makes claims it
         has checked.

         So the claim is checked: re-resolve the same manifest against
         the UNHELD snapshot, and emit the line only if that resolution
         succeeds. When it fails too, holding was never the cause — the
         constraint is unsatisfiable outright — and the plain
         ConflictReport is answered alone. The cost is one extra
         resolution on a path that is already failing, and the SETTLED
         resolver runs against the SETTLED snapshot: nothing here
         teaches either of them about holding."
        <category: 'private-add'>
        ((Resolver strategy: BacktrackingStrategy new)
            resolve: aManifest against: anUnheldSnapshot) isResolution
                ifFalse: [^self linesOf: aReport printString].
        ^(Array with: self heldPinsLine),
            (self linesOf: aReport printString)
    ]

    manifest: aNewManifest adds: aName to: anOldManifest [
        "Private — the semantic verification (Doc B §2.1): the reloaded
         manifest declares aName and is OTHERWISE EQUAL to the one
         loaded before the edit — same name, version, fileIns order and
         every pre-existing dependency. A textual edit that is not
         checked by the reader that owns the meaning is a hope."
        <category: 'private-add'>
        aNewManifest name = anOldManifest name ifFalse: [^false].
        aNewManifest version = anOldManifest version ifFalse: [^false].
        aNewManifest fileIns asArray = anOldManifest fileIns asArray
            ifFalse: [^false].
        aNewManifest dependencies size
            = (anOldManifest dependencies size + 1) ifFalse: [^false].
        anOldManifest dependencies do: [:dep |
            (aNewManifest dependencies includes: dep) ifFalse: [^false]].
        ^(aNewManifest dependencies
            detect: [:dep | dep name = aName]
            ifNone: [nil]) notNil
    ]

    restore: anOriginalText lock: aLockTextOrNil [
        "Private — put the project back exactly as add found it: the
         manifest bytes, and the lock as it stood (removed when there
         was none). The content-addressed store is deliberately not
         undone — a hash-verified archive is inert, re-used on the next
         run, and never observable as project state."
        <category: 'private-add'>
        self writePackage: anOriginalText.
        aLockTextOrNil isNil
            ifTrue: [PathGuard remove: self lockPath
                ifRefused: [:path | self refuseLockWrite: path]]
            ifFalse: [self write: aLockTextOrNil to: self lockPath]
    ]

    heldVersionsOf: aResolution except: aName [
        "Private — name -> Version for every pinned package other than
         aName; a nil aName holds them all. The Doc C §2.2 narrowing
         input, shared by update <pkg> (which frees the package it
         moves) and add (which frees nothing, because adding one
         dependency is not a licence to move the others)."
        <category: 'private-add'>
        | held |
        held := Dictionary new.
        aResolution isNil ifTrue: [^held].
        aResolution packageNames do: [:each |
            each = aName ifFalse: [
                held at: each put: (aResolution versionOf: each)]].
        ^held
    ]

    deletedHeldPinLineIn: aHeldDictionary against: aSnapshot [
        "Private — the first held pin, in sorted name order, the
         narrowed snapshot can offer nothing for; nil when every held
         pin is describable.

         §8 decision 47 made this state SOUND — narrowing offers a held
         version only when the snapshot holds a record for it, because
         offering one it cannot describe would write a lock tuple with
         an empty digest, manufacturing the corruption check exists to
         catch. What it left behind was an ordinary unsatisfiable
         narrowed world: the held-pins line plus a ConflictReport, which
         reads as a version conflict when the real defect is that the
         index owner deleted an entry. Both verbs that hold pins answer
         this one sentence instead — and on add it matters most, where
         the operator has just added something and would reasonably
         blame their own addition."
        <category: 'private-add'>
        aHeldDictionary keys asSortedCollection do: [:name |
            (aSnapshot versionsOf: name) isEmpty ifTrue: [
                ^self deletedHeldPinLineFor: name
                    version: (aHeldDictionary at: name)]].
        ^nil
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
         nil when no lock exists.

         THE READ IS A BOUNDARY (Doc E §4.1, Sprint 9 — the declared
         settled-class exception on this class). A lockfile that does
         not parse, or that parses but is not a #'parley-lock' 1
         artifact, is one LockError — never a raw IndexEntryParseError
         or IndexEntryFormatError, which is how a corrupt lock used to
         reach the §4.2 boundary undiagnosed and be answered with exit
         70. parley.lock is the operator's file, not Parley's defect.

         The reader and Resolution fromLockEntry: are consumed
         unchanged: validation asks them and never re-implements them."
        <category: 'private'>
        | entry shape value |
        (PathGuard exists: self lockPath) ifFalse: [^nil].
        self requireReadableLock.
        entry := [IndexEntryReader readFrom: (ReadStream on: self lockBytes)]
            on: IndexEntryParseError, IndexEntryFormatError
            do: [:e | ^self signalLockProblem: e messageText].
        (entry at: 1) = #'parley-lock' ifFalse: [
            ^self signalLockProblem: 'wrong artifact tag ',
                (entry at: 1) printString,
                ' - parley.lock holds only #''parley-lock'' 1 artifacts'].
        shape := self lockShapeProblemIn: entry.
        shape notNil ifTrue: [^self signalLockProblem: shape].
        value := self lockValueProblemIn: entry.
        value notNil ifTrue: [^self signalLockProblem: value].
        ^Resolution fromLockEntry: entry
    ]

    requireReadableLock [
        "Private — READABILITY IS CHECKED BEFORE SHAPE (Doc E §4.1,
         §8 decision 56, Sprint 16 — the declared settled-class
         exception on this class).

         Every rejection ground below this one validates what the file
         SAYS: is it a #'parley-lock' 1 artifact, does it parse, is the
         digest 64 hex characters. All of them presumed the bytes could
         be obtained at all, and on 3.2.5 that presumption is wrong in
         a specific and reachable way: File>>exists answers TRUE for a
         directory, and File>>contents on one signals a KERNEL
         SystemExceptions.WrongClass, which is not a Parley error and
         escapes the handler written for the declared ones. A
         parley.lock that is a directory — a botched checkout, a volume
         mount, a stray mkdir — therefore reached the §4.2 boundary
         undiagnosed and was answered with exit 70: a kernel integer on
         the operator's screen, and the offending file never named. A
         boundary that validates what a file says has already claimed
         the file could be read.

         ABSENCE IS NOT UNREADABILITY, and the distinction is the whole
         of the first line here. File>>isFile answers false for a path
         that is simply not there exactly as it does for a directory, so
         a check written as one predicate would turn every lockless
         project into a lock defect and destroy the settled
         'parley.lock is missing - run parley resolve to write it'
         diagnosis — which names a different repair for a different
         state. An absent lock is answered by the caller, as it always
         was; only an unreadable one is refused here.

         The repair is the two-step one that actually works, and it
         departs from signalLockProblem: deliberately (ruled at the
         Sprint 16 RED review). That method names parley update because
         for a CORRUPT lock the advice is true by construction — update
         is the one verb that never READS a lock. This state breaks the
         construction: update's WRITE cannot succeed against a directory
         either, which is why decision 56 refuses it at every verb
         including update. Naming update here would answer the defect
         with the verb that answers the same refusal, and would be
         decision 58's own standard broken by the sentence next door.
         Once the path is removed the lock is MISSING, not corrupt, and
         resolve is the verb that writes a first one."
        <category: 'private-lock'>
        (PathGuard exists: self lockPath) ifFalse: [^self].
        (PathGuard isReadableFile: self lockPath) ifTrue: [^self].
        ^LockError signalProblems: (Array with: self unreadableLockLine)
    ]

    unreadableLockLine [
        "Private — the readability diagnosis (pinned in RED, issue
         #18), in the settled three-part lock shape: the path, the
         defect, the repair. The defect names the PREDICATE that failed
         rather than guessing which way it failed — a directory, a
         device node, a file whose permissions deny the reader — because
         one sentence covers all of them and none of them is a different
         repair."
        <category: 'private-lock'>
        ^self lockPath,
            ': not a regular readable file - remove it and run parley resolve to write a new one'
    ]

    "---- the third rejection ground: body shape (Doc E §4.1) ----"

    lockKeys [
        "Private — the Doc B §5.3 keys, in the fixed order §5.4 rule 2
         defines. All present, always, in exactly this sequence."
        <category: 'private-lock'>
        ^#(#root #packages)
    ]

    lockKeyOrderText [
        "Private — the fixed key order rendered for a problem, derived
         from lockKeys so the two can never drift apart."
        <category: 'private-lock'>
        | out |
        out := WriteStream on: String new.
        self lockKeys
            do: [:each | out nextPutAll: each printString]
            separatedBy: [out nextPut: Character space].
        ^out contents
    ]

    lockShapeProblemIn: anEntry [
        "Private — the first Doc B §5.3 shape defect of a tag-valid
         lockfile, as the descriptive tail of one problem, or nil when
         the lock has the schema shape.

         THIS IS THE THIRD REJECTION GROUND (§8 decision 35). The two
         before it are syntactic; a lockfile that parses, carries the
         right tag and declares a supported format version but has a
         malformed body used to reach Resolution fromLockEntry: and die
         there as a KERNEL SystemExceptions.NotFound, answered with exit
         70 — 'a defect in Parley' about the operator's own hand-edited
         file. Validating here keeps fromLockEntry: trusting and fed
         only values this boundary accepted, exactly as
         LibraryManifest fromIndexEntry: is fed only entries the scan
         validated.

         ONE PROBLEM PER LOCKFILE, first defect found: the operator is
         repairing one file, not auditing it, and the repair is the same
         either way. Deliberately unlike the directory scan, which
         batches because it reports on many files at once."
        <category: 'private-lock'>
        | keys fields |
        anEntry size odd ifTrue: [
            ^'malformed lock - the schema keys and values do not pair up'].
        keys := OrderedCollection new.
        3 to: anEntry size - 1 by: 2 do: [:i | keys add: (anEntry at: i)].
        self lockKeys do: [:key |
            (keys includes: key) ifFalse: [
                ^'missing schema key ', key printString,
                    ' - the fixed key order is ', self lockKeyOrderText]].
        keys do: [:key |
            (self lockKeys includes: key) ifFalse: [
                ^'unknown schema key ', key printString,
                    ' - the fixed key order is ', self lockKeyOrderText]].
        keys asArray = self lockKeys ifFalse: [
            ^'schema keys out of order - the fixed key order is ',
                self lockKeyOrderText].
        fields := self lockFieldsOf: anEntry.
        (SchemaShape isString: (fields at: #root)) ifFalse: [
            ^'#root must be a string'].
        (self isLockPackageTuples: (fields at: #packages)) ifFalse: [
            ^'#packages must be an array of #(<name> <version> #sha256 <hex digest>) tuples'].
        ^nil
    ]

    lockValueProblemIn: anEntry [
        "Private — the first value defect of a lockfile already known to
         have the §5.3 shape, or nil when every version parses.

         The Doc F §4.1 lesson, applied here: a shape check asks whether
         a field is a string, and never whether the string MEANS
         anything, so a shape-perfect lock pinning version 'banana' was
         still a kernel error waiting to happen. The settled
         Version fromString: is CONSUMED, never re-implemented — it
         stays the single definition of what parses, and this asks only
         whether it said yes."
        <category: 'private-lock'>
        ((self lockFieldsOf: anEntry) at: #packages) do: [:tuple |
            (self parsesVersion: (tuple at: 2)) ifFalse: [
                ^'#packages version ', (tuple at: 2) printString,
                    ' for ', (tuple at: 1) printString,
                    ' does not parse as a version']].
        ((self lockFieldsOf: anEntry) at: #packages) do: [:tuple |
            (self isLockDigest: (tuple at: 4)) ifFalse: [
                ^'#packages digest ', (tuple at: 4) printString,
                    ' for ', (tuple at: 1) printString,
                    ' must be 64 lowercase hex characters']].
        ^nil
    ]

    isLockDigest: aString [
        "Private — a lock digest is 64 lowercase hex characters, OR
         the empty string: '' is RECORDED ABSENCE, what the settled
         writer renders for an #archive #() pin, and it must keep
         reaching the settled Installer diagnosis instead of being
         rejected here (Doc B §5.3; §8 decision 42 — the exemption is
         for absence, not laxity). The version check above runs first:
         the settled version wording is pinned by settled laws."
        <category: 'private-lock'>
        ^aString isEmpty or: [SchemaShape isHexDigest: aString]
    ]

    parsesVersion: aString [
        "Private — whether the settled parser accepts aString."
        <category: 'private-lock'>
        ^[Version fromString: aString. true]
            on: VersionFormatError
            do: [:e | e return: false]
    ]

    lockFieldsOf: anEntry [
        "Private — the lock's key-value pairs after the tag and version,
         as a Dictionary (Doc B §5.3 fixed key order)."
        <category: 'private-lock'>
        | fields |
        fields := Dictionary new.
        3 to: anEntry size - 1 by: 2 do: [:i |
            fields at: (anEntry at: i) put: (anEntry at: i + 1)].
        ^fields
    ]

    isLockPackageTuples: aValue [
        "Private — an array of four-element
         #(<name> <version> #sha256 <hex digest>) tuples. Every
         structural defect answers the one wording: they are one
         question and one repair, as the settled #dependencies and
         #archive checks already are. The digest itself is not
         inspected — shape only; digest truth is Doc D §3's
         verifyHash:."
        <category: 'private-lock'>
        (aValue isKindOf: Array) ifFalse: [^false].
        aValue do: [:tuple |
            ((tuple isKindOf: Array) and: [tuple size = 4])
                ifFalse: [^false].
            (SchemaShape isString: (tuple at: 1)) ifFalse: [^false].
            (SchemaShape isString: (tuple at: 2)) ifFalse: [^false].
            (tuple at: 3) == #sha256 ifFalse: [^false].
            (SchemaShape isString: (tuple at: 4)) ifFalse: [^false]].
        ^true
    ]

    signalLockProblem: aDescription [
        "Private — one LockError carrying the lock path, the reader's
         own message and the repair. The reader's message travels
         VERBATIM: it names a character position, and on a hand-edited
         file that position is the operator's only handle, so
         paraphrasing it would throw away the one thing that makes the
         diagnosis actionable.

         The repair named is parley update, because update is the one
         verb that ignores the lock entirely and rewrites it — the same
         shape as init in the missing-Package.st diagnosis (§8 decision
         31). install diagnoses and stops: repairing a corrupt lock
         silently would make a damaged lock indistinguishable from a
         valid one."
        <category: 'private'>
        ^LockError signalProblems: (Array with:
            self lockPath, ': ', aDescription,
            ' - run parley update to rewrite it')
    ]

    resolveAndLock: aManifest [
        "Private — resolve fresh against the source's snapshot; a
         Resolution rewrites the lock, a ConflictReport writes
         nothing.

         THE READABILITY CHECK IS OWED HERE TOO (§8 decision 56). This
         is the path resolve and plain update take, and neither of them
         READS the lock — resolve ignores a corrupt one because it is
         about to overwrite it, and update never reads one at all. Both
         nonetheless WRITE one, and that write cannot succeed against a
         path that is not a regular file, so answering exit 0 would
         claim a lock that was never written: the fail-wrong this whole
         boundary exists to prevent.

         resolve cannot delegate the check to seeding, either. seedNames
         catches LockError by construction (§8 decision 52) and defers
         to the boundary that owns the diagnosis, so the readability
         error would be swallowed exactly as a corrupt one is — right
         for a corrupt lock, wrong for this one. The Sprint 14 add
         shape: a settled caller whose meaning changes without a line of
         its code changing."
        <category: 'private'>
        | outcome |
        self requireReadableLock.
        outcome := (Resolver strategy: BacktrackingStrategy new)
            resolve: aManifest against: self seededSource snapshot.
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

    seededSource [
        "Private — the source told which names matter (§8 decision
         51): seededWith: is sent unconditionally at every snapshot
         site, and each source answers per its own nature — the
         scanning sources answer self, the sparse source a new seeded
         instance. The CLI supplies the seeds because the source must
         never read Package.st or parley.lock."
        <category: 'private'>
        ^source seededWith: self seedNames
    ]

    seededSourceAdding: aName [
        "Private — the add verb's seeded source: add snapshots BEFORE
         it edits Package.st, so the added name is in neither file the
         seed set is otherwise built from and must be seeded
         explicitly (issue #16 S16)."
        <category: 'private'>
        | names |
        names := self seedNames.
        names add: aName.
        ^source seededWith: names
    ]

    seedNames [
        "Private — the decision-51 seed set: the manifest's declared
         dependency names union the lock's pinned names, gathered
         BEST-EFFORT. Each file has a settled boundary that owns its
         diagnosis (the missing-manifest line, the lock boundary), and
         seed gathering must never pre-empt it: a file that cannot be
         read here contributes nothing, and the verb itself diagnoses
         it — resolve with a corrupt lock stays exit 0 (Doc E §4.1).

         EACH CATCH NAMES THE BOUNDARY IT DEFERS TO, AND NOTHING ELSE
         (§8 decision 52, cleared at its trigger). As first written
         both caught Error, which also swallows what neither of them
         anticipated — and what a swallowed error leaves behind is not
         an exception but a silently PARTIAL SEED SET. Under a scanning
         source that is invisible, because seededWith: answers self and
         the whole index is read anyway. Under --index it is decision
         47's describability line: the closure never fetches the names
         that went missing, and the verb answers a #noVersions
         ConflictReport BLAMING THE PACKAGE — the exact wrong-blame
         diagnosis this seeding exists to prevent, arriving silently,
         on a path no fixture exercises because every law's gathering
         succeeds.

         The rule, general beyond this site: a catch that exists to
         defer to another boundary names that boundary's errors and no
         others, so anything it did not anticipate reaches the settled
         taxonomy and is reported as the software defect it is —
         CommandLine's exit 70, never exit 0 and never a confident
         wrong sentence."
        <category: 'private'>
        | names |
        names := Set new.
        [(ManifestFile load: self packagePath) dependencies
            do: [:each | names add: each name]]
            on: ManifestError do: [:e | nil].
        [| pinned |
         pinned := self pinnedResolution.
         pinned notNil ifTrue: [
            pinned packageNames do: [:each | names add: each]]]
            on: LockError do: [:e | nil].
        ^names
    ]

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
        "Private — the byte-stable lock through the settled writer.

         THE BYTES ARE RENDERED BEFORE ANY FILE IS OPENED (Sprint 17).
         The settled writer is handed a String stream rather than a
         file stream deliberately: the chokepoint's translation must
         guard nothing but the write, or a writer's own failure would
         come back as a path refusal and the blame would land on the
         wrong party (§8 decision 52's discriminator). The bytes are
         identical either way, so every settled lock oracle is
         unchanged."
        <category: 'private'>
        | out |
        out := WriteStream on: String new.
        IndexEntryWriter writeLock: aResolution on: out.
        self write: out contents to: self lockPath
    ]

    lockBytes [
        "Private — the lock's bytes for a boundary that has already
         required the path to be readable. The refusal is the TOCTOU
         path and nothing else, and it answers this file's own declared
         error rather than a kernel one."
        <category: 'private'>
        ^PathGuard contentsOf: self lockPath
            ifRefused: [:path |
                LockError signalProblems: (Array with:
                    (PathGuard lineFor: path saying: PathGuard unreadableTail))]
    ]

    packageContents [
        "Private — the working directory's Package.st, as bytes. The
         operator's own file: read whole so add can put it back."
        <category: 'private'>
        ^PathGuard contentsOf: self packagePath
            ifRefused: [:path |
                ManifestError signalProblems: (Array with:
                    (PathGuard lineFor: path saying: PathGuard unreadableTail))]
    ]

    lockContents [
        "Private — the lock's bytes, or nil when the project has none;
         what add restores on any failure."
        <category: 'private'>
        ^(PathGuard exists: self lockPath)
            ifTrue: [self lockBytes]
            ifFalse: [nil]
    ]

    writePackage: aString [
        "Private — replace Package.st with aString. The only place any
         verb writes the operator's manifest after init."
        <category: 'private'>
        ^PathGuard write: aString to: self packagePath
            ifRefused: [:path |
                ManifestError signalProblems: (Array with:
                    (PathGuard unwritableLineFor: path))]
    ]

    write: aString to: aPath [
        "Private — aString as the complete contents of aPath. Only the
         lock arrives here; the manifest has writePackage:, because the
         two files answer DIFFERENT declared errors and a shared writer
         that guessed would be a boundary blaming the wrong file."
        <category: 'private'>
        ^PathGuard write: aString to: aPath
            ifRefused: [:path | self refuseLockWrite: path]
    ]

    refuseLockWrite: aPath [
        "Private — the lock's declared error for a path it cannot
         write, in the one composition every write boundary shares."
        <category: 'private'>
        ^LockError signalProblems: (Array with:
            (PathGuard unwritableLineFor: aPath))
    ]

    "---- results ----"

    usage [
        "Private — the pinned usage lines, exit 2."
        <category: 'private'>
        ^CliResult
            lines: (Array
                with: 'usage: parley <verb> [--source <dir> | --git <repo> | --index <base>]'
                with: 'verbs: init | resolve | install | update [<pkg>] | add <pkg> <constraint> | exec <script> | publish <dir> | why <pkg> | tree | check'
                with: 'flags: --source <dir>  index entries in a local directory'
                with: '       --git <repo>    index entries in a git repository'
                with: '       --index <base>  index entries fetched per package from a sparse index'),
                (Array with: '       --layout <name> flat (default) or sparse, the index layout publish writes')
            exitCode: 2
    ]

    reportPins: aResolution [
        "Private — one '<name> <version>' line per resolved pin in
         sorted package-name order, exit 0.

         A project with no dependencies resolves to NO pins, and one
         line is answered rather than none: the lock really was written
         (#packages #()), the work really did succeed, and a verb that
         prints nothing at all reads as a verb that did nothing at all.
         Silence is the wrong report for success — especially on the
         first run after `parley init`, which is exactly when a project
         has no dependencies yet."
        <category: 'private'>
        aResolution packageNames isEmpty ifTrue: [
            ^CliResult
                lines: (Array with: self noDependenciesLine)
                exitCode: 0].
        ^CliResult
            lines: (aResolution packageNames collect: [:name |
                name, ' ', (aResolution versionOf: name) printString])
            exitCode: 0
    ]

    noDependenciesLine [
        "Private — the pinned confirmation for a dependency-free
         project (pinned in RED)."
        <category: 'private'>
        ^'no dependencies to resolve - wrote parley.lock'
    ]

    heldPinsLine [
        "Private — the sentence update <pkg> prepends to a conflict
         under held pins (pinned in RED, issue #14): it names what was
         held and the verb that moves everything. The narration that
         follows is the resolver's own value, unmodified."
        <category: 'private'>
        ^'the other pins were held at their locked versions - run parley update to move everything'
    ]

    alreadyNewestLineFor: aName version: aVersion [
        "Private — the pinned already-newest success line (pinned in
         RED, issue #14)."
        <category: 'private'>
        ^aName, ' ', aVersion printString,
            ' is already the newest version its constraints allow - wrote parley.lock'
    ]

    unrecognizedManifestLineFor: aName constraint: aConstraintString [
        "Private — the shape refusal (pinned in RED, issue #15). It
         names the file AND THE EXACT TEXT TO PASTE, because a refusal
         that does not say what to type has cost the operator more than
         it saved. Recognize or refuse is the settled grammar of every
         boundary in the tool: fail-stop, never fail-wrong, and name the
         repair (§8 decisions 31 and 44)."
        <category: 'private'>
        ^self packagePath,
            ': no single Parley define: cascade to edit - add this clause by hand: dependency: ''',
            aName, ''' constraint: ''', aConstraintString, ''''
    ]

    alreadyDeclaredLineFor: aName constraint: aConstraintString [
        "Private — the different-constraint refusal (pinned in RED),
         naming the constraint already in the file."
        <category: 'private'>
        ^aName printString, ' is already declared with constraint ',
            aConstraintString printString,
            ' - changing a constraint is an edit, not an add: change it in Package.st by hand'
    ]

    alreadyDeclaredSuccessLineFor: aName constraint: aConstraintString [
        "Private — the idempotent success line (pinned in RED): the
         update <pkg> already-newest precedent, because a verb that
         prints nothing reads as a verb that did nothing."
        <category: 'private'>
        ^aName, ' ', aConstraintString,
            ' is already declared in Package.st - wrote parley.lock'
    ]

    deletedHeldPinLineFor: aName version: aVersion [
        "Private — the diagnosis add and update <pkg> SHARE for a held
         pin the index no longer publishes (pinned in RED, issue #15).
         The repair named is parley update: the one verb that holds
         nothing and re-resolves, so it is the verb that can move off a
         pin whose entry is gone."
        <category: 'private'>
        ^'parley.lock pins ', aName printString, ' at ',
            aVersion printString,
            ', which the index no longer publishes - run parley update to move off it'
    ]

    editVerificationLine [
        "Private — the refusal when the reload disagrees with the edit
         (pinned in RED). The operator is never left a half-edited
         file."
        <category: 'private'>
        ^self packagePath,
            ': the edited manifest did not load as the edit intended - Package.st was restored unchanged'
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
        "Private — the starter skeleton parley init writes, byte-exact
         (pinned in RED). It is deliberately NOT Doc B §2's illustration:
         that example declares kernel-json with two dependencies that do
         not exist, so `init` followed by `resolve` failed on phantom
         packages — the worst possible first run. A template's job is to
         be a correct starting point, not a feature tour. The dependency
         syntax is taught in the header comment instead, where it costs
         nothing to read and nothing to resolve."
        <category: 'private'>
        ^'"Package.st — the manifest Parley reads.
 Edit the values below, then:  parley resolve --source <index-dir>
 Add a dependency with:        dependency: ''name'' constraint: ''^1.0.0''"
Parley define: [:pkg |
    pkg
        name: ''my-package'';
        version: ''0.1.0'';
        summary: '''';
        author: '''';
        license: '''';
        fileIns: #(''MyPackage.st'') ]',
            (String with: Character nl)
    ]
]

Namespace current: Smalltalk.
