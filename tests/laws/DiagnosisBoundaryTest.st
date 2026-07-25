"Parley Sprint 8 — the two drift laws (issue #10 S7-S8; Doc E §4.2/§4.3).

 Both laws are mechanical, and both exist because this sprint's
 motivating defect was a DRIFT: a new src/ directory shipped
 unreachable because a hardcoded list in an untested script was never
 updated, and nothing in 409 laws could see it.

 S7 — the boundary is a CLOSED SET. Every Error subclass defined in the
 Parley namespace is either accounted for by the boundary's declared
 diagnosed set (exit 1) or named in the declared undiagnosed list, with
 no third bucket. A new error class can never drift into the exit-70
 bucket silently: the law fails first, and whoever adds it must decide,
 deliberately, which list it belongs to.

 The diagnosed side is read from the boundary itself (CommandLine
 diagnosedErrorClasses), never from a copy — a law comparing two
 copies of a list proves only that copying works. Coverage is by
 HANDLING, exactly as on:do: works: a subclass of a declared error is
 accounted for by its superclass and is deliberately not named
 anywhere (DerivedSourceError is the standing witness).

 S8 — the wrapper's own source must name every existing src/
 subdirectory. This is the law that would have caught the motivating
 defect, and it MUST fail against the pre-sprint wrapper: the shipped
 bin/parley-main.st really does omit src/publish. Its companion law
 holds the wrapper to Doc E §4.3's four steps: it names CommandLine
 and exits, and it no longer names the collaborators whose wiring
 moved into an object with laws.

 Scope note, declared honestly (issue #10): the bin/ drift law covers
 DIRECTORIES, not flags. GitIndexSource was built, lawful, and still
 unreachable from the binary because wiring it needs a repo-plus-cache
 flag grammar — design, not a fix, and deferred on that issue. This law
 does not falsely claim otherwise, and it still does not: Sprint 9
 closes the flag gap with its OWN law, over the flag table, in
 SourceFlagTest. Directories and flags are two different reachability
 questions and each keeps its own law.

 DECLARED PASS IN RED (issue #10):
 testTheUndiagnosedListNamesOnlyRealParleyErrorClasses — it checks the
 fixture list against the loaded image and needs no new behaviour. It
 is the guard that keeps a STALE name in the second list from
 accounting for a class that no longer exists while a new one slips
 past unnamed, so it must run from the first day the list exists.

 Neither law touches the filesystem beyond reading two paths of the
 checkout, spawns anything, or mutates the developer image."

Namespace current: Parley.

TestCase subclass: DiagnosisBoundaryTest [

    <comment: 'The two Sprint 8 drift laws: the closed error set of the
diagnosis boundary, and bin/parley-main.st naming every src/
subdirectory.'>

    isClass: aClass coveredBy: aCollectionOfClasses [
        "Coverage as on:do: computes it: a class is covered when it IS
         a declared class or INHERITS FROM one."
        <category: 'closed set'>
        ^(aCollectionOfClasses
            detect: [:each | aClass == each or: [aClass inheritsFrom: each]]
            ifNone: [nil]) notNil
    ]

    "---- S7: the boundary is a closed set ----"

    testTheBoundaryDeclaresExactlyTheDocumentedErrors [
        "The declared diagnosed set is exactly Doc E §4.2's, no more and
         no fewer — read from the boundary, so it cannot claim one
         thing and handle another. Renamed at Sprint 9 (issue #11): the
         set became SIX when LockError joined it, and a selector that
         says 'five' while asserting six is the drift this law exists to
         prevent."
        self assert: (CommandLineFixtures namesOf:
            CommandLine diagnosedErrorClasses)
                = CommandLineFixtures diagnosedErrorClassNames
    ]

    testEveryParleyErrorClassIsAccountedForByTheBoundary [
        | parleyErrors diagnosed undiagnosed |
        parleyErrors := CommandLineFixtures parleyErrorClasses.
        self deny: parleyErrors isEmpty.
        diagnosed := CommandLine diagnosedErrorClasses.
        undiagnosed := CommandLineFixtures undiagnosedErrorClassNames.
        parleyErrors do: [:each |
            | isCovered isDeclaredUndiagnosed |
            isCovered := self isClass: each coveredBy: diagnosed.
            isDeclaredUndiagnosed := undiagnosed includes:
                (CommandLineFixtures nameOf: each).
            self assert: (isCovered or: [isDeclaredUndiagnosed])
                description: (CommandLineFixtures nameOf: each),
                    ' is in neither the boundary''s diagnosed set nor the declared undiagnosed list'.
            "no third bucket, and no double-counting"
            self deny: (isCovered and: [isDeclaredUndiagnosed])
                description: (CommandLineFixtures nameOf: each),
                    ' is claimed by both lists — the buckets must partition']
    ]

    testTheUndiagnosedListNamesOnlyRealParleyErrorClasses [
        "A stale name in the second list would hide a real drift: the
         list would keep accounting for a class that no longer exists
         while a new one slipped past unnamed."
        | names |
        names := CommandLineFixtures namesOf:
            CommandLineFixtures parleyErrorClasses.
        CommandLineFixtures undiagnosedErrorClassNames do: [:each |
            self assert: (names includes: each)
                description: each,
                    ' is declared undiagnosed but is not a Parley error class']
    ]

    testTheTwoListsTogetherExhaustTheEnumeration [
        "The partition is complete: every enumerated class lands in
         exactly one bucket, so the two counts add up to the whole."
        | parleyErrors diagnosed undiagnosed covered named |
        parleyErrors := CommandLineFixtures parleyErrorClasses.
        diagnosed := CommandLine diagnosedErrorClasses.
        undiagnosed := CommandLineFixtures undiagnosedErrorClassNames.
        covered := parleyErrors select: [:each |
            self isClass: each coveredBy: diagnosed].
        named := parleyErrors select: [:each |
            undiagnosed includes: (CommandLineFixtures nameOf: each)].
        self assert: covered size + named size = parleyErrors size
    ]

    "---- S8: the wrapper names every src/ directory ----"

    testTheWrapperNamesEverySrcSubdirectory [
        "The law that would have caught the motivating defect. It must
         fail against the pre-sprint wrapper, which omits src/publish."
        | source names |
        source := CommandLineFixtures wrapperSource.
        names := CommandLineFixtures srcSubdirectoryNames.
        self deny: names isEmpty.
        self assert: (names includes: 'publish')
            description: 'the fixture is wrong: src/publish does not exist'.
        names do: [:each |
            self assert: (CommandLineFixtures does: source
                include: 'src/', each)
                description: CommandLineFixtures wrapperPath,
                    ' does not name src/', each,
                    ' — a src/ directory can never ship unreachable']
    ]

    testTheWrapperHoldsNoLogicOfItsOwn [
        "Doc E §4.3: file in, send CommandLine run:, print, quit. The
         wiring and the flag grammar moved into an object with laws,
         so the wrapper no longer names the collaborators it used to
         construct."
        | source |
        source := CommandLineFixtures wrapperSource.
        self assert: (CommandLineFixtures does: source
            include: 'CommandLine').
        self assert: (CommandLineFixtures does: source
            include: 'ObjectMemory quit:').
        self deny: (CommandLineFixtures does: source
            include: 'DirectorySource')
            description: 'the flag grammar belongs to CommandLine, not the wrapper'.
        self deny: (CommandLineFixtures does: source
            include: 'ContentStore')
            description: 'the wiring belongs to CommandLine, not the wrapper'
    ]
]

Namespace current: Smalltalk.
