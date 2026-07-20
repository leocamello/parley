"Parley Sprint 5 — runtime fixtures for the Installer suites (issue #7).

 Filesystem discipline (as Sprint 4): every fixture directory — entry
 directories, store roots, target paths — lives under tmp/, is unique
 per test via a label, and is removed in tearDown through
 SourceFixtures removeTree:; tmp/ is empty or absent after a clean run.

 The install diamond mirrors the settled Sprint 2/4 shape (a 1.0.0 -> c
 '>=1.0.0 <3.0.0', b 1.0.0 -> c '>=2.0.0 <3.0.0', c {1.5.0, 2.4.0,
 3.0.0}) with one difference: every #archive carries the TRUE Sha256
 digest of its archive bytes. Archives are runtime-written opaque byte
 strings — never a real archive format, never unpacked, never parsed.

 Digest discipline (issue #7): each pinned digest below is the true
 SHA-256 of the exact byte string it is paired with, precomputed with
 sha256sum at authoring time and re-verifiable the same way:

   'opaque archive bytes: a 1.0.0'
     -> ca830a9b7589b772e4cde0add3254541a1e5b537ac0aadda4f1441ed11da23ca
   'opaque archive bytes: b 1.0.0'
     -> 4da43d910afd9d0b85a20c0bf6577ce34e4d5992adaa27a7bd661f5816b2c27f
   'opaque archive bytes: c 1.5.0'
     -> 4d55ca3449b36e0a86e042ab150000e9ab2e013f11bf24d0eab90d9b7591150a
   'opaque archive bytes: c 2.4.0'
     -> a580ed8ad29366bfbdd4a8ce072b4f13dacf14633b74fd45c5b88909ab21256e
   'opaque archive bytes: c 3.0.0'
     -> 78e074b95cdf1398e3f93da9e063e1dda2fb146cd65c8b9a33ffa35c472c6df8
   'opaque archive bytes: e 1.0.0'
     -> c0e83e76684d8681689893f25ba32d4093958737fc291bf5bc2abda08a510a28
   'tampered archive bytes: b 1.0.0'
     -> f387d86d34df912396780292ad997fb8dcfd1f12dd17806f7ed3bc2d839b2e3f

 Only a, b and c 2.4.0 archives are ever written to disk (the resolved
 set); c 1.5.0 / c 3.0.0 / e digests are true digests of byte strings
 that never land on disk (e is the S8 missing-archive fixture)."

Namespace current: Parley.

Object subclass: InstallFixtures [

    <comment: 'Class-side factory for Installer test fixtures: the
install diamond entry set whose #archive fields carry true Sha256
digests, the runtime-written opaque archive byte strings, store-root
paths under tmp/, and tampering helpers. Stateless; uniqueness comes
from per-test labels. Directory creation and teardown delegate to the
settled SourceFixtures helpers.'>

    "---- the opaque archive byte strings ----"

    InstallFixtures class >> archiveBytesA [
        <category: 'archive bytes'>
        ^'opaque archive bytes: a 1.0.0'
    ]

    InstallFixtures class >> archiveBytesB [
        <category: 'archive bytes'>
        ^'opaque archive bytes: b 1.0.0'
    ]

    InstallFixtures class >> archiveBytesC24 [
        <category: 'archive bytes'>
        ^'opaque archive bytes: c 2.4.0'
    ]

    InstallFixtures class >> tamperedBytesB [
        "Different bytes overwriting b's archive — the corruption
         fixture."
        <category: 'archive bytes'>
        ^'tampered archive bytes: b 1.0.0'
    ]

    "---- the pinned true digests ----"

    InstallFixtures class >> digestA [
        <category: 'digests'>
        ^'ca830a9b7589b772e4cde0add3254541a1e5b537ac0aadda4f1441ed11da23ca'
    ]

    InstallFixtures class >> digestB [
        <category: 'digests'>
        ^'4da43d910afd9d0b85a20c0bf6577ce34e4d5992adaa27a7bd661f5816b2c27f'
    ]

    InstallFixtures class >> digestC15 [
        <category: 'digests'>
        ^'4d55ca3449b36e0a86e042ab150000e9ab2e013f11bf24d0eab90d9b7591150a'
    ]

    InstallFixtures class >> digestC24 [
        <category: 'digests'>
        ^'a580ed8ad29366bfbdd4a8ce072b4f13dacf14633b74fd45c5b88909ab21256e'
    ]

    InstallFixtures class >> digestC30 [
        <category: 'digests'>
        ^'78e074b95cdf1398e3f93da9e063e1dda2fb146cd65c8b9a33ffa35c472c6df8'
    ]

    InstallFixtures class >> digestE [
        <category: 'digests'>
        ^'c0e83e76684d8681689893f25ba32d4093958737fc291bf5bc2abda08a510a28'
    ]

    InstallFixtures class >> tamperedDigestB [
        "The true digest of tamperedBytesB — what a tampered b archive
         actually hashes to (the S13 'actual' digest)."
        <category: 'digests'>
        ^'f387d86d34df912396780292ad997fb8dcfd1f12dd17806f7ed3bc2d839b2e3f'
    ]

    "---- the install diamond entries (Doc B §5.2 schema-exact, true digests) ----"

    InstallFixtures class >> installEntryA [
        "a 1.0.0 -> c '>=1.0.0 <3.0.0', archive a-1.0.0.star, true digest."
        <category: 'install entries'>
        ^'#(#''parley-index'' 1 #name ''a'' #version ''1.0.0'' #summary '''' #author '''' #license '''' #fileIns #(''A.st'') #dependencies #(#(''c'' ''>=1.0.0 <3.0.0'')) #archive #(''a-1.0.0.star'' #sha256 ''',
            self digestA, '''))', SourceFixtures newline
    ]

    InstallFixtures class >> installEntryAEmptyArchive [
        "The S14 variant: a 1.0.0 with #archive #() — its resolved
         sha256 is '' (no published archive)."
        <category: 'install entries'>
        ^'#(#''parley-index'' 1 #name ''a'' #version ''1.0.0'' #summary '''' #author '''' #license '''' #fileIns #(''A.st'') #dependencies #(#(''c'' ''>=1.0.0 <3.0.0'')) #archive #())',
            SourceFixtures newline
    ]

    InstallFixtures class >> installEntryB [
        "b 1.0.0 -> c '>=2.0.0 <3.0.0', archive b-1.0.0.star, true digest."
        <category: 'install entries'>
        ^'#(#''parley-index'' 1 #name ''b'' #version ''1.0.0'' #summary '''' #author '''' #license '''' #fileIns #(''B.st'') #dependencies #(#(''c'' ''>=2.0.0 <3.0.0'')) #archive #(''b-1.0.0.star'' #sha256 ''',
            self digestB, '''))', SourceFixtures newline
    ]

    InstallFixtures class >> installEntryC15 [
        <category: 'install entries'>
        ^'#(#''parley-index'' 1 #name ''c'' #version ''1.5.0'' #summary '''' #author '''' #license '''' #fileIns #(''C.st'') #dependencies #() #archive #(''c-1.5.0.star'' #sha256 ''',
            self digestC15, '''))', SourceFixtures newline
    ]

    InstallFixtures class >> installEntryC24 [
        <category: 'install entries'>
        ^'#(#''parley-index'' 1 #name ''c'' #version ''2.4.0'' #summary '''' #author '''' #license '''' #fileIns #(''C.st'') #dependencies #() #archive #(''c-2.4.0.star'' #sha256 ''',
            self digestC24, '''))', SourceFixtures newline
    ]

    InstallFixtures class >> installEntryC30 [
        <category: 'install entries'>
        ^'#(#''parley-index'' 1 #name ''c'' #version ''3.0.0'' #summary '''' #author '''' #license '''' #fileIns #(''C.st'') #dependencies #() #archive #(''c-3.0.0.star'' #sha256 ''',
            self digestC30, '''))', SourceFixtures newline
    ]

    InstallFixtures class >> installEntryEMissingArchive [
        "e 1.0.0 whose #archive names e-1.0.0.star — a file the
         fixtures never write (the S8 missing-archive shape)."
        <category: 'install entries'>
        ^'#(#''parley-index'' 1 #name ''e'' #version ''1.0.0'' #summary '''' #author '''' #license '''' #fileIns #(''E.st'') #dependencies #() #archive #(''e-1.0.0.star'' #sha256 ''',
            self digestE, '''))', SourceFixtures newline
    ]

    "---- populating fixture directories ----"

    InstallFixtures class >> populateInstallDiamondIn: aDirPath [
        "The five diamond entries with true digests, plus the three
         resolved archives (a 1.0.0, b 1.0.0, c 2.4.0) as opaque bytes,
         side by side in the flat directory."
        <category: 'populating'>
        SourceFixtures write: self installEntryA
            toFile: 'a-1.0.0.st' in: aDirPath.
        SourceFixtures write: self installEntryB
            toFile: 'b-1.0.0.st' in: aDirPath.
        SourceFixtures write: self installEntryC15
            toFile: 'c-1.5.0.st' in: aDirPath.
        SourceFixtures write: self installEntryC24
            toFile: 'c-2.4.0.st' in: aDirPath.
        SourceFixtures write: self installEntryC30
            toFile: 'c-3.0.0.st' in: aDirPath.
        self writeArchivesIn: aDirPath
    ]

    InstallFixtures class >> populateInstallDiamondWithEmptyAIn: aDirPath [
        "The S14 shape: as populateInstallDiamondIn: but a's entry
         declares #archive #() (and no a archive is written)."
        <category: 'populating'>
        SourceFixtures write: self installEntryAEmptyArchive
            toFile: 'a-1.0.0.st' in: aDirPath.
        SourceFixtures write: self installEntryB
            toFile: 'b-1.0.0.st' in: aDirPath.
        SourceFixtures write: self installEntryC15
            toFile: 'c-1.5.0.st' in: aDirPath.
        SourceFixtures write: self installEntryC24
            toFile: 'c-2.4.0.st' in: aDirPath.
        SourceFixtures write: self installEntryC30
            toFile: 'c-3.0.0.st' in: aDirPath.
        SourceFixtures write: self archiveBytesB
            toFile: 'b-1.0.0.star' in: aDirPath.
        SourceFixtures write: self archiveBytesC24
            toFile: 'c-2.4.0.star' in: aDirPath
    ]

    InstallFixtures class >> writeArchivesIn: aDirPath [
        "The three resolved archives as opaque byte strings."
        <category: 'populating'>
        SourceFixtures write: self archiveBytesA
            toFile: 'a-1.0.0.star' in: aDirPath.
        SourceFixtures write: self archiveBytesB
            toFile: 'b-1.0.0.star' in: aDirPath.
        SourceFixtures write: self archiveBytesC24
            toFile: 'c-2.4.0.star' in: aDirPath
    ]

    InstallFixtures class >> addMissingArchiveEntryTo: aDirPath [
        "Add the e 1.0.0 entry whose named archive file does not exist."
        <category: 'populating'>
        SourceFixtures write: self installEntryEMissingArchive
            toFile: 'e-1.0.0.st' in: aDirPath
    ]

    InstallFixtures class >> addEmptyArchiveEntryTo: aDirPath [
        "Add the settled d 1.0.0 entry with #archive #() (the Sprint 4
         lateEntryDContents string) — the S6 no-published-archive shape."
        <category: 'populating'>
        SourceFixtures write: SourceFixtures lateEntryDContents
            toFile: 'd-1.0.0.st' in: aDirPath
    ]

    "---- tampering ----"

    InstallFixtures class >> tamperArchiveBIn: aDirPath [
        "Overwrite b's archive file with different bytes, so it no
         longer matches its entry's pinned digest."
        <category: 'tampering'>
        SourceFixtures write: self tamperedBytesB
            toFile: 'b-1.0.0.star' in: aDirPath
    ]

    InstallFixtures class >> tamperStoredHash: aHexString in: aStoreRoot [
        "Overwrite the stored <hash>.star file with different bytes —
         the corruption-detection fixture."
        <category: 'tampering'>
        SourceFixtures write: 'corrupted store bytes'
            toFile: aHexString, '.star' in: aStoreRoot
    ]

    "---- store roots under tmp/ ----"

    InstallFixtures class >> storeRootNamed: aLabel [
        "Answer the path tmp/parley-<aLabel> WITHOUT creating it — the
         ContentStore creates its root lazily on first store:. tmp/
         itself is ensured so lazy creation needs only one level;
         leftovers from a crashed run are swept first."
        <category: 'store roots'>
        | path |
        path := 'tmp/parley-', aLabel.
        SourceFixtures removeTree: path.
        (File name: 'tmp') exists ifFalse: [Directory create: 'tmp'].
        ^path
    ]

    InstallFixtures class >> starFileCountIn: aStoreRoot [
        "How many .star files the store root holds; 0 for an absent
         root — the idempotence and no-op oracles."
        <category: 'store roots'>
        | dir |
        dir := File name: aStoreRoot.
        (dir exists and: [dir isDirectory]) ifFalse: [^0].
        ^(dir files select: [:each | each name endsWith: '.star']) size
    ]
]

Object subclass: FailingFetchSource [

    <comment: 'The S16 cache-hit test double: a source whose
fetch:version: always signals, proving a pre-populated store satisfies
an install without the fetch path ever being touched.'>

    fetch: aPackageName version: aVersion [
        <category: 'source protocol'>
        ^self error: 'cache-hit law violated: fetch:version: was touched for ',
            aPackageName
    ]
]

Namespace current: Smalltalk.
