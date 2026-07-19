"Parley — IndexSnapshot: the concrete immutable receiver for the
 resolver's snapshot value.
 Spec: docs/design/resolver.md §2; issue #4 (approved addition).
 Hand-buildable from release tuples; answers versionsOf:,
 dependenciesOf:version: (pre-parsed Dependency values) and
 sha256For:version: ('' when absent). Built once before resolution
 begins — the resolver performs zero live I/O against it."

Namespace current: Parley.

Object subclass: IndexSnapshot [
    | packages |

    <comment: 'An immutable in-memory index snapshot. packages maps a
package name to the ordered collection of its (version, sha256,
dependencies) release records. All construction is class-side; no
operation mutates a built snapshot.'>

    IndexSnapshot class >> releases: aCollection [
        "Build a snapshot from release tuples. Each element is an Array:
         {name String. Version. sha256 String ('' when absent). Array of
         Dependency}."
        <category: 'instance creation'>
        ^self new setReleases: aCollection
    ]

    setReleases: aCollection [
        "Private — initialization from the class-side constructor."
        <category: 'private'>
        packages := Dictionary new.
        aCollection do: [:tuple |
            (packages at: (tuple at: 1)
                ifAbsentPut: [OrderedCollection new])
                add: (Array
                    with: (tuple at: 2)
                    with: (tuple at: 3)
                    with: (tuple at: 4))]
    ]

    versionsOf: aName [
        "All published Versions of aName; empty when unknown."
        <category: 'accessing'>
        ^(packages at: aName ifAbsent: [^#()])
            collect: [:rec | rec at: 1]
    ]

    dependenciesOf: aName version: aVersion [
        "The pre-parsed Dependency values of one release; empty when
         unknown."
        <category: 'accessing'>
        | rec |
        rec := self recordOf: aName version: aVersion.
        ^rec isNil ifTrue: [#()] ifFalse: [rec at: 3]
    ]

    sha256For: aName version: aVersion [
        "The release's content hash; the empty string when absent."
        <category: 'accessing'>
        | rec |
        rec := self recordOf: aName version: aVersion.
        ^rec isNil ifTrue: [''] ifFalse: [rec at: 2]
    ]

    recordOf: aName version: aVersion [
        "Private — the release record, or nil."
        <category: 'private'>
        ^(packages at: aName ifAbsent: [^nil])
            detect: [:rec | (rec at: 1) = aVersion]
            ifNone: [nil]
    ]
]

Namespace current: Smalltalk.
