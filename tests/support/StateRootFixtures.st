"Parley Sprint 18 — fixtures for the state-root boundary row's
 SHAPE-space (issue #20 S8, S9, S10; Doc E §4.1, §8 decision 74, method
 finding F13).

 WHAT WAS WRONG, PROBED THROUGH THE SHIPPED BINARY. Sprint 17 gave the
 wiring-state-directory row a deliberate rule: an operator told
 <workdir>/.parley could not be written is reading a name Parley
 invented, so the refusal names the working directory the operator
 chose. That rule is right for the state it was written for and FALSE
 for one it never considered. With a regular FILE at <workdir>/.parley
 — or at <workdir>/.parley/packages with .parley writable — resolve
 answers

   <workdir>: could not be written - check its permissions and try again

 about a directory test -w reports WRITABLE, with a remedy that cannot
 work. That is §8 decision 58's standard broken by the newest row in the
 table Sprint 17 built, and it was found only by an operator inventing a
 state nobody had listed.

 THE PORTABLE HALF IS THE LAW, NOT THE FIX. Sprint 17 made the ERROR
 CLASS total through PathGuard's broad translation, and did nothing at
 all about the set of hostile STATES its laws drive — which was a list
 of exactly two, unreadable and unwritable. A path is not two things. So
 the row is driven through the four shapes a path can take: ABSENT,
 ALREADY A DIRECTORY, A REGULAR FILE, and A WRONG-TYPE OR UNWRITABLE
 PARENT. A chokepoint's totality over error classes is not totality over
 input states, and the difference is where a confident false sentence
 lives.

 THE TABLE ITSELF IS NOT RESTRUCTURED. The row keeps its role, its
 direction, its declared error and its guarding; what it gains is a
 second declared SENTENCE for the state it could not previously tell
 apart, pinned here as wrongTypeLineFor:. The settled
 PathFixtures boundaryRoleNames oracle is byte-identical and the
 settled drivers are untouched.

 Every fixture path is under tmp/, unique per test via a label, and torn
 down through PathFixtures removeTree:, which unlocks the tree first —
 the unwritable-parent shape leaves a read-only directory behind and a
 teardown that did not unlock it would poison the next run."

Namespace current: Parley.

