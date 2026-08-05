"Parley Sprint 15 — fixtures for publishing into a sparse index
 (issue #17; Doc F §8, Doc B §5.6, Doc E §4.1/§4.2).

 Sprint 14 shipped the sparse-index CLIENT; this sprint ships the
 producer. Everything here is the producer side of artifacts Sprint 14
 already defined: the listing text comes from SparseIndexFixtures
 listingFor:, unchanged and undelegated-from — one definition of what a
 #'parley-listing' 1 artifact looks like, asserted from both ends. If
 the producer and the client ever disagree about those bytes, the
 disagreement IS the finding, and a fixture of its own here would hide
 it.

 The pinned wordings below mirror the settled SparseIndexSource listing
 grammar sentence for sentence (Doc F §7.2) and differ only in how the
 file is NAMED: the client names a listing by its constructed URL path
 relative to the base, because that is the only spelling it and the
 index owner share; the publisher names it by the destination path the
 author typed, because that is the only spelling THEY share. Same
 defect, same sentence, each boundary naming the file the way its
 operator can act on.

 THE TREE SNAPSHOT is the S7 oracle and it recurses: 3.2.5's
 File>>files answers regular files only and never subdirectories, and a
 sparse layout is MADE of subdirectories, so a comparison written the
 obvious way would compare two empty collections and pass on any tree
 whatsoever. treeSnapshotOf: walks with namesDo: at every level and
 every law that uses it guards with deny: isEmpty.

 Star bytes are NOT reproducible on this toolchain — probed at Sprint
 15 RED, not assumed: gst-package shells out to zip, which records file
 mtimes, so two builds of identical inputs seconds apart differ. That
 is why no law here pins a star digest as a literal (the settled Doc E
 §5 digest discipline) and why the two entries S1 compares are compared
 with their own runtime digests substituted out.

 Every path is under tmp/, unique per test, removed recursively by the
 caller in tearDown."

Namespace current: Parley.

Object subclass: PublishLayoutFixtures [

    <comment: 'Class-side factory for Sprint 15 fixtures: the probe-pkg
authoring directory and manifest, the sparse layout paths, the entry
and listing oracles, the pinned PublishError wordings of the fifth
deserialization boundary, the recursive tree snapshot that S7 compares,
and the release-hardening pins (the version line and the README
markers). Stateless; uniqueness comes from per-test labels.'>

    "---- the published package (probe-pkg) ----"

    PublishLayoutFixtures class >> packageName [
        <category: 'authoring'>
        ^'probe-pkg'
    ]

    PublishLayoutFixtures class >> fileInName [
        <category: 'authoring'>
        ^'Probe.st'
    ]

    PublishLayoutFixtures class >> probeSource [
        "The one filed-in unit of the published package. It is built by
         the real toolchain in every publish law and loaded by nothing
         until S16 registers it in a curated child."
        <category: 'authoring'>
        ^'Object subclass: ProbePkgWitness [
    ProbePkgWitness class >> greeting [ ^''published into a sparse index'' ]
]', SourceFixtures newline
    ]

    PublishLayoutFixtures class >> packageContentsAtVersion: aVersionString [
        "The author-side Package.st of probe-pkg at one version."
        <category: 'authoring'>
        ^'Parley define: [:pkg |
    pkg
        name: ''', self packageName, ''';
        version: ''', aVersionString, ''';
        summary: '''';
        author: '''';
        license: '''';
        fileIns: #(''', self fileInName, ''') ]', SourceFixtures newline
    ]

    PublishLayoutFixtures class >> manifestAtVersion: aVersionString [
        "The loaded LibraryManifest a Publisher law hands the pipeline
         directly, built through the settled authoring gateway — the
         Publisher never reads Package.st itself."
        <category: 'authoring'>
        | name fileIn |
        name := self packageName.
        fileIn := self fileInName.
        ^Parley define: [:pkg |
            pkg
                name: name;
                version: aVersionString;
                summary: '';
                author: '';
                license: '';
                fileIns: (Array with: fileIn)]
    ]

    PublishLayoutFixtures class >> workDirNamed: aLabel version: aVersionString [
        "An author working directory: the Package.st declaring
         probe-pkg at aVersionString and the file it declares. The
         caller tracks it for recursive teardown."
        <category: 'authoring'>
        | path |
        path := SourceFixtures directoryNamed: aLabel.
        ExecFixtures writePackage: (self packageContentsAtVersion: aVersionString)
            in: path.
        SourceFixtures write: self probeSource
            toFile: self fileInName in: path.
        ^path
    ]

    PublishLayoutFixtures class >> entryAtVersion: aVersionString digest: aDigest [
        "The settled Doc B §5.2 entry bytes for probe-pkg — the oracle
         BOTH layouts must write, because only the location changes."
        <category: 'oracles'>
        ^'#(#''parley-index'' 1 #name ''', self packageName,
            ''' #version ''', aVersionString,
            ''' #summary '''' #author '''' #license '''' #fileIns #(''',
            self fileInName, ''') #dependencies #() #archive #(''',
            (self archiveFileNameAtVersion: aVersionString),
            ''' #sha256 ''', aDigest, '''))', SourceFixtures newline
    ]

    PublishLayoutFixtures class >> listingFor: someVersionStrings [
        "The listing oracle is the CLIENT'S, consumed unchanged: Sprint
         14 defined these bytes to read them, and this sprint writes
         them. A second rendering here would let the producer and the
         consumer drift apart quietly, which is the one thing the
         shared artifact must never do."
        <category: 'oracles'>
        ^SparseIndexFixtures listingFor: someVersionStrings
    ]

    "---- the layout on disk (Doc F §8.2) ----"

    PublishLayoutFixtures class >> entryFileNameAtVersion: aVersionString [
        <category: 'layout paths'>
        ^self packageName, '-', aVersionString, '.st'
    ]

    PublishLayoutFixtures class >> archiveFileNameAtVersion: aVersionString [
        <category: 'layout paths'>
        ^self packageName, '-', aVersionString, '.star'
    ]

    PublishLayoutFixtures class >> listingFileName [
        <category: 'layout paths'>
        ^SparseIndexFixtures listingFileName
    ]

    PublishLayoutFixtures class >> packageDirIn: aDestDir [
        "Where a sparse publish lands probe-pkg — the directory the
         client addresses as <base>/<name>/."
        <category: 'layout paths'>
        ^aDestDir, '/', self packageName
    ]

    PublishLayoutFixtures class >> sparseEntryPathIn: aDestDir version: aVersionString [
        <category: 'layout paths'>
        ^(self packageDirIn: aDestDir), '/',
            (self entryFileNameAtVersion: aVersionString)
    ]

    PublishLayoutFixtures class >> sparseArchivePathIn: aDestDir version: aVersionString [
        <category: 'layout paths'>
        ^(self packageDirIn: aDestDir), '/',
            (self archiveFileNameAtVersion: aVersionString)
    ]

    PublishLayoutFixtures class >> sparseListingPathIn: aDestDir [
        <category: 'layout paths'>
        ^(self packageDirIn: aDestDir), '/', self listingFileName
    ]

    PublishLayoutFixtures class >> flatEntryPathIn: aDestDir version: aVersionString [
        <category: 'layout paths'>
        ^aDestDir, '/', (self entryFileNameAtVersion: aVersionString)
    ]

    PublishLayoutFixtures class >> flatArchivePathIn: aDestDir version: aVersionString [
        <category: 'layout paths'>
        ^aDestDir, '/', (self archiveFileNameAtVersion: aVersionString)
    ]

    PublishLayoutFixtures class >> sparsePackageDirNamesAtVersion: aVersionString [
        "Exactly what <dest>/<name>/ holds after one successful sparse
         publish, in sorted order (Doc F §8.2)."
        <category: 'layout paths'>
        ^((Array
            with: self listingFileName
            with: (self entryFileNameAtVersion: aVersionString)
            with: (self archiveFileNameAtVersion: aVersionString))
                asSortedCollection: [:a :b | a <= b]) asArray
    ]

    "---- the argv the operator types ----"

    PublishLayoutFixtures class >> layoutFlag [
        <category: 'argv'>
        ^'--layout'
    ]

    PublishLayoutFixtures class >> publishArgvTo: aDestDir layout: aLayoutName [
        <category: 'argv'>
        ^Array with: 'publish' with: aDestDir
            with: self layoutFlag with: aLayoutName
    ]

    PublishLayoutFixtures class >> publishArgvTo: aDestDir [
        "No flag at all — the settled Sprint 7 invocation, whose output
         this sprint must leave byte-identical."
        <category: 'argv'>
        ^Array with: 'publish' with: aDestDir
    ]

    "---- the pinned refusal wording, sparse-located ----"

    PublishLayoutFixtures class >> refusalProblemAtVersion: aVersionString in: aDestDir [
        "The SETTLED refusal sentence (PublishFixtures
         refusalProblemFor:version:in:), naming the entry path the
         sparse layout actually holds. Releases are immutable in both
         layouts; only the parenthesised path moves."
        <category: 'pinned wordings'>
        ^self packageName, ' ', aVersionString,
            ': already published - releases are immutable (',
            (self sparseEntryPathIn: aDestDir version: aVersionString),
            ' exists)'
    ]

    "---- the fifth deserialization boundary: pinned wordings ----"

    PublishLayoutFixtures class >> listingLabelIn: aDestDir [
        "How a PublishError names the listing it read: the destination
         path the AUTHOR typed, because that is the spelling they can
         act on. The client names the same file by its base-relative
         URL path for the same reason."
        <category: 'pinned wordings'>
        ^self sparseListingPathIn: aDestDir
    ]

    PublishLayoutFixtures class >> unreadableListingProblemIn: aDestDir [
        "The settled reader's positioned parse error, prefixed with the
         file it struck — the Doc F §4 malformed-artifact grammar
         applied to the fifth boundary."
        <category: 'pinned wordings'>
        ^(self listingLabelIn: aDestDir), ': ', self readerOpeningTokenMessage
    ]

    PublishLayoutFixtures class >> readerOpeningTokenMessage [
        "The settled IndexEntryReader message for text that is not a
         literal artifact at all. Mirrors SparseIndexFixtures
         unreadableListingProblemFor: — the same reader, so the same
         sentence."
        <category: 'pinned wordings'>
        ^'Parse error at position 1: artifact must open with a literal array - the micro-format accepts only literal arrays, strings, symbols and non-negative integers'
    ]

    PublishLayoutFixtures class >> wrongTagListingProblemIn: aDestDir tag: aTagPrintString [
        <category: 'pinned wordings'>
        ^(self listingLabelIn: aDestDir), ': wrong artifact tag ',
            aTagPrintString,
            ' - a version listing holds #''parley-listing'' 1 artifacts'
    ]

    PublishLayoutFixtures class >> missingVersionsKeyProblemIn: aDestDir [
        <category: 'pinned wordings'>
        ^(self listingLabelIn: aDestDir), ': missing schema key #versions'
    ]

    PublishLayoutFixtures class >> nonStringMemberProblemIn: aDestDir value: aValuePrintString [
        <category: 'pinned wordings'>
        ^(self listingLabelIn: aDestDir), ': #versions member ',
            aValuePrintString, ' is not a version string'
    ]

    PublishLayoutFixtures class >> unparseableVersionProblemIn: aDestDir value: aString [
        <category: 'pinned wordings'>
        ^(self listingLabelIn: aDestDir), ': #versions ',
            aString printString, ' does not parse as a version'
    ]

    "---- malformed listing texts, one per ground (S5) ----"

    PublishLayoutFixtures class >> malformedListingTexts [
        "Every ground the fifth boundary must diagnose, each paired
         with the block answering its pinned problem for a destination.
         The table is ITERATED by the law, so a ground added here
         without a wording fails loudly rather than going unchecked.
         The texts are the CLIENT'S, undelegated-from: one malformed
         listing, diagnosed by both boundaries."
        <category: 'malformed listings'>
        ^(Array
            with: (Array with: SparseIndexFixtures unreadableListingText
                with: [:dest | self unreadableListingProblemIn: dest])
            with: (Array with: SparseIndexFixtures wrongTagListingText
                with: [:dest | self wrongTagListingProblemIn: dest
                    tag: '#''parley-lock'''])
            with: (Array with: SparseIndexFixtures missingVersionsListingText
                with: [:dest | self missingVersionsKeyProblemIn: dest])
            with: (Array with: SparseIndexFixtures nonStringMemberListingText
                with: [:dest | self nonStringMemberProblemIn: dest
                    value: '42'])),
            (Array with: (Array
                with: SparseIndexFixtures unparseableVersionListingText
                with: [:dest | self unparseableVersionProblemIn: dest
                    value: 'abc']))
    ]

    "---- writing a destination by hand (the pre-existing index) ----"

    PublishLayoutFixtures class >> writeListing: aText in: aDestDir [
        "Place aText where a sparse publish reads its listing from,
         creating the package directory when it is absent."
        <category: 'destinations'>
        | dir |
        dir := self packageDirIn: aDestDir.
        (File name: dir) exists ifFalse: [Directory create: dir].
        SourceFixtures write: aText toFile: self listingFileName in: dir
    ]

    PublishLayoutFixtures class >> writeEntryText: aText in: aDestDir version: aVersionString [
        <category: 'destinations'>
        | dir |
        dir := self packageDirIn: aDestDir.
        (File name: dir) exists ifFalse: [Directory create: dir].
        SourceFixtures write: aText
            toFile: (self entryFileNameAtVersion: aVersionString) in: dir
    ]

    "---- the recursive tree snapshot (the S7 oracle) ----"

    PublishLayoutFixtures class >> treeSnapshotOf: aPath [
        "Every path under aPath, relative and sorted, each paired with
         its bytes — a directory pairs with the directoryMarker. THE
         WALK RECURSES: File>>files answers regular files only and
         never subdirectories, and a sparse layout is made of
         subdirectories, so a snapshot written with files would compare
         nothing to nothing and pass on any tree at all. Empty for an
         absent path, which is why every law using this guards with
         deny: isEmpty where a tree is expected."
        <category: 'tree comparison'>
        | rows |
        rows := OrderedCollection new.
        self collectTreeOf: aPath prefix: '' into: rows.
        ^(rows asSortedCollection: [:a :b | (a at: 1) <= (b at: 1)]) asArray
    ]

    PublishLayoutFixtures class >> treeSnapshotOf: aPath without: aName [
        "The snapshot with one top-level entry and everything beneath
         it dropped — the build-failure ground of S7, where Doc F §1
         step 4 rules that the stage is LEFT IN PLACE for inspection
         (fail-stop never cleans up behind an error) while Doc F §8.3
         scopes the atomicity claim to the entry, the archive and the
         listing."
        <category: 'tree comparison'>
        ^(self treeSnapshotOf: aPath) reject: [:row |
            ((row at: 1) = aName)
                or: [(row at: 1) startsWith: aName, '/']]
    ]

    PublishLayoutFixtures class >> collectTreeOf: aPath prefix: aPrefix into: rows [
        "Private — one directory level, recursing through namesDo:."
        <category: 'tree comparison'>
        | dir |
        dir := File name: aPath.
        (dir exists and: [dir isDirectory]) ifFalse: [^rows].
        (self entryNamesIn: aPath) do: [:each |
            | child relative |
            child := aPath, '/', each.
            relative := aPrefix, each.
            (File name: child) isDirectory
                ifTrue: [
                    rows add: (Array with: relative with: self directoryMarker).
                    self collectTreeOf: child prefix: relative, '/' into: rows]
                ifFalse: [
                    rows add: (Array with: relative
                        with: (File name: child) contents)]]
    ]

    PublishLayoutFixtures class >> entryNamesIn: aPath [
        "Private — the sorted entry names of one directory, dot entries
         dropped, through namesDo: because files skips subdirectories."
        <category: 'tree comparison'>
        | names |
        names := OrderedCollection new.
        (File name: aPath) namesDo: [:each |
            (#('.' '..') includes: each) ifFalse: [names add: each]].
        ^(names asSortedCollection: [:a :b | a <= b]) asArray
    ]

    PublishLayoutFixtures class >> directoryMarker [
        <category: 'tree comparison'>
        ^'<directory>'
    ]

    PublishLayoutFixtures class >> stageDirName [
        "The settled destination-confined stage (Doc F §1 step 3),
         named here so the S7 build-failure ground can exclude exactly
         it and nothing else."
        <category: 'tree comparison'>
        ^'.parley-publish-stage'
    ]

    "---- release hardening (S12, S13, S15) ----"

    PublishLayoutFixtures class >> versionFlag [
        <category: 'release hardening'>
        ^'--version'
    ]

    PublishLayoutFixtures class >> versionLine [
        "The one line parley --version prints. The VERSION half is
         derived from the constant rather than restated, so the law
         cannot pass against a second literal that has drifted; only
         the tool name is spelled here."
        <category: 'release hardening'>
        ^'parley ', Parley version
    ]

    PublishLayoutFixtures class >> layoutFlagUsageLine [
        "The usage flags: line the layout flag adds, pinned here while
         ExecFixtures usageLines is re-pinned in GREEN together with
         the CommandLine change (the Sprint 11/12/13/14 precedent —
         re-pinning in RED fails every settled usage law against a
         class that has not moved yet). The description column is the
         settled one: sixteen characters of flag and padding."
        <category: 'release hardening'>
        ^'       --layout <name> flat (default) or sparse, the index layout publish writes'
    ]

    PublishLayoutFixtures class >> proofScriptContentsFor: aProofPath [
        "The S16 witness: load the PUBLISHED package through
         PackageLoader in the curated child and record whether its
         class became visible. The package was built by the toolchain
         from the author's own manifest, published into a sparse index,
         fetched by a second author over file://, hash-verified and
         registered — and this is where all of that becomes one word in
         a file."
        <category: 'release hardening'>
        ^'| ok stream |
ok := [PackageLoader fileInPackage: ''', self packageName, '''.
    Smalltalk includesKey: #ProbePkgWitness] on: Error do: [:e | false].
stream := (File name: ''', aProofPath, ''') writeStream.
stream nextPutAll: (ok ifTrue: [''present''] ifFalse: [''absent'']).
stream close', SourceFixtures newline
    ]

    PublishLayoutFixtures class >> readmePath [
        <category: 'release hardening'>
        ^'README.md'
    ]

    PublishLayoutFixtures class >> readmeSource [
        "The README read as TEXT — the drift law compares what the tool
         documents against what the tool answers."
        <category: 'release hardening'>
        ^(File name: self readmePath) contents
    ]

    PublishLayoutFixtures class >> verbsIn: aUsageVerbsLine [
        "The verbs the CLI's own usage line declares: the text after
         the label, split on the pipe, each clause's first word. The
         README law compares against THIS rather than a hand-kept list,
         so a verb added without documentation fails the suite."
        <category: 'release hardening'>
        | body verbs word |
        body := aUsageVerbsLine copyFrom:
            (self indexOfSubstring: 'verbs: ' in: aUsageVerbsLine) + 7
            to: aUsageVerbsLine size.
        verbs := OrderedCollection new.
        word := WriteStream on: String new.
        body do: [:ch |
            ch = $| ifTrue: [
                self add: word contents firstWordTo: verbs.
                word := WriteStream on: String new]
                ifFalse: [word nextPut: ch]].
        self add: word contents firstWordTo: verbs.
        ^verbs asArray
    ]

    PublishLayoutFixtures class >> add: aClause firstWordTo: aCollection [
        "Private — the first whitespace-delimited word of a usage
         clause, which is the verb itself."
        <category: 'release hardening'>
        | word |
        word := WriteStream on: String new.
        aClause do: [:ch |
            ch isSeparator
                ifTrue: [word contents isEmpty ifFalse: [
                    ^aCollection add: word contents]]
                ifFalse: [word nextPut: ch]].
        word contents isEmpty ifFalse: [aCollection add: word contents]
    ]

    PublishLayoutFixtures class >> indexOfSubstring: aSubstring in: aString [
        "Private — the 1-based index where aSubstring begins, 0 when it
         does not occur."
        <category: 'release hardening'>
        1 to: aString size - aSubstring size + 1 do: [:i |
            ((aString copyFrom: i to: i + aSubstring size - 1) = aSubstring)
                ifTrue: [^i]].
        ^0
    ]

    PublishLayoutFixtures class >> execConstraintMarkers [
        "The §8 decision 45 consumer constraint, as the README must
         carry it: parley exec is a faithful pass-through of the
         child's exit code, so a script whose success matters to CI
         ends with an explicit quit. A README that dropped this would
         document a promise the tool does not make."
        <category: 'release hardening'>
        ^Array with: 'ObjectMemory quit:' with: 'matters to CI'
    ]

    PublishLayoutFixtures class >> layoutDocumentationMarkers [
        "What a stranger needs in order to publish into either layout:
         the flag and both of its values."
        <category: 'release hardening'>
        ^(Array with: '--layout' with: 'sparse') , (Array with: 'flat')
    ]
]

Namespace current: Smalltalk.
