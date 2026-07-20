"Parley Sprint 5 — Installer laws (Doc D §1/§4/§5; issue #7 S12-S16).

 Protocol decisions pinned here (posted on issue #7 for confirmation):
   - constructor: Installer source: aPackageSource store: aContentStore;
     both collaborators held immutably; install: aResolution is the one
     public operation — an InstalledSet on a clean pass, ONE signaled
     InstallError otherwise;
   - per-triple pipeline order (sorted package-name order): an empty
     sha256 '' is a problem before anything else (nothing to verify
     against, no fetch); then the cache-hit check (a contained hash
     skips fetch entirely); then fetch (a SourceError from the source
     becomes a batched problem; any other error propagates); then
     verify-then-store (a mismatch is a batched problem and the bytes
     never enter the store);
   - InstallError: 'problems' array in sorted package-name order;
     messageText 'Install has <n> problem(s): ' with problems joined
     by '; ' (the house style). The three problem wordings, exact:
       empty sha256:
         '<name> <version>: no published archive - the resolution
          carries an empty sha256'
       fetch failure:
         '<name> <version>: fetch failed - <the SourceError''s
          messageText>'
       hash mismatch:
         '<name> <version>: hash mismatch - expected <expected digest>
          but the fetched archive hashes to <actual digest>'
     (each rendered on one line; versions render via Version
     printString);
   - InstalledSet: immutable; one (package name, Version, sha256,
     store path) tuple per resolved package; surface: packageNames
     (sorted Array), versionOf:, sha256For:, pathFor:, and
     registrationCommandsFor: (the plan lives on the set, Doc D §4);
     NO value equality - `=` stays identity (the decision-23
     precedent); tests compare tuple fields;
   - registrationCommandsFor: aTargetDir answers an Array of Strings,
     one per package in sorted name order, each exactly
     'gst-package --install --target-directory <aTargetDir> <store
     path>' - a pure value; no process is ever spawned."

Namespace current: Parley.

TestCase subclass: InstallerTest [
    | fixtureDirs |

    <comment: 'Laws for the Installer pipeline per Doc D §1/§4:
happy-path set and cache contents, batching into one InstallError in
package-name order, verify-then-store, the cache-hit law, re-install
no-op, and the registration plan. All fixtures under tmp/, removed in
tearDown.'>

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
        "The settled diamond root resolved against the source's
         snapshot: a 1.0.0, b 1.0.0, c 2.4.0 with the true digests."
        | resolution |
        resolution := ResolverFixtures
            resolve: ResolverFixtures diamondRoot
            against: aSource snapshot.
        self assert: resolution isResolution.
        ^resolution
    ]

    diamondResolutionByHand [
        "The same resolved value, hand-built - for shapes where the
         source must never be scanned (the cache-hit law)."
        | triples |
        triples := Dictionary new.
        triples at: 'a' put: (Array
            with: (self version: '1.0.0') with: InstallFixtures digestA).
        triples at: 'b' put: (Array
            with: (self version: '1.0.0') with: InstallFixtures digestB).
        triples at: 'c' put: (Array
            with: (self version: '2.4.0') with: InstallFixtures digestC24).
        ^Resolution root: 'my-app' triples: triples
    ]

    problemsFrom: aBlock [
        "The problems array of the InstallError aBlock signals; fails
         when no error, or a non-InstallError, is signaled."
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
        "The three (name, version, digest, store path) tuples of the
         resolved diamond, field by field (no value equality on the
         set - the decision-23 precedent)."
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

    emptyShaProblemForA [
        ^'a 1.0.0: no published archive - the resolution carries an empty sha256'
    ]

    mismatchProblemForB [
        ^'b 1.0.0: hash mismatch - expected ', InstallFixtures digestB,
            ' but the fetched archive hashes to ',
            InstallFixtures tamperedDigestB
    ]

    "---- the happy path (S12) ----"

    testHappyPathFillsTheStoreAndAnswersTheSet [
        | dir root source store set |
        dir := self installDiamondDir: 'law-inst-happy'.
        root := self freshStoreRoot: 'law-inst-happy-store'.
        source := DirectorySource on: dir.
        store := ContentStore on: root.
        set := (Installer source: source store: store)
            install: (self resolutionAgainst: source).
        self assertDiamondTuplesOf: set against: root.
        self assert: (store containsHash: InstallFixtures digestA).
        self assert: (store containsHash: InstallFixtures digestB).
        self assert: (store containsHash: InstallFixtures digestC24).
        self assert: (InstallFixtures starFileCountIn: root) = 3.
        self assert: (store verifyHash: InstallFixtures digestA).
        self assert: (store verifyHash: InstallFixtures digestB).
        self assert: (store verifyHash: InstallFixtures digestC24)
    ]

    "---- verify-then-store: a mismatch never enters the store (S13) ----"

    testHashMismatchIsABatchedProblemAndNeverEntersTheStore [
        | dir root source store problems |
        dir := self installDiamondDir: 'law-inst-mismatch'.
        root := self freshStoreRoot: 'law-inst-mismatch-store'.
        InstallFixtures tamperArchiveBIn: dir.
        source := DirectorySource on: dir.
        store := ContentStore on: root.
        problems := self problemsFrom:
            [(Installer source: source store: store)
                install: (self resolutionAgainst: source)].
        self assert: problems size = 1.
        self assert: (problems at: 1) = self mismatchProblemForB.
        self deny: (store containsHash: InstallFixtures digestB).
        self deny: (store containsHash: InstallFixtures tamperedDigestB).
        self assert: (store containsHash: InstallFixtures digestA)
            description: 'the clean packages are still installed'.
        self assert: (store containsHash: InstallFixtures digestC24)
            description: 'the clean packages are still installed'
    ]

    "---- batching: ONE error, package-name order, clean work still done (S14) ----"

    testProblemsBatchIntoOneInstallErrorInPackageNameOrder [
        | dir root source store problems |
        dir := SourceFixtures directoryNamed: 'law-inst-batch'.
        fixtureDirs add: dir.
        InstallFixtures populateInstallDiamondWithEmptyAIn: dir.
        InstallFixtures tamperArchiveBIn: dir.
        root := self freshStoreRoot: 'law-inst-batch-store'.
        source := DirectorySource on: dir.
        store := ContentStore on: root.
        problems := self problemsFrom:
            [(Installer source: source store: store)
                install: (self resolutionAgainst: source)].
        self assert: problems size = 2.
        self assert: (problems at: 1) = self emptyShaProblemForA.
        self assert: (problems at: 2) = self mismatchProblemForB.
        self assert: (store containsHash: InstallFixtures digestC24)
            description: 'c - the clean package - was fetched, verified and stored'.
        self assert: (InstallFixtures starFileCountIn: root) = 1
    ]

    testInstallErrorMessageTextFollowsTheHouseStyle [
        | dir root source store |
        dir := SourceFixtures directoryNamed: 'law-inst-message'.
        fixtureDirs add: dir.
        InstallFixtures populateInstallDiamondWithEmptyAIn: dir.
        InstallFixtures tamperArchiveBIn: dir.
        root := self freshStoreRoot: 'law-inst-message-store'.
        source := DirectorySource on: dir.
        store := ContentStore on: root.
        [(Installer source: source store: store)
            install: (self resolutionAgainst: source).
         self assert: false description: 'expected an InstallError']
            on: Error
            do: [:e |
                self assert: (e isKindOf: InstallError).
                self assert: e messageText
                    = ('Install has 2 problem(s): ',
                        self emptyShaProblemForA, '; ',
                        self mismatchProblemForB)]
    ]

    "---- a fetch failure is a batched problem carrying the source's message ----"

    testFetchFailureIsABatchedProblemCarryingTheSourceMessage [
        | dir root source store triples problems |
        dir := self installDiamondDir: 'law-inst-fetchfail'.
        InstallFixtures addMissingArchiveEntryTo: dir.
        root := self freshStoreRoot: 'law-inst-fetchfail-store'.
        source := DirectorySource on: dir.
        store := ContentStore on: root.
        triples := Dictionary new.
        triples at: 'e' put: (Array
            with: (self version: '1.0.0') with: InstallFixtures digestE).
        problems := self problemsFrom:
            [(Installer source: source store: store)
                install: (Resolution root: 'my-app' triples: triples)].
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = 'e 1.0.0: fetch failed - Source directory has 1 problem(s): e-1.0.0.star: missing or unreadable archive file'.
        self deny: (store containsHash: InstallFixtures digestE)
    ]

    "---- the cache-hit law: hits never touch the fetch path (S16) ----"

    testCacheHitSkipsFetchEntirely [
        | root store set |
        root := self freshStoreRoot: 'law-inst-cachehit-store'.
        store := ContentStore on: root.
        store store: InstallFixtures archiveBytesA.
        store store: InstallFixtures archiveBytesB.
        store store: InstallFixtures archiveBytesC24.
        set := (Installer source: FailingFetchSource new store: store)
            install: self diamondResolutionByHand.
        self assertDiamondTuplesOf: set against: root.
        self assert: (InstallFixtures starFileCountIn: root) = 3
    ]

    "---- re-install is a no-op answering an equal-content set ----"

    testReInstallIsANoOpAnsweringAnEqualContentSet [
        | dir root source store installer first second |
        dir := self installDiamondDir: 'law-inst-noop'.
        root := self freshStoreRoot: 'law-inst-noop-store'.
        source := DirectorySource on: dir.
        store := ContentStore on: root.
        installer := Installer source: source store: store.
        first := installer install: (self resolutionAgainst: source).
        second := installer install: (self resolutionAgainst: source).
        self assertDiamondTuplesOf: first against: root.
        self assertDiamondTuplesOf: second against: root.
        self assert: (InstallFixtures starFileCountIn: root) = 3.
        self deny: first = second
            description: 'InstalledSet carries no value equality - the decision-23 precedent'
    ]

    "---- the registration plan is a pure pinned value (S15) ----"

    testRegistrationPlanRendersThePinnedCommandLines [
        | dir root source store set commands |
        dir := self installDiamondDir: 'law-inst-plan'.
        root := self freshStoreRoot: 'law-inst-plan-store'.
        source := DirectorySource on: dir.
        store := ContentStore on: root.
        set := (Installer source: source store: store)
            install: (self resolutionAgainst: source).
        commands := set registrationCommandsFor: 'tmp/parley-target'.
        self assert: commands size = 3.
        self assert: (commands at: 1)
            = ('gst-package --install --target-directory tmp/parley-target ',
                root, '/', InstallFixtures digestA, '.star').
        self assert: (commands at: 2)
            = ('gst-package --install --target-directory tmp/parley-target ',
                root, '/', InstallFixtures digestB, '.star').
        self assert: (commands at: 3)
            = ('gst-package --install --target-directory tmp/parley-target ',
                root, '/', InstallFixtures digestC24, '.star')
    ]
]

Namespace current: Smalltalk.
