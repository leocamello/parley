"Parley Sprint 13 - acceptance scenarios S1-S13 from GitHub issue #15.
 Each scenario Sn maps to exactly one selector starting with testSn_
 (enforced by the wrap traceability gate).

 The milestone: THE TOOL EDITS THE MANIFEST, AND NEVER RE-RENDERS IT.
 Every other verb reads the operator's Package.st; none of them writes
 it, so the one action that begins every real session - I want to use
 this library - is still four manual steps and a syntax recall. What
 gated it was a ruling, not capacity, and the ruling is made: §8
 decision 49. Package.st is executable Smalltalk the author owns and
 the manifest is a lossy projection of it, so the easy build - load the
 manifest, re-render the file - is DISQUALIFIED. add inserts one clause
 into a recognized cascade, preserves every other byte, verifies the
 result by re-reading it, and refuses, touching nothing, when the shape
 is unfamiliar.

 S3 IS THE SCENARIO DECISION 49 EXISTS FOR. A round-trip implementation
 passes S1, S2 and S4 and fails S3, which is why S3 asserts the header
 comment, the interior comment, the blank line and the author's
 indentation explicitly - byte by byte - rather than `the file still
 parses`. Both weaker claims are TRUE of the disqualified design.

 BYTE PRESERVATION IS COMPARED, NEVER INFERRED. S1, S2, S3, S5, S8 and
 S10 read the artifact back and compare it against what it was. `The
 text got longer`, `the file still loads` and `the manifest has three
 dependencies` all pass on an editor that silently reflowed the file,
 and an exit code proves nothing at all about a file on disk.

 THE CONTRAST CLAUSE IS THE PROOF (S9). Plain update runs against the
 IDENTICAL fixture and must move tool-b to 2.1.0: without it, S9 passes
 on a fixture where nothing else could have moved, and a proof that
 cannot fail proves nothing.

 DECLARED PASSES IN RED (issue #15): NONE in this file, and none in the
 sprint's law suites either (each declares so in its own class
 comment). S1-S3 and S5 message Parley.ManifestEditor, which does not
 exist against the pre-sprint tree; S4 and S6-S11 consume the
 three-element add argv row, which falls through to the settled usage
 answer (exit 2) where they demand 0 or 1; S12 pins the NEW verbs:
 line; and S13 demands one diagnosis line where the settled update
 <pkg> answers a ConflictReport narration.

 S11 registers through the recording runner; no scenario spawns
 bin/parley-main.st and none runs git. No test contacts a network,
 ever. Every fixture path is under tmp/, unique per test, removed
 recursively in tearDown; the developer image is never mutated."

Namespace current: Parley.

