"Parley Sprint 21 — the mode flags as a second declared table (issue
 #23; Doc E §4.2; §8 decisions 68, 69, 81, 83).

 THEY ARE NOT sourceFlags ROWS, AND THAT IS A RULING RATHER THAN A
 CONVENIENCE. --offline and --locked are VALUELESS: they build nothing
 and take no value, while every sourceFlags row is (flag, Class,
 builder) and SourceFlagTest holds each row to exactly three columns.
 Forcing a flag that constructs no source into that shape would move a
 law this sprint declares a NON-MOVER, so the mode flags are a second
 declared table in the decision-81 idiom — consumed by the extraction
 and by a drift law, exactly as sourceFlags, publishLayouts, verbRows
 and deserializationBoundaries are.

 EACH IS A GUARD INVARIANT WITH ONE ENFORCEMENT SITE, so no per-verb
 applicability table exists and a verb that cannot violate an invariant
 satisfies it trivially. --offline means THIS INVOCATION SPAWNS NO git
 AND NO curl, enforced at source wiring and keyed off the settled
 sourceFlags. --locked means THIS INVOCATION DOES NOT CHANGE
 parley.lock, enforced at the one lock-write site.

 BOTH SENTENCES ARE DECLARED WORDINGS CONSUMED TWICE (§8 decision 81's
 rule): the site that refuses reads the declaration, and the laws below
 read the same one. Composing a sentence where the refusal happens is
 the drift that idiom exists to prevent."

Namespace current: Parley.

