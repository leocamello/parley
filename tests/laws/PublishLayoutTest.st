"Parley Sprint 15 — the publish layouts, the listing, and atomicity
 (issue #17; Doc F §8, Doc B §5.6, Doc E §4.2, §8 decision 53).

 Sprint 14 shipped the sparse-index client; this is the producer, and
 the gap it closes is the difference between a package manager and an
 ecosystem. publish <dir> writes the flat layout a DirectorySource
 scans; nothing wrote the per-package layout SparseIndexSource reads.

 THE LAYOUT IS STATED, NEVER INFERRED (§8 decision 53). Reading the
 destination to guess would make an empty directory — a brand-new
 index, the commonest case — ambiguous, and would turn a mistyped path
 into a successful publish into the wrong shape. So --layout
 <flat|sparse>, flat by default, an unrecognized value a usage error at
 exit 2 and never a fallback. The rows live in
 CommandLine class >> publishLayouts, a DECLARATION CONSUMED TWICE
 exactly as sourceFlags is: the wiring is built from it and the drift
 law below drives a real publish through every row, so a layout can
 never be lawful and unreachable — the defect GitIndexSource shipped
 with for a whole sprint.

 THE ORDERING TRAP IS THE POINT OF TWO SEPARATE LAWS. Lexical order is
 the obvious implementation and the wrong one: '1.10.0' < '1.9.0' as
 strings. testVersionsOrderSemantically fails on it, and
 testPublicationOrderDoesNotChangeTheBytes fails on a renderer that
 appends instead of sorting. Both assert on FILE BYTES, never on parsed
 values, because a listing is an artifact the client reads byte-wise.

 THE PRODUCER MUST NOT BE ABLE TO MANUFACTURE THE STATE ITS OWN CLIENT
 DIAGNOSES (Doc F §8.3). §7.5 already rules that a listing naming an
 entry the index does not hold is an index defect — one SourceError
 naming both files. So the entry and the archive land BEFORE the
 listing, every refusal restores the destination, and the proof is not
 a restatement of what this file thinks was written: the published tree
 is scanned by the settled SparseIndexSource, which is the oracle.

 WHAT ATOMICITY COVERS, STATED PRECISELY. Doc F §8.3 scopes the claim
 to the entry, the archive and the listing — the decision-49 shape,
 which was narrowed at the Sprint 13 close-out for exactly this reason.
 Doc F §1 step 4 rules, settled and pinned by a settled law, that a
 failed BUILD leaves the destination-confined stage in place for
 inspection: fail-stop never cleans up behind an error. The stage is
 not published state — the client addresses <base>/<name>/... by
 constructed URL and can never see it, the next publish sweeps it, and
 removing it would contradict a settled law this sprint may not touch.
 So the build-failure ground of the byte-identity laws compares the
 tree WITHOUT the stage, and asserts separately that no package
 directory, entry, archive or listing appeared. Every other refusal
 ground compares the whole tree with no exception at all.

 DECLARED PASSES IN RED (issue #17):
   testTheFlatPublishIsByteIdenticalToTheSettledOutput — a
     SETTLED-BEHAVIOUR GUARD, not a new claim: the pre-sprint CLI
     already writes exactly this, and that is precisely what makes the
     law worth having, because it is what keeps this sprint additive.
     Said plainly rather than dressed up as a behaviour law.
 Every other law here fails against the pre-sprint tree: the table does
 not exist, --layout is not a flag, the Publisher has no sparse layout
 and no listing, and the boundary table has four rows.
 (testAnUnrecognizedLayoutIsAUsageErrorAndNeverAFallback passed in red
 as first written — every --layout invocation is exit 2 on a tree where
 --layout is not a flag — and was amended at Gate A to assert the
 recognized half beside the unrecognized one, which is what makes its
 exit 2 about the VALUE. Operator amendment, Sprint 15 Gate A.)

 The laws run the real toolchain (gst-package) through ProcessRunner —
 the one process seam — and the sparse scan runs real curl against
 file:// trees. No network is contacted, ever. Star bytes are NOT
 reproducible on this toolchain (probed at RED: gst-package shells out
 to zip, which records mtimes), so no digest is ever pinned as a
 literal and the two entries S1 compares are compared with their own
 runtime digests substituted out. Every fixture path is under tmp/,
 unique per test, removed recursively in tearDown."

Namespace current: Parley.

TestCase subclass: PublishLayoutTest [
    | fixtureDirs |

    <comment: 'Laws for the publishLayouts table and its drift law, the
sparse write, the listing read-modify-write with semantic ordering, the
fifth deserialization boundary, and the atomicity that keeps the
producer from creating the index defect its own client reports.'>

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

    workDir: aLabel version: aVersionString [
        ^self track: (PublishLayoutFixtures workDirNamed: aLabel
            version: aVersionString)
    ]

    contentsOf: aPath [
        ^(File name: aPath) contents
    ]

    exists: aPath [
        ^(File name: aPath) exists
    ]

    "---- running the shipped wiring ----"

    runIn: aWorkDir argv: anArgvArray runner: aRunner [
        ^(CommandLine in: aWorkDir runner: aRunner) run: anArgvArray
    ]

    publishFrom: aWorkDir to: aDestDir layout: aLayoutName [
        ^self runIn: aWorkDir
            argv: (PublishLayoutFixtures publishArgvTo: aDestDir
                layout: aLayoutName)
            runner: ProcessRunner new
    ]

    sparsePublish: aVersionString from: aLabel to: aDestDir [
        "One successful sparse publish of probe-pkg at aVersionString,
         asserted successful so a later assertion cannot pass on a
         destination nothing was ever written to."
        | work result |
        work := self workDir: aLabel version: aVersionString.
        result := self publishFrom: work to: aDestDir layout: 'sparse'.
        self assert: result exitCode = 0
            description: 'the sparse publish of ', aVersionString,
                ' failed: ', result lines printString.
        ^result
    ]

    listingIn: aDestDir [
        ^self contentsOf: (PublishLayoutFixtures sparseListingPathIn: aDestDir)
    ]

    "---- the declared table, and its drift law ----"

    testTheLayoutTableDeclaresExactlyFlatAndSparse [
        "Two rows, flat first because it is the default. Asserted
         against the table itself; the drift law below is what forces
         each row to be reachable."
        | names |
        names := CommandLine publishLayouts collect: [:row | row at: 1].
        self assert: names = #('flat' 'sparse')
            description: 'publishLayouts declares ', names printString
    ]

    testEveryDeclaredLayoutIsReachableThroughTheFlag [
        "THE DRIFT LAW: the table is ITERATED and every row is driven
         through the shipped flag into a real publish. A layout that is
         declared and unreachable fails here — the GitIndexSource
         defect, which sat lawful and unbuildable for a whole sprint
         because nothing constructed it. The deny: guard is not
         ceremony: an empty table would make the iteration vacuous and
         the law would pass while proving nothing."
        | rows unreachable |
        rows := CommandLine publishLayouts.
        self deny: rows isEmpty
            description: 'publishLayouts is empty - the drift law would pass vacuously'.
        unreachable := self unreachableLayoutsIn: rows labelled: 'reach'.
        self assert: unreachable isEmpty
            description: unreachable printString,
                ' are declared publish layouts that no publish can reach'
    ]

    testTheDriftLawDetectsAnUnreachableLayout [
        "The same check against a table carrying a row the wiring does
         not know. If this passes, the law above is about nothing —
         Sprint 8's lesson, that a drift law which has never failed on
         purpose is a law about nothing."
        | mutant unreachable |
        mutant := CommandLine publishLayouts,
            (Array with: (Array with: 'bogus' with: #())).
        unreachable := self unreachableLayoutsIn: mutant labelled: 'drift'.
        self assert: (unreachable includes: 'bogus')
            description: 'the drift law does not detect an unreachable layout - it proves nothing'
    ]

    unreachableLayoutsIn: someRows labelled: aLabel [
        "Every declared layout name that a real publish through the
         --layout flag cannot reach, each into its own fresh
         destination."
        | unreachable index |
        unreachable := OrderedCollection new.
        index := 0.
        someRows do: [:row |
            | dest work result |
            index := index + 1.
            dest := self freshDir: 'layout-', aLabel, '-dest-', index printString.
            work := self workDir: 'layout-', aLabel, '-work-', index printString
                version: '1.0.0'.
            result := self publishFrom: work to: dest layout: (row at: 1).
            result exitCode = 0 ifFalse: [unreachable add: (row at: 1)]].
        ^unreachable asArray
    ]

    testAnUnrecognizedLayoutIsAUsageErrorAndNeverAFallback [
        "Exit 2, the settled usage lines, and nothing written: an
         unrecognized value is a usage error, never a silent fallback
         to flat, because a fallback would publish into the wrong shape
         and call it success.

         THE RECOGNIZED HALF IS ASSERTED BESIDE IT, in the same argv
         shape and read from the same table. Without it this law passes
         on the PRE-SPRINT tree, where --layout is not a flag at all
         and every --layout invocation is exit 2 for a reason that has
         nothing to do with the value being unrecognized — passing for
         the wrong reason, and so unable to demonstrate red->green.
         (Operator amendment, Sprint 15 Gate A.)"
        | work dest result acceptedWork acceptedDest |
        work := self workDir: 'layout-bad-work' version: '1.0.0'.
        dest := self freshDir: 'layout-bad-dest'.
        result := self runIn: work
            argv: (PublishLayoutFixtures publishArgvTo: dest
                layout: 'nonsense')
            runner: RecordingRunner new.
        self assert: result exitCode = 2.
        self assert: (PublishFixtures fileNamesIn: dest) = #()
            description: 'an unrecognized layout wrote into the destination'.
        acceptedWork := self workDir: 'layout-good-work' version: '1.0.0'.
        acceptedDest := self freshDir: 'layout-good-dest'.
        self assert: (self publishFrom: acceptedWork to: acceptedDest
            layout: (CommandLine publishLayouts first at: 1)) exitCode = 0
            description: 'a DECLARED layout is refused in the very argv shape the unrecognized one is refused in - the exit 2 above proves nothing about the value'
    ]

    "---- what a sparse publish writes (Doc F §8.2) ----"

    testASparsePublishWritesTheThreeArtifactsTheClientFetches [
        | dest names |
        dest := self freshDir: 'sparse-write-dest'.
        self sparsePublish: '1.0.0' from: 'sparse-write-work' to: dest.
        self assert: (PublishFixtures fileNamesIn: dest)
            = (Array with: PublishLayoutFixtures packageName)
            description: 'the base holds something other than the package directory'.
        names := PublishFixtures fileNamesIn:
            (PublishLayoutFixtures packageDirIn: dest).
        self assert: names
            = (PublishLayoutFixtures sparsePackageDirNamesAtVersion: '1.0.0')
            description: 'the package directory holds ', names printString
    ]

    testTheSparseEntryIsTheSettledRenderingCarryingItsOwnDigest [
        "Only the LOCATION changed: the entry bytes are the settled
         Doc B §5.2 rendering, and the digest is the one the landed
         archive really hashes to — never a pinned literal, because
         toolchain-built star bytes vary."
        | dest entry archiveBytes digest |
        dest := self freshDir: 'sparse-entry-dest'.
        self sparsePublish: '1.0.0' from: 'sparse-entry-work' to: dest.
        archiveBytes := self contentsOf: (PublishLayoutFixtures
            sparseArchivePathIn: dest version: '1.0.0').
        digest := Sha256 hexDigestOf: archiveBytes.
        entry := self contentsOf: (PublishLayoutFixtures
            sparseEntryPathIn: dest version: '1.0.0').
        self assert: entry = (PublishLayoutFixtures
            entryAtVersion: '1.0.0' digest: digest)
    ]

    testTheSparseAndFlatEntriesDifferOnlyInTheirRuntimeDigest [
        "S1's claim, made mechanical on a toolchain whose archives are
         not byte-reproducible: publish the same manifest into both
         layouts and compare the entry bytes with each publish's own
         digest substituted out. What remains must be identical,
         because only the location changed."
        | flatDest sparseDest flat sparse flatDigest sparseDigest |
        flatDest := self freshDir: 'both-flat-dest'.
        sparseDest := self freshDir: 'both-sparse-dest'.
        self assert: (self publishFrom:
            (self workDir: 'both-flat-work' version: '1.0.0')
            to: flatDest layout: 'flat') exitCode = 0.
        self sparsePublish: '1.0.0' from: 'both-sparse-work' to: sparseDest.
        flatDigest := Sha256 hexDigestOf: (self contentsOf:
            (PublishLayoutFixtures flatArchivePathIn: flatDest
                version: '1.0.0')).
        sparseDigest := Sha256 hexDigestOf: (self contentsOf:
            (PublishLayoutFixtures sparseArchivePathIn: sparseDest
                version: '1.0.0')).
        flat := (self contentsOf: (PublishLayoutFixtures
            flatEntryPathIn: flatDest version: '1.0.0'))
                copyReplaceAll: flatDigest with: 'DIGEST'.
        sparse := (self contentsOf: (PublishLayoutFixtures
            sparseEntryPathIn: sparseDest version: '1.0.0'))
                copyReplaceAll: sparseDigest with: 'DIGEST'.
        self assert: sparse = flat
            description: 'the sparse entry is not the flat entry moved'
    ]

    testTheFlatPublishIsByteIdenticalToTheSettledOutput [
        "DECLARED PASS IN RED (issue #17) — a settled-behaviour guard,
         not a new claim. The pre-sprint CLI already writes exactly
         this, which is what makes the guard worth having: it is what
         keeps this sprint additive, and it is the law that fails if
         the layout work reaches into the default path."
        | dest |
        dest := self freshDir: 'flat-guard-dest'.
        self assert: (self runIn:
            (self workDir: 'flat-guard-work' version: '1.0.0')
            argv: (PublishLayoutFixtures publishArgvTo: dest)
            runner: ProcessRunner new) exitCode = 0.
        self assert: (PublishFixtures fileNamesIn: dest)
            = (Array
                with: (PublishLayoutFixtures entryFileNameAtVersion: '1.0.0')
                with: (PublishLayoutFixtures archiveFileNameAtVersion: '1.0.0'))
            description: 'the flat layout is no longer the settled flat layout'
    ]

    "---- the listing (Doc B §5.6 written, not only read) ----"

    testAFirstSparsePublishCreatesTheListingTheClientReads [
        "The bytes are the CLIENT'S oracle, consumed unchanged from
         Sprint 14: the producer writes exactly what the consumer was
         built to read, asserted from both ends of the same fixture."
        | dest |
        dest := self freshDir: 'listing-first-dest'.
        self sparsePublish: '1.0.0' from: 'listing-first-work' to: dest.
        self assert: (self listingIn: dest)
            = (PublishLayoutFixtures listingFor: #('1.0.0'))
    ]

    testASecondPublishAppendsToTheListingAndReRendersIt [
        | dest |
        dest := self freshDir: 'listing-second-dest'.
        self sparsePublish: '1.0.0' from: 'listing-second-work-a' to: dest.
        self sparsePublish: '1.1.0' from: 'listing-second-work-b' to: dest.
        self assert: (self listingIn: dest)
            = (PublishLayoutFixtures listingFor: #('1.0.0' '1.1.0')).
        self assert: (self exists: (PublishLayoutFixtures
            sparseEntryPathIn: dest version: '1.0.0'))
            description: 'the first release was lost'.
        self assert: (self exists: (PublishLayoutFixtures
            sparseEntryPathIn: dest version: '1.1.0'))
            description: 'the second release did not land'
    ]

    testVersionsOrderSemanticallyAndNotLexically [
        "'1.10.0' sorts BEFORE '1.9.0' as strings. Sorting the strings
         is the obvious implementation and the wrong one; this law
         fails on it, and it asserts on the file's bytes rather than on
         a parsed collection, because the listing is an artifact the
         client reads byte-wise."
        | dest bytes |
        dest := self freshDir: 'listing-order-dest'.
        self sparsePublish: '1.9.0' from: 'listing-order-work-a' to: dest.
        self sparsePublish: '1.10.0' from: 'listing-order-work-b' to: dest.
        bytes := self listingIn: dest.
        self assert: bytes = (PublishLayoutFixtures listingFor: #('1.9.0' '1.10.0'))
            description: 'the listing renders ', bytes printString
    ]

    testPublicationOrderDoesNotChangeTheListingBytes [
        "Byte-stability is a law here as everywhere: the same set of
         versions, published in either order, renders identically. A
         renderer that appended rather than sorted passes the ordering
         law above by luck and fails this one."
        | ascending descending |
        ascending := self freshDir: 'listing-stable-asc'.
        descending := self freshDir: 'listing-stable-desc'.
        self sparsePublish: '1.9.0' from: 'listing-stable-work-a' to: ascending.
        self sparsePublish: '1.10.0' from: 'listing-stable-work-b' to: ascending.
        self sparsePublish: '1.10.0' from: 'listing-stable-work-c' to: descending.
        self sparsePublish: '1.9.0' from: 'listing-stable-work-d' to: descending.
        self assert: (self listingIn: ascending) = (self listingIn: descending)
            description: 'the listing bytes depend on publication order'
    ]

    "---- the fifth deserialization boundary (Doc E §4.2) ----"

    testTheFifthBoundaryRowIsDeclaredAndNamesItsFile [
        "Reading the listing makes Publisher a sender of
         IndexEntryReader readFrom:, so it is a boundary by
         construction and the drift law in BoundaryCoverageTest forces
         the row the moment the send ships. A row that cannot name the
         operator's file is not a boundary; it is a reader."
        | rows publisherRows |
        rows := CommandLine deserializationBoundaries.
        "Re-pinned in Sprint 19's GREEN — Configuration is the sixth row
         (Doc B §5.7). This law's own claim, that the Publisher row
         exists once and names its file, is unchanged."
        self assert: (LockSchemaFixtures namesOfBoundaryClassesIn: rows)
            = LockSchemaFixtures boundaryClassNames.
        publisherRows := rows select: [:row |
            (row at: 1) name asString = 'Publisher'].
        self assert: publisherRows size = 1.
        self deny: (publisherRows first at: 2) isEmpty
            description: 'the Publisher row does not name the file it reads'
    ]

    testEveryMalformedListingGroundIsOneProblemAndNothingIsWritten [
        "The fifth boundary diagnosing its own input, ground by
         ground, with the destination byte-identical after each: the
         listing is read BEFORE anything is staged, so a malformed one
         costs the author a message and nothing else. The grounds are
         ITERATED from the fixture table, and the guard below is what
         stops an empty table from passing the law vacuously."
        | grounds index |
        grounds := PublishLayoutFixtures malformedListingTexts.
        self deny: grounds isEmpty
            description: 'no malformed-listing grounds - the law would pass vacuously'.
        index := 0.
        grounds do: [:ground |
            | dest work runner before result |
            index := index + 1.
            dest := self freshDir: 'listing-bad-dest-', index printString.
            work := self workDir: 'listing-bad-work-', index printString
                version: '1.0.0'.
            PublishLayoutFixtures writeListing: (ground at: 1) in: dest.
            before := PublishLayoutFixtures treeSnapshotOf: dest.
            self deny: before isEmpty
                description: 'the fixture destination is empty - the comparison would be vacuous'.
            runner := RecordingRunner new.
            result := self runIn: work
                argv: (PublishLayoutFixtures publishArgvTo: dest
                    layout: 'sparse')
                runner: runner.
            self assert: result exitCode = 1
                description: 'ground ', index printString,
                    ' answered exit ', result exitCode printString.
            self assert: result lines
                = (Array with: ((ground at: 2) value: dest))
                description: 'ground ', index printString,
                    ' answered ', result lines printString.
            self assert: runner commands = #()
                description: 'ground ', index printString,
                    ' spawned a process before diagnosing the listing'.
            self assert: (PublishLayoutFixtures treeSnapshotOf: dest) = before
                description: 'ground ', index printString,
                    ' changed the destination']
    ]

    "---- atomicity: the listing is written last (Doc F §8.3) ----"

    testRepublishingRefusesWithTheSettledWordingAndLeavesTheListing [
        "Releases are immutable in both layouts. The refusal is the
         settled sentence naming the entry the sparse layout holds, no
         process is spawned, and versions.st is untouched — a refusal
         that rewrote the listing would be a refusal that changed the
         index."
        | dest work runner before result |
        dest := self freshDir: 'republish-dest'.
        self sparsePublish: '1.0.0' from: 'republish-work-a' to: dest.
        before := PublishLayoutFixtures treeSnapshotOf: dest.
        self deny: before isEmpty.
        work := self workDir: 'republish-work-b' version: '1.0.0'.
        runner := RecordingRunner new.
        result := self runIn: work
            argv: (PublishLayoutFixtures publishArgvTo: dest layout: 'sparse')
            runner: runner.
        self assert: result exitCode = 1.
        self assert: result lines = (Array with: (PublishLayoutFixtures
            refusalProblemAtVersion: '1.0.0' in: dest)).
        self assert: runner commands = #()
            description: 'the refusal spawned a process'.
        self assert: (PublishLayoutFixtures treeSnapshotOf: dest) = before
            description: 'the refusal changed the destination'
    ]

    testAFailedBuildLandsNoPackageDirectoryAtAll [
        "The build-failure ground, stated exactly. Doc F §1 step 4 is
         settled and pinned by a settled law: the stage stays for
         inspection, because fail-stop never cleans up behind an error.
         Doc F §8.3 scopes atomicity to the entry, the archive and the
         listing — so what this law demands is that NONE of the three
         appeared, and that the destination is otherwise untouched. The
         stage is invisible to the client, which addresses artifacts by
         constructed URL, and the next publish sweeps it."
        | dest work runner before result |
        dest := self freshDir: 'failbuild-dest'.
        work := self workDir: 'failbuild-work' version: '1.0.0'.
        before := PublishLayoutFixtures treeSnapshotOf: dest.
        runner := RecordingRunner answering: 2.
        result := self runIn: work
            argv: (PublishLayoutFixtures publishArgvTo: dest layout: 'sparse')
            runner: runner.
        self assert: result exitCode = 1.
        self deny: runner commands isEmpty
            description: 'no build was attempted - the law proves nothing'.
        self deny: (self exists: (PublishLayoutFixtures packageDirIn: dest))
            description: 'a failed build created the package directory'.
        self assert: (PublishLayoutFixtures treeSnapshotOf: dest
            without: PublishLayoutFixtures stageDirName) = before
            description: 'a failed build left published state behind'
    ]

    testASparseTreeBuiltByAnySequenceScansCleanThroughTheSettledClient [
        "THE ORACLE IS THE CLIENT, not a restatement of what this file
         believes was written. Doc F §7.5 rules that a listing naming
         an entry the index does not hold is an index defect — Sprint
         14's S8, one SourceError naming both files — and this sprint
         exists so the producer cannot manufacture it. A tree built by
         successful publishes AND refusals is scanned by the settled
         SparseIndexSource over file://, and snapshot must answer
         cleanly."
        | dest cache badWork failWork snapshot |
        dest := self freshDir: 'scan-clean-dest'.
        cache := self freshDir: 'scan-clean-cache'.
        self sparsePublish: '1.0.0' from: 'scan-clean-work-a' to: dest.
        self sparsePublish: '1.1.0' from: 'scan-clean-work-b' to: dest.
        badWork := self workDir: 'scan-clean-work-c' version: '1.1.0'.
        self assert: (self publishFrom: badWork to: dest layout: 'sparse')
            exitCode = 1
            description: 'the republish was not refused'.

        "A FAILED BUILD is the one refusal ground that leaves a residue
         in the destination — Doc F §1 step 4 keeps the stage for
         inspection, because fail-stop never cleans up behind an error.
         This file's header ARGUES that the client cannot see it, since
         SparseIndexSource addresses <base>/<name>/... by constructed
         URL and never enumerates the base. Arguing is not proving, and
         the whole doctrine here is that the client is the oracle
         rather than a restatement of what this file believes. So the
         ground is included in the sequence: it is what would fail if
         the stage were ever published state, and it is the mechanical
         warrant for leaving the stage where the settled law puts it.
         (Operator amendment, Sprint 15 Gate A.)"
        failWork := self workDir: 'scan-clean-work-d' version: '1.2.0'.
        self assert: (self runIn: failWork
            argv: (PublishLayoutFixtures publishArgvTo: dest layout: 'sparse')
            runner: (RecordingRunner answering: 2)) exitCode = 1
            description: 'the failed build was not refused'.
        self assert: (self exists: dest, '/',
            PublishLayoutFixtures stageDirName)
            description: 'the failed build left no stage behind - the ground proves nothing'.

        snapshot := ((SparseIndexSource
            base: (SparseIndexFixtures baseUrlFor: dest)
            cache: cache
            runner: ProcessRunner new)
                seededWith: (Set with: PublishLayoutFixtures packageName))
                    snapshot.
        self assert: (snapshot versionsOf: PublishLayoutFixtures packageName)
            size = 2
            description: 'the client does not see both published releases'
    ]
]

Namespace current: Smalltalk.
