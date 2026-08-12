"Parley Sprint 13 - the add verb's laws (issue #15; Doc B §2.1,
 Doc E §4.1/§5, Doc C §2.2, §8 decisions 47 and 49).

 THE VERB OWNS EVERYTHING RISKY. ManifestEditor answers text; the CLI
 writes it, re-reads it through the settled ManifestFile load:,
 compares the manifests, and restores the original bytes on any
 disagreement. Every law below therefore drives a real working
 directory under tmp/ through the settled CommandLine wiring, and every
 `nothing changed` claim is asserted ON THE ARTIFACT - the file read
 back and compared byte for byte - never inferred from an exit code.

 THE VERIFICATION IS SEMANTIC, NOT SYNTACTIC (Doc B §2.1). A textual
 edit that is not checked by the reader that owns the meaning is a
 hope, so testTheEditIsVerifiedByTheReaderThatOwnsTheMeaning re-loads
 the edited file through ManifestFile load: and asserts the manifest
 gained EXACTLY the new dependency and is otherwise equal - name,
 version, fileIns order, and every pre-existing dependency.

 ROLLBACK IS REACHED HONESTLY, not by breaking the editor to reach it.
 Two real inputs make a clean insertion produce a file that will not
 load: adding the root's own name (ManifestBuilder rejects a
 self-dependency) and adding an unparseable constraint. add never
 parses a constraint itself - which is also why ConstraintFormatError
 keeps its declared ground of never being signaled out of a verb - so
 the settled builder is the one and only judge of the spelling, and its
 problems travel to the operator unchanged.

 ADDING HOLDS THE EXISTING PINS - the third application of Doc C §2.2's
 holding:, after retirement and selective update, with no resolver
 change again. testAddingDoesNotMoveTheOtherPinsCarriesItsContrast runs
 plain update against the IDENTICAL fixture and requires the different
 outcome, because a fixture where nothing else could move proves
 nothing.

 THE DELETED HELD PIN IS PROVED ON BOTH VERBS (the Sprint 12 carried
 gap). One shared diagnosis, one wording, two callers - and the
 contrast is that both used to answer a ConflictReport about a version
 conflict that was really a missing index entry.

 DECLARED PASSES IN RED (issue #15): NONE in this file. Every law
 consumes the three-element `add` argv row or the shared deleted-pin
 diagnosis, and neither exists against the pre-sprint tree: a
 three-element add argv falls through to the settled usage answer (exit
 2 with the OLD verbs: line) where these laws demand 0 or 1, the usage
 laws pin the NEW verbs: line, and the update half of the deleted-pin
 law demands one line where the settled verb answers a narration.

 Every fixture path is under tmp/, unique per test, removed recursively
 in tearDown; the developer image is never mutated; nothing here spawns
 (every runner is a RecordingRunner) and no network is contacted."

Namespace current: Parley.

TestCase subclass: AddVerbTest [
    | fixtureDirs |

    <comment: 'Laws for parley add <pkg> <constraint>: the edit written
and verified through the settled reader, rollback on any disagreement,
the four diagnoses at exit 1, the idempotent already-declared success,
resolution under held pins with its contrast, atomicity asserted on the
artifact, the install-and-register pipeline behind the verb, the shared
deleted-held-pin diagnosis on both add and update, and the add <pkg>
<constraint> argv grammar.'>

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

    "---- the edit lands, and the reader that owns the meaning checks it ----"

    testTheVerbWritesTheInsertedClauseAndPinsIt [
        "exit 0, the settled reportPins lines, the byte-exact edited
         Package.st and the byte-exact lock: add ends where update
         ends, because install and register run exactly as they do
         there."
        | work index result |
        work := self track:
            (ManifestEditFixtures toolBWorkDirNamed: 'add-write-work').
        index := self toolsIndex: 'add-write-index'.
        result := self addToolAIn: work source: index.
        self assert: result exitCode = 0.
        self assert: result lines
            = (Array with: 'tool-a 1.1.0' with: 'tool-b 2.0.0').
        self assert: (self packageIn: work)
            = ManifestEditFixtures withDependenciesEdited
            description: 'Package.st is not byte-exact after the add'.
        self assert: (self lockIn: work) = ManifestEditFixtures addedLockString
    ]

    testTheEditIsVerifiedByTheReaderThatOwnsTheMeaning [
        "Re-load the written file through the settled ManifestFile
         load: and assert the manifest gained EXACTLY the new dependency
         and is otherwise equal - name, version, fileIns order, and
         every pre-existing dependency."
        | work index before after added |
        work := self track:
            (ManifestEditFixtures toolBWorkDirNamed: 'add-verify-work').
        index := self toolsIndex: 'add-verify-index'.
        before := ManifestFile load: work, '/Package.st'.
        self assert: (self addToolAIn: work source: index) exitCode = 0.
        after := ManifestFile load: work, '/Package.st'.
        self assert: after name = before name.
        self assert: after version = before version.
        self assert: after fileIns asArray = before fileIns asArray
            description: 'the fileIns order changed - it is the gst-package load order'.
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
            description: 'the added dependency did not parse to the constraint asked for'
    ]

    testTheAuthorsOwnFileSurvivesARealAddThroughTheVerb [
        "The editor laws prove the splice on text; this proves the same
         file survives the whole verb - written, re-read by the settled
         loader, resolved, locked - with both comments and the blank
         line still there."
        | work index result |
        work := self track: (ManifestEditFixtures
            workDirNamed: 'add-authored-work'
            contents: ManifestEditFixtures authoredContents).
        index := self toolsIndex: 'add-authored-index'.
        result := self addToolAIn: work source: index.
        self assert: result exitCode = 0.
        self assert: (self packageIn: work)
            = ManifestEditFixtures authoredEdited
            description: 'the authored file did not survive the verb byte for byte'.
        self assert: (ManifestEditFixtures contains: (self packageIn: work)
            line: ManifestEditFixtures authoredInteriorCommentLine)
            description: 'the interior comment did not survive the verb'
    ]

    "---- rollback: any disagreement restores the original bytes ----"

    testAnEditThatWillNotLoadIsRolledBack [
        "Adding the root's own name inserts cleanly and produces a file
         the settled builder rejects. The operator sees the builder's
         own problem and a Package.st byte-identical to what they had.

         AMENDED IN SPRINT 18 GREEN, bounded to adding the header (issue
         #20; Doc E §3.1, §8 decision 44): the reload's authoring problems
         are now emitted inside the settled per-file batch, so the
         diagnosis names the file. The builder's own sentence does not
         move by one byte. THIS SITE WAS MISSED by the enumeration posted
         at the RED review, which grepped the problem LITERALS; this law
         reaches its problem through ManifestEditFixtures and so never
         matched. Recorded because the miss, not the fix, is the lesson —
         decision 60's rule one level over: a census must enumerate the
         property, never the spellings somebody thought of."
        | work index original result |
        work := self track:
            (ManifestEditFixtures toolBWorkDirNamed: 'add-selfdep-work').
        index := self toolsIndex: 'add-selfdep-index'.
        original := self packageIn: work.
        result := self addOf: ManifestEditFixtures selfDependencyName
            constraint: ManifestEditFixtures addedConstraint
            in: work source: index.
        self assert: result exitCode = 1.
        self assert: result lines
            = ((Array with: (AuthoringFixtures
                batchHeaderFor: work, '/Package.st' count: 1)),
                (Array with: ManifestEditFixtures selfDependencyProblem))
            description: 'the refused add answered ',
                result lines printString.
        self assert: (self packageIn: work) = original
            description: 'a failed add left a half-edited Package.st'.
        self assert: (self lockIn: work)
            = ManifestEditFixtures toolBOnlyLockString
            description: 'a failed add rewrote the lock'.
        self denyBlamesParley: result
    ]

    testAnUnparseableConstraintIsJudgedByTheSettledBuilderAndRolledBack [
        "add never parses a constraint itself: the spelling travels into
         the file and the reload is where it is judged, which keeps
         ConstraintFormatError's declared ground - never signaled out of
         a verb - true.

         AMENDED IN SPRINT 18 GREEN, bounded to adding the header, for the
         same reason as the self-dependency law above and missed by the
         same enumeration. The builder's sentence is byte-identical; the
         reload is still where the spelling is judged."
        | work index original result |
        work := self track:
            (ManifestEditFixtures toolBWorkDirNamed: 'add-badconstraint-work').
        index := self toolsIndex: 'add-badconstraint-index'.
        original := self packageIn: work.
        result := self addOf: ManifestEditFixtures addedName
            constraint: ManifestEditFixtures unparseableConstraint
            in: work source: index.
        self assert: result exitCode = 1.
        self assert: result lines
            = ((Array with: (AuthoringFixtures
                batchHeaderFor: work, '/Package.st' count: 1)),
                (Array with:
                    (ManifestEditFixtures unparseableConstraintProblemFor:
                        ManifestEditFixtures addedName)))
            description: 'the refused add answered ',
                result lines printString.
        self assert: (self packageIn: work) = original
            description: 'an unparseable constraint stayed in Package.st'.
        self denyBlamesParley: result
    ]

    "---- the four diagnoses, all exit 1, none exit 70 ----"

    testAProjectWithNoPackageStAnswersTheSettledMissingManifestLine [
        "The same answer every other verb gives (§8 decision 31), not a
         second wording for one question."
        | work index result |
        work := self freshDir: 'add-nomanifest-work'.
        index := self toolsIndex: 'add-nomanifest-index'.
        result := self addToolAIn: work source: index.
        self assert: result exitCode = 1.
        self assert: result lines = (Array with:
            (ManifestEditFixtures missingManifestProblemFor: work, '/Package.st')).
        self deny: (File name: work, '/parley.lock') exists
            description: 'the diagnosis wrote a lock'.
        self denyBlamesParley: result
    ]

    testAShapeItCannotRecognizeIsRefusedAndNothingChanges [
        "One line naming the file and the exact text to paste, the file
         byte-identical, no lock written, nothing spawned. A file that
         never sends define: must reach THIS refusal rather than the
         settled no-manifest line: the operator asked to add something,
         and being told the file defines no package is true and useless."
        | work index runner original result |
        work := self track: (ManifestEditFixtures
            workDirNamed: 'add-noshape-work'
            contents: ManifestEditFixtures noDefineContents).
        index := self toolsIndex: 'add-noshape-index'.
        runner := RecordingRunner new.
        original := self packageIn: work.
        result := self resultOf: (Array
                with: 'add' with: ManifestEditFixtures addedName
                with: ManifestEditFixtures addedConstraint
                with: '--source' with: index)
            in: work runner: runner.
        self assert: result exitCode = 1.
        self assert: result lines = (Array with:
            (ManifestEditFixtures
                unrecognizedLineFor: ManifestEditFixtures addedName
                constraint: ManifestEditFixtures addedConstraint
                in: work, '/Package.st')).
        self assert: (self packageIn: work) = original
            description: 'the refusal changed the file'.
        self deny: (File name: work, '/parley.lock') exists
            description: 'the refusal wrote a lock'.
        self assert: runner commands isEmpty.
        self denyBlamesParley: result
    ]

    testTwoDefineSendsAreTheSameRefusal [
        "Reached a second way - two cascades rather than none - and
         answered by the same sentence, because it is the same
         situation: add cannot tell which file it is looking at."
        | work index original result |
        work := self track: (ManifestEditFixtures
            workDirNamed: 'add-twodefines-work'
            contents: ManifestEditFixtures twoDefinesContents).
        index := self toolsIndex: 'add-twodefines-index'.
        original := self packageIn: work.
        result := self addToolAIn: work source: index.
        self assert: result exitCode = 1.
        self assert: result lines = (Array with:
            (ManifestEditFixtures
                unrecognizedLineFor: ManifestEditFixtures addedName
                constraint: ManifestEditFixtures addedConstraint
                in: work, '/Package.st')).
        self assert: (self packageIn: work) = original.
        self denyBlamesParley: result
    ]

    testAlreadyDeclaredWithADifferentConstraintIsARefusalNamingTheExistingOne [
        "Changing a constraint is an EDIT, and a verb that silently
         overwrote one would be a different verb wearing this name."
        | work index original result |
        work := self track:
            (ManifestEditFixtures declaredWorkDirNamed: 'add-different-work').
        index := self toolsIndex: 'add-different-index'.
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

    testAlreadyDeclaredIdenticallyIsAnIdempotentSuccess [
        "exit 0, one pinned confirmation line, both files byte-identical
         - and the pipeline still runs (§8 decision 48: already-declared
         changes what the verb REPORTS, never what it does). Idempotence
         is what makes add safe in a script."
        | work index runner result |
        work := self track:
            (ManifestEditFixtures declaredWorkDirNamed: 'add-idempotent-work').
        index := self toolsIndex: 'add-idempotent-index'.
        runner := RecordingRunner new.
        result := self resultOf: (Array
                with: 'add' with: ManifestEditFixtures addedName
                with: ManifestEditFixtures addedConstraint
                with: '--source' with: index)
            in: work runner: runner.
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
            description: 'the idempotent add did not rewrite the lock to identical bytes'.
        self deny: runner commands isEmpty
            description: 'already-declared skipped the pipeline - the report may narrow, the contract may not'
    ]

    "---- adding holds the existing pins, and fails atomically ----"

    testAddingDoesNotMoveTheOtherPinsCarriesItsContrast [
        "The lock gains tool-a 1.1.0 and the tool-b tuple is
         byte-identical - AND THE CONTRAST: plain update against the
         identical fixture moves tool-b to 2.1.0, so tool-b was movable
         and holding is what kept it."
        | addWork updateWork index before after |
        addWork := self track:
            (ManifestEditFixtures toolBWorkDirNamed: 'add-hold-add-work').
        updateWork := self track:
            (ManifestEditFixtures toolBWorkDirNamed: 'add-hold-upd-work').
        index := self toolsIndex: 'add-hold-index'.
        before := SelectiveUpdateFixtures packageTuplesIn: addWork.
        self assert: (self addToolAIn: addWork source: index) exitCode = 0.
        after := SelectiveUpdateFixtures packageTuplesIn: addWork.
        1 to: 4 do: [:i |
            self assert: ((after at: 'tool-b') at: i)
                = ((before at: 'tool-b') at: i)
                description: 'the held tool-b tuple changed at position ',
                    i printString].
        self assert: ((after at: 'tool-a') at: 2) = '1.1.0'.
        self assert: ((self resultOf: (Array
                with: 'update' with: '--source' with: index)
            in: updateWork runner: RecordingRunner new) exitCode) = 0.
        self assert: (self lockIn: updateWork)
            = ManifestEditFixtures toolBMovedLockString
            description: 'the contrast is broken: plain update did not move tool-b, so nothing was being held'
    ]

    testAFailedResolutionRestoresTheProjectExactlyAsItStarted [
        "The pinned held-pins line FOLLOWED BY the settled
         ConflictReport narration, composed here through the identical
         narrowed world - AND the atomicity claim asserted on the
         artifact: Package.st read back and compared byte for byte, the
         lock unchanged, nothing fetched."
        | work index runner original held outcome expected result storeRoot |
        work := self track: (ManifestEditFixtures
            heldConflictWorkDirNamed: 'add-atomic-work').
        index := self freshDir: 'add-atomic-index'.
        SelectiveUpdateFixtures populateHeldConflictIndexIn: index.
        runner := RecordingRunner new.
        original := self packageIn: work.
        held := ManifestEditFixtures heldVersionsIn: work.
        outcome := ResolverFixtures
            resolve: ManifestEditFixtures heldConflictRootManifestAfterAdd
            against: ((DirectorySource on: index) snapshot holding: held).
        self deny: outcome isResolution
            description: 'the fixture does not conflict under holding - the law cannot fail'.
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
        storeRoot := CommandLineFixtures storeRootIn: work.
        self assert: (InstallFixtures starFileCountIn: storeRoot) = 0
            description: 'a failed add fetched an archive'.
        self assert: runner commands isEmpty.
        self denyBlamesParley: result
    ]

    "---- the pipeline: install and register, exactly as update does ----"

    testTheVerbInstallsAndRegistersTheWholeResolvedSet [
        | work index runner result storeRoot storedPath |
        work := self track:
            (ManifestEditFixtures toolBWorkDirNamed: 'add-pipe-work').
        index := self toolsIndex: 'add-pipe-index'.
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
            description: 'the registration plan is not the settled update plan over the whole set, silenced'
    ]

    "---- the shared deleted-held-pin diagnosis (the Sprint 12 gap) ----"

    testADeletedHeldPinIsNamedAsSuchByAdd [
        "Not a ConflictReport. §8 decision 47 made the state sound - a
         held version the snapshot cannot describe is offered as
         nothing - and this makes it legible: the real defect is a
         missing index entry, not a version conflict."
        | work index original result |
        work := self track:
            (ManifestEditFixtures deletedPinWorkDirNamed: 'add-deleted-work').
        index := self freshDir: 'add-deleted-index'.
        ManifestEditFixtures populateDeletedPinIndexIn: index.
        original := self packageIn: work.
        result := self addToolAIn: work source: index.
        self assert: result exitCode = 1.
        self assert: result lines = (Array with:
            (ManifestEditFixtures deletedHeldPinLineFor: 'app-y'
                version: '1.0.0')).
        self assert: (self packageIn: work) = original
            description: 'the diagnosis edited the manifest'.
        self assert: (self lockIn: work)
            = ManifestEditFixtures deletedPinLockString.
        self denyBlamesParley: result
    ]

    testADeletedHeldPinIsNamedAsSuchByUpdateToo [
        "One diagnosis, two verbs. update <pkg> answers a narration
         today, which reads as a version conflict when the entry is
         simply gone."
        | work index result |
        work := self track:
            (ManifestEditFixtures deletedPinWorkDirNamed: 'upd-deleted-work').
        index := self freshDir: 'upd-deleted-index'.
        ManifestEditFixtures populateDeletedPinIndexIn: index.
        result := self resultOf: (Array
                with: 'update' with: ManifestEditFixtures addedName
                with: '--source' with: index)
            in: work runner: RecordingRunner new.
        self assert: result exitCode = 1.
        self assert: result lines = (Array with:
            (ManifestEditFixtures deletedHeldPinLineFor: 'app-y'
                version: '1.0.0')).
        self assert: (self lockIn: work)
            = ManifestEditFixtures deletedPinLockString
            description: 'the diagnosis rewrote the lock'.
        self denyBlamesParley: result
    ]

    "---- the argv grammar: add <pkg> <constraint> ----"

    testAddWithNoConstraintAnswersUsage [
        | work index result |
        work := self track:
            (ManifestEditFixtures toolBWorkDirNamed: 'add-arity1-work').
        index := self toolsIndex: 'add-arity1-index'.
        result := self resultOf: (Array
                with: 'add' with: ManifestEditFixtures addedName
                with: '--source' with: index)
            in: work runner: RecordingRunner new.
        self assert: result exitCode = 2.
        self assert: result lines = ManifestEditFixtures addUsageLines
            description: 'add with no constraint answered ',
                result lines printString.
        self assert: (self packageIn: work)
            = ManifestEditFixtures withDependenciesContents
    ]

    testAddWithThreeArgumentsAnswersUsage [
        | work index result |
        work := self track:
            (ManifestEditFixtures toolBWorkDirNamed: 'add-arity3-work').
        index := self toolsIndex: 'add-arity3-index'.
        result := self resultOf: (Array with: 'add' with: 'a' with: 'b'),
                (Array with: 'c' with: '--source' with: index)
            in: work runner: RecordingRunner new.
        self assert: result exitCode = 2.
        self assert: result lines = ManifestEditFixtures addUsageLines
            description: 'add with three arguments answered ',
                result lines printString
    ]

    testAddWithNoSourceAnswersUsage [
        "A source-requiring verb with no source is the settled usage
         answer - with the verbs: line now naming add <pkg>
         <constraint>."
        | runner result |
        runner := RecordingRunner new.
        result := (CLI in: 'tmp/parley-add-nosource-work'
            source: nil
            store: (ContentStore on: 'tmp/parley-add-nosource-store')
            target: 'tmp/parley-add-nosource-target'
            runner: runner) run: #('add' 'tool-a' '^1.0').
        self assert: result exitCode = 2.
        self assert: result lines
            = ManifestEditFixtures addNoSourceUsageLines
            description: 'a source-less add answered ', result lines printString.
        self assert: (CommandLineFixtures does:
            (GrammarFixtures verbsRowIn: result lines)
            include: 'add <pkg> <constraint>')
            description: 'the verbs: line does not name add <pkg> <constraint>'.
        self assert: runner commands isEmpty
    ]
]

Namespace current: Smalltalk.
