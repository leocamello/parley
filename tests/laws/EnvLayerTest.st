"Parley Sprint 22 — the environment layer's law suite.
 Spec: docs/design/execution-and-cli.md §4.2; §8 decision 85; issue #24
 S1-S8 and the P1/P2 pre-RED rulings.

 WHAT IS PROVED HERE. The precedence chain flag > environment > file,
 driven pairwise on fixtures whose locks are distinguishable (the
 Sprint 19 S7 idiom — the lock says which level was consulted, because
 an exit code cannot); the ruled skip, driven explicitly so it is ruled
 behavior rather than accident; the two-variables refusal with its
 contrast halves, including the placement mirror — the conflict is
 diagnosed even for an argv that would answer usage, exactly where the
 file's own malformed-body diagnosis sits; empty-is-unset; the
 --offline guard reaching an environment-supplied source; the amended
 needs-index sentence naming every declared variable; the seam's two
 constructors (the settled one closing it, the injected one opening
 it); and the variable-name mirror held to the declared table.

 EVERY LAW PINS ITS ENVIRONMENT THROUGH THE SEAM — the suite must be
 immune to the harness process's environment, so no law here or
 anywhere reads the developer's shell by accident: the settled
 two-argument constructor closes the seam by delegation, and the laws
 that drive environment states pass a Dictionary-backed reader.

 COST DECLARATION: the composer-pin law spawns the real shipped binary
 twice (a hostile export cannot be injected into the harness process,
 so it is proved through a child), confined to tmp/ working
 directories. Everything else runs in-image over tmp/ fixtures with a
 RecordingRunner, and no law contacts a network."

Namespace current: Parley.

