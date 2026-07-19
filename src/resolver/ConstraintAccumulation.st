"Parley — ConstraintAccumulation: one package's accumulated constraint
 with full provenance.
 Spec: docs/design/resolver.md §4; issue #4 S6.
 Immutable: addingTerm: answers a NEW accumulation with the intersection
 recomputed and the term appended — the value shape that makes the
 ledger's copy-on-descend sharing safe."

Namespace current: Parley.

Object subclass: ConstraintAccumulation [
    | constraint terms |

    <comment: 'An immutable pair of (accumulated VersionConstraint,
contributing Terms in recording order). Sharing instances across ledger
copies is safe because no operation mutates one.'>

    ConstraintAccumulation class >> empty [
        "The untouched accumulation: any-constraint, no terms."
        <category: 'instance creation'>
        ^self new setConstraint: VersionConstraint any terms: #()
    ]

    setConstraint: aConstraint terms: aTermArray [
        "Private — initialization from the class-side constructors."
        <category: 'private'>
        constraint := aConstraint.
        terms := aTermArray
    ]

    constraint [
        <category: 'accessing'>
        ^constraint
    ]

    terms [
        "The contributing terms, in recording order."
        <category: 'accessing'>
        ^terms
    ]

    addingTerm: aTerm [
        "A new accumulation: the intersection tightened by aTerm's
         constraint, the term appended to the provenance trail."
        <category: 'operations'>
        ^ConstraintAccumulation new
            setConstraint: (constraint intersect: aTerm constraint)
            terms: (terms copyWith: aTerm)
    ]
]

Namespace current: Smalltalk.
