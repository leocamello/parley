"Parley Sprint 12 — acceptance scenarios S1-S12 from GitHub issue #14.
 Each scenario Sn maps to exactly one selector starting with testSn_
 (enforced by the wrap traceability gate).

 The milestone: MOVE ONE DEPENDENCY WITHOUT MOVING THE REST. parley
 update moves everything — the honest MVP default and the wrong tool
 for the commonest real request. update <pkg> resolves the ordinary
 way against a snapshot narrowed to hold every OTHER pin at its locked
 version (Doc C §2.2): the Resolver, BacktrackingStrategy and
 ConstraintLedger are neither modified nor entered differently — a
 selective update is a normal resolution of a smaller world, which is
 what hands a future PubGrubStrategy selective update for free (§8
 decision 46, the decision-37 trick applied a second time).

 THE CONTRAST CLAUSES ARE THE SPRINT. S2, S8 and S10 each run plain
 update against the IDENTICAL fixture and require the different
 outcome: tool-b really was movable (S2), the S8 index really is
 satisfiable when nothing is held, and plain update really does move
 off the retired pin (S10). Without them S2 passes on a fixture where
 nothing else could move, S8 passes on an index that conflicts anyway,
 and S10 passes because nothing was retired — a proof that cannot
 fail proves nothing (the Sprint 11 trap-correctness discipline).

 BYTE-IDENTITY IS ASSERTED TUPLE BY TUPLE (S3): name, version and
 #sha256 digest, each compared against the pre-update lock. 'The lock
 changed' and 'the lock contains tool-b 2.0.0' both pass on a lock
 whose digest silently changed.

 HELD BEATS RETIRED (S10) IS A RULING, NOT AN OVERSIGHT: the §2.1
 retirement filter answers what a FRESH resolution may pick, and a
 held pin is not being picked, it is being kept — so an unrelated
 retirement never fails a selective update, and check remains the verb
 that reports retirement as a problem.

 DECLARED PASSES IN RED (issue #14): NONE in this file, and none in
 the sprint's law suites either (each declares so in its own class
 comment). Every scenario consumes the update <pkg> argv row or
 IndexSnapshot>>holding:, and neither exists against the pre-sprint
 tree: the two-element argv falls through to the settled usage answer
 (exit 2, OLD verbs: line) where S1-S11 demand 0 or 1 and S12 demands
 the NEW verbs: line, and holding: fails as a doesNotUnderstand.

 S11 registers through the recording runner; no scenario spawns
 bin/parley-main.st and none runs git. No test contacts a network,
 ever. Every fixture path is under tmp/, unique per test, removed
 recursively in tearDown; the developer image is never mutated."

Namespace current: Parley.

