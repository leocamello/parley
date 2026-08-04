"Parley — SparseIndexSource: the sparse-index client (Doc F §7;
 issue #16; §8 decisions 50 and 51). A registry-shaped index serves
 one listing and one entry file per package over a base URL; a client
 fetches the packages a resolution can reach and nothing else.

 Pure composition — the GitIndexSource shape applied a second time:
 the source holds an inner DirectorySource over the cache's entries
 directory and adds exactly ONE transport moment, at snapshot. That
 moment is a CLOSURE, never a callback (decision 50): snapshot walks
 the seed names to fixpoint — each reachable package's listing, the
 entries it names, the names those entries declare, repeat — then
 answers the inner source's sealed immutable IndexSnapshot. The
 resolver and the snapshot never learn about fetching.

 The seeds arrive as VALUES through seededWith: (decision 51): the
 CLI supplies them, because this source must never read Package.st or
 parley.lock. seededWith: performs no I/O and answers a NEW instance;
 the receiver is unchanged.

 The transport is curl through the one process seam, its grounds
 declared closed: 0 is a hit, 37 and 22 are a miss, anything else is
 one SourceError naming the exact command line and exit code — the
 GitIndexSource transport-failure precedent verbatim. A missing
 LISTING is decision 47's ordinary undescribed name; a missing ENTRY
 that a listing names is an index defect — one problem naming both
 files (Doc F §7.3 rules them different).

 Cache layout: fetched listings live in <cache>/listings/, BESIDE the
 flat <cache>/entries/ directory the inner DirectorySource scans —
 never in it. A listing is the one mutable artifact (a publish
 appends), so it is re-fetched every snapshot; a release is
 immutable, so a cached entry or archive is never fetched again.

 versionsOf: and manifestFor:version: are pure delegation and run no
 process. fetch:version: fetches the archive into the entries
 directory once — a cache hit spawns nothing — then delegates to the
 inner source, so the settled hash verification sees exactly the
 fetched bytes.

 No value equality (=/hash) — the decision-23 precedent."

Namespace current: Parley.

