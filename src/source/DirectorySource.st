"Parley — DirectorySource: the first real package source.
 Spec: docs/design/resolver.md §1/§1.1 (amended); issue #6.
 Sprint 7 (issue #9, Doc F §4 — the one declared exception on this
 settled class): the scan gains §5.2 schema-shape validation, closing
 the Sprint 4 ruled gap. A literal-valid, tag-valid entry that is not
 schema-shaped is now ONE batched problem naming the file and the
 defect, not a raw error — a malformed entry is a diagnosis, and
 directory sources stop being operator-curated. The reader stays a
 pure literals-only parser; validation belongs to the scan.
 A directory of index-entry files, each holding exactly one
 #'parley-index' 1 artifact parsed by IndexEntryReader — never the
 compiler. Package identity comes from entry contents, not filenames;
 files are read in sorted-filename order; a release's sha256 comes from
 the entry's #archive field ('' when #archive #()). Problems batch into
 one SourceError in sorted-filename order. snapshot is the source's one
 I/O moment: it answers the sealed immutable IndexSnapshot value that
 resolution consumes; fetch:version: answers archive bytes at install
 time per Doc D §1.1 (the Sprint 4 stub, superseded at Sprint 5)."

Namespace current: Parley.

Object subclass: DirectorySource [
    | path |

    <comment: 'A package source reading a flat directory of
#''parley-index'' 1 entry files through IndexEntryReader. Holds its
directory path immutably; class-side construction only. Speaks the
PackageSource protocol: snapshot, versionsOf:, manifestFor:version:,
and the install-time fetch:version: of Doc D §1.1.'>

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
        "Answer the complete raw bytes of the archive file named by
         the matching entry's #archive field, resolved relative to the
         source directory (Doc D §1.1). Problems — unknown (package,
         version), #archive #(), missing archive file — each signal a
         one-problem SourceError."
        <category: 'source protocol'>
        self scanEntries do: [:entry |
            | fields archive file |
            fields := self fieldsOf: entry.
            ((fields at: #name) = aPackageName
                and: [(Version fromString: (fields at: #version)) = aVersion])
                ifTrue: [
                    archive := fields at: #archive.
                    archive isEmpty ifTrue: [
                        ^SourceError signalProblems: (Array with:
                            aPackageName, ' ', aVersion printString,
                            ': no published archive - the entry declares #archive #()')].
                    file := File name: path, '/', (archive at: 1).
                    file exists ifFalse: [
                        ^SourceError signalProblems: (Array with:
                            (archive at: 1), ': missing or unreadable archive file')].
                    ^file contents]].
        ^SourceError signalProblems: (Array with:
            aPackageName, ' ', aVersion printString,
            ': unknown (package, version) - the source directory declares no entry for it')
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
         check the tag, check the §5.2 schema shape, detect duplicate
         (name, version) across files; a problem is recorded against
         the file's basename and the file contributes no entry."
        <category: 'private'>
        | basename entry shape fields name version key |
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
        shape := self schemaProblemIn: entry.
        shape notNil ifTrue: [
            problems add: basename, ': ', shape.
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

    "---- §5.2 schema-shape validation (Doc F §4) ----"

    schemaKeys [
        "Private — the Doc B §5.2 keys, in the fixed order the schema
         defines. All present, always, in exactly this sequence."
        <category: 'private-schema'>
        ^#(#name #version #summary #author #license #fileIns #dependencies #archive)
    ]

    schemaKeyOrderText [
        "Private — the fixed key order rendered for a problem, derived
         from schemaKeys so the two can never drift apart."
        <category: 'private-schema'>
        | out |
        out := WriteStream on: String new.
        self schemaKeys
            do: [:each | out nextPutAll: each printString]
            separatedBy: [out nextPut: Character space].
        ^out contents
    ]

    schemaProblemIn: anEntry [
        "Private — the first §5.2 shape defect of a tag-valid entry, as
         the descriptive tail of one problem, or nil when the entry has
         the schema shape. One problem per file: a malformed entry is a
         diagnosis, and one diagnosis per file is what the operator
         acts on."
        <category: 'private-schema'>
        | keys |
        anEntry size odd ifTrue: [
            ^'malformed entry - the schema keys and values do not pair up'].
        keys := OrderedCollection new.
        3 to: anEntry size - 1 by: 2 do: [:i | keys add: (anEntry at: i)].
        self schemaKeys do: [:key |
            (keys includes: key) ifFalse: [
                ^'missing schema key ', key printString,
                    ' - the fixed key order is ', self schemaKeyOrderText]].
        keys do: [:key |
            (self schemaKeys includes: key) ifFalse: [
                ^'unknown schema key ', key printString,
                    ' - the fixed key order is ', self schemaKeyOrderText]].
        keys asArray = self schemaKeys ifFalse: [
            ^'schema keys out of order - the fixed key order is ',
                self schemaKeyOrderText].
        ^self schemaKindProblemIn: anEntry
    ]

    schemaKindProblemIn: anEntry [
        "Private — the first schema-kind defect among the values of an
         entry whose keys are already known to be the eight, in order."
        <category: 'private-schema'>
        | fields |
        fields := self fieldsOf: anEntry.
        #(#name #version #summary #author #license) do: [:key |
            (self isSchemaString: (fields at: key)) ifFalse: [
                ^key printString, ' must be a string']].
        (self isSchemaStringArray: (fields at: #fileIns)) ifFalse: [
            ^'#fileIns must be an array of strings'].
        (self isSchemaDependencies: (fields at: #dependencies)) ifFalse: [
            ^'#dependencies must be an array of #(name constraint) string pairs'].
        (self isSchemaArchive: (fields at: #archive)) ifFalse: [
            ^'#archive must be #() or #(<filename> #sha256 <hex digest>)'].
        ^nil
    ]

    isSchemaString: aValue [
        "Private — a schema string is a String and NOT a Symbol (in
         3.2.5 Symbol is a String subclass, and the two are distinct
         literals in the micro-format grammar)."
        <category: 'private-schema'>
        ^aValue isString and: [aValue isSymbol not]
    ]

    isSchemaStringArray: aValue [
        <category: 'private-schema'>
        (aValue isKindOf: Array) ifFalse: [^false].
        aValue do: [:each |
            (self isSchemaString: each) ifFalse: [^false]].
        ^true
    ]

    isSchemaDependencies: aValue [
        "Private — an array of #(name constraint) string pairs."
        <category: 'private-schema'>
        (aValue isKindOf: Array) ifFalse: [^false].
        aValue do: [:pair |
            ((pair isKindOf: Array) and: [pair size = 2]) ifFalse: [^false].
            (self isSchemaStringArray: pair) ifFalse: [^false]].
        ^true
    ]

    isSchemaArchive: aValue [
        "Private — either #() or the #(<filename> #sha256 <hex>) triple."
        <category: 'private-schema'>
        (aValue isKindOf: Array) ifFalse: [^false].
        aValue isEmpty ifTrue: [^true].
        aValue size = 3 ifFalse: [^false].
        (self isSchemaString: (aValue at: 1)) ifFalse: [^false].
        (aValue at: 2) == #sha256 ifFalse: [^false].
        ^self isSchemaString: (aValue at: 3)
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
