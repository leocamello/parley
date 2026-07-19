"Parley Sprint 3 — pin verification, ApplicationManifest and lock
 read-back laws (Doc C §6 pure half; Doc B §4; issue #5 S7-S13).

 PinVerification is an immutable verdict value, a pure function of
 (root LibraryManifest, lock Resolution): it checks the root manifest's
 constraints ONLY — no snapshot, no resolver, no I/O — and batches every
 problem into one value in manifest-declaration order (the ManifestError
 problems style). ApplicationManifest is the immutable manifest+lock
 association of Doc B §4. Resolution class >> fromLockEntry: is the lock
 read-back path mirroring LibraryManifest fromIndexEntry:."

Namespace current: Parley.

TestCase subclass: PinVerificationTest [

    <comment: 'Law suite for PinVerification (valid, violated, missing
and extra-pin verdicts, problem batching, purity), the
ApplicationManifest value, and the write -> read -> fromLockEntry:
round-trip identity.'>

    version: aString [
        ^Version fromString: aString
    ]

    manifestWith: depPairs [
        ^ResolverFixtures rootWith: depPairs
    ]

    lockWith: entries [
        "entries: array of #(name versionString sha256) triples; the
         root name is my-app throughout."
        | triples |
        triples := Dictionary new.
        entries do: [:e |
            triples at: (e at: 1) put: (Array
                with: (Version fromString: (e at: 2))
                with: (e at: 3))].
        ^Resolution root: 'my-app' triples: triples
    ]

    baselineLock [
        "The S9 lock: a 1.4.0 and b 2.1.0 with their hashes."
        ^self lockWith: #(#('a' '1.4.0' 'ha14') #('b' '2.1.0' 'hb21'))
    ]

    "---- PinVerification verdicts (S9-S13) ----"

    testValidPinsVerify [
        | verdict |
        verdict := PinVerification
            of: (self manifestWith: #(#('a' '^1.0') #('b' '^2.0')))
            lock: self baselineLock.
        self assert: verdict isValid.
        self assert: verdict problems isEmpty
    ]

    testViolatedPinFailsNamingPackagePinAndConstraint [
        | verdict |
        verdict := PinVerification
            of: (self manifestWith: #(#('a' '^2.0') #('b' '^2.0')))
            lock: self baselineLock.
        self deny: verdict isValid.
        self assert: verdict problems size = 1.
        self assert: verdict problems first
            = 'lock pins ''a'' at 1.4.0 outside the manifest constraint >=2.0.0 <3.0.0'
    ]

    testMissingPinFailsNamingThePackage [
        | verdict |
        verdict := PinVerification
            of: (self manifestWith: #(#('a' '^1.0') #('b' '^2.0') #('c' '^1.0')))
            lock: self baselineLock.
        self deny: verdict isValid.
        self assert: verdict problems size = 1.
        self assert: verdict problems first
            = 'manifest dependency ''c'' (>=1.0.0 <2.0.0) is missing from the lock'
    ]

    testExtraTransitivePinsAreValid [
        "Doc C §6: verification checks the root's constraints only —
         transitive pins absent from the root manifest are expected."
        | verdict |
        verdict := PinVerification
            of: (self manifestWith: #(#('a' '^1.0')))
            lock: (self lockWith: #(#('a' '1.4.0' 'ha14') #('x' '3.0.0' 'hx30'))).
        self assert: verdict isValid.
        self assert: verdict problems isEmpty
    ]

    testProblemsAreBatchedInManifestDeclarationOrder [
        "One verdict value carries every problem at once — no exception,
         no early exit — ordered by the manifest's declaration order."
        | verdict |
        verdict := PinVerification
            of: (self manifestWith: #(#('a' '^2.0') #('c' '^1.0')))
            lock: self baselineLock.
        self deny: verdict isValid.
        self assert: verdict problems size = 2.
        self assert: (verdict problems at: 1)
            = 'lock pins ''a'' at 1.4.0 outside the manifest constraint >=2.0.0 <3.0.0'.
        self assert: (verdict problems at: 2)
            = 'manifest dependency ''c'' (>=1.0.0 <2.0.0) is missing from the lock'
    ]

    testVerificationIsAPureDeterministicValue [
        "A pure function of its two arguments: repeated application to
         the same hand-built values answers equal verdicts."
        | manifest first second |
        manifest := self manifestWith: #(#('a' '^2.0') #('c' '^1.0')).
        first := PinVerification of: manifest lock: self baselineLock.
        second := PinVerification of: manifest lock: self baselineLock.
        self assert: first isValid = second isValid.
        self assert: first problems = second problems
    ]

    "---- ApplicationManifest value laws (S7) ----"

    testApplicationManifestAssociatesAndDelegates [
        | lib lock app |
        lib := ResolverFixtures diamondRoot.
        lock := ResolverFixtures resolve: lib
            against: ResolverFixtures satisfiableDiamondSnapshot.
        app := ApplicationManifest manifest: lib lock: lock.
        self assert: app hasLock.
        self assert: app lock = lock.
        self assert: app manifest == lib.
        self assert: app name = lib name.
        self assert: app version = lib version.
        self assert: app summary = lib summary.
        self assert: app author = lib author.
        self assert: app license = lib license.
        self assert: app fileIns = lib fileIns.
        self assert: app dependencies = lib dependencies
    ]

    testApplicationManifestWithoutLock [
        | lib app |
        lib := ResolverFixtures diamondRoot.
        app := ApplicationManifest manifest: lib.
        self deny: app hasLock.
        self assert: app lock isNil.
        self assert: app name = lib name.
        self assert: app version = lib version
    ]

    "---- lock read-back (S8) ----"

    testLockEntryRoundTripsToTheIdenticalResolution [
        "write -> read -> fromLockEntry: = identity, and re-writing the
         reconstruction is byte-identical."
        | resolution bytes parsed rebuilt stream |
        resolution := ResolverFixtures resolve: ResolverFixtures diamondRoot
            against: ResolverFixtures satisfiableDiamondSnapshot.
        stream := WriteStream on: String new.
        IndexEntryWriter writeLock: resolution on: stream.
        bytes := stream contents.
        parsed := IndexEntryReader readFrom: (ReadStream on: bytes).
        rebuilt := Resolution fromLockEntry: parsed.
        self assert: (rebuilt isKindOf: Resolution).
        self assert: rebuilt = resolution.
        self assert: rebuilt rootName = 'my-app'.
        stream := WriteStream on: String new.
        IndexEntryWriter writeLock: rebuilt on: stream.
        self assert: stream contents = bytes
    ]
]

Namespace current: Smalltalk.
