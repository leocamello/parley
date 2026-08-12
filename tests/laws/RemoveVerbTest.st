"Parley Sprint 20 - the remove verb's laws (issue #22; Doc B §2.1,
 Doc E §4.1, Doc C §2.2, §8 decisions 47, 49 and 67).

 AN INSERTION THAT RECOGNIZES TOO LITTLE REFUSES; A DELETION THAT
 RECOGNIZES TOO LITTLE DAMAGES. That one sentence is why this file
 exists beside AddVerbTest rather than inside it. add's worst failure
 is a refusal the operator can work around in five seconds; remove's is
 a Package.st that no longer loads, written by the tool, in a file the
 author owns. So the splice is driven at all THREE clause positions -
 first, middle and last - and each is compared against a HAND-WRITTEN
 oracle, never one computed by the splice under test. An oracle
 produced by the same code cannot fail when that code is wrong.

 THE JOIN IS THE SUBJECT, NOT THE CLAUSE (§8 decision 67). Every
 position exercises a different join and each one breaks differently:
 an interior clause leaves a doubled separator, the LAST clause leaves
 `;` immediately before the cascade's closing bracket, and the FIRST
 clause shares its span with the cascade RECEIVER, so the span-verbatim
 splice deletes `pkg` and the take-the-preceding-join splice leaves
 `pkg;` in front of the next message. Three positions, three ways to
 write a file that will not parse.

 THE COMMENT TRAVELS WITH ITS CLAUSE, and both halves are asserted. A
 comment written above a dependency sits INSIDE that dependency's
 clause span and is about that dependency, so removing the dependency
 takes it and removing a different one leaves it exactly where it
 stood. `Preserve every other byte` is a claim about what moves as much
 as about what stays, and a law that only checked what stays would pass
 on a splice that never deleted anything at all.

 THE VERB OWNS EVERYTHING RISKY, exactly as it does for add.
 ManifestEditor answers text or nil; the CLI writes it, re-reads it
 through the settled ManifestFile load:, compares the manifests, and
 restores the original bytes on any disagreement. So every `nothing
 changed` claim below is asserted ON THE ARTIFACT - the file read back
 and compared byte for byte - and never inferred from an exit code.

 ROLLBACK IS REACHED HONESTLY. ghostContents declares a package the
 index never published, so a remove that has already rewritten
 Package.st then fails to resolve. The editor is never broken to reach
 the rollback path.

 DECLARED PASSES IN RED (issue #22): NONE in this file. Every law here
 either sends ManifestEditor a selector that does not exist yet - which
 aborts as an ERROR at that send - or drives the two-element remove
 argv, which the pre-sprint tree answers with the usage lines at exit 2
 where these laws demand 0 or 1. No law asserts exit 2, because an
 unknown argv already answers exit 2 and such a law would pass in red
 while testing nothing.

 Every fixture path is under tmp/, unique per label, removed
 recursively in tearDown - and tearDown unlocks before it removes,
 which PathFixtures removeTree: already does. Nothing here spawns
 (every runner is a RecordingRunner) and no network is contacted."

Namespace current: Parley.

TestCase subclass: RemoveVerbTest [
    | fixtureDirs |

    <comment: 'Laws for parley remove <pkg> and the manifest editor''s
deletion: the splice at all three clause positions against hand-written
oracles, the separator each position owns, the comment that travels
with its clause, the two refusals with the file byte-identical,
atomicity across the manifest and the lock, and the remaining pins held
where they stood.'>

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

    removeIndex: aLabel [
        | path |
        path := self freshDir: aLabel.
        RemoveFixtures populateRemoveIndexIn: path.
        ^path
    ]

    resultOf: anArgvArray in: aWorkDir [
        ^(CommandLine in: aWorkDir runner: RecordingRunner new)
            run: anArgvArray
    ]

    remove: aName in: aWorkDir source: anIndexDir [
        ^self resultOf: (Array with: 'remove' with: aName
            with: '--source' with: anIndexDir) in: aWorkDir
    ]

    update: aWorkDir source: anIndexDir [
        ^self resultOf: (Array with: 'update'
            with: '--source' with: anIndexDir) in: aWorkDir
    ]

    packageIn: aWorkDir [
        ^RemoveFixtures packageIn: aWorkDir
    ]

    lockIn: aWorkDir [
        ^RemoveFixtures lockIn: aWorkDir
    ]

    "---- the splice on TEXT: three positions, three joins ----"

    testRemovingAnInteriorClauseTakesItsSeparatorWithIt [
        "The ordinary interior join, byte for byte against a hand-written
         oracle. Everything the author wrote around the clause - a
         header comment, an interior comment, a blank line and six-space
         indentation - stands untouched."
        | editor |
        editor := ManifestEditor on: RemoveFixtures authoredThreeContents.
        self assert: editor isRecognized
            description: 'the fixture is not the recognized shape'.
        self assert: (editor textWithoutDependency: RemoveFixtures removedName)
            = RemoveFixtures authoredThreeWithoutMiddle
            description: 'the interior splice did not answer the hand-written text'
    ]

    testRemovingTheLastClauseTakesTheSeparatorBeforeIt [
        "THE SCENARIO A SPLICE THAT DELETES ONLY THE CLAUSE PASSES THE
         LAW ABOVE AND THEN FAILS. There is no separator after the last
         clause, so the one that binds it is the one before it - and a
         splice that left it behind would put `;` immediately in front
         of the cascade's closing bracket."
        | editor removed |
        editor := ManifestEditor on: RemoveFixtures authoredThreeContents.
        removed := editor textWithoutDependency: RemoveFixtures lastName.
        self assert: removed = RemoveFixtures authoredThreeWithoutLast
            description: 'the last-clause splice did not answer the hand-written text'.
        self deny: (ManifestEditFixtures contains: removed line: ';')
            description: 'a separator was left standing on a line of its own'
    ]

    testRemovingTheFirstClauseKeepsTheCascadeReceiver [
        "The recognizer splits clauses from the block argument bar, so
         clause one holds the cascade RECEIVER as well as its message.
         Deleting the span verbatim deletes `pkg`; deleting the
         PRECEDING join leaves `pkg;` in front of the next message.
         Both write a file that does not parse, so this position owns
         the separator AFTER it instead."
        | editor |
        editor := ManifestEditor on: RemoveFixtures receiverFirstContents.
        self assert: editor isRecognized
            description: 'the receiver-first fixture is not recognized'.
        self assert: (editor textWithoutDependency: RemoveFixtures firstName)
            = RemoveFixtures receiverFirstWithoutDependency
            description: 'the first-clause splice did not answer the hand-written text'
    ]

    testRemovingTheOnlyDependencyAnswersAValidCascade [
        "Ordinary success, not a special case: what remains declares no
         dependency and is still a manifest."
        | editor |
        editor := ManifestEditor on: RemoveFixtures soloContents.
        self assert: (editor textWithoutDependency: RemoveFixtures firstName)
            = RemoveFixtures soloWithoutDependency
            description: 'the only-dependency splice did not answer the hand-written text'
    ]

    "---- what moves, and what stays ----"

    testTheCommentAboveAClauseTravelsWithThatClause [
        "Both halves of `preserve every other byte`. The interior
         comment is about tool-b and sits inside tool-b's span, so
         removing tool-b takes it - and removing tool-c leaves it
         exactly where the author put it, indentation included."
        | editor withoutFirst withoutMiddle |
        editor := ManifestEditor on: RemoveFixtures authoredThreeContents.
        withoutFirst := editor textWithoutDependency: RemoveFixtures firstName.
        withoutMiddle := editor
            textWithoutDependency: RemoveFixtures removedName.
        self assert: withoutFirst = RemoveFixtures authoredThreeWithoutFirst
            description: 'removing the commented clause did not answer the hand-written text'.
        self deny: (ManifestEditFixtures contains: withoutFirst
            line: RemoveFixtures authoredInteriorCommentLine)
            description: 'the comment about the removed dependency was left behind'.
        self assert: (ManifestEditFixtures contains: withoutMiddle
            line: RemoveFixtures authoredInteriorCommentLine)
            description: 'removing a different clause destroyed the comment'.
        self assert: (ManifestEditFixtures contains: withoutFirst
            line: RemoveFixtures authoredHeaderCommentLine)
            description: 'the header comment did not survive'
    ]

    testTheEditorAnswersANewValueAndNeverMutatesItsText [
        "Structural immutability: an operation answers a new value and
         the receiver still answers what it was handed, so two removals
         from one editor are independent."
        | editor first second |
        editor := ManifestEditor on: RemoveFixtures authoredThreeContents.
        first := editor textWithoutDependency: RemoveFixtures removedName.
        second := editor textWithoutDependency: RemoveFixtures lastName.
        self assert: first = RemoveFixtures authoredThreeWithoutMiddle
            description: 'the first removal was disturbed by the second'.
        self assert: second = RemoveFixtures authoredThreeWithoutLast
            description: 'the second removal read a mutated text'.
        self assert: (editor constraintFor: RemoveFixtures removedName)
            = '^1.0'
            description: 'the editor forgot what its own text declares'
    ]

    testEverySplicedTextLoadsThroughTheReaderThatOwnsTheMeaning [
        "The splice is checked by the same authority that will consume
         the file (Doc B §2.1): a textual edit that is not read back by
         the reader that decides what a Package.st MEANS is a hope.

         IT LOADS THE SPLICE'S OWN ANSWER, not the hand-written oracle
         beside it. Writing the oracle out and loading that would be a
         law about this file's fixtures - true today, and unable to fail
         when the splice is wrong, which is the whole reason the byte
         comparisons above exist separately."
        | rows |
        rows := (Array
            with: (Array with: 'rvt-load-middle'
                with: RemoveFixtures authoredThreeContents
                with: RemoveFixtures removedName with: 2)
            with: (Array with: 'rvt-load-last'
                with: RemoveFixtures authoredThreeContents
                with: RemoveFixtures lastName with: 2)),
            (Array
                with: (Array with: 'rvt-load-first'
                    with: RemoveFixtures authoredThreeContents
                    with: RemoveFixtures firstName with: 2)
                with: (Array with: 'rvt-load-solo'
                    with: RemoveFixtures soloContents
                    with: RemoveFixtures firstName with: 0)
                with: (Array with: 'rvt-load-receiver'
                    with: RemoveFixtures receiverFirstContents
                    with: RemoveFixtures firstName with: 0)).
        rows do: [:row |
            | spliced work manifest |
            spliced := (ManifestEditor on: (row at: 2))
                textWithoutDependency: (row at: 3).
            self deny: spliced isNil
                description: (row at: 1), ' was refused rather than spliced'.
            work := self track: (RemoveFixtures
                workDirNamed: (row at: 1) contents: spliced).
            manifest := ManifestFile load: work, '/Package.st'.
            self assert: manifest dependencies size = (row at: 4)
                description: (row at: 1), ' loaded ',
                    manifest dependencies size printString,
                    ' dependencies'.
            self assert: (manifest dependencies
                detect: [:dep | dep name = (row at: 3)]
                ifNone: [nil]) isNil
                description: (row at: 1),
                    ' still declares the removed dependency']
    ]

    "---- the two refusals: nil, and the file untouched ----"

    testAnUnrecognizedShapeAnswersNil [
        "Recognize or refuse. Two complete cascades give the editor no
         way to choose that is not a guess."
        | editor |
        editor := ManifestEditor on: ManifestEditFixtures twoDefinesContents.
        self deny: editor isRecognized.
        self assert: (editor textWithoutDependency: RemoveFixtures firstName)
            isNil
            description: 'the editor spliced a shape it does not recognize'
    ]

    testRemovingAnUndeclaredNameAnswersNil [
        "A recognized cascade that simply does not declare the name.
         There is nothing to delete, and inventing a span to delete is
         how a manifest gets eaten."
        | editor |
        editor := ManifestEditor on: RemoveFixtures authoredThreeContents.
        self assert: (editor
            textWithoutDependency: RemoveFixtures undeclaredName) isNil
            description: 'the editor deleted something for a name it does not declare'
    ]

    "---- the verb: the artifacts, never the exit code ----"

    testTheVerbWritesTheRemovedTextAndReportsTheRemainingPins [
        | work index result |
        work := self track: (RemoveFixtures
            authoredWorkDirNamed: 'rvt-verb-work').
        index := self removeIndex: 'rvt-verb-index'.
        result := self remove: RemoveFixtures removedName
            in: work source: index.
        self assert: result exitCode = 0
            description: 'remove answered exit ', result exitCode printString,
                ': ', result lines printString.
        self assert: (self packageIn: work)
            = RemoveFixtures authoredThreeWithoutMiddle
            description: 'the author''s file did not survive the verb byte for byte'.
        self assert: result lines = RemoveFixtures pinsAfterRemovingMiddle
            description: 'remove reported ', result lines printString
    ]

    testTheVerbRemovesTheLastClauseThroughTheWholePipeline [
        "The dangling-semicolon case driven through the verb rather than
         the editor: written, re-read by the settled loader, resolved,
         locked."
        | work index result |
        work := self track: (RemoveFixtures
            authoredWorkDirNamed: 'rvt-verblast-work').
        index := self removeIndex: 'rvt-verblast-index'.
        result := self remove: RemoveFixtures lastName
            in: work source: index.
        self assert: result exitCode = 0
            description: 'remove answered exit ', result exitCode printString,
                ': ', result lines printString.
        self assert: (self packageIn: work)
            = RemoveFixtures authoredThreeWithoutLast
            description: 'the last-clause removal did not survive the verb'.
        self assert: result lines = RemoveFixtures pinsAfterRemovingLast
            description: 'remove reported ', result lines printString
    ]

    testAnUnrecognizedShapeIsRefusedWithTheFileByteIdentical [
        | work index original result |
        work := self track: (RemoveFixtures
            unrecognizedWorkDirNamed: 'rvt-refuse-work').
        index := self removeIndex: 'rvt-refuse-index'.
        original := self packageIn: work.
        result := self remove: RemoveFixtures firstName
            in: work source: index.
        self assert: result exitCode = 1
            description: 'an unrecognized shape answered exit ',
                result exitCode printString.
        self assert: result lines = (Array with: (RemoveFixtures
            unrecognizedLineFor: RemoveFixtures firstName
            in: work, '/Package.st'))
            description: 'the refusal answered ', result lines printString.
        self assert: (self packageIn: work) = original
            description: 'a refused remove rewrote Package.st'
    ]

    testAnUndeclaredNameIsRefusedAndNothingIsWritten [
        "Nothing is written - not the manifest, and not the lock. Both
         are asserted, because a verb that left the manifest alone and
         rewrote the lock would have manufactured exactly the state
         PinVerification exists to call broken."
        | work index original lock result |
        work := self track: (RemoveFixtures
            soloWorkDirNamed: 'rvt-undeclared-work').
        index := self removeIndex: 'rvt-undeclared-index'.
        original := self packageIn: work.
        lock := self lockIn: work.
        result := self remove: RemoveFixtures undeclaredName
            in: work source: index.
        self assert: result exitCode = 1
            description: 'an undeclared name answered exit ',
                result exitCode printString.
        self assert: result lines = (Array with: (RemoveFixtures
            notDeclaredLineFor: RemoveFixtures undeclaredName))
            description: 'the diagnosis answered ', result lines printString.
        self assert: (self packageIn: work) = original
            description: 'Package.st was rewritten'.
        self assert: (self lockIn: work) = lock
            description: 'parley.lock was rewritten'
    ]

    "---- atomicity, asserted on the artifacts ----"

    testAFailedResolutionRestoresBothArtifactsByteForByte [
        "The manifest is rewritten BEFORE the resolution runs, so this
         is the path where a non-atomic build leaves a manifest the lock
         does not match. Asserted on the two files, never on the exit
         code."
        | work index original lock result |
        work := self track: (RemoveFixtures
            ghostWorkDirNamed: 'rvt-atomic-work').
        index := self removeIndex: 'rvt-atomic-index'.
        original := self packageIn: work.
        lock := self lockIn: work.
        result := self remove: RemoveFixtures removedName
            in: work source: index.
        self deny: result exitCode = 0
            description: 'a remove whose resolution failed answered exit 0'.
        self deny: (result lines
            detect: [:line | CommandLineFixtures does: line include: 'ghost']
            ifNone: [nil]) isNil
            description: 'the verb never reached the resolution: ',
                result lines printString.
        self assert: (self packageIn: work) = original
            description: 'Package.st was left edited after a failed resolution'.
        self assert: (self lockIn: work) = lock
            description: 'parley.lock moved after a failed resolution'
    ]

    "---- holding the remaining pins (Doc C §2.2, the fourth
          application), with its contrast ----"

    testRemovingHoldsTheRemainingPinsTupleByTuple [
        "Removing one dependency is not a licence to move the others.
         Asserted tuple by tuple against the lock as it stood, never by
         comparing whole locks: the removed package's tuple is gone, so
         the two files necessarily differ and a whole-file comparison
         could only ever say so."
        | work index before after |
        work := self track: (RemoveFixtures
            fourPinsWorkDirNamed: 'rvt-hold-work').
        index := self removeIndex: 'rvt-hold-index'.
        before := RemoveFixtures lockTuplesIn: work.
        self assert: (self remove: RemoveFixtures removedName
            in: work source: index) exitCode = 0.
        after := RemoveFixtures lockTuplesIn: work.
        self assert: (RemoveFixtures
            tupleNamed: RemoveFixtures removedName in: after) isNil
            description: 'the removed package is still pinned'.
        #('tool-a' 'tool-b' 'tool-d') do: [:name |
            self assert: (RemoveFixtures tupleNamed: name in: after)
                = (RemoveFixtures tupleNamed: name in: before)
                description: name, ' moved: ',
                    (RemoveFixtures tupleNamed: name in: after) printString].
        self assert: ((RemoveFixtures
            tupleNamed: RemoveFixtures movableName in: after) at: 2)
            = RemoveFixtures movableHeldVersion
            description: 'the movable pin did not stay where it was pinned'.
        self carryTheContrastFor: 'rvt-hold'
    ]

    carryTheContrastFor: aLabel [
        "THE CONTRAST, INSIDE THE LAW IT GUARDS. A fixture where nothing
         else COULD move proves nothing, so plain update is run against
         an identical project and REQUIRED to move the pin remove held.

         It lives here rather than in a selector of its own because a
         guard with its own selector passes on its own before the verb
         it guards exists, and a law that passes in red is a law nobody
         has tested."
        | work index after |
        work := self track: (RemoveFixtures
            fourPinsWorkDirNamed: aLabel, '-contrast-work').
        index := self removeIndex: aLabel, '-contrast-index'.
        self assert: (self update: work source: index) exitCode = 0
            description: 'the contrast update failed'.
        after := RemoveFixtures lockTuplesIn: work.
        self assert: ((RemoveFixtures
            tupleNamed: RemoveFixtures movableName in: after) at: 2)
            = RemoveFixtures movableFreeVersion
            description: 'plain update did not move the movable pin - the contrast is empty'
    ]

    "---- the only dependency, through the verb ----"

    testRemovingTheOnlyDependencyRewritesTheLockWithNoPins [
        | work index result |
        work := self track: (RemoveFixtures
            soloWorkDirNamed: 'rvt-solo-work').
        index := self removeIndex: 'rvt-solo-index'.
        result := self remove: RemoveFixtures firstName
            in: work source: index.
        self assert: result exitCode = 0
            description: 'removing the only dependency answered exit ',
                result exitCode printString, ': ', result lines printString.
        self assert: (self packageIn: work)
            = RemoveFixtures soloWithoutDependency
            description: 'the solo manifest did not survive byte for byte'.
        self assert: (RemoveFixtures lockTuplesIn: work) isEmpty
            description: 'the rewritten lock still pins something'
    ]
]

Namespace current: Smalltalk.
