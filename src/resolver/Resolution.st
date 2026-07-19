"Parley — Resolution: the flat (package, version, sha256) success value.
 Spec: docs/design/resolver.md §2, §6; issue #4 S10, S16.
 Immutable; carries the root manifest name so the lockfile writer can
 render #root. Equality and hash ride the root name and the full triple
 set — the value the determinism law (AGENTS.md §7 law 11) compares."

Namespace current: Parley.

Object subclass: Resolution [
    | rootName triples |

    <comment: 'The resolver''s success value: an immutable set of
(package, Version, sha256) triples plus the root manifest name.
isResolution answers true — the polymorphic seam the search loop and
callers branch on instead of exceptions.'>

    Resolution class >> root: aString triples: aDictionary [
        "aDictionary maps a package name to an Array of
         {Version. sha256 String}."
        <category: 'instance creation'>
        ^self new setRoot: aString triples: aDictionary
    ]

    Resolution class >> fromLockEntry: anEntry [
        "Reconstruct a Resolution from a parsed #'parley-lock' 1
         structure (the nested array answered by IndexEntryReader) — the
         lock read-back path, mirroring LibraryManifest fromIndexEntry:.
         Versions re-parse via Version fromString:, so write -> read ->
         fromLockEntry: composes to the identity (issue #5 S8)."
        <category: 'instance creation'>
        | fields triples |
        fields := Dictionary new.
        3 to: anEntry size - 1 by: 2 do: [:i |
            fields at: (anEntry at: i) put: (anEntry at: i + 1)].
        triples := Dictionary new.
        (fields at: #packages) do: [:entry |
            triples at: (entry at: 1) put: (Array
                with: (Version fromString: (entry at: 2))
                with: (entry at: 4))].
        ^self root: (fields at: #root) triples: triples
    ]

    setRoot: aString triples: aDictionary [
        "Private — initialization from the class-side constructor."
        <category: 'private'>
        rootName := aString.
        triples := aDictionary
    ]

    rootName [
        <category: 'accessing'>
        ^rootName
    ]

    isResolution [
        <category: 'testing'>
        ^true
    ]

    packageNames [
        "All resolved package names, sorted by name."
        <category: 'accessing'>
        ^triples keys asSortedCollection asArray
    ]

    versionOf: aName [
        <category: 'accessing'>
        ^(triples at: aName) at: 1
    ]

    sha256Of: aName [
        <category: 'accessing'>
        ^(triples at: aName) at: 2
    ]

    = aResolution [
        <category: 'comparing'>
        (aResolution isKindOf: Resolution) ifFalse: [^false].
        rootName = aResolution rootName ifFalse: [^false].
        self packageNames = aResolution packageNames ifFalse: [^false].
        self packageNames do: [:name |
            (self versionOf: name) = (aResolution versionOf: name)
                ifFalse: [^false].
            (self sha256Of: name) = (aResolution sha256Of: name)
                ifFalse: [^false]].
        ^true
    ]

    hash [
        <category: 'comparing'>
        ^self packageNames inject: rootName hash into: [:acc :name |
            (acc * 31 + (self versionOf: name) hash) * 31
                + (self sha256Of: name) hash]
    ]
]

Namespace current: Smalltalk.
