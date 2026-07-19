"Parley — Resolver: the pure resolution function.
 Spec: docs/design/resolver.md §2; issue #4 S9, S17.
 A pure function of (root manifest, immutable index snapshot): zero live
 I/O mid-resolution, answers a value — Resolution or ConflictReport —
 never exceptions. The strategy seam stays clean:
 (Resolver strategy: BacktrackingStrategy new) today; a PubGrubStrategy
 must be an additive swap later (deferred — do not build)."

Namespace current: Parley.

Object subclass: Resolver [
    | strategy |

    <comment: 'The resolution entry point. Seeds a fresh
ConstraintLedger with the root manifest''s dependencies (as Terms whose
origins are the root''s dependency edges), delegates the search to the
configured strategy, and wraps any failure root in a ConflictReport.'>

    Resolver class >> strategy: aStrategy [
        <category: 'instance creation'>
        ^self new setStrategy: aStrategy
    ]

    setStrategy: aStrategy [
        "Private — initialization from the class-side constructor."
        <category: 'private'>
        strategy := aStrategy
    ]

    resolve: aManifest against: aSnapshot [
        "Answer a Resolution or a ConflictReport — a value either way."
        <category: 'resolving'>
        | ledger edge collapse result |
        ledger := ConstraintLedger new.
        aManifest dependencies do: [:dep |
            edge := Incompatibility package: aManifest name
                version: aManifest version
                dependsOn: dep name
                constraint: dep constraint.
            collapse := ledger recordTerm: (Term package: dep name
                constraint: dep constraint positive: true origin: edge).
            collapse notNil ifTrue: [^ConflictReport root: collapse]].
        result := strategy solve: aManifest against: aSnapshot
            ledger: ledger.
        ^result isResolution
            ifTrue: [result]
            ifFalse: [ConflictReport root: result]
    ]
]

Namespace current: Smalltalk.
