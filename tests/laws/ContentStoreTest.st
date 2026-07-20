"Parley Sprint 5 — ContentStore laws (Doc D §3/§5; issue #7 S9-S11).

 Protocol decisions pinned here (posted on issue #7 for confirmation):
   - constructor: ContentStore on: <root path String>; the root path is
     held immutably; the public surface is exactly Doc D §3
     (store:, containsHash:, pathForHash:, verifyHash:);
   - laziness: 'on:' performs no I/O and creates nothing; the root
     directory is created on the first store: — one directory level
     (the root's parent must already exist; fixtures guarantee tmp/);
   - store: answers the 64-hex digest of the stored bytes; the file
     lands as <root>/<digest>.star, byte-identical to what was stored;
   - pathForHash: answers exactly <root>/<hash>.star when the file is
     present and nil when absent;
   - verifyHash: answers false for a tampered file, an absent hash and
     the empty string ''; containsHash: '' is false (Doc D §3: the
     empty hash is never a valid store key);
   - the store never deletes: verifyHash: is detection only."

Namespace current: Parley.

TestCase subclass: ContentStoreTest [
    | fixtureDirs |

    <comment: 'Laws for the content-addressed ContentStore per
Doc D §3/§5: content addressing, idempotent store:, lazy root
creation, and verifyHash: on intact/tampered/absent/empty hashes.
Store roots live under tmp/ and are removed in tearDown.'>

    setUp [
        fixtureDirs := OrderedCollection new
    ]

    tearDown [
        fixtureDirs isNil ifTrue: [^self].
        fixtureDirs do: [:each | SourceFixtures removeTree: each].
        fixtureDirs := nil
    ]

    freshStoreRoot: aLabel [
        | path |
        path := InstallFixtures storeRootNamed: aLabel.
        fixtureDirs add: path.
        ^path
    ]

    "---- content addressing (S9) ----"

    testStoreAnswersTheBytesTrueDigest [
        | root store |
        root := self freshStoreRoot: 'law-store-digest'.
        store := ContentStore on: root.
        self assert: (store store: InstallFixtures archiveBytesA)
            = InstallFixtures digestA.
        self assert: (store store: InstallFixtures archiveBytesB)
            = InstallFixtures digestB
    ]

    testStoredFileLandsAsDigestDotStarByteIdentical [
        | root store path |
        root := self freshStoreRoot: 'law-store-file'.
        store := ContentStore on: root.
        store store: InstallFixtures archiveBytesA.
        self assert: (store containsHash: InstallFixtures digestA).
        path := store pathForHash: InstallFixtures digestA.
        self assert: path = (root, '/', InstallFixtures digestA, '.star').
        self assert: (File name: path) exists.
        self assert: (File name: path) contents
            = InstallFixtures archiveBytesA
    ]

    testRootIsCreatedLazilyOnFirstStore [
        | root store |
        root := self freshStoreRoot: 'law-store-lazy'.
        store := ContentStore on: root.
        self deny: (File name: root) exists
            description: 'on: must not create the root'.
        store store: InstallFixtures archiveBytesA.
        self assert: ((File name: root) exists
            and: [(File name: root) isDirectory])
    ]

    "---- idempotence (S10) ----"

    testStoringIdenticalBytesTwiceIsIdempotent [
        | root store first second |
        root := self freshStoreRoot: 'law-store-idem'.
        store := ContentStore on: root.
        first := store store: InstallFixtures archiveBytesA.
        second := store store: InstallFixtures archiveBytesA.
        self assert: first = second.
        self assert: first = InstallFixtures digestA.
        self assert: (InstallFixtures starFileCountIn: root) = 1.
        self assert: (File name: (store pathForHash: first)) contents
            = InstallFixtures archiveBytesA
    ]

    "---- verifyHash: intact / tampered / absent / '' (S11) ----"

    testVerifyHashTrueOnAnIntactEntry [
        | root store |
        root := self freshStoreRoot: 'law-verify-intact'.
        store := ContentStore on: root.
        store store: InstallFixtures archiveBytesA.
        self assert: (store verifyHash: InstallFixtures digestA)
    ]

    testVerifyHashFalseOnATamperedEntry [
        | root store |
        root := self freshStoreRoot: 'law-verify-tampered'.
        store := ContentStore on: root.
        store store: InstallFixtures archiveBytesA.
        InstallFixtures tamperStoredHash: InstallFixtures digestA in: root.
        self deny: (store verifyHash: InstallFixtures digestA).
        self assert: (store containsHash: InstallFixtures digestA)
            description: 'detection only - the store never deletes'
    ]

    testVerifyHashFalseOnAnAbsentHash [
        | root store |
        root := self freshStoreRoot: 'law-verify-absent'.
        store := ContentStore on: root.
        store store: InstallFixtures archiveBytesA.
        self deny: (store verifyHash: InstallFixtures digestB)
    ]

    testEmptyHashIsNeverAValidStoreKey [
        | root store |
        root := self freshStoreRoot: 'law-verify-empty'.
        store := ContentStore on: root.
        self deny: (store containsHash: '').
        self deny: (store verifyHash: '').
        store store: InstallFixtures archiveBytesA.
        self deny: (store containsHash: '').
        self deny: (store verifyHash: '')
    ]

    "---- pathForHash: absent ----"

    testPathForHashAnswersNilWhenAbsent [
        | root store |
        root := self freshStoreRoot: 'law-path-absent'.
        store := ContentStore on: root.
        self assert: (store pathForHash: InstallFixtures digestA) isNil.
        store store: InstallFixtures archiveBytesB.
        self assert: (store pathForHash: InstallFixtures digestA) isNil.
        self deny: (store pathForHash: InstallFixtures digestB) isNil
    ]
]

Namespace current: Smalltalk.
