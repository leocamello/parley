"Parley Sprint 17 — the chokepoint's own laws (issue #19; Doc E §4.1,
 §8 decision 59 as amended).

 Parley.PathGuard is THE SINGLE SITE IN PARLEY THAT PERFORMS FILE I/O.
 Everything else this sprint delivers is a caller of it, so a wrong
 shape here would be re-done eight times — which is why it is built
 first and alone, and why these laws must pass before any caller
 exists.

 IT DOES TWO THINGS, AND NEITHER ONE ALONE IS ENOUGH.

 It PRECHECKS, so a refusal happens BEFORE anything is created. That is
 the atomicity publish and add need: a check folded into the write can
 only report a failure the write already caused, and by then the stage
 directory exists and the manifest has been replaced.

 And it TRANSLATES, wrapping the operation itself in a BROAD catch that
 turns any error into the boundary's own declared refusal naming the
 path. A precheck alone enumerates the failure modes somebody thought
 of — the mistake one level down from the one this sprint exists to
 correct — and on this toolchain it demonstrably does not hold: a write
 to a read-only file raises a catchable SystemExceptions.FileError, but
 reading a DIRECTORY raises SystemExceptions.WrongClass and escapes a
 FileError handler. Enumerating error classes is the same trap as
 enumerating states, so nothing here enumerates either.

 BROAD IS CORRECT, AND IT DOES NOT CONTRADICT §8 DECISION 52. That
 decision governs a catch that DEFERS to another boundary, which must
 name that boundary's errors and no others. This catch OWNS the
 diagnosis, and the block it guards contains nothing but the operation.
 The discriminator is exactly that, and testTheGuardedBlockHoldsOnly
 TheOperation is the law that keeps it true.

 THE PREDICATE TRAP, PROBED (3.2.5): isWriteable answers false for a
 path that DOES NOT EXIST exactly as it does for a read-only one.
 Absence is not unwritability. A single-predicate write check turns
 every first resolve in a fresh project into a permissions error, which
 is the Sprint 16 isFile trap one predicate over and the thing the
 obvious implementation breaks first. Hence two predicates, and hence
 testTheCreatePredicateAcceptsAnAbsentPath.

 DECLARED PASSES IN RED: none. Every law in this file fails against the
 pre-sprint tree, because Parley.PathGuard does not exist there.

 Every fixture path is under tmp/, unique per test, and torn down
 through PathFixtures removeTree:, which UNLOCKS the tree first — a
 read-only fixture directory survives the settled remover and poisons
 the next run. Nothing here spawns a process and nothing contacts a
 network."

Namespace current: Parley.

