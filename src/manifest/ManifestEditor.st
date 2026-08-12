"Parley — ManifestEditor: the textual surgery on the operator's own
 Package.st, and nothing else.
 Spec: docs/design/manifest-and-serialization.md §2.1; §8 decision 49;
 issue #15 S1-S3, S5.

 PARLEY NEVER RE-RENDERS A FILE IT DID NOT WRITE. The easy build —
 load the manifest and render Package.st back out of it — is
 disqualified, not merely disfavoured: Package.st is executable
 Smalltalk the author owns, and the manifest is a lossy PROJECTION of
 it carrying none of the author's comments, formatting, reasons, or any
 Smalltalk that is not vocabulary. Re-rendering would silently
 substitute a different program that happens to build an equal
 manifest, and would damage the most careful authors worst. Canonical
 byte-stable rendering is a law for index entries and lockfiles
 BECAUSE Parley owns those artifacts (Doc B §5.4); Package.st is on the
 far side of that line.

 So the mechanism is RECOGNIZE OR REFUSE. This class is given text and
 answers text or nil: it opens no file, knows nothing of locks, sources
 or verbs, and mutates nothing — every operation answers a new value
 and the text it was handed is never touched. Everything about add that
 is risky (writing, re-reading, rolling back) lives in the CLI, where
 the atomicity contract lives.

 The one recognized shape is Doc B §2's: exactly one Parley define:
 send, taking a one-argument block, whose body is a single cascade
 whose clauses are manifest vocabulary sends. Recognition SCANS CODE —
 comments, string literals and character literals are skipped whole —
 because the settled parley init template's own header comment spells
 both the token Parley and a complete dependency:constraint: clause,
 and a recognizer reading raw text would miscount the sends and invent
 a declaration that is not there.

 Everything else is refused, and the refusal is half the feature: an
 editor that guesses at an unfamiliar file is how a package manager
 earns a reputation for eating manifests, while one that hands back a
 line to paste has cost the operator five seconds. Growing this into a
 general Smalltalk parser is exactly how that guess would arrive.

 The insertion preserves EVERY OTHER BYTE: one clause goes in
 immediately after the last clause's final character, at that line's
 own indentation, and the closing bracket, the trailing newline, the
 comments, the blank lines and the author's spacing all travel through
 untouched.

 DELETION IS THE SAME RULING AND IT OWNS THE JOIN (Sprint 20, §8
 decision 67; Doc B §2.1). parley remove <pkg> changes the same file
 under the same trust framing, and it is stated separately because
 deletion has a failure mode insertion does not: an insertion that
 recognizes too little REFUSES, while a deletion that recognizes too
 little DAMAGES. Removing a clause's text and leaving what bound it to
 its neighbours produces a dangling `;', two fused clauses, or a
 cascade with no terminating bracket — a Package.st that no longer
 loads, written by the tool.

 So textWithoutDependency: deletes the clause AND ITS JOIN: the one
 before it, except for the first clause, which owns the one after it.
 That exception is forced rather than tidy — the first clause shares
 its span with the cascade RECEIVER, so there is no join before it to
 take, and leaving `pkg;' in front of the next message is a parse
 error where leaving `pkg' alone is not (probed on 3.2.5 at Gate A).
 Everything between the join and the clause goes with it, including a
 comment the author wrote above that clause, which is a comment about
 the dependency being removed; every other byte is preserved."

Namespace current: Parley.

Object subclass: ManifestEditor [
    | text insertAt clauses |

    <comment: 'A recognizer and single-clause inserter over the text of
one Package.st. Class-side construction; zero public setters; no file
I/O and no collaborators. isRecognized answers whether the text is the
one Doc B §2 cascade shape this editor edits, constraintFor: answers
what that cascade already declares, textWithDependency:constraint:
answers NEW text with one clause inserted, and textWithoutDependency:
answers NEW text with one clause and the join that bound it deleted —
each of them preserving every other byte, or answering nil, the
refusal, when the shape is unfamiliar or the name is not declared.'>

    ManifestEditor class >> on: aString [
        "Answer an editor over the text of one Package.st. All
         recognition happens here, once: the answer to every later
         question is already decided by the time this returns."
        <category: 'instance creation'>
        ^self new setText: aString
    ]

    setText: aString [
        "Private — initialization from the class-side constructor."
        <category: 'private'>
        text := aString.
        self locateCascade
    ]

    "---- the questions this editor answers ----"

    isRecognized [
        "Whether the text is the one shape this editor edits. Everything
         else answers false and is refused untouched."
        <category: 'testing'>
        ^insertAt notNil
    ]

    constraintFor: aName [
        "The constraint aName is already declared under — the literal
         constraint string of a dependency:constraint: clause, or '*'
         for Doc B §3.2's unconstrained dependency: sugar — and nil when
         the cascade does not declare it.

         Read from the CODE, never from the raw text: a clause spelled
         inside a comment is prose, and the settled init template ships
         one."
        <category: 'accessing'>
        self isRecognized ifFalse: [^nil].
        clauses do: [:each |
            | dep |
            dep := self dependencyOfClauseFrom: (each at: 1) to: (each at: 2).
            (dep notNil and: [(dep at: 1) = aName])
                ifTrue: [^dep at: 2]].
        ^nil
    ]

    textWithoutDependency: aName [
        "Answer NEW text with aName's dependency clause AND THE JOIN
         THAT BOUND IT deleted, or nil when the shape is not recognized
         or the cascade does not declare aName.

         A DELETION OWNS ITS SEPARATOR (§8 decision 67). An insertion
         that recognizes too little refuses; a deletion that recognizes
         too little DAMAGES — it leaves a dangling `;`, fuses two
         clauses, or strands a cascade with no terminating `]`, and
         every one of those is a Package.st that no longer loads,
         written by the tool, in a file its author owns.

         WHICH join, amended at Sprint 20's Gate A after a probe: a
         clause owns the join BEFORE it, EXCEPT the first, which owns
         the join AFTER it. The exception is forced rather than tidy.
         The recognizer splits clauses from the block argument bar, so
         clause one holds the cascade RECEIVER as well as its message:
         deleting clause one's span verbatim deletes `pkg`, and taking
         the join before it is impossible because there is none. Taking
         the join after it is what leaves `pkg` standing in front of the
         next message — probed on 3.2.5: `pkg;` followed by a keyword
         message does not parse, and `pkg` alone does.

         Everything between the join and the clause's last character
         goes with it: the indentation, any blank line, and any comment
         the author wrote ABOVE the clause — which is a comment about
         the dependency being removed. Everything else is preserved
         byte for byte, and the receiver is not part of the clause."
        <category: 'editing'>
        | index pair |
        index := self clauseIndexDeclaring: aName.
        index isNil ifTrue: [^nil].
        pair := self deletionSpanAt: index.
        ^(text copyFrom: 1 to: (pair at: 1) - 1),
            (text copyFrom: (pair at: 2) + 1 to: text size)
    ]

    textWithDependency: aName constraint: aConstraintString [
        "Answer NEW text carrying one further dependency:constraint:
         clause after the cascade's last clause, or nil when the shape
         is not recognized.

         Every other byte is preserved: the previous last clause gains
         the cascade semicolon it now needs, the new clause takes that
         line's own indentation rather than one this tool prefers, and
         everything from the insertion point onward — the closing
         bracket, any trailing statement, the final newline — travels
         through as it stood. The receiver is not modified; like every
         Parley operation this answers a new value."
        <category: 'editing'>
        self isRecognized ifFalse: [^nil].
        ^(text copyFrom: 1 to: insertAt - 1),
            ';', self newline, self insertionIndent,
            'dependency: ', (self literalFor: aName),
            ' constraint: ', (self literalFor: aConstraintString),
            (text copyFrom: insertAt to: text size)
    ]

    "---- locating one clause and the span a deletion takes ----"

    clauseIndexDeclaring: aName [
        "Private — the position in the cascade of the clause declaring
         aName, or nil when the shape is unrecognized or nothing
         declares it. Read from the CODE, exactly as constraintFor: is:
         a clause spelled inside a comment is prose, and the settled
         init template ships one."
        <category: 'private-clauses'>
        self isRecognized ifFalse: [^nil].
        1 to: clauses size do: [:i |
            | dep |
            dep := self dependencyOfClauseFrom: ((clauses at: i) at: 1)
                to: ((clauses at: i) at: 2).
            (dep notNil and: [(dep at: 1) = aName]) ifTrue: [^i]].
        ^nil
    ]

    deletionSpanAt: anIndex [
        "Private — the (first, last) character indices a deletion takes:
         the clause's own text plus the ONE separator that bound it.

         For every clause but the first, the span opens just past the
         PREVIOUS clause's last character — so it swallows the join, the
         author's indentation, any blank line and any comment sitting
         above this clause — and closes on this clause's own last
         character, which leaves the closing bracket and the trailing
         newline exactly where they were.

         For the FIRST clause the span opens just past the cascade
         RECEIVER, which shares clause one, and closes on the join
         AFTER it (§8 decision 67 as amended). A first clause that is
         also the only one has no join to take and closes on its own
         last character."
        <category: 'private-clauses'>
        | pair last |
        pair := clauses at: anIndex.
        last := self lastClauseEndFrom: (pair at: 1) to: (pair at: 2).
        anIndex > 1 ifTrue: [
            | previous |
            previous := clauses at: anIndex - 1.
            ^Array
                with: (self lastClauseEndFrom: (previous at: 1)
                    to: (previous at: 2)) + 1
                with: last].
        ^Array
            with: (self receiverEndOfClause: pair) + 1
            with: (anIndex < clauses size
                ifTrue: [((clauses at: anIndex + 1) at: 1) - 1]
                ifFalse: [last])
    ]

    receiverEndOfClause: aPair [
        "Private — the last character of the cascade receiver, which
         shares the first clause with its message. It is everything
         before the clause's first keyword token, trailing whitespace
         and comments trimmed — so `pkg` survives a deletion and the
         author's spacing in front of it survives with it."
        <category: 'private-clauses'>
        | tokens first end |
        tokens := self keywordTokensFrom: (aPair at: 1) to: (aPair at: 2).
        first := ((tokens at: 1) at: 2) - ((tokens at: 1) at: 1) size.
        end := self lastClauseEndFrom: (aPair at: 1) to: first - 1.
        "A cascade whose first clause carries no receiver at all is not
         a shape this editor can be handed by a loadable Package.st, but
         it is a shape the recognizer admits — so the span opens at the
         clause instead of arithmetic on nil."
        ^end isNil ifTrue: [(aPair at: 1) - 1] ifFalse: [end]
    ]

    "---- recognition, decided once at construction ----"

    locateCascade [
        "Private — find the one editable cascade and remember where a
         clause would go. Nothing is remembered unless EVERY condition
         holds, so isRecognized stays one question about one variable
         and a half-recognized file cannot exist.

         The conditions, in order: exactly one Parley define: send; a
         balanced block taking one argument; a body that is a single
         cascade (a top-level period means the file computes, and
         `after the last clause` stops being well defined); at least one
         clause, none of them blank; every clause a manifest vocabulary
         send; and every dependency clause readable as literals, because
         an editor that cannot tell what is declared could declare a
         package twice."
        <category: 'private-recognition'>
        | starts bounds bar end found |
        starts := self defineSendStarts.
        starts size = 1 ifFalse: [^self].
        bounds := self blockBoundsFrom: (starts at: 1).
        bounds isNil ifTrue: [^self].
        bar := self blockArgumentBarFrom: (bounds at: 1).
        bar isNil ifTrue: [^self].
        end := self lastClauseEndFrom: bar + 1 to: (bounds at: 2) - 1.
        end isNil ifTrue: [^self].
        found := self clausesFrom: bar + 1 to: end.
        found isNil ifTrue: [^self].
        found do: [:each |
            (self isEditableClauseFrom: (each at: 1) to: (each at: 2))
                ifFalse: [^self]].
        clauses := found.
        insertAt := end + 1
    ]

    isEditableClauseFrom: aStart to: aStop [
        "Private — whether one cascade clause is a manifest vocabulary
         send this editor can read. The vocabulary is the settled
         ManifestBuilder category, CONSUMED here and never re-listed, so
         the two cannot drift."
        <category: 'private-recognition'>
        | selector |
        selector := self selectorOfClauseFrom: aStart to: aStop.
        selector isEmpty ifTrue: [^false].
        (ManifestBuilder vocabulary
            detect: [:each | each asString = selector]
            ifNone: [nil]) isNil ifTrue: [^false].
        (selector = 'dependency:' or: [selector = 'dependency:constraint:'])
            ifFalse: [^true].
        ^(self dependencyOfClauseFrom: aStart to: aStop) notNil
    ]

    defineSendStarts [
        "Private — every index at which the token Parley is the receiver
         of a define: send. The scan skips comments, string literals and
         character literals WHOLE, which is what keeps the settled init
         template's header comment — it spells the token Parley and a
         full dependency clause — from being read as code."
        <category: 'private-recognition'>
        | starts i |
        starts := OrderedCollection new.
        i := 1.
        [i <= text size] whileTrue: [
            (self isDefineSendAt: i)
                ifTrue: [starts add: i. i := i + 1]
                ifFalse: [i := self advancePast: i]].
        ^starts asArray
    ]

    isDefineSendAt: anIndex [
        "Private — whether the token Parley starts here and is followed
         by define:. The preceding character is checked so a longer
         identifier ending in Parley is not mistaken for it."
        <category: 'private-recognition'>
        | after |
        (text at: anIndex) = $P ifFalse: [^false].
        (anIndex > 1 and: [self isIdentifierChar: (text at: anIndex - 1)])
            ifTrue: [^false].
        (self matches: 'Parley' at: anIndex) ifFalse: [^false].
        after := anIndex + 6.
        (after <= text size and: [self isIdentifierChar: (text at: after)])
            ifTrue: [^false].
        ^self matches: 'define:' at: (self skipSeparatorsFrom: after)
    ]

    blockBoundsFrom: aDefineStart [
        "Private — the open and close bracket indices of the define:
         block, or nil when there is no balanced block to edit inside."
        <category: 'private-recognition'>
        | i open depth |
        i := self skipSeparatorsFrom: aDefineStart + 6.
        i := self skipSeparatorsFrom: i + 7.
        (i <= text size and: [(text at: i) = $[]) ifFalse: [^nil].
        open := i.
        depth := 0.
        [i <= text size] whileTrue: [
            | ch |
            ch := text at: i.
            ch = $[ ifTrue: [depth := depth + 1].
            ch = $] ifTrue: [
                depth := depth - 1.
                depth = 0 ifTrue: [^Array with: open with: i]].
            i := self advancePast: i].
        ^nil
    ]

    blockArgumentBarFrom: anOpenIndex [
        "Private — the index of the block argument bar of the Doc B §2
         [:pkg | … ] block, or nil for any other block shape."
        <category: 'private-recognition'>
        | i |
        i := self skipSeparatorsFrom: anOpenIndex + 1.
        (i <= text size and: [(text at: i) = $:]) ifFalse: [^nil].
        i := i + 1.
        (i <= text size and: [self isIdentifierStart: (text at: i)])
            ifFalse: [^nil].
        [i <= text size and: [self isIdentifierChar: (text at: i)]]
            whileTrue: [i := i + 1].
        i := self skipSeparatorsFrom: i.
        (i <= text size and: [(text at: i) = $|]) ifFalse: [^nil].
        ^i
    ]

    lastClauseEndFrom: aStart to: aStop [
        "Private — the last non-blank character of the cascade's final
         clause; nil when the block holds nothing. Insertion happens
         immediately after it, which is precisely what leaves the
         closing bracket and every byte around it alone."
        <category: 'private-recognition'>
        | i |
        i := aStop.
        [i >= aStart and: [(text at: i) isSeparator]]
            whileTrue: [i := i - 1].
        i < aStart ifTrue: [^nil].
        ^i
    ]

    clausesFrom: aStart to: aStop [
        "Private — the cascade's clauses as (start, stop) index pairs,
         split at top-level semicolons; nil when the body is not one
         cascade. A top-level period means the file computes and a
         blank clause means it cannot be read, and both are refusals
         rather than guesses."
        <category: 'private-recognition'>
        | found i depth clauseStart |
        found := OrderedCollection new.
        depth := 0.
        clauseStart := aStart.
        i := aStart.
        [i <= aStop] whileTrue: [
            | ch |
            ch := text at: i.
            (self isOpenBracket: ch) ifTrue: [depth := depth + 1].
            (self isCloseBracket: ch) ifTrue: [depth := depth - 1].
            (depth = 0 and: [ch = $.]) ifTrue: [^nil].
            (depth = 0 and: [ch = $;]) ifTrue: [
                found add: (Array with: clauseStart with: i - 1).
                clauseStart := i + 1].
            i := self advancePast: i].
        found add: (Array with: clauseStart with: aStop).
        found do: [:each |
            (self isBlankFrom: (each at: 1) to: (each at: 2))
                ifTrue: [^nil]].
        ^found asArray
    ]

    "---- reading one clause ----"

    keywordTokensFrom: aStart to: aStop [
        "Private — every depth-zero keyword token of one clause, as
         (keyword, index just past its colon) pairs in order. `pkg
         name: 'x'` answers one pair, `dependency: 'a' constraint: 'b'`
         answers two, and `yourself` answers none — which is what makes
         a clause outside the vocabulary detectable without parsing
         Smalltalk."
        <category: 'private-clauses'>
        | tokens i depth |
        tokens := OrderedCollection new.
        depth := 0.
        i := aStart.
        [i <= aStop] whileTrue: [
            | ch |
            ch := text at: i.
            (self isOpenBracket: ch) ifTrue: [depth := depth + 1].
            (self isCloseBracket: ch) ifTrue: [depth := depth - 1].
            (depth = 0 and: [self isIdentifierStart: ch])
                ifTrue: [
                    | j |
                    j := i.
                    [j <= aStop and: [self isIdentifierChar: (text at: j)]]
                        whileTrue: [j := j + 1].
                    (j <= aStop and: [(text at: j) = $:])
                        ifTrue: [
                            tokens add: (Array
                                with: (text copyFrom: i to: j)
                                with: j + 1).
                            i := j + 1]
                        ifFalse: [i := j]]
                ifFalse: [i := self advancePast: i]].
        ^tokens asArray
    ]

    selectorOfClauseFrom: aStart to: aStop [
        "Private — the joined selector of one clause's keyword tokens;
         the empty string when it sends no keyword message at all."
        <category: 'private-clauses'>
        | out |
        out := WriteStream on: String new.
        (self keywordTokensFrom: aStart to: aStop)
            do: [:each | out nextPutAll: (each at: 1)].
        ^out contents
    ]

    dependencyOfClauseFrom: aStart to: aStop [
        "Private — (name, constraint) for a dependency clause whose
         arguments are string literals; nil for every other clause AND
         for a dependency clause whose name or constraint is computed.
         The second case is a refusal on purpose: the editor cannot tell
         what such a cascade already declares, and declaring a package
         twice is worse than declining to declare it once."
        <category: 'private-clauses'>
        | tokens i name constraint |
        tokens := self keywordTokensFrom: aStart to: aStop.
        tokens isEmpty ifTrue: [^nil].
        ((tokens at: 1) at: 1) = 'dependency:' ifFalse: [^nil].
        i := self skipSeparatorsFrom: ((tokens at: 1) at: 2).
        (i <= aStop and: [(text at: i) = $']) ifFalse: [^nil].
        name := self stringLiteralAt: i.
        tokens size = 1 ifTrue: [^Array with: name with: '*'].
        tokens size = 2 ifFalse: [^nil].
        ((tokens at: 2) at: 1) = 'constraint:' ifFalse: [^nil].
        i := self skipSeparatorsFrom: ((tokens at: 2) at: 2).
        (i <= aStop and: [(text at: i) = $']) ifFalse: [^nil].
        constraint := self stringLiteralAt: i.
        ^Array with: name with: constraint
    ]

    "---- the scanner: code is what is left when literals are skipped ----"

    advancePast: anIndex [
        "Private — the index just past whatever begins at anIndex: a
         whole comment, a whole string literal, both characters of a
         character literal, or one ordinary code character. Consuming a
         character literal whole is what keeps a quote that is a VALUE
         from opening a literal region."
        <category: 'private-scanning'>
        | ch |
        ch := text at: anIndex.
        ch = $" ifTrue: [^self endOfCommentAt: anIndex].
        ch = $' ifTrue: [^self endOfStringAt: anIndex].
        ch = $$ ifTrue: [^anIndex + 2].
        ^anIndex + 1
    ]

    endOfCommentAt: anIndex [
        "Private — the index just past the comment opening at anIndex. A
         doubled quote inside a comment is an escaped quote, not the
         end. An unterminated comment runs to the end of the text, which
         leaves the file unrecognized rather than mis-edited."
        <category: 'private-scanning'>
        | i |
        i := anIndex + 1.
        [i <= text size] whileTrue: [
            (text at: i) = $"
                ifTrue: [
                    (i < text size and: [(text at: i + 1) = $"])
                        ifTrue: [i := i + 2]
                        ifFalse: [^i + 1]]
                ifFalse: [i := i + 1]].
        ^text size + 1
    ]

    endOfStringAt: anIndex [
        "Private — the index just past the string literal opening at
         anIndex; a doubled quote is an escaped quote."
        <category: 'private-scanning'>
        | i |
        i := anIndex + 1.
        [i <= text size] whileTrue: [
            (text at: i) = $'
                ifTrue: [
                    (i < text size and: [(text at: i + 1) = $'])
                        ifTrue: [i := i + 2]
                        ifFalse: [^i + 1]]
                ifFalse: [i := i + 1]].
        ^text size + 1
    ]

    stringLiteralAt: anIndex [
        "Private — the VALUE of the string literal opening at anIndex,
         with doubled quotes undoubled."
        <category: 'private-scanning'>
        | out i |
        out := WriteStream on: String new.
        i := anIndex + 1.
        [i <= text size] whileTrue: [
            (text at: i) = $'
                ifTrue: [
                    (i < text size and: [(text at: i + 1) = $'])
                        ifTrue: [out nextPut: $'. i := i + 2]
                        ifFalse: [^out contents]]
                ifFalse: [out nextPut: (text at: i). i := i + 1]].
        ^out contents
    ]

    skipSeparatorsFrom: anIndex [
        "Private — the first index at or after anIndex that is neither
         whitespace nor part of a comment."
        <category: 'private-scanning'>
        | i |
        i := anIndex.
        [i <= text size
            and: [(text at: i) isSeparator or: [(text at: i) = $"]]]
                whileTrue: [
                    (text at: i) = $"
                        ifTrue: [i := self endOfCommentAt: i]
                        ifFalse: [i := i + 1]].
        ^i
    ]

    matches: aString at: anIndex [
        "Private — whether aString appears at anIndex, bounds-checked."
        <category: 'private-scanning'>
        | i |
        anIndex < 1 ifTrue: [^false].
        anIndex + aString size - 1 > text size ifTrue: [^false].
        i := 1.
        [i <= aString size] whileTrue: [
            (text at: anIndex + i - 1) = (aString at: i) ifFalse: [^false].
            i := i + 1].
        ^true
    ]

    isBlankFrom: aStart to: aStop [
        "Private — whether the range holds nothing but whitespace (an
         empty range counts as blank)."
        <category: 'private-scanning'>
        aStart to: aStop do: [:i |
            (text at: i) isSeparator ifFalse: [^false]].
        ^true
    ]

    isIdentifierStart: aCharacter [
        <category: 'private-scanning'>
        ^aCharacter isLetter or: [aCharacter = $_]
    ]

    isIdentifierChar: aCharacter [
        <category: 'private-scanning'>
        ^aCharacter isLetter
            or: [aCharacter isDigit or: [aCharacter = $_]]
    ]

    isOpenBracket: aCharacter [
        <category: 'private-scanning'>
        ^aCharacter = $[ or: [aCharacter = $( or: [aCharacter = ${]]
    ]

    isCloseBracket: aCharacter [
        <category: 'private-scanning'>
        ^aCharacter = $] or: [aCharacter = $) or: [aCharacter = $}]]
    ]

    "---- rendering the one inserted clause ----"

    insertionIndent [
        "Private — the leading whitespace of the line the last clause
         ENDS on, which the inserted clause adopts. Imposing an
         indentation of the tool's own would be a small re-render, and
         the author's six spaces are as deliberate as their comments."
        <category: 'private-editing'>
        | lineStart i |
        lineStart := insertAt - 1.
        [lineStart >= 1 and: [(text at: lineStart) ~= Character nl]]
            whileTrue: [lineStart := lineStart - 1].
        lineStart := lineStart + 1.
        i := lineStart.
        [i < insertAt and: [(text at: i) isSeparator]]
            whileTrue: [i := i + 1].
        ^text copyFrom: lineStart to: i - 1
    ]

    literalFor: aString [
        "Private — aString as a Smalltalk string literal, quotes
         doubled."
        <category: 'private-editing'>
        | out |
        out := WriteStream on: String new.
        out nextPut: $'.
        aString do: [:ch |
            ch = $' ifTrue: [out nextPut: $'].
            out nextPut: ch].
        out nextPut: $'.
        ^out contents
    ]

    newline [
        <category: 'private-editing'>
        ^String with: Character nl
    ]
]

Namespace current: Smalltalk.
