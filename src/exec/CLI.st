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
    | workingDir source store target runner modes |

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
        runner := aProcessRunner.
        modes := Set new
    ]

    withModes: someModes [
        "Answer this CLI carrying the modes the invocation asserts
         (Doc E §4.2, Sprint 21). The settled constructor answers a CLI
         with none, so every settled caller is unchanged and a verb that
         cannot violate an invariant satisfies it trivially."
        <category: 'instance creation'>
        modes := someModes.
        ^self
    ]

    "---- dispatch ----"

    CLI class >> row: aGuardBlock verb: aSelector args: anIndexArray named: aVerbName [
        "Private — one dispatch row: a pure guard on (argv, has-source),
         the verb selector it selects, the argv indices its arguments
         come from, and THE VERB'S OWN NAME.

         The fourth column is a DECLARATION, never the first keyword of
         the row's selector (§8 decision 81). The two agree today only
         by a coincidence of spelling, and they stop agreeing the first
         time a verb and the method that runs it are named apart —
         #publish:layoutNamed: is already the row where that coincidence
         is doing the most work. The name is what tells an unknown verb
         apart from a known verb given arguments it does not take, and
         a diagnosis that inferred it from a selector would be reading
         the implementation to describe the grammar."
        <category: 'dispatch'>
        ^Array with: aGuardBlock with: aSelector with: anIndexArray
            with: aVerbName
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

         THE ROWS ARE BUILT IN GROUPS OF AT MOST FIVE AND CONCATENATED,
         which is a toolchain fact and not a style: 3.2.5's Array class
         answers with:with:with:with:with: and nothing longer, so a
         sixth with: in one group is a doesNotUnderstand at the first
         send of this method — which is every verb, every usage
         determination and every law that reaches either. Add a group
         rather than a keyword.

         Row order is the settled chain's order and stays significant
         only where guards could overlap; publish's two shapes are
         disjoint by arity. publish <dir> --layout <name> reads its own
         flag because CommandLine consumes only the SOURCE flags, so the
         layout arrives in the verb argv (Doc F §8.1); an unrecognized
         value is usage inside the verb, never a fallback."
        <category: 'dispatch'>
        ^(Array
            with: (self row: [:a :s | a size = 1 and: [(a at: 1) = 'init']]
                verb: #init args: #() named: 'init')
            with: (self row: [:a :s | a size = 2 and: [(a at: 1) = 'exec']]
                verb: #exec: args: #(2) named: 'exec')
            with: (self row: [:a :s | a size = 2 and: [(a at: 1) = 'publish']]
                verb: #publish: args: #(2) named: 'publish')
            with: (self row: [:a :s | a size = 4
                    and: [(a at: 1) = 'publish'
                    and: [(a at: 3) = CommandLine publishLayoutFlag]]]
                verb: #publish:layoutNamed: args: #(2 4) named: 'publish')
            with: (self row: [:a :s | a size = 2
                    and: [(a at: 1) = 'why']]
                verb: #why: args: #(2) named: 'why')),
        (Array
            with: (self row: [:a :s | s and: [a size = 2
                    and: [(a at: 1) = 'update']]]
                verb: #update: args: #(2) named: 'update')
            with: (self row: [:a :s | s and: [a size = 3
                    and: [(a at: 1) = 'add']]]
                verb: #add:constraint: args: #(2 3) named: 'add')
            with: (self row: [:a :s | s and: [a size = 2
                    and: [(a at: 1) = 'remove']]]
                verb: #remove: args: #(2) named: 'remove')
            with: (self row: [:a :s | a size = 1
                    and: [(a at: 1) = 'resolve']]
                verb: #resolve args: #() named: 'resolve')
            with: (self row: [:a :s | s and: [a size = 1
                    and: [(a at: 1) = 'install']]]
                verb: #install args: #() named: 'install')),
        (Array
            with: (self row: [:a :s | s and: [a size = 1
                    and: [(a at: 1) = 'update']]]
                verb: #update args: #() named: 'update')
            with: (self row: [:a :s | s and: [a size = 2
                    and: [(a at: 1) = 'search']]]
                verb: #search: args: #(2) named: 'search')
            with: (self row: [:a :s | s and: [a size = 2
                    and: [(a at: 1) = 'info']]]
                verb: #info: args: #(2) named: 'info')
            with: (self row: [:a :s | s and: [a size = 1
                    and: [(a at: 1) = 'outdated']]]
                verb: #outdated args: #() named: 'outdated')),
        (Array
            with: (self row: [:a :s | a size = 1
                    and: [(a at: 1) = 'tree']]
                verb: #tree args: #() named: 'tree')
            with: (self row: [:a :s | a size = 1
                    and: [(a at: 1) = 'check']]
                verb: #check args: #() named: 'check'))
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

    CLI class >> declaredVerbNames [
        "Every verb name the grammar declares, read from the fourth
         column of the one table. A verb that exists is a verb with a
         row, so the diagnosis and the dispatch can never disagree about
         what a verb is."
        <category: 'dispatch'>
        ^self verbRows collect: [:row | row at: 4]
    ]

    CLI class >> usageGroundFor: anArgvArray withSource: aBoolean [
        "WHY this argv answers usage rather than running a verb, as one
         of §8 decision 81's declared grounds. PURE, exactly as
         verbRowFor:withSource: is and for the same reason: CommandLine
         asks it before any state directory exists.

         THE GROUND IS DERIVED FROM THE DECLARED TABLE, never re-listed
         beside it. An empty argv is its own ground. Availability is
         tested by running the SAME guards twice — once as if a source
         were wired and once as if none were — which buys the
         needs-an-index ground with no second declaration at all. What
         is left splits on the verb-name column.

         AVAILABILITY IS TESTED BEFORE ARITY, and the order is the
         ruling rather than a preference: `parley resolve` has exactly
         the arguments resolve takes and lacks only an index, so an
         arity-first derivation would tell the operator their arguments
         are wrong — a sentence nothing checked, on the commonest usage
         error there is."
        <category: 'dispatch'>
        anArgvArray isEmpty ifTrue: [^#noVerb].
        ((self verbRowFor: anArgvArray withSource: true) notNil
            and: [(self verbRowFor: anArgvArray withSource: false) isNil])
                ifTrue: [^#needsIndex].
        ^(self declaredVerbNames includes: (anArgvArray at: 1))
            ifTrue: [#wrongArguments]
            ifFalse: [#unknownVerb]
    ]

    CLI class >> usageSubjectFor: anArgvArray [
        "The word a reason line names: the verb the operator typed, or
         the empty string when they typed none. One definition, because
         two grounds interpolate it and a third does not."
        <category: 'dispatch'>
        ^anArgvArray isEmpty ifTrue: [''] ifFalse: [anArgvArray at: 1]
    ]

    CLI class >> usageBlock [
        "THE BLOCK: what the tool offers, and the ONE definition of it.

         A usage error is one reason line followed by this block;
         --help is this block ALONE at exit 0 (§8 decision 79). The
         shared artifact is the block and NEITHER answer is derived from
         the other's finished one, so the two can never print different
         texts about what the tool offers and neither can inherit the
         other's claim about what just happened.

         The verbs: row renders each verb exactly as Doc E §4's argv
         grammar spells it, optional argument included.

         SPRINT 21 GROWS IT FROM SIX LINES TO EIGHT: the header names
         the two MODE flags and the flags: block gains a row for each.
         They are valueless and build nothing, so they are a second
         declared table rather than sourceFlags rows (Doc E §4.2) — but
         a flag the help hides is a flag that does not exist (§8
         decision 45's standard), so the block is where they become
         real to an operator. The verbs: row does NOT move: this sprint
         adds no verb."
        <category: 'usage'>
        ^(Array
            with: 'usage: parley <verb> [--source <dir> | --git <repo> | --index <base>] [--offline] [--locked]'
            with: 'verbs: init | resolve | install | update [<pkg>] | add <pkg> <constraint> | remove <pkg> | search <term> | info <pkg> | outdated | exec <script> | publish <dir> | why <pkg> | tree | check'
            with: 'flags: --source <dir>  index entries in a local directory'
            with: '       --git <repo>    index entries in a git repository'
            with: '       --index <base>  index entries fetched per package from a sparse index'),
            (Array
                with: '       --layout <name> flat (default) or sparse, the index layout publish writes'
                with: '       --offline       this invocation spawns no git and no curl'
                with: '       --locked        this invocation does not change parley.lock')
    ]

    CLI class >> conflictProvenanceLineFor: aName path: aDeclaredPath [
        "The line a conflict carries above the settled narration when an
         OVERLAID name participates (Sprint 21, §8 decision 68; pinned in
         RED), in the held-pins-line placement of §8 decision 46's
         family: the resolver answered truthfully about the world it was
         given and cannot know a DIRECTORY supplied one of its packages.
         The verb had that context and owes the sentence."
        <category: 'usage'>
        ^aName printString, ' is supplied by the path dependency ',
            aDeclaredPath printString,
            ' at the version that directory declares - the index''s releases of it were not considered'
    ]

    CLI class >> infoPathProvenanceLineFor: aName path: aDeclaredPath [
        "info on a name only a PATH supplies (pinned in RED). THE
         SETTLED UNKNOWN-PACKAGE ANSWER EXTENDED, NEVER CONTRADICTED:
         the operator asked about the index and the index's answer is
         still no, but a tool that knows why the project runs anyway
         owes the second half. Exit 1, exactly as the settled sentence."
        <category: 'usage'>
        ^aName printString,
            ' is not published by the configured index - it is supplied by the path dependency ',
            aDeclaredPath printString
    ]

    CLI class >> pathAllowedMarkerFor: aDeclaredPath [
        "What outdated renders in the allowed column for a PATH pin (§8
         decision 82's family, second member; pinned in RED).

         IT MUST NOT READ LIKE THE TRANSITIVE MARKER. A transitive pin
         says the repair is not the operator's to make; a path pin is
         one they DECLARED, so the marker names the directory that
         decides the version and leaves the repair in their hands. The
         published column stays the index's answer, because that fact is
         true whoever supplies the name."
        <category: 'usage'>
        ^'(path ', aDeclaredPath printString, ' - the directory decides)'
    ]

    CLI class >> driftProblemFor: aName pinned: aPinnedVersion declared: aDeclaredVersion path: aDeclaredPath [
        "check's drift leg (pinned in RED), in the settled check-problem
         shape the retirement leg already uses.

         THE BOUND IS IN THE SENTENCE: it is the DECLARED version that
         moved. This leg compares the sibling's declared version, read
         through the settled ManifestFile, against the pin's recorded
         version — and never file contents. An edit that leaves the
         declared version alone is invisible to it, deliberately:
         loading fresh content is exec's job, and diagnosing a stale PIN
         is this one's."
        <category: 'usage'>
        ^'lock pins ', aName printString, ' at ', aPinnedVersion,
            ', which the path dependency ', aDeclaredPath printString,
            ' now declares as ', aDeclaredVersion,
            ' - run parley resolve to update it'
    ]

    CLI class >> needsIndexRefusalFor: someNames [
        "THE SHARED IN-VERB REFUSAL for a manifest that needs an index
         when none is wired (§8 decisions 83 and 84), pinned in RED.

         ONE SENTENCE FOR ALL FOUR VERBS, never one per verb: resolve,
         check, tree and why reach it for the same reason and the repair
         is the same, and four sentences would be four wordings no law
         could hold together (§8 decision 81's rule).

         Exit 1 rather than 2 on decision 80's precedent — the argv is
         well formed and the PROJECT is the limit — and it names what
         the manifest declares plus the flags or the config file that
         can answer, NEVER the usage block: the operator's command was
         legal, so telling them how to type it would answer a question
         they did not ask."
        <category: 'usage'>
        ^'no index is wired, and Package.st declares ',
            (CommandLine list: someNames conjunction: 'and'),
            ' - give ',
            (CommandLine list: CommandLine sourceFlagNames
                conjunction: 'or'),
            ', or record one in parley.config.st'
    ]

    CLI class >> usageLinesFor: aGroundSymbol subject: aSubject [
        "One reason line, then the block. The composition, class-side
         and pure, so the composition root can answer usage without
         building a CLI it will never run."
        <category: 'usage'>
        ^(Array with: (CommandLine usageReasonFor: aGroundSymbol
            subject: aSubject)), self usageBlock
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
        row isNil ifTrue: [
            ^self usageFor: (self class
                usageGroundFor: anArgvArray withSource: source notNil)
                subject: (self class usageSubjectFor: anArgvArray)].
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
        | manifest refusal outcome |
        manifest := self loadManifest.
        refusal := self indexRefusalFor: manifest.
        refusal notNil ifTrue: [^refusal].
        "THE RESOLVE GOES THROUGH resolveAndLock: AND MUST KEEP DOING SO.
         That method is the seam two settled laws hang a resolver trap
         on (InspectionVerbTest and Sprint 20 S14 both assert that
         resolve still SPRINGS it, because a double that cannot spring
         proves nothing). Inlining it here to hold the snapshot for the
         conflict line silently moved the verb off the path those laws
         guard — a settled consumer whose meaning changed without a line
         of its code changing, which is the §8 decision 51 defect shape.
         The provenance therefore comes from the MANIFEST's own
         declarations instead."
        outcome := self resolveAndLock: manifest.
        outcome isResolution ifFalse: [
            ^CliResult
                lines: (self conflictLines: outcome
                    provenance: (self declaredProvenanceOf: manifest))
                exitCode: 1].
        ^self reportPins: outcome
    ]

    declaredProvenanceOf: aManifest [
        "Private — name -> declared path for the ROOT's own path
         dependencies, the provenance a conflict line can name without
         a second I/O moment.

         THE BOUND IS STATED RATHER THAN LEFT TO BE FOUND (§8 decision
         43): a TRANSITIVE path dependency — one a sibling declares —
         is not named here. The line explains the operator's OWN
         declaration, which is the one they can act on, and reaching a
         sibling's would mean re-composing the overlay on a path that
         has already failed.

         THIS IS THE OPPOSITE BOUND FROM hopAnnotationFor:dependency:
         resolution:, AND THE TWO ARE NOT IN CONFLICT. That one reads
         the LOCK's provenance, so a transitive path pin IS named there.
         The difference is which question is being answered and when: a
         conflict speaks BEFORE resolution about what the root DECLARED,
         where a sibling's declaration is not yet a fact of the project;
         why and tree speak AFTER it about what the lock RECORDED, where
         a transitive path pin is exactly as real as a root-declared
         one. Same word, two sources, both deliberate."
        <category: 'private'>
        | out |
        out := Dictionary new.
        aManifest pathDependencies do: [:each |
            out at: each name put: each path].
        ^out
    ]

    conflictLines: aReport provenance: aProvenanceDictionary [
        "Private — the settled ConflictReport narration, preceded by one
         line for each OVERLAID name the narration mentions (Doc E §4.1).

         Sorted by name so the answer is byte-stable, and driven by
         whether the narration actually names the package rather than by
         whether the project happens to declare one: a path dependency
         that took no part in the failure gets no line, because a
         sentence naming a cause asserts that cause and this tool only
         makes claims it has checked (§8 decision 58)."
        <category: 'private'>
        | narration lines |
        narration := self linesOf: aReport printString.
        lines := OrderedCollection new.
        (aProvenanceDictionary keys asSortedCollection: [:a :b | a <= b])
            do: [:name |
                (narration anySatisfy: [:line | self name: line includes: name])
                    ifTrue: [lines add: (self class
                        conflictProvenanceLineFor: name
                        path: (aProvenanceDictionary at: name))]].
        ^lines asArray, narration
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
        outcome := self resolve: manifest against: narrowed.
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
        | original editor declared before pinned held unheld narrowed deleted lock after kindRefusal |
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
        "ALREADY DECLARED QUANTIFIES OVER ALL THREE KINDS (issue #23),
         and it fires BEFORE any edit so a refusal leaves the file
         byte-identical. A name the manifest supplies by PATH or
         declares as a DEV dependency is already declared: inserting an
         index clause beside it would build a manifest the settled
         duplicate rule refuses (Doc B §3.4 item 5) — written by the
         tool, into a file the author owns. Changing HOW a dependency is
         supplied is an edit, exactly as changing a constraint is."
        kindRefusal := self alreadyDeclaredOtherKindLineFor: aName.
        kindRefusal isNil ifFalse: [
            ^CliResult lines: (Array with: kindRefusal) exitCode: 1].
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

    remove: aName [
        "Delete one dependency clause from Package.st and move the
         project off it in one operation (Doc E §4.1, §8 decision 67).

         THE SAME RULING AS add, APPLIED TO THE OPPOSITE OPERATION, and
         stated separately because deletion has a failure mode insertion
         does not: an insertion that recognizes too little REFUSES,
         while a deletion that recognizes too little DAMAGES. The
         mechanism is the settled ManifestEditor's, the verification is
         the settled reader's, and the atomicity is add's own tail —
         nothing here is new machinery.

         IT FREES THE PIN IT IS REMOVING (heldVersionsOf:except:, the
         parameter update <pkg> already uses). Holding every pin
         including the one being removed would be sound and would
         answer the wrong sentence in one real case: an index owner who
         DELETES an entry leaves the operator a pin the index no longer
         publishes, removing that dependency is exactly the repair, and
         a held-pin refusal would blame the package the operator is
         already getting rid of.

         Its three diagnoses, all exit 1: no Package.st (the settled
         missing-manifest line, signaled by load: so the sentence keeps
         one definition); a shape the editor cannot recognize (one line
         naming the file and the clause to delete, THE FILE
         BYTE-IDENTICAL); and a name the cascade does not declare (one
         line, the why precedent, and NOTHING written — not the
         manifest, not the lock). Removing the only dependency is
         ordinary success: what remains re-loads and the lock is
         rewritten with no pins."
        <category: 'verbs'>
        | original editor before pinned held unheld narrowed deleted lock after |
        (PathGuard isReadableFile: self packagePath) ifFalse: [
            ^self loadManifest].
        original := self packageContents.
        editor := ManifestEditor on: original.
        editor isRecognized ifFalse: [
            ^CliResult
                lines: (Array with: (self unrecognizedRemovalLineFor: aName))
                exitCode: 1].
        (editor constraintFor: aName) isNil ifTrue: [
            ^CliResult
                lines: (Array with: (self notDeclaredLineFor: aName))
                exitCode: 1].
        before := self loadManifest.
        pinned := self pinnedResolution.
        held := self heldVersionsOf: pinned except: aName.
        unheld := self seededSource snapshot.
        narrowed := unheld holding: held.
        deleted := self deletedHeldPinLineIn: held against: narrowed.
        deleted notNil ifTrue: [
            ^CliResult lines: (Array with: deleted) exitCode: 1].
        lock := self lockContents.
        self writePackage: (editor textWithoutDependency: aName).
        after := [self loadManifest]
            on: ManifestError
            do: [:e |
                self restore: original lock: lock.
                ^CliResult lines: e problems exitCode: 1].
        (self manifest: after removes: aName from: before) ifFalse: [
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
            runner: runner
            fileIns: self siblingFileIns) run: aScriptPath.
        ^CliResult lines: #() exitCode: code
    ]

    siblingFileIns [
        "Private — every #path pin's own fileIns, in dependency order,
         as paths the child can open (Sprint 21, §8 decision 68).

         READ FRESH AT EXEC TIME, NEVER FROM A CACHE, and that is the
         whole feature: the sibling's Package.st is loaded through the
         settled ManifestFile on THIS run, so an edit made since the
         lock was written is picked up with no publish, no rebuild and
         no re-registration. A sibling that is missing, unreadable or
         malformed answers its boundary's own diagnosis naming the
         sibling's path, at exit 1, having spawned nothing — the load
         happens before the scope is built.

         A project with no lock, or a lock with no #path pins, answers
         the empty array and the pinned composition does not move."
        <category: 'private'>
        | pinned out |
        pinned := self pinnedResolution.
        pinned isNil ifTrue: [^#()].
        out := OrderedCollection new.
        self addFileInsOf: pinned pathNames
            from: pinned
            seen: Set new
            into: out.
        ^out asArray
    ]

    addFileInsOf: someNames from: aResolution seen: aSeenSet into: aCollection [
        "Private — depth-first over the path-supplied names, appending
         each sibling's fileIns AFTER those of the path dependencies it
         declares.

         DEPENDENCY ORDER IS DEPENDENCIES-FIRST because that is what
         load order means in Smalltalk: a class the sibling's own code
         sends messages to must already be in the image. The visited set
         makes a diamond one visit and a cycle terminate — whether a
         cyclic graph RESOLVES stays the resolver's ordinary business,
         but a walk that hung here would hang the verb.

         Only names the LOCK records as path-supplied are followed: a
         sibling's index dependency is an installed star the child
         already sees through its curated path, not a source file to
         file in."
        <category: 'private'>
        someNames do: [:name |
            | declared manifest |
            (aSeenSet includes: name) ifFalse: [
                aSeenSet add: name.
                declared := aResolution provenanceOf: name.
                manifest := ManifestFile load:
                    workingDir, '/', declared, '/Package.st'.
                self addFileInsOf: (manifest pathDependencies
                        collect: [:each | each name])
                    from: aResolution
                    seen: aSeenSet
                    into: aCollection.
                manifest fileIns do: [:each |
                    aCollection add: declared, '/', each]]]
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
        row isNil ifTrue: [
            ^self usageFor: #unknownLayout subject: aLayoutName].
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
        | resolution manifest chains refusal |
        resolution := self pinnedResolution.
        resolution isNil ifTrue: [^self reportMissingLock].
        (resolution packageNames includes: aName) ifFalse: [
            ^CliResult
                lines: (Array with: aName printString,
                    ' is not pinned in parley.lock')
                exitCode: 1].
        manifest := self loadManifest.
        refusal := self indexRefusalFor: manifest.
        refusal notNil ifTrue: [^refusal].
        chains := OrderedCollection new.
        self collectChainsTo: aName
            from: (self declaredEdgesOf: manifest)
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
        | resolution manifest lines refusal |
        resolution := self pinnedResolution.
        resolution isNil ifTrue: [^self reportMissingLock].
        manifest := self loadManifest.
        refusal := self indexRefusalFor: manifest.
        refusal notNil ifTrue: [^refusal].
        lines := OrderedCollection new.
        lines add: manifest name, ' ', manifest version printString.
        self addTreeLinesFor: (self declaredEdgesOf: manifest)
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
        | resolution manifest snapshot problems refusal |
        resolution := self pinnedResolution.
        resolution isNil ifTrue: [^self reportMissingLock].
        manifest := self loadManifest.
        refusal := self indexRefusalFor: manifest.
        refusal notNil ifTrue: [^refusal].
        problems := OrderedCollection new.
        problems addAll:
            (PinVerification of: manifest lock: resolution) problems.
        snapshot := self seededSource snapshot.
        "THE DRIFT LEG (Sprint 21, §8 decision 68). A sibling that has
         moved its DECLARED version since the lock was written makes the
         lock a stale statement about the code exec actually loads, and
         the division of labour is the retirement leg's own: exec loads
         the sibling fresh and never fails on drift; check is where
         drift becomes a diagnosis, as install proceeds and check
         reports."
        resolution pathNames do: [:name |
            | declared sibling |
            declared := resolution provenanceOf: name.
            sibling := ManifestFile load:
                workingDir, '/', declared, '/Package.st'.
            sibling version = (resolution versionOf: name) ifFalse: [
                problems add: (self class driftProblemFor: name
                    pinned: (resolution versionOf: name) printString
                    declared: sibling version printString
                    path: declared)]].
        "THE RETIREMENT LEG PASSES PATH PINS BY: retirement is an index
         owner's assertion ABOUT A RELEASE THEY PUBLISHED, and no index
         published this pin. A leg that keyed on (name, version) alone
         would report a sibling as retired because the index happens to
         have retired a release of the same name."
        resolution packageNames do: [:name |
            | version reason |
            (resolution provenanceOf: name) isNil ifTrue: [
                version := resolution versionOf: name.
                reason := snapshot retirementReasonFor: name version: version.
                reason notNil ifTrue: [
                    problems add: 'lock pins ', name printString,
                        ' at ', version printString,
                        ', which the index has retired: ', reason]]].
        problems isEmpty ifTrue: [
            ^CliResult
                lines: (Array with: 'parley.lock is healthy - pins satisfy Package.st and nothing pinned is retired')
                exitCode: 0].
        ^CliResult lines: problems asArray exitCode: 1
    ]

    "---- the verbs that close the grammar (Doc E §4.1, Sprint 20) ----"

    search: aTerm [
        "Substring match over the package names the index publishes: one
         line per hit, sorted, exit 0 (§8 decision 80).

         IT REFUSES OVER A TRANSPORT THAT CANNOT ANSWER IT, and the
         refusal comes FIRST, before the source is ever consulted — a
         refusal that fetched would have begun answering the question it
         says it cannot answer. A sparse index publishes one listing per
         package and no catalogue, so a search over the snapshot such a
         source answers would return the operator's own closure: the
         packages they already depend on, dressed as a complete result
         and indistinguishable from one.

         NO MATCH IS AN ANSWER, NOT AN ERROR (§8 decision 57): one line
         naming the term and the index, at exit 0. An operator who asked
         a question got it answered, and apt, cargo, npm and gem all
         agree. The contrast is info, which exits 1 for a name the index
         does not publish — there the operator ASSERTED something and it
         was false."
        <category: 'verbs'>
        | seeded snapshot hits |
        (CommandLine canSearch: source) ifFalse: [
            ^CliResult
                lines: (Array with: self searchRefusalLine)
                exitCode: 1].
        seeded := self seededSource.
        snapshot := seeded snapshot.
        hits := snapshot packageNames select: [:name |
            self name: name includes: aTerm].
        hits isEmpty ifTrue: [
            ^CliResult
                lines: (Array with: (self noMatchLineFor: aTerm))
                exitCode: 0].
        ^CliResult
            lines: (hits collect: [:name |
                self searchLineFor: name in: snapshot source: seeded])
            exitCode: 0
    ]

    info: aName [
        "One package's metadata: name, latest version, summary, author,
         license, dependencies, and every published version with the
         retired ones MARKED.

         IT SEEDS THE NAME IT WAS ASKED ABOUT, through the settled
         private add already uses for the identical reason (§8 decision
         51). A name in neither Package.st nor parley.lock is invisible
         to a sparse closure, so without the seed a package the index
         really publishes would answer `not published` — a false
         diagnosis, and §8 decision 80's own harm class one door down,
         in the verb that same decision uses to justify refusing search.
         The seed is a no-op for a scanning source, which answers self.

         THE METADATA COMES FROM THE SOURCE PROTOCOL, NOT THE SNAPSHOT
         (Doc C §2): a release record is {Version. sha256.
         dependencies} and carries none of it. manifestFor:version:
         answers a LibraryManifest that carries exactly these fields.

         THE VERSION LIST COMES FROM allVersionsOf:, which keeps retired
         releases and bypasses the held map — info reports what the
         index PUBLISHED, which is a different question from what a
         resolution may select or what this project happens to pin."
        <category: 'verbs'>
        | seeded snapshot versions latest manifest lines |
        seeded := self seededSourceAdding: aName.
        snapshot := seeded snapshot.
        versions := snapshot allVersionsOf: aName.
        versions isEmpty ifTrue: [
            "A NAME ONLY A PATH SUPPLIES IS STILL NOT PUBLISHED, and the
             answer says both (§8 decision 68's matrix): the index's
             answer is unchanged, and the operator learns why their
             project runs anyway."
            | declared |
            declared := snapshot pathProvenance at: aName ifAbsent: [nil].
            ^CliResult
                lines: (Array with: (declared isNil
                    ifTrue: [self notPublishedLineFor: aName]
                    ifFalse: [self class infoPathProvenanceLineFor: aName
                        path: declared]))
                exitCode: 1].
        latest := self newestLiveIn: versions of: aName in: snapshot.
        manifest := seeded manifestFor: aName version: latest.
        lines := OrderedCollection new.
        lines add: 'name: ', aName.
        lines add: 'latest: ', latest printString.
        lines add: 'summary: ', manifest summary.
        lines add: 'author: ', manifest author.
        lines add: 'license: ', manifest license.
        lines add: 'dependencies: ',
            (self dependencyTextOf: manifest).
        lines add: 'versions:'.
        versions do: [:each |
            lines add: (self versionLineFor: each of: aName in: snapshot)].
        ^CliResult lines: lines asArray exitCode: 0
    ]

    outdated [
        "For each lock pin, TWO COLUMNS: the newest non-retired release
         the manifest's constraint still allows, and separately the
         newest the index publishes at all.

         CONFLATING THEM WOULD BE A WRONG CLAIM. `You can upgrade` and
         `you would have to widen your constraint` are different facts
         with different actions, so they are rendered apart and never
         merged into one arrow. A RETIRED newer release is offered in
         NEITHER: it is not an upgrade, whichever column it would land
         in.

         A TRANSITIVE PIN RENDERS A MARKER IN THE ALLOWED COLUMN (§8
         decision 82). A pin the root manifest never names has no
         constraint of the operator's, and both tempting defaults lie:
         treating absence as `every version is allowed` makes the two
         columns coincide and recommends an upgrade the dependency graph
         may forbid, while omitting the pin answers `nothing is
         outdated` over a lock carrying a stale transitive release. The
         published column is reported unchanged, because that fact is
         true whoever owns the constraint.

         A fully current project answers one line saying so at exit 0 —
         the resolve-with-no-dependencies precedent, because a verb that
         prints nothing reads as a verb that did nothing."
        <category: 'verbs'>
        | pinned manifest snapshot lines |
        pinned := self pinnedResolution.
        pinned isNil ifTrue: [^self reportMissingLock].
        manifest := self loadManifest.
        snapshot := self seededSource snapshot.
        lines := OrderedCollection new.
        pinned packageNames do: [:name |
            | line |
            line := self outdatedLineFor: name
                pinned: (pinned versionOf: name)
                manifest: manifest
                snapshot: snapshot
                path: (pinned provenanceOf: name).
            line notNil ifTrue: [lines add: line]].
        lines isEmpty ifTrue: [
            ^CliResult
                lines: (Array with: self nothingOutdatedLine)
                exitCode: 0].
        ^CliResult lines: lines asArray exitCode: 0
    ]

    "---- what the three reading verbs compute ----"

    name: aName includes: aTerm [
        "Private — whether aTerm appears anywhere in aName. A substring
         match rather than a prefix, so an operator who remembers half a
         name still finds the package. An empty term matches
         everything, which is the honest reading of asking for nothing
         in particular."
        <category: 'private-reporting'>
        aTerm isEmpty ifTrue: [^true].
        1 to: aName size - aTerm size + 1 do: [:i |
            (aName copyFrom: i to: i + aTerm size - 1) = aTerm
                ifTrue: [^true]].
        ^false
    ]

    newestLiveIn: someVersions of: aName in: aSnapshot [
        "Private — the newest of someVersions the index has NOT retired,
         or the newest of all when the index has retired every one of
         them. someVersions arrives sorted ascending.

         The fallback is deliberate rather than a shortcut: a package
         whose every release is retired is still published, still has a
         latest release, and still has metadata to report — answering
         nothing about it would be the silent partial answer §8
         decision 80 refuses."
        <category: 'private-reporting'>
        someVersions reverseDo: [:each |
            (aSnapshot retirementReasonFor: aName version: each) isNil
                ifTrue: [^each]].
        ^someVersions last
    ]

    newestAllowedOf: aName in: aSnapshot by: aConstraint [
        "Private — the newest non-retired release of aName the
         constraint admits, or nil when it admits none of them."
        <category: 'private-reporting'>
        (aSnapshot allVersionsOf: aName) reverseDo: [:each |
            ((aSnapshot retirementReasonFor: aName version: each) isNil
                and: [aConstraint allows: each]) ifTrue: [^each]].
        ^nil
    ]

    newestPublishedOf: aName in: aSnapshot [
        "Private — the newest non-retired release of aName, whatever any
         constraint says; nil when every release is retired."
        <category: 'private-reporting'>
        ^self newestAllowedOf: aName in: aSnapshot
            by: VersionConstraint any
    ]

    outdatedLineFor: aName pinned: aVersion manifest: aManifest snapshot: aSnapshot path: aDeclaredPathOrNil [
        "Private — one pin's two columns, or nil when the pin has
         nowhere to go and contributes no line.

         A PATH PIN RENDERS THE SECOND DECLARED MARKER OF §8 DECISION
         82's FAMILY, and it is checked BEFORE the transitive case
         because a path pin is not the transitive one: the operator
         DECLARED it, so the marker must not tell them the repair is out
         of their hands. Its published column is the index's answer
         unchanged, whoever supplies the name."
        <category: 'private-reporting'>
        | dependency published allowed allowedText |
        published := self newestPublishedOf: aName in: aSnapshot.
        published isNil ifTrue: [^nil].
        dependency := aManifest dependencies
            detect: [:each | each name = aName]
            ifNone: [nil].
        allowed := dependency isNil
            ifTrue: [nil]
            ifFalse: [self newestAllowedOf: aName in: aSnapshot
                by: dependency constraint].
        (published > aVersion
            or: [allowed notNil and: [allowed > aVersion]]) ifFalse: [^nil].
        allowedText := aDeclaredPathOrNil notNil
            ifTrue: [self class pathAllowedMarkerFor: aDeclaredPathOrNil]
            ifFalse: [allowed isNil
                ifTrue: [self class unconstrainedAllowedMarker]
                ifFalse: [allowed printString]].
        ^aName, ' ', aVersion printString, '  allowed ', allowedText,
            '  published ', published printString
    ]

    dependencyTextOf: aManifest [
        "Private — a manifest's dependencies as one line, sorted by name
         exactly as every other rendering of them is, or the word none."
        <category: 'private-reporting'>
        | out sorted |
        aManifest dependencies isEmpty ifTrue: [^'none'].
        sorted := aManifest dependencies asSortedCollection:
            [:a :b | a name <= b name].
        out := WriteStream on: String new.
        sorted
            do: [:each | out nextPutAll: each name;
                nextPutAll: ' ';
                nextPutAll: each constraint printString]
            separatedBy: [out nextPutAll: ', '].
        ^out contents
    ]

    versionLineFor: aVersion of: aName in: aSnapshot [
        "Private — one line of info's version list, indented two spaces
         like every other nested rendering this tool composes, and
         MARKED when the index owner has retired it — carrying their
         reason verbatim through the settled
         retirementReasonFor:version:, which gains its second reader
         here (the first is check)."
        <category: 'private-reporting'>
        | reason |
        reason := aSnapshot retirementReasonFor: aName version: aVersion.
        ^reason isNil
            ifTrue: ['  ', aVersion printString]
            ifFalse: ['  ', aVersion printString, '  retired: ', reason]
    ]

    searchLineFor: aName in: aSnapshot source: aPackageSource [
        "Private — one search hit: the name, the newest release an
         operator may actually take, and the summary, two spaces between
         columns. The latest column skips a retired release for the same
         reason outdated never offers one.

         The source is passed in rather than re-seeded per hit: seeding
         answers a NEW source, and taking one per line would re-read the
         index once per package for an answer already in hand."
        <category: 'private-reporting'>
        | latest |
        latest := self newestLiveIn: (aSnapshot allVersionsOf: aName)
            of: aName in: aSnapshot.
        ^aName, '  ', latest printString, '  ',
            (aPackageSource manifestFor: aName version: latest) summary
    ]

    declaredEdgesOf: aManifest [
        "Private — the root's own edges AS DECLARED, for the verbs that
         READ AND EXPLAIN: index dependencies, path dependencies and dev
         dependencies together (Doc E §4.1, ruled mid-sprint at GREEN
         step 5).

         Doc E §4.1 says the root's own edges come from its manifest,
         and with three declared kinds that must mean all three — a verb
         explaining two of them explains a graph the project does not
         have. `why kernel-text` answered ZERO LINES and `tree` rendered
         the root alone before this existed, and `why kernel-lint` had
         the identical gap for the dev kind.

         THIS IS NOT resolutionViewOf:, AND THE DIFFERENCE IS THE POINT.
         That value carries SYNTHETIC unconstrained edges because the
         Resolver needs candidates; this one is the DECLARED set, whose
         annotations the operator actually wrote. Two values, two
         purposes, one object read twice — the composed view keeps its
         four consumers and none of them is here.

         A path dependency's placeholder constraint is never rendered:
         the hop names the DIRECTORY, read from the lock's own
         provenance below."
        <category: 'private-inspection'>
        | edges |
        edges := OrderedCollection new.
        edges addAll: aManifest dependencies.
        aManifest pathDependencies do: [:each |
            edges add: (Dependency name: each name
                constraint: VersionConstraint any)].
        edges addAll: aManifest devDependencies.
        ^edges asArray
    ]

    hopAnnotationFor: aName dependency: aDependency resolution: aResolution [
        "Private — what a why hop says about the edge it just walked:
         the DECLARED DIRECTORY for a path-supplied pin, and the
         constraint that demanded it for every other. The operator asked
         why a pin exists, and `a directory you declared` is the answer
         (§8 decision 68's matrix).

         It reads the LOCK's provenance rather than the manifest, so a
         TRANSITIVE path pin — one a sibling declared — is named the
         same way as a root-declared one, which is what the lock records
         it as.

         THIS IS THE OPPOSITE BOUND FROM declaredProvenanceOf:, AND THE
         TWO ARE NOT IN CONFLICT. That one names only what the ROOT
         declared, because a conflict speaks before resolution and a
         sibling's declaration is not yet a fact of the project. This
         one reports what the lock recorded, after resolution settled
         it. Reading a Gate B diff, the distinction is design rather
         than drift: different question, different moment, different
         source."
        <category: 'private-inspection'>
        | declared |
        declared := aResolution provenanceOf: aName.
        ^declared isNil
            ifTrue: [aDependency constraint printString]
            ifFalse: ['path ', declared printString]
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
                    ' (', (self hopAnnotationFor: name
                        dependency: dep
                        resolution: aResolution), ')'.
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
        | corrupt set installable |
        anOutcome isResolution ifFalse: [^self reportConflict: anOutcome].
        "THE INSTALLER IS HANDED THE PATH-FREE VIEW (§8 decision 69). A
         #path pin is no-fetch, no-store, no-register: it is not an
         index release and never enters the Doc D pipeline, so Installer,
         InstalledSet and ContentStore never learn that paths exist and
         decision 25's empty-sha256 diagnosis keeps governing exactly
         the index pins it was written about. Path-supplied code reaches
         the child at exec time instead."
        installable := anOutcome pathFreeView.
        corrupt := self corruptHashIn: installable.
        corrupt notNil ifTrue: [^self reportCorruption: corrupt].
        set := [(Installer source: source store: store) install: installable]
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
        outcome := self resolve: aManifest against: aSnapshot.
        outcome isResolution ifFalse: [
            self restore: anOriginalText lock: aLockText.
            ^CliResult
                lines: (self conflictLinesFor: outcome
                    manifest: aManifest unheld: anUnheldSnapshot)
                exitCode: 1].
        "A --locked REFUSAL MUST NOT BREAK ATOMICITY. writeLock: signals
         when the mode forbids the change, and that signal would
         otherwise escape past the restore below — leaving an edited
         Package.st beside an unchanged lock, which is exactly the state
         PinVerification exists to call broken and which the tool would
         have manufactured (Doc B §2.1). The project goes back first;
         the boundary still composes the diagnosis.

         IT SIGNALS FRESH RATHER THAN SENDING pass, AND THAT IS A
         PROBED FACT ABOUT 3.2.5 RATHER THAN A PREFERENCE. On this
         toolchain `pass` DOES NOT UNWIND: it runs the outer handler,
         DISCARDS that handler's value, and RESUMES after the inner
         on:do:. Probed as a method-shaped reduction — an inner handler
         sending `e pass` prints the outer handler running and then the
         statement AFTER the on:do:, answering the method's own final
         value; the same shape signalling fresh answers the boundary's
         value and never reaches that statement.

         Shipped with `e pass` this method therefore restored the
         project, let CommandLine compose the exit-1 refusal, THREW
         THAT ANSWER AWAY, ran installResolution: and answered EXIT 0 —
         `add --locked` and `remove --locked` telling an operator, and
         any CI script, that the add succeeded while nothing had been
         written. A fail-wrong at exit 0 in the one contract §4.2 states
         without qualification: no failing command ever exits 0. Found
         at Gate B; the atomicity half had always been correct, which is
         what made the exit code the whole of the defect.

         THE SAFE CONTRAST SHAPE IS Parley.Parley class >> define:'s
         `^anError pass`, where pass is the handler's RETURNED final
         action, so its answer becomes the handler's answer. The
         difference is not the selector but whether the value is used;
         those are the only two live `pass` sends in src/.

         WHAT THE OLD COMMENT HERE GOT WRONG IS WORTH KEEPING. It
         reconciled this site against §8 decision 75 BY ARGUMENT —
         correctly observing that 75 refused catch-restore-pass for the
         authoring capture on containment grounds that do not apply to a
         block holding nothing but Parley's own write step. All of that
         is true and none of it was the question. The question was what
         `pass` DOES here, which only a probe could answer, and the
         comment's confident agreement with the code is what let one
         misunderstanding read as two independent confirmations. A
         reconciliation comment cites a probe, never an argument
         (decision 43's standard, applied to comments).

         The rest stands unchanged: the restore honours decision 49's
         atomicity under a mode flag, and the §4.2 boundary remains the
         one place a diagnosis is composed — it just has to be REACHED."
        [self writeLock: outcome]
            on: LockError
            do: [:e |
                self restore: anOriginalText lock: aLockText.
                LockError signalProblems: e problems].
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
        (self resolve: aManifest against: anUnheldSnapshot) isResolution
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

    manifest: aNewManifest removes: aName from: anOldManifest [
        "Private — the semantic verification for deletion (Doc B §2.1),
         the mirror of manifest:adds:to:. The reloaded manifest no
         longer declares aName and is OTHERWISE EQUAL to the one loaded
         before the edit — same name, version, fileIns ORDER and every
         other dependency still there.

         The fileIns comparison is not ceremony: it is gst-package load
         order, it is semantic in Smalltalk, and a splice that removed
         the wrong span could reorder or drop one while still answering
         a manifest that has one fewer dependency."
        <category: 'private-add'>
        aNewManifest name = anOldManifest name ifFalse: [^false].
        aNewManifest version = anOldManifest version ifFalse: [^false].
        aNewManifest fileIns asArray = anOldManifest fileIns asArray
            ifFalse: [^false].
        aNewManifest dependencies size
            = (anOldManifest dependencies size - 1) ifFalse: [^false].
        aNewManifest dependencies do: [:dep |
            (anOldManifest dependencies includes: dep) ifFalse: [^false]].
        ^(aNewManifest dependencies
            detect: [:dep | dep name = aName]
            ifNone: [nil]) isNil
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
            "A PATH PIN IS NEVER HELD (§8 decision 68). It is what you
             are DEVELOPING, so the overlay always answers the sibling's
             CURRENT declaration — and holding a drifted one at its
             locked version would narrow to a version the overlay no
             longer describes, which is §8 decision 47's collapse
             arriving by composition rather than by anyone's intent. The
             exclusion is the mechanism, not a preference."
            (each = aName or: [(aResolution provenanceOf: each) notNil])
                ifFalse: [held at: each put: (aResolution versionOf: each)]].
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
            ^'#packages must be an array of #(<name> <version> #sha256 <hex digest>) or #(<name> <version> #path <declared path>) tuples'].
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
        "THE DIGEST GROUND IS ASKED OF #sha256 TUPLES ALONE. A #path
         pin carries a declared directory in that position, not a
         digest, and holding it to 64 hex characters would refuse
         Parley's own output — the failure the settled empty-string
         exemption already exists to prevent, arriving on the other
         declared form. Its own shape rule (a non-empty String) is the
         boundary's, above."
        ((self lockFieldsOf: anEntry) at: #packages) do: [:tuple |
            ((tuple at: 3) == #sha256
                and: [(self isLockDigest: (tuple at: 4)) not]) ifTrue: [
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
        "Private — an array of four-element tuples in one of the TWO
         declared forms (Doc B §5.3): #(<name> <version> #sha256 <hex
         digest>), or from Sprint 21 #(<name> <version> #path <declared
         path>). Every structural defect answers the one wording: they
         are one question and one repair, as the settled #dependencies
         and #archive checks already are.

         EXACTLY THE TWO FORMS AND NOTHING BETWEEN THEM. A boundary
         that accepted any symbol in third position would let a future
         spelling through silently, and one that accepted an EMPTY
         declared path would write down a pin describing nothing — the
         corruption check exists to catch, manufactured by the tool
         itself (§8 decision 47's argument, one layer down). The digest
         itself is still not inspected here: shape only, and digest
         truth is Doc D §3's verifyHash:."
        <category: 'private-lock'>
        (aValue isKindOf: Array) ifFalse: [^false].
        aValue do: [:tuple |
            ((tuple isKindOf: Array) and: [tuple size = 4])
                ifFalse: [^false].
            (SchemaShape isString: (tuple at: 1)) ifFalse: [^false].
            (SchemaShape isString: (tuple at: 2)) ifFalse: [^false].
            (SchemaShape isString: (tuple at: 4)) ifFalse: [^false].
            (tuple at: 3) == #sha256
                ifFalse: [
                    (tuple at: 3) == #path ifFalse: [^false].
                    (tuple at: 4) isEmpty ifTrue: [^false]]].
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
        outcome := self resolve: aManifest
            against: self seededSource snapshot.
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
         never read Package.st or parley.lock.

         FROM SPRINT 21 THE WIRED SOURCE IS WRAPPED IN THE OVERLAY
         (Doc C §1.3, §8 decision 68), here and at every snapshot site
         at once, because a verb that took a bare source would resolve
         a different world from the one every other verb sees. The
         overlay is a DECORATOR: with no path dependencies declared it
         delegates everything and composes over an empty record set, so
         every settled path-free project is byte-identical."
        <category: 'private'>
        ^(self overlaidSource) seededWith: self seedNames
    ]

    overlaidSource [
        "Private — the wired source with the root manifest's declared
         path dependencies overlaid. Construction is pathname-passive:
         the siblings are read at the overlay's own one I/O moment,
         never here."
        <category: 'private'>
        ^PathOverlay over: source
            paths: self declaredPaths
            in: workingDir
    ]

    declaredPaths [
        "Private — the root manifest's path dependencies, gathered
         BEST-EFFORT in the settled shape of seedNames (§8 decision 52):
         the manifest has a boundary that owns its diagnosis, and
         gathering must never pre-empt it. A manifest that cannot be
         read contributes no paths and the verb itself diagnoses the
         file, exactly as a corrupt lock leaves resolve at exit 0.

         The catch names the boundary it defers to AND NOTHING ELSE:
         anything unanticipated reaches the settled taxonomy as the
         software defect it is, rather than becoming a silently empty
         overlay — which over a path-only project would answer a
         #noVersions conflict BLAMING THE PACKAGE, the exact wrong-blame
         diagnosis this overlay exists to make impossible."
        <category: 'private'>
        ^[(ManifestFile load: self packagePath) pathDependencies]
            on: ManifestError
            do: [:e | e return: #()]
    ]

    indexRefusalFor: aManifest [
        "Private — the §8 decision 83/84 refusal, or nil when this
         invocation can proceed. NEEDS AN INDEX IS A PROPERTY OF THE
         MANIFEST, never of the grammar: once a manifest may declare
         only path dependencies, HAS DEPENDENCIES and NEEDS AN INDEX
         come apart, and no argv-pure predicate can see the difference.

         It refuses AFTER state creation, joining route 6's residual,
         search's decision-80 refusal and info-on-an-unknown-name in the
         refuses-after-state class — declared here rather than left to
         be noticed."
        <category: 'private'>
        | needed |
        source notNil ifTrue: [^nil].
        needed := self indexNeedingNamesOf: aManifest.
        needed isEmpty ifTrue: [^nil].
        ^CliResult
            lines: (Array with: (self class needsIndexRefusalFor: needed))
            exitCode: 1
    ]

    indexNeedingNamesOf: aManifest [
        "Private — the declared names an index would have to supply,
         sorted so the refusal is byte-stable.

         PATH DEPENDENCIES ARE EXCLUDED because a directory supplies
         them: telling an operator to wire an index for code they
         already have on disk would be a remedy that cannot work. Dev
         dependencies are INCLUDED, because they are ordinary
         constraint-bearing declarations and only an index can satisfy
         one."
        <category: 'private'>
        | names |
        names := OrderedCollection new.
        aManifest dependencies do: [:each | names add: each name].
        aManifest devDependencies do: [:each | names add: each name].
        ^(names asSortedCollection: [:a :b | a <= b]) asArray
    ]

    resolutionViewOf: aManifest [
        "Private — the manifest as the RESOLVER must see it: the
         declared index edges, one UNCONSTRAINED edge per path
         dependency, and the root's own dev dependencies (§8 decision
         69: dev dependencies are resolved and installed for the root
         manifest alone).

         THE UNCONSTRAINED PATH EDGE IS EXACT RATHER THAN LAX. The
         overlay offers exactly one version for an overlaid name — the
         whole name, because a path dependency always wins over an index
         release — so the only candidate is the sibling's own
         declaration and any constraint admitting it admits nothing
         else. Spelling a version-shaped constraint here would put a pin
         in the graph that the author never wrote.

         IT IS AN INTERNAL WIRING VALUE WITH EXACTLY ONE CONSUMER, THE
         RESOLVER, and the boundary is stated so it cannot grow a
         second: the lock is written from the RESOLUTION, never from
         this; PinVerification verifies the DECLARED manifest over the
         three kinds, never this; publish serializes from the DECLARED
         manifest, so its path refusal and its dev exclusion both key
         off declarations; and this never reaches IndexEntryWriter's
         entry path. A fifth consumer is a halt-and-ask, not a
         judgement call."
        <category: 'private'>
        | edges |
        edges := OrderedCollection new.
        edges addAll: aManifest dependencies.
        aManifest pathDependencies do: [:each |
            edges add: (Dependency name: each name
                constraint: VersionConstraint any)].
        edges addAll: aManifest devDependencies.
        ^LibraryManifest
            name: aManifest name
            version: aManifest version
            summary: aManifest summary
            author: aManifest author
            license: aManifest license
            fileIns: aManifest fileIns
            dependencies: edges asArray
            paths: #()
            dev: #()
    ]

    resolve: aManifest against: aSnapshot [
        "Private — the ONE place this CLI enters the resolver, so the
         composed view and the provenance attachment cannot drift apart
         between the verbs that resolve.

         Provenance comes from the SNAPSHOT rather than the manifest,
         because a TRANSITIVE path pin — a sibling's own path dependency
         — is known to the overlay's walk and to nothing the manifest
         holds. withPaths: keeps only names the resolution carries, so a
         path-free project answers a value whose lock bytes are
         identical to Sprint 20's."
        <category: 'private'>
        | outcome |
        outcome := (Resolver strategy: BacktrackingStrategy new)
            resolve: (self resolutionViewOf: aManifest)
            against: aSnapshot.
        ^outcome isResolution
            ifTrue: [outcome withPaths: aSnapshot pathProvenance]
            ifFalse: [outcome]
    ]

    seededSourceAdding: aName [
        "Private — a source seeded with one further name beyond the
         decision-51 set, for the two verbs that ask about a package the
         project does not yet mention.

         add snapshots BEFORE it edits Package.st, so the added name is
         in neither file the seed set is otherwise built from and must
         be seeded explicitly (issue #16 S16).

         info IS THE SECOND CALLER, and it is here for the identical
         reason (Sprint 20, issue #22): the package an operator asks
         about is in neither Package.st nor parley.lock, so over a
         sparse index the closure would never fetch its listing and the
         verb would answer `not published` about a package the index
         really publishes. Same mechanism, same sentence, no new
         machinery — and a no-op for a scanning source, which answers
         self."
        <category: 'private'>
        | names |
        names := self seedNames.
        names add: aName.
        "THE OVERLAY WRAPS HERE TOO. Sending seededWith: to the bare
         source would give info and add a DIFFERENT world from every
         other verb — no path dependency in it at all — which is how
         info came to answer the settled not-published line about a name
         a directory really supplies. Every snapshot site wraps, or the
         verbs disagree about what the project is."
        ^self overlaidSource seededWith: names
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
        | out refusal |
        out := WriteStream on: String new.
        IndexEntryWriter writeLock: aResolution on: out.
        "THE --locked ENFORCEMENT SITE, AND THERE IS EXACTLY ONE (Doc E
         §4.2). The verb computes what it WOULD write, compares, and on
         any difference refuses naming the first differing pin — which
         is why the flag composes with every verb that writes the lock,
         add and remove included, without any of them knowing it exists.
         A current lock is ordinary success and nothing is written,
         because writing identical bytes is still a write."
        (modes includes: #locked) ifTrue: [
            refusal := self lockedRefusalAgainst: aResolution.
            refusal isNil ifFalse: [
                ^LockError signalProblems: (Array with: refusal)].
            ^self].
        self write: out contents to: self lockPath
    ]

    lockedRefusalAgainst: aResolution [
        "Private — the declared --locked refusal naming the FIRST
         differing pin in sorted order, or nil when this resolution
         would leave parley.lock exactly as it stands.

         Both directions of difference are a change: a pin that moves,
         a pin that is new (the current side renders as absent), and a
         pin the resolution drops (the would-be side renders as absent).
         A lock that does not exist at all is the new-pin case for every
         name, which is right — writing a first lock IS changing it.

         It READS the lock through the settled boundary, so a corrupt
         lock under --locked answers that boundary's own diagnosis. That
         is a deliberate consequence of the flag rather than a change to
         resolve: --locked is an assertion ABOUT the lock, so an
         invocation making it must be able to read the file it is
         asserting about."
        <category: 'private'>
        | pinned current |
        pinned := self pinnedResolution.
        current := Dictionary new.
        pinned isNil ifFalse: [
            pinned packageNames do: [:name |
                current at: name put: (pinned versionOf: name) printString]].
        aResolution packageNames do: [:name |
            | was now |
            now := (aResolution versionOf: name) printString.
            was := current at: name ifAbsent: [CommandLine absentPinText].
            was = now ifFalse: [
                ^CommandLine lockedRefusalFor: name
                    pinned: was would: now]].
        (current keys asSortedCollection: [:a :b | a <= b]) do: [:name |
            (aResolution packageNames includes: name) ifFalse: [
                ^CommandLine lockedRefusalFor: name
                    pinned: (current at: name)
                    would: CommandLine absentPinText]].
        ^nil
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

    usageFor: aGroundSymbol subject: aSubject [
        "Private — a usage error: the ground's own reason line, then the
         block, exit 2. The block is class-side and shared; the reason
         is what this invocation did."
        <category: 'private'>
        ^CliResult
            lines: (self class usageLinesFor: aGroundSymbol subject: aSubject)
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

    unrecognizedRemovalLineFor: aName [
        "Private — remove's shape refusal (pinned in RED, issue #22).
         It names the file AND the clause to delete, because a refusal
         that does not say what to do has cost the operator more than it
         saved (§8 decisions 31 and 44).

         IT NAMES THE CLAUSE BY ITS PACKAGE rather than by its exact
         bytes, and that is the honest half: a shape the recognizer
         could not read is a shape whose CONSTRAINT it could not read
         either, so a refusal quoting one would be asserting something
         it never checked — §8 decision 58's standard, in the sentence
         that exists to help."
        <category: 'private'>
        ^self packagePath,
            ': no single Parley define: cascade to edit - delete the dependency: ''',
            aName, ''' clause by hand'
    ]

    notDeclaredLineFor: aName [
        "Private — remove asked about a dependency the manifest does not
         declare (pinned in RED, issue #22). The why precedent and the
         why shape: the operator asked about something they do not have,
         which is their question and never a defect. Nothing is
         written."
        <category: 'private'>
        ^aName printString, ' is not declared in Package.st'
    ]

    alreadyDeclaredOtherKindLineFor: aName [
        "Private — the already-declared refusal for a name the manifest
         declares in one of the two ROOT-ONLY kinds, or nil when it
         declares neither (pinned in RED, issue #23).

         It reads the manifest rather than the editor's text, because
         the question is what the project DECLARES and the settled
         recognizer only knows dependency:constraint: clauses — which is
         precisely why a path or dev clause reaches this check instead
         of that one.

         The sentence stays in the already-declared family so the
         operator meets one idea rather than three, and it names the
         KIND and what is declared, because that is what tells them
         which clause to edit."
        <category: 'private-add'>
        | manifest |
        manifest := self loadManifest.
        manifest pathDependencies do: [:each |
            each name = aName ifTrue: [
                ^aName printString,
                    ' is already declared as a path dependency on ',
                    each path printString,
                    ' - changing how a dependency is supplied is an edit, not an add: change it in Package.st by hand']].
        manifest devDependencies do: [:each |
            each name = aName ifTrue: [
                ^aName printString,
                    ' is already declared as a dev dependency with constraint ',
                    each constraint printString printString,
                    ' - changing how a dependency is supplied is an edit, not an add: change it in Package.st by hand']].
        ^nil
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

    CLI class >> unconstrainedAllowedMarker [
        "What outdated renders in the allowed column for a pin the root
         manifest does not constrain (§8 decision 82, pinned in RED).

         ONE DECLARED WORDING CONSUMED TWICE — the renderer above and
         the law that holds it read this, and neither carries a copy.
         It is deliberately NOT version-shaped: the column means `what
         YOUR constraint allows`, a transitive pin has no such
         constraint, and the neutral element is the most dangerous
         default a report can pick — `no constraint` rendered as
         `anything goes` reads identically to a checked allowance, and
         a reader cannot tell an answer that was computed from an
         answer that was skipped."
        <category: 'usage'>
        ^'(transitive - no constraint of yours)'
    ]

    searchRefusalLine [
        "Private — search over a transport that publishes no catalogue
         (§8 decision 80, pinned in RED). It names the transport, WHY
         the question cannot be answered there, and the flags that CAN
         answer it, in the settled '<subject>: <cause> - <remedy>'
         grammar every other boundary uses.

         Exit 1 rather than 2, because the argv is well formed and the
         transport is the limit. Both flag lists are composed from the
         declared sourceFlags table, so a fourth source cannot drift out
         of the sentence that offers it."
        <category: 'private'>
        ^CommandLine unsearchableFlag,
            ': a sparse index publishes one listing per package and no catalogue - use ',
            (CommandLine list: CommandLine searchableFlagNames
                conjunction: 'or'),
            ' to search'
    ]

    noMatchLineFor: aTerm [
        "Private — search found nothing (pinned in RED). A question
         answered is not an error, so this is exit 0."
        <category: 'private'>
        ^'no package matching ', aTerm printString,
            ' in the configured index'
    ]

    notPublishedLineFor: aName [
        "Private — info was asked about a package the index does not
         publish (pinned in RED). Exit 1, and the contrast with search's
         empty answer is the whole reason the two codes differ: the
         operator ASSERTED this package exists and it does not."
        <category: 'private'>
        ^aName printString, ' is not published by the configured index'
    ]

    nothingOutdatedLine [
        "Private — every pin is already the newest the index publishes
         (pinned in RED). A line rather than silence: the
         resolve-with-no-dependencies precedent."
        <category: 'private'>
        ^'nothing is outdated - every pin is the newest the index publishes'
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
