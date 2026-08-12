"Parley Sprint 20 - the usage grounds and the --help decoupling
 (issue #22; Doc E §4/§4.2, §8 decisions 57, 79 and 81).

 A USAGE ERROR IS A REASON LINE FOLLOWED BY THE BLOCK; --help IS THE
 BLOCK ALONE. Three genuinely different mistakes - and a fourth the
 first draft of decision 79 dropped - answered a BYTE-IDENTICAL
 six-line block at exit 2, so the tool told the operator what it offers
 and never what they did. The block is good reference and a poor
 diagnosis.

 THE SHARED ARTIFACT IS THE BLOCK, NOT THE ANSWER. --help took the
 usage answer WHOLESALE, and its own method comment recorded that as a
 feature. Once a usage error names what was wrong, that coupling puts
 `no verb given` above --help - a fault asserted about a request that
 has none, which is the whole of decision 57. So both compose the same
 block, neither is derived from the other's finished answer, and this
 file asserts that relationship rather than two literals.

 SIX REASONS, ONE DECLARED TABLE (§8 decision 81). Four grounds are the
 verb grammar's - no verb, an unknown verb, a known verb given
 arguments it does not take, and a verb that needs an index with none
 given - and two are decided outside it: both source flags, refused
 before any verb exists, and an unrecognized --layout, refused after a
 verb row already matched. NEITHER of those two composes its own
 sentence: two sites each writing their own wording is two wordings no
 drift law can ever see, which is the drift the sourceFlags /
 publishLayouts / verbRows idiom exists to prevent.

 THE FOURTH GROUND IS INDEPENDENT, AND THE ORDER OF THE TEST MATTERS.
 `resolve --help` answers usage EVEN WITH A SOURCE WIRED, so its ground
 is the arity and never the index; and a source-requiring verb with
 correct arity and no source must be told it needs an index rather than
 that it holds the wrong arguments. Both directions are asserted here,
 because a derivation that tested arity first would answer the wrong
 sentence for the commonest usage error there is.

 NO LAW HERE INDEXES AN ABSOLUTE LINE. Every assertion locates the
 block by its start or asserts the answer ENDS with it. Eleven settled
 methods pinned `lines at: 2` into this block and every one of them
 moved this sprint; adding a twelfth would be writing the same defect
 into the sprint that found it.

 DECLARED PASSES IN RED (issue #22): NONE in this file. Two laws send
 CommandLine and CLI selectors that do not exist yet and abort as
 ERRORS at that send; every other law asserts an answer that carries a
 reason line the pre-sprint tree does not compose, or a block whose
 verbs row the pre-sprint tree has not grown. The two drift laws over
 sourceFlags and publishLayouts deliberately assert the SHIPPED first
 line rather than the fixture wording - a law that only checked the
 fixture would pass in red while testing nothing at all.

 Every fixture path is under tmp/, unique per label, removed
 recursively in tearDown; every runner is a TrapRunner, so anything
 that reached the process seam would answer 70 rather than 2 and the
 `nothing was built` half is proved rather than assumed."

Namespace current: Parley.

TestCase subclass: UsageGroundTest [
    | fixtureDirs |

    <comment: 'Laws for the six declared usage grounds: the table read
twice, each ground''s own first line, the derivation order that keeps
`needs an index` from being reported as `wrong arguments`, the two
grounds decided outside the verb grammar, and --help answering the
block alone at exit 0.'>

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

    resultOf: anArgvArray in: aWorkDir [
        ^(CommandLine in: aWorkDir runner: TrapRunner new) run: anArgvArray
    ]

    answerFor: anArgvArray labelled: aLabel [
        ^self resultOf: anArgvArray in: (self freshDir: aLabel)
    ]

    "---- the declared table, read twice ----"

    testTheDeclaredTableCarriesTheSixGroundsInOrder [
        "A DECLARATION CONSUMED TWICE, exactly as sourceFlags,
         publishLayouts and verbRows are: the composition reads it and
         this law reads the same rows, so a seventh ground can never
         arrive with a sentence nothing checks."
        | grounds |
        self deny: CommandLine usageReasons isEmpty
            description: 'the reason table is empty - a drift law over an empty collection proves nothing'.
        grounds := CommandLine usageReasons collect: [:row | row at: 1].
        self assert: grounds asArray = GrammarFixtures declaredGroundSymbols
            description: 'the declared grounds are ', grounds printString.
        CommandLine usageReasons do: [:row |
            self assert: row size = 2
                description: 'a reason row is not (ground, reason): ',
                    row printString.
            self assert: (row at: 1) isSymbol
                description: 'the first column names the ground']
    ]

    testEachDeclaredRowComposesItsPinnedSentence [
        "The wordings were pinned at the pre-RED ruling because they land
         at some thirty assertion sites; this is where the table is held
         to them."
        | subject |
        subject := 'resolve'.
        GrammarFixtures declaredGroundSymbols do: [:ground |
            self assert: (CommandLine usageReasonFor: ground subject: subject)
                = (GrammarFixtures reasonFor: ground subject: subject)
                description: ground printString, ' composed ',
                    (CommandLine usageReasonFor: ground subject: subject)
                        printString]
    ]

    testTheBlockHasOneDefinitionAndTheOracleIsIt [
        "The block is the shared artifact, so it has exactly one
         definition in src/ and one oracle in tests/. Five literal
         copies of this block or its verbs row lived in the suite before
         this sprint; the oracle below is now the only one."
        self assert: CLI usageBlock asArray = ExecFixtures usageLines
            description: 'the shipped block is ', CLI usageBlock printString
    ]

    "---- the four verb-grammar grounds ----"

    testEachVerbGrammarGroundAnswersItsOwnFirstLine [
        "One reason line, then the block, at exit 2 - driven through the
         real composition root rather than composed here."
        | rows |
        rows := (Array
            with: (Array with: 'ug-noverb' with: #() with: #noVerb with: '')
            with: (Array with: 'ug-unknown' with: #('conjure')
                with: #unknownVerb with: 'conjure')),
            (Array
                with: (Array with: 'ug-arity' with: #('exec')
                    with: #wrongArguments with: 'exec')
                with: (Array with: 'ug-index' with: #('resolve')
                    with: #needsIndex with: 'resolve')).
        rows do: [:row |
            | result |
            result := self answerFor: (row at: 2) labelled: (row at: 1).
            self assert: result exitCode = 2
                description: (row at: 2) printString, ' answered exit ',
                    result exitCode printString.
            self assert: result lines = (GrammarFixtures
                usageAnswerFor: (row at: 3) subject: (row at: 4))
                description: (row at: 2) printString, ' answered ',
                    result lines printString]
    ]

    testTheFourFirstLinesDifferFromEachOther [
        "Distinguished rather than merged: `you typed a verb that does
         not exist` and `that verb needs an index and you gave none`
         have different repairs, so they must not be the same sentence."
        | argvs seen |
        argvs := (Array with: #() with: #('conjure')),
            (Array with: #('exec') with: #('resolve')).
        seen := OrderedCollection new.
        argvs doWithIndex: [:argv :i |
            | first |
            first := (self answerFor: argv
                labelled: 'ug-distinct-', i printString) lines first.
            self deny: (seen includes: first)
                description: argv printString,
                    ' repeated an earlier reason: ', first printString.
            seen add: first]
    ]

    testAVerbThatNeedsAnIndexIsToldSoRatherThanToldItsArgumentsAreWrong [
        "The derivation tests availability BEFORE arity. `parley resolve`
         has exactly the arguments resolve takes; what it lacks is an
         index, and telling the operator their arguments are wrong would
         be a sentence the tool never checked."
        | result |
        result := self answerFor: #('resolve') labelled: 'ug-order-index'.
        self assert: result lines first
            = (GrammarFixtures needsIndexReasonFor: 'resolve')
            description: 'a source-less resolve was told ',
                result lines first printString
    ]

    testAWrongArityVerbIsToldSoEvenWhenASourceIsWired [
        "The other direction, and the probe that proves the fourth
         ground is independent rather than a spelling of its neighbour:
         with a source wired, `resolve --help` STILL answers usage, so
         its ground is the arity and never the index."
        | work index result |
        work := self freshDir: 'ug-order-arity-work'.
        index := self freshDir: 'ug-order-arity-index'.
        result := self resultOf: (Array with: 'resolve' with: '--help'
            with: '--source' with: index) in: work.
        self assert: result exitCode = 2
            description: 'resolve --help with a source answered exit ',
                result exitCode printString.
        self assert: result lines first
            = (GrammarFixtures wrongArgumentsReasonFor: 'resolve')
            description: 'resolve --help with a source was told ',
                result lines first printString
    ]

    "---- the two grounds decided outside the verb grammar ----"

    testBothSourceFlagsCarryTheirOwnDeclaredReason [
        "Refused in the composition root BEFORE any verb exists, so
         borrowing a verb-grammar reason would tell an operator who
         typed a verb that they gave none."
        | work index repo result |
        work := self freshDir: 'ug-both-work'.
        index := self freshDir: 'ug-both-index'.
        repo := self freshDir: 'ug-both-repo'.
        result := self resultOf: (Array with: 'resolve'
            with: '--source' with: index with: '--git') , (Array with: repo)
            in: work.
        self assert: result exitCode = 2.
        self assert: result lines
            = (GrammarFixtures usageAnswerFor: #bothSourceFlags subject: '')
            description: 'two source flags answered ', result lines printString
    ]

    testAnUnrecognizedLayoutCarriesItsOwnDeclaredReason [
        "Refused inside the verb, AFTER a row already matched - the one
         usage answer this tool composes from inside a verb, and the
         reason it needs a declared row of its own."
        | work dest result |
        work := self freshDir: 'ug-layout-work'.
        dest := self freshDir: 'ug-layout-dest'.
        result := self resultOf: (Array with: 'publish' with: dest
            with: '--layout' with: 'nonsense') in: work.
        self assert: result exitCode = 2.
        self assert: result lines = (GrammarFixtures
            usageAnswerFor: #unknownLayout subject: 'nonsense')
            description: 'an unrecognized layout answered ',
                result lines printString
    ]

    "---- the two sentences composed from declared tables ----"

    testTheNeedsIndexSentenceNamesEveryDeclaredSourceFlag [
        "A flag added to sourceFlags later must not be able to drift out
         of this sentence, so the sentence is composed from the table
         rather than typed. Asserted on the SHIPPED first line: a law
         that read the fixture instead would be checking its own
         wording."
        | first |
        first := (self answerFor: #('resolve') labelled: 'ug-flags') lines
            first.
        self assert: first = (GrammarFixtures needsIndexReasonFor: 'resolve')
            description: 'the needs-an-index line is ', first printString.
        CommandLine sourceFlags do: [:row |
            self assert: (CommandLineFixtures does: first
                include: (row at: 1))
                description: 'the sentence does not name ', (row at: 1)]
    ]

    testTheUnknownLayoutSentenceNamesEveryDeclaredLayout [
        "The sentence names every layout the table declares.

         THE EMPTINESS GUARD BELOW IS THIS LAW'S OWN (CF-6, cleared at
         Sprint 21's Gate A). The carried gap read this law as borrowing
         PublishLayoutTest's `deny: rows isEmpty` — an empty table makes
         the iteration prove nothing. THE PROBE REFUTES THAT READING:
         stubbing CommandLine publishLayouts to #() makes this law FAIL
         rather than pass vacuously, because the byte-pinned first
         assertion catches the empty table on its own — GrammarFixtures
         unknownLayoutReasonFor: is a LITERAL and does not move with the
         table, so a table that loses a layout, gains one, or empties
         breaks the sentence comparison before the loop is ever reached.
         The guard is kept regardless: it costs one line, it makes the
         non-vacuity local instead of a consequence of another method's
         current shape, and it is what would still hold the day that
         oracle is derived from the table rather than written out."
        | work dest first |
        work := self freshDir: 'ug-layoutnames-work'.
        dest := self freshDir: 'ug-layoutnames-dest'.
        first := (self resultOf: (Array with: 'publish' with: dest
            with: '--layout' with: 'nonsense') in: work) lines first.
        self assert: first
            = (GrammarFixtures unknownLayoutReasonFor: 'nonsense')
            description: 'the unknown-layout line is ', first printString.
        self deny: CommandLine publishLayouts isEmpty
            description: 'publishLayouts is empty - the iteration below would prove nothing'.
        CommandLine publishLayouts do: [:row |
            self assert: (CommandLineFixtures does: first
                include: (row at: 1))
                description: 'the sentence does not name the ',
                    (row at: 1), ' layout']
    ]

    "---- the decoupling ----"

    testTheQuestionAnswersTheBlockAloneAtExitZero [
        "--help, -h and the bare help are one question with three
         spellings, and none of them made a mistake: the block alone, no
         reason line, exit 0, all three identical."
        | first |
        first := nil.
        ReadinessFixtures helpSpellings doWithIndex: [:spelling :i |
            | result |
            result := self answerFor: (Array with: spelling)
                labelled: 'ug-help-', i printString.
            self assert: result exitCode = 0
                description: spelling, ' answered exit ',
                    result exitCode printString.
            self assert: result lines = GrammarFixtures usageBlockLines
                description: spelling, ' answered ', result lines printString.
            first isNil
                ifTrue: [first := result lines]
                ifFalse: [self assert: result lines = first
                    description: spelling, ' answered different lines']]
    ]

    testTheUsageAnswerEndsWithTheHelpBlockAndOpensWithItsReason [
        "The relationship, asserted as a relationship: the usage error's
         TAIL is exactly what --help answers, and its first line is the
         reason. Stronger than the equality it replaces, because it pins
         the shared text AND the added line in one assertion - and it
         locates the block by its start rather than by an offset."
        | help usage tail |
        help := self answerFor: (Array with: ReadinessFixtures helpFlag)
            labelled: 'ug-tail-help'.
        usage := self answerFor: #() labelled: 'ug-tail-usage'.
        self assert: help exitCode = 0.
        self assert: usage exitCode = 2.
        self assert: usage lines size = (help lines size + 1)
            description: 'the usage answer is ', usage lines size printString,
                ' lines beside a block of ', help lines size printString.
        tail := usage lines copyFrom: 2 to: usage lines size.
        self assert: tail = help lines
            description: 'the usage answer''s tail is not the help block: ',
                tail printString.
        self assert: usage lines first = GrammarFixtures noVerbReason
            description: 'the usage answer opens with ',
                usage lines first printString
    ]

    testTheQuestionNeverCarriesAReasonLine [
        "The evidence that --help stayed a question. Every declared
         reason is denied of the block, so a coupling reintroduced later
         fails here rather than at whichever settled guard noticed
         first."
        | help |
        help := self answerFor: (Array with: ReadinessFixtures helpFlag)
            labelled: 'ug-noreason'.
        self assert: help lines = GrammarFixtures usageBlockLines
            description: '--help answered ', help lines printString.
        GrammarFixtures declaredGroundSymbols do: [:ground |
            | reason |
            reason := GrammarFixtures reasonFor: ground subject: 'resolve'.
            help lines do: [:line |
                self deny: line = reason
                    description: '--help carried the ', ground printString,
                        ' reason']]
    ]
]

Namespace current: Smalltalk.
