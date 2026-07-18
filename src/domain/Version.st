"Parley — Version: an immutable major.minor.patch value object.
 Spec: docs/design/domain-model.md §1.
 Prerelease and build tags are deferred whole; parsing rejects them."

Namespace current: Parley.

Error subclass: VersionFormatError [
    <comment: 'Signaled by Version class>>fromString: on any input that is
not one to three dot-separated non-negative decimal integers. Prerelease
and build tags are unsupported in this version of Parley.'>
]

Object subclass: Version [
    | major minor patch |

    <comment: 'An immutable semantic version triple. Class-side construction
only; ordering is lexicographic on (major, minor, patch); canonical printing
always emits all three components.'>

    Version class >> major: aMajor minor: aMinor patch: aPatch [
        "Answer a version with the given non-negative integer components."
        <category: 'instance creation'>
        ^self new setMajor: aMajor minor: aMinor patch: aPatch
    ]

    Version class >> fromString: aString [
        "Parse one to three dot-separated non-negative decimal integer
         components; missing components default to 0. Signal
         VersionFormatError on anything else."
        <category: 'instance creation'>
        | parts current nums |
        (aString isNil or: [aString isEmpty])
            ifTrue: [^self signalFormat: aString].
        parts := OrderedCollection new.
        current := WriteStream on: String new.
        aString do: [:ch |
            ch = $.
                ifTrue: [parts add: current contents.
                        current := WriteStream on: String new]
                ifFalse: [current nextPut: ch]].
        parts add: current contents.
        parts size > 3 ifTrue: [^self signalFormat: aString].
        parts do: [:part |
            part isEmpty ifTrue: [^self signalFormat: aString].
            (part detect: [:ch | ch isDigit not] ifNone: [nil]) isNil
                ifFalse: [^self signalFormat: aString]].
        nums := parts collect: [:part | part asInteger].
        ^self
            major: (nums at: 1)
            minor: (nums size >= 2 ifTrue: [nums at: 2] ifFalse: [0])
            patch: (nums size >= 3 ifTrue: [nums at: 3] ifFalse: [0])
    ]

    Version class >> signalFormat: aString [
        <category: 'private'>
        ^VersionFormatError new signal: 'Invalid version string ',
            aString printString,
            ': expected 1-3 dot-separated non-negative integers; prerelease',
            ' and build tags are unsupported in this version of Parley'
    ]

    setMajor: aMajor minor: aMinor patch: aPatch [
        "Private — initialization from the class-side constructor."
        <category: 'private'>
        major := aMajor.
        minor := aMinor.
        patch := aPatch
    ]

    major [
        <category: 'accessing'>
        ^major
    ]

    minor [
        <category: 'accessing'>
        ^minor
    ]

    patch [
        <category: 'accessing'>
        ^patch
    ]

    < aVersion [
        <category: 'comparing'>
        major ~= aVersion major ifTrue: [^major < aVersion major].
        minor ~= aVersion minor ifTrue: [^minor < aVersion minor].
        ^patch < aVersion patch
    ]

    > aVersion [
        <category: 'comparing'>
        ^aVersion < self
    ]

    <= aVersion [
        <category: 'comparing'>
        ^(aVersion < self) not
    ]

    >= aVersion [
        <category: 'comparing'>
        ^(self < aVersion) not
    ]

    = aVersion [
        <category: 'comparing'>
        ^(aVersion isKindOf: Version)
            and: [major = aVersion major
                and: [minor = aVersion minor and: [patch = aVersion patch]]]
    ]

    hash [
        <category: 'comparing'>
        ^((major hash * 31) + minor hash) * 31 + patch hash
    ]

    printOn: aStream [
        "Canonical form: always all three components."
        <category: 'printing'>
        aStream
            nextPutAll: major printString;
            nextPut: $.;
            nextPutAll: minor printString;
            nextPut: $.;
            nextPutAll: patch printString
    ]
]

Namespace current: Smalltalk.
