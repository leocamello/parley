"Parley Sprint 7 — GitIndexSource laws (issue #9 S11-S14; Doc F §3).

 A PackageSource whose index is a git repository of entry files. Pure
 composition — no kind-branching, no inheritance, no scan logic of its
 own: it holds an inner DirectorySource over the cache directory and
 adds exactly ONE git moment, at snapshot.

 Protocol decisions pinned here (posted on issue #9 for confirmation):
   - constructor: GitIndexSource repo: aRepoPath cache: aCacheDir
     runner: aProcessRunner — three collaborators held immutably,
     class-side construction, zero public setters, no value equality;
     construction is pathname-passive (no I/O, no process), so a
     source can be built before its repository exists;
   - snapshot is the one git moment: 'git clone --quiet <repo> <cache>'
     when the cache is ABSENT, 'git -C <cache> pull --ff-only --quiet'
     when it is present, then the inner DirectorySource's snapshot —
     the pinned command lines are PublishFixtures cloneCommandFor:cache:
     and pullCommandFor:. BOTH GAINED --quiet AT SPRINT 20 (issue #22,
     finding F19, §8 decision 77): git wrote 'Cloning into <cache>' and
     'done.' to stderr on every cold snapshot, 'Already up to date.' to
     STDOUT on every warm one, and a whole diffstat of the index
     repository's own files whenever upstream had moved — text Parley
     did not compose, naming a .parley/git/<sha256> path the operator
     never chose. The flag silences the chatter and NOT the failure: a
     clone of a repository that does not exist still answers
     'fatal: repository ... does not exist' at exit 128, which is what
     the two failure laws below hold it to;
   - a nonzero git exit signals ONE SourceError whose single problem
     carries the exact command line and the exit code
     (gitFailureProblemFor:code:) and never any stderr text: the
     runner captures none. A broken transport and a broken entry are
     both 'this source cannot answer', so both are SourceError;
   - versionsOf:, manifestFor:version: and fetch:version: are pure
     delegation and run NO git command: resolution consumed the
     snapshot the one git moment produced, and install-time fetch must
     see exactly those bytes, not a moved branch.

 Git discipline: fixture repositories are built locally through
 ProcessRunner with per-command committer identity; every repo path is
 a local path under tmp/ and every clone is a local-path clone. No
 network is contacted, ever, and the developer's git config is never
 touched. Every law touches the missing GitIndexSource class before
 any fixture repository is built, so the red phase spawns nothing."

Namespace current: Parley.

TestCase subclass: GitIndexSourceTest [
    | fixtureDirs |

    <comment: 'Laws for GitIndexSource: the first snapshot clones, a
later snapshot fast-forwards, a git failure is one SourceError naming
the command and code, and the delegating messages run no git at all.'>

    setUp [
        fixtureDirs := OrderedCollection new
    ]

    tearDown [
        fixtureDirs isNil ifTrue: [^self].
        fixtureDirs do: [:each | ExecFixtures removeTree: each].
        fixtureDirs := nil
    ]

    track: aPath [
        fixtureDirs add: aPath.
        ^aPath
    ]

    freshDir: aLabel [
        ^self track: (SourceFixtures directoryNamed: aLabel)
    ]

    absentPath: aLabel [
        ^self track: (PublishFixtures absentPathNamed: aLabel)
    ]

    version: aString [
        ^Version fromString: aString
    ]

    versionStringsOf: aCollection [
        ^((aCollection collect: [:each | each printString])
            asSortedCollection: [:a :b | a <= b]) asArray
    ]

    problemsFrom: aBlock [
        "The problems array of the SourceError aBlock signals; fails
         when no error, or a non-SourceError, is signaled."
        [aBlock value.
         self assert: false description: 'expected a SourceError']
            on: Error
            do: [:e |
                self assert: (e isKindOf: SourceError)
                    description: 'expected a SourceError, got ', e class name.
                ^e problems].
        ^#()
    ]

    "---- S11: the first snapshot clones ----"

    testTheFirstSnapshotClonesAndAnswersTheRepositoryContent [
        | repo cache source snap control |
        repo := self absentPath: 'git-clone-repo'.
        cache := self absentPath: 'git-clone-cache'.
        source := GitIndexSource repo: repo cache: cache
            runner: ProcessRunner new.
        PublishFixtures buildDiamondRepoAt: repo.
        self deny: (File name: cache) exists.
        snap := source snapshot.
        self assert: (File name: cache) exists.
        control := (DirectorySource on: repo) snapshot.
        #('a' 'b' 'c') do: [:name |
            self assert: (self versionStringsOf: (snap versionsOf: name))
                = (self versionStringsOf: (control versionsOf: name))].
        self assert: (snap sha256For: 'c' version: (self version: '2.4.0'))
            = InstallFixtures digestC24.
        self assert: (snap dependenciesOf: 'a' version: (self version: '1.0.0'))
            size = 1
    ]

    "---- S12: a later snapshot fast-forwards ----"

    testALaterSnapshotSeesUpstreamGrowth [
        | repo cache source first second |
        repo := self absentPath: 'git-pull-repo'.
        cache := self absentPath: 'git-pull-cache'.
        source := GitIndexSource repo: repo cache: cache
            runner: ProcessRunner new.
        PublishFixtures buildDiamondRepoAt: repo.
        first := source snapshot.
        self assert: (first versionsOf: 'd') isEmpty.
        PublishFixtures growDiamondRepoAt: repo.
        second := source snapshot.
        self assert: (self versionStringsOf: (second versionsOf: 'd'))
            = #('1.0.0').
        "the earlier snapshot is a sealed value — growth never reaches it"
        self assert: (first versionsOf: 'd') isEmpty
    ]

    "---- the two git command lines ----"

    testBothComposedGitLinesCarryTheQuietFlag [
        "The composition is the subject, and BOTH halves of it are
         reached here - the clone branch by an absent cache, the pull
         branch by a populated one - because they are two different
         composed lines behind one predicate and a law that drove only
         one would leave the other silently noisy, which is how F19
         survived a whole sprint of chatter work.

         THE LINES ARE READ OFF THE RECORDING RUNNER, never off the
         fixture: an oracle asked whether it carries the flag it was
         just given is an oracle agreeing with itself, and it would pass
         before the source composed anything at all."
        | absent cloneRunner cache pullRunner |
        absent := self absentPath: 'git-quiet-clone-cache'.
        cloneRunner := RecordingRunner new.
        "A RECORDING RUNNER RECORDS AND NEVER CLONES, so the cache is
         still absent when the inner scan runs and the snapshot signals
         the settled missing-directory SourceError. The command line was
         composed and recorded BEFORE that, which is the whole of what
         this law asserts — so the failure is consumed through the
         settled helper rather than avoided by populating a cache, which
         would compose the OTHER branch and leave the clone line
         untested."
        self problemsFrom: [(GitIndexSource repo: 'tmp/parley-git-quiet-repo'
            cache: absent
            runner: cloneRunner) snapshot].
        self assert: cloneRunner commands size = 1
            description: 'a cold snapshot ran ',
                cloneRunner commands printString.
        self assert: (CommandLineFixtures does: cloneRunner commands first
            include: GrammarFixtures quietFlag)
            description: 'the clone line is ', cloneRunner commands first.
        cache := self freshDir: 'git-quiet-pull-cache'.
        InstallFixtures populateInstallDiamondIn: cache.
        pullRunner := RecordingRunner new.
        (GitIndexSource repo: 'tmp/parley-git-quiet-repo'
            cache: cache
            runner: pullRunner) snapshot.
        self assert: pullRunner commands size = 1
            description: 'a warm snapshot ran ',
                pullRunner commands printString.
        self assert: (CommandLineFixtures does: pullRunner commands first
            include: GrammarFixtures quietFlag)
            description: 'the pull line is ', pullRunner commands first
    ]

    testAnExistingCachePullsRatherThanClones [
        | cache runner source snap |
        cache := self freshDir: 'git-pullcmd-cache'.
        InstallFixtures populateInstallDiamondIn: cache.
        runner := RecordingRunner new.
        source := GitIndexSource repo: 'tmp/parley-git-pullcmd-repo'
            cache: cache
            runner: runner.
        snap := source snapshot.
        self assert: runner commands
            = (Array with: (PublishFixtures pullCommandFor: cache)).
        self assert: (self versionStringsOf: (snap versionsOf: 'c'))
            = #('1.5.0' '2.4.0' '3.0.0')
    ]

    "---- S13: a git failure is one SourceError ----"

    testAMissingRepositoryIsOneSourceErrorNamingTheCommandAndCode [
        | repo cache source problems |
        repo := self absentPath: 'git-nowhere-repo'.
        cache := self absentPath: 'git-nowhere-cache'.
        source := GitIndexSource repo: repo cache: cache
            runner: ProcessRunner new.
        problems := self problemsFrom: [source snapshot].
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = (PublishFixtures
                gitFailureProblemFor: (PublishFixtures cloneCommandFor: repo
                    cache: cache)
                code: 128)
    ]

    testAFailedPullIsOneSourceErrorNamingThePullCommand [
        | cache source problems |
        cache := self freshDir: 'git-badpull-cache'.
        InstallFixtures populateInstallDiamondIn: cache.
        source := GitIndexSource repo: 'tmp/parley-git-badpull-repo'
            cache: cache
            runner: (RecordingRunner answering: 1).
        problems := self problemsFrom: [source snapshot].
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = (PublishFixtures
                gitFailureProblemFor: (PublishFixtures pullCommandFor: cache)
                code: 1)
    ]

    "---- S14: fetch reads the checkout, never git ----"

    testFetchAnswersTheCheckoutBytesAfterUpstreamMoves [
        | repo cache source snap bytes |
        repo := self absentPath: 'git-fetch-repo'.
        cache := self absentPath: 'git-fetch-cache'.
        source := GitIndexSource repo: repo cache: cache
            runner: ProcessRunner new.
        PublishFixtures buildArchiveRepoAt: repo.
        snap := source snapshot.
        self assert: (snap sha256For: 'f' version: (self version: '1.0.0'))
            = (Sha256 hexDigestOf: PublishFixtures checkoutArchiveBytes).
        PublishFixtures moveArchiveUpstreamAt: repo.
        bytes := source fetch: 'f' version: (self version: '1.0.0').
        self assert: bytes = PublishFixtures checkoutArchiveBytes.
        self deny: bytes = PublishFixtures movedArchiveBytes
    ]

    testTheDelegatingMessagesRunNoProcessAtAll [
        "versionsOf:, manifestFor:version: and fetch:version: are pure
         delegation to the inner DirectorySource: a runner that signals
         on every run: is never touched."
        | cache source manifest |
        cache := self freshDir: 'git-trap-cache'.
        InstallFixtures populateInstallDiamondIn: cache.
        source := GitIndexSource repo: 'tmp/parley-git-trap-repo'
            cache: cache
            runner: TrapRunner new.
        self assert: (self versionStringsOf: (source versionsOf: 'c'))
            = #('1.5.0' '2.4.0' '3.0.0').
        manifest := source manifestFor: 'a' version: (self version: '1.0.0').
        self assert: manifest name = 'a'.
        self assert: (source fetch: 'a' version: (self version: '1.0.0'))
            = InstallFixtures archiveBytesA
    ]

    "---- the source composes rather than inherits ----"

    testAGitIndexSourceIsNotADirectorySource [
        "Composition, not inheritance: the git source holds an inner
         DirectorySource, it does not become one."
        | source |
        source := GitIndexSource repo: 'tmp/parley-git-shape-repo'
            cache: 'tmp/parley-git-shape-cache'
            runner: TrapRunner new.
        self deny: (source isKindOf: DirectorySource)
    ]
]

Namespace current: Smalltalk.
