"Parley Sprint 23 — documentation declarations and their drift pairs.
 Issue #25 S1-S17; architecture decisions 88-90; approved 2026-11-07
 resumption protocol. The baseline is 1169 tests and 91 decisions.

 TEXTUAL BOUND. These tests check declarations, named classes, fenced
 instructions and document sets. They do not prove prose accuracy,
 diagram arrows, rendered layout or a stranger's ability to follow
 the guide. Those remain the documented Gate B review and walk.

 Exactly six declared passes in RED: S5, S6, S10, S15, S16, S17.
 S10 and S15-S17 keep their atomic extraction/fixture meanings; no
 missing repository artifact is added merely to make them fail.
 S1-S4, S7-S9, S11-S14 require the real artifacts and fail until
 those artifacts arrive in GREEN. Their post-guard falsifiers are
 not claimed as executed before that point.

 COST: in-image reads and one isolated recursive fixture under tmp/;
 no child process, network, production mutation or document write."

Namespace current: Parley.

TestCase subclass: Sprint23AcceptanceTest [
    | fixtureDirs |

    <comment: 'The seventeen Sprint 23 documentation scenarios:
instruction-bearing moved claims, preserved README contracts,
release/guide and decision/index pairs, diagram census and local
class declarations, and the recursive documentation domain.'>

    setUp [
        fixtureDirs := OrderedCollection new
    ]

    tearDown [
        fixtureDirs isNil ifTrue: [^self].
        fixtureDirs do: [:each | ExecFixtures removeTree: each].
        fixtureDirs := nil
    ]

    freshDir: aLabel [
        | path |
        path := 'tmp/parley-', aLabel.
        ExecFixtures removeTree: path.
        path := SourceFixtures directoryNamed: aLabel.
        fixtureDirs add: path.
        ^path
    ]

    runningCodeSource [
        ^DocumentationFixtures sourceAt: 'docs/guide/running-code.md'
    ]

    publishingSource [
        ^DocumentationFixtures sourceAt: 'docs/guide/publishing.md'
    ]

    repositorySources [
        ^DocumentationFixtures documentationSourcesUnder: '.'
    ]

    repositoryBlocks [
        | sources failures blocks |
        sources := self repositorySources.
        self deny: sources isEmpty
            description: 'the documentation source walk is empty'.
        failures := DiagramFixtures censusFailuresIn: sources.
        blocks := DiagramFixtures blocksInSources: sources.
        self deny: blocks isEmpty
            description: 'the repository has no Mermaid diagrams'.
        self assert: failures isEmpty
            description: 'the diagram census or extraction failed: ',
                failures printString.
        ^blocks
    ]

    fencedSourceFor: aBlock [
        ^'```mermaid', (String with: Character nl),
            (aBlock at: #text), '```', (String with: Character nl)
    ]

    testS1_TheExecConstraintMovesWithItsLaw [
        "The actual destination page must contain both instructions;
         a doctored copy must specifically lose the CI constraint."
        | source removed failures |
        source := self runningCodeSource.
        self deny: source isEmpty
            description: 'docs/guide/running-code.md is missing or empty'.
        self assert: (DocumentationFixtures execGuideFailuresIn: source) isEmpty
            description: 'the running-code guide lacks the exec instructions'.
        removed := (source copyReplaceAll: 'matters to CI' with: '')
            copyReplaceAll: 'ObjectMemory quit: 1' with: ''.
        self deny: removed = source
            description: 'the exec-constraint mutation changed nothing'.
        failures := DocumentationFixtures execGuideFailuresIn: removed.
        self assert: (DocumentationFixtures hasFailure: #missingProse
            token: 'matters to CI' in: failures).
        self assert: (DocumentationFixtures hasFailure: #missingCode
            token: 'ObjectMemory quit: 1' in: failures)
    ]

    testS2_TheExecInstructionCannotBeReplacedByProse [
        "Keeping the CI sentence cannot substitute for fenced code.
         A code-shaped marker outside a fence cannot rescue it either."
        | source removed proseOnly failures |
        source := self runningCodeSource.
        self deny: source isEmpty
            description: 'docs/guide/running-code.md is missing or empty'.
        self assert: (DocumentationFixtures execGuideFailuresIn: source) isEmpty.
        removed := source copyReplaceAll: 'ObjectMemory quit: 1' with: ''.
        self deny: removed = source
            description: 'the explicit-quit mutation changed nothing'.
        self assert: (CommandLineFixtures does: removed include: 'matters to CI').
        failures := DocumentationFixtures execGuideFailuresIn: removed.
        self assert: (DocumentationFixtures hasFailure: #missingCode
            token: 'ObjectMemory quit: 1' in: failures).
        proseOnly := 'This matters to CI. ObjectMemory quit: 1',
            (String with: Character nl).
        self assert: (DocumentationFixtures hasFailure: #missingCode
            token: 'ObjectMemory quit: 1'
            in: (DocumentationFixtures execGuideFailuresIn: proseOnly))
    ]

    testS3_BothLayoutInstructionsMoveWithTheirLaw [
        "Both command examples must live in shell fences on the
         actual guide page; removing their flag is observable."
        | source removed failures |
        source := self publishingSource.
        self deny: source isEmpty
            description: 'docs/guide/publishing.md is missing or empty'.
        self assert: (DocumentationFixtures publishingGuideFailuresIn: source) isEmpty.
        removed := source copyReplaceAll: '--layout' with: ''.
        self deny: removed = source
            description: 'the layout-flag mutation changed nothing'.
        failures := DocumentationFixtures publishingGuideFailuresIn: removed.
        #('flat' 'sparse') do: [:layout |
            self assert: (DocumentationFixtures hasFailure: #missingCode
                token: 'parley publish ../my-index --layout ', layout
                in: failures)]
    ]

    testS4_MarketingCannotSatisfyThePublishingInstructions [
        "The README keeps its marketing claim while both guide
         commands are removed. Only the guide commands satisfy the law."
        | source readme removed failures |
        source := self publishingSource.
        self deny: source isEmpty
            description: 'docs/guide/publishing.md is missing or empty'.
        self assert: (DocumentationFixtures publishingGuideFailuresIn: source) isEmpty.
        readme := ReleaseFixtures readmeText.
        self assert: (CommandLineFixtures does: readme
            include: 'flat, or the per-package sparse layout')
            description: 'the discriminator has lost its retained marketing claim'.
        removed := source.
        #('flat' 'sparse') do: [:layout |
            removed := removed copyReplaceAll:
                'parley publish ../my-index --layout ', layout with: ''].
        self deny: removed = source
            description: 'the publishing-instruction mutation changed nothing'.
        failures := DocumentationFixtures publishingGuideFailuresIn: removed.
        #('flat' 'sparse') do: [:layout |
            self assert: (DocumentationFixtures hasFailure: #missingCode
                token: 'parley publish ../my-index --layout ', layout
                in: failures)].
        self assert: ReleaseFixtures readmeText = readme
            description: 'the retained README changed during the fixture check'
    ]

    testS5_TheReadmeNamesEveryLiveUsageVerb [
        "Declared RED pass. The oracle is the live usage response;
         an empty extraction must never make the comparison pass."
        | work result verbs readme |
        work := self freshDir: 's23-5-usage'.
        result := (CommandLine in: work runner: TrapRunner new) run: #().
        verbs := PublishLayoutFixtures verbsIn:
            (GrammarFixtures verbsRowIn: result lines).
        self deny: verbs isEmpty
            description: 'the live usage response yielded no verbs'.
        readme := ReleaseFixtures readmeText.
        verbs do: [:verb |
            self assert: (CommandLineFixtures does: readme include: 'parley ', verb)
                description: 'the README omits the live verb ', verb]
    ]

    testS6_TheSettledReadmeShapeAndTallyDoNotRegress [
        "Declared RED pass. Execute the named settled assertions;
         deliberately exclude both discovered-law-count assertions."
        ReleaseDriftTest new testTheReadmeCarriesTheRuledSlotsInTheRuledOrder.
        ReleaseDriftTest new testTheReadmeTallyEqualsTheFindingsTally.
        Sprint22AcceptanceTest new
            testS27_TheReadmeOpensWithBadgePitchInstallationAndTheHero.
        Sprint22AcceptanceTest new
            testS28_HowThisWasBuiltLinksTheRecordAndQuotesTheTally.
        Sprint22AcceptanceTest new
            testS30_TheShowcaseSectionSitsBesideHowThisWasBuilt
    ]

    testS7_TheGuideIndexEntersTheReleaseDeclaration [
        | declaration missing absent |
        declaration := Parley releaseFiles.
        self deny: declaration isEmpty.
        self assert: (declaration includes: 'docs/guide/README.md')
            description: 'the release declaration omits docs/guide/README.md'.
        missing := ReleaseFixtures missingReleaseFilesIn: declaration.
        self assert: missing isEmpty
            description: 'declared release files are absent or empty: ', missing printString.
        absent := 'no-such-sprint-23-release-file.md'.
        self deny: (File name: absent) exists
            description: 'the release falsifier must be an absent name'.
        missing := ReleaseFixtures missingReleaseFilesIn:
            (declaration, (Array with: absent)).
        self assert: missing asArray = (Array with: absent)
            description: 'the release walk did not isolate the injected absent name'
    ]

    testS8_TheGuideIndexEqualsThePagesOnDisk [
        | source pages links removed failures |
        source := DocumentationFixtures sourceAt: 'docs/guide/README.md'.
        pages := DocumentationFixtures guidePageNamesUnder: 'docs/guide'.
        self deny: source isEmpty
            description: 'docs/guide/README.md is missing or empty'.
        self deny: pages isEmpty
            description: 'the guide page walk is empty'.
        links := DocumentationFixtures guideLinksIn: source.
        self deny: links isEmpty
            description: 'the guide declaration contains no page links'.
        self assert: links asSet = pages asSet.
        self assert: links size = pages size.
        self assert: (DocumentationFixtures guideFailuresIn: source
            pageNames: pages) isEmpty.
        removed := pages first.
        failures := DocumentationFixtures guideFailuresIn: source
            pageNames: (pages reject: [:each | each = removed]).
        self assert: (DocumentationFixtures hasFailure: #missingGuidePage
            token: removed in: failures)
            description: 'the guide comparator did not name the removed page'
    ]

    testS9_TheDecisionIndexNamesEveryDecisionExactlyOnce [
        | source numbers rows rowNumbers |
        source := DecisionIndexFixtures architectureSource.
        numbers := DecisionIndexFixtures decisionNumbersIn: source.
        self deny: numbers isEmpty
            description: 'the bounded decision extraction is empty'.
        self assert: numbers size = 91.
        self assert: numbers asSet = (1 to: 91) asSet.
        rows := DecisionIndexFixtures indexRowsIn: source.
        self deny: rows isEmpty
            description: 'the decision index contains no rows'.
        rowNumbers := rows collect: [:row | row at: #number].
        self assert: rowNumbers size = numbers size.
        self assert: rowNumbers asSet = numbers asSet.
        self assert: (DecisionIndexFixtures indexFailuresIn: source) isEmpty
            description: 'the index has malformed, duplicate, unordered or misanchored rows'
    ]

    testS10_TheDecisionExtractionIsBoundedToSectionEight [
        "Declared RED pass: the source already has the section.
         No index assertion is smuggled into this extraction scenario."
        | source section bounded whole outside |
        source := DecisionIndexFixtures architectureSource.
        section := DecisionIndexFixtures decisionSectionIn: source.
        self deny: section isEmpty.
        bounded := DecisionIndexFixtures decisionNumbersIn: source.
        whole := DecisionIndexFixtures wholeFileDecisionNumbersIn: source.
        self deny: bounded isEmpty.
        self assert: bounded size = 91.
        self assert: bounded asSet = (1 to: 91) asSet.
        self assert: whole size = 100.
        outside := source copyReplaceAll: section with: ''.
        self deny: outside = source.
        self assert: (DecisionIndexFixtures wholeFileDecisionNumbersIn: outside) size = 9
            description: 'the nine out-of-section numbered items were not excluded'
    ]

    testS11_TheDecisionIndexComparatorFailsInBothDirections [
        | source rows removed grown failures |
        source := DecisionIndexFixtures architectureSource.
        rows := DecisionIndexFixtures indexRowsIn: source.
        self deny: rows isEmpty
            description: 'a real decision index is required before its row falsifier'.
        self assert: (DecisionIndexFixtures indexFailuresIn: source) isEmpty.
        removed := DecisionIndexFixtures removingIndexRow: 91 from: source.
        self deny: removed = source
            description: 'the index-row mutation changed nothing'.
        failures := DecisionIndexFixtures indexFailuresIn: removed.
        self assert: (DecisionIndexFixtures hasFailure: #missingIndexRow
            token: 91 in: failures).
        grown := DecisionIndexFixtures appendingUnindexedDecision: 92 to: source.
        self deny: grown = source
            description: 'the unindexed-decision mutation changed nothing'.
        self assert: (DecisionIndexFixtures decisionNumbersIn: grown) size = 92.
        failures := DecisionIndexFixtures indexFailuresIn: grown.
        self assert: (DecisionIndexFixtures hasFailure: #missingIndexRow
            token: 92 in: failures)
            description: 'the comparator did not specifically diagnose missing index row 92'
    ]

    testS12_TheFourDeclaredDiagramFilesHaveExactlyOneBlockEach [
        | blocks |
        blocks := self repositoryBlocks.
        self assert: blocks size = 4
            description: 'the complete documentation domain does not contain exactly four diagrams'
    ]

    testS13_EveryClassPositionNamesALocalBehavior [
        "Textual soundness only; no statement about arrows or behavior."
        | blocks identifierCount |
        blocks := self repositoryBlocks.
        identifierCount := 0.
        blocks do: [:block |
            | failures |
            ((DiagramFixtures nodeSegmentsIn: block) at: #segments) do: [:segment |
                (segment at: #identifiers) isNil ifFalse: [
                    identifierCount := identifierCount + (segment at: #identifiers) size]].
            failures := DiagramFixtures classFailuresIn: block.
            self assert: (failures reject: [:each |
                (each at: #category) = #classOutsidePosition]) isEmpty
                description: 'a diagram has an invalid class position or syntax: ',
                    failures printString].
        self assert: identifierCount > 0
            description: 'the real diagrams declare no class identifiers'
    ]

    testS14_NoLocalClassNameHidesOutsideClassPosition [
        "Textual prohibition only; no statement about arrows or behavior."
        | blocks |
        blocks := self repositoryBlocks.
        blocks do: [:block |
            | failures |
            failures := DiagramFixtures classFailuresIn: block.
            self assert: (failures select: [:each |
                #(#classOutsidePosition #unsupportedSyntax)
                    includes: (each at: #category)]) isEmpty
                description: 'a class name hides outside a declared class position: ',
                    failures printString]
    ]

    testS15_AKernelClassDoesNotSatisfyTheLocalOracle [
        "Declared RED pass. Array resolves hierarchically but must
         fail the same checker whose Resolver control succeeds."
        | control mutant failures |
        control := DiagramFixtures validBlock.
        self assert: (DiagramFixtures classFailuresIn: control) isEmpty.
        self assert: ((Smalltalk at: #Parley) includesKey: #Array).
        self deny: (DiagramFixtures localClassNames includes: 'Array').
        mutant := DiagramFixtures replacingFirstClassIn: control with: 'Array'.
        self deny: (mutant at: #text) = (control at: #text).
        failures := DiagramFixtures classFailuresIn: mutant.
        self assert: (DiagramFixtures hasFailure: #nonLocalClass
            token: 'Array' in: failures)
            description: 'hierarchical lookup accepted Array as a local class'.
        self assert: failures size = 1
            description: 'the Array fixture failed for an unrelated reason'
    ]

    testS16_UnknownAndHiddenClassesHaveSpecificDiagnoses [
        "Declared RED pass. Both falsifier directions retain valid
         diagram syntax and fail for the named token, not extraction."
        | control unknown prose failures |
        control := DiagramFixtures validBlock.
        self assert: (DiagramFixtures classFailuresIn: control) isEmpty.
        unknown := DiagramFixtures replacingFirstClassIn: control
            with: 'NoSuchClass'.
        self deny: (unknown at: #text) = (control at: #text).
        failures := DiagramFixtures classFailuresIn: unknown.
        self assert: (DiagramFixtures hasFailure: #unknownClass
            token: 'NoSuchClass' in: failures).
        self assert: failures size = 1.
        prose := DiagramFixtures placingClassInProseIn: control.
        self deny: (prose at: #text) = (control at: #text).
        failures := DiagramFixtures classFailuresIn: prose.
        self assert: (DiagramFixtures hasFailure: #classOutsidePosition
            token: 'Resolver' in: failures).
        self assert: failures size = 1
            description: 'the prose fixture failed for an unrelated reason'
    ]

    testS17_TheDocumentationWalkSeesNestedUntouchedDirectories [
        "Declared RED pass. The isolated tree has one diagram, so
         the real four-file census is intentionally not applied here."
        | root nested relative sources blocks control mutant failures |
        root := self freshDir: 's23-17-recursive'.
        Directory create: root, '/docs'.
        Directory create: root, '/docs/nested'.
        Directory create: root, '/docs/nested/deeper'.
        nested := root, '/docs/nested/deeper'.
        relative := 'docs/nested/deeper/diagram.md'.
        SourceFixtures write: 'The fixture root.' toFile: 'README.md' in: root.
        control := DiagramFixtures validBlock.
        SourceFixtures write: (self fencedSourceFor: control)
            toFile: 'diagram.md' in: nested.
        sources := DocumentationFixtures documentationSourcesUnder: root.
        self deny: sources isEmpty.
        self assert: (sources includesKey: 'README.md').
        self assert: (sources includesKey: relative)
            description: 'the recursive walk skipped the nested directory'.
        blocks := DiagramFixtures blocksInSources: sources.
        self assert: blocks size = 1.
        self assert: (blocks first at: #path) = relative.
        self assert: (DiagramFixtures classFailuresIn: blocks first) isEmpty.
        mutant := DiagramFixtures replacingFirstClassIn: control
            with: 'NoSuchClass'.
        self deny: (mutant at: #text) = (control at: #text).
        SourceFixtures write: (self fencedSourceFor: mutant)
            toFile: 'diagram.md' in: nested.
        sources := DocumentationFixtures documentationSourcesUnder: root.
        blocks := DiagramFixtures blocksInSources: sources.
        self assert: blocks size = 1.
        failures := DiagramFixtures classFailuresIn: blocks first.
        self assert: (DiagramFixtures hasFailure: #unknownClass
            token: 'NoSuchClass' in: failures).
        self assert: failures size = 1.
        self assert: (failures first at: #path) = relative
            description: 'the nested token diagnosis lost its source path'.
        self assert: (failures first at: #line) > 0
    ]
]

Namespace current: Smalltalk.
