"Sprint 23: guide declarations, with bounded fence/parser controls.
 These textual laws prove file/link sets and literal instruction seats,
 never prose truth or successful rendered walkthroughs."

Namespace current: Parley.

TestCase subclass: DocumentationSetTest [

    newline [ ^String with: Character nl ]

    guideIndex [
        ^DocumentationFixtures sourceAt: 'docs/guide/README.md'
    ]

    validGuideIndex [
        ^'| Page | Purpose |', self newline,
            '| --- | --- |', self newline,
            '| [Guide](README.md) | Start here |', self newline,
            '| [Run code](running-code.md) | Run a script |', self newline
    ]

    assertFailure: category token: token in: failures [
        self assert: (DocumentationFixtures hasFailure: category token: token in: failures)
            description: 'missing ', category printString, ' for ', token printString,
                ': ', failures printString.
        failures do: [:failure |
            self deny: (failure at: #path) isEmpty.
            self assert: (failure at: #line) > 0]
    ]

    assertFenceControls [
        | text result blocks wrapped |
        text := '   ~~~~mermaid', self newline,
            'flowchart LR', self newline, 'n["Resolver"]', self newline,
            '   ~~~~~', self newline.
        result := DocumentationFixtures fencedBlocksIn: text path: 'fences.md'.
        self assert: (result at: #failures) isEmpty.
        blocks := result at: #blocks.
        self assert: blocks size = 1.
        self assert: (blocks first at: #tag) = 'mermaid'.
        self assert: (blocks first at: #line) = 1.
        self assert: (blocks first at: #offset) = 16.
        self assert: (blocks first at: #text) =
            ('flowchart LR', self newline, 'n["Resolver"]', self newline).
        #('> ```mermaid' '- ```mermaid' '1. ```mermaid'
            '> - 1) ```mermaid' '    ```mermaid') do: [:line |
            result := DocumentationFixtures fencedBlocksIn:
                'A heading', self newline, line, self newline path: 'nested.md'.
            self assertFailure: #unsupportedContainer token: 'mermaid'
                in: (result at: #failures).
            self assert: ((result at: #failures) first at: #line) = 2.
            self assert: ((result at: #failures) first at: #path) = 'nested.md'].
        result := DocumentationFixtures fencedBlocksIn:
            (String with: Character tab), '```mermaid', self newline path: 'tabs.md'.
        self assertFailure: #unsupportedContainer token: 'mermaid'
            in: (result at: #failures).
        wrapped := '````text', self newline, '> ```mermaid', self newline,
            '```mermaid', self newline, '```', self newline, '````', self newline.
        result := DocumentationFixtures fencedBlocksIn: wrapped path: 'example.md'.
        self assert: (result at: #failures) isEmpty.
        self assert: (result at: #blocks) size = 1.
        self assert: ((result at: #blocks) first at: #tag) = 'text'.
        result := DocumentationFixtures fencedBlocksIn:
            '```mermaid', self newline, 'flowchart LR', self newline path: 'open.md'.
        self assertFailure: #unterminatedFence token: 'mermaid'
            in: (result at: #failures).
        result := DocumentationFixtures fencedBlocksIn:
            '```mermaid extra', self newline, '```', self newline path: 'info.md'.
        self assertFailure: #unsupportedFenceInfo token: 'mermaid extra'
            in: (result at: #failures)
    ]

    assertInstructionControls [
        | exec publish |
        exec := 'This matters to CI.', self newline, '```smalltalk', self newline,
            'ObjectMemory quit: 1.', self newline, '```', self newline.
        self assert: (DocumentationFixtures execGuideFailuresIn: exec) isEmpty.
        self assertFailure: #missingCode token: 'ObjectMemory quit: 1'
            in: (DocumentationFixtures execGuideFailuresIn:
                'This matters to CI. ObjectMemory quit: 1').
        self assertFailure: #missingProse token: 'matters to CI'
            in: (DocumentationFixtures execGuideFailuresIn:
                (exec copyReplaceAll: 'matters to CI' with: 'is documented')).
        publish := '```sh', self newline,
            'parley publish ../my-index --layout flat', self newline,
            'parley publish ../my-index --layout sparse', self newline,
            '```', self newline.
        self assert: (DocumentationFixtures publishingGuideFailuresIn: publish) isEmpty.
        self assertFailure: #missingCode token: 'parley publish ../my-index --layout flat'
            in: (DocumentationFixtures publishingGuideFailuresIn:
                (publish copyReplaceAll: '--layout' with: '')).
        self assertFailure: #missingCode token: 'parley publish ../my-index --layout sparse'
            in: (DocumentationFixtures publishingGuideFailuresIn:
                'The index has a flat, or the per-package sparse layout. --layout')
    ]

    assertGuideControls [
        | control names duplicate malformed |
        control := self validGuideIndex.
        names := #('README.md' 'running-code.md').
        self assert: (DocumentationFixtures guideLinksIn: control) = names.
        self assert: (DocumentationFixtures guideFailuresIn: control pageNames: names) isEmpty.
        self assertFailure: #missingGuidePage token: 'running-code.md'
            in: (DocumentationFixtures guideFailuresIn: control pageNames: #('README.md')).
        self assertFailure: #undeclaredGuidePage token: 'extra.md'
            in: (DocumentationFixtures guideFailuresIn: control pageNames: names, #('extra.md')).
        duplicate := control, '| [Again](README.md) | Duplicate |', self newline.
        self assertFailure: #duplicateGuideLink token: 'README.md'
            in: (DocumentationFixtures guideFailuresIn: duplicate pageNames: names).
        malformed := '| [Guide](README.md) || Start here |'.
        self assertFailure: #malformedGuideLink token: malformed
            in: (DocumentationFixtures guideFailuresIn:
                (control copyReplaceAll: '| [Guide](README.md) | Start here |' with: malformed)
                pageNames: names).
        self assertFailure: #missingGuideIndex token: 'README.md'
            in: (DocumentationFixtures guideFailuresIn: '' pageNames: names).
        self assertFailure: #emptyGuidePages token: 'docs/guide'
            in: (DocumentationFixtures guideFailuresIn: control pageNames: #())
    ]

    testTheGuideIndexEqualsTheDiscoveredPageSet [
        "The literal declaration equals files on disk; neither link
         labels nor prose accuracy are inferred from that equality."
        | source names removed |
        self assertFenceControls.
        self assertInstructionControls.
        self assertGuideControls.
        source := self guideIndex.
        self deny: source isEmpty description: 'the guide index is absent'.
        names := DocumentationFixtures guidePageNamesUnder: 'docs/guide'.
        self deny: names isEmpty description: 'no guide pages were discovered'.
        self assert: (DocumentationFixtures guideFailuresIn: source pageNames: names) isEmpty.
        self assert: (DocumentationFixtures guideLinksIn: source) asSet = names asSet.
        removed := names reject: [:name | name = names first].
        self assert: removed size = (names size - 1).
        self assertFailure: #missingGuidePage token: names first
            in: (DocumentationFixtures guideFailuresIn: source pageNames: removed)
    ]

    testTheGuideIndexRejectsDuplicateAndMalformedDeclarations [
        "Set equality alone permits duplicate declarations; this
         check also requires the bounded link grammar."
        | source names duplicate malformed original |
        self assertGuideControls.
        source := self guideIndex.
        self deny: source isEmpty description: 'the guide index is absent'.
        names := DocumentationFixtures guidePageNamesUnder: 'docs/guide'.
        self deny: names isEmpty.
        self assert: (DocumentationFixtures guideFailuresIn: source pageNames: names) isEmpty.
        original := ((DocumentationFixtures guideTableIn: source) at: #rows) at: 2.
        duplicate := source copyReplaceAll: original last
            with: original last, self newline, original last.
        self deny: duplicate = source.
        self assertFailure: #duplicateGuideLink
            token: (DocumentationFixtures guideLinkInRow: original last)
            in: (DocumentationFixtures guideFailuresIn: duplicate pageNames: names).
        malformed := source copyReplaceAll: '](README.md)' with: '](../README.md)'.
        self deny: malformed = source.
        self assert: ((DocumentationFixtures guideFailuresIn: malformed pageNames: names)
            anySatisfy: [:failure | (failure at: #category) = #malformedGuideLink])
    ]

    testTheGuideIndexBelongsToTheReleaseDeclaration [
        "An existing nonempty file must be declared; an invented name
         still fails the settled release-file walk in isolation."
        | declared missing grown |
        declared := Parley releaseFiles.
        self deny: declared isEmpty.
        self assert: (declared includes: 'docs/guide/README.md')
            description: 'releaseFiles does not yet declare the guide index'.
        self assert: (ReleaseFixtures missingReleaseFilesIn: declared) isEmpty.
        missing := 'docs/guide/absent-sprint23-proof.md'.
        self deny: (File name: missing) exists.
        grown := declared, (Array with: missing).
        self assert: (ReleaseFixtures missingReleaseFilesIn: grown) asArray = (Array with: missing)
    ]
]

Namespace current: Smalltalk.
