"Parley Sprint 23 — bounded diagram extraction and falsifier fixtures.
 Decision 88 and the approved issue #25 pre-RED protocol. These helpers
 parse declarations, never evaluate document text. The names are checked;
 arrows, behavior, rendering and visual quality remain reader judgments."

Namespace current: Parley.

Object subclass: DiagramFixtures [

    DiagramFixtures class >> expectedPaths [
        ^#('docs/design/architecture.md' 'docs/design/rationale.md'
            'docs/design/resolver.md' 'docs/design/execution-and-cli.md')
    ]

    DiagramFixtures class >> blockWithText: aText path: aPath [
        ^Dictionary new
            at: #tag put: 'mermaid';
            at: #text put: aText;
            at: #path put: aPath;
            at: #line put: 1;
            at: #offset put: 1;
            yourself
    ]

    DiagramFixtures class >> validBlock [
        ^self blockWithText: 'flowchart TD', SourceFixtures newline,
            'n["Resolver"]', SourceFixtures newline path: 'fixture.md'
    ]

    DiagramFixtures class >> failure: aCategory token: aToken
            block: aBlock line: aLine [
        ^Dictionary new
            at: #category put: aCategory;
            at: #token put: aToken;
            at: #path put: (aBlock at: #path);
            at: #line put: aLine;
            yourself
    ]

    DiagramFixtures class >> hasFailure: aCategory token: aToken in: failures [
        ^failures anySatisfy: [:each |
            (each at: #category) = aCategory
                and: [(each at: #token) = aToken]]
    ]

    DiagramFixtures class >> isBlank: aCharacter [
        ^aCharacter = Character space or: [aCharacter = Character tab]
    ]

    DiagramFixtures class >> trim: aText [
        | first last |
        first := 1.
        last := aText size.
        [first <= last and: [self isBlank: (aText at: first)]]
            whileTrue: [first := first + 1].
        [last >= first and: [self isBlank: (aText at: last)]]
            whileTrue: [last := last - 1].
        ^aText copyFrom: first to: last
    ]

    DiagramFixtures class >> identifierStart: aCharacter [
        ^((aCharacter >= $A and: [aCharacter <= $Z])
            or: [aCharacter >= $a and: [aCharacter <= $z]])
            or: [aCharacter = $_]
    ]

    DiagramFixtures class >> identifierPart: aCharacter [
        ^(self identifierStart: aCharacter)
            or: [aCharacter >= $0 and: [aCharacter <= $9]]
    ]

    DiagramFixtures class >> isIdentifier: aText [
        aText isEmpty ifTrue: [^false].
        (self identifierStart: aText first) ifFalse: [^false].
        ^aText allSatisfy: [:each | self identifierPart: each]
    ]

    DiagramFixtures class >> separatorSizeAt: anIndex in: aText [
        "Use string separators so the middle dot keeps its file encoding."
        #('+' ',' '·') do: [:separator |
            (anIndex + separator size - 1 <= aText size and: [
                (aText copyFrom: anIndex
                    to: anIndex + separator size - 1) = separator])
                        ifTrue: [^separator size]].
        ^0
    ]

    DiagramFixtures class >> identifierListIn: aText [
        "An entire segment is an identifier list, or it is prose.
         Unknown names are still class position; lookup never sets grammar."
        | text at start names separatorSize |
        text := self trim: aText.
        text isEmpty ifTrue: [^nil].
        names := OrderedCollection new.
        at := 1.
        [at <= text size] whileTrue: [
            (self identifierStart: (text at: at)) ifFalse: [^nil].
            start := at.
            [at <= text size and: [self identifierPart: (text at: at)]]
                whileTrue: [at := at + 1].
            names add: (text copyFrom: start to: at - 1).
            [at <= text size and: [self isBlank: (text at: at)]]
                whileTrue: [at := at + 1].
            at > text size ifTrue: [^names asArray].
            separatorSize := self separatorSizeAt: at in: text.
            separatorSize = 0 ifTrue: [^nil].
            at := at + separatorSize.
            [at <= text size and: [self isBlank: (text at: at)]]
                whileTrue: [at := at + 1].
            at > text size ifTrue: [^nil]].
        ^nil
    ]

    DiagramFixtures class >> localClassNames [
        "Namespace keys may be inherited. Keep only hereAt: behaviors."
        | namespace names |
        namespace := Smalltalk at: #Parley.
        names := Set new.
        namespace keysDo: [:key |
            | local |
            local := namespace hereAt: key ifAbsent: [nil].
            (local notNil and: [local isBehavior])
                ifTrue: [names add: key asString]].
        ^names
    ]

    DiagramFixtures class >> isEdge: aLine [
        | arrow at left right close |
        arrow := '-->'.
        at := aLine indexOfSubCollection: arrow.
        at = 0 ifTrue: [
            arrow := '-.->'.
            at := aLine indexOfSubCollection: arrow].
        at = 0 ifTrue: [^false].
        left := self trim: (aLine copyFrom: 1 to: at - 1).
        (self isIdentifier: left) ifFalse: [^false].
        right := self trim:
            (aLine copyFrom: at + arrow size to: aLine size).
        right isEmpty ifTrue: [^false].
        right first = $| ifTrue: [
            close := right indexOf: $| startingAt: 2.
            close = 0 ifTrue: [^false].
            right := self trim:
                (right copyFrom: close + 1 to: right size)].
        ^self isIdentifier: right
    ]

    DiagramFixtures class >> segmentsFor: aLabel startingAt: anOffset line: lineNumber [
        | segments at stop next segment |
        segments := OrderedCollection new.
        at := 1.
        [
            next := aLabel indexOfSubCollection: '<br/>' startingAt: at.
            stop := next = 0 ifTrue: [aLabel size] ifFalse: [next - 1].
            segment := aLabel copyFrom: at to: stop.
            segments add: (Dictionary new
                at: #text put: segment;
                at: #start put: anOffset + at - 1;
                at: #stop put: anOffset + stop - 1;
                at: #line put: lineNumber;
                at: #identifiers put: (self identifierListIn: segment);
                yourself).
            next = 0
        ] whileFalse: [at := next + 5].
        ^segments asArray
    ]

    DiagramFixtures class >> nodeSegmentsIn: aBlock [
        "Body-relative spans are retained for the outside-position scan.
         A supported header, node or edge consumes its whole source line."
        | segments failures offset lineNumber sawHeader text |
        segments := OrderedCollection new.
        failures := OrderedCollection new.
        offset := 1.
        lineNumber := (aBlock at: #line) + 1.
        sawHeader := false.
        text := aBlock at: #text.
        (ExecFixtures linesOf: text) do: [:line |
            | trimmed leading recognized bracket identifier label |
            trimmed := self trim: line.
            leading := 0.
            [leading < line size and: [
                self isBlank: (line at: leading + 1)]]
                    whileTrue: [leading := leading + 1].
            recognized := trimmed isEmpty or: [trimmed startsWith: '%%'].
            recognized ifFalse: [
                sawHeader ifFalse: [
                    (#('flowchart TD' 'flowchart TB' 'flowchart BT'
                        'flowchart LR' 'flowchart RL') includes: trimmed)
                            ifTrue: [sawHeader := true. recognized := true]]
                ifTrue: [
                    bracket := trimmed indexOfSubCollection: '["'.
                    (bracket > 1 and: [trimmed endsWith: '"]'])
                        ifTrue: [
                            identifier := trimmed copyFrom: 1 to: bracket - 1.
                            label := trimmed copyFrom: bracket + 2
                                to: trimmed size - 2.
                            ((self isIdentifier: identifier)
                                and: [(label includes: $") not]) ifTrue: [
                                    segments addAll: (self segmentsFor: label
                                        startingAt: offset + leading + bracket + 1
                                        line: lineNumber).
                                    recognized := true]].
                    recognized ifFalse: [
                        recognized := self isEdge: trimmed]]].
            recognized ifFalse: [
                failures add: (self failure: #unsupportedSyntax token: trimmed
                    block: aBlock line: lineNumber)].
            offset := offset + line size + 1.
            lineNumber := lineNumber + 1].
        sawHeader ifFalse: [
            failures add: (self failure: #unsupportedSyntax token: 'flowchart'
                block: aBlock line: (aBlock at: #line) + 1)].
        ^Dictionary new
            at: #segments put: segments asArray;
            at: #failures put: failures asArray;
            yourself
    ]

    DiagramFixtures class >> classFailuresIn: aBlock [
        | parsed segments failures localNames namespace text at lineNumber start token inside category value |
        parsed := self nodeSegmentsIn: aBlock.
        segments := parsed at: #segments.
        failures := (parsed at: #failures) asOrderedCollection.
        localNames := self localClassNames.
        namespace := Smalltalk at: #Parley.
        segments do: [:segment |
            | names |
            names := segment at: #identifiers.
            names notNil ifTrue: [names do: [:name |
                value := namespace hereAt: name asSymbol ifAbsent: [nil].
                (value notNil and: [value isBehavior]) ifFalse: [
                    value := namespace at: name asSymbol ifAbsent: [nil].
                    category := (value notNil and: [value isBehavior])
                        ifTrue: [#nonLocalClass] ifFalse: [#unknownClass].
                    failures add: (self failure: category token: name
                        block: aBlock line: (segment at: #line))]]]].
        text := aBlock at: #text.
        at := 1.
        lineNumber := (aBlock at: #line) + 1.
        [at <= text size] whileTrue: [
            (self identifierStart: (text at: at)) ifTrue: [
                start := at.
                [at <= text size and: [self identifierPart: (text at: at)]]
                    whileTrue: [at := at + 1].
                token := text copyFrom: start to: at - 1.
                inside := segments anySatisfy: [:segment |
                    (segment at: #identifiers) notNil
                        and: [start >= (segment at: #start)
                            and: [at - 1 <= (segment at: #stop)]]].
                ((localNames includes: token) and: [inside not]) ifTrue: [
                    failures add: (self failure: #classOutsidePosition token: token
                        block: aBlock line: lineNumber)]]
            ifFalse: [
                (text at: at) = Character nl
                    ifTrue: [lineNumber := lineNumber + 1].
                at := at + 1]].
        ^failures asArray
    ]

    DiagramFixtures class >> blocksInSources: sources [
        | blocks |
        blocks := OrderedCollection new.
        sources keys asSortedCollection do: [:path |
            | extraction |
            extraction := DocumentationFixtures
                fencedBlocksIn: (sources at: path) path: path.
            blocks addAll: ((extraction at: #blocks) select: [:block |
                (block at: #tag) = 'mermaid'])].
        ^blocks asArray
    ]

    DiagramFixtures class >> censusFailuresIn: sources [
        | failures blocks stub |
        failures := OrderedCollection new.
        sources keys asSortedCollection do: [:path |
            failures addAll: ((DocumentationFixtures
                fencedBlocksIn: (sources at: path) path: path) at: #failures)].
        blocks := self blocksInSources: sources.
        stub := self blockWithText: '' path: '<documentation>'.
        blocks size = 4 ifFalse: [
            failures add: (self failure: #diagramCensus
                token: blocks size printString block: stub line: 1)].
        self expectedPaths do: [:path |
            (blocks select: [:block | (block at: #path) = path]) size = 1 ifFalse: [
                failures add: (self failure: #diagramPath token: path
                    block: (self blockWithText: '' path: path) line: 1)]].
        blocks do: [:block |
            (self expectedPaths includes: (block at: #path)) ifFalse: [
                failures add: (self failure: #diagramPath token: (block at: #path)
                    block: block line: (block at: #line))]].
        ^failures asArray
    ]

    DiagramFixtures class >> replacingFirstClassIn: aBlock with: aName [
        | result text first names at old |
        result := aBlock copy.
        text := aBlock at: #text.
        first := ((self nodeSegmentsIn: aBlock) at: #segments)
            detect: [:each | (each at: #identifiers) notNil]
            ifNone: [^result].
        names := first at: #identifiers.
        old := names first.
        at := text indexOfSubCollection: old startingAt: (first at: #start).
        result at: #text put: (text copyFrom: 1 to: at - 1),
            aName, (text copyFrom: at + old size to: text size).
        ^result
    ]

    DiagramFixtures class >> placingClassInProseIn: aBlock [
        | result text segments at |
        result := aBlock copy.
        text := aBlock at: #text.
        segments := (self nodeSegmentsIn: aBlock) at: #segments.
        segments isEmpty ifTrue: [^result].
        at := (segments first at: #stop) + 1.
        result at: #text put: (text copyFrom: 1 to: at - 1),
            '<br/>Resolver handles packages',
            (text copyFrom: at to: text size).
        ^result
    ]
]

Namespace current: Smalltalk.
