"Parley — DirectorySource: the first real package source.
 Spec: docs/design/resolver.md §1/§1.1 (amended); issue #6.
 A directory of index-entry files, each holding exactly one
 #'parley-index' 1 artifact parsed by IndexEntryReader — never the
 compiler. Package identity comes from entry contents, not filenames;
 files are read in sorted-filename order; a release's sha256 comes from
 the entry's #archive field ('' when #archive #()). Problems batch into
 one SourceError in sorted-filename order. snapshot is the source's one
 I/O moment: it answers the sealed immutable IndexSnapshot value that
 resolution consumes; fetch:version: stays an install-time stub until
 the Installer exists (Sprint 5)."

Namespace current: Parley.

Object subclass: DirectorySource [
    | path |

    <comment: 'A package source reading a flat directory of
#''parley-index'' 1 entry files through IndexEntryReader. Holds its
directory path immutably; class-side construction only. Speaks the
PackageSource protocol: snapshot, versionsOf:, manifestFor:version:,
and the fetch:version: install-time stub.'>

    DirectorySource class >> on: aPathString [
        "Answer a source over the directory at aPathString."
        <category: 'instance creation'>
        ^self new setPath: aPathString
    ]

    setPath: aPathString [
        "Private — initialization from the class-side constructor."
        <category: 'private'>
        path := aPathString
    ]

    snapshot [
        "The source's one I/O moment: read every entry file once, in
         sorted-filename order, and answer the sealed immutable
         IndexSnapshot value — or signal one SourceError batching every
         problem the scan found."
        <category: 'source protocol'>
        ^IndexSnapshot releases:
            (self scanEntries collect: [:entry | self releaseFrom: entry])
    ]

    versionsOf: aPackageName [
        "All published Versions of aPackageName, in sorted-filename
         scan order; empty when the package is unknown (the snapshot
         convention)."
        <category: 'source protocol'>
        | versions |
        versions := OrderedCollection new.
        self scanEntries do: [:entry |
            | fields |
            fields := self fieldsOf: entry.
            (fields at: #name) = aPackageName ifTrue: [
                versions add: (Version fromString: (fields at: #version))]].
        ^versions
    ]

    manifestFor: aPackageName version: aVersion [
        "The LibraryManifest reconstructed from the matching entry via
         the settled fromIndexEntry: — the author path and the resolver
         path converge. Answers nil for an unknown (package, version)."
        <category: 'source protocol'>
        self scanEntries do: [:entry |
            | fields |
            fields := self fieldsOf: entry.
            ((fields at: #name) = aPackageName
                and: [(Version fromString: (fields at: #version)) = aVersion])
                ifTrue: [^LibraryManifest fromIndexEntry: entry]].
        ^nil
    ]

    fetch: aPackageName version: aVersion [
        "Archive retrieval is install-time only; the Installer arrives
         in Sprint 5 — until then this path signals."
        <category: 'source protocol'>
        ^self error: 'fetch:version: is install-time only - the Installer does not exist yet'
    ]

    scanEntries [
        "Private — read every .st file in sorted-filename order, one
         #'parley-index' 1 artifact each, batching every problem
         (unparseable, wrong tag, duplicate, missing directory) into
         one SourceError. Answers the parsed entries in scan order."
        <category: 'private'>
        | dir problems seen entries |
        dir := File name: path.
        (dir exists and: [dir isDirectory]) ifFalse: [
            ^SourceError signalProblems:
                (Array with: path, ': missing or unreadable directory')].
        problems := OrderedCollection new.
        seen := Dictionary new.
        entries := OrderedCollection new.
        ((dir files select: [:each | each name endsWith: '.st'])
            asSortedCollection: [:a :b | a stripPath <= b stripPath])
            do: [:each |
                self scan: each into: entries seen: seen problems: problems].
        problems isEmpty ifFalse: [SourceError signalProblems: problems].
        ^entries
    ]

    scan: aFile into: entries seen: seen problems: problems [
        "Private — one file: parse through the literals-only reader,
         check the tag, detect duplicate (name, version) across files;
         a problem is recorded against the file's basename and the file
         contributes no entry."
        <category: 'private'>
        | basename entry fields name version key |
        basename := aFile stripPath.
        entry := [IndexEntryReader readFrom: (ReadStream on: aFile contents)]
            on: IndexEntryParseError, IndexEntryFormatError
            do: [:e |
                problems add: basename, ': ', e messageText.
                e return: nil].
        entry isNil ifTrue: [^self].
        (entry at: 1) = #'parley-index' ifFalse: [
            problems add: basename, ': wrong artifact tag ',
                (entry at: 1) printString,
                ' - a source directory holds only #''parley-index'' 1 entries'.
            ^self].
        fields := self fieldsOf: entry.
        name := fields at: #name.
        version := Version fromString: (fields at: #version).
        key := name, '@', version printString.
        (seen includesKey: key) ifTrue: [
            problems add: basename, ': duplicate entry for ''', name, ''' ',
                version printString,
                ' (already declared in ', (seen at: key), ')'.
            ^self].
        seen at: key put: basename.
        entries add: entry
    ]

    releaseFrom: anEntry [
        "Private — the IndexSnapshot release tuple for one parsed
         entry: {name. Version. sha256 ('' when #archive #()). Array
         of Dependency}."
        <category: 'private'>
        | fields archive deps |
        fields := self fieldsOf: anEntry.
        archive := fields at: #archive.
        deps := (fields at: #dependencies) collect: [:pair |
            Dependency
                name: (pair at: 1)
                constraint: (VersionConstraint fromString: (pair at: 2))].
        ^Array
            with: (fields at: #name)
            with: (Version fromString: (fields at: #version))
            with: (archive isEmpty ifTrue: [''] ifFalse: [archive at: 3])
            with: deps asArray
    ]

    fieldsOf: anEntry [
        "Private — the entry's key-value pairs after the tag and
         version, as a Dictionary (Doc B §5.2 fixed key order)."
        <category: 'private'>
        | fields |
        fields := Dictionary new.
        3 to: anEntry size - 1 by: 2 do: [:i |
            fields at: (anEntry at: i) put: (anEntry at: i + 1)].
        ^fields
    ]
]

Namespace current: Smalltalk.
