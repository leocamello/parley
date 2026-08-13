"Parley — LibraryManifest: the immutable manifest value answered by
 ManifestBuilder>>build and reconstructed from parsed index entries.
 Spec: docs/design/manifest-and-serialization.md §4."

Namespace current: Parley.

Object subclass: LibraryManifest [
    | name version summary author license fileIns dependencies
      pathDependencies devDependencies |

    <comment: 'An immutable library manifest: name, Version, optional
summary/author/license (empty strings when unset), fileIns in declared
order (semantic: the gst-package load order), and Dependency objects with
loose constraints. Read-only accessors; class-side construction only.'>

    LibraryManifest class >> name: aName version: aVersion summary: aSummary author: anAuthor license: aLicense fileIns: aFileArray dependencies: aDependencyArray [
        "Answer an immutable manifest carrying the given, already
         validated and parsed, field values.

         THE SETTLED CONSTRUCTOR, UNCHANGED FOR EVERY SETTLED CALLER,
         and it answers a manifest declaring NEITHER root-only kind.
         That is what makes fromIndexEntry: reconstruct neither BY
         CONSTRUCTION rather than by remembering to (Sprint 21, §8
         decision 69): an entry never carries one, so the path that
         rebuilds a manifest from an entry has nothing to pass and no
         opportunity to invent one."
        <category: 'instance creation'>
        ^self
            name: aName
            version: aVersion
            summary: aSummary
            author: anAuthor
            license: aLicense
            fileIns: aFileArray
            dependencies: aDependencyArray
            paths: #()
            dev: #()
    ]

    LibraryManifest class >> name: aName version: aVersion summary: aSummary author: anAuthor license: aLicense fileIns: aFileArray dependencies: aDependencyArray paths: aPathArray dev: aDevArray [
        "The same, plus the two ROOT-MANIFEST-ONLY collections the
         builder fills (Sprint 21, §8 decision 69): PathDependency
         values carrying their authors' declared strings, and ordinary
         Dependency values in a collection of their own.

         BOTH ARE INVISIBLE TO THE ENTRY WRITER, and their living in
         separate collections is the mechanism rather than a filter
         somebody has to remember: the writer reads dependencies, so an
         entry published with and without either is byte-identical."
        <category: 'instance creation'>
        ^self new
            setName: aName
            version: aVersion
            summary: aSummary
            author: anAuthor
            license: aLicense
            fileIns: aFileArray
            dependencies: aDependencyArray
            paths: aPathArray
            dev: aDevArray
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

    setName: aName version: aVersion summary: aSummary author: anAuthor license: aLicense fileIns: aFileArray dependencies: aDependencyArray paths: aPathArray dev: aDevArray [
        "Private — initialization from the class-side constructor."
        <category: 'private'>
        name := aName.
        version := aVersion.
        summary := aSummary.
        author := anAuthor.
        license := aLicense.
        fileIns := aFileArray.
        dependencies := aDependencyArray.
        pathDependencies := aPathArray.
        devDependencies := aDevArray
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

    pathDependencies [
        "The PathDependency values this manifest declares, each carrying
         its author's declared path string (Sprint 21, §8 decision 69).
         Root-manifest-only: never serialized, and empty on every
         manifest rebuilt from an index entry."
        <category: 'accessing'>
        ^pathDependencies
    ]

    devDependencies [
        "The development dependencies this manifest declares, as
         ordinary Dependency values in a collection of their own
         (Sprint 21, §8 decision 69). Resolved and installed for THIS
         manifest alone; never serialized, so a consumer of a published
         package receives none of them."
        <category: 'accessing'>
        ^devDependencies
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