TestCase subclass: Sprint12AcceptanceTest [
    | fixtureDirs |

    <comment: 'Acceptance scenarios for Sprint 12: selective parley
update <pkg> — the named package moves, every other pin is
byte-identical, a transitive dependency can be named, the three
diagnoses answer exit 1, already-newest is a byte-identical success,
a held pin outranks a retirement, the pipeline installs and registers
behind the verb, and the argv grammar gains update [<pkg>]. The
contrast halves of S2, S8 and S10 run plain update against the
identical fixture.'>

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

    pinnedToolsWork: aLabel [
        ^self track:
            (SelectiveUpdateFixtures pinnedToolsWorkDirNamed: aLabel)
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

    plainUpdateIn: aWorkDir source: anIndexDir [
        ^self resultOf: (Array
                with: 'update' with: '--source' with: anIndexDir)
            in: aWorkDir runner: RecordingRunner new
    ]

    lockContentsIn: aWorkDir [
        ^SelectiveUpdateFixtures lockContentsIn: aWorkDir
    ]

    versionPinnedFor: aName in: aWorkDir [
        ^((SelectiveUpdateFixtures packageTuplesIn: aWorkDir)
            at: aName) at: 2
    ]

    assertTuple: aTuple equals: anOtherTuple for: aName [
        "Tuple-by-tuple byte-identity: name, version, the #sha256
         marker and the digest, each asserted by value."
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

    "---- S1-S2: the named package moves, and ONLY the named package ----"

    testS1_ASelectiveUpdateMovesTheNamedPackage [
        | work index result |
        work := self pinnedToolsWork: 's12-s1-work'.
        index := self toolsIndex: 's12-s1-index'.
        result := self updateOf: 'tool-a' in: work source: index.
        self assert: result exitCode = 0.
        self assert: (self versionPinnedFor: 'tool-a' in: work) = '1.1.0'
    ]

    testS2_AndItMovesOnlyTheNamedPackage [
        "The lock still pins tool-b 2.0.0 — AND THE CONTRAST THAT MAKES
         THIS MEAN SOMETHING: plain update against the identical
         fixture moves tool-b to 2.1.0, so tool-b was movable and
         holding is what kept it. A fixture where nothing else could
         move proves nothing."
        | selWork plainWork index result |
        selWork := self pinnedToolsWork: 's12-s2-sel-work'.
        plainWork := self pinnedToolsWork: 's12-s2-plain-work'.
        index := self toolsIndex: 's12-s2-index'.
        result := self updateOf: 'tool-a' in: selWork source: index.
        self assert: result exitCode = 0.
        self assert: (self versionPinnedFor: 'tool-b' in: selWork) = '2.0.0'
            description: 'holding did not keep tool-b at 2.0.0'.
        result := self plainUpdateIn: plainWork source: index.
        self assert: result exitCode = 0.
        self assert: (self versionPinnedFor: 'tool-b' in: plainWork) = '2.1.0'
            description: 'the contrast is broken: plain update did not move tool-b, so nothing was being held'.
        self assert: (self lockContentsIn: plainWork)
            = SelectiveUpdateFixtures toolsAllMovedLockString
    ]

    testS3_ThePinsThatDidNotMoveAreByteIdentical [
        "The new lock differs from the old in EXACTLY the tool-a tuple:
         every other tuple — name, version, #sha256 digest — is
         byte-identical, asserted tuple by tuple, never as 'the lock
         changed'."
        | work index before after result |
        work := self pinnedToolsWork: 's12-s3-work'.
        index := self toolsIndex: 's12-s3-index'.
        before := SelectiveUpdateFixtures packageTuplesIn: work.
        result := self updateOf: 'tool-a' in: work source: index.
        self assert: result exitCode = 0.
        after := SelectiveUpdateFixtures packageTuplesIn: work.
        self assert: after keys asSortedCollection asArray
            = before keys asSortedCollection asArray
            description: 'the update changed WHICH packages are pinned'.
        self assertTuple: (after at: 'tool-b')
            equals: (before at: 'tool-b') for: 'tool-b'.
        self assert: ((after at: 'tool-a') at: 2) = '1.1.0'.
        self deny: ((after at: 'tool-a') at: 4) = ((before at: 'tool-a') at: 4)
            description: 'tool-a moved but kept its old digest'
    ]

    testS4_ATransitiveDependencyCanBeNamed [
        "The settled diamond: the root declares a and b, never c — and
         update c moves it, with a and b byte-identical. What is PINNED
         is updatable; being declared is not the test."
        | work index before after result |
        work := self track: (SelectiveUpdateFixtures
            diamondPinnedWorkDirNamed: 's12-s4-work').
        index := self freshDir: 's12-s4-index'.
        InstallFixtures populateInstallDiamondIn: index.
        before := SelectiveUpdateFixtures packageTuplesIn: work.
        result := self updateOf: 'c' in: work source: index.
        self assert: result exitCode = 0.
        after := SelectiveUpdateFixtures packageTuplesIn: work.
        self assert: ((after at: 'c') at: 2) = '2.4.0'
            description: 'the named transitive dependency did not move'.
        self assertTuple: (after at: 'a') equals: (before at: 'a') for: 'a'.
        self assertTuple: (after at: 'b') equals: (before at: 'b') for: 'b'
    ]

    "---- S5-S6: the operator-side diagnoses ----"

    testS5_APackageThatIsNotPinnedIsADiagnosis [
        "One line naming the package and the lock — the operator's
         question about a package they do not have. Never exit 70,
         never a backtrace."
        | work index result |
        work := self pinnedToolsWork: 's12-s5-work'.
        index := self toolsIndex: 's12-s5-index'.
        result := self updateOf: 'kernel-nonexistent' in: work source: index.
        self assert: result exitCode = 1.
        self assert: result lines = (Array with:
            (SelectiveUpdateFixtures notPinnedLineFor: 'kernel-nonexistent')).
        self denyBlamesParley: result
    ]

    testS6_ALocklessProjectIsADiagnosisNotAFreshResolve [
        "There is nothing to hold selectively when nothing is pinned,
         and silently doing a full resolve would be the opposite of
         what was asked. The pinned missing-lock line names parley
         resolve; no lock is written."
        | work index result |
        work := self track:
            (SelectiveUpdateFixtures toolsWorkDirNamed: 's12-s6-work').
        index := self toolsIndex: 's12-s6-index'.
        result := self updateOf: 'tool-a' in: work source: index.
        self assert: result exitCode = 1.
        self assert: result lines
            = (Array with: SelectiveUpdateFixtures missingLockLine).
        self deny: (File name: work, '/parley.lock') exists
            description: 'the diagnosis resolved fresh and wrote a lock'.
        self denyBlamesParley: result
    ]

    testS7_AlreadyNewestIsASuccessThatSaysSo [
        "exit 0, one pinned confirmation line naming the package and
         version, and the lock byte-identical to what it was."
        | work index result |
        work := self track: (SelectiveUpdateFixtures
            newestToolsWorkDirNamed: 's12-s7-work').
        index := self toolsIndex: 's12-s7-index'.
        result := self updateOf: 'tool-a' in: work source: index.
        self assert: result exitCode = 0.
        self assert: result lines = (Array with:
            (SelectiveUpdateFixtures alreadyNewestLineFor: 'tool-a'
                version: '1.1.0')).
        self assert: (self lockContentsIn: work)
            = SelectiveUpdateFixtures toolsMovedLockString
            description: 'the lock is not byte-identical after an already-newest update'
    ]

    testS8_WhenHoldingMakesTheMoveImpossibleTheOperatorIsToldThatIsWhy [
        "exit 1, the pinned held-pins line FOLLOWED BY the settled
         ConflictReport narration, unmodified — composed through the
         identical narrowed world, because the narration is the
         resolver's own value. AND THE CONTRAST: plain update against
         the identical fixture succeeds by moving app-y to 1.1.0, so
         the conflict is caused by holding, not by the index."
        | selWork plainWork index held outcome expected result |
        selWork := self track: (SelectiveUpdateFixtures
            heldConflictWorkDirNamed: 's12-s8-sel-work').
        plainWork := self track: (SelectiveUpdateFixtures
            heldConflictWorkDirNamed: 's12-s8-plain-work').
        index := self freshDir: 's12-s8-index'.
        SelectiveUpdateFixtures populateHeldConflictIndexIn: index.
        held := SelectiveUpdateFixtures heldVersionsIn: selWork
            except: 'app-x'.
        outcome := ResolverFixtures resolve:
            SelectiveUpdateFixtures heldConflictRootManifest
            against: ((DirectorySource on: index) snapshot holding: held).
        self deny: outcome isResolution
            description: 'the fixture does not conflict under holding'.
        expected := (Array with: SelectiveUpdateFixtures heldPinsLine),
            (ExecFixtures linesOf: outcome printString).
        result := self updateOf: 'app-x' in: selWork source: index.
        self assert: result exitCode = 1.
        self assert: result lines = expected.
        self denyBlamesParley: result.
        result := self plainUpdateIn: plainWork source: index.
        self assert: result exitCode = 0
            description: 'the contrast is broken: the index conflicts even without holding'.
        self assert: (self versionPinnedFor: 'app-y' in: plainWork) = '1.1.0'.
        self assert: (self lockContentsIn: plainWork)
            = SelectiveUpdateFixtures heldConflictMovedLockString
    ]

    testS9_NarrowingAnswersANewSnapshotAndLeavesTheReceiverAlone [
        "The answer offers only 1.5.0 for c; the RECEIVER still offers
         all three; unheld packages are unaffected in both. Structural
         immutability, asserted rather than assumed."
        | snapshot held narrowed sortedOf |
        sortedOf := [:snap :name | (((snap versionsOf: name)
            collect: [:each | each printString]) asSortedCollection)
                asArray].
        snapshot := ResolverFixtures satisfiableDiamondSnapshot.
        held := Dictionary new.
        held at: 'c' put: (Version fromString: '1.5.0').
        narrowed := snapshot holding: held.
        self assert: (sortedOf value: narrowed value: 'c')
            = (Array with: '1.5.0').
        self assert: (sortedOf value: snapshot value: 'c')
            = (Array with: '1.5.0' with: '2.4.0' with: '3.0.0')
            description: 'holding: mutated its receiver'.
        self assert: (sortedOf value: narrowed value: 'a')
            = (Array with: '1.0.0').
        self assert: (sortedOf value: snapshot value: 'a')
            = (Array with: '1.0.0')
    ]

    testS10_AHeldPinThatIsRetiredIsStillHeld [
        "exit 0 and kernel-json still pinned at 0.3.2: an unrelated
         retirement never fails a selective update (§8 decision 46 —
         held beats retired; a held pin is being kept, not picked).
         AND THE CONTRAST: plain update against the identical fixture
         moves off 0.3.2, because fresh resolution IS where the
         retirement filter applies."
        | selWork plainWork index result |
        selWork := self track: (SelectiveUpdateFixtures
            retiredHeldWorkDirNamed: 's12-s10-sel-work').
        plainWork := self track: (SelectiveUpdateFixtures
            retiredHeldWorkDirNamed: 's12-s10-plain-work').
        index := self freshDir: 's12-s10-index'.
        SelectiveUpdateFixtures populateRetiredHeldIndexIn: index.
        result := self updateOf: 'tool-a' in: selWork source: index.
        self assert: result exitCode = 0
            description: 'an unrelated retirement failed a selective update'.
        self assert: (self versionPinnedFor: 'kernel-json' in: selWork)
            = '0.3.2'.
        self assert: (self lockContentsIn: selWork)
            = SelectiveUpdateFixtures retiredHeldMovedLockString.
        result := self plainUpdateIn: plainWork source: index.
        self assert: result exitCode = 0.
        self assert: (self versionPinnedFor: 'kernel-json' in: plainWork)
            = '0.3.1'
            description: 'the contrast is broken: plain update did not move off the retired pin, so nothing was retired'.
        self assert: (self lockContentsIn: plainWork)
            = SelectiveUpdateFixtures retiredHeldFreshLockString
    ]

    testS11_TheVerbInstallsAndRegistersExactlyAsUpdateDoes [
        "The moved package's archive is fetched and hash-verified into
         the store, the registration plan runs through the recording
         runner — the settled Doc D §4 shape over the whole resolved
         set — and the settled update pipeline is otherwise unchanged."
        | work index runner result storeRoot storedPath |
        work := self pinnedToolsWork: 's12-s11-work'.
        index := self toolsIndex: 's12-s11-index'.
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
            = SelectiveUpdateFixtures archiveBytesToolA110
            description: 'the stored archive is not the fetched bytes'.
        self assert: runner commands
            = (ChatterFixtures silencedPlan:
                (SelectiveUpdateFixtures toolsMovedRegistrationPlanIn: work))
            description: 'the registration plan is not the settled update plan, silenced'
    ]

    testS12_TheArgvGrammar [
        "update tool-a with no --source, and update a b with one, both
         answer the pinned usage lines at exit 2; the usage verbs:
         line names update [<pkg>]. Bare update is unchanged — the
         settled laws are what prove that."
        | work index result |
        result := (CLI in: 'tmp/parley-s12-s12-work'
            source: nil
            store: (ContentStore on: 'tmp/parley-s12-s12-store')
            target: 'tmp/parley-s12-s12-target'
            runner: RecordingRunner new) run: #('update' 'tool-a').
        self assert: result exitCode = 2.
        self assert: result lines
            = SelectiveUpdateFixtures selectiveUsageLines.
        self assert: ((result lines at: 2) indexOf: $|) > 0.
        self assert: (CommandLineFixtures does: (result lines at: 2)
            include: 'update [<pkg>]')
            description: 'the verbs: line does not name update [<pkg>]'.
        work := self pinnedToolsWork: 's12-s12-work'.
        index := self toolsIndex: 's12-s12-index'.
        result := self resultOf: (Array
                with: 'update' with: 'a' with: 'b'
                with: '--source' with: index)
            in: work runner: RecordingRunner new.
        self assert: result exitCode = 2.
        self assert: result lines
            = SelectiveUpdateFixtures selectiveUsageLines
    ]
]

Namespace current: Smalltalk.
