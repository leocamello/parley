"Parley Sprint 20 - acceptance scenarios S1-S23 (issue #22).

 THE VERBS THAT CLOSE THE GRAMMAR. remove, search, info and outdated
 are present in all seven of the package managers this project
 benchmarks against and were absent here. None is new machinery:
 remove is §8 decision 49's recognizer applied to deletion, info and
 search read what the source layer already answers, and outdated
 compares the lock against the snapshot. Two riders travel with them -
 the usage first lines (§8 decisions 79 and 81) and the F19 git chatter
 gap (§8 decision 77).

 RISKIEST WORK LOWEST-NUMBERED. remove's splice can write a Package.st
 that no longer loads, which is the only failure in this sprint that
 damages a file the operator owns, so S1-S7 come first and every one of
 them is asserted on the ARTIFACTS - the files read back and compared
 byte for byte against HAND-WRITTEN oracles - never on an exit code.

 THREE SCENARIOS EXIST BECAUSE A CHEAPER BUILD PASSES ALL THE OTHERS.
 S2 is the one a splice that deletes only the clause's own text fails
 after passing S1. S6 and S7 are the two a non-atomic remove fails
 after passing S1-S5. S23 is the one a closure-only info fails after
 passing S17-S19, having answered `not published` about a package the
 index really publishes.

 THE CHATTER SCENARIOS CAPTURE BOTH STREAMS SEPARATELY, through Sprint
 18's runShippedIn:args:captures:label:. The settled runners merge with
 2>&1 and cannot tell text Parley kept on one stream from text it must
 remove from the other - which is exactly why F19 shipped: no law in
 this suite had ever captured streams on a --git verb.

 DECLARED PASSES IN RED (issue #22): NONE. Every scenario drives a verb
 or a first line the pre-sprint tree does not have: the four new argvs
 answer the usage lines at exit 2 where these demand 0 or 1, the usage
 scenarios demand a reason line nothing composes yet, and the chatter
 scenarios demand zero bytes on a stream that today carries git's own
 text. No scenario asserts exit 2 alone.

 Every fixture path is under tmp/, unique per label AND per flag -
 Sprint 19 lost a scenario to one directory name colliding across two
 iterations of a driver loop - and removed recursively in tearDown,
 which unlocks before it removes. Real processes appear only in S20-S23,
 where the law under test IS execution; no network is contacted, and
 every git repository is a local path under tmp/."

Namespace current: Parley.

TestCase subclass: Sprint20AcceptanceTest [
    | fixtureDirs |

    <comment: 'The Sprint 20 acceptance scenarios: remove''s splice,
separator, refusals, atomicity and held pins; the four usage grounds
and the --help decoupling; search''s hits, empty answer and sparse
refusal; the no-resolver proof; outdated''s two columns; info''s fields,
marked retirements and unknown package; and the git chatter gap on both
streams, cold and warm, without silencing failure.'>

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

    absentPath: aLabel [
        ^self track: (SourceFixtures missingPathNamed: aLabel)
    ]

    absolute: aPath [
        ^CommandLineFixtures absolutePathOf: aPath
    ]

    captures: aLabel [
        ^AuthoringFixtures captureDirTracking: self tracker named: aLabel
    ]

    removeIndex: aLabel [
        | path |
        path := self freshDir: aLabel.
        RemoveFixtures populateRemoveIndexIn: path.
        ^path
    ]

    grammarIndex: aLabel [
        | path |
        path := self freshDir: aLabel.
        GrammarFixtures populateGrammarIndexIn: path.
        ^path
    ]

    sparseBase: aLabel [
        | path |
        path := self freshDir: aLabel.
        GrammarFixtures populateSparseBaseIn: path.
        ^path
    ]

    resultOf: anArgvArray in: aWorkDir runner: aRunner [
        ^(CommandLine in: aWorkDir runner: aRunner) run: anArgvArray
    ]

    resultOf: anArgvArray in: aWorkDir [
        ^self resultOf: anArgvArray in: aWorkDir runner: RecordingRunner new
    ]

    over: anIndexDir run: anArgvArray in: aWorkDir [
        ^self resultOf: anArgvArray , (Array with: '--source' with: anIndexDir)
            in: aWorkDir
    ]

    remove: aName in: aWorkDir source: anIndexDir [
        ^self over: anIndexDir run: (Array with: 'remove' with: aName)
            in: aWorkDir
    ]

    "---- S1: the middle clause, byte-identical to a hand-written oracle ----"

    testS1_removingAMiddleDependencyPreservesEveryOtherByte [
        | work index result |
        work := self track: (RemoveFixtures
            authoredWorkDirNamed: 's20-1-work').
        index := self removeIndex: 's20-1-index'.
        result := self remove: RemoveFixtures removedName
            in: work source: index.
        self assert: result exitCode = 0
            description: 'remove answered exit ', result exitCode printString,
                ': ', result lines printString.
        self assert: (RemoveFixtures packageIn: work)
            = RemoveFixtures authoredThreeWithoutMiddle
            description: 'the file is not byte-identical to the hand-written oracle'.
        self assert: (ManifestFile load: work, '/Package.st') dependencies size
            = 2
            description: 'the edited manifest did not re-load with two dependencies'.
        self assert: (ManifestEditFixtures
            contains: (RemoveFixtures packageIn: work)
            line: RemoveFixtures authoredHeaderCommentLine)
            description: 'the header comment did not survive'.
        self assert: (ManifestEditFixtures
            contains: (RemoveFixtures packageIn: work)
            line: RemoveFixtures authoredInteriorCommentLine)
            description: 'the interior comment did not survive'
    ]

    "---- S2: the last clause takes its separator with it ----"

    testS2_removingTheLastClauseTakesTheSeparatorWithIt [
        "The scenario a splice that deletes only the clause's own text
         passes S1 and then fails: what it leaves behind is `;`
         immediately before the cascade's closing bracket, and the file
         no longer loads."
        | work index result |
        work := self track: (RemoveFixtures
            authoredWorkDirNamed: 's20-2-work').
        index := self removeIndex: 's20-2-index'.
        result := self remove: RemoveFixtures lastName
            in: work source: index.
        self assert: result exitCode = 0
            description: 'remove answered exit ', result exitCode printString,
                ': ', result lines printString.
        self assert: (RemoveFixtures packageIn: work)
            = RemoveFixtures authoredThreeWithoutLast
            description: 'the last-clause removal is not byte-identical to the oracle'.
        self assert: (ManifestFile load: work, '/Package.st') dependencies size
            = 2
            description: 'the manifest did not re-load after the last clause went'
    ]

    "---- S3: the only dependency ----"

    testS3_removingTheOnlyDependencyLeavesAValidManifest [
        | work index result |
        work := self track: (RemoveFixtures soloWorkDirNamed: 's20-3-work').
        index := self removeIndex: 's20-3-index'.
        result := self remove: RemoveFixtures firstName
            in: work source: index.
        self assert: result exitCode = 0
            description: 'remove answered exit ', result exitCode printString,
                ': ', result lines printString.
        self assert: (RemoveFixtures packageIn: work)
            = RemoveFixtures soloWithoutDependency
            description: 'the solo removal is not byte-identical to the oracle'.
        self assert: (ManifestFile load: work, '/Package.st') dependencies
            isEmpty
            description: 'the manifest still declares a dependency'.
        self assert: (RemoveFixtures lockTuplesIn: work) isEmpty
            description: 'the rewritten lock still pins something'
    ]

    "---- S4: an unfamiliar shape is refused, the file byte-identical ----"

    testS4_anUnrecognizedShapeIsRefusedWithTheFileByteIdentical [
        | work index original result |
        work := self track: (RemoveFixtures
            unrecognizedWorkDirNamed: 's20-4-work').
        index := self removeIndex: 's20-4-index'.
        original := RemoveFixtures packageIn: work.
        result := self remove: RemoveFixtures firstName
            in: work source: index.
        self assert: result exitCode = 1
            description: 'an unrecognized shape answered exit ',
                result exitCode printString.
        self assert: result lines = (Array with: (RemoveFixtures
            unrecognizedLineFor: RemoveFixtures firstName
            in: work, '/Package.st'))
            description: 'the refusal answered ', result lines printString.
        self assert: (RemoveFixtures packageIn: work) = original
            description: 'a refused remove rewrote the operator''s file'
    ]

    "---- S5: an undeclared package, and nothing written ----"

    testS5_anUndeclaredPackageIsDiagnosedAndNothingIsWritten [
        | work index original lock result |
        work := self track: (RemoveFixtures soloWorkDirNamed: 's20-5-work').
        index := self removeIndex: 's20-5-index'.
        original := RemoveFixtures packageIn: work.
        lock := RemoveFixtures lockIn: work.
        result := self remove: RemoveFixtures undeclaredName
            in: work source: index.
        self assert: result exitCode = 1
            description: 'an undeclared package answered exit ',
                result exitCode printString.
        self assert: result lines = (Array with: (RemoveFixtures
            notDeclaredLineFor: RemoveFixtures undeclaredName))
            description: 'the diagnosis answered ', result lines printString.
        self assert: (RemoveFixtures packageIn: work) = original
            description: 'Package.st was written'.
        self assert: (RemoveFixtures lockIn: work) = lock
            description: 'parley.lock was written'
    ]

    "---- S6: atomicity, asserted on the artifacts ----"

    testS6_aFailedResolutionLeavesBothArtifactsByteIdentical [
        "The manifest is rewritten BEFORE the resolution runs, so this
         is the path a non-atomic remove leaves behind a manifest naming
         a dependency the lock does not pin - the exact state
         PinVerification exists to call broken, manufactured by the
         tool. Asserted on the two files; the exit code is not the
         claim."
        | work index original lock result |
        work := self track: (RemoveFixtures ghostWorkDirNamed: 's20-6-work').
        index := self removeIndex: 's20-6-index'.
        original := RemoveFixtures packageIn: work.
        lock := RemoveFixtures lockIn: work.
        result := self remove: RemoveFixtures removedName
            in: work source: index.
        self deny: result exitCode = 0
            description: 'a failed re-resolution answered exit 0'.
        self deny: (result lines
            detect: [:line | CommandLineFixtures does: line include: 'ghost']
            ifNone: [nil]) isNil
            description: 'the verb never reached the resolution it was meant to fail: ',
                result lines printString.
        self assert: (RemoveFixtures packageIn: work) = original
            description: 'Package.st was left edited'.
        self assert: (RemoveFixtures lockIn: work) = lock
            description: 'parley.lock moved'
    ]

    "---- S7: the remaining pins, tuple by tuple ----"

    testS7_everyUnrelatedPinIsByteIdenticalTupleByTuple [
        | work index before after |
        work := self track: (RemoveFixtures
            fourPinsWorkDirNamed: 's20-7-work').
        index := self removeIndex: 's20-7-index'.
        before := RemoveFixtures lockTuplesIn: work.
        self assert: before size = 4
            description: 'the fixture does not start from four pins'.
        self assert: (self remove: RemoveFixtures removedName
            in: work source: index) exitCode = 0.
        after := RemoveFixtures lockTuplesIn: work.
        self assert: (RemoveFixtures
            tupleNamed: RemoveFixtures removedName in: after) isNil
            description: 'the removed package is still pinned'.
        #('tool-a' 'tool-b' 'tool-d') do: [:name |
            self assert: (RemoveFixtures tupleNamed: name in: after)
                = (RemoveFixtures tupleNamed: name in: before)
                description: name, ' moved to ',
                    (RemoveFixtures tupleNamed: name in: after) printString]
    ]

    "---- S8: four usage errors, four first lines ----"

    testS8_eachUsageGroundAnswersItsOwnFirstLine [
        "Four genuinely different mistakes, four different first lines,
         one shared block. The fourth ground - a verb the tool HAS,
         given arguments it does not take - is the one §8 decision 79
         first omitted and 81 restored.

         THE #needsIndex ROW IS DRIVEN THROUGH install FROM SPRINT 21
         (§8 decisions 83, 84). THE GROUND SURVIVES UNTOUCHED and so
         does its wording law: nothing about the sentence, the table or
         the shared block moved. What moved is which verbs derive the
         ground - resolve, check, tree and why left the grammar, and
         install, update, add, remove, search, info and outdated kept
         it - so this row needs a verb that still derives it. install is
         the mirror's remaining member, and Sprint 21's own S33 guards
         exactly this argv, so the two cannot drift apart unnoticed."
        | rows seen |
        rows := (Array
            with: (Array with: 's20-8-noverb' with: #() with: #noVerb with: '')
            with: (Array with: 's20-8-unknown' with: #('conjure')
                with: #unknownVerb with: 'conjure')),
            (Array
                with: (Array with: 's20-8-arity' with: #('exec')
                    with: #wrongArguments with: 'exec')
                with: (Array with: 's20-8-index' with: #('install')
                    with: #needsIndex with: 'install')).
        seen := OrderedCollection new.
        rows do: [:row |
            | result |
            result := self resultOf: (row at: 2)
                in: (self freshDir: (row at: 1)) runner: TrapRunner new.
            self assert: result exitCode = 2
                description: (row at: 2) printString, ' answered exit ',
                    result exitCode printString.
            self assert: result lines = (GrammarFixtures
                usageAnswerFor: (row at: 3) subject: (row at: 4))
                description: (row at: 2) printString, ' answered ',
                    result lines printString.
            self deny: (seen includes: result lines first)
                description: (row at: 2) printString,
                    ' repeated an earlier first line'.
            seen add: result lines first]
    ]

    "---- S9: the decoupling ----"

    testS9_theQuestionAnswersTheBlockAloneAtExitZero [
        | first |
        first := nil.
        ReadinessFixtures helpSpellings doWithIndex: [:spelling :i |
            | result |
            result := self resultOf: (Array with: spelling)
                in: (self freshDir: 's20-9-', i printString)
                runner: TrapRunner new.
            self assert: result exitCode = 0
                description: spelling, ' answered exit ',
                    result exitCode printString.
            self assert: result lines = GrammarFixtures usageBlockLines
                description: spelling, ' answered ', result lines printString.
            GrammarFixtures declaredGroundSymbols do: [:ground |
                self deny: (result lines includes:
                    (GrammarFixtures reasonFor: ground subject: 'resolve'))
                    description: spelling, ' carried a reason line'].
            first isNil
                ifTrue: [first := result lines]
                ifFalse: [self assert: result lines = first
                    description: spelling, ' answered different lines']]
    ]

    "---- S10: the strengthened settled law ----"

    testS10_theUsageAnswersTailIsExactlyTheHelpBlock [
        "This replaces `help lines = usage lines` and is strictly
         stronger: it pins the shared text AND the added line in one
         assertion, where the old form pinned only equality. It locates
         the block by its start, never by an absolute index."
        | help usage tail |
        help := self resultOf: (Array with: ReadinessFixtures helpFlag)
            in: (self freshDir: 's20-10-help') runner: TrapRunner new.
        usage := self resultOf: #()
            in: (self freshDir: 's20-10-usage') runner: TrapRunner new.
        self assert: help exitCode = 0.
        self assert: usage exitCode = 2.
        self assert: usage lines size = (help lines size + 1)
            description: 'the usage answer is ', usage lines size printString,
                ' lines beside a block of ', help lines size printString.
        tail := usage lines copyFrom: 2 to: usage lines size.
        self assert: tail = help lines
            description: 'the usage answer''s tail is not the help block: ',
                tail printString.
        self assert: usage lines first = GrammarFixtures noVerbReason
            description: 'the usage answer opens with ',
                usage lines first printString
    ]

    "---- S11: search over a scanning source ----"

    testS11_searchAnswersOneSortedLinePerHit [
        | work index result |
        work := self freshDir: 's20-11-work'.
        index := self grammarIndex: 's20-11-index'.
        result := self over: index run: #('search' 'kernel') in: work.
        self assert: result exitCode = 0
            description: 'search answered exit ', result exitCode printString,
                ': ', result lines printString.
        self assert: result lines = GrammarFixtures kernelSearchLines
            description: 'search answered ', result lines printString
    ]

    "---- S12: no match is an answer ----"

    testS12_searchWithNoMatchExitsZeroNamingTheTerm [
        | work index result |
        work := self freshDir: 's20-12-work'.
        index := self grammarIndex: 's20-12-index'.
        result := self over: index
            run: (Array with: 'search'
                with: GrammarFixtures absentSearchTerm) in: work.
        self assert: result exitCode = 0
            description: 'an empty search answered exit ',
                result exitCode printString.
        self assert: result lines = (Array with: (GrammarFixtures
            noMatchLineFor: GrammarFixtures absentSearchTerm))
            description: 'an empty search answered ', result lines printString
    ]

    "---- S13: the transport that cannot answer refuses ----"

    testS13_searchRefusesOverTheSparseTransportAndSpawnsNothing [
        | work base runner result |
        work := self track: (GrammarFixtures
            sparseWorkDirNamed: 's20-13-index-work').
        base := self sparseBase: 's20-13-index-base'.
        runner := RecordingRunner new.
        result := self resultOf: (Array with: 'search' with: 'root'
            with: '--index' with: (SparseIndexFixtures baseUrlFor: base))
            in: work runner: runner.
        self assert: result exitCode = 1
            description: 'the refusal answered exit ',
                result exitCode printString, ': ', result lines printString.
        self assert: result lines
            = (Array with: GrammarFixtures searchRefusalLine)
            description: 'the refusal answered ', result lines printString.
        self assert: runner commands = #()
            description: 'the refusal spawned ', runner commands printString
    ]

    "---- S14: none of the three enters the resolver ----"

    testS14_noReadingVerbEntersTheResolver [
        "The trap sits on the verb's REAL path: ResolverTrapCLI is
         everything a CLI is except that resolveAndLock: signals.

         IT OPENS WITH A GUARD, and the guard is disclosed rather than
         hidden: resolve through the same double must still trip the
         trap, because a double that cannot spring proves nothing. The
         guard passes today; the three renderings after it are what this
         scenario is about."
        | work index trap tripped |
        work := self track: (GrammarFixtures
            outdatedWorkDirNamed: 's20-14-work').
        index := self grammarIndex: 's20-14-index'.
        trap := ResolverTrapCLI
            in: work
            source: (DirectorySource on: index)
            store: (ContentStore on: (CommandLineFixtures storeRootIn: work))
            target: (CommandLineFixtures targetDirIn: work)
            runner: RecordingRunner new.
        tripped := false.
        [trap run: #('resolve')]
            on: Error
            do: [:e |
                tripped := e messageText = ResolverTrapCLI trapMessage].
        self assert: tripped
            description: 'the trap does not sit on the real path - resolve did not trip it'.
        (Array
            with: #('search' 'kernel')
            with: #('info' 'kernel-text')
            with: #('outdated')) do: [:argv |
                | result |
                result := trap run: argv.
                self assert: result exitCode = 0
                    description: argv printString,
                        ' entered the resolver or failed: exit ',
                        result exitCode printString, ', ',
                        result lines printString]
    ]

    "---- S15: two columns, one run, not conflated ----"

    testS15_outdatedReportsBothColumnsWithoutConflatingThem [
        | work index result |
        work := self track: (GrammarFixtures
            outdatedWorkDirNamed: 's20-15-work').
        index := self grammarIndex: 's20-15-index'.
        result := self over: index run: #('outdated') in: work.
        self assert: result exitCode = 0
            description: 'outdated answered exit ', result exitCode printString,
                ': ', result lines printString.
        self assert: result lines = GrammarFixtures outdatedLines
            description: 'outdated answered ', result lines printString.
        self assert: result lines size = 2
            description: 'both pins must be reported in one run'
    ]

    "---- S16: a retired newer release is offered in neither column ----"

    testS16_aCurrentProjectSaysSoAndIgnoresARetiredNewerRelease [
        | work index result |
        work := self track: (GrammarFixtures
            currentWorkDirNamed: 's20-16-work').
        index := self grammarIndex: 's20-16-index'.
        result := self over: index run: #('outdated') in: work.
        self assert: result exitCode = 0
            description: 'a current project answered exit ',
                result exitCode printString.
        self assert: result lines
            = (Array with: GrammarFixtures nothingOutdatedLine)
            description: 'outdated answered ', result lines printString.
        self deny: (CommandLineFixtures does: result lines first
            include: '2.0.0')
            description: 'the retired release was offered as an upgrade'
    ]

    "---- S17: every declared field renders ----"

    testS17_infoRendersEveryDeclaredField [
        | work index result |
        work := self freshDir: 's20-17-work'.
        index := self grammarIndex: 's20-17-index'.
        result := self over: index run: #('info' 'kernel-json') in: work.
        self assert: result exitCode = 0
            description: 'info answered exit ', result exitCode printString,
                ': ', result lines printString.
        self assert: result lines = GrammarFixtures jsonInfoLines
            description: 'info answered ', result lines printString
    ]

    "---- S18: a retired release is listed and marked ----"

    testS18_infoMarksARetiredReleaseWithTheAuthorsReason [
        | work index lines |
        work := self freshDir: 's20-18-work'.
        index := self grammarIndex: 's20-18-index'.
        lines := (self over: index run: #('info' 'kernel-json') in: work)
            lines.
        self assert: (lines includes: (GrammarFixtures
            infoRetiredVersionLineFor: '0.3.2'
            reason: GrammarFixtures json032Reason))
            description: 'the retired release is not marked: ', lines printString
    ]

    "---- S19: an unknown package, on both transports ----"

    testS19_infoOnAnUnknownPackageIsExitOneOnEveryTransport [
        "Driven over --source AND --index, because the negative must
         mean ABSENT rather than NEVER NAMED BY THE CLOSURE on every
         transport. Each flag gets its own labelled directories: Sprint
         19 lost a scenario to one label colliding across two
         iterations."
        | index scanned base sparse |
        index := self grammarIndex: 's20-19-source-index'.
        scanned := self over: index
            run: (Array with: 'info'
                with: GrammarFixtures absentPackageName)
            in: (self freshDir: 's20-19-source-work').
        self assert: scanned exitCode = 1
            description: 'info over --source answered exit ',
                scanned exitCode printString.
        self assert: scanned lines = (Array with: (GrammarFixtures
            notPublishedLineFor: GrammarFixtures absentPackageName))
            description: 'info over --source answered ', scanned lines printString.
        base := self sparseBase: 's20-19-index-base'.
        sparse := self resultOf: (Array with: 'info'
            with: GrammarFixtures absentPackageName
            with: '--index' with: (SparseIndexFixtures baseUrlFor: base))
            in: (self track: (GrammarFixtures
                sparseWorkDirNamed: 's20-19-index-work'))
            runner: ProcessRunner new.
        self assert: sparse exitCode = 1
            description: 'info over --index answered exit ',
                sparse exitCode printString, ': ', sparse lines printString.
        self assert: sparse lines = (Array with: (GrammarFixtures
            notPublishedLineFor: GrammarFixtures absentPackageName))
            description: 'info over --index answered ', sparse lines printString
    ]

    "---- S20: a cold cache prints nothing of git's ----"

    testS20_aColdGitCacheWritesNothingOnEitherStream [
        "Captured SEPARATELY, through the shipped binary. No law in this
         suite had ever captured streams on a --git verb, which is
         precisely why F19 shipped."
        | work repo run |
        work := self track:
            (CommandLineFixtures diamondRootWorkDirNamed: 's20-20-work').
        repo := self absentPath: 's20-20-repo'.
        PublishFixtures buildDiamondRepoAt: repo.
        run := AuthoringFixtures runShippedIn: work
            args: 'resolve --git ', (self absolute: repo)
            captures: (self captures: 's20-20-captures')
            label: 's20-20'.
        self assert: (run at: 1) = 0
            description: 'a cold --git resolve exited ', (run at: 1) printString,
                ' with stdout ', (run at: 2) printString,
                ' and stderr ', (run at: 3) printString.
        self assert: (ExecFixtures linesOf: (run at: 2))
            = CommandLineFixtures diamondPinLines
            description: 'stdout carried ', (run at: 2) printString.
        self assert: (run at: 3) isEmpty
            description: 'stderr carried ', (run at: 3) printString.
        GrammarFixtures gitChatterMarkers do: [:row |
            self deny: (CommandLineFixtures does: (run at: 2)
                include: (row at: 2))
                description: 'stdout carried ', (row at: 1).
            self deny: (CommandLineFixtures does: (run at: 3)
                include: (row at: 2))
                description: 'stderr carried ', (row at: 1)]
    ]

    "---- S21: a warm cache whose index has MOVED ----"

    testS21_aWarmGitCacheOverAMovedIndexWritesNothingOfGits [
        "The case the recorded gap missed, and the one that puts foreign
         text on STDOUT: a warm cache whose upstream has moved answers a
         diffstat of the index repository's own files, above Parley's
         answer, on the stream the record calls clean."
        | work repo first run |
        work := self track:
            (CommandLineFixtures diamondRootWorkDirNamed: 's20-21-work').
        repo := self absentPath: 's20-21-repo'.
        PublishFixtures buildDiamondRepoAt: repo.
        first := AuthoringFixtures runShippedIn: work
            args: 'resolve --git ', (self absolute: repo)
            captures: (self captures: 's20-21-captures')
            label: 's20-21-cold'.
        self assert: (first at: 1) = 0
            description: 'the priming run exited ', (first at: 1) printString.
        PublishFixtures growDiamondRepoAt: repo.
        run := AuthoringFixtures runShippedIn: work
            args: 'resolve --git ', (self absolute: repo)
            captures: (self captures: 's20-21-captures2')
            label: 's20-21-warm'.
        self assert: (run at: 1) = 0
            description: 'the warm run exited ', (run at: 1) printString,
                ' with stdout ', (run at: 2) printString,
                ' and stderr ', (run at: 3) printString.
        self assert: (ExecFixtures linesOf: (run at: 2))
            = CommandLineFixtures diamondPinLines
            description: 'stdout carried ', (run at: 2) printString.
        self assert: (run at: 3) isEmpty
            description: 'stderr carried ', (run at: 3) printString.
        GrammarFixtures gitChatterMarkers do: [:row |
            self deny: (CommandLineFixtures does: (run at: 2)
                include: (row at: 2))
                description: 'stdout carried ', (row at: 1).
            self deny: (CommandLineFixtures does: (run at: 3)
                include: (row at: 2))
                description: 'stderr carried ', (row at: 1)]
    ]

    "---- S22: silencing chatter must not silence failure ----"

    testS22_aMissingRepositoryStillReachesTheOperator [
        "Quiet stops text being written; it must not stop a failure
         being reported. The settled SourceError still names the command
         actually run - which now carries the flag - and its exit code."
        | work repo result problems |
        work := self track:
            (CommandLineFixtures diamondRootWorkDirNamed: 's20-22-work').
        repo := SourceFixtures missingPathNamed: 's20-22-repo'.
        result := self resultOf: (Array with: 'resolve'
            with: '--git' with: repo) in: work runner: ProcessRunner new.
        self assert: result exitCode = 1
            description: 'a missing repository answered exit ',
                result exitCode printString, ': ', result lines printString.
        problems := result lines.
        self assert: problems size = 1
            description: 'the transport failure answered ', problems printString.
        self assert: (CommandLineFixtures does: problems first
            include: GrammarFixtures gitFailureMarker)
            description: 'the diagnosis lost its settled wording: ',
                problems first.
        self assert: (CommandLineFixtures does: problems first
            include: GrammarFixtures quietFlag)
            description: 'the diagnosis does not name the command actually run: ',
                problems first.
        self assert: (CommandLineFixtures does: problems first include: '128')
            description: 'the diagnosis lost the exit code: ', problems first
    ]

    "---- S23: the closure-only build's killer ----"

    testS23_infoReachesAPackageOutsideTheSeededClosure [
        "A build that seeds only from manifest-plus-lock passes S17-S19
         and fails here, having answered `not published` about a package
         the index really publishes - §8 decision 80's own harm class,
         one door down, in the verb the same issue uses to justify
         refusing search."
        | work base result |
        work := self track: (GrammarFixtures
            sparseWorkDirNamed: 's20-23-index-work').
        base := self sparseBase: 's20-23-index-base'.
        result := self resultOf: (Array with: 'info'
            with: GrammarFixtures outsideClosureName
            with: '--index' with: (SparseIndexFixtures baseUrlFor: base))
            in: work runner: ProcessRunner new.
        self assert: result exitCode = 0
            description: 'info on a package outside the closure answered exit ',
                result exitCode printString, ': ', result lines printString.
        self assert: result lines = GrammarFixtures unrelatedInfoLines
            description: 'info answered ', result lines printString
    ]
]

Namespace current: Smalltalk.
