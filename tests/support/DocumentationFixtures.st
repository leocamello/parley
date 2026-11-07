"Sprint 23 test-only Markdown extraction. This bounded scanner proves
 declarations and literal instructions, never their meaning or rendering."

Namespace current: Parley.

Object subclass: DocumentationFixtures [
    <comment: 'Stateless fixtures for documentation discovery, fenced code,
positioned diagnostics and the guide declaration. No evaluation or compilation.'>

    DocumentationFixtures class >> sourceAt: aPath [
        <category: 'sources'>
        | file |
        file := File name: aPath.
        file exists ifFalse: [^''].
        ^file contents
    ]

    DocumentationFixtures class >> markdownFilesUnder: aDirectory [
        <category: 'sources'>
        | out |
        out := OrderedCollection new.
        self collectMarkdownUnder: aDirectory prefix: '' into: out.
        ^out asSortedCollection asArray
    ]

    DocumentationFixtures class >> collectMarkdownUnder: aDirectory prefix: aPrefix into: out [
        <category: 'sources'>
        | dir |
        dir := File name: aDirectory.
        dir exists ifFalse: [^self].
        dir namesDo: [:name |
            (#('.' '..') includes: name) ifFalse: [
                | path relative |
                path := aDirectory, '/', name.
                relative := aPrefix, name.
                (File name: path) isDirectory
                    ifTrue: [self collectMarkdownUnder: path
                        prefix: relative, '/' into: out]
                    ifFalse: [(name endsWith: '.md')
                        ifTrue: [out add: relative]]]]
    ]

    DocumentationFixtures class >> documentationSourcesUnder: aRoot [
        <category: 'sources'>
        | sources |
        sources := Dictionary new.
        sources at: 'README.md' put: (self sourceAt: aRoot, '/README.md').
        (self markdownFilesUnder: aRoot, '/docs') do: [:relative |
            sources at: 'docs/', relative
                put: (self sourceAt: aRoot, '/docs/', relative)].
        ^sources
    ]

    DocumentationFixtures class >> guidePageNamesUnder: aDirectory [
        <category: 'sources'>
        | names dir |
        names := OrderedCollection new.
        dir := File name: aDirectory.
        dir exists ifFalse: [^#()].
        dir namesDo: [:name |
            ((name endsWith: '.md') and: [
                (File name: aDirectory, '/', name) isDirectory not])
                    ifTrue: [names add: name]].
        ^names asSortedCollection asArray
    ]

    DocumentationFixtures class >> failure: aCategory token: aToken path: aPath line: aLine [
        <category: 'diagnostics'>
        ^Dictionary new
            at: #category put: aCategory;
            at: #token put: aToken;
            at: #path put: aPath;
            at: #line put: aLine;
            yourself
    ]

    DocumentationFixtures class >> hasFailure: aCategory token: aToken in: failures [
        <category: 'diagnostics'>
        ^failures anySatisfy: [:each |
            (each at: #category) = aCategory and: [(each at: #token) = aToken]]
    ]

    DocumentationFixtures class >> spaceOrTab: aCharacter [
        <category: 'scanner'>
        ^aCharacter = Character space or: [aCharacter = Character tab]
    ]

    DocumentationFixtures class >> withoutLeadingWhitespace: aString [
        <category: 'scanner'>
        | index |
        index := 1.
        [index <= aString size and: [self spaceOrTab: (aString at: index)]]
            whileTrue: [index := index + 1].
        ^aString copyFrom: index to: aString size
    ]

    DocumentationFixtures class >> supportedIndentIn: aLine [
        <category: 'scanner'>
        | count |
        count := 0.
        [count < aLine size and: [(aLine at: count + 1) = Character space]]
            whileTrue: [count := count + 1].
        ^count <= 3 and: [count = aLine size or: [
            (aLine at: count + 1) ~= Character tab]]
    ]

    DocumentationFixtures class >> fenceOpeningIn: aContent [
        "Character, delimiter length, tag and complete info string.
         An empty array means the line is not a fence opener."
        <category: 'scanner'>
        | ch count info words |
        aContent size < 3 ifTrue: [^#()].
        ch := aContent first.
        (ch = $` or: [ch = $~]) ifFalse: [^#()].
        count := 1.
        [count < aContent size and: [(aContent at: count + 1) = ch]]
            whileTrue: [count := count + 1].
        count < 3 ifTrue: [^#()].
        info := (aContent copyFrom: count + 1 to: aContent size) trimSeparators.
        words := info subStrings.
        ^Array with: ch with: count
            with: (words isEmpty ifTrue: [''] ifFalse: [words first])
            with: info
    ]

    DocumentationFixtures class >> isClosingFence: aLine for: opening [
        <category: 'scanner'>
        | content count |
        (self supportedIndentIn: aLine) ifFalse: [^false].
        content := self withoutLeadingWhitespace: aLine.
        count := 0.
        [count < content size and: [(content at: count + 1) = opening first]]
            whileTrue: [count := count + 1].
        ^count >= (opening at: 2) and: [
            (content copyFrom: count + 1 to: content size) trimSeparators isEmpty]
    ]

    DocumentationFixtures class >> withoutContainerPrefixes: aLine [
        "Only detect unsupported candidate placement; do not pretend to
         parse blockquote/list content as ordinary Markdown."
        <category: 'scanner'>
        | rest changed i |
        rest := self withoutLeadingWhitespace: aLine.
        changed := true.
        [changed and: [rest isEmpty not]] whileTrue: [
            changed := false.
            rest first = $> ifTrue: [
                rest := self withoutLeadingWhitespace:
                    (rest copyFrom: 2 to: rest size).
                changed := true].
            (changed not and: [rest size >= 2]) ifTrue: [
                (('-+*' includes: rest first) and: [self spaceOrTab: (rest at: 2)])
                    ifTrue: [rest := self withoutLeadingWhitespace:
                        (rest copyFrom: 3 to: rest size). changed := true]].
            (changed not and: [rest isEmpty not]) ifTrue: [
                i := 1.
                [i <= rest size and: [('0123456789' includes: (rest at: i))]]
                    whileTrue: [i := i + 1].
                (i > 1 and: [i < rest size and: [
                    ('.)' includes: (rest at: i)) and: [self spaceOrTab: (rest at: i + 1)]]])
                        ifTrue: [rest := self withoutLeadingWhitespace:
                            (rest copyFrom: i + 2 to: rest size). changed := true]]].
        ^rest
    ]

    DocumentationFixtures class >> fencedBlocksIn: aSource path: aPath [
        "Every fence is tracked, so a nested example inside a longer
         ordinary fence is not mistaken for a diagram. Positions are
         one-based source offsets and opening line numbers."
        <category: 'fences'>
        | blocks failures opening block body lineNumber offset content candidate |
        blocks := OrderedCollection new.
        failures := OrderedCollection new.
        opening := nil.
        lineNumber := 0.
        offset := 1.
        (ExecFixtures linesOf: aSource) do: [:line |
            lineNumber := lineNumber + 1.
            opening isNil
                ifTrue: [
                    content := self withoutLeadingWhitespace: line.
                    candidate := self fenceOpeningIn:
                        (self withoutContainerPrefixes: line).
                    (candidate isEmpty not and: [
                        (candidate at: 3) = 'mermaid' and: [
                            (self supportedIndentIn: line) not or: [
                                content ~= (self withoutContainerPrefixes: line)]]])
                        ifTrue: [failures add: (self failure: #unsupportedContainer
                            token: 'mermaid' path: aPath line: lineNumber)]
                        ifFalse: [
                            (self supportedIndentIn: line) ifTrue: [
                                candidate := self fenceOpeningIn: content.
                                candidate isEmpty ifFalse: [
                                    opening := candidate.
                                    block := Dictionary new
                                        at: #tag put: (opening at: 3);
                                        at: #path put: aPath;
                                        at: #line put: lineNumber;
                                        at: #offset put: offset + line size + 1;
                                        yourself.
                                    body := WriteStream on: String new.
                                    ((opening at: 3) = 'mermaid' and: [
                                        (opening at: 4) ~= 'mermaid']) ifTrue: [
                                        failures add: (self failure: #unsupportedFenceInfo
                                            token: (opening at: 4) path: aPath line: lineNumber)]]]]]
                ifFalse: [
                    (self isClosingFence: line for: opening)
                        ifTrue: [block at: #text put: body contents.
                            blocks add: block. opening := nil]
                        ifFalse: [body nextPutAll: line; nextPut: Character nl]].
            offset := offset + line size + 1].
        opening notNil ifTrue: [
            block at: #text put: body contents.
            blocks add: block.
            (opening at: 3) = 'mermaid' ifTrue: [
                failures add: (self failure: #unterminatedFence
                    token: 'mermaid' path: aPath line: (block at: #line))]].
        ^Dictionary new at: #blocks put: blocks asArray;
            at: #failures put: failures asArray; yourself
    ]

    DocumentationFixtures class >> codeTextTagged: aTag in: aSource [
        <category: 'fences'>
        | out |
        out := WriteStream on: String new.
        ((self fencedBlocksIn: aSource path: '(guide)') at: #blocks) do: [:block |
            (block at: #tag) = aTag ifTrue: [out nextPutAll: (block at: #text)]].
        ^out contents
    ]

    DocumentationFixtures class >> guideTableIn: aSource [
        <category: 'guide index'>
        | rows found finished lineNumber failures |
        rows := OrderedCollection new.
        failures := OrderedCollection new.
        found := false. finished := false. lineNumber := 0.
        (ExecFixtures linesOf: aSource) do: [:line |
            lineNumber := lineNumber + 1.
            line = '| Page | Purpose |'
                ifTrue: [found ifTrue: [failures add: (self failure: #malformedGuideLink
                    token: line path: 'docs/guide/README.md' line: lineNumber)]. found := true]
                ifFalse: [(found and: [finished not]) ifTrue: [
                    (line startsWith: '|')
                        ifTrue: [rows add: (Array with: lineNumber with: line)]
                        ifFalse: [finished := true]]]].
        found ifFalse: [failures add: (self failure: #missingGuideIndex
            token: 'README.md' path: 'docs/guide/README.md' line: 1)].
        ^Dictionary new at: #rows put: rows asArray;
            at: #failures put: failures asArray; yourself
    ]

    DocumentationFixtures class >> guideLinkInRow: aLine [
        <category: 'guide index'>
        | cells link split destination |
        ((aLine startsWith: '|') and: [aLine endsWith: '|']) ifFalse: [^''].
        (aLine select: [:ch | ch = $|]) size = 3 ifFalse: [^''].
        cells := aLine subStrings: '|'.
        cells size = 2 ifFalse: [^''].
        link := cells first trimSeparators.
        (link startsWith: '[') ifFalse: [^''].
        split := link indexOfSubCollection: ']('.
        (split > 2 and: [link endsWith: ')']) ifFalse: [^''].
        destination := link copyFrom: split + 2 to: link size - 1.
        ((destination endsWith: '.md') and: [destination size > 3 and: [
            destination allSatisfy: [:ch |
                'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-' includes: ch]]])
                    ifFalse: [^''].
        cells last trimSeparators isEmpty ifTrue: [^''].
        ^destination
    ]

    DocumentationFixtures class >> guideSeparatorRow: aLine [
        <category: 'guide index'>
        | cells |
        ((aLine startsWith: '|') and: [aLine endsWith: '|']) ifFalse: [^false].
        (aLine select: [:ch | ch = $|]) size = 3 ifFalse: [^false].
        cells := aLine subStrings: '|'.
        ^cells size = 2 and: [cells allSatisfy: [:cell |
            | trimmed |
            trimmed := cell trimSeparators.
            trimmed size >= 3 and: [trimmed allSatisfy: [:ch | ch = $-]]]]
    ]

    DocumentationFixtures class >> guideLinksIn: aSource [
        <category: 'guide index'>
        | links |
        links := OrderedCollection new.
        ((self guideTableIn: aSource) at: #rows) do: [:row |
            | name |
            name := self guideLinkInRow: row last.
            name isEmpty ifFalse: [links add: name]].
        ^links asArray
    ]

    DocumentationFixtures class >> guideFailuresIn: aSource pageNames: names [
        <category: 'guide index'>
        | table failures links seen rows |
        table := self guideTableIn: aSource.
        failures := (table at: #failures) asOrderedCollection.
        rows := table at: #rows.
        (rows isEmpty or: [(self guideSeparatorRow: rows first last) not])
            ifTrue: [failures add: (self failure: #malformedGuideLink
                token: 'table separator' path: 'docs/guide/README.md' line: 1)].
        seen := Set new.
        rows doWithIndex: [:row :index |
            | name |
            (index = 1 and: [self guideSeparatorRow: row last]) ifFalse: [
                name := self guideLinkInRow: row last.
                name isEmpty
                    ifTrue: [failures add: (self failure: #malformedGuideLink
                        token: row last path: 'docs/guide/README.md' line: row first)]
                    ifFalse: [(seen includes: name) ifTrue: [
                        failures add: (self failure: #duplicateGuideLink
                            token: name path: 'docs/guide/README.md' line: row first)].
                        seen add: name]]].
        links := self guideLinksIn: aSource.
        links isEmpty ifTrue: [failures add: (self failure: #missingGuideIndex
            token: 'README.md' path: 'docs/guide/README.md' line: 1)].
        names isEmpty ifTrue: [failures add: (self failure: #emptyGuidePages
            token: 'docs/guide' path: 'docs/guide/README.md' line: 1)].
        (links asSet reject: [:name | names includes: name]) asSortedCollection do: [:name |
            failures add: (self failure: #missingGuidePage token: name
                path: 'docs/guide/README.md' line: 1)].
        (names asSet reject: [:name | links includes: name]) asSortedCollection do: [:name |
            failures add: (self failure: #undeclaredGuidePage token: name
                path: 'docs/guide/README.md' line: 1)].
        ^failures asArray
    ]

    DocumentationFixtures class >> execGuideFailuresIn: aSource [
        <category: 'guide instructions'>
        | failures code |
        failures := OrderedCollection new.
        aSource isEmpty ifTrue: [failures add: (self failure: #missingGuideSource
            token: 'docs/guide/running-code.md' path: 'docs/guide/running-code.md' line: 1)].
        (CommandLineFixtures does: aSource include: 'matters to CI') ifFalse: [
            failures add: (self failure: #missingProse token: 'matters to CI'
                path: 'docs/guide/running-code.md' line: 1)].
        code := self codeTextTagged: 'smalltalk' in: aSource.
        (CommandLineFixtures does: code include: 'ObjectMemory quit: 1') ifFalse: [
            failures add: (self failure: #missingCode token: 'ObjectMemory quit: 1'
                path: 'docs/guide/running-code.md' line: 1)].
        ^failures asArray
    ]

    DocumentationFixtures class >> publishingGuideFailuresIn: aSource [
        <category: 'guide instructions'>
        | failures code |
        failures := OrderedCollection new.
        aSource isEmpty ifTrue: [failures add: (self failure: #missingGuideSource
            token: 'docs/guide/publishing.md' path: 'docs/guide/publishing.md' line: 1)].
        code := self codeTextTagged: 'sh' in: aSource.
        #('parley publish ../my-index --layout flat'
          'parley publish ../my-index --layout sparse') do: [:command |
            (CommandLineFixtures does: code include: command) ifFalse: [
                failures add: (self failure: #missingCode token: command
                    path: 'docs/guide/publishing.md' line: 1)]].
        ^failures asArray
    ]
]

Namespace current: Smalltalk.
