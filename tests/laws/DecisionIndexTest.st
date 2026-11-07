"Parley Sprint 23 — decision/index drift laws, issue #25 S9-S11.
 These laws check the declared numbers, table ordering, explicit anchors
 and section bound. They do not prove a summary's meaning. Fixture
 controls execute before the real-artifact guard; the missing index is
 the genuine RED failure. No new selector is a declared pass in RED."

Namespace current: Parley.

TestCase subclass: DecisionIndexTest [

    <comment: 'Textual drift laws over the real section-eight log and
index, with independent positive controls and precisely diagnosed
falsifiers. Numeric log order is intentionally irrelevant.'>

    assertFailure: aCategory token: aToken in: someFailures [
        self assert: (DecisionIndexFixtures hasFailure: aCategory
            token: aToken in: someFailures)
            description: 'missing ', aCategory printString, ' for ',
                aToken printString, ': ', someFailures printString.
        someFailures do: [:failure |
            self assert: (failure at: #path) = DecisionIndexFixtures architecturePath.
            self assert: (failure at: #line) > 0]
    ]

    assertRealIndexPresentIn: text [
        self deny: text isEmpty description: 'the architecture source is absent'.
        self deny: (DecisionIndexFixtures decisionNumbersIn: text) isEmpty
            description: 'section eight yielded no decisions'.
        self deny: (DecisionIndexFixtures indexRowsIn: text) isEmpty
            description: 'section eight has no decision index'
    ]

    testTheIndexNamesEveryDecisionOnceInNumericOrder [
        "Numbers and anchors are textual declarations; their summaries
         still require a reader's review."
        | control text numbers rows reversed malformed firstRow lastRow |
        control := DecisionIndexFixtures validExample.
        self assert: (DecisionIndexFixtures decisionNumbersIn: control) = #(2 1).
        self assert: (DecisionIndexFixtures wholeFileDecisionNumbersIn: control)
            = #(9 2 1 99).
        self assert: (DecisionIndexFixtures indexFailuresIn: control) isEmpty.
        rows := DecisionIndexFixtures indexRowsIn: control.
        firstRow := rows first.
        lastRow := rows last.
        reversed := DecisionIndexFixtures
            replacingLine: (firstRow at: #line)
            with: (lastRow at: #text) in: control.
        reversed := DecisionIndexFixtures
            replacingLine: (lastRow at: #line)
            with: (firstRow at: #text) in: reversed.
        self deny: reversed = control.
        self assertFailure: #indexOrder token: #(2 1)
            in: (DecisionIndexFixtures indexFailuresIn: reversed).
        malformed := DecisionIndexFixtures
            replacingLine: (firstRow at: #line)
            with: '| one | First ruling | [decision 1](#decision-1) |'
            in: control.
        self assertFailure: #malformedIndexRow
            token: '| one | First ruling | [decision 1](#decision-1) |'
            in: (DecisionIndexFixtures indexFailuresIn: malformed).
        self assertFailure: #missingIndex token: DecisionIndexFixtures indexHeading
            in: (DecisionIndexFixtures indexFailuresIn: '').
        text := DecisionIndexFixtures architectureSource.
        self assertRealIndexPresentIn: text.
        numbers := DecisionIndexFixtures decisionNumbersIn: text.
        rows := DecisionIndexFixtures indexRowsIn: text.
        self assert: numbers asSet = (1 to: 91) asSet.
        self assert: (rows collect: [:row | row at: #number]) asSet = numbers asSet.
        self assert: (DecisionIndexFixtures indexFailuresIn: text) isEmpty
            description: (DecisionIndexFixtures indexFailuresIn: text) printString
    ]

    testTheIndexComparisonRejectsBothDriftDirections [
        "A removed row and an added decision are distinct mismatches.
         A hard-coded maximum must not mask the missing-row diagnosis."
        | control removed grown text |
        control := DecisionIndexFixtures validExample.
        self assert: (DecisionIndexFixtures indexFailuresIn: control) isEmpty.
        removed := DecisionIndexFixtures removingIndexRow: 1 from: control.
        self deny: removed = control.
        self assertFailure: #missingIndexRow token: 1
            in: (DecisionIndexFixtures indexFailuresIn: removed).
        grown := DecisionIndexFixtures appendingUnindexedDecision: 3 to: control.
        self deny: grown = control.
        self assert: (DecisionIndexFixtures decisionNumbersIn: grown) = #(2 1 3).
        self assert: (DecisionIndexFixtures indexFailuresIn: grown) size = 1.
        self assertFailure: #missingIndexRow token: 3
            in: (DecisionIndexFixtures indexFailuresIn: grown).
        text := DecisionIndexFixtures architectureSource.
        self assertRealIndexPresentIn: text.
        self assert: (DecisionIndexFixtures indexFailuresIn: text) isEmpty.
        removed := DecisionIndexFixtures removingIndexRow: 1 from: text.
        self deny: removed = text.
        self assertFailure: #missingIndexRow token: 1
            in: (DecisionIndexFixtures indexFailuresIn: removed).
        grown := DecisionIndexFixtures appendingUnindexedDecision: 92 to: text.
        self deny: grown = text.
        self assert: (DecisionIndexFixtures decisionNumbersIn: grown) size = 92.
        self assert: (DecisionIndexFixtures indexFailuresIn: grown) size = 1.
        self assertFailure: #missingIndexRow token: 92
            in: (DecisionIndexFixtures indexFailuresIn: grown)
    ]

    testTheIndexRejectsDuplicateRowsAndBrokenAnchors [
        "Set equality alone misses duplicate rows; link presence alone
         misses a link aimed at the wrong decision."
        | control duplicated broken text anchorRecord removedAnchor duplicatedAnchor displacedAnchor |
        control := DecisionIndexFixtures validExample.
        self assert: (DecisionIndexFixtures indexFailuresIn: control) isEmpty.
        duplicated := DecisionIndexFixtures duplicatingIndexRow: 1 in: control.
        self deny: duplicated = control.
        self assertFailure: #duplicateIndexRow token: 1
            in: (DecisionIndexFixtures indexFailuresIn: duplicated).
        broken := DecisionIndexFixtures breakingAnchorFor: 1 in: control.
        self deny: broken = control.
        self assertFailure: #anchorMismatch token: 1
            in: (DecisionIndexFixtures indexFailuresIn: broken).
        anchorRecord := (DecisionIndexFixtures linesIn: control)
            detect: [:record | (record at: #text) = '<a id="decision-1"></a>'].
        removedAnchor := DecisionIndexFixtures
            replacingLine: (anchorRecord at: #line) with: '' in: control.
        self assertFailure: #missingAnchor token: 1
            in: (DecisionIndexFixtures indexFailuresIn: removedAnchor).
        duplicatedAnchor := DecisionIndexFixtures
            replacingLine: (anchorRecord at: #line)
            with: '<a id="decision-1"></a>', (String with: Character nl),
                '<a id="decision-1"></a>' in: control.
        self assertFailure: #duplicateAnchor token: 1
            in: (DecisionIndexFixtures indexFailuresIn: duplicatedAnchor).
        displacedAnchor := DecisionIndexFixtures
            replacingLine: (anchorRecord at: #line)
            with: '<a id="decision-1"></a>', (String with: Character nl)
            in: control.
        self assertFailure: #misplacedAnchor token: 1
            in: (DecisionIndexFixtures indexFailuresIn: displacedAnchor).
        text := DecisionIndexFixtures architectureSource.
        self assertRealIndexPresentIn: text.
        self assert: (DecisionIndexFixtures indexFailuresIn: text) isEmpty.
        duplicated := DecisionIndexFixtures duplicatingIndexRow: 1 in: text.
        self deny: duplicated = text.
        self assertFailure: #duplicateIndexRow token: 1
            in: (DecisionIndexFixtures indexFailuresIn: duplicated).
        broken := DecisionIndexFixtures breakingAnchorFor: 1 in: text.
        self deny: broken = text.
        self assertFailure: #anchorMismatch token: 1
            in: (DecisionIndexFixtures indexFailuresIn: broken)
    ]
]

Namespace current: Smalltalk.