TestCase subclass: Sprint13AcceptanceTest [
    | fixtureDirs |

    <comment: 'Acceptance scenarios for Sprint 13: parley add <pkg>
<constraint> - one clause inserted into a recognized cascade with every
other byte preserved, the edit verified through the settled
ManifestFile load:, the four diagnoses at exit 1, the idempotent
already-declared success, resolution under held pins with its contrast,
atomicity asserted on the artifact, install and register behind the
verb, the argv grammar, and the shared deleted-held-pin diagnosis on
both add and update.'>

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

    editedTextOf: aText [
        ^(ManifestEditor on: aText)
            textWithDependency: ManifestEditFixtures addedName
            constraint: ManifestEditFixtures addedConstraint
    ]

    linesOf: aString [
        ^ManifestEditFixtures textLinesOf: aString
    ]

    resultOf: anArgvArray in: aWorkDir runner: aRunner [
        ^(CommandLine in: aWorkDir runner: aRunner) run: anArgvArray
    ]

    addOf: aName constraint: aConstraint in: aWorkDir source: anIndexDir [
        ^self resultOf: (Array
                with: 'add' with: aName with: aConstraint
                with: '--source' with: anIndexDir)
            in: aWorkDir runner: RecordingRunner new
    ]

    addToolAIn: aWorkDir source: anIndexDir [
        ^self addOf: ManifestEditFixtures addedName
            constraint: ManifestEditFixtures addedConstraint
            in: aWorkDir source: anIndexDir
    ]

    packageIn: aWorkDir [
        ^ManifestEditFixtures packageContentsIn: aWorkDir
    ]

    lockIn: aWorkDir [
        ^ManifestEditFixtures lockContentsIn: aWorkDir
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

    assertSpliceOf: anEditedText from: anOriginalText [
        "The byte comparison, line by line and independent of any
         expected literal: the file is the original with the previous
         last clause line gaining a semicolon, one new line carrying the
         clause at that line's own indent, and NOTHING ELSE touched. An
         editor that reflowed the file fails at the first line it had no
         business rewriting."
        | before after last |
        before := self linesOf: anOriginalText.
        after := self linesOf: anEditedText.
        last := before size.
        self assert: after size = (last + 1)
            description: 'the edit changed the line count by ',
                (after size - last) printString, ' rather than by one'.
        1 to: last - 1 do: [:i |
            self assert: (after at: i) = (before at: i)
                description: 'line ', i printString, ' was rewritten: <',
                    (before at: i), '> became <', (after at: i), '>'].
        self assert: (after at: last)
            = (((before at: last) copyFrom: 1 to: (before at: last) size - 2), ';')
            description: 'the previous last clause line is not itself plus a semicolon: <',
                (after at: last), '>'.
        self assert: (after at: last + 1)
            = ((ManifestEditFixtures indentOf: (before at: last)),
                ManifestEditFixtures addedClauseText, ' ]')
            description: 'the inserted line is wrong: <', (after at: last + 1), '>'
    ]

    "---- S1-S3: one clause in, every other byte preserved ----"

    testS1_OneClauseIsInsertedIntoAManifestWithNoDependenciesYet [
        "The byte-exact parley init template, whose cascade ends
         fileIns: #('MyPackage.st') ]. Exactly one clause is inserted -
         the previous last clause gains its semicolon, the new clause
         reads dependency: 'tool-a' constraint: '^1.0' - and every other
         byte is unchanged, asserted as a byte comparison against the
         original and never as `the text got longer`."
        | original edited |
        original := ManifestEditFixtures initTemplateContents.
        edited := self editedTextOf: original.
        self assert: edited = ManifestEditFixtures initTemplateEdited
            description: 'the edited init template is not byte-exact'.
        self assertSpliceOf: edited from: original
    ]

    testS2_AndIntoAManifestThatAlreadyDeclaresDependencies [
        "The new clause FOLLOWS the existing one, the existing clauses
         are byte-identical, and declaration order is preserved (Doc B
         §6: dependency order is not semantic, but stability is a
         property of the file)."
        | original edited lines |
        original := ManifestEditFixtures withDependenciesContents.
        edited := self editedTextOf: original.
        self assert: edited = ManifestEditFixtures withDependenciesEdited
            description: 'the edited cascade is not byte-exact'.
        self assertSpliceOf: edited from: original.
        lines := self linesOf: edited.
        self assert: (lines at: lines size - 1)
            = '        dependency: ''tool-b'' constraint: ''^2.0'';'
            description: 'the existing dependency clause moved or changed'.
        self assert: (lines at: lines size)
            = '        dependency: ''tool-a'' constraint: ''^1.0'' ]'
            description: 'the new clause did not land after the existing one'
    ]

    testS3_CommentsBlankLinesAndTheAuthorsFormattingSurvive [
        "A header comment, an interior comment above a clause, a blank
         line inside the cascade and six-space indentation. The result
         is byte-identical to the original except for the inserted
         clause, asserted COMMENT BY COMMENT AND LINE BY LINE. This is
         the scenario decision 49 exists for: a round-trip
         implementation passes S1, S2 and S4 and fails here, which is
         the point."
        | original edited |
        original := ManifestEditFixtures authoredContents.
        edited := self editedTextOf: original.
        self assert: edited = ManifestEditFixtures authoredEdited
            description: 'the authored file is not byte-exact after the edit'.
        self assertSpliceOf: edited from: original.
        self assert: (ManifestEditFixtures contains: edited
            line: ManifestEditFixtures authoredHeaderCommentLine)
            description: 'the header comment did not survive'.
        self assert: (ManifestEditFixtures contains: edited
            line: ManifestEditFixtures authoredInteriorCommentLine)
            description: 'the interior comment did not survive'.
        self assert: (ManifestEditFixtures blankLineCountIn: edited) = 1
            description: 'the blank line inside the cascade did not survive'.
        self assert: (self linesOf: edited) last
            = '      dependency: ''tool-a'' constraint: ''^1.0'' ]'
            description: 'the new clause did not adopt the author''s indentation'
    ]

    "---- S4: the edit is verified by the reader that owns the meaning ----"

    testS4_TheEditIsVerifiedByTheReaderThatOwnsTheMeaning [
        "Re-loaded through the settled ManifestFile load:, the manifest
         declares the new dependency with the parsed constraint and is
         otherwise EQUAL to the manifest loaded before the edit - same
         name, version, fileIns order and every pre-existing dependency.
         A textual edit that is not checked by the reader is a hope."
        | work index before after added |
        work := self track:
            (ManifestEditFixtures toolBWorkDirNamed: 's13-s4-work').
        index := self toolsIndex: 's13-s4-index'.
        before := ManifestFile load: work, '/Package.st'.
        self assert: (self addToolAIn: work source: index) exitCode = 0.
        after := ManifestFile load: work, '/Package.st'.
        self assert: after name = before name.
        self assert: after version = before version.
        self assert: after fileIns asArray = before fileIns asArray
            description: 'the fileIns order changed'.
        self assert: after dependencies size = (before dependencies size + 1)
            description: 'the edit did not add exactly one dependency'.
        before dependencies do: [:dep |
            self assert: (after dependencies includes: dep)
                description: 'a pre-existing dependency was lost or changed: ',
                    dep printString].
        added := after dependencies
            detect: [:dep | dep name = ManifestEditFixtures addedName]
            ifNone: [nil].
        self deny: added isNil
            description: 'the reloaded manifest does not declare the added dependency'.
        self assert: added constraint
            = (VersionConstraint fromString: ManifestEditFixtures addedConstraint)
    ]

    "---- S5-S8: the diagnoses and the idempotent success ----"

    testS5_AShapeItCannotRecognizeIsRefusedAndNothingChanges [
        "A Package.st with no Parley define: send, and separately one
         with TWO of them. Both answer exit 1 and one line naming the
         file and the exact text to paste; both files are
         byte-identical; neither writes a lock. Never exit 70, never a
         backtrace."
        | index shapes |
        index := self toolsIndex: 's13-s5-index'.
        shapes := Array
            with: (Array with: 's13-s5-nodefine'
                with: ManifestEditFixtures noDefineContents)
            with: (Array with: 's13-s5-twodefines'
                with: ManifestEditFixtures twoDefinesContents).
        shapes do: [:each |
            | work original result |
            work := self track: (ManifestEditFixtures
                workDirNamed: (each at: 1) contents: (each at: 2)).
            original := self packageIn: work.
            result := self addToolAIn: work source: index.
            self assert: result exitCode = 1
                description: (each at: 1), ' did not answer exit 1'.
            self assert: result lines = (Array with:
                (ManifestEditFixtures
                    unrecognizedLineFor: ManifestEditFixtures addedName
                    constraint: ManifestEditFixtures addedConstraint
                    in: work, '/Package.st')).
            self assert: (self packageIn: work) = original
                description: (each at: 1), ': the refusal changed the file'.
            self deny: (File name: work, '/parley.lock') exists
                description: (each at: 1), ': the refusal wrote a lock'.
            self denyBlamesParley: result]
    ]

    testS6_AProjectWithNoPackageStIsTheSettledDiagnosis [
        "The settled missing-manifest line naming parley init (§8
         decision 31) - the same answer every other verb gives, not a
         second wording for one question."
        | work index result |
        work := self freshDir: 's13-s6-work'.
        index := self toolsIndex: 's13-s6-index'.
        result := self addToolAIn: work source: index.
        self assert: result exitCode = 1.
        self assert: result lines = (Array with:
            (ManifestEditFixtures missingManifestProblemFor: work, '/Package.st')).
        self denyBlamesParley: result
    ]

    testS7_AddingWhatIsAlreadyDeclaredIdenticallyIsAnIdempotentSuccess [
        "exit 0, one pinned confirmation line, and BOTH Package.st and
         parley.lock byte-identical to what they were. Idempotence is
         what makes add safe to put in a script."
        | work index result |
        work := self track:
            (ManifestEditFixtures declaredWorkDirNamed: 's13-s7-work').
        index := self toolsIndex: 's13-s7-index'.
        result := self addToolAIn: work source: index.
        self assert: result exitCode = 0.
        self assert: result lines = (Array with:
            (ManifestEditFixtures alreadyDeclaredSuccessFor:
                ManifestEditFixtures addedName
                constraint: ManifestEditFixtures addedConstraint)).
        self assert: (self packageIn: work)
            = ManifestEditFixtures declaredRootContents
            description: 'the idempotent add rewrote Package.st'.
        self assert: (self lockIn: work)
            = ManifestEditFixtures declaredLockString
            description: 'the idempotent add did not leave the lock byte-identical'
    ]

    testS8_AddingWhatIsDeclaredDifferentlyIsARefusalNamingTheExistingOne [
        "exit 1, one line naming tool-a and its existing ^1.0, and the
         file byte-identical. Changing a constraint is an edit, and a
         verb that silently overwrote one would be a different verb
         wearing this name."
        | work index original result |
        work := self track:
            (ManifestEditFixtures declaredWorkDirNamed: 's13-s8-work').
        index := self toolsIndex: 's13-s8-index'.
        original := self packageIn: work.
        result := self addOf: ManifestEditFixtures addedName
            constraint: '^2.0' in: work source: index.
        self assert: result exitCode = 1.
        self assert: result lines = (Array with:
            (ManifestEditFixtures alreadyDeclaredRefusalFor:
                ManifestEditFixtures addedName constraint: '^1.0')).
        self assert: (self packageIn: work) = original
            description: 'the refusal overwrote the existing constraint'.
        self assert: (self lockIn: work)
            = ManifestEditFixtures declaredLockString.
        self denyBlamesParley: result
    ]

    "---- S9-S10: holding the rest, and failing atomically ----"

    testS9_AddingOneDependencyDoesNotMoveTheOthers [
        "The lock gains tool-a 1.1.0 and the tool-b tuple is
         byte-identical - name, version and #sha256, asserted tuple by
         tuple. AND THE CONTRAST: plain update against the identical
         fixture moves tool-b to 2.1.0, so tool-b was movable and
         holding is what kept it."
        | addWork updateWork index before after result |
        addWork := self track:
            (ManifestEditFixtures toolBWorkDirNamed: 's13-s9-add-work').
        updateWork := self track:
            (ManifestEditFixtures toolBWorkDirNamed: 's13-s9-upd-work').
        index := self toolsIndex: 's13-s9-index'.
        before := SelectiveUpdateFixtures packageTuplesIn: addWork.
        result := self addToolAIn: addWork source: index.
        self assert: result exitCode = 0.
        after := SelectiveUpdateFixtures packageTuplesIn: addWork.
        self assert: ((after at: 'tool-a') at: 2) = '1.1.0'
            description: 'the added package was not pinned at 1.1.0'.
        1 to: 4 do: [:i |
            self assert: ((after at: 'tool-b') at: i)
                = ((before at: 'tool-b') at: i)
                description: 'the held tool-b tuple changed at position ',
                    i printString, ': ', ((after at: 'tool-b') at: i) printString,
                    ' vs ', ((before at: 'tool-b') at: i) printString].
        self assert: (self lockIn: addWork)
            = ManifestEditFixtures addedLockString.
        result := self resultOf: (Array
                with: 'update' with: '--source' with: index)
            in: updateWork runner: RecordingRunner new.
        self assert: result exitCode = 0.
        self assert: (self lockIn: updateWork)
            = ManifestEditFixtures toolBMovedLockString
            description: 'the contrast is broken: plain update did not move tool-b, so nothing was being held'
    ]

    testS10_AFailedAdditionLeavesTheProjectExactlyAsItStarted [
        "app-x's only published release needs core ^2.0 while the held
         pins require core 1.0.0. exit 1, the pinned held-pins line
         followed by the settled ConflictReport narration unmodified -
         AND Package.st byte-identical to before the run, the lock
         unchanged and nothing fetched. Atomicity asserted on the
         artifact, never inferred from the exit code."
        | work index runner original held outcome expected result |
        work := self track: (ManifestEditFixtures
            heldConflictWorkDirNamed: 's13-s10-work').
        index := self freshDir: 's13-s10-index'.
        SelectiveUpdateFixtures populateHeldConflictIndexIn: index.
        runner := RecordingRunner new.
        original := self packageIn: work.
        held := ManifestEditFixtures heldVersionsIn: work.
        outcome := ResolverFixtures
            resolve: ManifestEditFixtures heldConflictRootManifestAfterAdd
            against: ((DirectorySource on: index) snapshot holding: held).
        self deny: outcome isResolution
            description: 'the fixture does not conflict under holding - the scenario cannot fail'.
        expected := (Array with: ManifestEditFixtures heldPinsLine),
            (ExecFixtures linesOf: outcome printString).
        result := self resultOf: (Array
                with: 'add' with: 'app-x' with: '^1.0'
                with: '--source' with: index)
            in: work runner: runner.
        self assert: result exitCode = 1.
        self assert: result lines = expected.
        self assert: (self packageIn: work) = original
            description: 'a failed add left the manifest edited'.
        self assert: (self lockIn: work)
            = ManifestEditFixtures heldConflictLockString
            description: 'a failed add rewrote the lock'.
        self assert: (InstallFixtures starFileCountIn:
            (CommandLineFixtures storeRootIn: work)) = 0
            description: 'a failed add fetched an archive'.
        self assert: runner commands isEmpty.
        self denyBlamesParley: result
    ]

    "---- S11-S12: the pipeline and the grammar ----"

    testS11_TheVerbInstallsAndRegistersExactlyAsUpdateDoes [
        "The added package's archive is fetched and hash-verified into
         the store, and the registration plan runs through the recording
         runner over the WHOLE resolved set - the held pin included,
         exactly as update registers what it pins."
        | work index runner result storeRoot storedPath |
        work := self track:
            (ManifestEditFixtures toolBWorkDirNamed: 's13-s11-work').
        index := self toolsIndex: 's13-s11-index'.
        runner := RecordingRunner new.
        result := self resultOf: (Array
                with: 'add' with: ManifestEditFixtures addedName
                with: ManifestEditFixtures addedConstraint
                with: '--source' with: index)
            in: work runner: runner.
        self assert: result exitCode = 0.
        storeRoot := CommandLineFixtures storeRootIn: work.
        storedPath := storeRoot, '/',
            SelectiveUpdateFixtures digestToolA110, '.star'.
        self assert: (File name: storedPath) exists
            description: 'the added archive never reached the store'.
        self assert: (File name: storedPath) contents
            = SelectiveUpdateFixtures archiveBytesToolA110
            description: 'the stored archive is not the fetched bytes'.
        self assert: runner commands
            = (ChatterFixtures silencedPlan:
                (ManifestEditFixtures addedRegistrationPlanIn: work))
            description: 'the registration plan is not the settled update plan, silenced'
    ]

    testS12_TheArgvGrammar [
        "add tool-a with a source, add tool-a ^1.0 with none, and add a
         b c with one: all three answer the pinned usage lines at exit
         2, and the usage verbs: line names add <pkg> <constraint>."
        | work index result |
        result := (CLI in: 'tmp/parley-s13-s12-work'
            source: nil
            store: (ContentStore on: 'tmp/parley-s13-s12-store')
            target: 'tmp/parley-s13-s12-target'
            runner: RecordingRunner new) run: #('add' 'tool-a' '^1.0').
        self assert: result exitCode = 2.
        self assert: result lines
            = ManifestEditFixtures addNoSourceUsageLines
            description: 'a source-less add answered ', result lines printString.
        self assert: (CommandLineFixtures does:
            (GrammarFixtures verbsRowIn: result lines)
            include: 'add <pkg> <constraint>')
            description: 'the verbs: line does not name add <pkg> <constraint>'.
        work := self track:
            (ManifestEditFixtures toolBWorkDirNamed: 's13-s12-work').
        index := self toolsIndex: 's13-s12-index'.
        result := self resultOf: (Array
                with: 'add' with: 'tool-a' with: '--source' with: index)
            in: work runner: RecordingRunner new.
        self assert: result exitCode = 2.
        self assert: result lines = ManifestEditFixtures addUsageLines
            description: 'add with no constraint answered ',
                result lines printString.
        result := self resultOf: (Array with: 'add' with: 'a' with: 'b'),
                (Array with: 'c' with: '--source' with: index)
            in: work runner: RecordingRunner new.
        self assert: result exitCode = 2.
        self assert: result lines = ManifestEditFixtures addUsageLines
            description: 'add with three arguments answered ',
                result lines printString.
        self assert: (self packageIn: work)
            = ManifestEditFixtures withDependenciesContents
            description: 'a usage answer touched the manifest'
    ]

    "---- S13: the Sprint 12 carried gap, on both verbs ----"

    testS13_AHeldPinTheIndexNoLongerPublishesIsNamedAsSuch [
        "One line naming app-y, its pinned version, and that the index
         no longer publishes it - NOT a ConflictReport, which is what
         both verbs answer today. Decision 47 made this state sound;
         this makes it legible, on both verbs, from one shared
         diagnosis."
        | addWork updateWork index original expected addResult updateResult |
        addWork := self track:
            (ManifestEditFixtures deletedPinWorkDirNamed: 's13-s13-add-work').
        updateWork := self track:
            (ManifestEditFixtures deletedPinWorkDirNamed: 's13-s13-upd-work').
        index := self freshDir: 's13-s13-index'.
        ManifestEditFixtures populateDeletedPinIndexIn: index.
        original := self packageIn: addWork.
        expected := Array with: (ManifestEditFixtures
            deletedHeldPinLineFor: 'app-y' version: '1.0.0').
        addResult := self addToolAIn: addWork source: index.
        self assert: addResult exitCode = 1.
        self assert: addResult lines = expected.
        self assert: (self packageIn: addWork) = original
            description: 'the diagnosis edited the manifest'.
        self assert: (self lockIn: addWork)
            = ManifestEditFixtures deletedPinLockString.
        self denyBlamesParley: addResult.
        updateResult := self resultOf: (Array
                with: 'update' with: ManifestEditFixtures addedName
                with: '--source' with: index)
            in: updateWork runner: RecordingRunner new.
        self assert: updateResult exitCode = 1.
        self assert: updateResult lines = expected
            description: 'update <pkg> did not answer the shared deleted-pin diagnosis'.
        self assert: (self lockIn: updateWork)
            = ManifestEditFixtures deletedPinLockString.
        self denyBlamesParley: updateResult
    ]
]

Namespace current: Smalltalk.
