"Parley — IndexEntryReader: the literals-only reader, the trust boundary
 for all static third-party artifacts.
 Spec: docs/design/manifest-and-serialization.md §5.1, §7.
 A self-contained recursive-descent parser accepting ONLY literal arrays,
 strings, symbols and non-negative integers, separated by whitespace.
 Everything else fails with a positioned parse error. Never delegates to
 any compilation pathway."

Namespace current: Parley.

Error subclass: IndexEntryParseError [
    | position |

    <comment: 'Signaled by IndexEntryReader on any input outside the
literal grammar. position is the 1-based index of the first character at
which the input departs from the grammar.'>

    IndexEntryParseError class >> signalAt: anInteger reason: aString [
        "Signal a parse error at the given 1-based character position."
        <category: 'instance creation'>
        ^self new setPosition: anInteger;
            signal: 'Parse error at position ', anInteger printString,
                ': ', aString,
                ' - the micro-format accepts only literal arrays,',
                ' strings, symbols and non-negative integers'
    ]

    setPosition: anInteger [
        "Private — initialization before signaling."
        <category: 'private'>
        position := anInteger
    ]

    position [
        <category: 'accessing'>
        ^position
    ]
]

Error subclass: IndexEntryFormatError [
    <comment: 'Signaled by IndexEntryReader on a structurally valid literal
artifact whose format tag is unknown or whose format version is
unsupported — the forward-evolution point, distinct from a parse error.'>
]

