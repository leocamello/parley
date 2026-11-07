"Parley Sprint 23 — the diagram declaration pair, decision 88.
 These textual laws prove class names and their positions within the
 approved notation. They prove nothing about arrows, behavior, layout
 quality or Mermaid rendering. No law is declared passing in RED:
 controls run first, then the missing real diagram census fails."

Namespace current: Parley.

TestCase subclass: DiagramDriftTest [

    assertFailure: category token: token in: failures [
        self assert: (DiagramFixtures hasFailure: category token: token in: failures)
            description: 'missing ', category printString, ' for ', token.
        failures do: [:failure |
            self deny: (failure at: #path) isEmpty.
            self assert: (failure at: #line) > 0]
    ]

    assertSupported: text [
        self assert: (DiagramFixtures classFailuresIn:
            (DiagramFixtures blockWithText: text path: 'fixture.md')) isEmpty
    ]

    assertGrammarControls [
        "Whole-token, whole-segment grammar. A valid control prevents
         universal rejection from satisfying every negative fixture."
        | nl block failures |
        nl := SourceFixtures newline.
        self assert: (DiagramFixtures identifierListIn: 'Resolver')
            = #('Resolver').
        self assert: (DiagramFixtures identifierListIn:
            ' Resolver + Resolution, ConflictReport · Installer ')
                = #('Resolver' 'Resolution' 'ConflictReport' 'Installer').
        #('read metadata' 'Package.st' 'Resolver ++ Resolution' 'Resolver,'
            '+ Resolver' '') do: [:prose |
                self assert: (DiagramFixtures identifierListIn: prose) isNil].
        self assertSupported: 'flowchart LR', nl,
            'a["Resolver<br/>read metadata"]', nl,
            'b["Resolution + ConflictReport"]', nl,
            'a -->|choose a result| b', nl,
            'a -.-> b', nl, '%% ordinary comment', nl.
        self assertSupported: 'flowchart TD', nl,
            'n["ResolverInput description"]', nl.
        block := DiagramFixtures blockWithText:
            'flowchart TD', nl, 'n(Resolver)', nl path: 'unsupported.md'.
        failures := DiagramFixtures classFailuresIn: block.
        self assertFailure: #unsupportedSyntax token: 'n(Resolver)' in: failures.
        #('Resolver["read metadata"]'
            'a -->|Resolver handles packages| b'
            '%% Resolver is mentioned here') do: [:outside |
                block := DiagramFixtures blockWithText:
                    'flowchart TD', nl, 'n["Resolver"]', nl, outside, nl
                    path: 'outside.md'.
                self assertFailure: #classOutsidePosition token: 'Resolver'
                    in: (DiagramFixtures classFailuresIn: block)].
        block := DiagramFixtures validBlock.
        self assert: (DiagramFixtures classFailuresIn: block) isEmpty.
        self assertFailure: #nonLocalClass token: 'Array'
            in: (DiagramFixtures classFailuresIn:
                (DiagramFixtures replacingFirstClassIn: block with: 'Array')).
        self assertFailure: #unknownClass token: 'NoSuchClass'
            in: (DiagramFixtures classFailuresIn:
                (DiagramFixtures replacingFirstClassIn: block with: 'NoSuchClass')).
        self assertFailure: #classOutsidePosition token: 'Resolver'
            in: (DiagramFixtures classFailuresIn:
                (DiagramFixtures placingClassInProseIn: block))
    ]

    realBlocks [
        | sources blocks |
        sources := DocumentationFixtures documentationSourcesUnder: '.'.
        self deny: sources isEmpty.
        blocks := DiagramFixtures blocksInSources: sources.
        self deny: blocks isEmpty
            description: 'the real documentation has no Mermaid blocks'.
        self assert: (DiagramFixtures censusFailuresIn: sources) isEmpty
            description: 'the real documentation does not have the four ruled diagrams'.
        ^blocks
    ]

    testTheDiagramCensusMatchesTheWholeDocumentationTree [
        "The real four-file census is a textual presence claim, not
         a rendering test. Removing a real block must break the pair."
        | sources blocks removed path extraction |
        self assertGrammarControls.
        sources := DocumentationFixtures documentationSourcesUnder: '.'.
        self deny: sources isEmpty.
        blocks := self realBlocks.
        self assert: blocks size = 4.
        removed := sources copy.
        path := DiagramFixtures expectedPaths first.
        extraction := DocumentationFixtures fencedBlocksIn: (sources at: path) path: path.
        self assert: ((extraction at: #blocks) anySatisfy: [:block |
            (block at: #tag) = 'mermaid']).
        removed at: path put: ''.
        self assertFailure: #diagramPath token: path
            in: (DiagramFixtures censusFailuresIn: removed)
    ]

    testClassPositionsNameLocalClassesAndRejectDoctoredNames [
        "Names in whole identifier-list segments are local behaviors.
         This proves neither edge correctness nor diagram rendering."
        | blocks positions chosen mutated |
        self assertGrammarControls.
        blocks := self realBlocks.
        positions := OrderedCollection new.
        blocks do: [:block |
            self assert: (DiagramFixtures classFailuresIn: block) isEmpty.
            positions addAll: (((DiagramFixtures nodeSegmentsIn: block)
                at: #segments) select: [:segment |
                    (segment at: #identifiers) notNil])].
        self deny: positions isEmpty
            description: 'the real diagrams declare no class-position identifiers'.
        chosen := blocks detect: [:block |
            ((DiagramFixtures nodeSegmentsIn: block) at: #segments)
                anySatisfy: [:segment | (segment at: #identifiers) notNil]].
        #('NoSuchClass' 'Array') do: [:replacement |
            mutated := DiagramFixtures replacingFirstClassIn: chosen with: replacement.
            self deny: (mutated at: #text) = (chosen at: #text).
            self assertFailure:
                (replacement = 'Array' ifTrue: [#nonLocalClass] ifFalse: [#unknownClass])
                token: replacement in: (DiagramFixtures classFailuresIn: mutated)]
    ]

    testLocalClassNamesCannotHideOutsideClassPosition [
        "The complement of class-position spans is scanned by identifier
         tokens, including prose, IDs, comments and edge labels. Arrow
         meaning and rendered output are outside this textual claim."
        | blocks chosen mutated |
        self assertGrammarControls.
        blocks := self realBlocks.
        self deny: DiagramFixtures localClassNames isEmpty.
        blocks do: [:block |
            self assert: (DiagramFixtures classFailuresIn: block) isEmpty].
        chosen := blocks detect: [:block |
            ((DiagramFixtures nodeSegmentsIn: block) at: #segments) isEmpty not].
        mutated := DiagramFixtures placingClassInProseIn: chosen.
        self deny: (mutated at: #text) = (chosen at: #text).
        self assertFailure: #classOutsidePosition token: 'Resolver'
            in: (DiagramFixtures classFailuresIn: mutated)
    ]
]

Namespace current: Smalltalk.
