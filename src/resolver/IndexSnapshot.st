"Parley — IndexSnapshot: the concrete immutable receiver for the
 resolver's snapshot value.
 Spec: docs/design/resolver.md §2; issue #4 (approved addition).
 Hand-buildable from release tuples; answers versionsOf:,
 dependenciesOf:version: (pre-parsed Dependency values) and
 sha256For:version: ('' when absent). Built once before resolution
 begins — the resolver performs zero live I/O against it."

Namespace current: Parley.

Object subclass: IndexSnapshot [
    | packages retirements |

    <comment: 'An immutable in-memory index snapshot. packages maps a
package name to the ordered collection of its (version, sha256,
dependencies) release records; retirements maps a package name to the
(version, reason) records its index owner has retired. All
construction is class-side; no operation mutates a built snapshot.'>

    IndexSnapshot class >> releases: aCollection [
        "Build a snapshot from release tuples. Each element is an Array:
         {name String. Version. sha256 String ('' when absent). Array of
         Dependency}. A snapshot with no retirements — the settled
         constructor, and the shape every pre-Sprint-10 caller keeps
         getting."
        <category: 'instance creation'>
        ^self releases: aCollection retirements: #()
    ]

    IndexSnapshot class >> releases: aCollection retirements: aRetirementCollection [
        "The same, plus the index owner's retirements (Doc C §2.1): each
         element an Array {name String. Version. reason String}. A
         retirement naming a release this snapshot does not hold is kept
         and simply never matches — an index owner may retire ahead of a
         deletion."
        <category: 'instance creation'>
        ^self new setReleases: aCollection retirements: aRetirementCollection
    ]

    setReleases: aCollection retirements: aRetirementCollection [
        "Private — initialization from the class-side constructor."
        <category: 'private'>
        packages := Dictionary new.
        aCollection do: [:tuple |
            (packages at: (tuple at: 1)
                ifAbsentPut: [OrderedCollection new])
                add: (Array
                    with: (tuple at: 2)
                    with: (tuple at: 3)
                    with: (tuple at: 4))].
        retirements := Dictionary new.
        aRetirementCollection do: [:tuple |
            (retirements at: (tuple at: 1)
                ifAbsentPut: [OrderedCollection new])
                add: (Array
                    with: (tuple at: 2)
                    with: (tuple at: 3))]
    ]

    versionsOf: aName [
        "All published Versions of aName that are still offered to fresh
         resolution; empty when unknown.

         RETIRED VERSIONS ARE EXCLUDED (Doc C §2.1), and this is the
         whole of the mechanism: the resolver selects only from what it
         is offered, so a retired release is never picked, never appears
         in a conflict derivation, and needs no special case anywhere in
         the search loop. The other accessors below still answer for it,
         because an existing lock must keep installing — excluded from
         fresh resolution, never from fetch."
        <category: 'accessing'>
        ^((packages at: aName ifAbsent: [^#()])
            reject: [:rec | self isRetired: aName version: (rec at: 1)])
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

    retirementReasonFor: aName version: aVersion [
        "The reason the index owner wrote for retiring this release, or
         nil when it is live (or unknown). Carried so consumers can
         surface it; used by nothing inside resolution — the resolver
         never learns that retirement exists."
        <category: 'accessing'>
        | rec |
        rec := self retirementOf: aName version: aVersion.
        ^rec isNil ifTrue: [nil] ifFalse: [rec at: 2]
    ]

    recordOf: aName version: aVersion [
        "Private — the release record, or nil. Retirement does not enter
         here: a retired release is still fully described, which is what
         lets an existing lock verify and install exactly as before."
        <category: 'private'>
        ^(packages at: aName ifAbsent: [^nil])
            detect: [:rec | (rec at: 1) = aVersion]
            ifNone: [nil]
    ]

    retirementOf: aName version: aVersion [
        "Private — the (version, reason) retirement record, or nil."
        <category: 'private'>
        ^(retirements at: aName ifAbsent: [^nil])
            detect: [:rec | (rec at: 1) = aVersion]
            ifNone: [nil]
    ]

    isRetired: aName version: aVersion [
        "Private — whether this release is excluded from fresh
         resolution."
        <category: 'private'>
        ^(self retirementOf: aName version: aVersion) notNil
    ]
]

Namespace current: Smalltalk.
