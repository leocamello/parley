"Parley — Term: the resolver's polarity-carrying clause atom.
 Spec: docs/design/resolver.md §3; issue #4 S1.
 An immutable (package, VersionConstraint, isPositive) value. A positive
 term asserts 'any selected version of package satisfies constraint'; a
 negative term asserts the complement. Equality and hash ride the three
 value fields only; the optional origin (the Incompatibility that
 introduced the term) is pure provenance and is excluded."

Namespace current: Parley.

Object subclass: Term [
    | package constraint isPositive origin |

    <comment: 'An immutable resolver clause atom: package name, version
constraint and polarity. negated answers a new Term with the polarity
flipped. origin carries the Incompatibility that imposed this term
(provenance for hard ban 6 — never intersect anonymously) and takes no
part in equality.'>

    Term class >> package: aName constraint: aConstraint positive: aBoolean [
        "A term with no provenance origin."
        <category: 'instance creation'>
        ^self package: aName constraint: aConstraint positive: aBoolean
            origin: nil
    ]

    Term class >> package: aName constraint: aConstraint positive: aBoolean origin: anIncompatibilityOrNil [
        "A term carrying the Incompatibility that imposed it."
        <category: 'instance creation'>
        ^self new
            setPackage: aName
            constraint: aConstraint
            positive: aBoolean
            origin: anIncompatibilityOrNil
    ]

    setPackage: aName constraint: aConstraint positive: aBoolean origin: anOrigin [
        "Private — initialization from the class-side constructors."
        <category: 'private'>
        package := aName.
        constraint := aConstraint.
        isPositive := aBoolean.
        origin := anOrigin
    ]

    package [
        <category: 'accessing'>
        ^package
    ]

    constraint [
        <category: 'accessing'>
        ^constraint
    ]

    isPositive [
        <category: 'accessing'>
        ^isPositive
    ]

    origin [
        "The Incompatibility that imposed this term, or nil."
        <category: 'accessing'>
        ^origin
    ]

    negated [
        "A new Term with the polarity flipped; provenance rides along."
        <category: 'operations'>
        ^Term package: package constraint: constraint
            positive: isPositive not origin: origin
    ]

    = aTerm [
        <category: 'comparing'>
        ^(aTerm isKindOf: Term)
            and: [package = aTerm package
                and: [constraint = aTerm constraint
                    and: [isPositive = aTerm isPositive]]]
    ]

    hash [
        <category: 'comparing'>
        ^(package hash * 31 + constraint hash) * 31 + isPositive hash
    ]

    pinnedVersion [
        "The single exactly-pinned Version this term's constraint allows,
         or nil when the constraint is not an exact pin."
        <category: 'accessing'>
        | rs r |
        rs := constraint ranges.
        rs size = 1 ifFalse: [^nil].
        r := rs first.
        (r min notNil
            and: [r min = r max
                and: [r includeMin and: [r includeMax]]])
            ifTrue: [^r min].
        ^nil
    ]

    printOn: aStream [
        "The narration phrase: exact pins render as bare versions
         ('kernel-a 1.2.0'); everything else via the constraint's
         canonical printString ('kernel-c >=1.0.0 <2.0.0')."
        <category: 'printing'>
        | pinned |
        aStream nextPutAll: package.
        aStream nextPut: Character space.
        pinned := self pinnedVersion.
        pinned isNil
            ifTrue: [aStream print: constraint]
            ifFalse: [aStream print: pinned]
    ]
]

Namespace current: Smalltalk.
