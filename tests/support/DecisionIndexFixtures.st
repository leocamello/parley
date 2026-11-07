"Parley Sprint 23 — bounded decision/index extraction and falsifiers.
 Spec: architecture decision 90; issue #25 S9-S11 and the approved
 pre-RED extraction convention. These are textual checkers, not a
 Markdown renderer or a proof that an index summary states its ruling.
 No repository document is changed by a falsifier."

Namespace current: Parley.

Object subclass: DecisionIndexFixtures [

    <comment: 'Stateless test-only readers for the section-eight decision
log, its numbered index and explicit anchors. Positioned diagnostics
retain the offending number or row. The reusable comparer derives its
range from the input; the current 91-decision baseline belongs to tests.'>

    DecisionIndexFixtures class >> architecturePath [
        ^'docs/design/architecture.md'
    ]

    DecisionIndexFixtures class >> architectureSource [
        ^DocumentationFixtures sourceAt: self architecturePath
    ]

    DecisionIndexFixtures class >> sectionHeading [
        ^'## 8. Decision Log'
    ]

    DecisionIndexFixtures class >> indexHeading [
        ^'| Number | Ruling | Anchor |'
    ]

    DecisionIndexFixtures class >> linesIn: aString [
        "Keep offsets and physical line numbers even for empty lines."
        | out stream position lineNumber line |
        out := OrderedCollection new.
        stream := ReadStream on: aString.
        position := 1.
        lineNumber := 1.
        [stream atEnd] whileFalse: [
            line := stream upTo: Character nl.
            out add: (Dictionary new
                at: #text put: line;
                at: #line put: lineNumber;
                at: #offset put: position;
                at: #path put: self architecturePath;
                yourself).
            position := position + line size + 1.
            lineNumber := lineNumber + 1].
        ^out asArray
    ]

    DecisionIndexFixtures class >> sectionRecordsIn: aString [
        | out started finished |
        out := OrderedCollection new.
        started := false.
        finished := false.
        (self linesIn: aString) do: [:record |
            | line |
            line := record at: #text.
            finished ifFalse: [
                started
                    ifTrue: [
                        (line startsWith: '## ')
                            ifTrue: [finished := true]
                            ifFalse: [out add: record]]
                    ifFalse: [line = self sectionHeading
                        ifTrue: [started := true]]]].
        ^out asArray
    ]

    DecisionIndexFixtures class >> decisionSectionIn: aString [
        | out |
        out := WriteStream on: String new.
        (self sectionRecordsIn: aString) do: [:record |
            out nextPutAll: (record at: #text); nextPut: Character nl].
        ^out contents
    ]

    DecisionIndexFixtures class >> isDigit: aCharacter [
        ^aCharacter >= $0 and: [aCharacter <= $9]
    ]

    DecisionIndexFixtures class >> integerIn: aString [
        "Only an entire ASCII decimal spelling is accepted."
        | value |
        aString isEmpty ifTrue: [^nil].
        value := 0.
        aString do: [:character |
            (self isDigit: character) ifFalse: [^nil].
            value := value * 10 + character asInteger - $0 asInteger].
        ^value
    ]

    DecisionIndexFixtures class >> decisionNumberAtStartOf: aLine [
        | position |
        position := 1.
        [position <= aLine size and: [self isDigit: (aLine at: position)]]
            whileTrue: [position := position + 1].
        (position = 1 or: [position + 3 > aLine size]) ifTrue: [^nil].
        (aLine copyFrom: position to: position + 3) = '. **'
            ifFalse: [^nil].
        ^self integerIn: (aLine copyFrom: 1 to: position - 1)
    ]

    DecisionIndexFixtures class >> numberedRecordsIn: someRecords [
        | out |
        out := OrderedCollection new.
        someRecords do: [:record |
            | number numbered |
            number := self decisionNumberAtStartOf: (record at: #text).
            number isNil ifFalse: [
                numbered := record copy.
                numbered at: #number put: number.
                out add: numbered]].
        ^out asArray
    ]

    DecisionIndexFixtures class >> decisionNumbersIn: aString [
        ^(self numberedRecordsIn: (self sectionRecordsIn: aString))
            collect: [:record | record at: #number]
    ]

    DecisionIndexFixtures class >> wholeFileDecisionNumbersIn: aString [
        "The deliberately unbounded observation used by S10's control."
        ^(self numberedRecordsIn: (self linesIn: aString))
            collect: [:record | record at: #number]
    ]

    DecisionIndexFixtures class >> failure: aCategory token: aToken line: aLine [
        ^Dictionary new
            at: #category put: aCategory;
            at: #token put: aToken;
            at: #path put: self architecturePath;
            at: #line put: aLine;
            yourself
    ]

    DecisionIndexFixtures class >> hasFailure: aCategory token: aToken in: someFailures [
        ^someFailures anySatisfy: [:failure |
            (failure at: #category) = aCategory and: [
                (failure at: #token) = aToken]]
    ]

    DecisionIndexFixtures class >> tableCellsIn: aLine [
        | cells stream |
        (aLine size < 2 or: [aLine first ~= $| or: [aLine last ~= $|]])
            ifTrue: [^#()].
        cells := OrderedCollection new.
        stream := ReadStream on: (aLine copyFrom: 2 to: aLine size - 1).
        [stream atEnd] whileFalse: [
            cells add: (stream upTo: $|) trimSeparators].
        ^cells asArray
    ]

    DecisionIndexFixtures class >> isSeparatorRow: aLine [
        | cells |
        cells := self tableCellsIn: aLine.
        cells size = 3 ifFalse: [^false].
        ^cells allSatisfy: [:cell |
            | start finish |
            start := 1.
            finish := cell size.
            (cell isEmpty not and: [cell first = $:])
                ifTrue: [start := start + 1].
            (cell isEmpty not and: [cell last = $:])
                ifTrue: [finish := finish - 1].
            finish - start + 1 >= 3 and: [
                (cell copyFrom: start to: finish)
                    allSatisfy: [:character | character = $-]]]
    ]

    DecisionIndexFixtures class >> parsedIndexIn: aString [
        | records nonEmpty rows failures cursor record cells number row |
        records := self sectionRecordsIn: aString.
        nonEmpty := records select: [:each |
            (each at: #text) trimSeparators isEmpty not].
        rows := OrderedCollection new.
        failures := OrderedCollection new.
        (nonEmpty isEmpty or: [
            (nonEmpty first at: #text) ~= self indexHeading]) ifTrue: [
                failures add: (self failure: #missingIndex
                    token: self indexHeading
                    line: (nonEmpty isEmpty ifTrue: [1]
                        ifFalse: [nonEmpty first at: #line])).
                ^Dictionary new at: #rows put: rows asArray;
                    at: #failures put: failures asArray; yourself].
        cursor := (records indexOf: nonEmpty first) + 1.
        (cursor > records size or: [
            (self isSeparatorRow: ((records at: cursor) at: #text)) not])
            ifTrue: [failures add: (self failure: #malformedIndexHeader
                token: self indexHeading line: (nonEmpty first at: #line))]
            ifFalse: [cursor := cursor + 1].
        [cursor <= records size and: [
            ((records at: cursor) at: #text) startsWith: '|']]
            whileTrue: [
                record := records at: cursor.
                cells := self tableCellsIn: (record at: #text).
                number := cells size = 3
                    ifTrue: [self integerIn: cells first]
                    ifFalse: [nil].
                (number isNil or: [number < 1 or: [
                    (cells at: 2) isEmpty or: [(cells at: 3) isEmpty]]])
                    ifTrue: [failures add: (self failure: #malformedIndexRow
                        token: (record at: #text) line: (record at: #line))]
                    ifFalse: [
                        row := record copy.
                        row at: #number put: number;
                            at: #ruling put: (cells at: 2);
                            at: #anchor put: (cells at: 3).
                        rows add: row].
                cursor := cursor + 1].
        rows isEmpty ifTrue: [failures add: (self failure: #emptyIndex
            token: self indexHeading line: (nonEmpty first at: #line))].
        (nonEmpty select: [:each | (each at: #text) = self indexHeading]) size > 1
            ifTrue: [failures add: (self failure: #duplicateIndex
                token: self indexHeading line: (nonEmpty first at: #line))].
        ^Dictionary new at: #rows put: rows asArray;
            at: #failures put: failures asArray; yourself
    ]

    DecisionIndexFixtures class >> indexRowsIn: aString [
        ^(self parsedIndexIn: aString) at: #rows
    ]

    DecisionIndexFixtures class >> anchorLinkFor: aNumber [
        ^'[decision ', aNumber printString, '](#decision-',
            aNumber printString, ')'
    ]

    DecisionIndexFixtures class >> anchorLineFor: aNumber [
        ^'<a id="decision-', aNumber printString, '"></a>'
    ]

    DecisionIndexFixtures class >> indexFailuresIn: aString [
        | parsed failures lines decisions numbers rows rowNumbers maximum anchors |
        parsed := self parsedIndexIn: aString.
        failures := (parsed at: #failures) asOrderedCollection.
        lines := self linesIn: aString.
        decisions := self numberedRecordsIn: (self sectionRecordsIn: aString).
        numbers := decisions collect: [:record | record at: #number].
        rows := parsed at: #rows.
        rowNumbers := rows collect: [:record | record at: #number].
        numbers isEmpty ifTrue: [
            failures add: (self failure: #emptyDecisions token: self sectionHeading line: 1).
            ^failures asArray].
        (self hasFailure: #missingIndex token: self indexHeading in: failures)
            ifTrue: [^failures asArray].
        maximum := numbers inject: 0 into: [:largest :number | largest max: number].
        1 to: maximum do: [:number |
            (numbers includes: number) ifFalse: [
                failures add: (self failure: #missingDecision token: number line: 1)]].
        numbers asSet do: [:number |
            (numbers occurrencesOf: number) > 1 ifTrue: [
                failures add: (self failure: #duplicateDecision token: number
                    line: ((decisions detect: [:record |
                        (record at: #number) = number]) at: #line))].
            (rowNumbers includes: number) ifFalse: [
                failures add: (self failure: #missingIndexRow token: number
                    line: ((decisions detect: [:record |
                        (record at: #number) = number]) at: #line))]].
        rowNumbers asSet do: [:number |
            (rowNumbers occurrencesOf: number) > 1 ifTrue: [
                failures add: (self failure: #duplicateIndexRow token: number
                    line: ((rows detect: [:row | (row at: #number) = number]) at: #line))].
            (numbers includes: number) ifFalse: [
                failures add: (self failure: #unexpectedIndexRow token: number
                    line: ((rows detect: [:row | (row at: #number) = number]) at: #line))]].
        rowNumbers = rowNumbers asSortedCollection asArray ifFalse: [
            failures add: (self failure: #indexOrder token: rowNumbers
                line: (rows isEmpty ifTrue: [1] ifFalse: [rows first at: #line]))].
        rows do: [:row |
            (row at: #anchor) = (self anchorLinkFor: (row at: #number))
                ifFalse: [failures add: (self failure: #anchorMismatch
                    token: (row at: #number) line: (row at: #line))]].
        decisions do: [:record |
            | number expected |
            number := record at: #number.
            expected := self anchorLineFor: number.
            anchors := lines select: [:line | (line at: #text) = expected].
            anchors isEmpty ifTrue: [failures add: (self failure: #missingAnchor
                token: number line: (record at: #line))].
            anchors size > 1 ifTrue: [failures add: (self failure: #duplicateAnchor
                token: number line: (anchors first at: #line))].
            (anchors size = 1 and: [
                (anchors first at: #line) + 1 ~= (record at: #line)])
                ifTrue: [failures add: (self failure: #misplacedAnchor
                    token: number line: (anchors first at: #line))]].
        ^failures asArray
    ]

    DecisionIndexFixtures class >> removingIndexRow: aNumber from: aString [
        | rows target out |
        rows := (self indexRowsIn: aString) select: [:row |
            (row at: #number) = aNumber].
        rows isEmpty ifTrue: [^aString copy].
        target := rows first at: #line.
        out := WriteStream on: String new.
        (self linesIn: aString) do: [:record |
            (record at: #line) = target ifFalse: [
                out nextPutAll: (record at: #text); nextPut: Character nl]].
        ^out contents
    ]

    DecisionIndexFixtures class >> appendingUnindexedDecision: aNumber to: aString [
        | section target out |
        section := self sectionRecordsIn: aString.
        section isEmpty ifTrue: [^aString copy].
        target := section last at: #line.
        out := WriteStream on: String new.
        (self linesIn: aString) do: [:record |
            out nextPutAll: (record at: #text); nextPut: Character nl.
            (record at: #line) = target ifTrue: [
                out nextPutAll: (self anchorLineFor: aNumber); nextPut: Character nl;
                    nextPutAll: aNumber printString;
                    nextPutAll: '. **Fixture decision without an index row**';
                    nextPut: Character nl]].
        ^out contents
    ]

    DecisionIndexFixtures class >> replacingLine: aLineNumber with: replacement in: aString [
        | out |
        out := WriteStream on: String new.
        (self linesIn: aString) do: [:record |
            out nextPutAll: ((record at: #line) = aLineNumber
                ifTrue: [replacement] ifFalse: [record at: #text]);
                nextPut: Character nl].
        ^out contents
    ]

    DecisionIndexFixtures class >> duplicatingIndexRow: aNumber in: aString [
        | row |
        row := (self indexRowsIn: aString) detect: [:each |
            (each at: #number) = aNumber] ifNone: [^aString copy].
        ^self replacingLine: (row at: #line)
            with: (row at: #text), (String with: Character nl), (row at: #text)
            in: aString
    ]

    DecisionIndexFixtures class >> breakingAnchorFor: aNumber in: aString [
        | row |
        row := (self indexRowsIn: aString) detect: [:each |
            (each at: #number) = aNumber] ifNone: [^aString copy].
        ^self replacingLine: (row at: #line)
            with: '| ', aNumber printString, ' | ', (row at: #ruling),
                ' | [decision ', aNumber printString, '](#absent-anchor) |'
            in: aString
    ]

    DecisionIndexFixtures class >> validExample [
        "Independent literal oracle: index ordered, log deliberately not."
        ^'## 1. Before
9. **An ordinary list item**
## 8. Decision Log

| Number | Ruling | Anchor |
| --- | --- | --- |
| 1 | First ruling | [decision 1](#decision-1) |
| 2 | Second ruling | [decision 2](#decision-2) |

<a id="decision-2"></a>
2. **Second ruling**
<a id="decision-1"></a>
1. **First ruling**

## 9. After
99. **Another ordinary list item**
'
    ]
]

Namespace current: Smalltalk.
