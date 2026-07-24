"Parley Sprint 7 — the archive-carrying IndexEntryWriter selector
 (issue #9 S4-S5; Doc F §2).

 The ONE new selector on a settled class (a declared exception):
 write: aManifest archive: aFileName sha256: aHexDigest on: aStream —
 identical §5.2 canonical rendering to the settled write:on:, except
 #archive #('<aFileName>' #sha256 '<aHexDigest>') in place of
 #archive #(). The settled write:on: is untouched and its output stays
 byte-identical: the Sprint 1 oracle keeps passing unchanged. That
 regression guard is S5 and lives ONLY in tests/acceptance/ — it is
 one of the sprint's two declared passes-in-red, and duplicating it
 here would silently add a third.

 Protocol decisions pinned here (posted on issue #9 for confirmation):
   - the selector shape and argument order above;
   - the byte oracle PublishFixtures templateArchiveEntryString: the
     settled Sprint 1 oracle with the #archive field populated and
     nothing else changed;
   - the digest is opaque to the writer — it renders whatever string it
     is handed (the archiveDigest fixture is AUTHORED input, never a
     star's true digest, which is always computed at fixture time);
   - the settled IndexEntryReader consumes populated #archive fields
     unchanged (Sprint 4) — round-trip needs no reader change.

 Fixture directories live under tmp/ and are removed in tearDown. No
 process is spawned by this suite."

Namespace current: Parley.

TestCase subclass: IndexEntryWriterArchiveTest [
    | fixtureDirs |

    <comment: 'Laws for IndexEntryWriter write:archive:sha256:on: —
the published entry''s byte oracle, byte-stability, the settled
write:on: regression guard, the exact one-field difference between the
two renderings, and the round-trip through the settled reader and the
DirectorySource scan.'>

    setUp [
        fixtureDirs := OrderedCollection new
    ]

    tearDown [
        fixtureDirs isNil ifTrue: [^self].
        fixtureDirs do: [:each | ExecFixtures removeTree: each].
        fixtureDirs := nil
    ]

    freshDir: aLabel [
        | path |
        path := SourceFixtures directoryNamed: aLabel.
        fixtureDirs add: path.
        ^path
    ]

    version: aString [
        ^Version fromString: aString
    ]

    write: aManifest [
        "The settled rendering, as a String."
        | stream |
        stream := WriteStream on: String new.
        IndexEntryWriter write: aManifest on: stream.
        ^stream contents
    ]

    writePublished: aManifest [
        "The new rendering, carrying the fixture archive name and
         digest, as a String."
        | stream |
        stream := WriteStream on: String new.
        IndexEntryWriter
            write: aManifest
            archive: PublishFixtures templateArchiveFileName
            sha256: PublishFixtures archiveDigest
            on: stream.
        ^stream contents
    ]

    "---- S4: the published entry's byte oracle ----"

    testTheArchiveSelectorRendersTheCanonicalPublishedEntry [
        self assert: (self writePublished: PublishFixtures templateManifest)
            = PublishFixtures templateArchiveEntryString
    ]

    "---- the two renderings differ in exactly one field ----"

    testThePublishedEntryDiffersFromTheSettledOnlyInTheArchiveField [
        | settled published settledTail publishedTail |
        settled := self write: PublishFixtures templateManifest.
        published := self writePublished: PublishFixtures templateManifest.
        settledTail := '#archive #())', SourceFixtures newline.
        publishedTail := '#archive #(''',
            PublishFixtures templateArchiveFileName, ''' #sha256 ''',
            PublishFixtures archiveDigest, '''))', SourceFixtures newline.
        self assert: (settled endsWith: settledTail).
        self assert: (published endsWith: publishedTail).
        self assert: (settled copyFrom: 1 to: settled size - settledTail size)
            = (published copyFrom: 1 to: published size - publishedTail size)
    ]

    "---- byte-stability ----"

    testThePublishedRenderingIsByteStable [
        | manifest first second |
        manifest := PublishFixtures templateManifest.
        first := self writePublished: manifest.
        second := self writePublished: manifest.
        self assert: first = second
    ]

    testThePublishedRenderingPreservesFileInOrderAndSortsDependencies [
        "The two deliberate ordering rules are unchanged by the new
         selector: fileIns keep author order, dependencies sort."
        | permuted |
        permuted := Parley define: [:pkg |
            pkg
                name: 'kernel-json';
                version: '0.3.1';
                summary: 'A JSON reader/writer speaking pure message sends';
                author: 'Leonardo';
                license: 'MIT';
                fileIns: #('Reader.st' 'Writer.st' 'Extensions.st');
                dependency: 'kernel-strings' constraint: '^0.4.2';
                dependency: 'kernel-streams' constraint: '>=1.0 <2.0'].
        self assert: (self writePublished: permuted)
            = PublishFixtures templateArchiveEntryString
    ]

    "---- the settled reader consumes the populated field unchanged ----"

    testThePublishedEntryRoundTripsThroughTheSettledReader [
        | entry fields back original |
        original := PublishFixtures templateManifest.
        entry := IndexEntryReader readFrom:
            (ReadStream on: (self writePublished: original)).
        fields := Dictionary new.
        3 to: entry size - 1 by: 2 do: [:i |
            fields at: (entry at: i) put: (entry at: i + 1)].
        self assert: (fields at: #archive) size = 3.
        self assert: ((fields at: #archive) at: 1)
            = PublishFixtures templateArchiveFileName.
        self assert: ((fields at: #archive) at: 2) = #sha256.
        self assert: ((fields at: #archive) at: 3)
            = PublishFixtures archiveDigest.
        back := LibraryManifest fromIndexEntry: entry.
        self assert: back name = original name.
        self assert: back version = original version.
        self assert: back summary = original summary.
        self assert: back author = original author.
        self assert: back license = original license.
        self assert: back fileIns = original fileIns.
        self assert: back dependencies size = original dependencies size
    ]

    "---- a published entry is a scannable entry ----"

    testAPublishedEntryScansAndCarriesItsDigest [
        "The writer is the schema's other half: everything it emits
         satisfies the shape contract the scan now enforces, and the
         snapshot carries the digest the entry declares."
        | dir stream snap |
        dir := self freshDir: 'writer-published'.
        stream := (File name: dir, '/kernel-json-0.3.1.st') writeStream.
        [IndexEntryWriter
            write: PublishFixtures templateManifest
            archive: PublishFixtures templateArchiveFileName
            sha256: PublishFixtures archiveDigest
            on: stream]
                ensure: [stream close].
        snap := (DirectorySource on: dir) snapshot.
        self assert: (snap versionsOf: 'kernel-json') size = 1.
        self assert: (snap sha256For: 'kernel-json'
            version: (self version: '0.3.1'))
                = PublishFixtures archiveDigest
    ]
]

Namespace current: Smalltalk.
