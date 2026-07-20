"Parley Sprint 5 — acceptance scenarios S1-S17 from GitHub issue #7.
 Each scenario Sn maps to exactly one selector starting with testSn_
 (enforced by the wrap traceability gate).

 The Installer value pipeline (Doc D): the pure FIPS 180-4 Sha256
 primitive (S1-S4), the real DirectorySource fetch:version: (S5-S8),
 the content-addressed ContentStore (S9-S11), the Installer with
 batched InstallError, immutable InstalledSet and the registration
 plan (S12-S16), and the end-to-end pipeline with true digests on
 disk plus the re-install no-op (S17).

 Exact wordings and the e2e lockfile oracle are pinned in the Sprint 5
 law suites and here (posted on issue #7 for confirmation); the four
 Sha256 vectors and every fixture digest are operator-verified against
 sha256sum. No process is ever spawned by these tests: the S15
 registration plan is asserted purely as string values."

Namespace current: Parley.

TestCase subclass: Sprint5AcceptanceTest [
    | fixtureDirs |

    <comment: 'Acceptance scenarios for Sprint 5: Sha256, real fetch,
ContentStore, Installer, InstallError, InstalledSet and the
registration plan. Fixture directories and store roots live under
tmp/ and are removed in tearDown.'>

    setUp [
        fixtureDirs := OrderedCollection new
    ]

    tearDown [
        fixtureDirs isNil ifTrue: [^self].
        fixtureDirs do: [:each | SourceFixtures removeTree: each].
        fixtureDirs := nil
    ]

    installDiamondDir: aLabel [
        | path |
        path := SourceFixtures directoryNamed: aLabel.
        fixtureDirs add: path.
        InstallFixtures populateInstallDiamondIn: path.
        ^path
    ]

    freshDir: aLabel [
        | path |
        path := SourceFixtures directoryNamed: aLabel.
        fixtureDirs add: path.
        ^path
    ]

    freshStoreRoot: aLabel [
        | path |
        path := InstallFixtures storeRootNamed: aLabel.
        fixtureDirs add: path.
        ^path
    ]

    version: aString [
        ^Version fromString: aString
    ]

    resolutionAgainst: aSource [
        | resolution |
        resolution := ResolverFixtures
            resolve: ResolverFixtures diamondRoot
            against: aSource snapshot.
        self assert: resolution isResolution.
        ^resolution
    ]

    sourceProblemsFrom: aBlock [
        [aBlock value.
         self assert: false description: 'expected a SourceError']
            on: Error
            do: [:e |
                self assert: (e isKindOf: SourceError)
                    description: 'expected a SourceError'.
                ^e problems].
        ^#()
    ]

    installProblemsFrom: aBlock [
        [aBlock value.
         self assert: false description: 'expected an InstallError']
            on: Error
            do: [:e |
                self assert: (e isKindOf: InstallError)
                    description: 'expected an InstallError'.
                ^e problems].
        ^#()
    ]

    assertDiamondTuplesOf: aSet against: aStoreRoot [
        self assert: aSet packageNames = #('a' 'b' 'c').
        self assert: (aSet versionOf: 'a') = (self version: '1.0.0').
        self assert: (aSet versionOf: 'b') = (self version: '1.0.0').
        self assert: (aSet versionOf: 'c') = (self version: '2.4.0').
        self assert: (aSet sha256For: 'a') = InstallFixtures digestA.
        self assert: (aSet sha256For: 'b') = InstallFixtures digestB.
        self assert: (aSet sha256For: 'c') = InstallFixtures digestC24.
        self assert: (aSet pathFor: 'a')
            = (aStoreRoot, '/', InstallFixtures digestA, '.star').
        self assert: (aSet pathFor: 'b')
            = (aStoreRoot, '/', InstallFixtures digestB, '.star').
        self assert: (aSet pathFor: 'c')
            = (aStoreRoot, '/', InstallFixtures digestC24, '.star')
    ]

    pinnedLockString [
        "The e2e lockfile oracle: the Sprint 2/4 canonical shape now
         carrying the three TRUE archive digests (operator-verified
         against sha256sum)."
        ^'#(#''parley-lock'' 1 #root ''my-app'' #packages #(#(''a'' ''1.0.0'' #sha256 ''ca830a9b7589b772e4cde0add3254541a1e5b537ac0aadda4f1441ed11da23ca'') #(''b'' ''1.0.0'' #sha256 ''4da43d910afd9d0b85a20c0bf6577ce34e4d5992adaa27a7bd661f5816b2c27f'') #(''c'' ''2.4.0'' #sha256 ''a580ed8ad29366bfbdd4a8ce072b4f13dacf14633b74fd45c5b88909ab21256e'')))',
            (String with: Character nl)
    ]

    "---- S1-S4: the pinned Sha256 vectors ----"

    testS1_sha256OfTheEmptyString [
        self assert: (Sha256 hexDigestOf: '')
            = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
    ]

    testS2_sha256OfAbc [
        self assert: (Sha256 hexDigestOf: 'abc')
            = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
    ]

    testS3_sha256OfTheNistTwoBlockMessage [
        self assert: (Sha256 hexDigestOf:
                'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq')
            = '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1'
    ]

    testS4_sha256AtAnExactBlockBoundary [
        self assert: (Sha256 hexDigestOf: (String new: 64 withAll: $a))
            = 'ffe054fe7ae0cb6dc65c3af9b61d5209f439851db43d0ba5997337df154668eb'
    ]

    "---- S5-S8: the real fetch ----"

    testS5_fetchAnswersTheArchiveFilesExactBytes [
        | source |
        source := DirectorySource on: (self installDiamondDir: 's5-fetch').
        self assert: (source fetch: 'a' version: (self version: '1.0.0'))
            = InstallFixtures archiveBytesA
    ]

    testS6_fetchWithNoPublishedArchiveFails [
        | dir problems |
        dir := self installDiamondDir: 's6-noarchive'.
        InstallFixtures addEmptyArchiveEntryTo: dir.
        problems := self sourceProblemsFrom:
            [(DirectorySource on: dir)
                fetch: 'd' version: (self version: '1.0.0')].
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = 'd 1.0.0: no published archive - the entry declares #archive #()'
    ]

    testS7_fetchForAnUnknownPackageVersionFails [
        | problems |
        problems := self sourceProblemsFrom:
            [(DirectorySource on: (self installDiamondDir: 's7-ghost'))
                fetch: 'ghost' version: (self version: '1.0.0')].
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = 'ghost 1.0.0: unknown (package, version) - the source directory declares no entry for it'
    ]

    testS8_fetchWithTheNamedArchiveFileMissingFails [
        | dir problems |
        dir := self installDiamondDir: 's8-missingfile'.
        InstallFixtures addMissingArchiveEntryTo: dir.
        problems := self sourceProblemsFrom:
            [(DirectorySource on: dir)
                fetch: 'e' version: (self version: '1.0.0')].
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = 'e-1.0.0.star: missing or unreadable archive file'
    ]

    "---- S9-S11: the content-addressed store ----"

    testS9_theStoreIsContentAddressed [
        | root store digest path |
        root := self freshStoreRoot: 's9-store'.
        store := ContentStore on: root.
        digest := store store: InstallFixtures archiveBytesA.
        self assert: digest = InstallFixtures digestA.
        self assert: (store containsHash: digest).
        path := store pathForHash: digest.
        self assert: path = (root, '/', digest, '.star').
        self assert: (File name: path) contents
            = InstallFixtures archiveBytesA
    ]

    testS10_storingIsIdempotent [
        | root store first second |
        root := self freshStoreRoot: 's10-store'.
        store := ContentStore on: root.
        first := store store: InstallFixtures archiveBytesA.
        second := store store: InstallFixtures archiveBytesA.
        self assert: first = second.
        self assert: (InstallFixtures starFileCountIn: root) = 1
    ]

    testS11_corruptionIsDetected [
        | root store |
        root := self freshStoreRoot: 's11-store'.
        store := ContentStore on: root.
        store store: InstallFixtures archiveBytesA.
        store store: InstallFixtures archiveBytesB.
        InstallFixtures tamperStoredHash: InstallFixtures digestA in: root.
        self deny: (store verifyHash: InstallFixtures digestA).
        self assert: (store verifyHash: InstallFixtures digestB).
        self deny: (store verifyHash: InstallFixtures digestC24).
        self deny: (store verifyHash: '')
    ]

    "---- S12-S16: the installer ----"

    testS12_installerHappyPathFillsTheCacheAndAnswersTheSet [
        | dir root source store set |
        dir := self installDiamondDir: 's12-entries'.
        root := self freshStoreRoot: 's12-store'.
        source := DirectorySource on: dir.
        store := ContentStore on: root.
        set := (Installer source: source store: store)
            install: (self resolutionAgainst: source).
        self assertDiamondTuplesOf: set against: root.
        self assert: (store containsHash: InstallFixtures digestA).
        self assert: (store containsHash: InstallFixtures digestB).
        self assert: (store containsHash: InstallFixtures digestC24).
        self assert: (InstallFixtures starFileCountIn: root) = 3
    ]

    testS13_hashMismatchIsBatchedAndNeverEntersTheStore [
        | dir root source store problems |
        dir := self installDiamondDir: 's13-entries'.
        root := self freshStoreRoot: 's13-store'.
        InstallFixtures tamperArchiveBIn: dir.
        source := DirectorySource on: dir.
        store := ContentStore on: root.
        problems := self installProblemsFrom:
            [(Installer source: source store: store)
                install: (self resolutionAgainst: source)].
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = ('b 1.0.0: hash mismatch - expected ',
                InstallFixtures digestB,
                ' but the fetched archive hashes to ',
                InstallFixtures tamperedDigestB).
        self deny: (store containsHash: InstallFixtures digestB).
        self deny: (store containsHash: InstallFixtures tamperedDigestB)
    ]

    testS14_multipleProblemsBatchIntoOneErrorInPackageNameOrder [
        | dir root source store problems |
        dir := self freshDir: 's14-entries'.
        InstallFixtures populateInstallDiamondWithEmptyAIn: dir.
        InstallFixtures tamperArchiveBIn: dir.
        root := self freshStoreRoot: 's14-store'.
        source := DirectorySource on: dir.
        store := ContentStore on: root.
        problems := self installProblemsFrom:
            [(Installer source: source store: store)
                install: (self resolutionAgainst: source)].
        self assert: problems size = 2.
        self assert: (problems at: 1)
            = 'a 1.0.0: no published archive - the resolution carries an empty sha256'.
        self assert: (problems at: 2)
            = ('b 1.0.0: hash mismatch - expected ',
                InstallFixtures digestB,
                ' but the fetched archive hashes to ',
                InstallFixtures tamperedDigestB).
        self assert: (store containsHash: InstallFixtures digestC24)
            description: 'c - the clean package - was still fetched, verified and stored'
    ]

    testS15_theRegistrationPlanIsAPurePinnedValue [
        | dir root source store set commands |
        dir := self installDiamondDir: 's15-entries'.
        root := self freshStoreRoot: 's15-store'.
        source := DirectorySource on: dir.
        store := ContentStore on: root.
        set := (Installer source: source store: store)
            install: (self resolutionAgainst: source).
        commands := set registrationCommandsFor: 'tmp/parley-s15-target'.
        self assert: commands size = 6.
        self assert: (commands at: 1)
            = ('install -D -m 644 ', root, '/', InstallFixtures digestA,
                '.star tmp/parley-s15-target/.parley-staging/a.star').
        self assert: (commands at: 2)
            = ('gst-package --target-directory tmp/parley-s15-target ',
                'tmp/parley-s15-target/.parley-staging/a.star').
        self assert: (commands at: 3)
            = ('install -D -m 644 ', root, '/', InstallFixtures digestB,
                '.star tmp/parley-s15-target/.parley-staging/b.star').
        self assert: (commands at: 4)
            = ('gst-package --target-directory tmp/parley-s15-target ',
                'tmp/parley-s15-target/.parley-staging/b.star').
        self assert: (commands at: 5)
            = ('install -D -m 644 ', root, '/', InstallFixtures digestC24,
                '.star tmp/parley-s15-target/.parley-staging/c.star').
        self assert: (commands at: 6)
            = ('gst-package --target-directory tmp/parley-s15-target ',
                'tmp/parley-s15-target/.parley-staging/c.star')
    ]

    testS16_cacheHitsSkipFetchEntirely [
        | root store triples set |
        root := self freshStoreRoot: 's16-store'.
        store := ContentStore on: root.
        store store: InstallFixtures archiveBytesA.
        store store: InstallFixtures archiveBytesB.
        store store: InstallFixtures archiveBytesC24.
        triples := Dictionary new.
        triples at: 'a' put: (Array
            with: (self version: '1.0.0') with: InstallFixtures digestA).
        triples at: 'b' put: (Array
            with: (self version: '1.0.0') with: InstallFixtures digestB).
        triples at: 'c' put: (Array
            with: (self version: '2.4.0') with: InstallFixtures digestC24).
        set := (Installer source: FailingFetchSource new store: store)
            install: (Resolution root: 'my-app' triples: triples).
        self assertDiamondTuplesOf: set against: root
    ]

    "---- S17: end-to-end, and re-install is a no-op ----"

    testS17_endToEndResolveLockfileInstallAndReInstallNoOp [
        | entries locks root source store lockPaths first second |
        entries := self installDiamondDir: 's17-entries'.
        locks := self freshDir: 's17-locks'.
        root := self freshStoreRoot: 's17-store'.
        lockPaths := Array with: locks, '/my-app-1.lock'
            with: locks, '/my-app-2.lock'.
        lockPaths do: [:lockPath |
            | resolution stream |
            resolution := self resolutionAgainst:
                (DirectorySource on: entries).
            stream := (File name: lockPath) writeStream.
            [IndexEntryWriter writeLock: resolution on: stream]
                ensure: [stream close]].
        lockPaths do: [:lockPath |
            self assert: (File name: lockPath) contents
                = self pinnedLockString].
        source := DirectorySource on: entries.
        store := ContentStore on: root.
        first := (Installer source: source store: store)
            install: (self resolutionAgainst: source).
        self assertDiamondTuplesOf: first against: root.
        self assert: (store containsHash: InstallFixtures digestA).
        self assert: (store containsHash: InstallFixtures digestB).
        self assert: (store containsHash: InstallFixtures digestC24).
        self assert: (InstallFixtures starFileCountIn: root) = 3.
        second := (Installer source: source store: store)
            install: (self resolutionAgainst: source).
        self assertDiamondTuplesOf: second against: root.
        self assert: (InstallFixtures starFileCountIn: root) = 3
    ]
]

Namespace current: Smalltalk.
