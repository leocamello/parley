"Parley — VersionConstraint: the keystone set algebra over versions.
 Spec: docs/design/domain-model.md §3.
 Normal form: a sorted Array of disjoint, non-adjacent VersionRanges; all
 construction passes through normalizing:. Two constraints denoting the
 same version set are structurally identical."

Namespace current: Parley.

Error subclass: ConstraintFormatError [
    <comment: 'Signaled by VersionConstraint class>>fromString: on input
outside the constraint grammar, naming the offending token.'>
]

Object subclass: VersionConstraint [
    | ranges |

    <comment: 'An immutable set of versions in two-level normal form: a
sorted Array of disjoint, non-adjacent VersionRanges ordered by lower
bound (nil min sorts first). The algebra rests on the two primitives
intersect: and complement plus normalization; difference: and isSubsetOf:
stay derived.'>

    "---- construction (all funnels into normalizing:) ----"

    VersionConstraint class >> normalizing: aRangeCollection [
        "THE single construction funnel: sort by lower bound, drop empties,
         coalesce overlapping/adjacent ranges, answer canonical instance."
        <category: 'instance creation'>
        | sorted merged |
        sorted := (aRangeCollection reject: [:r | r isNil or: [r isEmpty]])
            asSortedCollection: [:a :b | self lower: a notAfter: b].
        merged := OrderedCollection new.
        sorted do: [:r |
            (merged isEmpty not and: [merged last coalescesWith: r])
                ifTrue: [merged addLast: (self hull: merged removeLast with: r)]
                ifFalse: [merged addLast: r]].
        ^self new setRanges: merged asArray
    ]

    VersionConstraint class >> any [
        "The constraint allowing every version: one fully unbounded range."
        <category: 'instance creation'>
        ^self normalizing: (Array with:
            (VersionRange from: nil to: nil includeMin: false includeMax: false))
    ]

    VersionConstraint class >> none [
        "The empty constraint: no ranges."
        <category: 'instance creation'>
        ^self normalizing: #()
    ]

    VersionConstraint class >> exactly: aVersion [
        "An exact pin: the degenerate range [v, v]."
        <category: 'instance creation'>
        ^self normalizing: (Array with:
            (VersionRange from: aVersion to: aVersion
                includeMin: true includeMax: true))
    ]

    VersionConstraint class >> atLeast: aVersion [
        "[v, oo)"
        <category: 'instance creation'>
        ^self normalizing: (Array with:
            (VersionRange from: aVersion to: nil
                includeMin: true includeMax: false))
    ]

    VersionConstraint class >> lessThan: aVersion [
        "(-oo, v)"
        <category: 'instance creation'>
        ^self normalizing: (Array with:
            (VersionRange from: nil to: aVersion
                includeMin: false includeMax: false))
    ]

    VersionConstraint class >> from: lo to: hi [
        "[lo, hi) — the half-open default."
        <category: 'instance creation'>
        ^self normalizing: (Array with:
            (VersionRange from: lo to: hi includeMin: true includeMax: false))
    ]

    VersionConstraint class >> compatibleWith: aVersion [
        "Caret over a full three-component version (spec §3.4)."
        <category: 'instance creation'>
        ^self caret: aVersion components: 3
    ]

    VersionConstraint class >> caret: aVersion components: componentCount [
        "Cargo-exact caret: the leftmost nonzero of the componentCount
         written components is the breaking-change boundary; when all
         written components are zero, the last written one is."
        <category: 'private'>
        | comps idx upper |
        comps := Array
            with: aVersion major with: aVersion minor with: aVersion patch.
        idx := nil.
        1 to: componentCount do: [:i |
            (idx isNil and: [(comps at: i) > 0]) ifTrue: [idx := i]].
        idx isNil ifTrue: [idx := componentCount].
        idx = 1 ifTrue: [
            upper := Version major: aVersion major + 1 minor: 0 patch: 0].
        idx = 2 ifTrue: [
            upper := Version
                major: aVersion major minor: aVersion minor + 1 patch: 0].
        idx = 3 ifTrue: [
            upper := Version
                major: aVersion major
                minor: aVersion minor
                patch: aVersion patch + 1].
        ^self from: aVersion to: upper
    ]

    "---- parsing (§3.6 grammar; accepts everything printOn: emits) ----"

    VersionConstraint class >> fromString: aString [
        "Parse the constraint grammar: '*' | clause ('||' clause)*, where a
         clause is a caret, ANDed comparators, or a bare (exact) version.
         Also accepts 'none' — printOn: emits it and the parser must accept
         everything printOn: emits. Signals ConstraintFormatError."
        <category: 'instance creation'>
        | trimmed result |
        trimmed := (aString ifNil: ['']) trimSeparators.
        trimmed isEmpty
            ifTrue: [^self formatError: aString].
        trimmed = '*' ifTrue: [^self any].
        trimmed = 'none' ifTrue: [^self none].
        result := self none.
        (self split: trimmed) do: [:clause |
            result := result union: (self parseClause: clause)].
        ^result
    ]

    VersionConstraint class >> split: aString [
        "Private — split on the '||' union separator, keeping empty
         clauses so they can be rejected."
        <category: 'private'>
        | clauses current stream ch |
        clauses := OrderedCollection new.
        current := WriteStream on: String new.
        stream := ReadStream on: aString.
        [stream atEnd] whileFalse: [
            ch := stream next.
            (ch = $| and: [stream atEnd not and: [stream peek = $|]])
                ifTrue: [stream next.
                        clauses add: current contents.
                        current := WriteStream on: String new]
                ifFalse: [current nextPut: ch]].
        clauses add: current contents.
        ^clauses
    ]

    VersionConstraint class >> parseClause: aString [
        "Private — parse one clause: caret, comparators, or bare version."
        <category: 'private'>
        | tokens |
        tokens := aString trimSeparators
            ifEmpty: [^self formatError: aString]
            ifNotEmpty: [:trimmed | trimmed subStrings: ' '].
        (tokens size = 1 and: [(tokens first at: 1) = $^])
            ifTrue: [^self parseCaret: tokens first].
        (tokens size = 1 and: [(tokens first at: 1) isDigit])
            ifTrue: [^self exactly: (self version: tokens first in: tokens first)].
        ^tokens inject: self any into: [:acc :token |
            acc intersect: (self parseComparator: token)]
    ]

    VersionConstraint class >> parseCaret: aToken [
        "Private — '^' version, expanded per §3.4 with the written
         component count."
        <category: 'private'>
        | rest |
        rest := aToken copyFrom: 2 to: aToken size.
        rest isEmpty ifTrue: [^self formatError: aToken].
        ^self
            caret: (self version: rest in: aToken)
            components: (rest occurrencesOf: $.) + 1
    ]

    VersionConstraint class >> parseComparator: aToken [
        "Private — one comparator-prefixed version."
        <category: 'private'>
        | v |
        (aToken startsWith: '>=') ifTrue: [
            ^self atLeast: (self version: (aToken copyFrom: 3 to: aToken size) in: aToken)].
        (aToken startsWith: '<=') ifTrue: [
            v := self version: (aToken copyFrom: 3 to: aToken size) in: aToken.
            ^self normalizing: (Array with:
                (VersionRange from: nil to: v includeMin: false includeMax: true))].
        (aToken startsWith: '>') ifTrue: [
            v := self version: (aToken copyFrom: 2 to: aToken size) in: aToken.
            ^self normalizing: (Array with:
                (VersionRange from: v to: nil includeMin: false includeMax: false))].
        (aToken startsWith: '<') ifTrue: [
            ^self lessThan: (self version: (aToken copyFrom: 2 to: aToken size) in: aToken)].
        (aToken startsWith: '=') ifTrue: [
            ^self exactly: (self version: (aToken copyFrom: 2 to: aToken size) in: aToken)].
        ^self formatError: aToken
    ]

    VersionConstraint class >> version: aString in: aToken [
        "Private — parse a version inside a constraint, converting format
         failures into ConstraintFormatError naming the offending token."
        <category: 'private'>
        ^[Version fromString: aString]
            on: VersionFormatError
            do: [:e | self formatError: aToken]
    ]

    VersionConstraint class >> formatError: aToken [
        <category: 'private'>
        ^ConstraintFormatError new signal: 'Invalid constraint near ',
            aToken printString,
            ': expected ''*'', a caret, comparators, or a version,',
            ' with clauses joined by ''||'''
    ]

    VersionConstraint class >> lower: aRange notAfter: otherRange [
        "Private — sort predicate on lower bounds; nil min sorts first."
        <category: 'private'>
        aRange min isNil ifTrue: [^true].
        otherRange min isNil ifTrue: [^false].
        aRange min = otherRange min
            ifTrue: [^aRange includeMin or: [otherRange includeMin not]].
        ^aRange min < otherRange min
    ]

    VersionConstraint class >> hull: aRange with: otherRange [
        "Private — the single range spanning two coalescing ranges."
        <category: 'private'>
        | lo iLo hi iHi |
        (aRange min isNil or: [otherRange min isNil])
            ifTrue: [lo := nil. iLo := false]
            ifFalse: [
                aRange min < otherRange min
                    ifTrue: [lo := aRange min. iLo := aRange includeMin]
                    ifFalse: [
                        otherRange min < aRange min
                            ifTrue: [lo := otherRange min.
                                    iLo := otherRange includeMin]
                            ifFalse: [lo := aRange min.
                                    iLo := aRange includeMin
                                        or: [otherRange includeMin]]]].
        (aRange max isNil or: [otherRange max isNil])
            ifTrue: [hi := nil. iHi := false]
            ifFalse: [
                aRange max > otherRange max
                    ifTrue: [hi := aRange max. iHi := aRange includeMax]
                    ifFalse: [
                        otherRange max > aRange max
                            ifTrue: [hi := otherRange max.
                                    iHi := otherRange includeMax]
                            ifFalse: [hi := aRange max.
                                    iHi := aRange includeMax
                                        or: [otherRange includeMax]]]].
        ^VersionRange from: lo to: hi includeMin: iLo includeMax: iHi
    ]

    "---- instance side ----"

    setRanges: anArray [
        "Private — initialization from normalizing:."
        <category: 'private'>
        ranges := anArray
    ]

    ranges [
        "The normal-form Array of disjoint, non-adjacent ranges."
        <category: 'accessing'>
        ^ranges
    ]

    allows: aVersion [
        <category: 'testing'>
        ranges do: [:r | (r allows: aVersion) ifTrue: [^true]].
        ^false
    ]

    isEmpty [
        <category: 'testing'>
        ^ranges isEmpty
    ]

    isAny [
        <category: 'testing'>
        ^ranges size = 1
            and: [ranges first min isNil and: [ranges first max isNil]]
    ]

    intersect: aConstraint [
        "Pairwise range intersection, then normalization. Naive O(n*m) is
         accepted — real n,m are 1-2."
        <category: 'set operations'>
        | acc |
        acc := OrderedCollection new.
        ranges do: [:r |
            aConstraint ranges do: [:s |
                | overlap |
                overlap := r intersect: s.
                overlap notNil ifTrue: [acc add: overlap]]].
        ^VersionConstraint normalizing: acc
    ]

    union: aConstraint [
        <category: 'set operations'>
        ^VersionConstraint normalizing: ranges , aConstraint ranges
    ]

    complement [
        "Walk the gaps: a range before the first, between consecutive, and
         after the last, flipping bound inclusivity at each edge."
        <category: 'set operations'>
        | acc first last |
        ranges isEmpty ifTrue: [^VersionConstraint any].
        acc := OrderedCollection new.
        first := ranges first.
        first min notNil ifTrue: [
            acc add: (VersionRange
                from: nil to: first min
                includeMin: false includeMax: first includeMin not)].
        1 to: ranges size - 1 do: [:i |
            | a b |
            a := ranges at: i.
            b := ranges at: i + 1.
            acc add: (VersionRange
                from: a max to: b min
                includeMin: a includeMax not
                includeMax: b includeMin not)].
        last := ranges last.
        last max notNil ifTrue: [
            acc add: (VersionRange
                from: last max to: nil
                includeMin: last includeMax not includeMax: false)].
        ^VersionConstraint normalizing: acc
    ]

    difference: aConstraint [
        "Derived — keep it derived."
        <category: 'set operations'>
        ^self intersect: aConstraint complement
    ]

    isSubsetOf: aConstraint [
        "Derived — keep it derived."
        <category: 'testing'>
        ^(self difference: aConstraint) isEmpty
    ]

    = aConstraint [
        <category: 'comparing'>
        ^(aConstraint isKindOf: VersionConstraint)
            and: [ranges = aConstraint ranges]
    ]

    hash [
        <category: 'comparing'>
        ^ranges inject: 17 into: [:h :r | (h * 31 + r hash) \\ 1073741824]
    ]

    printOn: aStream [
        "Canonical rendering per §3.5 — this IS the wire form."
        <category: 'printing'>
        ranges ifEmpty: [^aStream nextPutAll: 'none'].
        self isAny ifTrue: [^aStream nextPutAll: '*'].
        ranges
            do: [:r | aStream print: r]
            separatedBy: [aStream nextPutAll: ' || ']
    ]
]

Namespace current: Smalltalk.
