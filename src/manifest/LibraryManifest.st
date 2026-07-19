"Parley — LibraryManifest: the immutable manifest value answered by
 ManifestBuilder>>build and reconstructed from parsed index entries.
 Spec: docs/design/manifest-and-serialization.md §4."

Namespace current: Parley.

Object subclass: LibraryManifest [
    | name version summary author license fileIns dependencies |

    <comment: 'An immutable library manifest: name, Version, optional
summary/author/license (empty strings when unset), fileIns in declared
order (semantic: the gst-package load order), and Dependency objects with
loose constraints. Read-only accessors; class-side construction only.'>

    LibraryManifest class >> name: aName version: aVersion summary: aSummary author: anAuthor license: aLicense fileIns: aFileArray dependencies: aDependencyArray [
        "Answer an immutable manifest carrying the given, already
         validated and parsed, field values."
        <category: 'instance creation'>
        ^self new
            setName: aName
            version: aVersion
            summary: aSummary
            author: anAuthor
            license: aLicense
            fileIns: aFileArray
            dependencies: aDependencyArray
    ]

    LibraryManifest class >> fromIndexEntry: anEntry [
        "Reconstruct a manifest from a parsed #'parley-index' 1 entry (the
         nested array answered by IndexEntryReader). Constraints re-parse
         through VersionConstraint fromString: into the exact same
         normalized objects the builder produced."
        <category: 'instance creation'>
        | fields deps |
        fields := Dictionary new.
        3 to: anEntry size - 1 by: 2 do: [:i |
            fields at: (anEntry at: i) put: (anEntry at: i + 1)].
        deps := (fields at: #dependencies) collect: [:pair |
            Dependency
                name: (pair at: 1)
                constraint: (VersionConstraint fromString: (pair at: 2))].
        ^self
            name: (fields at: #name)
            version: (Version fromString: (fields at: #version))
            summary: (fields at: #summary)
            author: (fields at: #author)
            license: (fields at: #license)
            fileIns: (fields at: #fileIns)
            dependencies: deps asArray
    ]

    setName: aName version: aVersion summary: aSummary author: anAuthor license: aLicense fileIns: aFileArray dependencies: aDependencyArray [
        "Private — initialization from the class-side constructor."
        <category: 'private'>
        name := aName.
        version := aVersion.
        summary := aSummary.
        author := anAuthor.
        license := aLicense.
        fileIns := aFileArray.
        dependencies := aDependencyArray
    ]

    name [
        <category: 'accessing'>
        ^name
    ]

    version [
        <category: 'accessing'>
        ^version
    ]

    summary [
        <category: 'accessing'>
        ^summary
    ]

    author [
        <category: 'accessing'>
        ^author
    ]

    license [
        <category: 'accessing'>
        ^license
    ]

    fileIns [
        "The declared load order, preserved exactly — never sorted."
        <category: 'accessing'>
        ^fileIns
    ]

    dependencies [
        <category: 'accessing'>
        ^dependencies
    ]

    printOn: aStream [
        <category: 'printing'>
        aStream
            nextPutAll: 'LibraryManifest(';
            nextPutAll: name;
            nextPut: Character space;
            print: version;
            nextPut: $)
    ]
]

Namespace current: Smalltalk.
