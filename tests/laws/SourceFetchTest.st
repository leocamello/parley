"Parley Sprint 5 — DirectorySource fetch:version: laws (Doc D §1.1,
 amended Doc C §1.1; issue #7 S5-S8). A NEW file: the reviewed Sprint 4
 test files are not modified; the two Sprint 4 fetch-stub tests were
 superseded and removed by the operator at staging, and this suite
 re-pins the fetch contract.

 Protocol decisions pinned here (posted on issue #7 for confirmation):
   - fetch: aPackageName version: aVersion answers the complete raw
     bytes (a String) of the archive file named by the entry's #archive
     field, resolved relative to the source directory;
   - problems signal a one-problem SourceError (the settled
     signalProblems: house style, so messageText is
     'Source directory has 1 problem(s): <problem>');
   - the three problem wordings, exact:
       unknown (package, version):
         '<name> <version>: unknown (package, version) - the source
          directory declares no entry for it'
       no published archive (#archive #()):
         '<name> <version>: no published archive - the entry declares
          #archive #()'
       named archive file missing/unreadable:
         '<archive basename>: missing or unreadable archive file'
     (each rendered on one line; versions render via Version
     printString)."

Namespace current: Parley.

TestCase subclass: SourceFetchTest [
    | fixtureDirs |

    <comment: 'Laws for the real DirectorySource fetch:version: per
Doc D §1.1: exact byte round-trip and the three one-problem
SourceError shapes. Fixture directories live under tmp/ and are
removed in tearDown.'>

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

    version: aString [
        ^Version fromString: aString
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

    "---- the round-trip law: fetch answers the file's exact bytes ----"

    testFetchAnswersTheArchiveFilesExactBytes [
        | source |
        source := DirectorySource on:
            (self installDiamondDir: 'law-fetch-bytes').
        self assert: (source fetch: 'a' version: (self version: '1.0.0'))
            = InstallFixtures archiveBytesA.
        self assert: (source fetch: 'b' version: (self version: '1.0.0'))
            = InstallFixtures archiveBytesB.
        self assert: (source fetch: 'c' version: (self version: '2.4.0'))
            = InstallFixtures archiveBytesC24
    ]

    "---- problem shape 1: unknown (package, version) ----"

    testFetchUnknownPackageSignalsOneProblem [
        | source problems |
        source := DirectorySource on:
            (self installDiamondDir: 'law-fetch-ghost').
        problems := self problemsFrom:
            [source fetch: 'ghost' version: (self version: '1.0.0')].
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = 'ghost 1.0.0: unknown (package, version) - the source directory declares no entry for it'
    ]

    testFetchUnknownVersionOfAKnownPackageSignalsOneProblem [
        | source problems |
        source := DirectorySource on:
            (self installDiamondDir: 'law-fetch-noversion').
        problems := self problemsFrom:
            [source fetch: 'c' version: (self version: '9.9.9')].
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = 'c 9.9.9: unknown (package, version) - the source directory declares no entry for it'
    ]

    "---- problem shape 2: #archive #() (no published archive) ----"

    testFetchEntryWithEmptyArchiveSignalsOneProblem [
        | dir problems |
        dir := self installDiamondDir: 'law-fetch-noarchive'.
        InstallFixtures addEmptyArchiveEntryTo: dir.
        problems := self problemsFrom:
            [(DirectorySource on: dir)
                fetch: 'd' version: (self version: '1.0.0')].
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = 'd 1.0.0: no published archive - the entry declares #archive #()'
    ]

    "---- problem shape 3: the named archive file is missing ----"

    testFetchMissingArchiveFileSignalsOneProblem [
        | dir problems |
        dir := self installDiamondDir: 'law-fetch-missingfile'.
        InstallFixtures addMissingArchiveEntryTo: dir.
        problems := self problemsFrom:
            [(DirectorySource on: dir)
                fetch: 'e' version: (self version: '1.0.0')].
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = 'e-1.0.0.star: missing or unreadable archive file'
    ]

    "---- the SourceError house style holds on the fetch path ----"

    testFetchSourceErrorMessageTextFollowsTheHouseStyle [
        | source |
        source := DirectorySource on:
            (self installDiamondDir: 'law-fetch-message').
        [source fetch: 'ghost' version: (self version: '1.0.0').
         self assert: false description: 'expected a SourceError']
            on: Error
            do: [:e |
                self assert: (e isKindOf: SourceError).
                self assert: e messageText
                    = 'Source directory has 1 problem(s): ghost 1.0.0: unknown (package, version) - the source directory declares no entry for it']
    ]
]

Namespace current: Smalltalk.
