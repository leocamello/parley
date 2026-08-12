"Parley — GitIndexSource: a git checkout used as an index directory.
 Spec: docs/design/publish-and-sources.md §3; issue #9 S11-S14.
 Pure composition — no kind-branching, no inheritance, no scan logic of
 its own: the source holds an inner DirectorySource over the cache
 directory and adds exactly ONE git moment, at snapshot.

 snapshot is the source's one I/O moment, git moment included: clone
 when the cache is absent, fast-forward pull when it is present, then
 the inner source's snapshot. BOTH COMPOSED LINES CARRY --quiet from
 Sprint 20 (finding F19, §8 decision 77): this source used to print
 git's own text on every snapshot — to stderr on a cold cache, and to
 STDOUT above Parley's own answer on every warm one. The flag stops
 the text being written and buffers nothing; a failing git still
 answers fatal: … at exit 128. A nonzero git exit is one SourceError —
 the settled batched-scan error class, because a broken transport and a
 broken entry are both 'this source cannot answer'. Its single problem
 carries the exact command line and the exit code and never any stderr
 text: the runner captures none.

 versionsOf:, manifestFor:version: and fetch:version: are pure
 delegation and run NO git command. That is the metadata/archive split
 holding: resolution consumed the snapshot the one git moment produced,
 and install-time fetch must see exactly those bytes, not a moved
 branch. Archives live in the repository beside the entries, exactly as
 in any directory source.

 No value equality (=/hash) — the decision-23 precedent."

Namespace current: Parley.

Object subclass: GitIndexSource [
    | repo cache runner inner |

    <comment: 'A PackageSource whose index is a git repository of entry
files: the repo location (any path git clone accepts), the local
checkout directory, and the one process seam, all held immutably,
plus the inner DirectorySource it delegates every non-git message to.
Construction is pathname-passive — nothing is cloned, read or spawned
until snapshot. Class-side construction; zero public setters.'>

    GitIndexSource class >> repo: aRepoPath cache: aCacheDir runner: aProcessRunner [
        "Answer a source over the git repository at aRepoPath, checked
         out into aCacheDir, spawning only through aProcessRunner.
         Pathname-passive: neither path is touched here."
        <category: 'instance creation'>
        ^self new setRepo: aRepoPath cache: aCacheDir runner: aProcessRunner
    ]

    setRepo: aRepoPath cache: aCacheDir runner: aProcessRunner [
        "Private — initialization from the class-side constructor. The
         inner source is built here and held immutably: DirectorySource
         construction touches no disk, so this stays pathname-passive."
        <category: 'private'>
        repo := aRepoPath.
        cache := aCacheDir.
        runner := aProcessRunner.
        inner := DirectorySource on: aCacheDir
    ]

    seededWith: someNames [
        "Answer a source told that someNames matter (§8 decision 51).
         A source that clones its whole index genuinely has nothing to
         do with the information — self is the honest answer, not a
         stub. No process runs here."
        <category: 'source protocol'>
        ^self
    ]

    snapshot [
        "The source's one I/O moment, git moment included: refresh the
         checkout, then answer the inner source's sealed immutable
         IndexSnapshot. A nonzero git exit signals one SourceError
         carrying the command line and the code."
        <category: 'source protocol'>
        | command code |
        command := self refreshCommand.
        code := runner run: command.
        code = 0 ifFalse: [
            ^SourceError signalProblems: (Array with:
                'git command failed with exit code ', code printString,
                ': ', command)].
        ^inner snapshot
    ]

    versionsOf: aPackageName [
        "Pure delegation to the checkout — no git command runs."
        <category: 'source protocol'>
        ^inner versionsOf: aPackageName
    ]

    manifestFor: aPackageName version: aVersion [
        "Pure delegation to the checkout — no git command runs."
        <category: 'source protocol'>
        ^inner manifestFor: aPackageName version: aVersion
    ]

    fetch: aPackageName version: aVersion [
        "Pure delegation to the EXISTING checkout — no git command
         runs. Install-time fetch must answer exactly the bytes the
         snapshot was taken over, never a moved branch."
        <category: 'source protocol'>
        ^inner fetch: aPackageName version: aVersion
    ]

    refreshCommand [
        "Private — the one git command line of a snapshot: clone into
         an absent cache, fast-forward an existing one. --ff-only
         because an index checkout is a mirror, never a merge base.

         BOTH LINES CARRY --quiet (Sprint 20, finding F19, §8 decision
         77's rule applied to the last member of the domain it named).
         Without it this source printed text Parley did not compose on
         every single snapshot, and the recorded description of the gap
         understated it: a cold cache wrote `Cloning into '<cache>'` and
         `done.` to STDERR, naming a .parley/git/<sha256> path the
         operator never chose; a warm cache wrote `Already up to date.`
         to STDOUT, ABOVE Parley's own answer; and a warm cache whose
         index had moved wrote a whole diffstat of the index
         repository's files there. Every run after the first put it on
         the stream the record called clean.

         THE FLAG STOPS TEXT BEING WRITTEN AND BUFFERS NOTHING, which
         is what keeps it clear of the deferred output-capture row — the
         same shape -g took for exec's child. And it silences chatter,
         never failure: probed on this exact composition, a clone of a
         repository that does not exist still answers `fatal: repository
         … does not exist` at exit 128, and a diverged cache still
         answers `fatal: Not possible to fast-forward, aborting.` at
         128, so the settled SourceError still reaches the operator
         naming the command actually run — flag included."
        <category: 'private'>
        ^(PathGuard exists: cache)
            ifTrue: ['git -C ', cache, ' pull --ff-only --quiet']
            ifFalse: ['git clone --quiet ', repo, ' ', cache]
    ]
]

Namespace current: Smalltalk.
