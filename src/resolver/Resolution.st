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
