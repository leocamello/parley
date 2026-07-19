"Parley — ConstraintLedger: the sole custodian of constraint
 accumulation during resolution.
 Spec: docs/design/resolver.md §4 (the §4.2 reference shape);
 issue #4 S7-S8.
 Hard ban 6: no bare constraint is ever stored — every recording rides a
 Term with provenance. recordTerm: answers nil while satisfiable and the
 collapse Incompatibility (conflictFrom: the contributing terms) the
 moment an accumulation empties. copy is copy-on-descend: the dictionary
 is copied, the immutable accumulation values are shared."

Namespace current: Parley.

Object subclass: ConstraintLedger [
    | accumulations |

    <comment: 'The resolver''s constraint bookkeeper. Grows by replacing
dictionary entries with fresh ConstraintAccumulation values — never by
mutating one — so copies made on descent share history safely and
backtracking is simply discarding a ledger.'>

    init [
        "Private — a fresh, empty ledger."
        <category: 'private'>
        accumulations := Dictionary new
    ]

    ConstraintLedger class >> new [
        <category: 'instance creation'>
        ^super new init
    ]

    postCopy [
        "Copy-on-descend: own dictionary, shared accumulation values."
        <category: 'copying'>
        super postCopy.
        accumulations := accumulations copy
    ]

    recordTerm: aTerm [
        "Fold aTerm into its package's accumulation. Answers nil while
         the accumulation stays satisfiable; answers the collapse
         Incompatibility (with full term provenance) when it empties."
        <category: 'recording'>
        | acc |
        acc := (accumulations at: aTerm package
            ifAbsent: [ConstraintAccumulation empty]) addingTerm: aTerm.
        accumulations at: aTerm package put: acc.
        ^acc constraint isEmpty
            ifTrue: [Incompatibility conflictFrom: acc terms]
            ifFalse: [nil]
    ]

    constraintFor: aName [
        "The accumulated constraint for aName; any if untouched."
        <category: 'accessing'>
        ^(accumulations at: aName
            ifAbsent: [^VersionConstraint any]) constraint
    ]

    termsFor: aName [
        "The contributing terms for aName in recording order; empty if
         untouched."
        <category: 'accessing'>
        ^(accumulations at: aName ifAbsent: [^#()]) terms
    ]

    undecidedPackagesGiven: aPartialSolution [
        "The ledger-touched package names absent from the partial
         solution dictionary (name -> Version)."
        <category: 'accessing'>
        ^accumulations keys
            reject: [:name | aPartialSolution includesKey: name]
    ]
]

Namespace current: Smalltalk.
