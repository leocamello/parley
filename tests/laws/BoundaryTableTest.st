"Parley Sprint 17 — the boundary table and the prohibition over it
 (issue #19 S12, S13, S15; Doc E §4.1, §8 decisions 59 and 60).

 WHY A TABLE RATHER THAN TWELVE FIXES. ManifestFile said
 missing or unreadable Package.st from Sprint 8 while its predicate
 tested exists alone — eight sprints of a right sentence over a
 missing predicate, invisible because reviewers read the sentence and
 nothing in this repository could compare a sentence against a check.
 The deliverable is therefore one declared table with laws over it, and
 these are those laws: every row driven through the hostile state its
 direction defines, every row's diagnosis structurally checked, and a
 prohibition that fails the moment a NINTH class starts doing file I/O.

 THE LAW IS A PROHIBITION, NOT AN ENUMERATION (§8 decision 59 as
 amended). Nothing outside PathGuard performs direct File I/O, with the
 Gate C census as the exemption list (§8 decision 60). Narrowing it to
 no I/O outside PathGuard AT A DECLARED BOUNDARY ROW is the
 disqualified implementation: it would still pass, and it would restore
 the enumeration this sprint exists to abolish.

 THE BOUND, STATED IN THE LAW (decision 43's standard). Two bounds, and
 neither is hidden:
   - The prohibition is a TEXTUAL search over comment-stripped,
     whitespace-normalized source, because 3.2.5 offers no reflective
     alternative — whichSelectorsReferTo: searches literals rather than
     sends, and allCallsOn: does not exist. I/O reached through a
     temporary or assembled by perform: stays invisible.
   - Naming the eight census classes as the exemption list means the
     live claim is that a NINTH class never starts doing direct File
     I/O. What holds the eight themselves to the chokepoint is the
     behaviour half below: no class can answer its row's diagnosis
     while raising a kernel FileError of its own.

 THE NON-EMPTY GUARD IS MANDATORY, NOT DECORATIVE. 3.2.5's File>>files
 answers regular files only and never recurses, so a src/ walk written
 the obvious way sees NOTHING and every law over it passes while
 proving nothing — the Sprint 8 bin/ drift-law lesson, and the one
 failure mode that would make every law in this file decorative.
 testTheIoEnumerationSeesTheRealSites is that guard.

 DECLARED PASS IN RED — one, and it is a fixture-correctness guard in
 the exact shape Sprint 10's testTheEnumerationSeesTheRealSenders has:
   testTheProhibitionDetectsANinthClass — it runs the prohibition's own
     comparison over a FABRICATED tree under tmp/ holding a ninth class
     that really opens a path, and requires the comparison to name it.
     It reads no src/ code and calls nothing this sprint adds, so it
     passes from the first day — which is the point: it is what stops
     every other prohibition law here from being a law about nothing.
 Every other law here fails against the pre-sprint tree — the table
 does not exist, and both live-tree laws assert that the walk sees
 PathGuard, which does not exist either.

 Every fixture path is under tmp/, unique per test, torn down through
 PathFixtures removeTree:, which UNLOCKS the tree first. Nothing here
 spawns except where a verb's own pipeline does; no network is
 contacted and no git runs."

Namespace current: Parley.

TestCase subclass: BoundaryTableTest [
    | fixtureDirs |

    <comment: 'Laws for CommandLine class >> pathBoundaries: every read
row driven through an unreadable path and every write row through an
unwritable one, each answering a diagnosis at exit 1 that names its
path; the structural path/cause/remedy law; the table''s own shape; and
the prohibition on direct File I/O outside PathGuard with its
non-empty guard and its must-fail-on-drift proof.'>

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

    readRowDrivers [
        "The declared READ rows and their hostile-state drivers, built
         in PathFixtures so this suite and the acceptance suite drive
         the identical set — two enumerations of the same table would
         be inventory row 22 again, one sprint after it was ruled."
        ^PathFixtures readRowDriversTracking: [:path | self track: path]
    ]

    writeRowDrivers [
        ^PathFixtures writeRowDriversTracking: [:path | self track: path]
    ]

    assertDiagnosis: aResult names: aPath for: aRole [
        "Every row's obligation, in one place: exit 1, at least one
         line, a line naming the path, and NEVER the exit-70 sentence,
         a backtrace, or a kernel class name on the operator's screen.

         Exit 1 is what proves a DECLARED Parley error reached the
         boundary: §4.2 maps declared errors to 1 and everything else
         to 70, so a row that answers 1 answered one of the six."
        self assert: aResult exitCode = 1
            description: aRole, ' answered exit ',
                aResult exitCode printString, ': ',
                aResult lines printString.
        self deny: aResult lines isEmpty
            description: aRole, ' answered no lines'.
        self assert: (aResult lines anySatisfy: [:line |
            CommandLineFixtures does: line include: aPath])
            description: aRole, ' never named ', aPath, ': ',
                aResult lines printString.
        aResult lines do: [:line |
            self deny: (CommandLineFixtures does: line
                include: LockBoundaryFixtures undiagnosedLinePrefix)
                description: aRole, ' blamed Parley: ', line.
            self deny: (CommandLineFixtures does: line
                include: ReadinessFixtures kernelErrorMarker)
                description: aRole, ' named a kernel error: ', line.
            CommandLineFixtures backtraceMarkers do: [:marker |
                self deny: (CommandLineFixtures does: line include: marker)
                    description: aRole, ' dumped a backtrace: ', line]]
    ]

    "---- S12: every row answers its own error under its hostile state ----"

    testEveryReadRowRefusesAnUnreadablePath [
        "The read half of S12. Each driver's path EXISTS and cannot be
         read, which is the state every check written against existence
         waves through — and the state that reached §4.2 as a kernel
         FileError at exit 70 in six ordinary places.

         The driver roles are asserted against the declared read rows
         FIRST, so a row added to the table without a driver fails here
         rather than silently widening the claim."
        | drivers |
        drivers := self readRowDrivers.
        self assert: (self rolesOf: drivers)
            = (self declaredRolesWithDirection: #read)
            description: 'the read drivers and the declared read rows disagree: ',
                (self rolesOf: drivers) printString.
        drivers do: [:row |
            self assertDiagnosis: (row at: 3) value
                names: (row at: 2)
                for: (row at: 1)]
    ]

    testEveryWriteRowRefusesAnUnwritablePath [
        "The write half of S12 — decision 56's rule with the direction
         reversed, and the half nothing in the tool governed at all
         before this sprint."
        | drivers |
        drivers := self writeRowDrivers.
        self assert: (self rolesOf: drivers)
            = (self declaredRolesWithDirection: #write)
            description: 'the write drivers and the declared write rows disagree: ',
                (self rolesOf: drivers) printString.
        drivers do: [:row |
            self assertDiagnosis: (row at: 3) value
                names: (row at: 2)
                for: (row at: 1)]
    ]

    rolesOf: someDrivers [
        ^((someDrivers collect: [:row | row at: 1])
            asSortedCollection: [:a :b | a <= b]) asArray
    ]

    declaredRolesWithDirection: aSymbol [
        ^(((CommandLine pathBoundaries
            select: [:row | (row at: 2) = aSymbol])
                collect: [:row | row at: 1])
                    asSortedCollection: [:a :b | a <= b]) asArray
    ]

    "---- S15: the structural diagnosis guarantee ----"

    testEveryRowsDiagnosisNamesItsPathAndACause [
        "§8 decision 58's standard made a law rather than a habit: the
         line a first-time user meets must say WHICH file and WHAT is
         wrong with it, in the settled '<path>: <cause>' grammar.

         THE LAW GOVERNS THE ROW'S SENTENCE, NOT THE WHOLE LINE (§8
         decision 73). It asserts that the operator's line ENDS WITH
         the row's declared sentence and that the sentence OPENS WITH
         the path. For eleven of the twelve rows the sentence IS the
         line and the two readings coincide; the twelfth crosses
         Installer's settled batching carrier, which composes
         '<name> <version>: fetch failed - ' in front of a SourceError
         whose text is law-pinned for the archive-absent case.

         THE VACUITY THE OPENS-WITH FORM CLOSED STAYS CLOSED: the
         abolished internal error: FileError: could not open <path> -
         this is a defect in Parley, not in your project contains a
         path, a cause and a remedy, but it ENDS WITH no row's
         DECLARED sentence.

         WHAT BOUNDS THE PREFIX IS NAMED RATHER THAN LEFT TO THIS
         LAW'S SILENCE (decision 43). This law now tolerates a prefix,
         so it must say what constrains one:
         testEveryReadRowRefusesAnUnreadablePath and its write twin
         drive these same twelve rows and hold every one to exit 1 with
         its own declared error, and the acceptance suite's S12 drives
         them again under BOTH hostile states holding every one to
         never exit 70, never name a kernel class, never print a
         backtrace and never carry the undiagnosed prefix. A law that
         tolerates composition without saying what bounds the composed
         part has traded a precise claim for a vague one."
        | rows |
        rows := self everyRowsFirstLine.
        self deny: rows isEmpty
            description: 'no row produced a diagnosis to check'.
        rows do: [:row |
            | role path line sentence |
            role := row at: 1.
            path := row at: 2.
            line := row at: 3.
            sentence := row at: 4.
            self assert: (line endsWith: sentence)
                description: role, ' does not end with its declared sentence ',
                    sentence printString, ': ', line.
            self assert: (sentence startsWith: path)
                description: role, ' declares a sentence that does not open with its path ',
                    path printString, ': ', sentence.
            self deny: (PathFixtures causePartOf: sentence) isEmpty
                description: role, ' states no cause: ', sentence]
    ]

    testEveryWriteRowsDiagnosisOffersARemedy [
        "A remedy is asserted only when it has been checked (§8 decision
         58), so this half of the guarantee is scoped — and the scope is
         the point rather than a weakening. Every WRITE refusal is a
         state the operator owns and can repair, so every write row
         owes a remedy. The read rows that report on somebody ELSE's
         index — an unreadable entry, an unreadable archive — owe none,
         and inventing one for them would be the very defect decision 58
         rules against."
        | lines |
        lines := self writeRowsFirstLine.
        self deny: lines isEmpty
            description: 'no write row produced a diagnosis to check'.
        lines do: [:row |
            "The line must END WITH the row's own declared sentence
             before its remedy means anything (§8 decision 73). Without
             this half the law passes over the pre-sprint sentence
             internal error: FileError: could not open <path> - this is
             a defect in Parley, not in your project, which has a path
             in it, a colon and a dash, and is the exact diagnosis this
             sprint exists to abolish."
            self assert: ((row at: 3) endsWith: (row at: 4))
                description: (row at: 1),
                    ' does not end with its declared sentence: ', (row at: 3).
            self deny: (PathFixtures remedyPartOf: (row at: 4)) isEmpty
                description: (row at: 1), ' offers no remedy: ',
                    (row at: 4)]
    ]

    everyRowsFirstLine [
        ^self firstLinesNaming: self readRowDrivers, self writeRowDrivers
    ]

    writeRowsFirstLine [
        ^self firstLinesNaming: self writeRowDrivers
    ]

    firstLinesNaming: someDrivers [
        "Private — for each driver, the first line that names its path.
         The rows that batch (the scan) answer several problems; the one
         about THIS path is the one the structure law is about."
        | pairs |
        pairs := OrderedCollection new.
        someDrivers do: [:row |
            | result named |
            result := (row at: 3) value.
            named := result lines
                detect: [:line | CommandLineFixtures does: line
                    include: (row at: 2)]
                ifNone: [nil].
            named isNil ifFalse: [
                pairs add: (Array with: (row at: 1) with: (row at: 2)
                    with: named with: (row at: 4))]].
        ^pairs asArray
    ]

    "---- the table's own shape ----"

    testTheTableDeclaresEveryRoleExactlyOnce [
        | roles |
        roles := PathFixtures namesOfBoundaryRolesIn: CommandLine pathBoundaries.
        self deny: roles isEmpty
            description: 'the boundary table declares no rows'.
        self assert: roles = PathFixtures boundaryRoleNames
            description: 'the table declares ', roles printString
    ]

    testEveryRowDeclaresOneOfTheTwoDirections [
        "A third direction would mean somebody invented a kind of file
         access; a missing one would mean a row nobody can drive."
        CommandLine pathBoundaries do: [:row |
            self assert: (PathFixtures declaredDirections includes: (row at: 2))
                description: (row at: 1), ' declares direction ',
                    (row at: 2) printString].
        self deny: (self declaredRolesWithDirection: #read) isEmpty
            description: 'no row declares the read direction'.
        self deny: (self declaredRolesWithDirection: #write) isEmpty
            description: 'no row declares the write direction'
    ]

    testEveryRowDeclaresAnErrorTheBoundaryDiagnoses [
        "A row may not declare an error the §4.2 boundary would answer
         with exit 70 — that would be a boundary whose declared
         diagnosis blames Parley, which is the whole disease."
        | diagnosed |
        diagnosed := CommandLine diagnosedErrorClasses.
        CommandLine pathBoundaries do: [:row |
            self assert: (diagnosed anySatisfy: [:each |
                (row at: 3) == each or: [(row at: 3) inheritsFrom: each]])
                description: (row at: 1), ' declares ',
                    (CommandLineFixtures nameOf: (row at: 3)),
                    ', which the boundary does not diagnose']
    ]

    testEveryRowDeclaresHowItIsGuarded [
        "PRECHECK YES, TRANSLATE NO IS A PROPERTY OF A ROW, NOT A
         SENTENCE IN A REPORT (§8 decision 73). Every row prechecks
         through PathGuard; all but one also route the operation
         through its translating seam. Package.st (read) deliberately
         does not: ManifestFile files the author's own program in, and
         a broad translation around THAT would relabel a vocabulary
         typo or a division by zero as an I/O failure — decision 52's
         discriminator, in the one place this project has been most
         careful about blame. That is Sprint 18's boundary.

         The reason it is a column rather than prose: Sprint 8's
         ManifestFile defect was a right sentence over a missing
         predicate, and it survived eight sprints because the reasoning
         lived in a comment where nothing could compare it against the
         code."
        | prechecked |
        prechecked := OrderedCollection new.
        CommandLine pathBoundaries do: [:row |
            self assert: (PathFixtures declaredGuardings includes: (row at: 4))
                description: (row at: 1), ' declares guarding ',
                    (row at: 4) printString.
            (row at: 4) = #prechecked
                ifTrue: [prechecked add: (row at: 1)]].
        self assert: prechecked asArray = PathFixtures precheckOnlyRoles
            description: 'the rows that precheck without translating are ',
                prechecked asArray printString
    ]

    "---- S13: the prohibition, its guard, and its proof of drift ----"

    testTheIoEnumerationSeesARealSiteAndIgnoresProse [
        "THE NON-EMPTY GUARD, and the law that stops every prohibition
         law here from passing over an empty walk. 3.2.5's File>>files
         answers regular files only and never recurses, so a src/ walk
         written the obvious way answers () and proves nothing — the
         Sprint 8 bin/ drift-law lesson.

         The oracle is a fabricated src/-shaped tree under tmp/ holding
         one class that really opens a path and one whose COMMENT names
         the send, walked through the SAME code path as the real
         enumeration. Proving the walk against a fabrication rather than
         against a pinned list of live filenames is deliberate: the live
         census legitimately SHRINKS as this sprint routes I/O into the
         chokepoint, and a guard pinned to today's filenames would have
         to be edited every time the sprint succeeded — which is a guard
         that measures the fixture rather than the walk."
        | root found |
        root := self freshDir: 'boundary-io-probe'.
        PathFixtures populateIoProbeTreeIn: root.
        found := PathFixtures ioSiteFileNamesUnder: root
            subdirectories: PathFixtures ioProbeSubdirectoryNames.
        self deny: found isEmpty
            description: 'the walk found no I/O at all — File>>files does not recurse; the walk must use namesDo:'.
        self assert: found = PathFixtures probeIoSiteFileNames
            description: 'the walk answered ', found printString.
        self deny: PathFixtures ioSiteClassNames isEmpty
            description: 'the walk over the real src/ tree found nothing'.
        self assert: (PathFixtures ioSiteClassNames
            includes: PathFixtures guardClassName)
            description: 'the walk does not see the chokepoint itself, which is the one class that MUST perform file I/O'
    ]

    testNothingOutsidePathGuardPerformsDirectFileIo [
        "THE PROHIBITION (§8 decision 59 as amended): PathGuard is the
         single site in Parley that performs file I/O, and the exemption
         list is a census of the property the law prohibits (§8 decision
         60), never the set of sites that motivated the rule. Narrowing
         it to no I/O outside PathGuard AT A DECLARED BOUNDARY ROW is
         the disqualified implementation: it would still pass, and it
         would restore the enumeration this sprint exists to abolish.

         THE CLAIM IS BOUNDED, AND THE BOUND IS STATED HERE RATHER THAN
         IMPLIED (decision 43's standard). Two bounds. First, this is a
         TEXTUAL search over comment-stripped, whitespace-normalized
         source: 3.2.5 offers no reflective alternative, so I/O reached
         through a temporary or assembled by perform: stays invisible.
         Second, naming the eight census classes as exemptions makes the
         live claim that a NINTH class never starts doing direct File
         I/O — it is NOT the claim that the eight have none left. What
         holds the eight themselves to the chokepoint is the behaviour
         half of this file: no class can answer its row's diagnosis
         while raising a kernel FileError of its own."
        | offenders |
        self assert: (PathFixtures ioSiteClassNames
            includes: PathFixtures guardClassName)
            description: 'the prohibition names a chokepoint that performs no file I/O in src/ — a prohibition around an absent centre is a claim about nothing'.
        offenders := PathFixtures
            classesDoingIoIn: PathFixtures ioSiteClassNames
            outside: PathFixtures ioCensusClassNames.
        self assert: offenders isEmpty
            description: offenders printString,
                ' perform direct File I/O in src/ but are neither PathGuard nor declared in the §8 decision 60 census'
    ]

    testTheProhibitionDetectsANinthClass [
        "DECLARED PASS IN RED (issue #19) — a fixture-correctness guard
         in the shape Sprint 10's testTheEnumerationSeesTheRealSenders
         has, not a behaviour claim: it reads no src/ code and calls
         nothing this sprint adds, so it passes from the first day.

         The same comparison, run over a tree that really holds a ninth
         class doing real I/O. A drift law that has never failed on
         purpose is a law about nothing, and this one fails on the exact
         shape it exists to catch: a new class, in an existing
         directory, opening a path on its own."
        | root offenders |
        root := self freshDir: 'boundary-io-ninth'.
        PathFixtures populateIoProbeTreeIn: root.
        PathFixtures addNinthClassTo: root.
        offenders := PathFixtures
            classesDoingIoIn: (PathFixtures classNamesOf:
                (PathFixtures ioSiteFileNamesUnder: root
                    subdirectories: PathFixtures ioProbeSubdirectoryNames))
            outside: PathFixtures ioCensusClassNames.
        self assert: (offenders includes: 'Ninth')
            description: 'the prohibition does not detect an undeclared class — it proves nothing: ',
                offenders printString
    ]
]

Namespace current: Smalltalk.