Object subclass: IndexEntryReader [
    | stream |

    <comment: 'Parses one static artifact from a stream into nested Arrays
of strings, symbols and non-negative integers, then validates the format
tag and version. Recursive descent over the literal grammar only; no
third-party content ever reaches a compiler pathway.'>

    IndexEntryReader class >> readFrom: aStream [
        "Parse and answer the artifact's nested literal structure,
         validating the format tag and version."
        <category: 'reading'>
        ^self new parse: aStream
    ]

    parse: aStream [
        "Private — one artifact: a single literal array, then end of
         input, then tag validation."
        <category: 'private'>
        | artifact |
        stream := aStream.
        self skipWhitespace.
        (self peekOr: nil) = $#
            ifFalse: [self errorAt: self nextPosition
                reason: 'artifact must open with a literal array'].
        artifact := self parseElement.
        self skipWhitespace.
        stream atEnd ifFalse: [
            self errorAt: self nextPosition
                reason: 'trailing content after the artifact'].
        self validateTagOf: artifact.
        ^artifact
    ]

    validateTagOf: anArray [
        "Private — accept only the #'parley-index' 1 and #'parley-lock' 1
         openings (the pair owns both schemas; Doc B §7)."
        <category: 'private'>
        | tag |
        (anArray size >= 2 and: [(anArray at: 1) isSymbol])
            ifFalse: [^IndexEntryFormatError new signal:
                'artifact does not open with a format tag and version'].
        tag := anArray at: 1.
        (tag = #'parley-index' or: [tag = #'parley-lock'])
            ifFalse: [^IndexEntryFormatError new signal:
                'unknown format tag ', tag printString,
                ': this Parley reads #''parley-index'' and #''parley-lock'' artifacts'].
        (anArray at: 2) = 1
            ifFalse: [^IndexEntryFormatError new signal:
                'unsupported ', tag printString, ' format version ',
                (anArray at: 2) printString,
                ': this Parley reads format version 1']
    ]

    parseElement [
        "Private — array, string, symbol or non-negative integer."
        <category: 'private'>
        | ch |
        ch := self peekOr: nil.
        ch isNil ifTrue: [
            self errorAt: self nextPosition reason: 'unexpected end of input'].
        ch = $# ifTrue: [^self parseHashed].
        ch = $' ifTrue: [^self parseString].
        ch isDigit ifTrue: [^self parseInteger].
        self errorAt: self nextPosition
            reason: 'unexpected character ', ch printString
    ]

    parseHashed [
        "Private — after peeking '#': a nested array, a bare symbol, or a
         quoted symbol."
        <category: 'private'>
        | ch |
        stream next.
        ch := self peekOr: nil.
        ch isNil ifTrue: [
            self errorAt: self nextPosition
                reason: 'unexpected end of input after #'].
        ch = $( ifTrue: [stream next. ^self parseArrayBody].
        ch = $' ifTrue: [^self parseQuotedString asSymbol].
        ch isLetter ifTrue: [^self parseBareSymbol].
        self errorAt: self nextPosition
            reason: 'unexpected character ', ch printString, ' after #'
    ]

    parseArrayBody [
        "Private — elements up to the closing parenthesis."
        <category: 'private'>
        | elements ch |
        elements := OrderedCollection new.
        [self skipWhitespace.
         ch := self peekOr: nil.
         ch isNil ifTrue: [
            self errorAt: self nextPosition
                reason: 'unterminated literal array'].
         ch = $)] whileFalse: [elements add: self parseElement].
        stream next.
        ^elements asArray
    ]

    parseString [
        "Private — a string literal."
        <category: 'private'>
        ^self parseQuotedString
    ]

    parseQuotedString [
        "Private — quote-delimited characters; '' escapes a quote."
        <category: 'private'>
        | out ch |
        stream next.
        out := WriteStream on: String new.
        [true] whileTrue: [
            stream atEnd ifTrue: [
                self errorAt: self nextPosition
                    reason: 'unterminated string'].
            ch := stream next.
            ch = $'
                ifTrue: [
                    (self peekOr: nil) = $'
                        ifTrue: [out nextPut: stream next]
                        ifFalse: [^out contents]]
                ifFalse: [out nextPut: ch]]
    ]

    parseBareSymbol [
        "Private — #identifier: letters, digits and colons."
        <category: 'private'>
        | out ch |
        out := WriteStream on: String new.
        [ch := self peekOr: nil.
         ch notNil and: [ch isLetter or: [ch isDigit or: [ch = $:]]]]
            whileTrue: [out nextPut: stream next].
        ^out contents asSymbol
    ]

    parseInteger [
        "Private — a non-negative decimal integer; the character right
         after the digits must be whitespace, a closing parenthesis or
         the end of input (a decimal point or letter is float or
         message-send syntax and is rejected there)."
        <category: 'private'>
        | value ch |
        value := 0.
        [ch := self peekOr: nil.
         ch notNil and: [ch isDigit]] whileTrue: [
            value := value * 10 + (stream next digitValue)].
        ch := self peekOr: nil.
        (ch isNil or: [(self isWhitespace: ch) or: [ch = $)]])
            ifFalse: [self errorAt: self nextPosition
                reason: 'unexpected character ', ch printString,
                    ' after an integer'].
        ^value
    ]

    skipWhitespace [
        "Private — space, tab, carriage return and newline separate
         elements."
        <category: 'private'>
        | ch |
        [ch := self peekOr: nil.
         ch notNil and: [self isWhitespace: ch]]
            whileTrue: [stream next]
    ]

    isWhitespace: aCharacter [
        <category: 'private'>
        ^aCharacter = Character space
            or: [aCharacter = Character tab
                or: [aCharacter = Character nl
                    or: [aCharacter = Character cr]]]
    ]

    peekOr: aDefault [
        "Private — the next character without consuming it, or aDefault
         at end of input."
        <category: 'private'>
        ^stream atEnd ifTrue: [aDefault] ifFalse: [stream peek]
    ]

    nextPosition [
        "Private — the 1-based position of the next unread character."
        <category: 'private'>
        ^stream position + 1
    ]

    errorAt: anInteger reason: aString [
        <category: 'private'>
        ^IndexEntryParseError signalAt: anInteger reason: aString
    ]
]

Namespace current: Smalltalk.