Object subclass: SparseIndexSource [
    | base cache runner inner seeds |

    <comment: 'A PackageSource over a sparse index: the base URL, the
local cache directory, the one process seam and the seed names, all
held immutably, plus the inner DirectorySource over the cache''s
entries directory that it delegates every non-transport message to.
Construction is pathname-passive — nothing is fetched, read or
spawned until snapshot. Class-side construction; zero public
setters.'>

    SparseIndexSource class >> base: aBaseUrl cache: aCacheDir runner: aProcessRunner [
        "Answer a source over the sparse index at aBaseUrl, caching
         into aCacheDir, spawning only through aProcessRunner.
         Pathname-passive: neither location is touched here. The
         answered source holds NO seeds — its snapshot closes over
         nothing until seededWith: supplies the names that matter."
        <category: 'instance creation'>
        ^self new
            setBase: aBaseUrl cache: aCacheDir runner: aProcessRunner
            seeds: Set new
    ]

    setBase: aBaseUrl cache: aCacheDir runner: aProcessRunner seeds: aSet [
        "Private — initialization from the class-side constructor and
         from seededWith:. The inner source is built here and held
         immutably: DirectorySource construction touches no disk, so
         this stays pathname-passive."
        <category: 'private'>
        base := aBaseUrl.
        cache := aCacheDir.
        runner := aProcessRunner.
        seeds := aSet.
        inner := DirectorySource on: self entriesDir
    ]

    seededWith: someNames [
        "Answer a NEW source told that someNames matter — the
         decision-51 protocol message. The seeds are values: no I/O
         happens here, and the receiver is unchanged, still holding
         ITS seeds. The answered instance shares the base, the cache
         and the runner, and holds the union of both seed sets."
        <category: 'source protocol'>
        | union |
        union := Set new.
        seeds do: [:each | union add: each].
        someNames do: [:each | union add: each].
        ^self class new
            setBase: base cache: cache runner: runner
            seeds: union
    ]

    snapshot [
        "The source's one I/O moment, transport included: walk the
         decision-50 closure over the seeds to fixpoint, then answer
         the inner source's sealed immutable IndexSnapshot. Every
         problem the walk finds — malformed listings, entries a
         listing names but the index lacks — is batched into one
         SourceError in sorted-filename order, exactly as the settled
         scan batches."
        <category: 'source protocol'>
        | done frontier problems |
        self ensureCacheLayout.
        done := Set new.
        problems := OrderedCollection new.
        frontier := OrderedCollection new.
        seeds asSortedCollection do: [:each | frontier add: each].
        [frontier isEmpty] whileFalse: [
            | name |
            name := frontier removeFirst.
            (done includes: name) ifFalse: [
                done add: name.
                (self walk: name problems: problems) do: [:dep |
                    (done includes: dep) ifFalse: [frontier add: dep]]]].
        problems isEmpty ifFalse: [
            SourceError signalProblems:
                (problems asSortedCollection: [:a :b | a <= b]) asArray].
        ^inner snapshot
    ]

    versionsOf: aPackageName [
        "Pure delegation to the cache — no process runs."
        <category: 'source protocol'>
        ^inner versionsOf: aPackageName
    ]

    manifestFor: aPackageName version: aVersion [
        "Pure delegation to the cache — no process runs."
        <category: 'source protocol'>
        ^inner manifestFor: aPackageName version: aVersion
    ]

    fetch: aPackageName version: aVersion [
        "The archive half of the metadata/archive split: fetch the
         .star into the entries directory once — a cache hit spawns
         nothing — then delegate to the inner source, so the settled
         missing-archive and hash-verification behavior sees exactly
         the fetched bytes. A transport miss fetches nothing and
         leaves the diagnosis to the inner source's settled
         missing-archive problem."
        <category: 'source protocol'>
        | path |
        path := self archivePathFor: aPackageName
            version: aVersion printString.
        (File name: path) exists ifFalse: [
            self fetchUrl: (self archiveUrlFor: aPackageName
                    version: aVersion printString)
                to: path].
        ^inner fetch: aPackageName version: aVersion
    ]

    "---- the closure (decision 50) ----"

    walk: aName problems: problems [
        "Private — one package of the closure: re-fetch its listing (a
         listing is the one mutable artifact), read the versions it
         names, ensure each named entry is cached, and answer the
         dependency names those entries declare. A listing miss is the
         ordinary undescribed name — nothing to walk, no problem."
        <category: 'private'>
        | discovered ground |
        discovered := OrderedCollection new.
        ground := self fetchUrl: (self listingUrlFor: aName)
            to: (self listingPathFor: aName).
        ground = #miss ifTrue: [^discovered].
        (self versionsInListingFor: aName problems: problems)
            do: [:versionString |
                (self ensureEntryFor: aName version: versionString
                    problems: problems)
                    ifTrue: [discovered addAll:
                        (self dependencyNamesFor: aName
                            version: versionString)]].
        ^discovered
    ]

    versionsInListingFor: aName problems: problems [
        "Private — the fourth deserialization boundary (Doc F §7.2):
         the cached listing through the settled IndexEntryReader, then
         the #'parley-listing' 1 shape checks. Any defect is ONE
         problem naming the file and the defect, and the package
         contributes no versions."
        <category: 'private'>
        | label entry members |
        label := aName, '/', self listingFileName.
        entry := [IndexEntryReader readFrom: (ReadStream on:
                (File name: (self listingPathFor: aName)) contents)]
            on: IndexEntryParseError, IndexEntryFormatError
            do: [:e |
                problems add: label, ': ', e messageText.
                ^#()].
        (entry at: 1) = #'parley-listing' ifFalse: [
            problems add: label, ': wrong artifact tag ',
                (entry at: 1) printString,
                ' - a version listing holds #''parley-listing'' 1 artifacts'.
            ^#()].
        (entry size >= 4 and: [(entry at: 3) = #versions])
            ifFalse: [
                problems add: label, ': missing schema key #versions'.
                ^#()].
        members := entry at: 4.
        members do: [:each |
            (SchemaShape isString: each) ifFalse: [
                problems add: label, ': #versions member ',
                    each printString, ' is not a version string'.
                ^#()].
            [Version fromString: each]
                on: VersionFormatError
                do: [:e |
                    problems add: label, ': #versions ',
                        each printString, ' does not parse as a version'.
                    ^#()]].
        ^members
    ]

    ensureEntryFor: aName version: aVersionString problems: problems [
        "Private — cache the named entry, once ever: a release is
         immutable, so a cached entry is never fetched again. A
         transport MISS here is not the ordinary undescribed name: the
         index made a claim it did not keep (Doc F §7.3) — one problem
         naming both files. Answers whether the entry is cached."
        <category: 'private'>
        | path ground |
        path := self entryPathFor: aName version: aVersionString.
        (File name: path) exists ifTrue: [^true].
        ground := self fetchUrl:
                (self entryUrlFor: aName version: aVersionString)
            to: path.
        ground = #miss ifTrue: [
            problems add: aName, '/', aName, '-', aVersionString,
                '.st: named by ', aName, '/', self listingFileName,
                ' but absent from the index'.
            ^false].
        ^true
    ]

    dependencyNamesFor: aName version: aVersionString [
        "Private — the dependency names the cached entry declares,
         best-effort: a malformed entry contributes no names here and
         is diagnosed by the inner scan, which owns entry diagnosis."
        <category: 'private'>
        | entry |
        entry := [IndexEntryReader readFrom: (ReadStream on:
                (File name: (self entryPathFor: aName
                    version: aVersionString)) contents)]
            on: Error
            do: [:e | ^#()].
        ^[self dependencyNamesIn: entry] on: Error do: [:e | ^#()]
    ]

    dependencyNamesIn: anArray [
        "Private — the first element of each #dependencies pair, from
         the entry's key/value positions."
        <category: 'private'>
        | names i |
        names := OrderedCollection new.
        i := 3.
        [i < anArray size] whileTrue: [
            (anArray at: i) = #dependencies ifTrue: [
                (anArray at: i + 1) do: [:pair |
                    names add: (pair at: 1)]].
            i := i + 2].
        ^names
    ]

    "---- the transport (grounds declared closed) ----"

    fetchUrl: aUrl to: aFilePath [
        "Private — the one transport command. The grounds are closed:
         0 is a hit, 37 and 22 are a miss (file:// and HTTP spellings
         of 'the index has no such file'), anything else is one
         SourceError naming the exact command line and exit code."
        <category: 'private'>
        | command code |
        command := 'curl -sfS ', aUrl, ' -o ', aFilePath.
        code := runner run: command.
        code = 0 ifTrue: [^#hit].
        (code = 37 or: [code = 22]) ifTrue: [^#miss].
        ^SourceError signalProblems: (Array with:
            'curl command failed with exit code ', code printString,
            ': ', command)
    ]

    "---- the layout (Doc F §7.1, §7.4) ----"

    listingFileName [
        <category: 'private'>
        ^'versions.st'
    ]

    entriesDir [
        <category: 'private'>
        ^cache, '/entries'
    ]

    listingsDir [
        <category: 'private'>
        ^cache, '/listings'
    ]

    listingPathFor: aName [
        <category: 'private'>
        ^self listingsDir, '/', aName, '.st'
    ]

    entryPathFor: aName version: aVersionString [
        <category: 'private'>
        ^self entriesDir, '/', aName, '-', aVersionString, '.st'
    ]

    archivePathFor: aName version: aVersionString [
        <category: 'private'>
        ^self entriesDir, '/', aName, '-', aVersionString, '.star'
    ]

    listingUrlFor: aName [
        <category: 'private'>
        ^base, '/', aName, '/', self listingFileName
    ]

    entryUrlFor: aName version: aVersionString [
        <category: 'private'>
        ^base, '/', aName, '/', aName, '-', aVersionString, '.st'
    ]

    archiveUrlFor: aName version: aVersionString [
        <category: 'private'>
        ^base, '/', aName, '/', aName, '-', aVersionString, '.star'
    ]

    ensureCacheLayout [
        "Private — the cache directory with listings BESIDE the
         scanned entries directory, created at the I/O moment, never
         at construction. Directory creation, not a process."
        <category: 'private'>
        (File name: cache) exists ifFalse: [Directory create: cache].
        (File name: self entriesDir) exists
            ifFalse: [Directory create: self entriesDir].
        (File name: self listingsDir) exists
            ifFalse: [Directory create: self listingsDir]
    ]
]

Namespace current: Smalltalk.
