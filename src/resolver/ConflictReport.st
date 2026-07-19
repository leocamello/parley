"Parley — ConflictReport: the resolver's failure value, wrapping the
 root of the derivation tree.
 Spec: docs/design/resolver.md §3, §6; issue #4 S15.
 A live object: tests and tools message the tree directly (root, cause,
 terms, isExternal, isDerived). printOn: narrates the proof — a
 post-order walk over the derived nodes, causes before conclusions, one
 canonical sentence per line, no trailing newline."

Namespace current: Parley.

Object subclass: ConflictReport [
    | root |

    <comment: 'The failure value answered by Resolver. Wraps the root
Incompatibility of the derivation tree; delegates the node protocol to
it so callers can walk the proof, and renders the full narrated proof
via printOn:.'>

    ConflictReport class >> root: anIncompatibility [
        <category: 'instance creation'>
        ^self new setRoot: anIncompatibility
    ]

    setRoot: anIncompatibility [
        "Private — initialization from the class-side constructor."
        <category: 'private'>
        root := anIncompatibility
    ]

    root [
        <category: 'accessing'>
        ^root
    ]

    isResolution [
        <category: 'testing'>
        ^false
    ]

    cause [
        <category: 'accessing'>
        ^root cause
    ]

    terms [
        <category: 'accessing'>
        ^root terms
    ]

    isExternal [
        <category: 'testing'>
        ^root isExternal
    ]

    isDerived [
        <category: 'testing'>
        ^root isDerived
    ]

    printOn: aStream [
        "The narrated proof: every derived node in post-order (causes
         before conclusions), one sentence per line, single newlines, no
         trailing newline. An external root narrates its own sentence."
        <category: 'printing'>
        | derived |
        derived := OrderedCollection new.
        self collectDerivedFrom: root into: derived.
        derived isEmpty ifTrue: [^root printOn: aStream].
        derived
            do: [:node | node printOn: aStream]
            separatedBy: [aStream nl]
    ]

    collectDerivedFrom: aNode into: aCollection [
        "Private — post-order accumulation of derived nodes, each once."
        <category: 'private'>
        aNode isDerived ifFalse: [^self].
        aNode cause do: [:parent |
            self collectDerivedFrom: parent into: aCollection].
        (aCollection detect: [:n | n == aNode] ifNone: [nil]) isNil
            ifTrue: [aCollection add: aNode]
    ]
]

Namespace current: Smalltalk.
