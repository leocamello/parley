"Parley — CLI: the package-manager verbs over everything beneath.
 Spec: docs/design/execution-and-cli.md §4; issue #8 S10-S19.
 An orchestration answering a value: run: dispatches the argv
 grammar (init | resolve | install | update [<pkg>] | exec <script> |
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
 (issue #14)."

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
        (verb = 'publish' and: [anArgvArray size = 2])
            ifTrue: [^self publish: (anArgvArray at: 2)].
        (verb = 'why' and: [anArgvArray size = 2 and: [source notNil]])
            ifTrue: [^self why: (anArgvArray at: 2)].
        (verb = 'update' and: [anArgvArray size = 2 and: [source notNil]])
            ifTrue: [^self update: (anArgvArray at: 2)].
        (anArgvArray size = 1 and: [source notNil]) ifTrue: [
            verb = 'resolve' ifTrue: [^self resolve].
            verb = 'install' ifTrue: [^self install].
            verb = 'update' ifTrue: [^self update].
            verb = 'tree' ifTrue: [^self tree].
            verb = 'check' ifTrue: [^self check]].
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
        | pinned held outcome result |
        pinned := self pinnedResolution.
        pinned isNil ifTrue: [^self reportMissingLock].
        (pinned packageNames includes: aName) ifFalse: [
            ^CliResult
                lines: (Array with: aName printString,
                    ' is not pinned in parley.lock')
                exitCode: 1].
        held := Dictionary new.
        pinned packageNames do: [:each |
            each = aName ifFalse: [
                held at: each put: (pinned versionOf: each)]].
        outcome := (Resolver strategy: BacktrackingStrategy new)
            resolve: self loadManifest
            against: (source snapshot holding: held).
        outcome isResolution ifFalse: [
            ^CliResult
                lines: (Array with: self heldPinsLine),
                    (self linesOf: outcome printString)
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

    publish: aDestDir [
        "Publish the working directory's own package into the
         destination index directory (Doc F §5): load the manifest,
         then run the Publisher pipeline. Success is one line naming
         the package and version, exit 0; a PublishError's problems
         become the lines, exit 1. No source collaborator is required —
         publishing produces index entries, it does not consume them."
        <category: 'verbs'>
        | manifest |
        manifest := self loadManifest.
        [(Publisher
            manifest: manifest
            in: workingDir
            to: aDestDir
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
            snapshot: source snapshot
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
            snapshot: source snapshot
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
        snapshot := source snapshot.
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
        | file entry shape value |
        file := File name: self lockPath.
        file exists ifFalse: [^nil].
        entry := [IndexEntryReader readFrom: (ReadStream on: file contents)]
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
                with: 'usage: parley <verb> [--source <dir> | --git <repo>]'
                with: 'verbs: init | resolve | install | update [<pkg>] | exec <script> | publish <dir> | why <pkg> | tree | check'
                with: 'flags: --source <dir>  index entries in a local directory'
                with: '       --git <repo>    index entries in a git repository')
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
