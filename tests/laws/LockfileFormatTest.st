"Parley Sprint 2 — lockfile schema laws (Doc B §5.3-§5.4, §7).

 The writer/reader pair owns both schemas. writeLock: renders canonical
 #'parley-lock' 1 bytes: tag + version first, #root, then #packages
 sorted by package name, exact three-component versions with their
 sha256 hashes, single spaces, single-line, single trailing newline.
 The reader accepts the lock tag; the index-entry path is untouched."

Namespace current: Parley.

TestCase subclass: LockfileFormatTest [

    <comment: 'Law suite for the lockfile micro-format: canonical byte
rendering, byte-stability, lock-tag acceptance and lock round-trip.'>

    diamondResolution [
        ^ResolverFixtures resolve: ResolverFixtures diamondRoot
            against: ResolverFixtures satisfiableDiamondSnapshot
    ]

    lockBytesFor: aResolution [
        | stream |
        stream := WriteStream on: String new.
        IndexEntryWriter writeLock: aResolution on: stream.
        ^stream contents
    ]

    read: aString [
        ^IndexEntryReader readFrom: (ReadStream on: aString)
    ]

    canonicalDiamondLock [
        ^'#(#''parley-lock'' 1 #root ''my-app'' #packages #(#(''a'' ''1.0.0'' #sha256 ''ab12'') #(''b'' ''1.0.0'' #sha256 ''cd34'') #(''c'' ''2.4.0'' #sha256 ''ef56'')))',
            (String with: Character nl)
    ]

    testWriteLockRendersTheCanonicalBytes [
        self assert: (self lockBytesFor: self diamondResolution)
            = self canonicalDiamondLock
    ]

    testWriteLockIsByteStable [
        self assert: (self lockBytesFor: self diamondResolution)
            = (self lockBytesFor: self diamondResolution)
    ]

    testReaderAcceptsTheLockTag [
        | parsed |
        parsed := self read: self canonicalDiamondLock.
        self assert: (parsed at: 1) = #'parley-lock'.
        self assert: (parsed at: 2) = 1.
        self assert: (parsed at: 3) = #root.
        self assert: (parsed at: 4) = 'my-app'.
        self assert: (parsed at: 5) = #packages
    ]

    testReaderRejectsAnUnsupportedLockFormatVersion [
        "Strengthened at red review: the error must NAME the unsupported
         version (mirrors the index-schema test), so this cannot pass via
         the unknown-tag path while the lock tag is still unimplemented."
        [self read: '#(#''parley-lock'' 99 #root ''x'' #packages #())', (String with: Character nl)]
            on: IndexEntryFormatError
            do: [:e |
                self assert: (e messageText indexOfSubCollection: '99') > 0.
                ^self].
        self assert: false
            description: 'accepted an unsupported lock format version'
    ]

    testReaderStillReadsIndexEntriesUnchanged [
        | manifest stream parsed |
        manifest := Parley define: [:pkg |
            pkg name: 'kernel-a'; version: '1.0.0'; fileIns: #('A.st')].
        stream := WriteStream on: String new.
        IndexEntryWriter write: manifest on: stream.
        parsed := self read: stream contents.
        self assert: (parsed at: 1) = #'parley-index'
    ]

    testLockRoundTripsToTheResolutionTriples [
        | resolution parsed packages |
        resolution := self diamondResolution.
        parsed := self read: (self lockBytesFor: resolution).
        packages := parsed at: 6.
        self assert: packages size = resolution packageNames size.
        packages do: [:entry |
            | name |
            name := entry at: 1.
            self assert: (resolution versionOf: name)
                = (Version fromString: (entry at: 2)).
            self assert: (entry at: 3) = #sha256.
            self assert: (resolution sha256Of: name) = (entry at: 4)]
    ]
]

Namespace current: Smalltalk.
