"Parley — BacktrackingStrategy: the MVP search strategy.
 Spec: docs/design/resolver.md §5 (the reference shape); issue #4
 S9-S14.
 Smallest-domain-first package selection (ties alphabetical), candidates
 highest-first, copy-on-descend ledgers (backtracking = discarding a
 ledger; no undo logs). External incompatibilities are born on the way
 down; derived ones at collapse and exhaustion points; the unwind
 carries finished values only — never exceptions, never explanation
 branches, never I/O. No backjumping in the MVP (deferred; the
 provenance data supports it)."

Namespace current: Parley.

Object subclass: BacktrackingStrategy [
    | snapshot rootName |

    <comment: 'The depth-first search strategy behind Resolver. Holds
the immutable snapshot and root name for the duration of one solve;
every recursion level owns its own ledger copy and partial-solution
copy, so failure is answered upward as a finished Incompatibility
value.'>

    solve: aManifest against: aSnapshot ledger: aLedger [
        "Run the search from the root ledger. Answers a Resolution or
         the root Incompatibility of the failure derivation."
        <category: 'solving'>
        snapshot := aSnapshot.
        rootName := aManifest name.
        ^self solveFrom: aLedger solution: Dictionary new
    ]

    solveFrom: ledger solution: partial [
        "One search level: pick the smallest-domain undecided package,
         try its candidates highest-first, answer the first Resolution
         or the exhaustion Incompatibility."
        <category: 'solving'>
        | package candidates failures result |
        package := self nextUndecidedIn: ledger given: partial.
        package isNil ifTrue: [^self resolutionFrom: partial].
        candidates := ((snapshot versionsOf: package)
            select: [:v | (ledger constraintFor: package) allows: v])
            asSortedCollection: [:a :b | a > b].
        candidates isEmpty ifTrue: [
            ^Incompatibility noVersionsOf: package
                matching: (ledger constraintFor: package)
                blamedOn: (ledger termsFor: package)].
        failures := OrderedCollection new.
        candidates do: [:version |
            result := self try: package version: version
                ledger: ledger solution: partial.
            result isResolution ifTrue: [^result].
            failures add: result].
        ^Incompatibility exhausted: package
            blamedOn: (ledger termsFor: package)
            causes: failures
    ]

    try: package version: version ledger: ledger solution: partial [
        "Descend on one candidate: copy the ledger, record the
         candidate's dependency edges as terms with provenance, recurse.
         A ledger collapse is answered upward immediately."
        <category: 'solving'>
        | child extended collapse edge |
        child := ledger copy.
        (snapshot dependenciesOf: package version: version) do: [:dep |
            edge := Incompatibility package: package version: version
                dependsOn: dep name constraint: dep constraint.
            collapse := child recordTerm: (Term package: dep name
                constraint: dep constraint positive: true origin: edge).
            collapse notNil ifTrue: [^collapse]].
        extended := partial copy.
        extended at: package put: version.
        ^self solveFrom: child solution: extended
    ]

    nextUndecidedIn: ledger given: partial [
        "The undecided package with the fewest allowed candidates; ties
         broken alphabetically. nil when every touched package is
         decided."
        <category: 'private'>
        | best bestSize size |
        best := nil.
        bestSize := nil.
        ((ledger undecidedPackagesGiven: partial)
            asSortedCollection: [:x :y | x <= y]) do: [:name |
                size := ((snapshot versionsOf: name)
                    select: [:v | (ledger constraintFor: name) allows: v])
                    size.
                (best isNil or: [size < bestSize]) ifTrue: [
                    best := name.
                    bestSize := size]].
        ^best
    ]

    resolutionFrom: partial [
        "Private — finish: pair every decided version with its snapshot
         hash and answer the Resolution value."
        <category: 'private'>
        | triples |
        triples := Dictionary new.
        partial keysAndValuesDo: [:name :version |
            triples at: name put: (Array
                with: version
                with: (snapshot sha256For: name version: version))].
        ^Resolution root: rootName triples: triples
    ]
]

Namespace current: Smalltalk.
