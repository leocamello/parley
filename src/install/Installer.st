"Parley — Installer: the strictly post-resolution install pipeline.
 Spec: docs/design/installer.md §1/§4; issue #7 S12-S16.
 Consumes a Resolution — never a manifest, never a snapshot. For each
 (package, version, sha256) triple in sorted package-name order: an
 empty sha256 is a problem (nothing to verify against; no fetch); a
 cache hit skips fetch entirely (the content address is the identity);
 otherwise fetch, verify against the triple's sha256, and store only
 verified bytes (verify-then-store — a mismatch never enters the
 store). Every problem across the whole pass batches into ONE
 InstallError; a clean pass answers an immutable InstalledSet.
 Re-running install: with the same arguments is a no-op: every hash
 already present means zero fetches. The Installer orchestrates
 values; its own I/O happens only through the source and the store."

Namespace current: Parley.

Object subclass: Installer [
    | source store |

    <comment: 'The install orchestrator over two immutably held
collaborators: a PackageSource (fetch:version:) and a ContentStore.
install: runs the Doc D §1 pipeline and answers an InstalledSet on a
clean pass or signals one batched InstallError. Class-side
construction; no public setters.'>

    Installer class >> source: aPackageSource store: aContentStore [
        "Answer an installer fetching from aPackageSource and caching
         into aContentStore."
        <category: 'instance creation'>
        ^self new setSource: aPackageSource store: aContentStore
    ]

    setSource: aPackageSource store: aContentStore [
        "Private — initialization from the class-side constructor."
        <category: 'private'>
        source := aPackageSource.
        store := aContentStore
    ]

    install: aResolution [
        "Run the pipeline over every triple of aResolution in sorted
         package-name order. Answers an InstalledSet on a clean pass;
         signals one InstallError carrying every problem otherwise."
        <category: 'installing'>
        | problems tuples |
        problems := OrderedCollection new.
        tuples := Dictionary new.
        aResolution packageNames do: [:name |
            self install: name
                version: (aResolution versionOf: name)
                sha256: (aResolution sha256Of: name)
                into: tuples
                problems: problems].
        problems isEmpty ifFalse: [InstallError signalProblems: problems].
        ^InstalledSet tuples: tuples
    ]

    install: aName version: aVersion sha256: aSha into: tuples problems: problems [
        "Private — one triple: empty-hash problem, cache-hit skip, or
         fetch/verify/store. Successful packages land in tuples;
         problems accumulate for the batched InstallError."
        <category: 'private'>
        | bytes actual |
        aSha isEmpty ifTrue: [
            problems add: aName, ' ', aVersion printString,
                ': no published archive - the resolution carries an empty sha256'.
            ^self].
        (store containsHash: aSha) ifTrue: [
            ^self record: aName version: aVersion sha256: aSha into: tuples].
        bytes := [source fetch: aName version: aVersion]
            on: SourceError
            do: [:e |
                problems add: aName, ' ', aVersion printString,
                    ': fetch failed - ', e messageText.
                e return: nil].
        bytes isNil ifTrue: [^self].
        actual := Sha256 hexDigestOf: bytes.
        actual = aSha ifFalse: [
            problems add: aName, ' ', aVersion printString,
                ': hash mismatch - expected ', aSha,
                ' but the fetched archive hashes to ', actual.
            ^self].
        store store: bytes.
        self record: aName version: aVersion sha256: aSha into: tuples
    ]

    record: aName version: aVersion sha256: aSha into: tuples [
        "Private — the (name, Version, sha256, store path) tuple of an
         installed package."
        <category: 'private'>
        tuples at: aName put: (Array
            with: aVersion
            with: aSha
            with: (store pathForHash: aSha))
    ]
]

Namespace current: Smalltalk.
