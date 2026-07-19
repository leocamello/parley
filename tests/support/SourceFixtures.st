"Parley Sprint 4 — runtime fixture-directory builder for the
 DirectorySource suites (issue #6).

 Filesystem discipline (issue #6 'Test fixture hygiene'):
   - every fixture directory lives under tmp/ (relative to the working
     directory), is created at runtime, and is removed in tearDown;
     nothing under tmp/ is ever committed and no other location is
     touched;
   - directories are flat (files only, no subdirectories);
   - directory names are 'tmp/parley-<label>' with a per-test label, so
     a crashed run's leftovers are swept by the next directoryNamed:.

 The diamond entry set mirrors the settled Sprint 2 shape
 (ResolverFixtures satisfiableDiamondSnapshot): a 1.0.0 -> c
 '>=1.0.0 <3.0.0' (sha 'ab12'), b 1.0.0 -> c '>=2.0.0 <3.0.0'
 ('cd34'), c 1.5.0 ('ef15'), c 2.4.0 ('ef56'), c 3.0.0 ('ef30').
 Entry files carrying hashes are hand-authored strings, schema-exact
 per Doc B §5.2 (the writer emits #archive #() today; populated
 #archive triples exist only in hand-authored fixtures)."

Namespace current: Parley.

Object subclass: SourceFixtures [

    <comment: 'Class-side factory for DirectorySource test fixtures:
unique flat directories under tmp/, hand-authored index-entry strings
for the Sprint 2 diamond shape, offending-file contents for every
SourceError kind, and the teardown helpers that keep tmp/ empty after
a clean run. Stateless; uniqueness comes from per-test labels.'>

    "---- directories under tmp/ ----"

    SourceFixtures class >> directoryNamed: aLabel [
        "Create and answer the path of a fresh, empty fixture directory
         tmp/parley-<aLabel>, sweeping any leftover from a crashed
         earlier run."
        <category: 'directories'>
        | path |
        path := 'tmp/parley-', aLabel.
        self removeTree: path.
        (File name: 'tmp') exists ifFalse: [Directory create: 'tmp'].
        Directory create: path.
        ^path
    ]

    SourceFixtures class >> missingPathNamed: aLabel [
        "Answer a path under tmp/ that is never created — the S12
         missing-directory fixture."
        <category: 'directories'>
        ^'tmp/parley-missing-', aLabel
    ]

    SourceFixtures class >> write: aString toFile: aBaseName in: aDirPath [
        "Write aString as the complete contents of aDirPath/aBaseName."
        <category: 'directories'>
        | stream |
        stream := (File name: aDirPath, '/', aBaseName) writeStream.
        [stream nextPutAll: aString] ensure: [stream close]
    ]

    SourceFixtures class >> writeManifest: aManifest as: aBaseName in: aDirPath [
        "Serialize aManifest into the directory through the settled
         IndexEntryWriter — the S7 writer-authored path."
        <category: 'directories'>
        | stream |
        stream := (File name: aDirPath, '/', aBaseName) writeStream.
        [IndexEntryWriter write: aManifest on: stream] ensure: [stream close]
    ]

    SourceFixtures class >> removeTree: aDirPath [
        "Remove every file of the flat fixture directory, then the
         directory itself, then tmp/ when it is left empty. Silent when
         the path does not exist."
        <category: 'directories'>
        | dir |
        dir := File name: aDirPath.
        dir exists ifTrue: [
            dir isDirectory ifTrue: [dir files do: [:each | each remove]].
            dir remove].
        self removeTmpWhenEmpty
    ]

    SourceFixtures class >> removeTmpWhenEmpty [
        "Remove tmp/ itself once no fixture content remains, so a clean
         run leaves tmp/ empty or absent (issue #6 definition of done)."
        <category: 'directories'>
        | tmp |
        tmp := File name: 'tmp'.
        (tmp exists and: [tmp isDirectory]) ifFalse: [^self].
        tmp namesDo: [:each |
            (#('.' '..') includes: each) ifFalse: [^self]].
        tmp remove
    ]

    "---- the hand-authored diamond entry set (Doc B §5.2 schema-exact) ----"

    SourceFixtures class >> newline [
        <category: 'private'>
        ^String with: Character nl
    ]

    SourceFixtures class >> diamondEntryA [
        "a 1.0.0 -> c '>=1.0.0 <3.0.0', archive sha256 'ab12'."
        <category: 'diamond entries'>
        ^'#(#''parley-index'' 1 #name ''a'' #version ''1.0.0'' #summary '''' #author '''' #license '''' #fileIns #(''A.st'') #dependencies #(#(''c'' ''>=1.0.0 <3.0.0'')) #archive #(''a-1.0.0.star'' #sha256 ''ab12''))', self newline
    ]

    SourceFixtures class >> diamondEntryB [
        "b 1.0.0 -> c '>=2.0.0 <3.0.0', archive sha256 'cd34'."
        <category: 'diamond entries'>
        ^'#(#''parley-index'' 1 #name ''b'' #version ''1.0.0'' #summary '''' #author '''' #license '''' #fileIns #(''B.st'') #dependencies #(#(''c'' ''>=2.0.0 <3.0.0'')) #archive #(''b-1.0.0.star'' #sha256 ''cd34''))', self newline
    ]

    SourceFixtures class >> diamondEntryC15 [
        "c 1.5.0, no dependencies, archive sha256 'ef15'."
        <category: 'diamond entries'>
        ^'#(#''parley-index'' 1 #name ''c'' #version ''1.5.0'' #summary '''' #author '''' #license '''' #fileIns #(''C.st'') #dependencies #() #archive #(''c-1.5.0.star'' #sha256 ''ef15''))', self newline
    ]

    SourceFixtures class >> diamondEntryC24 [
        "c 2.4.0, no dependencies, archive sha256 'ef56'."
        <category: 'diamond entries'>
        ^'#(#''parley-index'' 1 #name ''c'' #version ''2.4.0'' #summary '''' #author '''' #license '''' #fileIns #(''C.st'') #dependencies #() #archive #(''c-2.4.0.star'' #sha256 ''ef56''))', self newline
    ]

    SourceFixtures class >> diamondEntryC30 [
        "c 3.0.0, no dependencies, archive sha256 'ef30'."
        <category: 'diamond entries'>
        ^'#(#''parley-index'' 1 #name ''c'' #version ''3.0.0'' #summary '''' #author '''' #license '''' #fileIns #(''C.st'') #dependencies #() #archive #(''c-3.0.0.star'' #sha256 ''ef30''))', self newline
    ]

    SourceFixtures class >> populateDiamondIn: aDirPath [
        "Write the five diamond entries under the recommended
         <name>-<version>.st layout."
        <category: 'diamond entries'>
        self populateDiamondIn: aDirPath with24As: 'c-2.4.0.st'
    ]

    SourceFixtures class >> populateDiamondIn: aDirPath with24As: aBaseName [
        "Write the five diamond entries, storing the c 2.4.0 entry under
         aBaseName — the S6 contents-not-filename fixture."
        <category: 'diamond entries'>
        self write: self diamondEntryA toFile: 'a-1.0.0.st' in: aDirPath.
        self write: self diamondEntryB toFile: 'b-1.0.0.st' in: aDirPath.
        self write: self diamondEntryC15 toFile: 'c-1.5.0.st' in: aDirPath.
        self write: self diamondEntryC24 toFile: aBaseName in: aDirPath.
        self write: self diamondEntryC30 toFile: 'c-3.0.0.st' in: aDirPath
    ]

    "---- offending-file contents, one per SourceError kind ----"

    SourceFixtures class >> malformedContents [
        "Not a literal artifact: a message send, rejected by the reader
         at position 1."
        <category: 'offending files'>
        ^'Transcript showCr: ''pwned''', self newline
    ]

    SourceFixtures class >> lockArtifactContents [
        "A well-formed #'parley-lock' 1 artifact — readable, but the
         wrong tag for a source directory."
        <category: 'offending files'>
        ^'#(#''parley-lock'' 1 #root ''my-app'' #packages #())', self newline
    ]

    SourceFixtures class >> unsupportedVersionContents [
        "A #'parley-index' artifact with format version 2 — rejected by
         the reader's forward-evolution check."
        <category: 'offending files'>
        ^'#(#''parley-index'' 2)', self newline
    ]

    SourceFixtures class >> duplicateC24Contents [
        "A second well-formed entry also declaring c 2.4.0 (different
         sha) — the duplicate-(name, version) fixture."
        <category: 'offending files'>
        ^'#(#''parley-index'' 1 #name ''c'' #version ''2.4.0'' #summary '''' #author '''' #license '''' #fileIns #(''C.st'') #dependencies #() #archive #(''c-2.4.0.star'' #sha256 ''dead''))', self newline
    ]

    SourceFixtures class >> lateEntryDContents [
        "A d 1.0.0 entry with an empty #archive — added to a directory
         after snapshot answers, for the sealed-snapshot law."
        <category: 'offending files'>
        ^'#(#''parley-index'' 1 #name ''d'' #version ''1.0.0'' #summary '''' #author '''' #license '''' #fileIns #(''D.st'') #dependencies #() #archive #())', self newline
    ]
]

Namespace current: Smalltalk.
