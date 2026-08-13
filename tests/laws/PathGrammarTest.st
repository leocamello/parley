"Parley Sprint 21 — decision 83's grammar, the reporting matrix's
 remaining legs, and the README obligation (issue #23; Doc E §4/§4.1,
 Doc B §2.1; §8 decisions 57, 68, 80, 81, 82, 83).

 NEEDS AN INDEX IS A PROPERTY OF THE MANIFEST, NEVER OF THE GRAMMAR.
 Once a manifest may declare only path dependencies, HAS DEPENDENCIES
 and NEEDS AN INDEX come apart, and no argv-pure predicate can see the
 difference. So resolve's verbRows guard stops requiring a source, the
 #needsIndex ground stops firing for it BY DERIVATION rather than by
 edit — decision 81 derives that ground from `some row matches with a
 source and none without`, and the declared table read twice keeps
 working with no new declaration — and the index requirement becomes a
 declared refusal INSIDE the verb.

 THE BOUND IS HELD BY LAW RATHER THAN BY INTENTION. The mirror is
 deferred with its trigger, so every other source-requiring verb keeps
 its grammar; the over-narrowing twin is a source-less install still
 answering #needsIndex, and that guard lives beside this sprint's own
 scenario rather than only in the acceptance file.

 THE MATRIX LEGS HERE ARE THE ONES THAT ARE LAWS RATHER THAN
 SCENARIOS: tree renders a path pin as any pin; the two editing verbs
 refuse the new clause kinds with the file BYTE-IDENTICAL (Doc B
 §2.1's stated bound); and add's already-declared check quantifies over
 all three kinds.

 THE README LAW EXISTS BECAUSE NO SETTLED LAW FORCES FLAG
 DOCUMENTATION — the settled README drift laws bind VERBS only, checked
 at staging. A flag the documentation hides is a flag that does not
 exist (§8 decision 45's standard, applied to this sprint's surface)."

Namespace current: Parley.

TestCase subclass: PathGrammarTest [
    | fixtureDirs |

    <comment: 'Laws over resolve''s source-optional grammar and its
three manifest states, the derived usage ground and the deferred
mirror''s bound, the reporting-matrix legs that are laws, and the
README marker obligation for the two flags and the workflow.'>

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

    workDir: aLabel contents: aContentsString [
        ^self track:
            (PathDepFixtures workDirNamed: aLabel contents: aContentsString)
    ]

    sibling: aLabel [
        ^self track: (PathDepFixtures textSiblingNamed: aLabel)
    ]

    resultOf: anArgvArray in: aWorkDir [
        ^PathDepFixtures resultOf: anArgvArray
            in: aWorkDir runner: RecordingRunner new
    ]

    "---- the grammar itself ----"

    testResolveMatchesWithAndWithoutASource [
        "FOUR GUARDS MOVED, AND NO OTHER ROW. The determination is a pure
         function of argv and of whether a source was wired, so it can
         be asked directly — which is how this law proves the change
         landed in the table rather than in a branch somewhere below
         it.

         AMENDED AT THE FIFTH MID-SPRINT HALT (§8 decision 84). As
         frozen this comment read ONE GUARD, AND NO OTHER ROW, and the
         mirror group below asserted that `tree`, `check` and `why`
         still require a source. Decision 84 moved exactly those three
         out of the grammar, so three of those assertions became false
         BY THE RULING rather than by a defect — the law was asserting
         precisely the bound the ruling moves, which is what a bound
         law is for. It was invisible to the halt sweep because it is a
         pure grammar law and drives no verb.

         The three are not merely removed: they are re-asserted in the
         OTHER direction below, so this law still fails an
         over-narrowing table in both senses — a build that keeps them
         source-requiring fails here, and a build that lets a WRITE
         verb slip out of the grammar fails here too. Removing them
         without re-asserting them would have left the ruling's own
         change unguarded at the table level, which is the hole the
         owed law closes end to end and this one closes at the
         declaration."
        self deny: (CLI verbRowFor: (Array with: 'resolve')
            withSource: false) isNil
            description: 'a source-less resolve still selects no verb'.
        self deny: (CLI verbRowFor: (Array with: 'resolve')
            withSource: true) isNil
            description: 'resolve stopped matching WITH a source'.
        "THE READ-ONLY VERBS DECISION 84 MOVED, asserted in BOTH
         directions: they match with a source and without one, because
         a project that needs no index must be inspectable and a
         project that has one must not stop working."
        (Array
            with: (Array with: 'tree')
            with: (Array with: 'check')
            with: (Array with: 'why' with: 'kernel-a')) do: [:argv |
                self deny: (CLI verbRowFor: argv withSource: false) isNil
                    description: argv printString,
                        ' still requires a source'.
                self deny: (CLI verbRowFor: argv withSource: true) isNil
                    description: argv printString,
                        ' stopped matching with a source'].
        "THE DEFERRED MIRROR'S REMAINING BOUND, asserted beside the
         guards that moved rather than in a law of its own: every WRITE
         verb still fails to match without a source, so an
         over-narrowing change to the table fails HERE. install is the
         mirror's named member and S33 holds its end-to-end half."
        (Array
            with: (Array with: 'install')
            with: (Array with: 'update')) do: [:argv |
                self assert: (CLI verbRowFor: argv withSource: false) isNil
                    description: argv printString,
                        ' stopped requiring a source'.
                self deny: (CLI verbRowFor: argv withSource: true) isNil
                    description: argv printString,
                        ' stopped matching with a source'].
        (Array
            with: (Array with: 'remove' with: 'kernel-a')
            with: (Array with: 'add' with: 'kernel-a' with: '^1.0.0'))
                do: [:argv |
                    self assert: (CLI verbRowFor: argv withSource: false)
                        isNil
                        description: argv printString,
                            ' stopped requiring a source']
    ]

    testTheNeedsIndexGroundSurvivesByDerivation [
        "§8 decision 81 derives the ground from the declared table:
         SOME row matches with a source and NONE without. Nothing was
         edited to make #needsIndex stop firing for resolve, and this
         law is what says so — it asks the derivation directly, for a
         verb that moved and one that did not."
        self assert: (CLI usageGroundFor: (Array with: 'install')
            withSource: false) = #needsIndex
            description: 'install derives ',
                (CLI usageGroundFor: (Array with: 'install')
                    withSource: false) printString.
        self deny: (CLI usageGroundFor: (Array with: 'resolve')
            withSource: false) = #needsIndex
            description: 'resolve still derives the needs-index ground'.
        "THE DECLARED NON-MOVERS of the grammar half, asserted beside
         the ground that moved: an empty argv, an unknown verb and a
         known verb given arguments it does not take each derive exactly
         what they always did."
        self assert: (CLI usageGroundFor: #() withSource: false) = #noVerb.
        self assert: (CLI usageGroundFor: (Array with: 'nonsense')
            withSource: true) = #unknownVerb.
        self assert: (CLI usageGroundFor: (Array with: 'resolve'
            with: '--help') withSource: true) = #wrongArguments
            description: 'a trailing question flag derives ',
                (CLI usageGroundFor: (Array with: 'resolve' with: '--help')
                    withSource: true) printString
    ]

    "---- the three manifest states ----"

    testADependencyFreeManifestResolvesWithoutASource [
        "The first state, and the first-session defect it closes: no
         dependencies at all resolves, writes the lock and answers the
         settled confirmation line. It never needed an index; it failed
         by grammar."
        | work result |
        work := self workDir: 'pg-empty-work'
            contents: PathDepFixtures emptyRootContents.
        result := self resultOf: PathDepFixtures flaglessResolveArgv in: work.
        self assert: result exitCode = 0
            description: result lines printString.
        self assert: result lines
            = (Array with: 'no dependencies to resolve - wrote parley.lock')
            description: 'the settled confirmation line moved: ',
                result lines printString
    ]

    testAPathOnlyManifestResolvesOverTheOverlayAlone [
        "The second state: the overlay stands alone, with NO base source
         wired. A decorator that required a base would fail here and
         nowhere else."
        | work result |
        self sibling: 'pg-pathonly-text'.
        work := self workDir: 'pg-pathonly-work'
            contents: (PathDepFixtures rootDeclaring:
                (PathDepFixtures declaredPathFor: 'pg-pathonly-text')).
        result := self resultOf: PathDepFixtures flaglessResolveArgv in: work.
        self assert: result exitCode = 0
            description: result lines printString.
        self assert: result lines = (Array with: 'kernel-text 1.2.0')
            description: result lines printString
    ]

    testTheNeedsIndexRefusalIsTheDeclaredWordingConsumedTwice [
        "The third state's refusal is a DECLARED wording, read by the
         verb that refuses and by this law. Composing it at the site
         that refuses is the drift §8 decision 81 exists to prevent."
        | work result |
        work := self workDir: 'pg-needs-work'
            contents: PathDepFixtures indexNeedingRootContents.
        result := self resultOf: PathDepFixtures flaglessResolveArgv in: work.
        self assert: result lines = (Array with: (CLI needsIndexRefusalFor:
            (Array with: PathDepFixtures indexNeedingName)))
            description: result lines printString.
        self assert: result lines = (Array with: (PathDepFixtures
            needsIndexRefusalFor: (Array with:
                PathDepFixtures indexNeedingName)))
            description: 'the declared wording moved: ',
                result lines printString
    ]

    testAnIndexNeedingProjectRefusesInsideEveryReadOnlyVerb [
        "THE LAW §8 DECISION 84 OWES ITSELF, named in the decision
         rather than left to be noticed: an INDEX-PINNED project running
         a flagless read-only verb answers the DECLARED REFUSAL at exit
         1 — never the usage block.

         Nothing else drives that case. The six laws that forced the
         widening all drive PATH-ONLY projects, where there is nothing
         an index could supply and the refusal must never fire; this is
         the other direction, and without it the widening is unguarded
         in exactly the way it can go wrong — a verb that simply
         stopped asking would answer a snapshot-less question and blame
         the package, which is the wrong-blame class this project has
         spent six sprints closing.

         The project is resolved WITH a source first, so the lock exists
         and the verbs get past the settled missing-lock line: what is
         being tested is the index requirement, not the lock's absence.
         All three verbs are driven, because a guard wired into one is a
         guard two verbs do not have."
        | work index |
        index := self freshDir: 'pg-owed-index'.
        SourceFixtures write: (PathDepFixtures plainEntryFor: 'kernel-a'
            version: '1.0.0' dependencies: '')
            toFile: 'kernel-a-1.0.0.st' in: index.
        work := self workDir: 'pg-owed-work'
            contents: PathDepFixtures indexNeedingRootContents.
        self assert: (self resultOf: (PathDepFixtures resolveArgvOn: index)
            in: work) exitCode = 0
            description: 'the fixture never resolved, so the verbs below would answer the missing-lock line instead'.
        (Array
            with: (Array with: 'check')
            with: (Array with: 'tree')
            with: (Array with: 'why' with: PathDepFixtures indexNeedingName))
                do: [:argv |
                    | result |
                    result := self resultOf: argv in: work.
                    self assert: result exitCode = 1
                        description: argv printString, ' answered exit ',
                            result exitCode printString, ': ',
                            result lines printString.
                    self assert: result lines = (Array with: (CLI
                        needsIndexRefusalFor: (Array with:
                            PathDepFixtures indexNeedingName)))
                        description: argv printString, ' answered ',
                            result lines printString.
                    result lines do: [:line |
                        self deny: (CommandLineFixtures does: line
                            include: 'usage: parley')
                            description: argv printString,
                                ' answered the usage block']]
    ]

    testTheRefusalNamesEveryIndexNeedingDependencyAndNoPathOne [
        "It names WHAT THE MANIFEST DECLARES, which is the index-needing
         dependencies and not the path ones: telling an operator to wire
         an index for a directory they already have would be a remedy
         that cannot work."
        | work result |
        self sibling: 'pg-mixed-text'.
        work := self workDir: 'pg-mixed-work'
            contents: (PathDepFixtures rootDeclaring:
                (PathDepFixtures declaredPathFor: 'pg-mixed-text')
                andIndexDependency: 'kernel-a' constraint: '^1.0.0').
        result := self resultOf: PathDepFixtures flaglessResolveArgv in: work.
        self assert: result exitCode = 1
            description: result lines printString.
        self assert: (CommandLineFixtures does: result lines first
            include: '''kernel-a''')
            description: result lines first printString.
        self deny: (CommandLineFixtures does: result lines first
            include: 'kernel-text')
            description: 'the refusal named a path-supplied dependency: ',
                result lines first printString
    ]

    testAMalformedManifestUnderAFlaglessResolveAnswersTheAuthoringDiagnosis [
        "The command was LEGAL and the manifest is what is broken, so
         the authoring diagnosis is right rather than a leak. The read
         stays inside the verb, after the argv-pure determination and
         after state creation — which is the inversion the orphan record
         warned against, and the one this ruling does not make."
        | work result |
        work := self freshDir: 'pg-malformed-work'.
        ExecFixtures writePackage: PathDepFixtures malformedSiblingContents
            in: work.
        result := self resultOf: PathDepFixtures flaglessResolveArgv in: work.
        self assert: result exitCode = 1
            description: result lines printString.
        self assert: (result lines anySatisfy: [:line |
            CommandLineFixtures does: line include: 'invalid version'])
            description: result lines printString.
        result lines do: [:line |
            self deny: (CommandLineFixtures does: line
                include: 'usage: parley')
                description: 'the authoring diagnosis carried the usage block']
    ]

    testASourceLessResolveStillRefusesAnUnreadableLock [
        "resolve WRITES a lock even in its new states, so §8 decision
         56's readability check is owed exactly as before: answering
         exit 0 while unable to produce a lock is the fail-wrong that
         boundary exists to prevent. The new grammar must not have
         routed around it."
        | work result |
        work := self workDir: 'pg-lockdir-work'
            contents: PathDepFixtures emptyRootContents.
        Directory create: work, '/parley.lock'.
        result := self resultOf: PathDepFixtures flaglessResolveArgv in: work.
        self assert: result exitCode = 1
            description: 'a directory-shaped lock answered exit ',
                result exitCode printString, ': ', result lines printString.
        self assert: (result lines anySatisfy: [:line |
            CommandLineFixtures does: line
                include: 'not a regular readable file'])
            description: result lines printString
    ]

    "---- the matrix legs that are laws rather than scenarios ----"

    testTreeRendersAPathPinAsAnyPin [
        "tree renders name and version — both are true, and DEPTH is
         what tree reports. A verb that annotated provenance here would
         be answering why's question in tree's output."
        | work result |
        self sibling: 'pg-tree-text'.
        work := self workDir: 'pg-tree-work'
            contents: (PathDepFixtures rootDeclaring:
                (PathDepFixtures declaredPathFor: 'pg-tree-text')).
        self resultOf: PathDepFixtures flaglessResolveArgv in: work.
        result := self resultOf: (Array with: 'tree') in: work.
        self assert: result exitCode = 0
            description: result lines printString.
        self assert: result lines = (Array
            with: 'my-app 1.0.0'
            with: '  kernel-text 1.2.0')
            description: result lines printString
    ]

    testTheEditingVerbsRefuseTheTwoNewClauseKindsByteIdentically [
        "Doc B §2.1's STATED BOUND: a dependency:path: or a
         devDependency:constraint: clause is a shape add and remove do
         not recognize, so both answer the settled refusal with the file
         BYTE-IDENTICAL. Honest, and it costs the operator one hand
         edit; teaching the recognizer both kinds is deferred with its
         trigger.

         The file is compared byte for byte because an editor that
         recognized too little REFUSES while one that recognized wrongly
         DAMAGES — and the damage is a Package.st that no longer loads,
         written by the tool, in a file the author owns."
        | index |
        index := self freshDir: 'pg-edit-index'.
        SourceFixtures write: (PathDepFixtures plainEntryFor: 'kernel-b'
            version: '1.0.0' dependencies: '')
            toFile: 'kernel-b-1.0.0.st' in: index.
        (Array
            with: (Array with: 'pg-edit-path'
                with: (PathDepFixtures rootDeclaring: '../kernel-text'))
            with: (Array with: 'pg-edit-dev'
                with: (PathDepFixtures rootWithDevDependencyOn: 'kernel-lint'
                    constraint: '^1.0.0'))) do: [:row |
                | work before removed added |
                work := self workDir: (row at: 1) contents: (row at: 2).
                before := ManifestEditFixtures packageContentsIn: work.
                removed := self resultOf: (Array with: 'remove'
                    with: 'kernel-text' with: '--source' with: index) in: work.
                self assert: (ManifestEditFixtures packageContentsIn: work)
                    = before
                    description: (row at: 1), ': remove changed the file'.
                self assert: (removed lines anySatisfy: [:line |
                    CommandLineFixtures does: line include: 'kernel-text'])
                    description: (row at: 1), ': remove answered ',
                        removed lines printString.
                self deny: (removed lines anySatisfy: [:line |
                    CommandLineFixtures does: line
                        include: 'missing or unreadable'])
                    description: (row at: 1), ': the manifest never loaded — ',
                        removed lines printString.
                added := self resultOf: (Array with: 'add' with: 'kernel-b'
                    with: '^1.0.0' with: '--source' with: index) in: work.
                self assert: added exitCode = 0
                    description: (row at: 1), ': add answered exit ',
                        added exitCode printString, ': ',
                        added lines printString]
    ]

    testAddsAlreadyDeclaredCheckQuantifiesOverAllThreeKinds [
        "A name already declared as a PATH or a DEV dependency is
         already declared, and add must say so rather than inserting a
         second clause for the same name — which would produce a
         manifest the settled duplicate rule refuses, written by the
         tool."
        | index |
        index := self freshDir: 'pg-declared-index'.
        SourceFixtures write: (PathDepFixtures plainEntryFor: 'kernel-text'
            version: '1.0.0' dependencies: '')
            toFile: 'kernel-text-1.0.0.st' in: index.
        SourceFixtures write: (PathDepFixtures plainEntryFor: 'kernel-lint'
            version: '1.0.0' dependencies: '')
            toFile: 'kernel-lint-1.0.0.st' in: index.
        (Array
            with: (Array with: 'pg-declared-path' with: 'kernel-text'
                with: (PathDepFixtures rootDeclaring: '../kernel-text'))
            with: (Array with: 'pg-declared-dev' with: 'kernel-lint'
                with: (PathDepFixtures rootWithDevDependencyOn: 'kernel-lint'
                    constraint: '^1.0.0'))) do: [:row |
                | work before result |
                work := self workDir: (row at: 1) contents: (row at: 3).
                before := ManifestEditFixtures packageContentsIn: work.
                result := self resultOf: (Array with: 'add'
                    with: (row at: 2) with: '^1.0.0' with: '--source'
                    with: index) in: work.
                self assert: result exitCode = 1
                    description: (row at: 1), ': add answered exit ',
                        result exitCode printString, ': ',
                        result lines printString.
                self assert: (result lines anySatisfy: [:line |
                    CommandLineFixtures does: line
                        include: 'already declared'])
                    description: (row at: 1), ': ', result lines printString.
                self assert: (ManifestEditFixtures packageContentsIn: work)
                    = before
                    description: (row at: 1), ': the refusal edited the file']
    ]

    "---- the README obligation ----"

    testTheReadmeDocumentsBothFlagsAndTheWorkflow [
        "NO SETTLED LAW FORCES FLAG DOCUMENTATION — the settled README
         drift laws bind verbs only — so this sprint declares the
         obligation and the law that keeps it. The markers are declared
         once in the fixture and read here, in the Sprint 15
         layoutDocumentationMarkers shape."
        | readme |
        readme := (File name: 'README.md') contents.
        "The non-empty guard is MANDATORY rather than decorative and
         lives here rather than in a law of its own: a marker list that
         emptied would make the loop below pass while proving nothing —
         the Sprint 8 bin/ drift-law lesson, which this project has now
         paid for twice."
        self deny: PathDepFixtures readmeMarkers isEmpty
            description: 'the README marker list is empty'.
        PathDepFixtures readmeMarkers do: [:row |
            self assert: (CommandLineFixtures does: readme
                include: (row at: 2))
                description: 'the README never mentions ', (row at: 1),
                    ' (looked for ', (row at: 2) printString, ')']
    ]

]

Namespace current: Smalltalk.
