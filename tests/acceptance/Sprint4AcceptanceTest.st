"Parley Sprint 4 — acceptance scenarios S1-S12 from GitHub issue #6.
 Each scenario Sn maps to exactly one selector starting with testSn_
 (enforced by the wrap traceability gate).

 The first real source: DirectorySource reads a directory of index-entry
 files through IndexEntryReader and answers the immutable IndexSnapshot
 at its one I/O moment; problems batch into one SourceError in
 sorted-filename order; fetch:version: is an install-time stub; the
 end-to-end pipeline proves directory -> resolve -> byte-stable lockfile
 on disk (the Sprint 2 S16 pinned lock string is the oracle)."

Namespace current: Parley.

TestCase subclass: Sprint4AcceptanceTest [
    | fixtureDirs |

    <comment: 'Acceptance scenarios for Sprint 4: DirectorySource,
SourceError, and resolve-on-disk. Fixture directories live under tmp/
and are removed in tearDown.'>

    setUp [
        fixtureDirs := OrderedCollection new
    ]

    tearDown [
        fixtureDirs isNil ifTrue: [^self].
        fixtureDirs do: [:each | SourceFixtures removeTree: each].
        fixtureDirs := nil
    ]

    freshDir: aLabel [
        | path |
        path := SourceFixtures directoryNamed: aLabel.
        fixtureDirs add: path.
        ^path
    ]

    diamondDir: aLabel [
        | path |
        path := self freshDir: aLabel.
        SourceFixtures populateDiamondIn: path.
        ^path
    ]

    version: aString [
        ^Version fromString: aString
    ]

    constraint: aString [
        ^VersionConstraint fromString: aString
    ]

    assertVersions: aCollection are: versionStrings [
        | sorted expected |
        sorted := (aCollection asSortedCollection: [:a :b | a < b]) asArray.
        expected := versionStrings collect: [:each | self version: each].
        self assert: sorted = expected
    ]

    problemsFrom: aBlock [
        "The problems array of the SourceError aBlock signals; fails
         when no error, or a non-SourceError, is signaled."
        [aBlock value.
         self assert: false description: 'expected a SourceError']
            on: Error
            do: [:e |
                self assert: (e isKindOf: SourceError)
                    description: 'expected a SourceError'.
                ^e problems].
        ^#()
    ]

    readerRejectionTail [
        "The fixed suffix of every IndexEntryParseError message."
        ^' - the micro-format accepts only literal arrays, strings, symbols and non-negative integers'
    ]

    pinnedLockString [
        "The Sprint 2 S16 canonical lockfile bytes for the satisfiable
         diamond — the settled oracle for S10."
        ^'#(#''parley-lock'' 1 #root ''my-app'' #packages #(#(''a'' ''1.0.0'' #sha256 ''ab12'') #(''b'' ''1.0.0'' #sha256 ''cd34'') #(''c'' ''2.4.0'' #sha256 ''ef56'')))',
            (String with: Character nl)
    ]

    testS1_directoryOfEntryFilesSnapshotsCorrectly [
        | snap deps |
        snap := (DirectorySource on: (self diamondDir: 's1-diamond'))
            snapshot.
        self assert: (snap isKindOf: IndexSnapshot).
        self assertVersions: (snap versionsOf: 'c')
            are: #('1.5.0' '2.4.0' '3.0.0').
        deps := snap dependenciesOf: 'a' version: (self version: '1.0.0').
        self assert: deps size = 1.
        self assert: (deps at: 1) name = 'c'.
        self assert: (deps at: 1) constraint
            = (self constraint: '>=1.0.0 <3.0.0').
        self assert: (snap sha256For: 'b' version: (self version: '1.0.0'))
            = 'cd34'
    ]

    testS2_malformedEntryFileFailsNamingFileAndPositionedReason [
        | dir problems |
        dir := self diamondDir: 's2-malformed'.
        SourceFixtures write: SourceFixtures malformedContents
            toFile: 'zz-bad.st' in: dir.
        problems := self problemsFrom: [(DirectorySource on: dir) snapshot].
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = ('zz-bad.st: Parse error at position 1: artifact must open with a literal array',
                self readerRejectionTail)
    ]

    testS3_nonIndexArtifactFailsNamingFileAndTag [
        | dir problems |
        dir := self diamondDir: 's3-wrongtag'.
        SourceFixtures write: SourceFixtures lockArtifactContents
            toFile: 'zz-lock.st' in: dir.
        problems := self problemsFrom: [(DirectorySource on: dir) snapshot].
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = 'zz-lock.st: wrong artifact tag #''parley-lock'' - a source directory holds only #''parley-index'' 1 entries'
    ]

    testS4_duplicateNameVersionAcrossFilesFails [
        | dir problems |
        dir := self diamondDir: 's4-duplicate'.
        SourceFixtures write: SourceFixtures duplicateC24Contents
            toFile: 'zz-dup.st' in: dir.
        problems := self problemsFrom: [(DirectorySource on: dir) snapshot].
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = 'zz-dup.st: duplicate entry for ''c'' 2.4.0 (already declared in c-2.4.0.st)'
    ]

    testS5_problemsAreBatchedInSortedFilenameOrder [
        | dir problems |
        dir := self diamondDir: 's5-batching'.
        SourceFixtures write: SourceFixtures malformedContents
            toFile: 'aa-bad.st' in: dir.
        SourceFixtures write: SourceFixtures duplicateC24Contents
            toFile: 'zz-dup.st' in: dir.
        problems := self problemsFrom: [(DirectorySource on: dir) snapshot].
        self assert: problems size = 2.
        self assert: (problems at: 1)
            = ('aa-bad.st: Parse error at position 1: artifact must open with a literal array',
                self readerRejectionTail).
        self assert: (problems at: 2)
            = 'zz-dup.st: duplicate entry for ''c'' 2.4.0 (already declared in c-2.4.0.st)'
    ]

    testS6_identityComesFromEntryContentsNotFilenames [
        | dir snap |
        dir := self freshDir: 's6-contents'.
        SourceFixtures populateDiamondIn: dir with24As: 'zz-anything.st'.
        snap := (DirectorySource on: dir) snapshot.
        self assertVersions: (snap versionsOf: 'c')
            are: #('1.5.0' '2.4.0' '3.0.0').
        self assert: (snap sha256For: 'c' version: (self version: '2.4.0'))
            = 'ef56'
    ]

    testS7_writerAuthoredEntryLandsWithAnEmptyHash [
        | dir manifest snap deps |
        dir := self diamondDir: 's7-writer'.
        manifest := Parley define: [:pkg |
            pkg name: 'd'; version: '1.0.0'; fileIns: #('D.st');
                dependency: 'c' constraint: '^2.0'].
        SourceFixtures writeManifest: manifest as: 'd-1.0.0.st' in: dir.
        snap := (DirectorySource on: dir) snapshot.
        self assertVersions: (snap versionsOf: 'd') are: #('1.0.0').
        deps := snap dependenciesOf: 'd' version: (self version: '1.0.0').
        self assert: deps size = 1.
        self assert: (deps at: 1) name = 'c'.
        self assert: (deps at: 1) constraint = (self constraint: '^2.0').
        self assert: (snap sha256For: 'd' version: (self version: '1.0.0'))
            = ''
    ]

    testS8_directorySourceSpeaksThePackageSourceProtocol [
        | source found direct |
        source := DirectorySource on: (self diamondDir: 's8-protocol').
        self assertVersions: (source versionsOf: 'c')
            are: #('1.5.0' '2.4.0' '3.0.0').
        self assert: (source versionsOf: 'unknown') isEmpty.
        found := source manifestFor: 'a' version: (self version: '1.0.0').
        direct := LibraryManifest fromIndexEntry:
            (IndexEntryReader readFrom:
                (ReadStream on: SourceFixtures diamondEntryA)).
        self assert: (found isKindOf: LibraryManifest).
        self assert: found name = direct name.
        self assert: found version = direct version.
        self assert: found dependencies size = direct dependencies size.
        1 to: found dependencies size do: [:i |
            self assert: (found dependencies at: i) name
                = ((direct dependencies at: i) name).
            self assert: (found dependencies at: i) constraint
                = ((direct dependencies at: i) constraint)].
        self assert: (source manifestFor: 'unknown'
            version: (self version: '1.0.0')) isNil
    ]

    testS9_fetchIsAnInstallTimeStub [
        | source message |
        source := DirectorySource on: (self diamondDir: 's9-fetch').
        message := nil.
        [source fetch: 'a' version: (self version: '1.0.0').
         self assert: false description: 'expected the fetch stub error']
            on: Error
            do: [:e | message := e messageText].
        self assert: message
            = 'fetch:version: is install-time only - the Installer does not exist yet'
    ]

    testS10_endToEndResolveWritesByteStableLockfileOnDisk [
        | entries locks paths |
        entries := self diamondDir: 's10-entries'.
        locks := self freshDir: 's10-locks'.
        paths := Array with: locks, '/my-app-1.lock'
            with: locks, '/my-app-2.lock'.
        paths do: [:lockPath |
            | snap resolution stream |
            snap := (DirectorySource on: entries) snapshot.
            resolution := ResolverFixtures
                resolve: ResolverFixtures diamondRoot
                against: snap.
            self assert: resolution isResolution.
            stream := (File name: lockPath) writeStream.
            [IndexEntryWriter writeLock: resolution on: stream]
                ensure: [stream close]].
        paths do: [:lockPath |
            self assert: (File name: lockPath) exists.
            self assert: (File name: lockPath) contents
                = self pinnedLockString]
    ]

    testS11_emptyDirectoryResolvesToAConflictValueNotASourceError [
        | snap result leaves |
        snap := (DirectorySource on: (self freshDir: 's11-empty')) snapshot.
        self assert: (snap isKindOf: IndexSnapshot).
        self assert: (snap versionsOf: 'a') isEmpty.
        result := ResolverFixtures
            resolve: (ResolverFixtures rootWith: #(#('a' '^1.0')))
            against: snap.
        self deny: result isResolution.
        leaves := ResolverFixtures externalLeavesOf: result root.
        self deny: (leaves
            detect: [:leaf | leaf cause = #noVersions]
            ifNone: [nil]) isNil
    ]

    testS12_missingDirectoryFailsNamingThePath [
        | path problems |
        path := SourceFixtures missingPathNamed: 's12-nowhere'.
        problems := self problemsFrom: [(DirectorySource on: path) snapshot].
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = (path, ': missing or unreadable directory')
    ]
]

Namespace current: Smalltalk.
