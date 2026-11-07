"Parley — one immutable argument represented as a POSIX shell word.
 Spec: Doc E section 6; architecture decision 91; issue #26.
 Composers supply complete arguments. This value neither interprets
 command syntax nor performs I/O, URL encoding or path normalization."

Namespace current: Parley.

Object subclass: ShellArgument [
    | text |

    <comment: 'An immutable process argument. Construction validates and
copies its String; shellString preserves its bytes as one shell word.
The representation does not change a child tool''s option grammar.'>

    ShellArgument class >> fromString: aString [
        "Validate before construction: NUL cannot occur in a process
         argument, and arbitrary objects are never coerced to strings."
        <category: 'instance creation'>
        aString isString ifFalse: [
            ^CommandArgumentError signal: 'command argument must be a String'].
        (aString includes: (Character value: 0)) ifTrue: [
            ^CommandArgumentError signal: 'command argument contains NUL'].
        ^self new initializeFrom: aString
    ]

    initializeFrom: aString [
        <category: 'private'>
        text := aString copy.
        ^self
    ]

    isSafeToken [
        "Only the approved ASCII alphabet can bypass quoting. Empty
         input still needs a shell word so it does not disappear."
        <category: 'private'>
        | alphabet |
        alphabet := 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_@%+=:,./-'.
        ^text isEmpty not and: [
            (text detect: [:each | (alphabet includes: each) not]
                ifNone: [nil]) isNil]
    ]

    shellString [
        "Answer a fresh rendering. An apostrophe closes the quoted
         portion, escapes one apostrophe, and reopens the quote."
        <category: 'rendering'>
        | out quote |
        self isSafeToken ifTrue: [^text copy].
        quote := Character value: 39.
        out := WriteStream on: String new.
        out nextPut: quote.
        text do: [:each |
            each = quote
                ifTrue: [out nextPut: quote; nextPut: (Character value: 92);
                    nextPut: quote; nextPut: quote]
                ifFalse: [out nextPut: each]].
        out nextPut: quote.
        ^out contents
    ]

    = anArgument [
        "The canonical rendering uniquely represents the raw argument;
         compare through the value protocol without exposing its storage."
        <category: 'comparing'>
        ^self class = anArgument class
            and: [self shellString = anArgument shellString]
    ]

    hash [
        <category: 'comparing'>
        ^self shellString hash
    ]
]

Namespace current: Smalltalk.