TestCase subclass: ModeFlagTest [
    | fixtureDirs |

    <comment: 'Laws over the mode-flag table, its extraction, the two
enforcement sites, both declared refusal wordings, and the settled
tables and grammar the two flags must leave exactly where they found
them.'>

    setUp [
        fixtureDirs := OrderedCollection new
    ]

    tearDown [
        fixtureDirs isNil ifTrue: [^self].
        fixtureDirs do: [:each | PathFixtures removeTree: each].
        fixtureDirs := nil
    ]

    freshDir: aLabel [
        | path |
        path := SourceFixtures directoryNamed: aLabel.
        fixtureDirs add: path.
        ^path
    ]

    workDir: aLabel contents: aContentsString [
        | path |
        path := PathDepFixtures workDirNamed: aLabel contents: aContentsString.
        fixtureDirs add: path.
        ^path
    ]

    resultOf: anArgvArray in: aWorkDir runner: aRunner [
        ^PathDepFixtures resultOf: anArgvArray in: aWorkDir runner: aRunner
    ]

    "---- the declared table ----"

    testTheModeFlagTableDeclaresBothFlagsAndNothingElse [
        "THE DRIFT LAW. The table is the one declaration, so a flag the
         parser knows and the table does not — or the reverse — fails
         here rather than in a user's terminal."
        self assert: CommandLine modeFlagNames asSortedCollection asArray
            = PathDepFixtures modeFlagNames asSortedCollection asArray
            description: 'the mode-flag table declares ',
                CommandLine modeFlagNames printString
    ]

    testEveryModeFlagRowIsAFlagAndAMode [
        "Two columns, both meaningful: the spelling the operator types
         and the mode symbol the invocation carries. Asserted as a SHAPE
         so a third column cannot arrive unnoticed — the discipline
         SourceFlagTest applies to the table next door."
        self deny: CommandLine modeFlags isEmpty.
        CommandLine modeFlags do: [:row |
            self assert: row size = 2
                description: 'a mode-flag row has ', row size printString,
                    ' columns: ', row printString.
            self assert: (row at: 1) isString.
            self assert: ((row at: 1) startsWith: '--')
                description: 'a mode flag must look like a flag: ',
                    (row at: 1).
            self assert: (row at: 2) isSymbol
                description: 'the second column names the mode: ',
                    row printString]
    ]

    testTheSourceFlagTableIsUntouched [
        "THE DECLARED NON-MOVER, ASSERTED IN THIS SPRINT'S OWN FILE.
         sourceFlags keeps exactly its three rows and its three columns:
         the new flags build no source, and SourceFlagTest:149's shape
         law must not move."
        self assert: CommandLine sourceFlagNames
            = (Array with: '--source' with: '--git' with: '--index')
            description: CommandLine sourceFlagNames printString.
        CommandLine sourceFlags do: [:row |
            self assert: row size = 3
                description: 'a source-flag row grew to ',
                    row size printString, ' columns'].
        CommandLine modeFlagNames do: [:flag |
            self deny: (CommandLine sourceFlagNames includes: flag)
                description: flag, ' was forced into the source table']
    ]

    testTheNetworkFlagsAreDerivedFromTheSourceTable [
        "--offline's predicate is keyed off the declaration the wiring
         already holds, exactly as §8 decision 80's capability predicate
         is. --source is deliberately absent: a local directory is what
         offline MEANS, and refusing it would make the flag useless for
         the case it exists to serve."
        self assert: CommandLine networkSourceFlagNames
            asSortedCollection asArray
            = PathDepFixtures networkFlagNames asSortedCollection asArray
            description: CommandLine networkSourceFlagNames printString.
        CommandLine networkSourceFlagNames do: [:flag |
            self assert: (CommandLine sourceFlagNames includes: flag)
                description: flag, ' is not a declared source flag at all']
    ]

    "---- the extraction ----"

    testAModeFlagIsExtractedAndNeverReachesTheVerbArgv [
        "The mode flags are extracted by the same flag parse that
         extracts the source flags, wherever they appear ahead of the
         verb argv. A mode flag that travelled on would arrive at the
         settled CLI as an unknown shape and answer usage — which is
         how a new flag looks exactly like a typo."
        | work result |
        work := self workDir: 'mf-extract-work'
            contents: PathDepFixtures emptyRootContents.
        result := self resultOf: (Array with: 'resolve'
            with: PathDepFixtures lockedFlag)
            in: work runner: RecordingRunner new.
        self deny: result exitCode = 2
            description: 'the mode flag reached the verb argv: ',
                result lines printString
    ]

    testBothModeFlagsComposeWithEachOtherAndWithASourceFlag [
        "Both flags compose with each other and with any source flag —
         which is what makes them modes rather than verbs. A --source
         index is not a network source, so --offline permits it, and a
         current lock satisfies --locked."
        | work index result |
        work := self workDir: 'mf-compose-work'
            contents: PathDepFixtures emptyRootContents.
        index := self freshDir: 'mf-compose-index'.
        self resultOf: (Array with: 'resolve' with: '--source' with: index)
            in: work runner: RecordingRunner new.
        result := self resultOf: (Array with: 'resolve' with: '--source'
            with: index with: PathDepFixtures offlineFlag
            with: PathDepFixtures lockedFlag)
            in: work runner: RecordingRunner new.
        self assert: result exitCode = 0
            description: 'the two modes together answered exit ',
                result exitCode printString, ': ', result lines printString
    ]

    testTheQuestionFlagsStayAheadOfTheModeFlags [
        "--version and --help are answered before verb dispatch, before
         the config read and before any state directory (§8 decision
         57), and the mode flags do not move that line: a question must
         not depend on the state of a project, nor on a mode nobody
         applied to it."
        | work |
        work := self freshDir: 'mf-question-work'.
        self assert: (self resultOf: (Array with: '--help')
            in: work runner: TrapRunner new) exitCode = 0.
        self assert: (self resultOf: (Array with: '--version')
            in: work runner: TrapRunner new) exitCode = 0.
        CommandLine modeFlagNames do: [:flag |
            self deny: (CommandLine helpFlags includes: flag)
                description: flag, ' is also a question flag'.
            self deny: flag = CommandLine versionFlag
                description: flag, ' is also the version flag']
    ]

    "---- --offline: one enforcement site, at source wiring ----"

    testOfflineRefusesEveryNetworkFlagWithItsDeclaredWording [
        "One declared line per transport, consumed twice: here, and at
         the site that refuses. Driven over BOTH network flags, because
         a guard that named one of them by literal would pass a
         single-flag law and ship the other."
        | work |
        work := self workDir: 'mf-offline-work'
            contents: PathDepFixtures emptyRootContents.
        CommandLine networkSourceFlagNames do: [:flag |
            | runner result |
            runner := RecordingRunner new.
            result := self resultOf: (Array with: 'resolve' with: flag
                with: 'tmp/parley-mf-offline-remote'
                with: PathDepFixtures offlineFlag) in: work runner: runner.
            self assert: result exitCode = 1
                description: flag, ' answered exit ',
                    result exitCode printString.
            self assert: result lines
                = (Array with: (CommandLine offlineRefusalFor: flag))
                description: result lines printString.
            self assert: result lines
                = (Array with: (PathDepFixtures offlineRefusalFor: flag))
                description: 'the declared wording moved: ',
                    result lines printString.
            self assert: runner commands = #()
                description: flag, ' spawned ', runner commands printString]
    ]

    testOfflineLeavesALocalDirectorySourceAlone [
        "The contrast that makes the refusal a claim rather than a
         blanket: --source is unaffected, because a local directory is
         what offline means."
        | work index runner result |
        work := self workDir: 'mf-local-work'
            contents: PathDepFixtures emptyRootContents.
        index := self freshDir: 'mf-local-index'.
        runner := RecordingRunner new.
        result := self resultOf: (Array with: 'resolve' with: '--source'
            with: index with: PathDepFixtures offlineFlag)
            in: work runner: runner.
        self assert: result exitCode = 0
            description: '--source under --offline answered ',
                result lines printString
    ]

    testOfflineCreatesNoCacheDirectoryForTheSourceItRefuses [
        "Building a --git or --index source creates its cache root under
         .parley/, so a refusal that fired AFTER the build would leave a
         directory behind for a command that did nothing. The refusal is
         at the wiring, which is before the build."
        | work result |
        work := self workDir: 'mf-nocache-work'
            contents: PathDepFixtures emptyRootContents.
        result := self resultOf: (Array with: 'resolve' with: '--git'
            with: 'tmp/parley-mf-nocache-remote'
            with: PathDepFixtures offlineFlag)
            in: work runner: RecordingRunner new.
        self assert: result exitCode = 1
            description: 'the refusal answered exit ',
                result exitCode printString, ': ', result lines printString.
        self deny: (File name: work, '/.parley/git') exists
            description: 'the refused --git source created its cache root'
    ]

    "---- --locked: one enforcement site, at the lock write ----"

    testLockedAcceptsACurrentLockAndWritesNothingNew [
        "A current lock is ordinary success. The file is byte-identical
         either way, so the observation that matters is the exit code
         and the bytes — never whether a write happened to be a no-op."
        | work index before result |
        index := self freshDir: 'mf-current-index'.
        work := self workDir: 'mf-current-work'
            contents: PathDepFixtures emptyRootContents.
        self resultOf: (Array with: 'resolve' with: '--source' with: index)
            in: work runner: RecordingRunner new.
        before := PathDepFixtures lockTextIn: work.
        result := self resultOf: (Array with: 'resolve' with: '--source'
            with: index with: PathDepFixtures lockedFlag)
            in: work runner: RecordingRunner new.
        self assert: result exitCode = 0
            description: result lines printString.
        self assert: (PathDepFixtures lockTextIn: work) = before
            description: 'the lock moved under --locked'
    ]

    testLockedRefusesWhenThereIsNoLockAtAll [
        "A project with no lock cannot satisfy `this invocation does not
         change parley.lock` the moment it has anything to pin: writing
         a first lock IS a change. The refusal names the first pin in
         sorted order and the absent side as such, because `nothing` is
         the honest rendering of a pin that is not there."
        | work index result |
        index := self freshDir: 'mf-nolock-index'.
        SourceFixtures write: (PathDepFixtures plainEntryFor: 'kernel-a'
            version: '1.0.0' dependencies: '')
            toFile: 'kernel-a-1.0.0.st' in: index.
        work := self workDir: 'mf-nolock-work'
            contents: PathDepFixtures indexNeedingRootContents.
        result := self resultOf: (Array with: 'resolve' with: '--source'
            with: index with: PathDepFixtures lockedFlag)
            in: work runner: RecordingRunner new.
        self assert: result exitCode = 1
            description: result lines printString.
        self assert: result lines = (Array with: (PathDepFixtures
            lockedRefusalFor: 'kernel-a'
            pinned: PathDepFixtures absentPinText would: '1.0.0'))
            description: result lines printString.
        self deny: (File name: work, '/parley.lock') exists
            description: '--locked wrote the lock it refused'
    ]

    testTheRefusalNamesTheFirstDifferingPinInSortedOrder [
        "SORTED ORDER RATHER THAN DISCOVERY ORDER, because the answer
         must be the same on every machine — the byte-stability rule
         this project applies to every rendering, applied to a
         diagnosis. Two pins move at once here, and the earlier NAME is
         the one reported."
        | work index result |
        index := self freshDir: 'mf-sorted-index'.
        (Array with: 'kernel-a' with: 'kernel-z') do: [:name |
            (Array with: '1.0.0' with: '2.0.0') do: [:version |
                SourceFixtures write: (PathDepFixtures plainEntryFor: name
                    version: version dependencies: '')
                    toFile: name, '-', version, '.st' in: index]].
        work := self workDir: 'mf-sorted-work' contents: 'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''kernel-a'' constraint: ''=1.0.0'';
        dependency: ''kernel-z'' constraint: ''=1.0.0'' ]',
            SourceFixtures newline.
        self resultOf: (Array with: 'resolve' with: '--source' with: index)
            in: work runner: RecordingRunner new.
        ExecFixtures writePackage: 'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''kernel-a'' constraint: ''=2.0.0'';
        dependency: ''kernel-z'' constraint: ''=2.0.0'' ]',
            SourceFixtures newline in: work.
        result := self resultOf: (Array with: 'resolve' with: '--source'
            with: index with: PathDepFixtures lockedFlag)
            in: work runner: RecordingRunner new.
        self assert: result lines = (Array with: (CommandLine
            lockedRefusalFor: 'kernel-a' pinned: '1.0.0' would: '2.0.0'))
            description: result lines printString
    ]

    testTheLockedWordingIsTheDeclaredOneConsumedTwice [
        "The site that refuses reads the declaration, and so does this
         law. Two sites each writing their own sentence is two wordings
         no law can see."
        self assert: (CommandLine lockedRefusalFor: 'kernel-a'
            pinned: '1.0.0' would: '2.0.0')
            = (PathDepFixtures lockedRefusalFor: 'kernel-a'
                pinned: '1.0.0' would: '2.0.0')
            description: 'the shipped wording is ',
                (CommandLine lockedRefusalFor: 'kernel-a'
                    pinned: '1.0.0' would: '2.0.0') printString
    ]

    testUpdateUnderLockedRefusesAndWritesNothing [
        "--locked composes with EVERY verb that writes the lock, and
         update is the one whose whole job is to move pins. A guard that
         had been wired only into resolve would pass every law above and
         fail here."
        | work index before result |
        index := self freshDir: 'mf-update-index'.
        SourceFixtures write: (PathDepFixtures plainEntryFor: 'kernel-a'
            version: '1.0.0' dependencies: '')
            toFile: 'kernel-a-1.0.0.st' in: index.
        work := self workDir: 'mf-update-work'
            contents: PathDepFixtures indexNeedingRootContents.
        self resultOf: (Array with: 'resolve' with: '--source' with: index)
            in: work runner: RecordingRunner new.
        before := PathDepFixtures lockTextIn: work.
        SourceFixtures write: (PathDepFixtures plainEntryFor: 'kernel-a'
            version: '1.9.0' dependencies: '')
            toFile: 'kernel-a-1.9.0.st' in: index.
        result := self resultOf: (Array with: 'update' with: '--source'
            with: index with: PathDepFixtures lockedFlag)
            in: work runner: RecordingRunner new.
        self assert: result exitCode = 1
            description: result lines printString.
        self assert: result lines = (Array with: (CommandLine
            lockedRefusalFor: 'kernel-a' pinned: '1.0.0' would: '1.9.0'))
            description: result lines printString.
        self assert: (PathDepFixtures lockTextIn: work) = before
            description: 'update under --locked changed the lock'
    ]

    "---- what the flags must leave alone ----"

    testTheConfigurationSchemaGainsNoModeKey [
        "The mode flags are per-invocation assertions — a CI run's
         property, not a project's — so #'parley-config' 1 is unchanged
         and byte-identical. A key for either is deferred WITH ITS
         TRIGGER (the first caller that genuinely cannot pass a flag),
         and this law is what makes the deferral checkable."
        | work result |
        work := self workDir: 'mf-config-work'
            contents: PathDepFixtures emptyRootContents.
        SourceFixtures write:
            '#(#''parley-config'' 1 #source '''' #git '''' #index '''' #offline '''')',
            SourceFixtures newline
            toFile: 'parley.config.st' in: work.
        result := self resultOf: (Array with: 'resolve')
            in: work runner: RecordingRunner new.
        self assert: result exitCode = 1
            description: 'an unknown config key was accepted: ',
                result lines printString.
        "THE SECOND HALF DRIVES A VALID CONFIG, AND IT HAS TO (amended
         mid-sprint, GREEN step 6). Asked against the MALFORMED file
         above, valueFor: does not answer nil — it raises the settled
         ExecutionError carrying the malformed-configuration diagnosis
         (probed at this gate). That is the boundary family working, and
         the half above already proves it: a config naming a mode flag
         is REFUSED, so the flag is not in the schema.
         This half proves the complementary fact — that the lookup has
         no key for a mode flag even on a well-formed file — and it can
         only be asked where the file parses."
        SourceFixtures write:
            '#(#''parley-config'' 1 #source '''' #git '''' #index '''')',
            SourceFixtures newline
            toFile: 'parley.config.st' in: work.
        CommandLine modeFlagNames do: [:flag |
            self assert: ((Configuration in: work) valueFor: flag) isNil
                description: flag, ' became a configuration key']
    ]

    testTheSettledTrailingFlagGrammarStillHolds [
        "The mode flags are recognized in the flag parse ahead of the
         verb argv, NOT as a general `valueless flags are grammar now`
         change — which would silently alter what every settled
         trailing-flag law is testing without touching a line of them
         (the Sprint 15 and Sprint 16 reasoning, applied a third time).
         A trailing --help on a verb is still a usage error."
        | work index |
        work := self freshDir: 'mf-trailing-work'.
        self assert: (self resultOf: (Array with: 'resolve' with: '--help')
            in: work runner: TrapRunner new) exitCode = 2
            description: 'the settled trailing-flag grammar moved'.
        index := self freshDir: 'mf-trailing-index'.
        ExecFixtures writePackage: PathDepFixtures emptyRootContents in: work.
        self deny: (self resultOf: (Array with: 'resolve' with: '--source'
            with: index with: PathDepFixtures lockedFlag)
            in: work runner: RecordingRunner new) exitCode = 2
            description: 'a trailing mode flag was not extracted'
    ]
]

Namespace current: Smalltalk.
