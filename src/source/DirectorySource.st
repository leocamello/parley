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

    seededWith: someNames [
        "Answer a source told that someNames matter (§8 decision 51).
         A source that reads its whole index genuinely has nothing to
         do with the information — self is the honest answer, not a
         stub — and answering it is what lets every call site send the
         message unconditionally, with no kind-branching."
        <category: 'source protocol'>
        ^self
    ]

    snapshot [
        "The source's one I/O moment: read every artifact file once, in
         sorted-filename order, and answer the sealed immutable
         IndexSnapshot value — or signal one SourceError batching every
         problem the scan found.

         From Sprint 10 the index holds two kinds of artifact (Doc F
         §4.2): release entries and retirement records. Both are read
         here and handed to the snapshot, which is where retirement
         takes effect (Doc C §2.1); the scan makes no resolution
         decision of its own."
        <category: 'source protocol'>
        | scanned |
        scanned := self scanArtifacts.
        ^IndexSnapshot
            releases: ((scanned at: 1)
                collect: [:entry | self releaseFrom: entry])
            retirements: (scanned at: 2)
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
                    file := path, '/', (archive at: 1).
                    (PathGuard isReadableFile: file) ifFalse: [
                        ^SourceError signalProblems: (Array with:
                            (archive at: 1), ': missing or unreadable archive file')].
                    ^PathGuard contentsOf: file
                        ifRefused: [:each |
                            SourceError signalProblems: (Array with:
                                (archive at: 1), ': missing or unreadable archive file')]]].
        ^SourceError signalProblems: (Array with:
            aPackageName, ' ', aVersion printString,
            ': unknown (package, version) - the source directory declares no entry for it')
    ]

    scanEntries [
        "Private — the release entries of the scan, in sorted-filename
         order. The scan's other half is the retirement records; every
         caller here (versionsOf:, manifestFor:version:, fetch:version:)
         asks about published releases and nothing else."
        <category: 'private'>
        ^self scanArtifacts at: 1
    ]

    scanArtifacts [
        "Private — read every .st file in sorted-filename order, one
         artifact each, dispatch on the tag the reader already
         validated, and batch every problem (unparseable, wrong tag,
         malformed entry, malformed retirement record, duplicate,
         missing directory) into one SourceError. Answers
         {entries. retirement tuples}, both in scan order."
        <category: 'private'>
        | problems seen entries retired |
        (PathGuard isReadableDirectory: path) ifFalse: [
            ^SourceError signalProblems:
                (Array with: path, ': missing or unreadable directory')].
        problems := OrderedCollection new.
        seen := Dictionary new.
        entries := OrderedCollection new.
        retired := OrderedCollection new.
        (((PathGuard filePathsIn: path
            ifRefused: [:each |
                SourceError signalProblems:
                    (Array with: path, ': missing or unreadable directory')])
                select: [:each | each endsWith: '.st'])
            asSortedCollection: [:a :b |
                (PathGuard baseNameOf: a) <= (PathGuard baseNameOf: b)])
            do: [:each |
                self scan: each into: entries retiring: retired
                    seen: seen problems: problems].
        problems isEmpty ifFalse: [SourceError signalProblems: problems].
        ^Array with: entries with: retired
    ]

    "---- §4.2 tag dispatch (Doc F, Sprint 10) ----"

    artifactHandlers [
        "Private — the artifact table: each row is a format tag, the
         message that takes such an artifact in, and the noun a
         diagnosis calls it by.

         A dispatch on a VALUE THE READER ALREADY VALIDATED — the shape
         the index/lock split has used since Sprint 2 — never an
         isKindOf: chain. Contents decide, never the filename (Doc C §1,
         Sprint 4): an index owner may name and split these files
         however they like.

         It is a DECLARATION consumed twice: the dispatch looks a tag up
         in it, and the wrong-tag diagnosis is RENDERED from it, so what
         a source directory accepts and what its diagnosis says it
         accepts cannot drift apart."
        <category: 'private-dispatch'>
        ^Array
            with: (Array with: #'parley-index'
                with: #takeEntry:named:into:retiring:seen:problems:
                with: 'entries')
            with: (Array with: #'parley-retired'
                with: #takeRetirements:named:into:retiring:seen:problems:
                with: 'records')
    ]

    handlerFor: aTag [
        "Private — the row for a tag, or nil when a source directory
         does not hold that artifact at all."
        <category: 'private-dispatch'>
        ^self artifactHandlers
            detect: [:row | (row at: 1) = aTag]
            ifNone: [nil]
    ]

    artifactVocabularyText [
        "Private — what a source directory holds, rendered from the
         table: '#''parley-index'' 1 entries and #''parley-retired'' 1
         records'. The diagnosis it feeds used to say a source directory
         holds ONLY entries, which this sprint made false — and a
         diagnosis that misstates what is allowed sends an operator to
         delete a file that belongs there (Sprint 10 RED review)."
        <category: 'private-dispatch'>
        | out rows |
        rows := self artifactHandlers.
        out := WriteStream on: String new.
        1 to: rows size do: [:i |
            i = 1 ifFalse: [
                out nextPutAll: (i = rows size
                    ifTrue: [' and ']
                    ifFalse: [', '])].
            out nextPutAll: ((rows at: i) at: 1) printString;
                nextPutAll: ' 1 ';
                nextPutAll: ((rows at: i) at: 3)].
        ^out contents
    ]

    scan: aPath into: entries retiring: retired seen: seen problems: problems [
        "Private — one file: parse through the literals-only reader,
         then hand the artifact to the handler its tag selects. A
         problem is recorded against the file's basename and the file
         contributes nothing.

         READABILITY IS A SCAN PROBLEM LIKE ANY OTHER (§8 decision 56's
         own domain, applied at last — Sprint 17). An entry file the
         reader lacks permission to open EXISTS, so the enumeration
         above hands it here and File>>contents died on it: exit 70,
         blaming Parley for somebody else's index. It batches now, in
         this class's settled voice and beside the archive sentence it
         has always carried."
        <category: 'private'>
        | basename artifact row |
        basename := PathGuard baseNameOf: aPath.
        artifact := [IndexEntryReader readFrom: (ReadStream on:
                (PathGuard contentsOf: aPath
                    ifRefused: [:each |
                        problems add: basename, ': missing or unreadable entry file'.
                        ^self]))]
            on: IndexEntryParseError, IndexEntryFormatError
            do: [:e |
                problems add: basename, ': ', e messageText.
                e return: nil].
        artifact isNil ifTrue: [^self].
        row := self handlerFor: (artifact at: 1).
        row isNil ifTrue: [
            problems add: basename, ': wrong artifact tag ',
                (artifact at: 1) printString,
                ' - a source directory holds ', self artifactVocabularyText.
            ^self].
        "3.2.5's Array class >> with: stops at five arguments, so the
         sixth is concatenated rather than passed."
        ^self
            perform: (row at: 2)
            withArguments: ((Array
                with: artifact with: basename with: entries
                with: retired with: seen), (Array with: problems))
    ]

    takeEntry: entry named: basename into: entries retiring: retired seen: seen problems: problems [
        "Private — one #'parley-index' 1 release entry: the §5.2 schema
         shape, then the §4.1 values, then duplicate (name, version)
         detection across files. Unchanged by Sprint 10 except that the
         tag test above now selects it."
        <category: 'private'>
        | shape value fields name version key |
        shape := self schemaProblemIn: entry.
        shape notNil ifTrue: [
            problems add: basename, ': ', shape.
            ^self].
        value := self valueProblemIn: entry.
        value notNil ifTrue: [
            problems add: basename, ': ', value.
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

    takeRetirements: record named: basename into: entries retiring: retired seen: seen problems: problems [
        "Private — one #'parley-retired' 1 record (Doc B §5.5): its own
         shape validation, exactly as an entry has, then every triple
         becomes a snapshot retirement tuple {name. Version. reason}.

         A retirement naming a release the index does not hold is
         accepted silently: an index owner may retire ahead of a
         deletion, and the snapshot simply never matches it."
        <category: 'private'>
        | problem |
        problem := self retirementProblemIn: record.
        problem notNil ifTrue: [
            problems add: basename, ': ', problem.
            ^self].
        ((self fieldsOf: record) at: #retirements) do: [:triple |
            retired add: (Array
                with: (triple at: 1)
                with: (Version fromString: (triple at: 2))
                with: (triple at: 3))]
    ]

    "---- §5.5 retirement-record validation (Doc F §4.2) ----"

    retirementKeys [
        "Private — the Doc B §5.5 keys. One key, always present."
        <category: 'private-retirement'>
        ^#(#retirements)
    ]

    retirementKeyText [
        "Private — the record's schema vocabulary rendered for a
         problem, derived from retirementKeys so the two cannot drift."
        <category: 'private-retirement'>
        ^'the only key of a retirement record is ',
            (self retirementKeys at: 1) printString
    ]

    retirementProblemIn: aRecord [
        "Private — the first §5.5 defect of a tag-valid retirement
         record, as the descriptive tail of one problem, or nil when the
         record is well formed. One problem per file, as everywhere in
         the scan: a malformed record is a diagnosis, not a crash.

         Shape first, then values — the Doc F §4.1 lesson, that a shape
         check never asks whether a string MEANS anything. The settled
         Version fromString: is consulted, never re-implemented."
        <category: 'private-retirement'>
        | keys triples |
        aRecord size odd ifTrue: [
            ^'malformed retirement record - the schema keys and values do not pair up'].
        keys := OrderedCollection new.
        3 to: aRecord size - 1 by: 2 do: [:i | keys add: (aRecord at: i)].
        self retirementKeys do: [:key |
            (keys includes: key) ifFalse: [
                ^'missing schema key ', key printString, ' - ',
                    self retirementKeyText]].
        keys do: [:key |
            (self retirementKeys includes: key) ifFalse: [
                ^'unknown schema key ', key printString, ' - ',
                    self retirementKeyText]].
        triples := (self fieldsOf: aRecord) at: #retirements.
        (self isRetirementTriples: triples) ifFalse: [
            ^'#retirements must be an array of #(<name> <version> <reason>) string triples'].
        triples do: [:triple |
            (self parses: [Version fromString: (triple at: 2)])
                ifFalse: [
                    ^'#retirements version ', (triple at: 2) printString,
                        ' for ', (triple at: 1) printString,
                        ' does not parse as a version']].
        ^nil
    ]

    isRetirementTriples: aValue [
        "Private — an array of three-element #(name version reason)
         String triples."
        <category: 'private-retirement'>
        (aValue isKindOf: Array) ifFalse: [^false].
        aValue do: [:triple |
            ((triple isKindOf: Array) and: [triple size = 3])
                ifFalse: [^false].
            (SchemaShape isStringArray: triple) ifFalse: [^false]].
        ^true
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
            (SchemaShape isString: (fields at: key)) ifFalse: [
                ^key printString, ' must be a string']].
        (SchemaShape isStringArray: (fields at: #fileIns)) ifFalse: [
            ^'#fileIns must be an array of strings'].
        (self isSchemaDependencies: (fields at: #dependencies)) ifFalse: [
            ^'#dependencies must be an array of #(name constraint) string pairs'].
        (self isSchemaArchive: (fields at: #archive)) ifFalse: [
            ^'#archive must be #() or #(<filename> #sha256 <hex digest>)'].
        ^nil
    ]

    isSchemaDependencies: aValue [
        "Private — an array of #(name constraint) string pairs."
        <category: 'private-schema'>
        (aValue isKindOf: Array) ifFalse: [^false].
        aValue do: [:pair |
            ((pair isKindOf: Array) and: [pair size = 2]) ifFalse: [^false].
            (SchemaShape isStringArray: pair) ifFalse: [^false]].
        ^true
    ]

    "---- §4.1 value-shape validation (Doc F §4.1, Sprint 8) ----"

    valueProblemIn: anEntry [
        "Private — the first §4.1 value defect of an entry already
         known to have the §4 schema shape, as the descriptive tail of
         one problem, or nil when every value parses. Shape validation
         asks whether a field is a string; it never asked whether the
         string MEANS anything, and a #version 'banana' was the last
         way a malformed entry could crash instead of diagnose.

         Runs BEFORE duplicate detection, which needs a parsed version
         to compare. One problem per file, as everywhere in the scan."
        <category: 'private-values'>
        | fields |
        fields := self fieldsOf: anEntry.
        (self parses: [Version fromString: (fields at: #version)])
            ifFalse: [
                ^'#version ', (fields at: #version) printString,
                    ' does not parse as a version'].
        (fields at: #dependencies) do: [:pair |
            (self parses: [VersionConstraint fromString: (pair at: 2)])
                ifFalse: [
                    ^'#dependencies constraint ', (pair at: 2) printString,
                        ' for ', (pair at: 1) printString,
                        ' does not parse as a version constraint']].
        ^self archiveDigestProblemIn: (fields at: #archive)
    ]

    archiveDigestProblemIn: anArchiveValue [
        "Private — the digest defect of a shape-valid #archive value,
         or nil. A declared archive carries a digest that is exactly
         64 lowercase hex characters — what the settled Sha256 renders
         (Doc F §4; §8 decision 42). Shape only, never truth: whether
         the digest matches any bytes stays the installer's
         verifyHash:. #() carries no digest string at all, so absence
         needs no exemption here."
        <category: 'private-values'>
        anArchiveValue isEmpty ifTrue: [^nil].
        (SchemaShape isHexDigest: (anArchiveValue at: 3)) ifTrue: [^nil].
        ^'#archive digest ', (anArchiveValue at: 3) printString,
            ' must be 64 lowercase hex characters'
    ]

    parses: aBlock [
        "Private — whether the SETTLED parser aBlock consults accepts
         its input. Validation asks the parsers and never re-implements
         them: they stay the single definition of what parses, and this
         answers only whether they said yes."
        <category: 'private-values'>
        ^[aBlock value. true]
            on: VersionFormatError, ConstraintFormatError
            do: [:e | e return: false]
    ]

    isSchemaArchive: aValue [
        "Private — either #() or the #(<filename> #sha256 <hex>) triple."
        <category: 'private-schema'>
        (aValue isKindOf: Array) ifFalse: [^false].
        aValue isEmpty ifTrue: [^true].
        aValue size = 3 ifFalse: [^false].
        (SchemaShape isString: (aValue at: 1)) ifFalse: [^false].
        (aValue at: 2) == #sha256 ifFalse: [^false].
        ^SchemaShape isString: (aValue at: 3)
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
