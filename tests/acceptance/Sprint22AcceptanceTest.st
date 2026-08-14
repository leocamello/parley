"Parley Sprint 22 — acceptance: the release, the environment layer and
 the self-hosting showcase.
 Spec: docs/design/execution-and-cli.md §4.1/§4.2/§4.3/§5; Doc B §4;
 Doc F §1 step 3; §8 decisions 70, 71, 85, 86, 87; issue #24 S1-S30.

 THE SHAPE OF THIS SUITE. S1-S8 drive the precedence chain into the
 settled wiring on fixtures whose locks are distinguishable — the lock
 says which level was consulted, an exit code cannot. S9-S12 are the
 showcase: Parley's own root manifest through the settled boundary,
 the recursive fileIns drift pair, the nested-fileIns pipeline, and
 the package manager packaged by itself. S13 closes the exec cwd
 conformance, S14 proves the deletion, S15-S26 are the release
 machinery with every law driven over a falsifier anchored to the
 real artifact, and S27-S30 close the README.

 EVERY SCENARIO PINS ITS ENVIRONMENT THROUGH THE SEAM: in-image
 drives pass a Dictionary-backed reader or the empty reader to the
 injected constructor, and shipped-binary drives compose the pinned
 or exported variables into the child's own command line — the suite
 is immune to the harness process's environment by construction.

 COST DECLARATION. S2 spawns the real shipped binary once (the one
 law shape that proves the production seam is open — bin passes the
 process environment). S11 and S12 run the real pipeline — a real
 gst-package build, a real registration, a real curated child — S12
 over Parley's own 48-file tree, because a showcase a double can
 satisfy is not a showcase; both are confined to tmp/ destinations
 and consumer directories, and the repository tree is read, never
 written. Everything else runs in-image over tmp/ fixtures with a
 RecordingRunner. Declared passes-in-red: S24, S25, S26 — each a law
 over an artifact that already conforms; every other selector fails
 red."

Namespace current: Parley.

