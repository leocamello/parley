"Parley — ContentStore: the content-addressed archive cache.
 Spec: docs/design/installer.md §3; issue #7 S9-S11.
 A flat directory whose filenames ARE the content hashes:
 <sha256>.star — the name is the claim, re-hashing is the audit.
 Holds its root path immutably; the root directory is created lazily
 on the first store: (one level — the root's parent must exist).
 store: is idempotent; verifyHash: is detection only (the store never
 deletes); the empty hash '' is never a valid store key. I/O is
 confined to the store's own root."

Namespace current: Parley.

Object subclass: ContentStore [
    | root |

    <comment: 'The content-addressed cache over one directory: stores
archive bytes under their Sha256 digest as <hash>.star, answers
membership, paths and integrity re-checks. Class-side construction;
the root path is held immutably.'>

    ContentStore class >> on: aRootPath [
        "Answer a store over the directory at aRootPath. No I/O: the
         root is created lazily on the first store:."
        <category: 'instance creation'>
        ^self new setRoot: aRootPath
    ]

    setRoot: aRootPath [
        "Private — initialization from the class-side constructor."
        <category: 'private'>
        root := aRootPath
    ]

    store: aByteString [
        "Hash the bytes, write <hash>.star under the root when absent,
         and answer the hex hash. Idempotent: re-storing identical
         bytes writes nothing new and answers the same hash."
        <category: 'storing'>
        | digest path |
        digest := Sha256 hexDigestOf: aByteString.
        self ensureRoot.
        path := self starPathFor: digest.
        (PathGuard exists: path) ifFalse: [
            PathGuard write: aByteString to: path
                ifRefused: [:each | self refuseStore: each]].
        ^digest
    ]

    containsHash: aHexString [
        "Whether <hash>.star exists under the root; always false for
         the empty hash '' (a no-archive release is never a store key)."
        <category: 'accessing'>
        aHexString isEmpty ifTrue: [^false].
        ^PathGuard exists: (self starPathFor: aHexString)
    ]

    pathForHash: aHexString [
        "The <hash>.star file's path when present, nil when absent."
        <category: 'accessing'>
        ^(self containsHash: aHexString)
            ifTrue: [self starPathFor: aHexString]
            ifFalse: [nil]
    ]

    verifyHash: aHexString [
        "Re-hash the stored file's bytes and answer whether they still
         match the name; false for a tampered file, an absent hash and
         ''. Detection only — repair is an operator action."
        <category: 'accessing'>
        (self containsHash: aHexString) ifFalse: [^false].
        ^(Sha256 hexDigestOf:
            (PathGuard contentsOf: (self starPathFor: aHexString)
                ifRefused: [:each | self refuseRead: each]))
            = aHexString
    ]

    starPathFor: aHexString [
        "Private — the store path of the hash: <root>/<hash>.star."
        <category: 'private'>
        ^root, '/', aHexString, '.star'
    ]

    ensureRoot [
        "Private — lazy root creation on the first store:, through the
         chokepoint (§8 decision 59). The store lives under the
         operator's own .parley/, so a store they cannot write is their
         filesystem and not a defect in Parley — and it answered exit
         70 saying otherwise."
        <category: 'private'>
        ^PathGuard ensureDirectory: root
            ifRefused: [:each | self refuseStore: (PathGuard parentOf: each)]
    ]

    refuseStore: aPath [
        "Private — the cache's declared error for a path it cannot
         write. The store is the install pipeline's, so an InstallError
         is what the §4.2 boundary answers as one line at exit 1."
        <category: 'private'>
        ^InstallError signalProblems: (Array with:
            (PathGuard unwritableLineFor: aPath))
    ]

    refuseRead: aPath [
        "Private — and for a stored archive that cannot be read. The
         store never repairs itself (detection only), so this names the
         file and says nothing it has not checked."
        <category: 'private'>
        ^InstallError signalProblems: (Array with:
            (PathGuard lineFor: aPath saying: PathGuard unreadableTail))
    ]
]

Namespace current: Smalltalk.
