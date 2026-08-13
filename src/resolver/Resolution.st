"Parley — Resolution: the flat (package, version, sha256) success value.
 Spec: docs/design/resolver.md §2, §6; issue #4 S10, S16.
 Immutable; carries the root manifest name so the lockfile writer can
 render #root. Equality and hash ride the root name and the full triple
 set — the value the determinism law (AGENTS.md §7 law 11) compares."

Namespace current: Parley.

Object subclass: Resolution [
    | rootName triples paths |

    <comment: 'The resolver''s success value: an immutable set of
(package, Version, sha256) triples plus the root manifest name.
isResolution answers true — the polymorphic seam the search loop and
callers branch on instead of exceptions.'>

    Resolution class >> root: aString triples: aDictionary [
        "aDictionary maps a package name to an Array of
         {Version. sha256 String}.

         THE STRATEGIES BUILD THIS FORM AND KNOW NOTHING ABOUT PATHS,
         which is why provenance arrives by withPaths: afterwards rather
         than through a widened constructor: Resolver, both strategies
         and ConstraintLedger are instruments this sprint does not
         touch (§8 decision 40)."
        <category: 'instance creation'>
        ^self new setRoot: aString triples: aDictionary paths: Dictionary new
    ]

    Resolution class >> fromLockEntry: anEntry [
        "Reconstruct a Resolution from a parsed #'parley-lock' 1
         structure (the nested array answered by IndexEntryReader) — the
         lock read-back path, mirroring LibraryManifest fromIndexEntry:.
         Versions re-parse via Version fromString:, so write -> read ->
         fromLockEntry: composes to the identity (issue #5 S8)."
        <category: 'instance creation'>
        | fields triples paths |
        fields := Dictionary new.
        3 to: anEntry size - 1 by: 2 do: [:i |
            fields at: (anEntry at: i) put: (anEntry at: i + 1)].
        triples := Dictionary new.
        paths := Dictionary new.
        (fields at: #packages) do: [:entry |
            "THE TUPLE HAS TWO DECLARED FORMS AND THE THIRD ELEMENT
             SAYS WHICH (Doc B §5.3, Sprint 21): #sha256 carries a
             digest, #path carries the author's declared directory
             string. A pin no index supplied has no digest to record —
             it is described by its PROVENANCE — so the two are read
             apart here and the empty digest keeps meaning what it
             always meant: an index release that published no archive
             (§8 decisions 25 and 69)."
            (entry at: 3) == #path
                ifTrue: [
                    triples at: (entry at: 1) put: (Array
                        with: (Version fromString: (entry at: 2))
                        with: '').
                    paths at: (entry at: 1) put: (entry at: 4)]
                ifFalse: [
                    triples at: (entry at: 1) put: (Array
                        with: (Version fromString: (entry at: 2))
                        with: (entry at: 4))]].
        ^(self root: (fields at: #root) triples: triples) withPaths: paths
    ]

    setRoot: aString triples: aDictionary paths: aPathDictionary [
        "Private — initialization from the class-side constructor."
        <category: 'private'>
        rootName := aString.
        triples := aDictionary.
        paths := aPathDictionary
    ]

    withPaths: aDictionary [
        "Answer a NEW resolution recording, for each name aDictionary
         maps, the DECLARED path string that supplied it (Doc B §5.3,
         §8 decision 69). The receiver is unchanged: an operation
         answers a new instance, exactly as holding: does one layer
         down.

         Only names this resolution actually carries are recorded, so a
         caller may hand over a whole snapshot's provenance map without
         first intersecting it — and a resolution that selected none of
         them renders bytes identical to what Sprint 20 wrote.

         The lock is written from THIS value and never from the CLI's
         composed resolution view: the view is internal wiring with one
         consumer, and provenance is a property of what was resolved."
        <category: 'provenance'>
        | kept |
        kept := Dictionary new.
        aDictionary keysAndValuesDo: [:name :declared |
            (triples includesKey: name)
                ifTrue: [kept at: name put: declared]].
        ^self class new setRoot: rootName triples: triples paths: kept
    ]

    provenanceOf: aName [
        "The declared path string that supplied aName, or nil when the
         index did. The writer asks this to choose between the two
         declared tuple forms, and why asks it to name the directory."
        <category: 'provenance'>
        ^paths at: aName ifAbsent: [nil]
    ]

    pathNames [
        "Every name a directory supplied, sorted — the pins install must
         not touch and the reporting verbs answer differently."
        <category: 'provenance'>
        ^(paths keys asSortedCollection: [:a :b | a <= b]) asArray
    ]

    pathFreeView [
        "Answer this resolution with every path-supplied pin removed —
         the value the CLI hands the Installer (§8 decision 69).

         A #path pin is no-fetch, no-store, no-register, and this view
         is HOW that is true rather than a branch inside the pipeline:
         Installer, InstalledSet and ContentStore never learn that paths
         exist, and §8 decision 25's empty-sha256 diagnosis keeps
         governing exactly the index pins it was written about. The two
         states answer differently because they are different — '' is an
         index release that published no archive, #path is a pin no
         index supplied.

         A resolution with no path pins answers an equal value, so the
         CLI sends this unconditionally and no caller asks whether paths
         are involved."
        <category: 'provenance'>
        | kept |
        paths isEmpty ifTrue: [^self].
        kept := Dictionary new.
        triples keysAndValuesDo: [:name :triple |
            (paths includesKey: name)
                ifFalse: [kept at: name put: triple]].
        ^self class new setRoot: rootName triples: kept paths: Dictionary new
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