TestCase subclass: EnvLayerTest [
    | fixtureDirs |

    <comment: 'Law suite for §8 decision 85: the precedence matrix over
distinguishable locks, the ruled config skip, the two-variables refusal
and its contrasts, empty-is-unset, the no-spawn guard over an
environment-supplied source, the amended refusal sentence, the seam
constructors, and the variable-name mirror drift law.'>

    setUp [
        fixtureDirs := OrderedCollection new
    ]

    tearDown [
        fixtureDirs isNil ifTrue: [^self].
        fixtureDirs do: [:each | PathFixtures removeTree: each].
        fixtureDirs := nil
    ]

    tracker [
        ^[:path | fixtureDirs add: path. path]
    ]

    track: aPath [
        fixtureDirs add: aPath.
        ^aPath
    ]

    freshDir: aLabel [
        ^self track: (SourceFixtures directoryNamed: aLabel)
    ]

    realDiamondIndex: aLabel [
        "The install-diamond population: real archive digests, so its
         lock differs from the placeholder population's below — the
         distinguishability every pairwise precedence law leans on."
        | path |
        path := self freshDir: aLabel.
        InstallFixtures populateInstallDiamondIn: path.
        ^path
    ]

    placeholderDiamondIndex: aLabel [
        | path |
        path := self freshDir: aLabel.
        SourceFixtures populateDiamondIn: path.
        ^path
    ]

    absolute: aPath [
        ^CommandLineFixtures absolutePathOf: aPath
    ]

    resultOf: anArgvArray in: aWorkDir env: anEnvReader runner: aRunner [
        ^(CommandLine in: aWorkDir
            runner: aRunner
            environment: anEnvReader) run: anArgvArray
    ]

    lockOracleAgainst: anIndexDir labelled: aLabel [
        "The lock a flagged resolve writes, taken in a control project
         of its own so it is an oracle and not a leftover."
        | control |
        control := ConfigFixtures plainWorkDirTracking: self tracker
            named: aLabel.
        (CommandLine in: control runner: RecordingRunner new)
            run: (ConfigFixtures resolveArgvOn: anIndexDir).
        ^ConfigFixtures lockContentsIn: control
    ]

    "---- the variable-name mirror (P1) ----"

    testTheVariableNamesAreThePerRowFieldOfTheDeclaredTable [
        "EnvFixtures variableNames is a test-side mirror so RED
         fixtures can compose wordings and shipped commands before the
         production column exists; this drift law is what keeps the
         mirror from becoming a second authority. Each name is also
         held to ITS OWN row, because a collect that happened to answer
         the right set in the wrong order would wire --git from
         PARLEY_INDEX."
        self assert: EnvFixtures variableNames asArray
            = CommandLine environmentVariableNames asArray
            description: 'the mirror and the declared table disagree'.
        CommandLine sourceFlags doWithIndex: [:row :i |
            self assert: (row at: 4) = (EnvFixtures variableNames at: i)
                description: 'row ', i printString,
                    ' declares ', (row at: 4) printString]
    ]

    "---- the seam's two constructors (P1) ----"

    testTheSettledConstructorClosesTheSeamAndTheInjectedOneOpensIt [
        "in:runner: delegates with the seam CLOSED — that is what
         makes all 59 settled construction sites immune to the harness
         environment with no edits — and in:runner:environment: is the
         open seam the laws drive. Both halves run over one config so
         the difference is the constructor alone. The closed half is a
         canary on a machine with PARLEY_SOURCE exported: it fails
         there exactly when the seam leaks."
        | envIndex configIndex work envLock configLock result |
        envIndex := self placeholderDiamondIndex: 'env-seam-env-index'.
        configIndex := self realDiamondIndex: 'env-seam-config-index'.
        envLock := self lockOracleAgainst: envIndex
            labelled: 'env-seam-env-oracle'.
        configLock := self lockOracleAgainst: configIndex
            labelled: 'env-seam-config-oracle'.
        self deny: envLock = configLock
            description: 'the two indexes answer one lock - this law could not tell them apart'.
        work := ConfigFixtures workDirTracking: self tracker
            named: 'env-seam-open-work'
            contents: (ConfigFixtures contentsDeclaring: '--source'
                value: (self absolute: configIndex)).
        result := self resultOf: ConfigFixtures resolveArgv
            in: work
            env: (EnvFixtures environmentOf: 'PARLEY_SOURCE'
                value: (self absolute: envIndex))
            runner: RecordingRunner new.
        self assert: result exitCode = 0
            description: 'the open-seam resolve answered ',
                result lines printString.
        self assert: (ConfigFixtures lockContentsIn: work) = envLock
            description: 'the injected environment did not win over the file'.
        work := ConfigFixtures workDirTracking: self tracker
            named: 'env-seam-closed-work'
            contents: (ConfigFixtures contentsDeclaring: '--source'
                value: (self absolute: configIndex)).
        self assert: ((CommandLine in: work runner: RecordingRunner new)
            run: ConfigFixtures resolveArgv) exitCode = 0
            description: 'the closed-seam resolve did not run'.
        self assert: (ConfigFixtures lockContentsIn: work) = configLock
            description: 'the settled constructor consulted an environment'
    ]

    "---- the precedence matrix (S1/S2's law) ----"

    testThePrecedenceChainAnswersFlagThenEnvironmentThenFile [
        "Pairwise over distinguishable locks: a flag beats a set
         variable, and a set variable beats a declaring file. Each
         pair carries its own fixture-correctness guard, because a
         pair answering one lock is a law about nothing (the Sprint 19
         S7 lesson)."
        | flagIndex envIndex fileIndex flagLock envLock fileLock work env |
        flagIndex := self realDiamondIndex: 'env-chain-flag-index'.
        envIndex := self placeholderDiamondIndex: 'env-chain-env-index'.
        flagLock := self lockOracleAgainst: flagIndex
            labelled: 'env-chain-flag-oracle'.
        envLock := self lockOracleAgainst: envIndex
            labelled: 'env-chain-env-oracle'.
        self deny: flagLock = envLock
            description: 'the flag/env pair answers one lock'.
        work := ConfigFixtures plainWorkDirTracking: self tracker
            named: 'env-chain-pair1-work'.
        env := EnvFixtures environmentOf: 'PARLEY_SOURCE'
            value: (self absolute: envIndex).
        self assert: (self resultOf: (ConfigFixtures resolveArgvOn: flagIndex)
            in: work env: env runner: RecordingRunner new) exitCode = 0.
        self assert: (ConfigFixtures lockContentsIn: work) = flagLock
            description: 'the flag did not beat the environment'.
        self assert: (self resultOf: ConfigFixtures resolveArgv
            in: work env: env runner: RecordingRunner new) exitCode = 0.
        self assert: (ConfigFixtures lockContentsIn: work) = envLock
            description: 'the environment level did not supply the source'.
        fileIndex := self realDiamondIndex: 'env-chain-file-index'.
        fileLock := self lockOracleAgainst: fileIndex
            labelled: 'env-chain-file-oracle'.
        self deny: envLock = fileLock
            description: 'the env/file pair answers one lock'.
        work := ConfigFixtures workDirTracking: self tracker
            named: 'env-chain-pair2-work'
            contents: (ConfigFixtures contentsDeclaring: '--source'
                value: (self absolute: fileIndex)).
        self assert: (self resultOf: ConfigFixtures resolveArgv
            in: work env: env runner: RecordingRunner new) exitCode = 0.
        self assert: (ConfigFixtures lockContentsIn: work) = envLock
            description: 'the environment did not beat the file'.
        self assert: (self resultOf: ConfigFixtures resolveArgv
            in: work env: EnvFixtures emptyEnvironment
            runner: RecordingRunner new) exitCode = 0.
        self assert: (ConfigFixtures lockContentsIn: work) = fileLock
            description: 'the file level was not reached with the environment empty'
    ]

    "---- the ruled skip (S4's law) ----"

    testAMalformedConfigurationIsUndiagnosedUnderAFlagAndUnderTheEnvironment [
        "The skip is RULED, not accidental (§8 decision 85): a level
         that wins means the levels below are not consulted, so their
         defects are not diagnosed — the probed mirror of the settled
         flag behavior, driven here on both winning levels, with the
         no-winner control proving the file's own diagnosis is intact
         underneath."
        | index work oracle result |
        index := self realDiamondIndex: 'env-skip-index'.
        oracle := self lockOracleAgainst: index
            labelled: 'env-skip-oracle'.
        work := ConfigFixtures workDirTracking: self tracker
            named: 'env-skip-work'
            contents: ConfigFixtures unparseableContents.
        result := self resultOf: (ConfigFixtures resolveArgvOn: index)
            in: work env: EnvFixtures emptyEnvironment
            runner: RecordingRunner new.
        self assert: result exitCode = 0
            description: 'a flag did not skip the malformed file: ',
                result lines printString.
        result := self resultOf: ConfigFixtures resolveArgv
            in: work
            env: (EnvFixtures environmentOf: 'PARLEY_SOURCE'
                value: (self absolute: index))
            runner: RecordingRunner new.
        self assert: result exitCode = 0
            description: 'the environment did not skip the malformed file: ',
                result lines printString.
        result lines do: [:line |
            self deny: (CommandLineFixtures does: line
                include: 'parley.config.st')
                description: 'the skipped file was diagnosed: ', line].
        self assert: (ConfigFixtures lockContentsIn: work) = oracle
            description: 'the environment-supplied resolve wrote a different lock'.
        result := self resultOf: ConfigFixtures resolveArgv
            in: work env: EnvFixtures emptyEnvironment
            runner: RecordingRunner new.
        self assert: result exitCode = 1
            description: 'with no winning level the malformed file was not diagnosed'.
        self assert: (CommandLineFixtures does: result lines first
            include: 'parley.config.st')
            description: 'the control diagnosis does not name the file: ',
                result lines first
    ]

    "---- the two-variables refusal (S5's law) ----"

    testTwoSetVariablesRefuseNamingBothAndNeverTheUsageBlock [
        "The file's own two-source rule applied to the second supplier
         of recorded state. Four halves: the refusal itself (nothing
         written, nothing spawned); the placement mirror — an argv
         that would answer usage still answers the refusal, exactly as
         a malformed config file does today (P2: the conflict check
         sits where the file read sits, in every case); the flag
         contrast — the same environment with a source flag proceeds,
         unexamined; and empty-does-not-count — an empty variable is
         unset and raises no conflict."
        | index repo work env result refusal |
        index := self realDiamondIndex: 'env-twovar-index'.
        repo := self freshDir: 'env-twovar-repo'.
        work := ConfigFixtures plainWorkDirTracking: self tracker
            named: 'env-twovar-work'.
        env := EnvFixtures environmentOf: 'PARLEY_SOURCE'
            value: (self absolute: index)
            and: 'PARLEY_GIT' value: (self absolute: repo).
        refusal := EnvFixtures twoVariablesRefusalFor: 'PARLEY_SOURCE'
            and: 'PARLEY_GIT'.
        result := self resultOf: ConfigFixtures resolveArgv
            in: work env: env runner: RecordingRunner new.
        self assert: result exitCode = 1
            description: 'two set variables answered exit ',
                result exitCode printString.
        self assert: result lines = (Array with: refusal)
            description: 'the refusal answered ', result lines printString.
        self deny: (PathGuard exists: work, '/.parley')
            description: 'the refusal created project state'.
        self deny: (PathGuard exists: work, '/parley.lock')
            description: 'the refusal wrote a lock'.
        result := self resultOf: (Array with: 'conjure')
            in: work env: env runner: RecordingRunner new.
        self assert: result exitCode = 1
            description: 'an unknown verb with the conflict answered exit ',
                result exitCode printString.
        self assert: result lines = (Array with: refusal)
            description: 'the conflict did not outrank usage: ',
                result lines printString.
        result := self resultOf: (ConfigFixtures resolveArgvOn: index)
            in: work env: env runner: RecordingRunner new.
        self assert: result exitCode = 0
            description: 'a flag did not skip the conflicted environment: ',
                result lines printString.
        result := self resultOf: ConfigFixtures resolveArgv
            in: work
            env: (EnvFixtures environmentOf: 'PARLEY_SOURCE' value: ''
                and: 'PARLEY_GIT' value: (self absolute: repo))
            runner: RecordingRunner new.
        self deny: result lines = (Array with: refusal)
            description: 'an empty variable counted toward the conflict'
    ]

    "---- the --offline guard over the environment (S7's law) ----"

    testOfflineReachesAnEnvironmentSuppliedSource [
        "By construction the environment resolves at wiring into the
         same wired-source value a flag produces — and this law proves
         the no-spawn refusal there rather than trusting the
         construction (§8 decision 85)."
        | repo index work runner result |
        repo := self freshDir: 'env-offline-repo'.
        work := ConfigFixtures plainWorkDirTracking: self tracker
            named: 'env-offline-work'.
        runner := RecordingRunner new.
        result := self resultOf: (Array with: 'resolve' with: '--offline')
            in: work
            env: (EnvFixtures environmentOf: 'PARLEY_GIT'
                value: (self absolute: repo))
            runner: runner.
        self assert: result exitCode = 1
            description: '--offline over PARLEY_GIT answered exit ',
                result exitCode printString.
        self assert: result lines
            = (Array with: (PathDepFixtures offlineRefusalFor: '--git'))
            description: 'the refusal answered ', result lines printString.
        self assert: runner commands = #()
            description: 'the refusal spawned ', runner commands printString.
        index := self realDiamondIndex: 'env-offline-index'.
        result := self resultOf: (Array with: 'resolve' with: '--offline')
            in: work
            env: (EnvFixtures environmentOf: 'PARLEY_SOURCE'
                value: (self absolute: index))
            runner: RecordingRunner new.
        self assert: result exitCode = 0
            description: '--offline refused a local directory source: ',
                result lines printString
    ]

    "---- the amended sentence (S8's law) ----"

    testTheNeedsIndexSentenceNamesEveryDeclaredVariable [
        "The third remedy is composed from the declared table, never
         spelled — so this law asserts the pinned wording AND walks
         the table's variable field, the UsageGroundTest idiom one
         sentence over."
        | work result first |
        work := ConfigFixtures plainWorkDirTracking: self tracker
            named: 'env-sentence-work'.
        result := self resultOf: ConfigFixtures resolveArgv
            in: work env: EnvFixtures emptyEnvironment
            runner: RecordingRunner new.
        self assert: result exitCode = 1
            description: 'a source-less resolve answered exit ',
                result exitCode printString.
        first := result lines first.
        self assert: result lines = (Array with: (PathDepFixtures
            needsIndexRefusalFor: (Array with: 'a' with: 'b')))
            description: 'the declared refusal moved: ', first.
        CommandLine sourceFlags do: [:row |
            self assert: (CommandLineFixtures does: first
                include: (row at: 4))
                description: 'the sentence does not name ',
                    (row at: 4) printString]
    ]

    "---- the composer pins (P1's immunity half) ----"

    testTheShippedComposerPinsDefeatAnExportedVariable [
        "Two real children. The unpinned composition proves an
         exported variable REACHES the shipped chain (bin passes the
         process environment — the one law shape that catches a closed
         production seam); the settled pinned composition proves the
         fixture pins DEFEAT the same export, which is what makes
         every shipped-binary law immune to the harness environment."
        | envIndex configIndex work envLock configLock |
        envIndex := self placeholderDiamondIndex: 'env-pin-env-index'.
        configIndex := self realDiamondIndex: 'env-pin-config-index'.
        envLock := self lockOracleAgainst: envIndex
            labelled: 'env-pin-env-oracle'.
        configLock := self lockOracleAgainst: configIndex
            labelled: 'env-pin-config-oracle'.
        self deny: envLock = configLock
            description: 'the two indexes answer one lock'.
        work := ConfigFixtures workDirTracking: self tracker
            named: 'env-pin-work'
            contents: (ConfigFixtures contentsDeclaring: '--source'
                value: (self absolute: configIndex)).
        ProcessRunner new run: (EnvFixtures unpinnedCommandIn: work
            args: 'resolve'
            exporting: 'PARLEY_SOURCE'
            value: (self absolute: envIndex)).
        self assert: (ConfigFixtures lockContentsIn: work) = envLock
            description: 'the exported variable never reached the shipped chain'.
        ProcessRunner new run: 'export PARLEY_SOURCE=',
            (self absolute: envIndex), '; ',
            (CommandLineFixtures shippedBinaryCommandIn: work
                args: 'resolve').
        self assert: (ConfigFixtures lockContentsIn: work) = configLock
            description: 'the composer pins did not defeat the export'
    ]
]

Namespace current: Smalltalk.
