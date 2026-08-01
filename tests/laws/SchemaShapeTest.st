"Parley Sprint 11 — laws for Parley.SchemaShape (issue #13; Doc B
 §7.1, §8 decisions 41 and 42).

 SchemaShape holds the value predicates both schema validators ask, as
 class-side messages: isString:, isStringArray:, isHexDigest:. It
 holds no state and decides nothing — it answers questions about
 values handed to it. It exists because CLI>>isLockString: and
 DirectorySource>>isSchemaString: were the SAME predicate in two
 classes, duplicated deliberately in Sprint 10; hex-digest validation
 is the third caller, the exact trigger Sprint 10 named for fixing it.

 The admission rule is fixed (Doc B §7.1): a predicate belongs here
 when TWO schema validators need it; one caller keeps it private. The
 single-definition law at the bottom is what proves the deletion — a
 private copy left behind is the gap not closed.

 isHexDigest: validates the SHAPE — exactly 64 lowercase hex
 characters, what a sha256 renders as under §5.4 — never the truth:
 whether a digest matches its bytes is ContentStore>>verifyHash: and
 nothing else.

 DECLARED PASSES IN RED: none. Every law here fails against the
 pre-sprint tree — the class does not exist yet, so each send answers
 a MessageNotUnderstood, which is the valid red the gate accepts.

 Nothing here touches the filesystem, spawns, or contacts a network."

Namespace current: Parley.

TestCase subclass: SchemaShapeTest [

    <comment: 'Laws for SchemaShape: the three value predicates over
their corpora, the shape rule of isHexDigest: from every side, and the
single-definition law proving both settled private copies are gone.'>

    hex: aCharacter times: anInteger [
        ^String new: anInteger withAll: aCharacter
    ]

    "---- isString: ----"

    testIsStringAcceptsStringsAndRejectsSymbols [
        "The predicate the two validators duplicated: a schema string
         is a String and NOT a Symbol — in 3.2.5 Symbol is a String
         subclass, and the two are distinct literals in the
         micro-format grammar."
        self assert: (SchemaShape isString: 'kernel-json').
        self assert: (SchemaShape isString: '').
        self deny: (SchemaShape isString: #root).
        self deny: (SchemaShape isString: #'kernel-json')
    ]

    testIsStringRejectsNonStrings [
        self deny: (SchemaShape isString: 42).
        self deny: (SchemaShape isString: #()).
        self deny: (SchemaShape isString: (Array with: 'a')).
        self deny: (SchemaShape isString: nil)
    ]

    "---- isStringArray: ----"

    testIsStringArrayAcceptsOnlyArraysOfStrings [
        self assert: (SchemaShape isStringArray: #()).
        self assert: (SchemaShape isStringArray:
            (Array with: 'Reader.st' with: 'Writer.st')).
        self deny: (SchemaShape isStringArray: 'Reader.st').
        self deny: (SchemaShape isStringArray: (Array with: #root)).
        self deny: (SchemaShape isStringArray:
            (Array with: 'Reader.st' with: 42)).
        self deny: (SchemaShape isStringArray:
            (Array with: (Array with: 'nested')))
    ]

    "---- isHexDigest: ----"

    testIsHexDigestAcceptsSixtyFourLowercaseHex [
        self assert: (SchemaShape isHexDigest: (self hex: $a times: 64)).
        self assert: (SchemaShape isHexDigest: (self hex: $0 times: 64)).
        self assert: (SchemaShape isHexDigest: (self hex: $f times: 64)).
        self assert: (SchemaShape isHexDigest:
            '4da43d9155a1c841dd267a01a54cd0670bcabcdd6a29c46f455ea5e6e93a5edd')
    ]

    testIsHexDigestRejectsWrongLengths [
        self deny: (SchemaShape isHexDigest: '').
        self deny: (SchemaShape isHexDigest: (self hex: $a times: 63)).
        self deny: (SchemaShape isHexDigest: (self hex: $a times: 65)).
        self deny: (SchemaShape isHexDigest: 'nothex')
    ]

    testIsHexDigestRejectsTheWrongAlphabet [
        "Uppercase is rejected deliberately: §5.4 fixes what a sha256
         RENDERS as, and the settled Sha256 renders lowercase. A digest
         an operator uppercased is not the writer's output."
        self deny: (SchemaShape isHexDigest: (self hex: $A times: 64)).
        self deny: (SchemaShape isHexDigest: (self hex: $g times: 64)).
        self deny: (SchemaShape isHexDigest:
            (self hex: $a times: 63), 'G').
        self deny: (SchemaShape isHexDigest:
            (self hex: $a times: 63), ' ')
    ]

    testIsHexDigestRejectsNonStrings [
        "A Symbol of 64 hex characters is still not a schema string —
         the kind rule and the shape rule compose."
        self deny: (SchemaShape isHexDigest: (self hex: $a times: 64) asSymbol).
        self deny: (SchemaShape isHexDigest: 42).
        self deny: (SchemaShape isHexDigest: nil).
        self deny: (SchemaShape isHexDigest: #())
    ]

    testAHexDigestIsAlwaysASchemaString [
        "The implication over the whole corpus: whatever isHexDigest:
         accepts, isString: accepts too — the digest shape is a
         refinement of the string kind, never a parallel rule."
        InspectionFixtures hexDigestCorpus do: [:row |
            self assert: ((SchemaShape isHexDigest: (row at: 1)) not
                    or: [SchemaShape isString: (row at: 1)])
                description: 'isHexDigest: accepted what isString: rejects: ',
                    (row at: 1) printString]
    ]

    testTheCorpusVerdictsHold [
        "The two corpora as declared rows, so S12 and these laws read
         one fixture and cannot drift apart."
        InspectionFixtures hexDigestCorpus do: [:row |
            self assert: (SchemaShape isHexDigest: (row at: 1)) = (row at: 2)
                description: 'isHexDigest: disagreed on ', (row at: 1) printString].
        InspectionFixtures stringCorpus do: [:row |
            self assert: (SchemaShape isString: (row at: 1)) = (row at: 2)
                description: 'isString: disagreed on ', (row at: 1) printString]
    ]

    "---- the single definition (S12's law half) ----"

    testNeitherValidatorImplementsThePredicateItself [
        "The deletion proved: the settled private copies are GONE, not
         merely bypassed. includesSelector: asks a Behavior about its
         OWN selectors (probed against 3.2.5), so a copy left behind
         fails here even if nothing calls it — a copy left behind is
         the gap not closed."
        self deny: (CLI includesSelector: #isLockString:)
            description: 'CLI still carries its private isLockString: copy'.
        self deny: (DirectorySource includesSelector: #isSchemaString:)
            description: 'DirectorySource still carries its private isSchemaString: copy'.
        self deny: (DirectorySource includesSelector: #isSchemaStringArray:)
            description: 'DirectorySource still carries its private isSchemaStringArray: copy'
    ]
]

Namespace current: Smalltalk.
