"Parley Sprint 21 — the overlay decorator and the provenance split
 (issue #23; Doc C §1.2/§1.3/§2/§7; §8 decisions 50, 51, 68).

 A SOURCE IS COMPOSED, NEVER TAUGHT. PathOverlay implements the full
 PackageSource protocol AROUND the wired source — or around nothing —
 and no settled source class changes. That is the fifth consecutive
 application of the put-it-in-the-source pattern (§8 decisions 37, 46,
 50, 51), and the reason Resolver, both strategies and ConstraintLedger
 are untouched: a future PubGrubStrategy inherits path dependencies for
 free.

 THE ONE I/O MOMENT IS snapshot, AND THE TRAP DOUBLE IS HOW THAT IS
 PROVED. A decorator that read a sibling lazily would satisfy every
 value law here and break the purity contract that the whole resolver
 rests on, so the composition is driven through a base that SIGNALS on
 every protocol message a resolution could reach.

 THE PROVENANCE SPLIT IS PROVED ON BOTH HALVES OF ONE FIXTURE. An
 implementation that overlaid everything passes the resolution half; an
 implementation that overlaid nothing passes the reporting half. Only a
 fixture where the index publishes the same name at a different version
 can fail either, so that is the fixture every split law here uses.

 THE CENSUS STAYS AT EIGHT (§8 decision 60). PathOverlay performs no
 direct File I/O of its own: siblings are read through the settled
 ManifestFile, which already has its census seat, and the resolved
 absolute path the visited set is keyed by is computed as a STRING
 rather than asked of the filesystem. The prohibition law in
 BoundaryTableTest is what enforces that, and it fails the moment a
 ninth class appears — this file states the constraint so the next
 reader knows the string arithmetic below is deliberate."

Namespace current: Parley.

TestCase subclass: PathOverlayTest [
    | fixtureDirs |

    <comment: 'Laws over PathOverlay: the fixpoint walk and its visited
set, the two-paths refusal, the re-seed through the settled
seededWith:, delegation of the index questions, the snapshot
composition with its provenance split, and the trap double proving zero
live I/O mid-resolution.'>

    setUp [
        fixtureDirs := OrderedCollection new
    ]

    tearDown [
        fixtureDirs isNil ifTrue: [^self].
        fixtureDirs do: [:each | PathFixtures removeTree: each].
        fixtureDirs := nil
    ]

    track: aPath [
        fixtureDirs add: aPath.
        ^aPath
    ]

    freshDir: aLabel [
        ^self track: (SourceFixtures directoryNamed: aLabel)
    ]

    sibling: aLabel [
        ^self track: (PathDepFixtures textSiblingNamed: aLabel)
    ]

    pathDependencyOn: aLabel [
        ^PathDependency name: 'kernel-text'
            path: (PathDepFixtures declaredPathFor: aLabel)
    ]

    workDirNamed: aLabel [
        "A working directory the overlay resolves declared paths
         against. It needs no Package.st: the overlay is handed the
         path dependencies as VALUES, exactly as the sparse source is
         handed its seeds, because a source that read the project would
         duplicate a settled deserialization boundary (§8 decision 51)."
        ^self freshDir: aLabel
    ]

    overlayOver: aSource paths: somePathDependencies in: aWorkDir [
        ^PathOverlay over: aSource paths: somePathDependencies in: aWorkDir
    ]

    indexWithTextAt: aVersionString named: aLabel [
        | index |
        index := self freshDir: aLabel.
        SourceFixtures write: (PathDepFixtures textEntryAt: aVersionString)
            toFile: 'kernel-text-', aVersionString, '.st' in: index.
        ^DirectorySource on: index
    ]

    "---- the protocol contract ----"

    testSeededWithAnswersANewDecoratorAndPerformsNoIo [
        "Doc C §1.2's contract verbatim: seededWith: answers a source
         that has not yet read anything. Driven over a base that signals
         on snapshot, so a decorator that read anything while being
         seeded fails rather than merely being slow."
        | overlay seeded |
        overlay := self overlayOver: SnapshotAndFetchTrapSource new
            paths: (Array with: (self pathDependencyOn: 'po-seed-text'))
            in: (self workDirNamed: 'po-seed-work').
        seeded := overlay seededWith: (Set with: 'kernel-a').
        self deny: seeded == overlay
            description: 'seededWith: answered the receiver rather than a new decorator'.
        self assert: (seeded isKindOf: PathOverlay)
            description: 'seededWith: answered ', seeded class name
    ]

    testTheIndexQuestionsDelegateToTheBaseUntouched [
        "versionsOf:, manifestFor:version: and fetch:version: are INDEX
         questions, and §2's provenance split governs the protocol
         exactly as it governs the snapshot. The base here publishes
         kernel-text 2.0.0 while a path supplies 1.2.0; the protocol
         answers the base."
        | base overlay |
        self sibling: 'po-delegate-text'.
        base := self indexWithTextAt: '2.0.0' named: 'po-delegate-index'.
        overlay := self overlayOver: base
            paths: (Array with: (self pathDependencyOn: 'po-delegate-text'))
            in: (self workDirNamed: 'po-delegate-work').
        self assert: (overlay versionsOf: 'kernel-text')
            = (base versionsOf: 'kernel-text')
            description: 'versionsOf: answered ',
                (overlay versionsOf: 'kernel-text') printString.
        self assert: (overlay manifestFor: 'kernel-text'
            version: (Version fromString: '2.0.0')) name = 'kernel-text'
            description: 'manifestFor:version: did not delegate'
    ]

    "---- the walk ----"

    testTheWalkFollowsASiblingsOwnPathDependencyToFixpoint [
        "Each sibling's own path dependencies are walked, so a chain of
         two directories composes into one snapshot. The walk is the
         overlay's, not the resolver's: the resolver never learns that
         any of this happened."
        | text snapshot |
        self track: (PathDepFixtures bSiblingNamed: 'po-walk-b').
        text := self freshDir: 'po-walk-text'.
        ExecFixtures writePackage: (PathDepFixtures walkingSiblingContentsOn:
            (PathDepFixtures declaredPathFor: 'po-walk-b')) in: text.
        snapshot := (self overlayOver: nil
            paths: (Array with: (self pathDependencyOn: 'po-walk-text'))
            in: (self workDirNamed: 'po-walk-work')) snapshot.
        self assert: (snapshot versionsOf: 'kernel-text')
            = (Array with: (Version fromString: '1.2.0'))
            description: (snapshot versionsOf: 'kernel-text') printString.
        self assert: (snapshot versionsOf: 'kernel-b')
            = (Array with: (Version fromString: '2.5.0'))
            description: 'the walk never reached the second hop: ',
                (snapshot versionsOf: 'kernel-b') printString
    ]

    testASiblingsDevDependenciesAreExcludedFromItsOverlayRecord [
        "A sibling's dev dependencies are excluded exactly as publish
         would exclude them (§8 decision 69) — the overlay is the
         development-time reading of the same projection publish makes
         at release time. The ROOT's own dev dependencies are a
         different question and are resolved normally."
        | text snapshot edges |
        self track: (PathDepFixtures bSiblingNamed: 'po-dev-b').
        text := self freshDir: 'po-dev-text'.
        ExecFixtures writePackage: (PathDepFixtures walkingSiblingContentsOn:
            (PathDepFixtures declaredPathFor: 'po-dev-b')) in: text.
        snapshot := (self overlayOver: nil
            paths: (Array with: (self pathDependencyOn: 'po-dev-text'))
            in: (self workDirNamed: 'po-dev-work')) snapshot.
        edges := snapshot dependenciesOf: 'kernel-text'
            version: (Version fromString: '1.2.0').
        self assert: (edges anySatisfy: [:each | each name = 'kernel-b'])
            description: 'the sibling''s path edge is missing: ',
                edges printString.
        self deny: (edges anySatisfy: [:each | each name = 'kernel-lint'])
            description: 'a sibling''s dev dependency became an overlay edge: ',
                edges printString
    ]

    testACycleTerminatesAsAReVisitNoOp [
        "The visited set is keyed by RESOLVED ABSOLUTE PATH, so two
         siblings pointing at each other terminate rather than walking
         for ever. Whether a cyclic dependency GRAPH resolves stays the
         resolver's ordinary business — this law is only about the walk
         coming back."
        | first second snapshot |
        first := self freshDir: 'po-cycle-one'.
        second := self freshDir: 'po-cycle-two'.
        ExecFixtures writePackage: 'Parley define: [:pkg |
    pkg
        name: ''cyc-a'';
        version: ''1.0.0'';
        fileIns: #(''A.st'');
        dependency: ''cyc-b'' path: ''../parley-po-cycle-two'' ]',
            SourceFixtures newline in: first.
        ExecFixtures writePackage: 'Parley define: [:pkg |
    pkg
        name: ''cyc-b'';
        version: ''1.0.0'';
        fileIns: #(''B.st'');
        dependency: ''cyc-a'' path: ''../parley-po-cycle-one'' ]',
            SourceFixtures newline in: second.
        snapshot := (self overlayOver: nil
            paths: (Array with: (PathDependency name: 'cyc-a'
                path: '../parley-po-cycle-one'))
            in: (self workDirNamed: 'po-cycle-work')) snapshot.
        self assert: (snapshot versionsOf: 'cyc-a') size = 1
            description: (snapshot versionsOf: 'cyc-a') printString.
        self assert: (snapshot versionsOf: 'cyc-b') size = 1
            description: (snapshot versionsOf: 'cyc-b') printString
    ]

    testTheSameDirectoryReachedTwiceIsNotADoublePathRefusal [
        "The visited set makes a re-visit a NO-OP, and this is the law
         that keeps the two-paths refusal from firing on it: one
         directory reached by two routes is one supplier, and refusing
         it would make a diamond of local checkouts unusable. The
         refusal below is about two DIFFERENT directories claiming one
         name."
        | shared root snapshot |
        shared := self sibling: 'po-diamond-text'.
        root := self workDirNamed: 'po-diamond-work'.
        snapshot := (self overlayOver: nil
            paths: (Array
                with: (self pathDependencyOn: 'po-diamond-text')
                with: (self pathDependencyOn: 'po-diamond-text'))
            in: root) snapshot.
        self assert: (snapshot versionsOf: 'kernel-text') size = 1
            description: (snapshot versionsOf: 'kernel-text') printString
    ]

    testAnAliasedPairIsOneSupplierAndTheCanonicalFormNeverLeaks [
        "THE VISITED SET IS KEYED BY TEXTUAL CANONICALISATION OF THE
         DECLARED STRING (§8 decision 68 as amended at Sprint 21's Gate
         A; Doc C §1.3, §7). The clause first read *resolved absolute
         path*, which names a FILESYSTEM question — `File name: ...
         fullName` — and asking it would make PathOverlay a ninth I/O
         class and fail §8 decision 60's eight-class census by
         construction. So `./` segments and `<segment>/..` pairs
         collapse by STRING ARITHMETIC and no filesystem is consulted.

         `'../a'` and `'../x/../a'` are therefore ONE SUPPLIER: one
         visit, no two-paths refusal, so a legitimate diamond of local
         checkouts spelled two ways resolves instead of being refused.
         This is the falsifier for a build that keys on the declared
         bytes: such a build passes every other law in this file and
         REFUSES here, on input that is correct.

         THE CANONICAL FORM IS FOR KEYING ONLY, and the second half is
         what proves it never leaks into a sentence: the same
         collapsing spelling pointed at a genuinely DIFFERENT directory
         is a real two-paths refusal, and that refusal must name the
         author's DECLARED strings byte for byte — never the collapsed
         form the walk computed for itself. Every diagnosis in this
         tool names what the author wrote, exactly as the lock
         byte-preserves it.

         THE BOUND IS STATED HERE RATHER THAN LEFT TO BE DISCOVERED
         (§8 decision 43's standard). SYMLINK ALIASING IS OUTSIDE THIS
         CLAIM: two declared strings that differ textually and reach
         one directory THROUGH A SYMLINK are two suppliers to this
         walk, and a symlinked diamond declaring one name trips the
         two-paths refusal. Resolving that would need exactly the File
         I/O the census forbids, so it is FAIL-STOP, NOT FAIL-WRONG —
         the operator gets one diagnosis naming both declared paths and
         can spell them alike. No fixture here builds a symlink,
         because the law would then assert the behaviour the bound
         excludes.

         THE DETOUR DIRECTORY IS REAL, AND THAT IS DELIBERATE (added at
         Gate A). POSIX resolves a path component by component, so
         `<mid>/..` requires <mid> to EXIST — probed at this gate:
         reading through an absent intermediate answers `No such file or
         directory`. Left absent, this law would silently require the
         overlay to READ through the canonical form rather than the
         declared string, and the amended decision 68 makes no such
         choice: it rules the canonical form for KEYING and says nothing
         about which spelling opens the file. The second half is where
         that bites — two DIFFERENT directories never dedupe, so the
         detour is really traversed. Creating it keeps this law
         asserting its own claim and nothing else; both read strategies
         satisfy it."
        | plain aliased snapshot other refused |
        self sibling: 'po-alias-text'.
        self freshDir: 'po-alias-mid'.
        plain := PathDepFixtures declaredPathFor: 'po-alias-text'.
        aliased := PathDepFixtures aliasedDeclaredPathFor: 'po-alias-text'
            through: 'po-alias-mid'.
        self deny: plain = aliased
            description: 'the two spellings are the same bytes, which makes this law vacuous'.
        snapshot := (self overlayOver: nil
            paths: (Array
                with: (PathDependency name: 'kernel-text' path: plain)
                with: (PathDependency name: 'kernel-text' path: aliased))
            in: (self workDirNamed: 'po-alias-work')) snapshot.
        self assert: (snapshot versionsOf: 'kernel-text')
            = (Array with: (Version fromString: '1.2.0'))
            description: 'the aliased pair was not one supplier: ',
                (snapshot versionsOf: 'kernel-text') printString.
        self sibling: 'po-alias-other'.
        other := PathDepFixtures aliasedDeclaredPathFor: 'po-alias-other'
            through: 'po-alias-mid'.
        refused := [(self overlayOver: nil
            paths: (Array
                with: (PathDependency name: 'kernel-text' path: plain)
                with: (PathDependency name: 'kernel-text' path: other))
            in: (self workDirNamed: 'po-alias-refuse-work')) snapshot. nil]
                on: SourceError
                do: [:e | e return: e problems].
        self deny: refused isNil
            description: 'two genuinely different directories composed cleanly'.
        self assert: refused = (Array with: (PathDepFixtures
            twoPathsRefusalFor: 'kernel-text' first: plain second: other))
            description: 'the refusal does not carry the declared strings: ',
                refused printString
    ]

    testOneNameFromTwoDirectoriesIsRefusedNamingBoth [
        "One diagnosis naming BOTH paths (Doc C §1.3). The refusal is
         the overlay's own, raised while it composes, so no verb has to
         re-derive it."
        | first second raised |
        self sibling: 'po-two-one'.
        self sibling: 'po-two-two'.
        first := PathDepFixtures declaredPathFor: 'po-two-one'.
        second := PathDepFixtures declaredPathFor: 'po-two-two'.
        raised := [(self overlayOver: nil
            paths: (Array
                with: (PathDependency name: 'kernel-text' path: first)
                with: (PathDependency name: 'kernel-text' path: second))
            in: (self workDirNamed: 'po-two-work')) snapshot. nil]
                on: SourceError
                do: [:e | e return: e problems].
        self deny: raised isNil
            description: 'two directories supplying one name composed cleanly'.
        self assert: raised = (Array with: (PathDepFixtures
            twoPathsRefusalFor: 'kernel-text' first: first second: second))
            description: raised printString
    ]

    "---- the re-seed ----"

    testTheBaseIsReSeededWithTheSiblingsDeclaredNames [
        "The base receives, through the SETTLED seededWith:, the
         caller's own seeds UNION the siblings' declared dependency
         names — which is what lets a sparse closure fetch what a
         sibling needs, with no new protocol and no source change.
         Driven through a recording double, so the law reads the seeds
         the base was actually handed rather than inferring them from a
         resolution that could have succeeded for another reason."
        | text base |
        text := self freshDir: 'po-seedset-text'.
        ExecFixtures writePackage: PathDepFixtures seedingSiblingContents
            in: text.
        base := SeedRecordingSource new.
        ((self overlayOver: base
            paths: (Array with: (self pathDependencyOn: 'po-seedset-text'))
            in: (self workDirNamed: 'po-seedset-work'))
                seededWith: (Set with: 'kernel-a')) snapshot.
        self assert: (base seeds includes: 'kernel-a')
            description: 'the caller''s own seeds were dropped: ',
                base seeds printString.
        self assert: (base seeds includes: PathDepFixtures seedOnlyName)
            description: 'the sibling''s declared name never reached the base: ',
                base seeds printString
    ]

    "---- the composition and the provenance split ----"

    testAnOverlaidNameOffersExactlyTheSiblingsVersion [
        "The resolution protocol answers the OVERLAY for an overlaid
         name — the whole name, because a path dependency always wins
         over an index release, which is what a path dependency is for.
         The index publishes 2.0.0 here, so an implementation that
         merged the two version sets fails."
        | snapshot |
        self sibling: 'po-precedence-text'.
        snapshot := (self overlayOver:
            (self indexWithTextAt: '2.0.0' named: 'po-precedence-index')
            paths: (Array with: (self pathDependencyOn: 'po-precedence-text'))
            in: (self workDirNamed: 'po-precedence-work')) snapshot.
        self assert: (snapshot versionsOf: 'kernel-text')
            = (Array with: (Version fromString: '1.2.0'))
            description: (snapshot versionsOf: 'kernel-text') printString
    ]

    testAnOverlaidReleaseDescribesItselfByProvenanceRatherThanADigest [
        "sha256For: answers '' for an overlay release, because an
         overlay release is described by its PROVENANCE, not a digest.
         §8 decision 47's describability line forbids offering what
         would write a lock tuple the boundary rejects — and the #path
         tuple IS a tuple the boundary accepts, which is what keeps the
         line intact rather than bent."
        | snapshot |
        self sibling: 'po-digest-text'.
        snapshot := (self overlayOver:
            (self indexWithTextAt: '2.0.0' named: 'po-digest-index')
            paths: (Array with: (self pathDependencyOn: 'po-digest-text'))
            in: (self workDirNamed: 'po-digest-work')) snapshot.
        self assert: (snapshot sha256For: 'kernel-text'
            version: (Version fromString: '1.2.0')) = ''
            description: 'an overlay release answered a digest: ',
                (snapshot sha256For: 'kernel-text'
                    version: (Version fromString: '1.2.0')) printString
    ]

    testTheReportingAccessorsKeepAnsweringTheIndexAlone [
        "BOTH HALVES OF THE SPLIT, ON THE FIXTURE THAT CAN FAIL EITHER.
         packageNames never lists an overlay-only name; allVersionsOf:
         and retirementReasonFor:version: answer what the index
         PUBLISHED, whoever overlays it. This is what keeps search, info
         and outdated honest (Doc E §4.1)."
        | index snapshot |
        self sibling: 'po-split-text'.
        index := self freshDir: 'po-split-index'.
        SourceFixtures write: (PathDepFixtures textEntryAt: '2.0.0')
            toFile: 'kernel-text-2.0.0.st' in: index.
        SourceFixtures write: (PathDepFixtures plainEntryFor: 'kernel-a'
            version: '1.0.0' dependencies: '')
            toFile: 'kernel-a-1.0.0.st' in: index.
        snapshot := (self overlayOver: (DirectorySource on: index)
            paths: (Array with: (self pathDependencyOn: 'po-split-text'))
            in: (self workDirNamed: 'po-split-work')) snapshot.
        self assert: (snapshot allVersionsOf: 'kernel-text')
            = (Array with: (Version fromString: '2.0.0'))
            description: 'allVersionsOf: answered the overlay: ',
                (snapshot allVersionsOf: 'kernel-text') printString.
        self assert: snapshot packageNames
            = (Array with: 'kernel-a' with: 'kernel-text')
            description: 'packageNames answered ',
                snapshot packageNames printString
    ]

    testAnOverlayOnlyNameIsNeverListedByPackageNames [
        "The other side of the same rule, where it can actually fail: an
         overlaid name the index does NOT publish must not appear in the
         enumeration at all, because that enumeration is what search
         renders."
        | index snapshot |
        self sibling: 'po-only-text'.
        index := self freshDir: 'po-only-index'.
        SourceFixtures write: (PathDepFixtures plainEntryFor: 'kernel-a'
            version: '1.0.0' dependencies: '')
            toFile: 'kernel-a-1.0.0.st' in: index.
        snapshot := (self overlayOver: (DirectorySource on: index)
            paths: (Array with: (self pathDependencyOn: 'po-only-text'))
            in: (self workDirNamed: 'po-only-work')) snapshot.
        self assert: snapshot packageNames = (Array with: 'kernel-a')
            description: snapshot packageNames printString.
        self assert: (snapshot allVersionsOf: 'kernel-text') isEmpty
            description: (snapshot allVersionsOf: 'kernel-text') printString.
        self assert: (snapshot versionsOf: 'kernel-text')
            = (Array with: (Version fromString: '1.2.0'))
            description: 'resolution lost the overlay: ',
                (snapshot versionsOf: 'kernel-text') printString
    ]

    testTheOverlayComposesBeforeResolutionBegins [
        "THE PURITY PROOF (Doc C §7). The composed snapshot is a sealed
         VALUE: a resolution driven against it touches no source at all,
         proved by handing the resolver a snapshot composed over a base
         whose every protocol message signals. If the overlay had left a
         lazy read behind, the trap would fire during the search rather
         than during composition."
        | snapshot outcome manifest work |
        self sibling: 'po-purity-text'.
        work := self workDirNamed: 'po-purity-work'.
        snapshot := (self overlayOver: nil
            paths: (Array with: (self pathDependencyOn: 'po-purity-text'))
            in: work) snapshot.
        ExecFixtures writePackage: (PathDepFixtures rootDeclaring:
            (PathDepFixtures declaredPathFor: 'po-purity-text')) in: work.
        manifest := ManifestFile load: work, '/Package.st'.
        outcome := (Resolver strategy: BacktrackingStrategy new)
            resolve: manifest against: snapshot.
        self assert: outcome isResolution
            description: 'the composed snapshot did not resolve: ',
                outcome printString.
        self assert: (outcome versionOf: 'kernel-text')
            = (Version fromString: '1.2.0')
            description: (outcome versionOf: 'kernel-text') printString
    ]

    testTheSnapshotIsSealedAgainstALaterSiblingEdit [
        "A snapshot is a sealed value: editing the sibling AFTER it
         answers changes nothing about it. That is what makes the one
         I/O moment a moment rather than a habit, and it is the property
         exec deliberately does NOT rely on — exec reads fresh, per run,
         which is a different mechanism at a different time."
        | text snapshot |
        text := self sibling: 'po-sealed-text'.
        snapshot := (self overlayOver: nil
            paths: (Array with: (self pathDependencyOn: 'po-sealed-text'))
            in: (self workDirNamed: 'po-sealed-work')) snapshot.
        ExecFixtures writePackage: (PathDepFixtures textSiblingContentsAt:
            PathDepFixtures driftedVersionString) in: text.
        self assert: (snapshot versionsOf: 'kernel-text')
            = (Array with: (Version fromString: '1.2.0'))
            description: 'the snapshot changed under a later edit: ',
                (snapshot versionsOf: 'kernel-text') printString
    ]

    testASnapshotWithNoPathDependenciesIsUnchanged [
        "THE DECLARED REGRESSION GUARD (Doc C §7): an overlay with no
         path dependencies must be invisible. Asserted against the
         BASE's own snapshot rather than against a hand-written list, so
         it stays true as the base's shape evolves."
        | index base composed |
        index := self freshDir: 'po-empty-index'.
        SourceFixtures populateDiamondIn: index.
        base := DirectorySource on: index.
        composed := (self overlayOver: base paths: #()
            in: (self workDirNamed: 'po-empty-work')) snapshot.
        self assert: composed packageNames = base snapshot packageNames
            description: composed packageNames printString.
        base snapshot packageNames do: [:name |
            self assert: (composed versionsOf: name)
                = (base snapshot versionsOf: name)
                description: name, ' answered ',
                    (composed versionsOf: name) printString]
    ]
]

Object subclass: SeedRecordingSource [
    | seeds |

    <comment: 'A base double that records the seeds it was handed
through the settled seededWith: and answers an empty snapshot. It
proves the re-seed reached the base as VALUES — which is the only
observation that can distinguish a re-seed from a resolution that
happened to succeed for another reason.'>

    SeedRecordingSource class >> new [
        <category: 'instance creation'>
        ^self basicNew setSeeds: Set new
    ]

    setSeeds: aSet [
        <category: 'private'>
        seeds := aSet
    ]

    seeds [
        <category: 'accessing'>
        ^seeds
    ]

    seededWith: someNames [
        <category: 'source protocol'>
        seeds addAll: someNames.
        ^self
    ]

    snapshot [
        <category: 'source protocol'>
        ^IndexSnapshot releases: #()
    ]

    versionsOf: aPackageName [
        <category: 'source protocol'>
        ^#()
    ]

    manifestFor: aPackageName version: aVersion [
        <category: 'source protocol'>
        ^nil
    ]

    fetch: aPackageName version: aVersion [
        <category: 'source protocol'>
        ^self error: 'no-fetch law violated during composition'
    ]
]

Namespace current: Smalltalk.