Object subclass: StateRootFixtures [

    <comment: 'Class-side factory for the state-root row''s shape-space:
the pinned wrong-type refusal, and one enumeration of the four path
shapes with the outcome each owes, consumed by both the boundary-table
law and the acceptance suite so the two cannot drift apart.'>

    "---- the pinned wording (posted on issue #20) ----"

    StateRootFixtures class >> wrongTypeLineFor: aPath [
        "THE REFUSAL FOR A PATH OF THE WRONG TYPE (§8 decision 74),
         naming THE OFFENDING PATH ITSELF rather than its parent.

         The shape is the one the parley.lock row already carries —
         not a regular readable file - remove it and run parley resolve
         to write a new one — with the predicate this row actually
         checks: the path exists and is not a directory. The cause is
         what was tested, and the remedy is the operator''s own file to
         remove, so both halves are checked rather than guessed
         (decision 58).

         THE PARENT-NAMING RULE SURVIVES for the state it was written
         for: when the creation really cannot happen because the parent
         cannot be written, the refusal still names the working
         directory the operator chose, through the settled
         PathFixtures unwritableLineFor:."
        <category: 'pinned wordings'>
        ^aPath, ': not a directory - remove it and try again'
    ]

    "---- the shape-space (S10) ----"

    StateRootFixtures class >> declaredShapes [
        "THE FOUR SHAPES A PATH CAN TAKE, and the whole of them. Sprint
         17's laws drove two states and called the claim total; this is
         the enumeration that replaces them. A fifth shape would mean
         somebody found a way for a path to be something else; a
         missing one is where the false sentence lived."
        <category: 'shape space'>
        ^#(#absent #directory #regularFile #unwritableParent)
    ]

    StateRootFixtures class >> shapesOf: someRows [
        "The distinct shapes someRows drive, sorted — asserted against
         declaredShapes so a row added or dropped fails the law rather
         than silently changing what it quantifies over."
        <category: 'shape space'>
        | shapes |
        shapes := Set new.
        someRows do: [:row | shapes add: (row at: 1)].
        ^((shapes collect: [:each | each asString])
            asSortedCollection: [:a :b | a <= b]) asArray
            collect: [:each | each asSymbol]
    ]

    StateRootFixtures class >> sortedDeclaredShapes [
        <category: 'shape space'>
        ^((self declaredShapes collect: [:each | each asString])
            asSortedCollection: [:a :b | a <= b]) asArray
            collect: [:each | each asSymbol]
    ]

    StateRootFixtures class >> shapeDriversTracking: track [
        "ONE DRIVER PER SHAPE, each a row of five: the shape, a label,
         the path the diagnosis must name (nil where the verb
         proceeds), a block answering the CliResult a real resolve
         reaches the state with, and the line it owes (nil where the
         verb proceeds at exit 0).

         The regular-file shape appears TWICE, once at each of the two
         state paths CommandLine creates, because .parley/packages with
         .parley writable is the second half of F13 and a fix that
         reached only the first would pass a one-row drive. Both rows
         carry the same shape, so the shape enumeration is still four."
        <category: 'shape space'>
        | absent dirWork fileWork packagesWork lockedWork index rows |
        index := track value: (SourceFixtures directoryNamed:
            'state-root-index').
        InstallFixtures populateInstallDiamondIn: index.

        absent := self workDirTracking: track named: 'state-root-absent'.

        dirWork := self workDirTracking: track named: 'state-root-dir'.
        PathFixtures makeStateDir: 'packages' in: dirWork.

        fileWork := self workDirTracking: track named: 'state-root-file'.
        SourceFixtures write: 'not a directory'
            toFile: '.parley' in: fileWork.

        packagesWork := self workDirTracking: track
            named: 'state-root-packages'.
        Directory create: (CommandLineFixtures parleyDirIn: packagesWork).
        SourceFixtures write: 'not a directory'
            toFile: 'packages'
            in: (CommandLineFixtures parleyDirIn: packagesWork).

        lockedWork := self workDirTracking: track
            named: 'state-root-locked'.
        PathFixtures makeReadOnly: lockedWork.

        rows := OrderedCollection new.
        rows add: (Array with: #absent with: 'absent'
            with: nil
            with: [self resolveIn: absent source: index]
            with: nil).
        rows add: (Array with: #directory with: 'already a directory'
            with: nil
            with: [self resolveIn: dirWork source: index]
            with: nil).
        rows add: (Array with: #regularFile
            with: 'a regular file at .parley'
            with: (CommandLineFixtures parleyDirIn: fileWork)
            with: [self resolveIn: fileWork source: index]
            with: (self wrongTypeLineFor:
                (CommandLineFixtures parleyDirIn: fileWork))).
        rows add: (Array with: #regularFile
            with: 'a regular file at .parley/packages'
            with: (self packagesPathIn: packagesWork)
            with: [self resolveIn: packagesWork source: index]
            with: (self wrongTypeLineFor:
                (self packagesPathIn: packagesWork))).
        rows add: (Array with: #unwritableParent
            with: 'an unwritable working directory'
            with: lockedWork
            with: [self resolveIn: lockedWork source: index]
            with: (PathFixtures unwritableLineFor: lockedWork)).
        ^rows asArray
    ]

    StateRootFixtures class >> workDirTracking: track named: aLabel [
        "A resolvable working directory: the settled diamond root, so a
         shape that must PROCEED really resolves and answers the
         settled pin lines rather than some other diagnosis."
        <category: 'shape space'>
        ^track value:
            (CommandLineFixtures diamondRootWorkDirNamed: aLabel)
    ]

    StateRootFixtures class >> packagesPathIn: aWorkDir [
        <category: 'shape space'>
        ^(CommandLineFixtures parleyDirIn: aWorkDir), '/packages'
    ]

    StateRootFixtures class >> resolveIn: aWorkDir source: anIndexDir [
        <category: 'shape space'>
        ^(CommandLine in: aWorkDir runner: RecordingRunner new)
            run: (Array with: 'resolve' with: '--source'
                with: anIndexDir)
    ]
]

Namespace current: Smalltalk.
