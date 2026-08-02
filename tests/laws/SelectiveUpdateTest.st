"Parley Sprint 12 — the selective-update verb laws (issue #14;
 Doc C §2.2, Doc E §4.1/§5, §8 decision 46).

 THE DESIGN'S HEART IS WHERE THE NARROWING LIVES. It is in the
 SNAPSHOT, not in the search: update <pkg> resolves the ORDINARY way
 against a world narrowed to hold every other pin, so the Resolver,
 BacktrackingStrategy and ConstraintLedger are neither modified nor
 entered differently — a selective update is a normal resolution of a
 smaller world, and a future PubGrubStrategy inherits it for free.
 testANarrowedWorldResolvesTheOrdinaryWay is that claim at the value
 level: the settled resolver seam, consumed unchanged, over a narrowed
 snapshot — a Resolution when the smaller world allows one, a
 ConflictReport VALUE (never an exception) when it does not.

 THE BYTE-IDENTITY LAWS compare tuple by tuple — name, version and
 #sha256 digest — against the pre-update lock, because the weak forms
 ('the lock changed', 'the lock contains tool-b 2.0.0') both pass on a
 lock whose digest silently changed.

 THE DIAGNOSES all answer exit 1, never 70, never a backtrace: a
 missing lock, an unpinned package, and a conflict caused by holding —
 whose lines are the pinned held-pins sentence FOLLOWED BY the settled
 ConflictReport narration unmodified, composed here through the same
 narrowed world the verb must resolve (provenance stays at the CLI;
 the resolver cannot know why the world was small).

 DECLARED PASSES IN RED (issue #14): NONE in this file. Every law
 consumes IndexSnapshot>>holding: or the update <pkg> argv row, and
 neither exists against the pre-sprint tree: holding: fails as a
 doesNotUnderstand, and a two-element update argv falls through to the
 settled usage answer (exit 2) where these laws demand 0 or 1 — and
 the two usage laws themselves pin the NEW verbs: line, which the
 settled CLI does not render.

 Every fixture path is under tmp/, unique per test, removed
 recursively in tearDown; the developer image is never mutated;
 nothing here spawns (every runner is a RecordingRunner) and no
 network is contacted."

Namespace current: Parley.

TestCase subclass: SelectiveUpdateTest [
    | fixtureDirs |

    <comment: 'Laws for parley update <pkg>: the narrowed world
resolving through the untouched resolver seam, the named package
moving while every other tuple stays byte-identical, the transitive
name, the three diagnoses at exit 1, the already-newest byte-identical
rewrite, the install-and-register pipeline behind the verb, and the
update [<pkg>] argv grammar.'>

    setUp [
        fixtureDirs := OrderedCollection new
    ]

    tearDown [
        fixtureDirs isNil ifTrue: [^self].
        fixtureDirs do: [:each | ExecFixtures removeTree: each].
        fixtureDirs := nil
    ]

    track: aPath [
        fixtureDirs add: aPath.
        ^aPath
    ]

    freshDir: aLabel [
        ^self track: (SourceFixtures directoryNamed: aLabel)
    ]

    toolsIndex: aLabel [
        | path |
        path := self freshDir: aLabel.
        SelectiveUpdateFixtures populateToolsIndexIn: path.
        ^path
    ]

    version: aString [
        ^Version fromString: aString
    ]

    resultOf: anArgvArray in: aWorkDir runner: aRunner [
        ^(CommandLine in: aWorkDir runner: aRunner) run: anArgvArray
    ]

    updateOf: aName in: aWorkDir source: anIndexDir [
        ^self resultOf: (Array
                with: 'update' with: aName
                with: '--source' with: anIndexDir)
            in: aWorkDir runner: RecordingRunner new
    ]

    lockContentsIn: aWorkDir [
        ^SelectiveUpdateFixtures lockContentsIn: aWorkDir
    ]

    assertTuple: aTuple equals: anOtherTuple for: aName [
        "Tuple-by-tuple byte-identity: name, version, the #sha256
         marker and the digest, each asserted by value — String
         equality IS byte equality."
        1 to: 4 do: [:i |
            self assert: (aTuple at: i) = (anOtherTuple at: i)
                description: 'the unmoved ', aName,
                    ' tuple changed at position ', i printString,
                    ': ', (aTuple at: i) printString,
                    ' vs ', (anOtherTuple at: i) printString]
    ]

    denyBlamesParley: aResult [
        self deny: aResult exitCode = 70.
        aResult lines do: [:line |
            self deny: (CommandLineFixtures does: line
                include: LockBoundaryFixtures undiagnosedLinePrefix)
                description: 'the diagnosis blames Parley: ', line.
            CommandLineFixtures backtraceMarkers do: [:marker |
                self deny: (CommandLineFixtures does: line include: marker)
                    description: 'the diagnosis dumped a backtrace: ', line]]
    ]

    "---- the narrowed world resolves the ordinary way ----"

    testANarrowedWorldResolvesTheOrdinaryWay [
        "The settled resolver seam, consumed unchanged, over a
         narrowed snapshot. Held at a version the diamond can satisfy,
         it answers a Resolution honouring the hold; held at one it
         cannot, it answers a ConflictReport — a VALUE, never an
         exception, exactly as any small world does."
        | snapshot held outcome |
        snapshot := ResolverFixtures satisfiableDiamondSnapshot.
        held := Dictionary new.
        held at: 'c' put: (self version: '2.4.0').
        outcome := ResolverFixtures resolve: ResolverFixtures diamondRoot
            against: (snapshot holding: held).
        self assert: outcome isResolution.
        self assert: (outcome versionOf: 'c') printString = '2.4.0'.
        held := Dictionary new.
        held at: 'c' put: (self version: '1.5.0').
        outcome := ResolverFixtures resolve: ResolverFixtures diamondRoot
            against: (snapshot holding: held).
        self deny: outcome isResolution
            description: 'holding c at 1.5.0 against b''s ^2.0 must conflict'
    ]

    "---- the named package moves; the rest is byte-identical ----"

    testTheNamedPackageMovesAndAnswersThePinLines [
        "exit 0, the settled reportPins lines, and the byte-exact moved
         lock: install + register run exactly as update does, so the
         report is update's report."
        | work index result |
        work := self track: (SelectiveUpdateFixtures
            pinnedToolsWorkDirNamed: 'sel-move-work').
        index := self toolsIndex: 'sel-move-index'.
        result := self updateOf: 'tool-a' in: work source: index.
        self assert: result exitCode = 0.
        self assert: result lines
            = (Array with: 'tool-a 1.1.0' with: 'tool-b 2.0.0').
        self assert: (self lockContentsIn: work)
            = SelectiveUpdateFixtures toolsMovedLockString
    ]

    testEveryUnmovedTupleIsByteIdentical [
        "The S3 law shape: capture the pre-update tuples, run the
         update, and compare every unmoved tuple element by element —
         never as 'the lock changed'."
        | work index before after result |
        work := self track: (SelectiveUpdateFixtures
            pinnedToolsWorkDirNamed: 'sel-bytes-work').
        index := self toolsIndex: 'sel-bytes-index'.
        before := SelectiveUpdateFixtures packageTuplesIn: work.
        result := self updateOf: 'tool-a' in: work source: index.
        self assert: result exitCode = 0.
        after := SelectiveUpdateFixtures packageTuplesIn: work.
        self assertTuple: (after at: 'tool-b')
            equals: (before at: 'tool-b') for: 'tool-b'.
        self assert: ((after at: 'tool-a') at: 2) = '1.1.0'
            description: 'the named package did not move'
    ]

    testATransitiveDependencyCanBeNamed [
        "What is PINNED is updatable; being declared is not the test.
         The diamond root declares only a and b; naming c moves it to
         2.4.0 and writes exactly the settled diamond lock, with the a
         and b tuples byte-identical."
        | work index before result after |
        work := self track: (SelectiveUpdateFixtures
            diamondPinnedWorkDirNamed: 'sel-trans-work').
        index := self freshDir: 'sel-trans-index'.
        InstallFixtures populateInstallDiamondIn: index.
        before := SelectiveUpdateFixtures packageTuplesIn: work.
        result := self updateOf: 'c' in: work source: index.
        self assert: result exitCode = 0.
        self assert: (self lockContentsIn: work)
            = ExecFixtures diamondLockString.
        after := SelectiveUpdateFixtures packageTuplesIn: work.
        self assertTuple: (after at: 'a') equals: (before at: 'a') for: 'a'.
        self assertTuple: (after at: 'b') equals: (before at: 'b') for: 'b'
    ]

    "---- the diagnoses: exit 1, never 70, never a backtrace ----"

    testAnUnpinnedPackageIsOneDiagnosisLine [
        "The why precedent, in the why wording: the operator asked
         about a package they do not have. Nothing moves, nothing
         spawns, the lock is untouched."
        | work index runner result |
        work := self track: (SelectiveUpdateFixtures
            pinnedToolsWorkDirNamed: 'sel-unpinned-work').
        index := self toolsIndex: 'sel-unpinned-index'.
        runner := RecordingRunner new.
        result := self resultOf: (Array
                with: 'update' with: 'kernel-nonexistent'
                with: '--source' with: index)
            in: work runner: runner.
        self assert: result exitCode = 1.
        self assert: result lines = (Array with:
            (SelectiveUpdateFixtures notPinnedLineFor: 'kernel-nonexistent')).
        self assert: (self lockContentsIn: work)
            = SelectiveUpdateFixtures toolsLockString.
        self assert: runner commands isEmpty.
        self denyBlamesParley: result
    ]

    testALocklessProjectAnswersThePinnedMissingLockLine [
        "There is nothing to hold selectively when nothing is pinned,
         and silently doing a full resolve would be the opposite of
         what was asked. The repair named is resolve — the verb that
         writes a FIRST lock — and no lock is written by the
         diagnosis itself."
        | work index runner result |
        work := self track: (SelectiveUpdateFixtures
            toolsWorkDirNamed: 'sel-lockless-work').
        index := self toolsIndex: 'sel-lockless-index'.
        runner := RecordingRunner new.
        result := self resultOf: (Array
                with: 'update' with: 'tool-a'
                with: '--source' with: index)
            in: work runner: runner.
        self assert: result exitCode = 1.
        self assert: result lines
            = (Array with: SelectiveUpdateFixtures missingLockLine).
        self deny: (File name: work, '/parley.lock') exists
            description: 'the diagnosis wrote a lock'.
        self assert: runner commands isEmpty.
        self denyBlamesParley: result
    ]

    testHeldPinsUnsatisfiableAnswersTheHeldLineThenTheSettledNarration [
        "The pinned held-pins line FOLLOWED BY the settled
         ConflictReport narration, unmodified — composed here through
         the identical narrowed world, because the narration is the
         resolver's own value and the verb owes only the sentence the
         resolver could not know (Doc C §2.2: provenance at the CLI).
         A conflict writes nothing: the lock is byte-unchanged."
        | work index result held narrowed outcome expected |
        work := self track: (SelectiveUpdateFixtures
            heldConflictWorkDirNamed: 'sel-held-work').
        index := self freshDir: 'sel-held-index'.
        SelectiveUpdateFixtures populateHeldConflictIndexIn: index.
        held := SelectiveUpdateFixtures heldVersionsIn: work except: 'app-x'.
        narrowed := (DirectorySource on: index) snapshot holding: held.
        outcome := ResolverFixtures resolve:
            SelectiveUpdateFixtures heldConflictRootManifest
            against: narrowed.
        self deny: outcome isResolution
            description: 'the fixture does not conflict under holding - the law cannot fail'.
        expected := (Array with: SelectiveUpdateFixtures heldPinsLine),
            (ExecFixtures linesOf: outcome printString).
        result := self updateOf: 'app-x' in: work source: index.
        self assert: result exitCode = 1.
        self assert: result lines = expected.
        self assert: (self lockContentsIn: work)
            = SelectiveUpdateFixtures heldConflictLockString
            description: 'a conflict rewrote the lock'.
        self denyBlamesParley: result
    ]

    "---- already newest: a success that says so ----"

    testAlreadyNewestRewritesIdenticalBytesAndSaysSo [
        "exit 0, ONE pinned confirmation line naming the package and
         version, and the lock rewritten to identical bytes — the
         resolve-with-no-dependencies precedent."
        | work index result |
        work := self track: (SelectiveUpdateFixtures
            newestToolsWorkDirNamed: 'sel-newest-work').
        index := self toolsIndex: 'sel-newest-index'.
        result := self updateOf: 'tool-a' in: work source: index.
        self assert: result exitCode = 0.
        self assert: result lines = (Array with:
            (SelectiveUpdateFixtures alreadyNewestLineFor: 'tool-a'
                version: '1.1.0')).
        self assert: (self lockContentsIn: work)
            = SelectiveUpdateFixtures toolsMovedLockString
            description: 'the already-newest rewrite is not byte-identical'
    ]

    "---- the pipeline: install and register, exactly as update does ----"

    testTheVerbInstallsAndRegistersExactlyAsUpdateDoes [
        "The moved archive is fetched and hash-verified into the
         wiring's store, and the recorded registration plan is the
         settled Doc D §4 shape over the whole resolved set — the
         held pin included, exactly as update registers what it pins."
        | work index runner result storeRoot storedPath |
        work := self track: (SelectiveUpdateFixtures
            pinnedToolsWorkDirNamed: 'sel-pipe-work').
        index := self toolsIndex: 'sel-pipe-index'.
        runner := RecordingRunner new.
        result := self resultOf: (Array
                with: 'update' with: 'tool-a'
                with: '--source' with: index)
            in: work runner: runner.
        self assert: result exitCode = 0.
        storeRoot := CommandLineFixtures storeRootIn: work.
        storedPath := storeRoot, '/',
            SelectiveUpdateFixtures digestToolA110, '.star'.
        self assert: (File name: storedPath) exists
            description: 'the moved archive never reached the store'.
        self assert: (File name: storedPath) contents
            = SelectiveUpdateFixtures archiveBytesToolA110.
        self assert: runner commands
            = (SelectiveUpdateFixtures toolsMovedRegistrationPlanIn: work)
    ]

    "---- the argv grammar: update [<pkg>] ----"

    testUpdateWithAPackageAndNoSourceAnswersUsage [
        "A source-requiring verb with no source is the settled usage
         answer — with the verbs: line now naming update [<pkg>]."
        | cli runner result |
        runner := RecordingRunner new.
        cli := CLI in: 'tmp/parley-sel-usage-work'
            source: nil
            store: (ContentStore on: 'tmp/parley-sel-usage-store')
            target: 'tmp/parley-sel-usage-target'
            runner: runner.
        result := cli run: #('update' 'tool-a').
        self assert: result exitCode = 2.
        self assert: result lines
            = SelectiveUpdateFixtures selectiveUsageLines.
        self assert: runner commands isEmpty
    ]

    testUpdateWithTwoPackagesAnswersUsage [
        "Wrong arity — even with a source wired — is usage, exit 2:
         the grammar takes at most one package."
        | work index result |
        work := self track: (SelectiveUpdateFixtures
            pinnedToolsWorkDirNamed: 'sel-arity-work').
        index := self toolsIndex: 'sel-arity-index'.
        result := self resultOf: (Array
                with: 'update' with: 'tool-a' with: 'tool-b'
                with: '--source' with: index)
            in: work runner: RecordingRunner new.
        self assert: result exitCode = 2.
        self assert: result lines
            = SelectiveUpdateFixtures selectiveUsageLines.
        self assert: (self lockContentsIn: work)
            = SelectiveUpdateFixtures toolsLockString
    ]
]

Namespace current: Smalltalk.