TestCase subclass: Sprint22AcceptanceTest [
    | fixtureDirs |

    <comment: 'The Sprint 22 acceptance scenarios: the environment
layer''s precedence chain, ruled skip and refusals; the self-hosting
showcase and the nested-fileIns pipeline; the exec working-directory
conformance; the ApplicationManifest deletion; the release manifest,
CHANGELOG, completions and CI drift laws with their falsifiers; and
the restructured README.'>

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
        | control |
        control := ConfigFixtures plainWorkDirTracking: self tracker
            named: aLabel.
        (CommandLine in: control runner: RecordingRunner new)
            run: (ConfigFixtures resolveArgvOn: anIndexDir).
        ^ConfigFixtures lockContentsIn: control
    ]

    contentsOf: aPath [
        ^(File name: aPath) contents
    ]

    "---- S1: a flag beats the environment ----"

    testS1_AFlagBeatsTheEnvironment [
        "resolve --source A with PARLEY_SOURCE=B pins from A on a
         fixture where the two answer distinguishable pins; B is never
         consulted, and the lock is what says so."
        | flagIndex envIndex flagLock envLock work result |
        flagIndex := self realDiamondIndex: 's22-1-flag-index'.
        envIndex := self placeholderDiamondIndex: 's22-1-env-index'.
        flagLock := self lockOracleAgainst: flagIndex
            labelled: 's22-1-flag-oracle'.
        envLock := self lockOracleAgainst: envIndex
            labelled: 's22-1-env-oracle'.
        self deny: flagLock = envLock
            description: 'the two indexes answer one lock - this scenario could not tell them apart'.
        work := ConfigFixtures plainWorkDirTracking: self tracker
            named: 's22-1-work'.
        result := self resultOf: (ConfigFixtures resolveArgvOn: flagIndex)
            in: work
            env: (EnvFixtures environmentOf: 'PARLEY_SOURCE'
                value: (self absolute: envIndex))
            runner: RecordingRunner new.
        self assert: result exitCode = 0
            description: 'the flagged resolve answered ',
                result lines printString.
        self assert: (ConfigFixtures lockContentsIn: work) = flagLock
            description: 'the flag did not win over the environment'.
        self deny: (ConfigFixtures lockContentsIn: work) = envLock
            description: 'the environment level was consulted under a flag'
    ]

    "---- S2: the environment beats the file, through the shipped binary ----"

    testS2_TheEnvironmentBeatsTheFileThroughTheShippedBinary [
        "REQUIRED THROUGH THE REAL BINARY (pre-RED P1 ruling): an
         exported variable defeating the config file proves the
         production seam is open — bin/parley-main.st passes the
         process environment — which no in-image double can prove."
        | envIndex fileIndex envLock fileLock work code |
        envIndex := self placeholderDiamondIndex: 's22-2-env-index'.
        fileIndex := self realDiamondIndex: 's22-2-file-index'.
        envLock := self lockOracleAgainst: envIndex
            labelled: 's22-2-env-oracle'.
        fileLock := self lockOracleAgainst: fileIndex
            labelled: 's22-2-file-oracle'.
        self deny: envLock = fileLock
            description: 'the two indexes answer one lock - this scenario could not tell them apart'.
        work := ConfigFixtures workDirTracking: self tracker
            named: 's22-2-work'
            contents: (ConfigFixtures contentsDeclaring: '--source'
                value: (self absolute: fileIndex)).
        code := ProcessRunner new run:
            (EnvFixtures shippedCommandIn: work
                args: 'resolve'
                exporting: 'PARLEY_SOURCE'
                value: (self absolute: envIndex)).
        self assert: code = 0
            description: 'the shipped flagless resolve exited ',
                code printString.
        self assert: (ConfigFixtures lockContentsIn: work) = envLock
            description: 'the exported variable did not beat the config file'.
        self deny: (ConfigFixtures lockContentsIn: work) = fileLock
            description: 'the file level was consulted under the environment'
    ]

    "---- S3: each variable wires its kind ----"

    testS3_EachVariableWiresItsKind [
        "PARLEY_GIT wires the git source (the settled cache under
         .parley/git/<sha256 of the repo>), PARLEY_INDEX wires the
         sparse source — flagless, observable through the settled
         wiring on a recording runner where a spawn would occur."
        | repo base work runner result |
        repo := self freshDir: 's22-3-repo'.
        work := ConfigFixtures plainWorkDirTracking: self tracker
            named: 's22-3-git-work'.
        runner := RecordingRunner new.
        result := self resultOf: ConfigFixtures resolveArgv
            in: work
            env: (EnvFixtures environmentOf: 'PARLEY_GIT'
                value: (self absolute: repo))
            runner: runner.
        self deny: runner commands isEmpty
            description: 'PARLEY_GIT wired nothing that spawns'.
        self assert: runner commands first
            = ('git clone --quiet ', (self absolute: repo), ' ',
                work, '/.parley/git/',
                (Sha256 hexDigestOf: (self absolute: repo)))
            description: 'the git wiring composed ',
                runner commands first printString.
        base := 'tmp/parley-s22-3-base'.
        work := ConfigFixtures plainWorkDirTracking: self tracker
            named: 's22-3-index-work'.
        runner := RecordingRunner new.
        result := self resultOf: ConfigFixtures resolveArgv
            in: work
            env: (EnvFixtures environmentOf: 'PARLEY_INDEX' value: base)
            runner: runner.
        self deny: runner commands isEmpty
            description: 'PARLEY_INDEX wired nothing that spawns'.
        self assert: (runner commands first startsWith: 'curl -sfS ', base)
            description: 'the sparse wiring composed ',
                runner commands first printString.
        self assert: (CommandLineFixtures does: runner commands first
            include: work, '/.parley/index/', (Sha256 hexDigestOf: base))
            description: 'the sparse cache is not the working directory''s: ',
                runner commands first printString
    ]

    "---- S4: the ruled skip ----"

    testS4_AMalformedConfigIsNotDiagnosedUnderTheEnvironment [
        "The probed mirror of the settled flag behavior, driven
         explicitly so it is ruled rather than accidental: an
         environment-supplied source skips the file, malformations
         included."
        | index oracle work result |
        index := self realDiamondIndex: 's22-4-index'.
        oracle := self lockOracleAgainst: index
            labelled: 's22-4-oracle'.
        work := ConfigFixtures workDirTracking: self tracker
            named: 's22-4-work'
            contents: ConfigFixtures unparseableContents.
        result := self resultOf: ConfigFixtures resolveArgv
            in: work
            env: (EnvFixtures environmentOf: 'PARLEY_SOURCE'
                value: (self absolute: index))
            runner: RecordingRunner new.
        self assert: result exitCode = 0
            description: 'the environment-supplied resolve answered exit ',
                result exitCode printString, ': ', result lines printString.
        result lines do: [:line |
            self deny: (CommandLineFixtures does: line
                include: 'parley.config.st')
                description: 'the skipped file was diagnosed: ', line].
        self assert: (ConfigFixtures lockContentsIn: work) = oracle
            description: 'the resolve did not pin from the environment''s index'
    ]

    "---- S5: two variables set, argv flagless ----"

    testS5_TwoSetVariablesRefuseNamingBothAndAFlagProceeds [
        | index repo work env runner result |
        index := self realDiamondIndex: 's22-5-index'.
        repo := self freshDir: 's22-5-repo'.
        work := ConfigFixtures plainWorkDirTracking: self tracker
            named: 's22-5-work'.
        env := EnvFixtures environmentOf: 'PARLEY_SOURCE'
            value: (self absolute: index)
            and: 'PARLEY_GIT' value: (self absolute: repo).
        runner := RecordingRunner new.
        result := self resultOf: ConfigFixtures resolveArgv
            in: work env: env runner: runner.
        self assert: result exitCode = 1
            description: 'two set variables answered exit ',
                result exitCode printString.
        self assert: result lines = (Array with:
            (EnvFixtures twoVariablesRefusalFor: 'PARLEY_SOURCE'
                and: 'PARLEY_GIT'))
            description: 'the refusal answered ', result lines printString.
        self assert: runner commands = #()
            description: 'the refusal spawned ', runner commands printString.
        self deny: (PathGuard exists: work, '/.parley')
            description: 'the refusal created project state'.
        self deny: (PathGuard exists: work, '/parley.lock')
            description: 'the refusal wrote a lock'.
        result := self resultOf: (ConfigFixtures resolveArgvOn: index)
            in: work env: env runner: RecordingRunner new.
        self assert: result exitCode = 0
            description: 'the same environment with a flag answered exit ',
                result exitCode printString, ': ', result lines printString
    ]

    "---- S6: empty means unset ----"

    testS6_AnEmptyVariableIsUnset [
        | index oracle work result |
        index := self realDiamondIndex: 's22-6-index'.
        oracle := self lockOracleAgainst: index
            labelled: 's22-6-oracle'.
        work := ConfigFixtures workDirTracking: self tracker
            named: 's22-6-work'
            contents: (ConfigFixtures contentsDeclaring: '--source'
                value: (self absolute: index)).
        result := self resultOf: ConfigFixtures resolveArgv
            in: work
            env: (EnvFixtures environmentOf: 'PARLEY_SOURCE' value: '')
            runner: RecordingRunner new.
        self assert: result exitCode = 0
            description: 'an empty variable beside a config answered exit ',
                result exitCode printString, ': ', result lines printString.
        self assert: (ConfigFixtures lockContentsIn: work) = oracle
            description: 'the file level was not reached past the empty variable'
    ]

    "---- S7: --offline over an environment-supplied source ----"

    testS7_OfflineRefusesAnEnvironmentGitAndAcceptsADirectory [
        | repo index work runner result |
        repo := self freshDir: 's22-7-repo'.
        work := ConfigFixtures plainWorkDirTracking: self tracker
            named: 's22-7-work'.
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
        index := self realDiamondIndex: 's22-7-index'.
        result := self resultOf: (Array with: 'resolve' with: '--offline')
            in: work
            env: (EnvFixtures environmentOf: 'PARLEY_SOURCE'
                value: (self absolute: index))
            runner: RecordingRunner new.
        self assert: result exitCode = 0
            description: '--offline refused a directory source: ',
                result lines printString
    ]

    "---- S8: the needs-index refusal names the variables ----"

    testS8_TheNeedsIndexRefusalNamesTheVariables [
        | work result |
        work := ConfigFixtures plainWorkDirTracking: self tracker
            named: 's22-8-work'.
        result := self resultOf: ConfigFixtures resolveArgv
            in: work env: EnvFixtures emptyEnvironment
            runner: RecordingRunner new.
        self assert: result exitCode = 1
            description: 'a source-less resolve answered exit ',
                result exitCode printString.
        self assert: result lines = (Array with: (PathDepFixtures
            needsIndexRefusalFor: (Array with: 'a' with: 'b')))
            description: 'the declared refusal moved: ',
                result lines printString.
        EnvFixtures variableNames do: [:name |
            self assert: (CommandLineFixtures does: result lines first
                include: name)
                description: 'the refusal does not name ', name].
        result lines do: [:line |
            self deny: (CommandLineFixtures does: line
                include: 'usage: parley')
                description: 'the refusal carried the usage block']
    ]

    "---- S9: the root Package.st loads and matches the constant ----"

    testS9_TheRootManifestLoadsAndItsVersionEqualsTheConstant [
        | manifest |
        manifest := ShowcaseFixtures rootManifest.
        self assert: manifest name = 'parley'
            description: 'the root manifest is named ',
                manifest name printString.
        self assert: manifest version
            = (Version fromString: Parley version)
            description: 'the manifest declares ',
                manifest version printString,
                ' while Parley version answers ', Parley version
    ]

    "---- S10: the fileIns drift law, recursive, with its falsifier ----"

    testS10_TheFileInsEqualTheRecursiveWalkAndTheComparisonCanFail [
        | walk manifest |
        walk := ReleaseFixtures srcFileWalk.
        self deny: walk isEmpty
            description: 'the recursive walk answered nothing'.
        manifest := ShowcaseFixtures rootManifest.
        self assert: (ReleaseFixtures fileInsMatch: manifest fileIns
            walk: walk)
            description: 'the fileIns and the recursive src walk disagree'.
        self deny: (ReleaseFixtures fileInsMatch: manifest fileIns
            walk: (walk copyFrom: 2 to: walk size))
            description: 'the comparison cannot see a removed name'
    ]

    "---- S11: nested fileIns publish end to end ----"

    testS11_ANestedFileInPublishesInstallsAndAnswersInTheChild [
        "The small fixture, not Parley: the stage carries the nested
         path with parents created byte-exact, the star builds and
         registers, and the curated child answers the NESTED class -
         a proof that asked only for the top-level one would pass
         over a stage that dropped the subdirectory. Real toolchain,
         tmp/-confined."
        | author dest consumer runner result proofPath |
        runner := ProcessRunner new.
        author := self freshDir: 's22-11-author'.
        ShowcaseFixtures writeNestedProjectIn: author.
        dest := self freshDir: 's22-11-index'.
        result := self resultOf: (Array with: 'publish' with: dest)
            in: author env: EnvFixtures emptyEnvironment runner: runner.
        self assert: result exitCode = 0
            description: 'the nested publish answered ',
                result lines printString.
        self assert: (PathGuard isReadableFile:
            dest, '/kernel-nested-1.0.0.star')
            description: 'the nested star did not land'.
        self deny: (PathGuard exists: dest, '/.parley-publish-stage')
            description: 'the stage survived a successful publish'.
        consumer := self freshDir: 's22-11-consumer'.
        SourceFixtures write: ShowcaseFixtures nestedConsumerContents
            toFile: 'Package.st' in: consumer.
        result := self resultOf: (Array with: 'resolve'
            with: '--source' with: dest)
            in: consumer env: EnvFixtures emptyEnvironment runner: runner.
        self assert: result exitCode = 0
            description: 'the consumer resolve answered ',
                result lines printString.
        result := self resultOf: (Array with: 'install'
            with: '--source' with: dest)
            in: consumer env: EnvFixtures emptyEnvironment runner: runner.
        self assert: result exitCode = 0
            description: 'the consumer install answered ',
                result lines printString.
        proofPath := consumer, '/proof.txt'.
        SourceFixtures write: (ShowcaseFixtures
            nestedProofScriptContentsFor: proofPath)
            toFile: 'proof.st' in: consumer.
        result := self resultOf: (Array with: 'exec' with: 'proof.st')
            in: consumer env: EnvFixtures emptyEnvironment runner: runner.
        self assert: result exitCode = 0
            description: 'the consumer exec answered exit ',
                result exitCode printString.
        self assert: (self contentsOf: proofPath) = 'present'
            description: 'the curated child could not answer the nested class'
    ]

    "---- S12: the showcase loop ----"

    testS12_ParleyPublishesInstallsAndAnswersItself [
        "Parley's own root manifest into a transient index, a consumer
         resolving and installing parley-1.0.0, and a curated child
         making the gateway ANSWER its version - the package manager,
         packaged by itself, proved on every run. The publish reads
         the repository tree and writes only into the tmp/
         destination; the showcase index is transient and never
         committed."
        | manifest dest digest consumer runner result proofPath pinLine |
        runner := ProcessRunner new.
        manifest := ShowcaseFixtures rootManifest.
        dest := self freshDir: 's22-12-index'.
        digest := (Publisher manifest: manifest
            in: ShowcaseFixtures repositoryRoot
            to: dest
            runner: runner) publish.
        self assert: (SchemaShape isHexDigest: digest)
            description: 'the showcase publish answered ',
                digest printString.
        consumer := self freshDir: 's22-12-consumer'.
        SourceFixtures write: ShowcaseFixtures showcaseConsumerContents
            toFile: 'Package.st' in: consumer.
        pinLine := 'parley ', Parley version.
        result := self resultOf: (Array with: 'resolve'
            with: '--source' with: dest)
            in: consumer env: EnvFixtures emptyEnvironment runner: runner.
        self assert: result exitCode = 0
            description: 'the consumer resolve answered ',
                result lines printString.
        self assert: result lines = (Array with: pinLine)
            description: 'the resolve did not pin parley: ',
                result lines printString.
        result := self resultOf: (Array with: 'install'
            with: '--source' with: dest)
            in: consumer env: EnvFixtures emptyEnvironment runner: runner.
        self assert: result exitCode = 0
            description: 'the consumer install answered ',
                result lines printString.
        proofPath := consumer, '/proof.txt'.
        SourceFixtures write: (ShowcaseFixtures
            showcaseProofScriptContentsFor: proofPath)
            toFile: 'proof.st' in: consumer.
        result := self resultOf: (Array with: 'exec' with: 'proof.st')
            in: consumer env: EnvFixtures emptyEnvironment runner: runner.
        self assert: result exitCode = 0
            description: 'the consumer exec answered exit ',
                result exitCode printString.
        self assert: (self contentsOf: proofPath) = Parley version
            description: 'the curated child answered ',
                (self contentsOf: proofPath) printString,
                ' instead of the gateway''s version'
    ]

    "---- S13: exec resolves the script against the working directory ----"

    testS13_ExecResolvesTheScriptAgainstTheWorkingDirectory [
        "Both halves on a recording runner. A script existing only at
         W/<name> runs, the pinned child line carrying the
         workdir-resolved path; a script existing only at the process
         cwd answers the settled refusal naming the workdir-resolved
         path, spawning nothing."
        | work runner result decoyDir |
        work := self freshDir: 's22-13-work'.
        ExecFixtures writePackage: ExecFixtures noDependencyRootContents
            in: work.
        SourceFixtures write: (ExecFixtures quitScriptContentsFor: 0)
            toFile: 'w13.st' in: work.
        runner := RecordingRunner answering: 7.
        result := self resultOf: (Array with: 'exec' with: 'w13.st')
            in: work env: EnvFixtures emptyEnvironment runner: runner.
        self assert: result exitCode = 7
            description: 'the workdir-resolved exec answered exit ',
                result exitCode printString, ': ', result lines printString.
        self assert: runner commands = (Array with:
            'gst -g -i -I ', work,
            '/.parley/packages/parley.im --no-user-files ',
            work, '/w13.st')
            description: 'the child line did not carry the resolved path: ',
                runner commands printString.
        decoyDir := self freshDir: 's22-13-decoy'.
        SourceFixtures write: (ExecFixtures quitScriptContentsFor: 0)
            toFile: 'run.st' in: decoyDir.
        runner := RecordingRunner new.
        result := self resultOf: (Array with: 'exec'
            with: decoyDir, '/run.st')
            in: work env: EnvFixtures emptyEnvironment runner: runner.
        self assert: result exitCode = 1
            description: 'a cwd-only script answered exit ',
                result exitCode printString.
        self assert: result lines = (Array with:
            (ReadinessFixtures execRefusalLineFor:
                work, '/', decoyDir, '/run.st'))
            description: 'the refusal named ', result lines printString.
        self assert: runner commands = #()
            description: 'the refusal spawned ', runner commands printString
    ]

    "---- S14: the deletion ----"

    testS14_TheNamespaceNoLongerBindsApplicationManifest [
        "Fails red while the class exists; green when the GREEN stage
         deletes src/manifest/ApplicationManifest.st - deleted, never
         commented out."
        self deny: ((Smalltalk at: #Parley)
            includesKey: #ApplicationManifest)
            description: 'the Parley namespace still binds ApplicationManifest'
    ]

    "---- S15/S16: the release walk and its falsifier ----"

    testS15_EveryDeclaredReleaseFileExistsAndIsNonEmpty [
        | missing |
        self deny: Parley releaseFiles isEmpty
            description: 'the release declaration is empty'.
        missing := ReleaseFixtures missingReleaseFilesIn:
            Parley releaseFiles.
        self assert: missing isEmpty
            description: 'declared release files are missing or empty: ',
                missing printString
    ]

    testS16_TheReleaseWalkIsProvedAbleToFail [
        | missing |
        missing := ReleaseFixtures missingReleaseFilesIn:
            (Parley releaseFiles,
                (Array with: 'no-such-release-file.md')).
        self assert: missing asArray
            = (Array with: 'no-such-release-file.md')
            description: 'the walk did not isolate the absent name: ',
                missing printString
    ]

    "---- S17/S18/S19: the CHANGELOG laws and their falsifiers ----"

    testS17_TheNewestChangelogHeadingEqualsTheVersion [
        self assert: (ReleaseFixtures newestVersionHeadingIn:
            ReleaseFixtures changelogText) = Parley version
            description: 'the newest heading is not ', Parley version
    ]

    testS18_TheHeadingSetEqualsTheReleasedSetWithNoUnreleased [
        | text |
        text := ReleaseFixtures changelogText.
        self assert: (ReleaseFixtures headingSet: text
            equals: (Array with: Parley version))
            description: 'the heading set is ',
                (ReleaseFixtures versionHeadingsIn: text) printString.
        self deny: (CommandLineFixtures does: text include: '[Unreleased]')
            description: 'the changelog carries an Unreleased heading'
    ]

    testS19_TheChangelogLawsAreProvedAbleToFail [
        | text doubled |
        text := ReleaseFixtures changelogText.
        self deny: (ReleaseFixtures newestVersionHeadingIn: text)
            = (Parley version, '.1')
            description: 'the comparison cannot see a bumped constant'.
        doubled := text, (String with: Character nl),
            '## [', Parley version, '] - duplicated',
            (String with: Character nl).
        self deny: (ReleaseFixtures headingSet: doubled
            equals: (Array with: Parley version))
            description: 'the comparison cannot see a duplicated heading'
    ]

    "---- S20-S23: the completions ----"

    testS20_TheBashCompletionOffersExactlyTheDeclaredVerbs [
        self assert: (CommandLineFixtures does:
            CompletionFixtures committedBashText
            include: 'compgen -W "',
                (CompletionFixtures spaceJoined:
                    CompletionFixtures verbWords), '"')
            description: 'the bash completion does not offer the declared verb list'
    ]

    testS21_TheZshCompletionOffersExactlyTheSameVerbs [
        self assert: (CommandLineFixtures does:
            CompletionFixtures committedZshText
            include: '1:verb:(',
                (CompletionFixtures spaceJoined:
                    CompletionFixtures verbWords), ')')
            description: 'the zsh completion does not offer the declared verb list'
    ]

    testS22_BothCompletionsOfferExactlyTheDeclaredFlags [
        "The source flags, the mode flags, the layout values, and the
         question flags - the P3 amendment ruled the last in."
        | bash zsh |
        bash := CompletionFixtures committedBashText.
        zsh := CompletionFixtures committedZshText.
        CompletionFixtures flagWords do: [:flag |
            self assert: (CommandLineFixtures does: bash include: flag)
                description: 'the bash completion omits ', flag.
            self assert: (CommandLineFixtures does: zsh include: flag)
                description: 'the zsh completion omits ', flag].
        self assert: (CommandLineFixtures does: bash
            include: 'compgen -W "',
                (CompletionFixtures spaceJoined:
                    CompletionFixtures layoutWords), '"')
            description: 'the bash completion does not offer the layout values'.
        self assert: (CommandLineFixtures does: zsh
            include: ':layout:(',
                (CompletionFixtures spaceJoined:
                    CompletionFixtures layoutWords), ')')
            description: 'the zsh completion does not offer the layout values'
    ]

    testS23_TheCompletionComparisonIsProvedAbleToFail [
        self deny: CompletionFixtures committedBashText
            = (CompletionFixtures bashTextOverVerbWords:
                CompletionFixtures grownVerbWords)
            description: 'the bash comparison cannot see a grown verb table'.
        self deny: CompletionFixtures committedZshText
            = (CompletionFixtures zshTextOverVerbWords:
                CompletionFixtures grownVerbWords)
            description: 'the zsh comparison cannot see a grown verb table'
    ]

    "---- S24: the CI drift law (DECLARED PASS-IN-RED) ----"

    testS24_TheWorkflowRunsTheOneGateAndTheCheckCanFail [
        "The workflow has named the one gate since H0, so this law
         passes in red by declaration. The bound is textual and stated
         in the checker: it proves the workflow NAMES
         verify-sprint.sh --phase green twice with the second seed
         explicit and non-default, and names no other test entry
         point; what a YAML engine does with the text is outside the
         claim (§8 decision 71, decision 43's standard). The
         falsifier halves drive the same checker over doctored copies
         of the real text."
        | text nl |
        text := self contentsOf: ReleaseFixtures verifyWorkflowPath.
        nl := String with: Character nl.
        self assert: (ReleaseFixtures workflowRunsTheOneGate: text)
            description: 'the workflow does not name the one gate as ruled'.
        self deny: (ReleaseFixtures workflowRunsTheOneGate:
            text, nl, '        run: ./scripts/verify-sprint.sh --phase green', nl)
            description: 'the checker cannot see a third gate invocation'.
        self deny: (ReleaseFixtures workflowRunsTheOneGate:
            text, nl, '        run: gst scripts/run-tests.st', nl)
            description: 'the checker cannot see a second entry point'.
        self deny: (ReleaseFixtures workflowRunsTheOneGate:
            '        run: ./scripts/verify-sprint.sh', nl)
            description: 'the checker accepts a gate without the explicit phase'
    ]

    "---- S25: the wrap staging list vs the scope (DECLARED PASS-IN-RED) ----"

    testS25_EveryWrapStagedPathIsAdmittedByTheActiveScope [
        "Row 15's law: everything wrap-sprint.sh stages, over existing
         files, is admitted by the active scope-<N> regex - so a wrap
         can never stage what the sentinel rejects. The mini-matcher's
         honesty is its shape guard: every alternative is a prefix or
         an anchored literal, and any other construct fails the law
         loudly rather than matching wrongly."
        | wrap scope alternatives tokens notesPath |
        wrap := self contentsOf: ReleaseFixtures wrapScriptPath.
        scope := self contentsOf: ReleaseFixtures scopePath.
        alternatives := ReleaseFixtures activeScopeAlternativesIn: scope.
        self deny: alternatives isEmpty
            description: 'no active scope alternatives were read'.
        self assert: (ReleaseFixtures alternativesAreWellShaped:
            alternatives)
            description: 'the scope regex grew a construct the matcher cannot represent: ',
                alternatives printString.
        self deny: (ReleaseFixtures path: 'operator/kickoffs/sprint-22.md'
            admittedBy: alternatives)
            description: 'the matcher admits the operator-local tree - it cannot refuse anything'.
        tokens := ReleaseFixtures stagedTokensIn: wrap.
        self deny: tokens isEmpty
            description: 'no staged paths were read from the wrap script'.
        tokens do: [:token |
            (token endsWith: '/')
                ifTrue: [
                    (ReleaseFixtures filesUnder:
                        (token copyFrom: 1 to: token size - 1))
                        do: [:path |
                            self assert: (ReleaseFixtures path: path
                                admittedBy: alternatives)
                                description: token, ' stages ', path,
                                    ', which the scope does not admit']]
                ifFalse: [
                    (PathGuard exists: token) ifTrue: [
                        self assert: (ReleaseFixtures path: token
                            admittedBy: alternatives)
                            description: token,
                                ' is staged and not admitted']]].
        notesPath := 'docs/sprints/sprint-22-notes.md'.
        self assert: (ReleaseFixtures path: notesPath
            admittedBy: alternatives)
            description: 'the sprint notes path is not admitted'
    ]

    "---- S26: the sprints index (DECLARED PASS-IN-RED) ----"

    testS26_EveryIndexRowNamesAnExistingNotesFileAndBack [
        | named onDisk doctored |
        named := ReleaseFixtures notesFilesNamedIn:
            (self contentsOf: ReleaseFixtures sprintsIndexPath).
        onDisk := ReleaseFixtures notesFilesOnDisk.
        self deny: named isEmpty
            description: 'the index names no notes files'.
        self assert: named = onDisk
            description: 'the index and the directory disagree: ',
                named printString, ' vs ', onDisk printString.
        doctored := (self contentsOf: ReleaseFixtures sprintsIndexPath),
            (String with: Character nl),
            '- [Sprint 99](sprint-99-notes.md)'.
        self deny: (ReleaseFixtures notesFilesNamedIn: doctored) = onDisk
            description: 'the index parser cannot see a phantom row'
    ]

    "---- S27-S30: the README ----"

    testS27_TheReadmeOpensWithBadgePitchInstallationAndTheHero [
        | readme badgeIdx installIdx heroIdx |
        readme := ReleaseFixtures readmeText.
        badgeIdx := readme indexOfSubCollection:
            ReleaseFixtures badgeMarker.
        installIdx := readme indexOfSubCollection:
            ReleaseFixtures installingHeading.
        heroIdx := readme indexOfSubCollection:
            ReleaseFixtures heroHeading.
        self assert: badgeIdx > 0
            description: 'the README carries no CI badge'.
        self assert: installIdx > 0
            description: 'the README has no Installing section'.
        self assert: heroIdx > 0
            description: 'the README has no sixty-second hero'.
        self assert: badgeIdx < installIdx
            description: 'the badge does not precede installation'.
        self assert: installIdx < heroIdx
            description: 'installation does not precede the hero walk'.
        self assert: (CommandLineFixtures does:
            (ReleaseFixtures sectionOf: ReleaseFixtures heroHeading
                in: readme)
            include: ReleaseFixtures heroContentMarker)
            description: 'the hero slot does not carry the path-dependency walk'
    ]

    testS28_HowThisWasBuiltLinksTheRecordAndQuotesTheTally [
        | readme section findings |
        readme := ReleaseFixtures readmeText.
        self assert: (readme indexOfSubCollection:
            ReleaseFixtures howBuiltHeading) > 0
            description: 'the README has no how-built section'.
        section := ReleaseFixtures sectionOf:
            ReleaseFixtures howBuiltHeading in: readme.
        ReleaseFixtures specFileNames do: [:each |
            self assert: (CommandLineFixtures does: section include: each)
                description: 'how-built does not link ', each].
        self assert: (CommandLineFixtures does: section
            include: 'docs/sprints/')
            description: 'how-built does not link the sprint records'.
        self assert: (CommandLineFixtures does: section
            include: ReleaseFixtures findingsPath)
            description: 'how-built does not link the findings file'.
        findings := self contentsOf: ReleaseFixtures findingsPath.
        ReleaseFixtures tallyLabels do: [:label |
            self assert: (ReleaseFixtures tallyCountFor: label in: readme)
                = (ReleaseFixtures tallyCountFor: label in: findings)
                description: 'the README and findings.md disagree on ',
                    label]
    ]

    testS29_TheLawCountSentenceMatchesTheDiscoveredSuite [
        | count |
        count := ReleaseFixtures discoveredLawCount.
        self assert: count > 0
            description: 'the discovery counted nothing'.
        self assert: (CommandLineFixtures does:
            ReleaseFixtures readmeText
            include: (ReleaseFixtures lawCountMarkerFor: count))
            description: 'the README does not state the discovered count of ',
                count printString
    ]

    testS30_TheShowcaseSectionSitsBesideHowThisWasBuilt [
        | readme howIdx showcaseIdx afterHow nextIdx nextHeading |
        readme := ReleaseFixtures readmeText.
        howIdx := readme indexOfSubCollection:
            ReleaseFixtures howBuiltHeading.
        showcaseIdx := readme indexOfSubCollection:
            ReleaseFixtures showcaseHeading.
        self assert: howIdx > 0
            description: 'the README has no how-built section'.
        self assert: showcaseIdx > 0
            description: 'the README has no showcase section'.
        self assert: howIdx < showcaseIdx
            description: 'the showcase precedes how-built'.
        afterHow := readme copyFrom:
            howIdx + ReleaseFixtures howBuiltHeading size
            to: readme size.
        nextIdx := afterHow indexOfSubCollection:
            (String with: Character nl), '## '.
        self assert: nextIdx > 0
            description: 'no section follows how-built'.
        nextHeading := afterHow copyFrom: nextIdx + 1
            to: (afterHow size min:
                nextIdx + ReleaseFixtures showcaseHeading size).
        self assert: nextHeading = ReleaseFixtures showcaseHeading
            description: 'the section beside how-built is ',
                nextHeading printString.
        self deny: (CommandLineFixtures does:
            (ReleaseFixtures sectionOf: ReleaseFixtures heroHeading
                in: readme)
            include: ReleaseFixtures showcaseHeading)
            description: 'the showcase took the hero slot'
    ]
]

Namespace current: Smalltalk.
