"Parley — Incompatibility: an immutable set of terms that cannot all
 hold, plus its cause.
 Spec: docs/design/resolver.md §3, §5; issue #4 S2-S5.
 External nodes are born on the way down (#dependency off an index edge,
 #noVersions at an empty candidate set, #decision when a strategy
 decides pkg -> v); derived nodes are born at
 ledger collapse and candidate exhaustion, their cause linking the
 parent incompatibilities into a walkable derivation tree.
 printOn: renders the canonical human sentence for this node only."

Namespace current: Parley.

Object subclass: Incompatibility [
    | terms cause conclusionTerms subject matching |

    <comment: 'An immutable resolver clause: a term set that cannot all
hold. cause is #dependency, #noVersions or #decision for external nodes,
or the collection of parent Incompatibilities for derived nodes. conclusionTerms
carry the terms the narrated conclusion speaks about; subject/matching
name the starved package for #noVersions nodes.'>

    "---- external constructors (born on the way down) ----"

    Incompatibility class >> package: aName version: aVersion dependsOn: depName constraint: aConstraint [
        "The external #dependency clause for one index edge:
         {P exactly v, not (Q C)}."
        <category: 'instance creation'>
        ^self new
            setTerms: (Array
                with: (Term package: aName
                    constraint: (VersionConstraint exactly: aVersion)
                    positive: true)
                with: (Term package: depName
                    constraint: aConstraint
                    positive: false))
            cause: #dependency
            conclusionTerms: nil
            subject: nil
            matching: nil
    ]

    Incompatibility class >> noVersionsOf: aName matching: aConstraint blamedOn: aTermCollection [
        "The external #noVersions clause: the candidate set of aName
         under its accumulated constraint is empty. The blamed terms are
         the accumulation's contributing terms — provenance in hand."
        <category: 'instance creation'>
        ^self new
            setTerms: aTermCollection asArray
            cause: #noVersions
            conclusionTerms: nil
            subject: aName
            matching: aConstraint
    ]

    Incompatibility class >> decisionOf: aName version: aVersion [
        "The external #decision clause: the strategy decided
         aName -> aVersion. The single positive exact term
         {aName = aVersion} — the origin of that decision's pin term
         (Doc C §3, §5 as amended; issue #5 S3)."
        <category: 'instance creation'>
        ^self new
            setTerms: (Array with: (Term package: aName
                constraint: (VersionConstraint exactly: aVersion)
                positive: true))
            cause: #decision
            conclusionTerms: nil
            subject: nil
            matching: nil
    ]

    "---- derived constructors (born at collapse and exhaustion) ----"

    Incompatibility class >> conflictFrom: aTermCollection [
        "The ledger-collapse clause: the contributing terms intersect to
         nothing. The terms ARE the contributing terms; the cause is
         their origin incompatibilities; the conclusion speaks about the
         origins' positive (decision) terms."
        <category: 'instance creation'>
        | contributed causes conclusions |
        contributed := aTermCollection asArray.
        causes := OrderedCollection new.
        contributed do: [:t |
            (t origin notNil
                and: [(causes detect: [:c | c == t origin] ifNone: [nil]) isNil])
                ifTrue: [causes add: t origin]].
        conclusions := OrderedCollection new.
        causes do: [:c | conclusions addAll: c positiveTerms].
        conclusions isEmpty
            ifTrue: [conclusions := contributed asOrderedCollection].
        ^self new
            setTerms: contributed
            cause: causes asArray
            conclusionTerms: conclusions asArray
            subject: nil
            matching: nil
    ]

    Incompatibility class >> exhausted: aName blamedOn: aTermCollection causes: failureCollection [
        "The exhaustion clause: every candidate of aName failed. The
         per-candidate failures become the cause; the blamed terms are
         the accumulation's contributing terms for aName."
        <category: 'instance creation'>
        ^self new
            setTerms: aTermCollection asArray
            cause: failureCollection asArray
            conclusionTerms: aTermCollection asArray
            subject: aName
            matching: nil
    ]

    setTerms: aTermArray cause: aCause conclusionTerms: conclusionArray subject: aName matching: aConstraint [
        "Private — initialization from the class-side constructors."
        <category: 'private'>
        terms := aTermArray.
        cause := aCause.
        conclusionTerms := conclusionArray.
        subject := aName.
        matching := aConstraint
    ]

    "---- accessing & testing ----"

    terms [
        <category: 'accessing'>
        ^terms
    ]

    cause [
        "#dependency / #noVersions / #decision for external nodes; the
         parent Incompatibility collection for derived nodes."
        <category: 'accessing'>
        ^cause
    ]

    isExternal [
        <category: 'testing'>
        ^cause isSymbol
    ]

    isDerived [
        <category: 'testing'>
        ^self isExternal not
    ]

    isResolution [
        "Incompatibilities travel the search loop as failure values."
        <category: 'testing'>
        ^false
    ]

    positiveTerms [
        "The decision-side terms of this clause."
        <category: 'accessing'>
        ^terms select: [:t | t isPositive]
    ]

    "---- narration ----"

    conclusionOn: aStream [
        "The conclusion phrase of this node's sentence."
        <category: 'printing'>
        cause = #dependency ifTrue: [
            (terms detect: [:t | t isPositive]) printOn: aStream.
            aStream nextPutAll: ' depends on '.
            (terms detect: [:t | t isPositive not]) printOn: aStream.
            ^self].
        cause = #decision ifTrue: [
            terms first printOn: aStream.
            aStream nextPutAll: ' is selected'.
            ^self].
        cause = #noVersions ifTrue: [
            aStream nextPutAll: 'no version of '.
            aStream nextPutAll: subject.
            aStream nextPutAll: ' satisfies '.
            aStream print: matching.
            ^self].
        conclusionTerms
            do: [:t | t printOn: aStream]
            separatedBy: [aStream nextPutAll: ' and '].
        aStream nextPutAll: (conclusionTerms size = 1
            ifTrue: [' is incompatible']
            ifFalse: [' are incompatible'])
    ]

    printOn: aStream [
        "The canonical single-node sentence: external nodes are their
         conclusion; derived nodes render 'because <direct causes''
         conclusions>, <conclusion>'."
        <category: 'printing'>
        self isExternal ifTrue: [^self conclusionOn: aStream].
        aStream nextPutAll: 'because '.
        cause
            do: [:parent | parent conclusionOn: aStream]
            separatedBy: [aStream nextPutAll: ' and '].
        aStream nextPutAll: ', '.
        self conclusionOn: aStream
    ]
]

Namespace current: Smalltalk.
