"Parley — VersionRange: one contiguous, immutable span of versions.
 Spec: docs/design/domain-model.md §2.
 nil bounds mean unbounded; inclusivity is explicit per bound."

Namespace current: Parley.

Object subclass: VersionRange [
    | min max includeMin includeMax |

    <comment: 'One contiguous span of versions with explicit open/closed
bounds; a nil bound means unbounded on that side. Immutable: class-side
construction only; construction signals on a provably empty span.'>

    VersionRange class >> from: lo to: hi includeMin: minBool includeMax: maxBool [
        "Answer a range [lo, hi] with the given bound inclusivity; lo/hi
         may be nil (unbounded). Signal on a provably empty span."
        <category: 'instance creation'>
        (lo notNil and: [hi notNil]) ifTrue: [
            lo > hi ifTrue: [
                ^Error new signal: 'Empty version range: lower bound ',
                    lo printString, ' exceeds upper bound ', hi printString].
            (lo = hi and: [(minBool and: [maxBool]) not]) ifTrue: [
                ^Error new signal: 'Empty version range: equal bounds at ',
                    lo printString, ' with an open end']].
        ^self new
            setMin: lo
            max: hi
            includeMin: (lo isNil ifTrue: [false] ifFalse: [minBool])
            includeMax: (hi isNil ifTrue: [false] ifFalse: [maxBool])
    ]

    setMin: lo max: hi includeMin: minBool includeMax: maxBool [
        "Private — initialization from the class-side constructor."
        <category: 'private'>
        min := lo.
        max := hi.
        includeMin := minBool.
        includeMax := maxBool
    ]

    min [
        <category: 'accessing'>
        ^min
    ]

    max [
        <category: 'accessing'>
        ^max
    ]

    includeMin [
        <category: 'accessing'>
        ^includeMin
    ]

    includeMax [
        <category: 'accessing'>
        ^includeMax
    ]

    allows: aVersion [
        "Bound checks honoring inclusivity (spec §2.2 reference shape)."
        <category: 'testing'>
        (min notNil and: [
            includeMin ifTrue: [aVersion < min] ifFalse: [aVersion <= min]])
                ifTrue: [^false].
        (max notNil and: [
            includeMax ifTrue: [aVersion > max] ifFalse: [aVersion >= max]])
                ifTrue: [^false].
        ^true
    ]

    isEmpty [
        <category: 'testing'>
        (min isNil or: [max isNil]) ifTrue: [^false].
        min > max ifTrue: [^true].
        ^min = max and: [(includeMin and: [includeMax]) not]
    ]

    intersect: aRange [
        "Answer the overlap of the receiver and aRange, or nil when
         disjoint. Greater lower bound and lesser upper bound win (a nil
         bound always loses); inclusivity resolves by AND on equal bounds."
        <category: 'set operations'>
        | lo iLo hi iHi |
        lo := min.
        iLo := includeMin.
        aRange min notNil ifTrue: [
            (lo isNil or: [aRange min > lo])
                ifTrue: [lo := aRange min. iLo := aRange includeMin]
                ifFalse: [
                    aRange min = lo
                        ifTrue: [iLo := iLo and: [aRange includeMin]]]].
        hi := max.
        iHi := includeMax.
        aRange max notNil ifTrue: [
            (hi isNil or: [aRange max < hi])
                ifTrue: [hi := aRange max. iHi := aRange includeMax]
                ifFalse: [
                    aRange max = hi
                        ifTrue: [iHi := iHi and: [aRange includeMax]]]].
        (lo notNil and: [hi notNil]) ifTrue: [
            lo > hi ifTrue: [^nil].
            (lo = hi and: [(iLo and: [iHi]) not]) ifTrue: [^nil]].
        ^VersionRange from: lo to: hi includeMin: iLo includeMax: iHi
    ]

    coalescesWith: aRange [
        "True when the receiver and aRange overlap, or when they are
         exactly adjacent: one's max equals the other's min and at least
         one of the touching bounds is inclusive (spec §2.2)."
        <category: 'testing'>
        (self intersect: aRange) notNil ifTrue: [^true].
        ^(self touchesBelow: aRange) or: [aRange touchesBelow: self]
    ]

    touchesBelow: aRange [
        "Private — true when the receiver's max meets aRange's min and at
         least one touching bound is inclusive."
        <category: 'private'>
        ^(max notNil and: [aRange min notNil and: [max = aRange min]])
            and: [includeMax or: [aRange includeMin]]
    ]

    = aRange [
        <category: 'comparing'>
        ^(aRange isKindOf: VersionRange)
            and: [min = aRange min
                and: [max = aRange max
                    and: [includeMin = aRange includeMin
                        and: [includeMax = aRange includeMax]]]]
    ]

    hash [
        <category: 'comparing'>
        ^((min hash * 31 + max hash) * 31 + includeMin hash) * 31
            + includeMax hash
    ]

    printOn: aStream [
        "Render per the §3.5 comparator-pair rules for a single range."
        <category: 'printing'>
        (min isNil and: [max isNil]) ifTrue: [^aStream nextPutAll: '*'].
        (min notNil and: [min = max])
            ifTrue: [^aStream nextPut: $=; print: min].
        min notNil ifTrue: [
            aStream nextPutAll: (includeMin ifTrue: ['>='] ifFalse: ['>']).
            aStream print: min.
            max notNil ifTrue: [aStream nextPut: Character space]].
        max notNil ifTrue: [
            aStream nextPutAll: (includeMax ifTrue: ['<='] ifFalse: ['<']).
            aStream print: max]
    ]
]

Namespace current: Smalltalk.
