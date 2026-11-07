"Parley Sprint 24 — real transport acceptance, S7-S11.
 Spec: Doc D section 4, Doc F transport/publication seams and the
 approved operator/staging/maintenance-2026-11-07/path-repair-design.md.

 These laws exercise real production seams, never formatted-command
 equality. The package witnesses load actual gst-package-built stars.
 All paths live in isolated tmp/ trees removed recursively on every
 outcome. Git is local; sparse transport uses file://. Declared
 passes-in-RED: none. No test expects third-party tool support for
 tab/newline-bearing gst-package filenames."

Namespace current: Parley.

TestCase subclass: Sprint24TransportAcceptanceTest [
    | fixtureRoots |

    <comment: 'S7-S11: stored archive registration, publication and
consumption, cold git clone, quiet warm update, and sparse metadata
plus archive retrieval across space/apostrophe path boundaries.'>

    setUp [
        fixtureRoots := OrderedCollection new
    ]

    tearDown [
        fixtureRoots isNil ifTrue: [^self].
        fixtureRoots do: [:each | ExecFixtures removeTree: each].
        fixtureRoots := nil
    ]

    root: aLabel [
        | path |
        path := TransportArgumentFixtures freshRootNamed: aLabel.
        fixtureRoots add: path.
        ^path
    ]

    directory: aName in: aRoot [
        ^TransportArgumentFixtures directory: aName in: aRoot
    ]

    testS7_SpacedStoredArchiveAndTargetLoadARealPackage [
        | root bytes store digest target tuples scope proof script |
        root := self root: 's24-transport-s7'.
        bytes := TransportArgumentFixtures probeArchiveLabeled: 's24-transport-s7'.
        store := ContentStore on: root, '/archive store'.
        digest := store store: bytes.
        target := self directory: 'registered packages' in: root.
        tuples := Dictionary new.
        tuples at: 'parley-probe' put: (Array
            with: (Version fromString: '1.0.0')
            with: digest
            with: (store pathForHash: digest)).
        scope := ExecutionScope on: (InstalledSet tuples: tuples)
            target: target runner: ProcessRunner new.
        scope register.
        self assert: (File name: target, '/parley-probe.star') contents
            = bytes.
        proof := root, '/proof.txt'.
        script := root, '/proof.st'.
        SourceFixtures write: (ExecFixtures proofScriptContentsFor: proof)
            toFile: 'proof.st' in: root.
        self assert: (scope run: script) = 0.
        self assert: (File name: proof) contents = 'present'
    ]

    testS8_PublicationAcrossSpaceAndApostrophePathsIsConsumable [
        | root author destination consumer publish install execute cli proof
          archive digest |
        root := self root: 's24-transport-s8'.
        author := self directory: 'author''s project' in: root.
        destination := self directory: 'community''s index' in: root.
        consumer := self directory: 'consumer' in: root.
        PublishFixtures populateGreetingWorkDirIn: author.
        publish := (CommandLine in: author runner: ProcessRunner new)
            run: (Array with: 'publish' with: destination).
        self assert: publish exitCode = 0
            description: publish lines printString.
        archive := destination, '/', PublishFixtures archiveFileName.
        self assert: (File name: archive) exists.
        digest := Sha256 hexDigestOf: (File name: archive) contents.
        self assert: (File name: destination, '/',
                PublishFixtures entryFileName) contents
            = (PublishFixtures greetingEntryWithDigest: digest).
        ExecFixtures writePackage: PublishFixtures greetingRootContents
            in: consumer.
        cli := CommandLine in: consumer runner: ProcessRunner new.
        install := cli run: (Array with: 'install' with: '--source'
            with: destination).
        self assert: install exitCode = 0
            description: install lines printString.
        self assert: install lines = #('kernel-greeting 1.0.0').
        proof := root, '/proof.txt'.
        SourceFixtures
            write: (PublishFixtures greetingProofScriptContentsFor: proof)
            toFile: 'proof.st' in: consumer.
        execute := cli run: (Array with: 'exec' with: 'proof.st'
            with: '--source' with: destination).
        self assert: execute exitCode = 0
            description: execute lines printString.
        self assert: (File name: proof) contents = 'present'
    ]

    testS9_ColdGitSourceWithSpaceAndApostrophePathsResolves [
        | root repo cache source snapshot resolution runner |
        root := self root: 's24-transport-s9'.
        repo := root, '/maintainer''s repository'.
        cache := root, '/consumer''s cache'.
        TransportArgumentFixtures diamondRepositoryAt: repo.
        self deny: (File name: cache) exists.
        runner := TransportCaptureRunner in: root.
        source := GitIndexSource repo: repo cache: cache runner: runner.
        snapshot := source snapshot.
        resolution := ResolverFixtures resolve: ResolverFixtures diamondRoot
            against: snapshot.
        self assert: resolution isResolution.
        self assert: resolution packageNames = #('a' 'b' 'c').
        self assert: (resolution versionOf: 'c')
            = (Version fromString: '2.4.0').
        self assert: (source fetch: 'a' version: (Version fromString: '1.0.0'))
            = InstallFixtures archiveBytesA.
        self assert: runner stdoutContents = ''.
        self assert: runner stderrContents = ''
    ]

    testS10_WarmGitUpdateWithSpaceAndApostrophePathsStaysQuiet [
        | root repo cache source before after runner |
        root := self root: 's24-transport-s10'.
        repo := root, '/maintainer''s repository'.
        cache := root, '/consumer''s cache'.
        TransportArgumentFixtures diamondRepositoryAt: repo.
        TransportArgumentFixtures clone: repo to: cache.
        before := (DirectorySource on: cache) snapshot.
        self assert: (before versionsOf: 'd') isEmpty.
        TransportArgumentFixtures growRepositoryAt: repo.
        runner := TransportCaptureRunner in: root.
        source := GitIndexSource repo: repo cache: cache runner: runner.
        after := source snapshot.
        self assert: (after versionsOf: 'd') asArray
            = (Array with: (Version fromString: '1.0.0')).
        self assert: (before versionsOf: 'd') isEmpty
            description: 'refresh must leave the earlier snapshot immutable'.
        self assert: (File name: cache, '/d-1.0.0.st') contents
            = SourceFixtures lateEntryDContents.
        self assert: runner stdoutContents = ''.
        self assert: runner stderrContents = ''
    ]

    testS11_EncodedFileUrlAndSpacedSparseCacheFetchMetadataAndArchive [
        | root base cache bytes source snapshot version archivePath |
        root := self root: 's24-transport-s11'.
        base := self directory: 'maintainer''s sparse index' in: root.
        "The word after the space starts with file:, so even the RED
         unquoted command cannot reinterpret it as a network URL."
        cache := root, '/sparse file:cache'.
        bytes := TransportArgumentFixtures probeArchiveLabeled: 's24-transport-s11'.
        SparseIndexFixtures populateProbeTreeIn: base bytes: bytes.
        source := (SparseIndexSource
            base: (TransportArgumentFixtures fileUrlFor: base)
            cache: cache runner: ProcessRunner new)
                seededWith: #('parley-probe').
        snapshot := source snapshot.
        version := Version fromString: '1.0.0'.
        self assert: (snapshot versionsOf: 'parley-probe') asArray
            = (Array with: version).
        self assert: (File name: (SparseIndexFixtures
                cachedEntryPathIn: cache for: 'parley-probe' version: '1.0.0'))
            contents = (ExecFixtures probeEntryWithDigest:
                (Sha256 hexDigestOf: bytes)).
        archivePath := SparseIndexFixtures cachedArchivePathIn: cache
            for: 'parley-probe' version: '1.0.0'.
        self deny: (File name: archivePath) exists
            description: 'snapshot must retrieve metadata without archives'.
        self assert: (source fetch: 'parley-probe' version: version) = bytes.
        self assert: (File name: archivePath) contents = bytes
    ]
]

Namespace current: Smalltalk.
