"Parley — IndexSnapshot: the concrete immutable receiver for the
 resolver's snapshot value.
 Spec: docs/design/resolver.md §2; issue #4 (approved addition).
 Hand-buildable from release tuples; answers versionsOf:,
 dependenciesOf:version: (pre-parsed Dependency values) and
 sha256For:version: ('' when absent). Built once before resolution
 begins — the resolver performs zero live I/O against it.

 IT ANSWERS TWO FURTHER ENUMERATIONS FOR THE REPORTING VERBS, and both
 are purely additive (Sprint 20, Doc C §2): packageNames, sorted, and
 allVersionsOf:, which keeps retired releases and bypasses the held
 map. No existing selector changes behaviour and the Resolver calls
 neither — they exist for verbs that read and explain, and a snapshot
 whose two reporting accessors SIGNAL still resolves, which is how the
 laws prove it rather than by reading the search loop.

 The distinction between allVersionsOf: and versionsOf: is deliberate
 and load-bearing: versionsOf: answers what a fresh resolution may
 PICK, allVersionsOf: answers what the index PUBLISHED, and collapsing
 the two would either leak retirement into the search loop or report
 this project's own pin as the index's newest release."

Namespace current: Parley.

Object subclass: IndexSnapshot [
    | packages retirements held |

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
                    with: (tuple at: 3))].
        held := Dictionary new
    ]

    holding: aDictionary [
        "Answer a NEW snapshot narrowed to offer, for every name in
         aDictionary (name -> Version), exactly the held version — the
         Doc C §2.2 derivation behind parley update <pkg>. The receiver
         is not mutated: like every domain operation, this answers a
         new instance (Architecture §1.5), sharing the immutable
         release and retirement records.

         The narrowing lives here and nowhere else: the resolver
         selects only from what versionsOf: offers, so a selective
         update is a normal resolution of a smaller world — no strategy
         or ledger change, which is what hands a future PubGrubStrategy
         selective update for free (§8 decision 46).

         A held pin outranks a retirement (§8 decision 46): a retired
         held version is offered anyway, because the §2.1 filter
         answers what a FRESH resolution may pick and a held pin is
         being kept, not picked. But narrowing can only offer what the
         snapshot can DESCRIBE (§8 decision 47): a held version this
         snapshot holds no record for is offered as nothing at all,
         because offering it would let update write a lock tuple with
         an empty digest — manufactured corruption. The describing
         accessors are untouched either way: an existing lock must
         keep verifying and installing exactly as before."
        <category: 'narrowing'>
        ^self class new
            setPackages: packages
            retirements: retirements
            held: aDictionary
    ]

    setPackages: aPackagesDictionary retirements: aRetirementsDictionary held: aHeldDictionary [
        "Private — initialization of a narrowed derivation from
         holding:. The built record dictionaries are shared (nothing
         ever mutates them); the held map is copied so a caller
         mutating its argument afterwards cannot reach inside."
        <category: 'private'>
        packages := aPackagesDictionary.
        retirements := aRetirementsDictionary.
        held := aHeldDictionary copy
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
         fresh resolution, never from fetch.

         A HELD NAME IS OFFERED AS EXACTLY ITS HELD VERSION (Doc C
         §2.2) — bypassing the retirement filter (held beats retired,
         §8 decision 46) but bounded by describability (§8 decision
         47): a held version with no release record here is offered as
         nothing. The filter lives in this accessor and never in the
         search loop."
        <category: 'accessing'>
        (held includesKey: aName) ifTrue: [
            ^(self recordOf: aName version: (held at: aName)) isNil
                ifTrue: [#()]
                ifFalse: [Array with: (held at: aName)]].
        ^((packages at: aName ifAbsent: [^#()])
            reject: [:rec | self isRetired: aName version: (rec at: 1)])
                collect: [:rec | rec at: 1]
    ]

    packageNames [
        "Every package name this snapshot holds, SORTED — the
         enumeration the reporting verbs need and the one nothing
         previously offered (Doc C §2, Sprint 20).

         PURELY ADDITIVE, and the addition is an accessor on the
         snapshot rather than a new PackageSource selector: a snapshot
         is a value every source already answers, and growing the
         protocol would change three settled sources for a question
         none of them needs to be asked.

         Sorted because the answer is RENDERED. A rendering that varied
         with dictionary order would not be byte-stable, which is the
         property every other answer this tool composes already has.

         THE RESOLVER CALLS THIS NEVER. It exists for verbs that read
         and explain (§8 decision 40), and the purity contract above is
         untouched: nothing here is reachable from the search loop."
        <category: 'reporting'>
        ^(packages keys asSortedCollection: [:a :b | a <= b]) asArray
    ]

    allVersionsOf: aName [
        "Every version of aName this snapshot holds, RETIRED ONES
         INCLUDED, sorted ascending; empty when unknown.

         DELIBERATELY DISTINCT FROM versionsOf:, and the distinction is
         the point rather than an inconvenience. versionsOf: answers
         what a FRESH RESOLUTION MAY PICK: it excludes retired releases
         (§2.1) and it collapses a HELD name to exactly its held version
         (§2.2). Both are right for resolution and wrong for a report —
         a verb built on versionsOf: would tell an operator that their
         own pin is the newest release the index carries, which is a
         confident wrong answer about somebody else's index.

         So this accessor answers what the index PUBLISHED: the held map
         is bypassed and the retirement filter is not applied here.
         Retirement is still reported, by the settled
         retirementReasonFor:version: beside it — what an index
         published and what it still recommends are two facts, and the
         caller renders both rather than being handed one.

         THE RESOLVER CALLS THIS NEVER, for the same reason as above."
        <category: 'reporting'>
        ^((packages at: aName ifAbsent: [^#()])
            collect: [:rec | rec at: 1])
                asSortedCollection asArray
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