TestCase subclass: PathGuardTest [
    | fixtureDirs |

    <comment: 'Laws for Parley.PathGuard: the overwrite, create and
read predicates with their absent-path guards, the precheck firing
before the operation, and the broad translation at the seam — proved
against a kernel WrongClass and against an error class invented by this
suite, which nothing in src/ knows exists.'>

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

    fileIn: aDir named: aBaseName [
        SourceFixtures write: 'contents' toFile: aBaseName in: aDir.
        ^aDir, '/', aBaseName
    ]

    refusalCatching: aBlock [
        "Answer the InventedIoError-free refusal the guard produced, as
         a String: the whole point of every law below is that SOME
         declared refusal arrives, carrying the path, rather than the
         raw kernel error."
        ^[aBlock value. nil]
            on: PathRefusal
            do: [:e | e messageText]
    ]

    "---- the overwrite predicate: an existing file, writable ----"

    testTheOverwritePredicateAcceptsAWritableFile [
        | dir path |
        dir := self freshDir: 'guard-overwrite-ok'.
        path := self fileIn: dir named: 'target.txt'.
        self assert: (PathGuard isWritableFile: path)
            description: 'a writable regular file was refused for overwrite'
    ]

    testTheOverwritePredicateRefusesAReadOnlyFile [
        | dir path |
        dir := self freshDir: 'guard-overwrite-readonly'.
        path := self fileIn: dir named: 'target.txt'.
        PathFixtures makeReadOnly: path.
        self deny: (PathGuard isWritableFile: path)
            description: 'a read-only file was accepted for overwrite'
    ]

    testTheOverwritePredicateRefusesADirectory [
        "isFile carries this half. A directory is writable in the
         isWriteable sense and is not a file you can overwrite, which
         is why the predicate is a conjunction and not one send."
        | dir |
        dir := self freshDir: 'guard-overwrite-directory'.
        self deny: (PathGuard isWritableFile: dir)
            description: 'a directory was accepted for overwrite'
    ]

    testTheOverwritePredicateRefusesAnAbsentPath [
        "Absent is not overwritable — there is nothing to overwrite.
         The create predicate is the one that answers this state, and
         keeping them apart is what stops either from covering for the
         other."
        | dir |
        dir := self freshDir: 'guard-overwrite-absent'.
        self deny: (PathGuard isWritableFile: dir, '/nothing.txt')
            description: 'an absent path was accepted for overwrite'
    ]

    "---- the create predicate: the PARENT directory ----"

    testTheCreatePredicateAcceptsAnAbsentPathInAWritableDirectory [
        "THE GUARD THE OBVIOUS IMPLEMENTATION BREAKS FIRST, at the unit
         level, and the direct descendant of Sprint 16's absent-lock
         law. isWriteable answers FALSE for a path that does not exist
         (probed, 3.2.5), so a create check written as one send on the
         file itself refuses every first write a project ever makes.
         The predicate is on the PARENT."
        | dir |
        dir := self freshDir: 'guard-create-absent'.
        self assert: (PathGuard isCreatable: dir, '/parley.lock')
            description: 'an absent path in a writable directory was refused for create'
    ]

    testTheCreatePredicateRefusesAPathInAReadOnlyDirectory [
        | dir |
        dir := self freshDir: 'guard-create-readonly'.
        PathFixtures makeReadOnly: dir.
        self deny: (PathGuard isCreatable: dir, '/parley.lock')
            description: 'a path in a read-only directory was accepted for create'
    ]

    testTheCreatePredicateRefusesAPathWhoseParentIsNotThere [
        | dir |
        dir := self freshDir: 'guard-create-noparent'.
        self deny: (PathGuard isCreatable: dir, '/absent/parley.lock')
            description: 'a path under an absent directory was accepted for create'
    ]

    testTheWritableDirectoryPredicateSeparatesTheThreeStates [
        "One law over the directory predicate's whole domain, because
         its three answers are the three the write side turns on: a
         writable directory, a read-only one, and one that is not
         there. isWriteable alone cannot tell the last two apart."
        | root writable readOnly |
        root := self freshDir: 'guard-directory-states'.
        writable := root, '/writable'.
        readOnly := root, '/readonly'.
        Directory create: writable.
        Directory create: readOnly.
        PathFixtures makeReadOnly: readOnly.
        self assert: (PathGuard isWritableDirectory: writable)
            description: 'a writable directory was refused'.
        self deny: (PathGuard isWritableDirectory: readOnly)
            description: 'a read-only directory was accepted'.
        self deny: (PathGuard isWritableDirectory: root, '/absent')
            description: 'an absent directory was accepted'
    ]

    "---- the read predicate (§8 decision 56's rule, at the chokepoint) ----"

    testTheReadPredicateRequiresARegularReadableFile [
        "The three states decision 56 ruled on, in one place for the
         first time: a readable file passes, a directory does not (it
         answers true to exists, which is how a directory-shaped
         parley.lock reached the boundary as a kernel WrongClass), and
         an unreadable file does not (it also answers true to exists,
         which is how a root-owned Package.st reached it as a
         FileError)."
        | dir readable unreadable |
        dir := self freshDir: 'guard-read-states'.
        readable := self fileIn: dir named: 'readable.txt'.
        unreadable := self fileIn: dir named: 'unreadable.txt'.
        PathFixtures makeUnreadable: unreadable.
        self assert: (PathGuard isReadableFile: readable)
            description: 'a readable regular file was refused'.
        self deny: (PathGuard isReadableFile: dir)
            description: 'a directory was accepted as a readable file'.
        self deny: (PathGuard isReadableFile: unreadable)
            description: 'an unreadable file was accepted'.
        self deny: (PathGuard isReadableFile: dir, '/absent.txt')
            description: 'an absent path was accepted as a readable file'
    ]

    "---- the precheck fires BEFORE the operation ----"

    testThePrecheckRefusesBeforeTheOperationRuns [
        "The atomicity publish and add need, asserted where it is
         decided. A guard that ran the operation and reported its
         failure would answer the same refusal and the same code, and
         would already have created the file."
        | dir target refused ran |
        dir := self freshDir: 'guard-precheck-order'.
        PathFixtures makeReadOnly: dir.
        target := dir, '/created.txt'.
        ran := false.
        refused := self refusalCatching: [
            PathGuard
                creating: target
                do: [ran := true]
                ifRefused: [:path | PathRefusal new signal: path]].
        self deny: ran
            description: 'the guarded operation ran even though the precheck refused'.
        self assert: refused = target
            description: 'the refusal named ', refused printString.
        PathFixtures unlock: dir.
        self deny: (PathFixtures exists: target)
            description: 'a refused create left a file behind'
    ]

    testAPassingPrecheckLetsTheOperationRun [
        "The other half, and the guard against implementing the
         precheck as a gate: when the path is fine the operation runs
         and its value is answered, unchanged and unwrapped."
        | dir target answer |
        dir := self freshDir: 'guard-precheck-passes'.
        target := dir, '/created.txt'.
        answer := PathGuard
            creating: target
            do: [SourceFixtures write: 'x' toFile: 'created.txt' in: dir. #ran]
            ifRefused: [:path | PathRefusal new signal: path].
        self assert: answer = #ran
            description: 'the guard did not answer the operation value'.
        self assert: (PathFixtures exists: target)
            description: 'the operation did not run'
    ]

    "---- the broad translation at the seam ----"

    testTheSeamTranslatesAnErrorClassNobodyEnumerated [
        "S14a's law at the unit level, and the reason the catch is
         broad. InventedIoError is defined in tests/support and nothing
         in src/ knows it exists — a guard that named the error classes
         it expected would let it through, and the caller would receive
         an exit-70 sentence blaming Parley for a filesystem it does
         not control."
        | dir refused |
        dir := self freshDir: 'guard-seam-invented'.
        refused := self refusalCatching: [
            PathGuard
                at: dir, '/whatever.txt'
                do: [InventedIoError new signal: 'a mode nobody listed']
                ifRefused: [:path | PathRefusal new signal: path]].
        self assert: refused = (dir, '/whatever.txt')
            description: 'the seam answered ', refused printString
    ]

    testTheSeamTranslatesTheKernelWrongClass [
        "The concrete escape that motivated the amendment: reading a
         DIRECTORY raises SystemExceptions.WrongClass, which is not a
         FileError and walks straight past a handler written for one.
         Driven through the real primitive rather than a double,
         because the claim is about this toolchain."
        | dir refused |
        dir := self freshDir: 'guard-seam-wrongclass'.
        refused := self refusalCatching: [
            PathGuard
                at: dir
                do: [(File name: dir) contents]
                ifRefused: [:path | PathRefusal new signal: path]].
        self assert: refused = dir
            description: 'reading a directory answered ', refused printString
    ]

    testTheSeamTranslatesTheKernelFileError [
        "And the ordinary one, so the law covers both sides of the trap
         it exists to close rather than only the surprising side."
        | dir path refused |
        dir := self freshDir: 'guard-seam-fileerror'.
        path := self fileIn: dir named: 'target.txt'.
        PathFixtures makeReadOnly: path.
        refused := self refusalCatching: [
            PathGuard
                at: path
                do: [(File name: path) writeStream]
                ifRefused: [:path2 | PathRefusal new signal: path2]].
        self assert: refused = path
            description: 'a read-only write answered ', refused printString
    ]

    testTheSeamAnswersTheOperationValueWhenNothingFails [
        "The translation must be invisible on the ordinary path: what
         each verb does when the path is fine must not change by one
         byte."
        | dir answer |
        dir := self freshDir: 'guard-seam-quiet'.
        answer := PathGuard
            at: dir
            do: [#theValue]
            ifRefused: [:path | PathRefusal new signal: path].
        self assert: answer = #theValue
            description: 'the seam changed the operation value on the happy path'
    ]

    testTheGuardedBlockHoldsOnlyTheOperation [
        "THE DISCRIMINATOR AGAINST §8 DECISION 52, made a law rather
         than a comment. A broad catch is correct only while the block
         it guards contains nothing but the operation; the moment the
         guarded block also computes something, the catch starts
         swallowing errors whose diagnosis belongs elsewhere — which is
         exactly what decision 52 rules against.

         The law drives an error raised OUTSIDE the operation block —
         while composing the refusal — and requires it to escape the
         guard rather than be re-translated. A guard whose handler ran
         inside its own protected block would loop or swallow here."
        | dir escaped |
        dir := self freshDir: 'guard-block-bound'.
        escaped := [PathGuard
                at: dir, '/target.txt'
                do: [InventedIoError new signal: 'the operation failed']
                ifRefused: [:path | InventedIoError new signal: 'the refusal failed'].
            nil]
                on: InventedIoError
                do: [:e | e messageText].
        self assert: escaped = 'the refusal failed'
            description: 'the refusal path was itself swallowed: ', escaped printString
    ]

    "---- diagnosis composition ----"

    testTheGuardComposesTheSettledPathGrammar [
        "One composition, used by every boundary, so no two rows can
         spell the same shape differently. The grammar is the settled
         '<path>: <cause>' every file diagnosis in the tool already
         uses."
        | line |
        line := PathGuard lineFor: 'tmp/x/parley.lock'
            saying: 'could not be written - check its permissions and try again'.
        self assert: line
            = (PathFixtures unwritableLineFor: 'tmp/x/parley.lock')
            description: 'the guard composed ', line printString
    ]
]

Namespace current: Smalltalk.
