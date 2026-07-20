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
        | digest file stream |
        digest := Sha256 hexDigestOf: aByteString.
        self ensureRoot.
        file := File name: (self starPathFor: digest).
        file exists ifFalse: [
            stream := file writeStream.
            [stream nextPutAll: aByteString] ensure: [stream close]].
        ^digest
    ]

    containsHash: aHexString [
        "Whether <hash>.star exists under the root; always false for
         the empty hash '' (a no-archive release is never a store key)."
        <category: 'accessing'>
        aHexString isEmpty ifTrue: [^false].
        ^(File name: (self starPathFor: aHexString)) exists
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
            (File name: (self starPathFor: aHexString)) contents)
            = aHexString
    ]

    starPathFor: aHexString [
        "Private — the store path of the hash: <root>/<hash>.star."
        <category: 'private'>
        ^root, '/', aHexString, '.star'
    ]

    ensureRoot [
        "Private — lazy root creation on the first store:."
        <category: 'private'>
        (File name: root) exists ifFalse: [Directory create: root]
    ]
]

Namespace current: Smalltalk.
