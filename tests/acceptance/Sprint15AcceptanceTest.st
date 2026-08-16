"Parley Sprint 15 — acceptance scenarios S1-S16 (issue #17).

 THE LAST v1.0 SPRINT, and the gap it closes is the difference between
 a package manager and an ecosystem. Sprint 14 shipped the sparse-index
 CLIENT: a project resolves, locks, installs and executes against an
 index it never downloads in full. What it could not do is PUT a
 package there — publish <dir> writes the flat layout a DirectorySource
 scans, and nothing wrote the per-package layout SparseIndexSource
 reads. S1-S11 and S16 close that; S12-S15 are the rest of release
 hardening.

 ONE SENTENCE GOVERNS THE WHOLE SPRINT (Doc F §7.5, §8.3): a listing
 naming an entry the index does not hold is an INDEX DEFECT, and
 Sprint 14's own S8 diagnoses it. The producer must be unable to
 manufacture the state its own client reports. That is why the entry
 and the archive land before the listing, why every refusal restores
 the destination, and why S8 proves it by scanning the published tree
 with the SETTLED CLIENT rather than with a restatement of what this
 file believes was written.

 EVERY SCENARIO DRIVES THE SHIPPED WIRING. Publishing runs through
 CommandLine — the flag grammar, the composition root and the
 diagnosis boundary — because the layout flag is only real if the
 operator can type it. S12 goes one further and spawns the shipped
 binary itself, which is the only way to prove a version answer needs
 no working directory.

 WHAT S7'S BYTE-IDENTITY MEANS, EXACTLY. Doc F §8.3 scopes atomicity to
 the entry, the archive and the listing (the decision-49 shape,
 narrowed at the Sprint 13 close-out for this precise reason), and
 Doc F §1 step 4 rules — settled, and pinned byte-for-byte by a settled
 law this sprint may not touch — that a failed BUILD leaves the
 destination-confined stage in place for inspection, because fail-stop
 never cleans up behind an error. The stage is not published state: the
 client addresses artifacts by constructed URL and can never see it,
 and the next publish sweeps it. So S7 compares the WHOLE destination
 tree, file names and contents, recursively, for every refusal ground —
 and for the build-failure ground compares the tree without the stage
 while separately requiring that no package directory, entry, archive
 or listing appeared. This reading is declared in the RED report; where
 the issue and the docs disagree, the docs win.

 DECLARED PASSES IN RED (issue #17):
   testS9_TheDefaultLayoutIsFlatAndByteIdenticalToWhatItAlwaysWas — a
     SETTLED-BEHAVIOUR GUARD, not a new claim. The pre-sprint CLI
     already writes exactly this. That is what makes it worth having:
     it is the law that keeps this sprint additive and fails the moment
     the layout work reaches into the default path. Said plainly.
   testS15_TheReadmeDescribesTheToolThatExists FAILS in red (the
     README documents six of the ten verbs), so it is NOT in this list
     — named here only because its companion law in
     ReleaseHardeningTest, the exec consumer constraint, does pass.
 Every other scenario fails against the pre-sprint tree.

 COST, DECLARED: S1-S11 and S16 run the real toolchain (gst-package)
 through ProcessRunner — the one process seam — and S8 and S16 spawn
 real curl against file:// trees under tmp/. S12 spawns the shipped
 binary. No scenario contacts a network and none runs git. Star bytes
 are not reproducible on this toolchain (probed at RED: gst-package
 shells out to zip, which records mtimes), so no digest is pinned as a
 literal — the settled Doc E §5 digest discipline.

 Every fixture path is under tmp/, unique per test, removed recursively
 in tearDown; the developer image is never mutated."

Namespace current: Parley.

TestCase subclass: Sprint15AcceptanceTest [
    | fixtureDirs |

    <comment: 'The Sprint 15 acceptance scenarios: publishing into a
sparse index with --layout, the listing read-modify-write with semantic
ordering, atomicity proved through the settled client, parley --version,
the README drift law, the decision-52 narrowing, and the offline
end-to-end loop that closes v1.0.'>

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
        | result |
        result := self publishFrom: (self workDir: aLabel version: aVersionString)
            to: aDestDir layout: 'sparse'.
        self assert: result exitCode = 0
            description: 'the sparse publish of ', aVersionString,
                ' failed: ', result lines printString.
        ^result
    ]

    listingIn: aDestDir [
        ^self contentsOf: (PublishLayoutFixtures sparseListingPathIn: aDestDir)
    ]

    digestOfArchiveIn: aDestDir version: aVersionString [
        ^Sha256 hexDigestOf: (self contentsOf: (PublishLayoutFixtures
            sparseArchivePathIn: aDestDir version: aVersionString))
    ]

    "---- S1: a sparse publish writes the layout the client reads ----"

    testS1_ASparsePublishWritesTheLayoutTheClientReads [
        "The three artifacts Doc F §7.1 says a client fetches, in the
         one place it fetches them from — and the entry bytes are the
         settled flat publish's, because only the LOCATION changed.
         Toolchain-built archives are not byte-reproducible, so the two
         entries are compared with each publish's own runtime digest
         substituted out rather than by hoping two zip files agree."
        | dest flatDest result flat sparse |
        dest := self freshDir: 's15-s1-dest'.
        flatDest := self freshDir: 's15-s1-flat-dest'.
        result := self sparsePublish: '1.0.0' from: 's15-s1-work' to: dest.
        self assert: result exitCode = 0.
        self assert: (PublishFixtures fileNamesIn:
            (PublishLayoutFixtures packageDirIn: dest))
                = (PublishLayoutFixtures sparsePackageDirNamesAtVersion: '1.0.0')
            description: 'the package directory does not hold the three artifacts'.
        self assert: (self publishFrom:
            (self workDir: 's15-s1-flat-work' version: '1.0.0')
            to: flatDest layout: 'flat') exitCode = 0.
        sparse := (self contentsOf: (PublishLayoutFixtures
            sparseEntryPathIn: dest version: '1.0.0'))
                copyReplaceAll: (self digestOfArchiveIn: dest version: '1.0.0')
                with: 'DIGEST'.
        flat := (self contentsOf: (PublishLayoutFixtures
            flatEntryPathIn: flatDest version: '1.0.0'))
                copyReplaceAll: (Sha256 hexDigestOf: (self contentsOf:
                    (PublishLayoutFixtures flatArchivePathIn: flatDest
                        version: '1.0.0')))
                with: 'DIGEST'.
        self assert: sparse = flat
            description: 'the sparse entry is not the flat entry, moved'
    ]

    "---- S2: a second publish appends to the listing ----"

    testS2_ASecondPublishAppendsToTheListing [
        | dest |
        dest := self freshDir: 's15-s2-dest'.
        self sparsePublish: '1.0.0' from: 's15-s2-work-a' to: dest.
        self sparsePublish: '1.1.0' from: 's15-s2-work-b' to: dest.
        self assert: (self exists: (PublishLayoutFixtures
            sparseEntryPathIn: dest version: '1.0.0'))
            description: 'the first release was lost'.
        self assert: (self exists: (PublishLayoutFixtures
            sparseEntryPathIn: dest version: '1.1.0'))
            description: 'the second release did not land'.
        self assert: (self listingIn: dest)
            = (PublishLayoutFixtures listingFor: #('1.0.0' '1.1.0'))
            description: 'the listing does not name both versions'
    ]

    "---- S3: versions order semantically, not lexically ----"

    testS3_VersionsOrderSemanticallyNotLexically [
        "'1.10.0' precedes '1.9.0' as STRINGS. Sorting the strings is
         the obvious implementation and the wrong one; this scenario
         exists to fail on it, and it asserts on the file's bytes."
        | dest bytes |
        dest := self freshDir: 's15-s3-dest'.
        self sparsePublish: '1.9.0' from: 's15-s3-work-a' to: dest.
        self sparsePublish: '1.10.0' from: 's15-s3-work-b' to: dest.
        bytes := self listingIn: dest.
        self assert: bytes
            = (PublishLayoutFixtures listingFor: #('1.9.0' '1.10.0'))
            description: 'versions.st renders ', bytes printString
    ]

    "---- S4: publication order does not change the bytes ----"

    testS4_PublicationOrderDoesNotChangeTheBytes [
        "Byte-stability is a law here as everywhere. A renderer that
         appends rather than sorts can pass S3 by luck; it cannot pass
         this."
        | ascending descending |
        ascending := self freshDir: 's15-s4-asc'.
        descending := self freshDir: 's15-s4-desc'.
        self sparsePublish: '1.9.0' from: 's15-s4-work-a' to: ascending.
        self sparsePublish: '1.10.0' from: 's15-s4-work-b' to: ascending.
        self sparsePublish: '1.10.0' from: 's15-s4-work-c' to: descending.
        self sparsePublish: '1.9.0' from: 's15-s4-work-d' to: descending.
        self assert: (self listingIn: ascending)
            = (self listingIn: descending)
            description: 'the listing bytes depend on publication order'
    ]

    "---- S5: a malformed existing listing is one problem, and
          nothing is written ----"

    testS5_AMalformedListingIsOneProblemAndNothingIsWritten [
        "The fifth deserialization boundary diagnosing its own input:
         each ground separately, one problem naming the file and the
         defect, exit 1, no process spawned, and the destination
         byte-identical to before — the listing is read BEFORE anything
         is staged. The grounds are iterated from the fixture table and
         the guard is what stops an empty table from passing the
         scenario vacuously."
        | grounds index |
        grounds := PublishLayoutFixtures malformedListingTexts.
        self deny: grounds isEmpty
            description: 'no malformed-listing grounds - the scenario would be vacuous'.
        index := 0.
        grounds do: [:ground |
            | dest work runner before result |
            index := index + 1.
            dest := self freshDir: 's15-s5-dest-', index printString.
            work := self workDir: 's15-s5-work-', index printString
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
                description: 'ground ', index printString, ' spawned a process'.
            self assert: (PublishLayoutFixtures treeSnapshotOf: dest) = before
                description: 'ground ', index printString,
                    ' changed the destination']
    ]

    "---- S6: re-publishing a released version is the settled
          refusal ----"

    testS6_RepublishingAReleasedVersionIsTheSettledRefusal [
        "Releases are immutable, in both layouts: the settled refusal
         wording, exit 1, no process spawned, and versions.st
         unchanged."
        | dest work runner listingBefore result |
        dest := self freshDir: 's15-s6-dest'.
        self sparsePublish: '1.0.0' from: 's15-s6-work-a' to: dest.
        listingBefore := self listingIn: dest.
        work := self workDir: 's15-s6-work-b' version: '1.0.0'.
        runner := RecordingRunner new.
        result := self runIn: work
            argv: (PublishLayoutFixtures publishArgvTo: dest layout: 'sparse')
            runner: runner.
        self assert: result exitCode = 1.
        self assert: result lines = (Array with: (PublishLayoutFixtures
            refusalProblemAtVersion: '1.0.0' in: dest))
            description: 'the refusal answered ', result lines printString.
        self assert: runner commands = #()
            description: 'the refusal spawned a process'.
        self assert: (self listingIn: dest) = listingBefore
            description: 'the refusal rewrote the listing'
    ]

    "---- S7: every refusal leaves the destination byte-identical ----"

    testS7_EveryRefusalLeavesTheDestinationByteIdentical [
        "A refusal that answers the right words while leaving a
         half-written tree passes S6 and fails here, which is why the
         two are separate scenarios and why this one compares the WHOLE
         tree — file names and contents, recursively — rather than the
         listing alone. Each ground gets its own destination. The
         build-failure ground compares the tree without the settled
         destination-confined stage (Doc F §1 step 4: fail-stop never
         cleans up behind an error) and separately requires that no
         package directory appeared, which is the whole of what Doc F
         §8.3 scopes atomicity to."
        | missing dest work before |
        "Ground 1 — the destination does not exist. Publish does not
         create it (Doc F §1), so the strongest byte-identity statement
         available is that it is still not there."
        missing := SourceFixtures missingPathNamed: 's15-s7-absent'.
        self deny: (self exists: missing)
            description: 'the missing-destination fixture exists'.
        self assert: (self publishFrom:
            (self workDir: 's15-s7-work-missing' version: '1.0.0')
            to: missing layout: 'sparse') exitCode = 1.
        self deny: (self exists: missing)
            description: 'the refusal created the destination it refused'.

        "Ground 2 — a declared fileIn is missing from the working
         directory. The version differs from the published one, so the
         refusal really is the pre-flight and not the republish."
        dest := self freshDir: 's15-s7-filein-dest'.
        self sparsePublish: '1.0.0' from: 's15-s7-filein-seed' to: dest.
        work := self workDir: 's15-s7-filein-work' version: '1.1.0'.
        ExecFixtures removeTree: work, '/', PublishLayoutFixtures fileInName.
        before := self snapshotOf: dest labelled: 'missing-filein'.
        self assert: (self publishFrom: work to: dest layout: 'sparse')
            exitCode = 1
            description: 'the missing fileIn was not refused'.
        self assertTreeOf: dest matches: before labelled: 'missing-filein'.

        "Ground 3 — the release is already published."
        dest := self freshDir: 's15-s7-republish-dest'.
        self sparsePublish: '1.0.0' from: 's15-s7-republish-seed' to: dest.
        work := self workDir: 's15-s7-republish-work' version: '1.0.0'.
        before := self snapshotOf: dest labelled: 'republish'.
        self assert: (self publishFrom: work to: dest layout: 'sparse')
            exitCode = 1
            description: 'the republish was not refused'.
        self assertTreeOf: dest matches: before labelled: 'republish'.

        "Ground 4 — the existing listing is malformed. It is written
         BEFORE the snapshot, so the comparison covers the listing the
         publish read and refused."
        dest := self freshDir: 's15-s7-listing-dest'.
        PublishLayoutFixtures
            writeListing: SparseIndexFixtures wrongTagListingText
            in: dest.
        work := self workDir: 's15-s7-listing-work' version: '1.0.0'.
        before := self snapshotOf: dest labelled: 'malformed-listing'.
        self assert: (self publishFrom: work to: dest layout: 'sparse')
            exitCode = 1
            description: 'the malformed listing was not refused'.
        self assertTreeOf: dest matches: before labelled: 'malformed-listing'.

        "Ground 5 — the toolchain build fails."
        self assertAFailedBuildLeavesNothingPublishedIn:
            (self freshDir: 's15-s7-failbuild-dest')
    ]

    snapshotOf: aDestDir labelled: aLabel [
        "The whole tree, recursively, with the guard that stops an
         empty snapshot from making the later comparison vacuous."
        | before |
        before := PublishLayoutFixtures treeSnapshotOf: aDestDir.
        self deny: before isEmpty
            description: aLabel, ' snapshotted an empty tree - the comparison would be vacuous'.
        ^before
    ]

    assertTreeOf: aDestDir matches: aSnapshot labelled: aLabel [
        self assert: (PublishLayoutFixtures treeSnapshotOf: aDestDir)
            = aSnapshot
            description: aLabel, ' changed the destination'
    ]

    assertAFailedBuildLeavesNothingPublishedIn: aDestDir [
        "The build-failure ground, held to exactly what Doc F §8.3
         scopes: no entry, no archive, no listing, no package directory
         — and the rest of the destination untouched beside the stage
         Doc F §1 leaves for inspection."
        | work runner before result |
        work := self workDir: 's15-s7-failbuild-work' version: '1.0.0'.
        before := PublishLayoutFixtures treeSnapshotOf: aDestDir.
        runner := RecordingRunner answering: 2.
        result := self runIn: work
            argv: (PublishLayoutFixtures publishArgvTo: aDestDir
                layout: 'sparse')
            runner: runner.
        self assert: result exitCode = 1.
        self deny: runner commands isEmpty
            description: 'no build was attempted - the ground proves nothing'.
        self deny: (self exists: (PublishLayoutFixtures packageDirIn: aDestDir))
            description: 'a failed build created the package directory'.
        self assert: (PublishLayoutFixtures treeSnapshotOf: aDestDir
            without: PublishLayoutFixtures stageDirName) = before
            description: 'a failed build left published state behind'
    ]

    "---- S8: the producer cannot manufacture the index defect ----"

    testS8_TheProducerCannotManufactureTheStateTheClientCallsAnIndexDefect [
        "THE CLIENT IS THE ORACLE. A tree built by a mixed sequence of
         successful and refused publishes is scanned by the settled
         SparseIndexSource over file://, and snapshot must answer
         cleanly — never Sprint 14's S8 index-defect problem, which is
         what a listing naming an absent entry produces. This sprint's
         atomicity exists to make that state unreachable, and the proof
         is the consumer's own diagnosis rather than a restatement of
         it."
        | dest cache source snapshot |
        dest := self freshDir: 's15-s8-dest'.
        cache := self freshDir: 's15-s8-cache'.
        self sparsePublish: '1.0.0' from: 's15-s8-work-a' to: dest.
        self assert: (self publishFrom:
            (self workDir: 's15-s8-work-b' version: '1.0.0')
            to: dest layout: 'sparse') exitCode = 1
            description: 'the republish was not refused'.
        self assert: (self publishFrom:
            (self workDir: 's15-s8-work-c' version: '1.1.0')
            to: dest layout: 'sparse') exitCode = 0.
        source := (SparseIndexSource
            base: (SparseIndexFixtures baseUrlFor: dest)
            cache: cache
            runner: ProcessRunner new)
                seededWith: (Set with: PublishLayoutFixtures packageName).
        snapshot := source snapshot.
        self assert: (snapshot versionsOf: PublishLayoutFixtures packageName)
            size = 2
            description: 'the client does not see exactly the two published releases'
    ]

    "---- S9: the default layout is flat, byte-identical ----"

    testS9_TheDefaultLayoutIsFlatAndByteIdenticalToWhatItAlwaysWas [
        "DECLARED PASS IN RED (issue #17) — a settled-behaviour guard,
         not a new claim: the pre-sprint CLI already writes exactly
         this. That is precisely what makes it worth having. It is the
         law that keeps this sprint additive, and it fails the moment
         the layout work reaches into the default path."
        | dest result digest |
        dest := self freshDir: 's15-s9-dest'.
        result := self runIn: (self workDir: 's15-s9-work' version: '1.0.0')
            argv: (PublishLayoutFixtures publishArgvTo: dest)
            runner: ProcessRunner new.
        self assert: result exitCode = 0.
        self assert: (PublishFixtures fileNamesIn: dest)
            = (Array
                with: (PublishLayoutFixtures entryFileNameAtVersion: '1.0.0')
                with: (PublishLayoutFixtures archiveFileNameAtVersion: '1.0.0'))
            description: 'the default publish wrote ',
                (PublishFixtures fileNamesIn: dest) printString.
        digest := Sha256 hexDigestOf: (self contentsOf: (PublishLayoutFixtures
            flatArchivePathIn: dest version: '1.0.0')).
        self assert: (self contentsOf: (PublishLayoutFixtures
            flatEntryPathIn: dest version: '1.0.0'))
                = (PublishLayoutFixtures entryAtVersion: '1.0.0' digest: digest)
    ]

    "---- S10: the layout flag, and its drift law ----"

    testS10_TheLayoutFlagAndItsDriftLaw [
        "An unrecognized value is a usage error at exit 2 and never a
         fallback; the table carries exactly the two rows; every
         declared row is reachable through the flag, so a layout cannot
         be lawful and unreachable; and the usage flags: lines name the
         flag while the verbs: line does not move — no verb moves this
         sprint."
        | dest usage names |
        dest := self freshDir: 's15-s10-dest'.
        usage := self runIn: (self workDir: 's15-s10-work' version: '1.0.0')
            argv: (PublishLayoutFixtures publishArgvTo: dest
                layout: 'nonsense')
            runner: RecordingRunner new.
        self assert: usage exitCode = 2
            description: 'an unrecognized layout answered exit ',
                usage exitCode printString.
        self assert: (PublishFixtures fileNamesIn: dest) = #()
            description: 'an unrecognized layout wrote into the destination'.
        names := CommandLine publishLayouts collect: [:row | row at: 1].
        self assert: names = #('flat' 'sparse')
            description: 'publishLayouts declares ', names printString.
        self assert: (GrammarFixtures headerRowIn: usage lines)
            = SparseIndexFixtures usageHeaderLine
            description: 'the usage header moved'.
        self assert: (GrammarFixtures verbsRowIn: usage lines)
            = GrammarFixtures usageVerbsLine
            description: 'the verbs: line is not the block''s own'.
        self assert: usage lines first = (GrammarFixtures
            unknownLayoutReasonFor: 'nonsense')
            description: 'an unrecognized layout answered ',
                usage lines first printString.
        self assert: (usage lines includes:
            PublishLayoutFixtures layoutFlagUsageLine)
            description: 'no flags: line describes --layout'
    ]

    "---- S11: the fifth deserialization boundary is declared ----"

    testS11_TheFifthDeserializationBoundaryIsDeclared [
        "Reading the listing makes Publisher a sender of
         IndexEntryReader readFrom:, so the drift law forces the row
         the moment the send ships — the mechanism of §8 decisions 35,
         38 and 43, exercised rather than widened. The per-boundary
         malformed-input law the table's contract requires is S5."
        | rows senders |
        rows := CommandLine deserializationBoundaries.
        "Re-pinned in Sprint 19's GREEN: Configuration reads
         parley.config.st through the settled reader (Doc B §5.7), so the
         table has six rows. THIS SCENARIO'S OWN CLAIM IS UNCHANGED and
         is the one asserted below — Publisher is a sender the walk sees
         and a row the table declares. The count and the class list move
         with the table by construction rather than by hand."
        self assert: rows size = LockSchemaFixtures boundaryClassNames size
            description: 'the boundary table has ', rows size printString,
                ' rows'.
        self assert: (LockSchemaFixtures namesOfBoundaryClassesIn: rows)
            = LockSchemaFixtures boundaryClassNames.
        senders := LockSchemaFixtures readerSenderClassNames.
        self deny: senders isEmpty
            description: 'the src/ walk found no senders at all'.
        self assert: (senders includes: 'Publisher')
            description: 'the src/ walk does not see Publisher as a sender: ',
                senders printString.
        self assert: (LockSchemaFixtures undeclaredSendersIn: rows) isEmpty
            description: 'a sender of the reader is not a declared boundary'
    ]

    "---- S12: parley --version, through the shipped binary ----"

    testS12_ParleyVersionThroughTheShippedBinary [
        "One line naming the tool and its version, exit 0, with NO
         working directory required and no state directories created.
         Run through the product the user actually types, because a
         version answer that needs a project is not a version answer."
        | work outPath code output |
        work := self freshDir: 's15-s12-work'.
        outPath := (CommandLineFixtures absolutePathOf: work), '/version.txt'.
        code := ProcessRunner new run: (CommandLineFixtures
            shippedBinaryCommandIn: work
            args: PublishLayoutFixtures versionFlag
            outputTo: outPath).
        self assert: code = 0
            description: 'the shipped binary answered exit ', code printString.
        output := ExecFixtures linesOf: (self contentsOf: outPath).
        self assert: output size = 1
            description: 'parley --version printed ', output printString.
        self assert: (output at: 1) = PublishLayoutFixtures versionLine.
        self deny: (self exists: (CommandLineFixtures parleyDirIn: work))
            description: '--version created the .parley state directory'.
        CommandLineFixtures backtraceMarkers do: [:marker |
            self deny: (CommandLineFixtures does: (self contentsOf: outPath)
                include: marker)
                description: 'parley --version printed a backtrace']
    ]

    "---- S13: the version has exactly one definition ----"

    testS13_TheVersionHasExactlyOneDefinition [
        "The command's output is compared against the CONSTANT, not
         against a second literal — the single-definition rule that
         keeps a version from drifting the moment it matters, which is
         in a bug report."
        | result |
        result := self runIn: (self freshDir: 's15-s13-work')
            argv: (Array with: PublishLayoutFixtures versionFlag)
            runner: TrapRunner new.
        self assert: result exitCode = 0.
        self assert: result lines size = 1.
        self assert: (CommandLineFixtures does: (result lines at: 1)
            include: Parley version)
            description: 'the printed line does not carry Parley version'.
        self assert: (Version fromString: Parley version) printString
            = Parley version
            description: 'the version constant is not a three-component version'
    ]

    "---- S14: a seed-gathering failure is a defect, not a conflict ----"

    testS14_ASeedGatheringFailureIsADefectNotAConflict [
        "§8 decision 52, cleared at its trigger — this is the last v1.0
         sprint, so release IS the trigger, and after it a latent
         wrong-blame diagnosis is in released software. The seed
         gathering may swallow only the errors whose diagnosis it defers
         to; anything else leaves a silently partial seed set, and under
         --index that becomes a #noVersions conflict blaming the
         package. Narrowed, it reaches the settled taxonomy: exit 70,
         one line, never a backtrace and never exit 0."
        | base work result |
        base := self track: (SparseIndexFixtures baseTreeNamed: 's15-s14-base').
        SparseIndexFixtures publish: 'other-pkg' version: '1.0.0'
            dependencies: #() in: base.
        work := self track: (SparseIndexFixtures workDirNamed: 's15-s14-work'
            declaring: 'absent-pkg' constraint: '^1.0').
        "THE DRIVER MOVED AT SPRINT 16, AND ONLY THE DRIVER (ruled on
         issue #18). This scenario was driven by a parley.lock that was
         a DIRECTORY — then the one operator state reaching the exit-70
         branch. §8 decision 56 now diagnoses that state at exit 1 and
         closed the equivalent ManifestFile hole with it, so no
         filesystem state reaches the branch any more, by design: gst
         swallows anything raised by filed-in manifest code, so a
         boundary skipping its readability check was always the only
         escape. Re-driving onto a surviving hole would make this
         scenario depend on that hole staying open, which is how the
         lock one survived two sprints. The claim is about what the
         CATCH does with an error it did not anticipate, so the error is
         injected at the seam the gathering reads through. Every
         assertion below is the settled one."
        result := (SeedFaultCommandLine in: work runner: ProcessRunner new)
            run: (Array with: 'resolve' with: '--index'
                with: (SparseIndexFixtures baseUrlFor: base)).
        self assert: result exitCode = 70
            description: 'the seed-gathering failure answered exit ',
                result exitCode printString, ': ', result lines printString.
        self assert: result lines size = 1.
        self deny: (CommandLineFixtures does: (result lines at: 1)
            include: 'absent-pkg')
            description: 'the failure was reported as a conflict blaming the package'
    ]

    "---- S15: the README describes the tool that exists ----"

    testS15_TheReadmeDescribesTheToolThatExists [
        "A DRIFT LAW, not good intentions: every verb the CLI's own
         usage line declares must appear in the README, and the §8
         decision 45 consumer constraint must be there — parley exec is
         a faithful pass-through of the child's exit code and is not a
         CI pass/fail signal on its own. A verb added without
         documentation fails the suite rather than quietly shipping
         undocumented."
        | verbs readme undocumented |
        verbs := PublishLayoutFixtures verbsIn: (GrammarFixtures
            verbsRowIn: (self runIn: (self freshDir: 's15-s15-work')
                argv: #() runner: TrapRunner new) lines).
        self deny: verbs isEmpty
            description: 'no verbs were extracted - the scenario would be vacuous'.
        readme := PublishLayoutFixtures readmeSource.
        undocumented := verbs reject: [:verb |
            CommandLineFixtures does: readme include: 'parley ', verb].
        self assert: undocumented isEmpty
            description: undocumented printString,
                ' are verbs the CLI offers and the README does not name'.
        PublishLayoutFixtures execConstraintMarkers do: [:marker |
            self assert: (CommandLineFixtures does: readme include: marker)
                description: 'the README dropped the exec constraint marker: ',
                    marker printString]
    ]

    "---- S16: end to end, offline — the ecosystem loop closes ----"

    testS16_EndToEndOfflineTheEcosystemLoopClosesOverASparseIndex [
        "THE SPRINT'S EXIT CRITERION, AND v1.0's. Author A publishes a
         real toolchain-built package into an empty base with --layout
         sparse; author B declares it, resolves, locks, installs and
         execs against that base through --index over file://. The lock
         is written, the archive is fetched and hash-verified into the
         store, the registration plan runs, and a curated child proves
         the class visible. Published by one working directory,
         consumed by another, over a layout neither downloads in full —
         offline, no network, every path under tmp/."
        | base authorA consumer runner result proofPath digest |
        base := self freshDir: 's15-s16-base'.
        authorA := self workDir: 's15-s16-author' version: '1.0.0'.
        runner := ProcessRunner new.
        result := self runIn: authorA
            argv: (PublishLayoutFixtures publishArgvTo: base layout: 'sparse')
            runner: runner.
        self assert: result exitCode = 0
            description: 'the publish failed: ', result lines printString.
        digest := self digestOfArchiveIn: base version: '1.0.0'.
        consumer := self track: (SparseIndexFixtures
            workDirNamed: 's15-s16-consumer'
            declaring: PublishLayoutFixtures packageName
            constraint: '^1.0').
        result := self runIn: consumer
            argv: (Array with: 'resolve' with: '--index'
                with: (SparseIndexFixtures baseUrlFor: base))
            runner: runner.
        self assert: result exitCode = 0
            description: 'resolve failed: ', result lines printString.
        self assert: (CommandLineFixtures does:
            (self contentsOf: consumer, '/parley.lock')
            include: digest)
            description: 'the lock does not pin the published archive digest'.
        result := self runIn: consumer
            argv: (Array with: 'install' with: '--index'
                with: (SparseIndexFixtures baseUrlFor: base))
            runner: runner.
        self assert: result exitCode = 0
            description: 'install failed: ', result lines printString.
        self assert: ((ContentStore on:
            (CommandLineFixtures storeRootIn: consumer))
                containsHash: digest)
            description: 'the archive was not hash-verified into the store'.
        proofPath := consumer, '/proof.txt'.
        SourceFixtures
            write: (PublishLayoutFixtures proofScriptContentsFor: proofPath)
            toFile: 'proof-script.st' in: consumer.
        "workdir-relative argv (Sprint 22, the exec-cwd family's ruled
         re-pin: the script resolves against the working directory,
         never the process cwd — a member the C1 sweep found late)"
        result := self runIn: consumer
            argv: (Array with: 'exec' with: 'proof-script.st')
            runner: runner.
        self assert: result exitCode = 0.
        self assert: (self contentsOf: proofPath) = 'present'
            description: 'the curated child cannot see the published class'
    ]
]

Namespace current: Smalltalk.
