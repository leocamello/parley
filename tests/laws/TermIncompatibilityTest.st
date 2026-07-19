"Parley Sprint 2 — Term & Incompatibility laws (Doc C §3).

 Term is an immutable (package, constraint, isPositive) value; negated
 flips polarity; equality/hash ride on the three value fields only (an
 optional origin Incompatibility carries provenance and is excluded).
 Incompatibilities are external (#dependency, #noVersions) or derived
 (cause links the parent incompatibilities), forming a walkable
 derivation tree; printOn: renders the canonical single-node sentence."

Namespace current: Parley.

TestCase subclass: TermIncompatibilityTest [

    <comment: 'Law suite for the resolver clause values: Term polarity
and equality laws, external and derived incompatibility shapes,
derivation-tree walking, and the pinned Doc C §3 narration.'>

    "---- shared example values ----"

    constraint: aString [
        ^VersionConstraint fromString: aString
    ]

    version: aString [
        ^Version fromString: aString
    ]

    positiveTermOn: aName exactly: aVersionString [
        ^Term
            package: aName
            constraint: (VersionConstraint exactly: (self version: aVersionString))
            positive: true
    ]

    edgeOf: aName version: aVersionString on: depName constraint: aConstraintString [
        "The external #dependency incompatibility for one index edge."
        ^Incompatibility
            package: aName
            version: (self version: aVersionString)
            dependsOn: depName
            constraint: (self constraint: aConstraintString)
    ]

    docCExampleNode [
        "The Doc C §3 derived node: both kernel-c requirements collapse."
        | extA extB termA termB |
        extA := self edgeOf: 'kernel-a' version: '1.2.0'
            on: 'kernel-c' constraint: '>=1.0 <2.0'.
        extB := self edgeOf: 'kernel-b' version: '2.0.0'
            on: 'kernel-c' constraint: '>=2.0 <3.0'.
        termA := Term package: 'kernel-c'
            constraint: (self constraint: '>=1.0 <2.0')
            positive: true
            origin: extA.
        termB := Term package: 'kernel-c'
            constraint: (self constraint: '>=2.0 <3.0')
            positive: true
            origin: extB.
        ^Incompatibility conflictFrom: (Array with: termA with: termB)
    ]

    "---- Term laws ----"

    testTermNegatedFlipsPolarityAndPreservesTheOriginal [
        | t n |
        t := Term package: 'kernel-c'
            constraint: (self constraint: '>=1.0 <2.0')
            positive: true.
        n := t negated.
        self assert: t isPositive.
        self deny: n isPositive.
        self assert: n package = 'kernel-c'.
        self assert: n constraint = (self constraint: '>=1.0 <2.0').
        self assert: t isPositive
            description: 'negated must answer a new Term, not mutate'.
        self assert: n negated = t
    ]

    testTermEqualityAndHashRideTheValueFieldsTogether [
        | a b c |
        a := Term package: 'p' constraint: (self constraint: '^1.2') positive: true.
        b := Term package: 'p' constraint: (self constraint: '^1.2') positive: true.
        c := Term package: 'p' constraint: (self constraint: '^1.2') positive: false.
        self assert: a = b.
        self assert: a hash = b hash.
        self deny: a = c.
        self deny: a = 'p'
    ]

    testTermEqualityIgnoresProvenanceOrigin [
        | plain carried |
        plain := Term package: 'kernel-c'
            constraint: (self constraint: '^1.0') positive: true.
        carried := Term package: 'kernel-c'
            constraint: (self constraint: '^1.0')
            positive: true
            origin: (self edgeOf: 'kernel-a' version: '1.0.0'
                on: 'kernel-c' constraint: '^1.0').
        self assert: plain = carried.
        self assert: plain hash = carried hash
    ]

    testTermPhraseRendersExactPinsAsBareVersions [
        self assert: (self positiveTermOn: 'kernel-a' exactly: '1.2.0')
            printString = 'kernel-a 1.2.0'.
        self assert: (Term package: 'kernel-c'
                constraint: (self constraint: '>=1.0 <2.0')
                positive: true) printString
            = 'kernel-c >=1.0.0 <2.0.0'
    ]

    "---- external incompatibilities ----"

    testDependencyEdgeShape [
        | inc pos neg |
        inc := self edgeOf: 'kernel-a' version: '1.2.0'
            on: 'kernel-c' constraint: '>=1.0 <2.0'.
        self assert: inc isExternal.
        self deny: inc isDerived.
        self assert: inc cause = #dependency.
        self assert: inc terms size = 2.
        pos := ResolverFixtures in: inc terms
            findPackage: 'kernel-a' positive: true
            constraint: (VersionConstraint exactly: (self version: '1.2.0')).
        neg := ResolverFixtures in: inc terms
            findPackage: 'kernel-c' positive: false
            constraint: (self constraint: '>=1.0 <2.0').
        self deny: pos isNil.
        self deny: neg isNil
    ]

    testDependencyEdgeSentence [
        self assert: (self edgeOf: 'kernel-a' version: '1.2.0'
                on: 'kernel-c' constraint: '>=1.0 <2.0') printString
            = 'kernel-a 1.2.0 depends on kernel-c >=1.0.0 <2.0.0'
    ]

    testNoVersionsShapeCarriesTheContributingTerms [
        | blamed inc |
        blamed := Array
            with: (Term package: 'a' constraint: VersionConstraint any positive: true)
            with: (Term package: 'a' constraint: (self constraint: '^9.0') positive: true).
        inc := Incompatibility
            noVersionsOf: 'a'
            matching: (self constraint: '^9.0')
            blamedOn: blamed.
        self assert: inc isExternal.
        self deny: inc isDerived.
        self assert: inc cause = #noVersions.
        self assert: inc terms asOrderedCollection = blamed asOrderedCollection
    ]

    testNoVersionsSentence [
        self assert: (Incompatibility
                noVersionsOf: 'a'
                matching: (self constraint: '^9.0')
                blamedOn: (Array with:
                    (Term package: 'a' constraint: (self constraint: '^9.0') positive: true)))
                printString
            = 'no version of a satisfies >=9.0.0 <10.0.0'
    ]

    "---- derived incompatibilities & the tree ----"

    testConflictFromAnswersDerivedNodeWithParentPairCause [
        | node causes |
        node := self docCExampleNode.
        self assert: node isDerived.
        self deny: node isExternal.
        causes := node cause.
        self assert: causes size = 2.
        self assert: (causes conform: [:p | p isExternal]).
        self assert: (causes conform: [:p | p cause = #dependency])
    ]

    testConflictFromKeepsTheContributingTermsAsItsTerms [
        | node found |
        node := self docCExampleNode.
        self assert: node terms size = 2.
        found := ResolverFixtures in: node terms
            findPackage: 'kernel-c' positive: true
            constraint: (self constraint: '>=1.0 <2.0').
        self deny: found isNil.
        found := ResolverFixtures in: node terms
            findPackage: 'kernel-c' positive: true
            constraint: (self constraint: '>=2.0 <3.0').
        self deny: found isNil
    ]

    testExhaustedAnswersDerivedNodeOverItsCandidateFailures [
        | collapse blamed node |
        collapse := self docCExampleNode.
        blamed := Array with:
            (Term package: 'kernel-b' constraint: (self constraint: '^2.0') positive: true).
        node := Incompatibility
            exhausted: 'kernel-b'
            blamedOn: blamed
            causes: (Array with: collapse).
        self assert: node isDerived.
        self assert: node cause size = 1.
        self assert: (node cause includes: collapse).
        self assert: node terms asOrderedCollection = blamed asOrderedCollection
    ]

    testDerivationTreeWalksToExternalLeaves [
        | node leaves |
        node := Incompatibility
            exhausted: 'kernel-b'
            blamedOn: (Array with:
                (Term package: 'kernel-b' constraint: (self constraint: '^2.0') positive: true))
            causes: (Array with: self docCExampleNode).
        leaves := ResolverFixtures externalLeavesOf: node.
        self assert: leaves size = 2.
        self assert: (leaves conform: [:l | l cause = #dependency])
    ]

    testPinnedDocCDerivedSentence [
        "Doc C §3, verbatim — the canonical single-node narration."
        self assert: self docCExampleNode printString
            = 'because kernel-a 1.2.0 depends on kernel-c >=1.0.0 <2.0.0 and kernel-b 2.0.0 depends on kernel-c >=2.0.0 <3.0.0, kernel-a 1.2.0 and kernel-b 2.0.0 are incompatible'
    ]
]

Namespace current: Smalltalk.
