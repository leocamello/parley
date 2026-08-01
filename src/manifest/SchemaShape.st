"Parley — SchemaShape: the value predicates the schema validators share.
 Spec: docs/design/manifest-and-serialization.md §7.1; issue #13 S12;
 §8 decisions 41-42.
 CLI's lock validator and DirectorySource's entry validator each kept a
 private copy of the same string predicate — duplicated deliberately at
 Sprint 10, with hex-digest validation named as the third caller that
 would end it. This is that ending: one definition, asked by both.
 The admission rule is fixed (Doc B §7.1): a predicate belongs here when
 TWO schema validators need it; one caller keeps it private. SchemaShape
 holds no state and decides nothing — it answers questions about values
 handed to it, and never signals: the validators own their wordings."

Namespace current: Parley.

Object subclass: SchemaShape [

    <comment: 'The shared value predicates of the schema validators, as
class-side messages: isString:, isStringArray:, isHexDigest:. Stateless
— every message answers a Boolean about the value handed to it. Shape
only, never truth: isHexDigest: checks what a sha256 RENDERS as under
Doc B §5.4; whether a digest matches its bytes stays
ContentStore>>verifyHash:.'>

    SchemaShape class >> isString: aValue [
        "A schema string is a String and NOT a Symbol: in 3.2.5 Symbol
         is a String subclass, and the two are distinct literals in
         the micro-format grammar."
        <category: 'value predicates'>
        ^aValue isString and: [aValue isSymbol not]
    ]

    SchemaShape class >> isStringArray: aValue [
        "An Array whose every element is a schema string. The empty
         array qualifies."
        <category: 'value predicates'>
        (aValue isKindOf: Array) ifFalse: [^false].
        aValue do: [:each |
            (self isString: each) ifFalse: [^false]].
        ^true
    ]

    SchemaShape class >> isHexDigest: aValue [
        "Exactly 64 lowercase hex characters — what the settled Sha256
         renders under Doc B §5.4. Uppercase is rejected deliberately:
         a digest an operator uppercased is not the writer's output.
         The digest shape is a refinement of the string kind: whatever
         this accepts, isString: accepts too."
        <category: 'value predicates'>
        (self isString: aValue) ifFalse: [^false].
        aValue size = 64 ifFalse: [^false].
        aValue do: [:each |
            ((each >= $0 and: [each <= $9])
                or: [each >= $a and: [each <= $f]]) ifFalse: [^false]].
        ^true
    ]
]

Namespace current: Smalltalk.
