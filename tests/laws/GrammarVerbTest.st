"Parley Sprint 20 - laws for the three verbs that only READ
 (issue #22; Doc E §4.1, Doc C §2, Doc F §7.3, §8 decisions 37, 40, 57,
 and 80).

 search, info and outdated answer questions and change nothing. None
 writes a file, spawns a process or mutates the store, and NONE OF THEM
 ENTERS THE RESOLVER - decision 40's rule extended, proved the way
 Sprint 11 proved it for why, tree and check: a trap on the verb's real
 path, plus a guard that the trap can still spring.

 THE SNAPSHOT GAINS TWO ACCESSORS AND NOTHING ELSE. It answered no
 enumeration of the names it holds, and versionsOf: excludes retired
 releases BY DESIGN so the resolver never learns retirement exists. A
 reporting verb needs both of the things that leaves out, so the sealed
 value answers its package names, sorted, and every version of a name
 INCLUDING retired ones - deliberately distinct from versionsOf:'s
 filtered view, because what an index PUBLISHED is a different question
 from what a resolution may SELECT.

 THE HELD MAP IS THE TRAP UNDER BOTH NEW VERBS, and it is why the
 all-versions accessor is not merely a convenience. versionsOf:
 collapses a HELD name to exactly its held version, bypassing the
 retirement filter - so info's `latest` built on it would answer THIS
 PROJECT'S PIN rather than the index's newest release, and outdated's
 absolute-newest column would report a held package as never outdated,
 forever and silently. Both are asserted against a narrowed snapshot
 here, where the collapse is visible, rather than against a plain one,
 where the two accessors happen to agree.

 SEARCH REFUSES OVER --index, AND THE REFUSAL PRECEDES THE TRANSPORT
 (§8 decision 80). A sparse index publishes one listing per package and
 no catalogue, so a search over the snapshot the source answers would
 return the operator's OWN closure - the packages they already depend
 on - and read exactly like a complete result. The refusal is proved to
 spawn nothing, because a refusal that first fetched would have
 answered the question it says it cannot answer.

 THE TWO EXIT CODES DIFFER DELIBERATELY. No match is an answer at exit
 0 - a question answered is not an error (§8 decision 57), and apt,
 cargo, npm and gem all agree - while an unknown package is exit 1,
 because the operator ASSERTED a package exists and it does not. They
 are asserted side by side in one law so a build that unified them
 fails on the comparison rather than on one of two distant literals.

 DECLARED PASSES IN RED (issue #22): NONE in this file. Every law
 either sends IndexSnapshot an accessor that does not exist yet, which
 aborts as an ERROR at that send, or drives a two-element search / info
 argv or the one-element outdated argv, which the pre-sprint tree
 answers with the usage lines at exit 2 where these laws demand 0 or 1.
 The resolver-purity law opens with the accessor rather than with the
 trap, so it fails in red on the accessor and cannot pass vacuously.

 Every fixture path is under tmp/, unique per label AND per flag -
 Sprint 19 lost a scenario to one directory name colliding across two
 iterations - and removed recursively in tearDown."

Namespace current: Parley.

TestCase subclass: GrammarVerbTest [
    | fixtureDirs |

    <comment: 'Laws for parley search, parley info and parley outdated:
the two additive snapshot accessors and the held-map trap under them,
the sorted hit lines, the answered-not-error empty result, the sparse
refusal that spawns nothing, every info field including a marked
retirement, and outdated''s two columns held apart.'>

    setUp [
        fixtureDirs := OrderedCollection new
    ]

    tearDown [
        fixtureDirs isNil ifTrue: [^self].
        fixtureDirs do: [:each | PathFixtures removeTree: each].
        fixtureDirs := nil
    ]

    track: aPath [
        fixtureDirs add: aPath.
        ^aPath
    ]

    freshDir: aLabel [
        ^self track: (SourceFixtures directoryNamed: aLabel)
    ]

    grammarIndex: aLabel [
        | path |
        path := self freshDir: aLabel.
        GrammarFixtures populateGrammarIndexIn: path.
        ^path
    ]

    grammarSnapshot: aLabel [
        ^(DirectorySource on: (self grammarIndex: aLabel)) snapshot
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

    versionStringsOf: aVersionCollection [
        ^(aVersionCollection collect: [:v | v printString]) asArray
    ]

    "---- the two additive accessors (Doc C §2) ----"

    testTheSnapshotAnswersItsPackageNamesSorted [
        "The enumeration search needs and nothing previously offered.
         Sorted, because the answer is rendered and a rendering that
         varies with dictionary order is not byte-stable."
        | snapshot |
        snapshot := self grammarSnapshot: 'gvt-names-index'.
        self assert: snapshot packageNames asArray
            = #('kernel-json' 'kernel-lint' 'kernel-solo' 'kernel-text')
            description: 'the snapshot enumerated ',
                snapshot packageNames printString
    ]

    testTheAllVersionsAccessorKeepsWhatVersionsOfFiltersOut [
        "Deliberately distinct from versionsOf:. What an index PUBLISHED
         is a different question from what a fresh resolution may
         SELECT, and collapsing the two would either leak retirement
         into the search loop or hide it from the operator."
        | snapshot |
        snapshot := self grammarSnapshot: 'gvt-allversions-index'.
        self assert: (self versionStringsOf:
            (snapshot allVersionsOf: 'kernel-json'))
                = #('0.3.1' '0.3.2')
            description: 'allVersionsOf: answered ',
                (snapshot allVersionsOf: 'kernel-json') printString.
        self assert: (self versionStringsOf: (snapshot versionsOf: 'kernel-json'))
            = #('0.3.1')
            description: 'the settled filtered accessor moved'.
        self assert: (snapshot allVersionsOf: 'kernel-nowhere') isEmpty
            description: 'an unknown name answered versions'
    ]

    testTheAllVersionsAccessorBypassesTheHeldMap [
        "THE TRAP UNDER info AND outdated. versionsOf: collapses a held
         name to exactly its held version, so a `latest` or a
         `newest published` built on it answers THIS PROJECT'S PIN and
         calls it the index's newest. The reporting accessor answers the
         index, whatever this project holds."
        | snapshot held |
        snapshot := self grammarSnapshot: 'gvt-held-index'.
        held := Dictionary new.
        held at: 'kernel-text' put: (Version fromString: '1.0.0').
        self assert: (self versionStringsOf:
            ((snapshot holding: held) versionsOf: 'kernel-text'))
                = #('1.0.0')
            description: 'the settled narrowing stopped collapsing - the trap is gone'.
        self assert: (self versionStringsOf:
            ((snapshot holding: held) allVersionsOf: 'kernel-text'))
                = #('1.0.0' '1.2.0' '2.0.0')
            description: 'the reporting accessor was collapsed by the held map: ',
                ((snapshot holding: held) allVersionsOf: 'kernel-text')
                    printString
    ]

    testTheAccessorsAreAdditiveAndTheResolverCallsNeither [
        "Additive means the resolver is untouched, and that is proved
         mechanically rather than by reading the search loop: a snapshot
         whose two reporting accessors SIGNAL still resolves.

         The accessor is asserted FIRST so this law cannot pass
         vacuously before the accessors exist - a trap that cannot
         spring proves nothing, and neither does a trap nothing reached."
        | trapped outcome |
        self assert: (self grammarSnapshot: 'gvt-additive-index')
            packageNames isEmpty not
            description: 'the reporting accessor answers nothing on a real snapshot'.
        trapped := ReportingAccessorTrapSnapshot releases: (Array
            with: (ResolverFixtures release: 'kernel-a' version: '1.0.0'
                sha256: '' dependencies: #())).
        self assert: (trapped versionsOf: 'kernel-a') size = 1
            description: 'the trap double does not hold the settled release'.
        [trapped packageNames.
         self assert: false
            description: 'the trap does not spring on packageNames']
            on: Error do: [:e | nil].
        outcome := ResolverFixtures
            resolve: (ResolverFixtures rootWith: #(#('kernel-a' '^1.0')))
            against: trapped.
        self assert: outcome isResolution
            description: 'resolution through the trap answered ',
                outcome printString
    ]

    "---- search ----"

    testSearchAnswersOneSortedLinePerHit [
        | work index result |
        work := self freshDir: 'gvt-search-work'.
        index := self grammarIndex: 'gvt-search-index'.
        result := self over: index run: #('search' 'kernel') in: work.
        self assert: result exitCode = 0
            description: 'search answered exit ', result exitCode printString,
                ': ', result lines printString.
        self assert: result lines = GrammarFixtures kernelSearchLines
            description: 'search answered ', result lines printString
    ]

    testSearchMatchesASubstringRatherThanAPrefix [
        "A substring match over the names the index publishes: an
         operator who remembers half a name gets the package."
        | work index result |
        work := self freshDir: 'gvt-substring-work'.
        index := self grammarIndex: 'gvt-substring-index'.
        result := self over: index run: #('search' 'json') in: work.
        self assert: result exitCode = 0.
        self assert: result lines = (Array with: (GrammarFixtures
            searchLineFor: 'kernel-json' version: '0.3.1'
            summary: GrammarFixtures jsonSummary))
            description: 'a substring search answered ', result lines printString
    ]

    testSearchLatestColumnSkipsARetiredRelease [
        "The latest column names the newest release an operator may
         actually take, so a retired newest is not offered as the
         answer to `what is the current version`."
        | work index line |
        work := self freshDir: 'gvt-searchretired-work'.
        index := self grammarIndex: 'gvt-searchretired-index'.
        line := (self over: index run: #('search' 'json') in: work) lines first.
        self assert: line = (GrammarFixtures searchLineFor: 'kernel-json'
            version: '0.3.1' summary: GrammarFixtures jsonSummary)
            description: 'search answered ', line printString.
        self deny: (CommandLineFixtures does: line include: '0.3.2')
            description: 'search offered the retired release: ', line
    ]

    testSearchWithNoMatchIsAnAnswerAtExitZero [
        "A question answered is not an error (§8 decision 57)."
        | work index result |
        work := self freshDir: 'gvt-nomatch-work'.
        index := self grammarIndex: 'gvt-nomatch-index'.
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

    testSearchRefusesOverTheSparseTransportAndSpawnsNothing [
        "The refusal PRECEDES the transport: a refusal that first
         fetched would have started answering the question it says it
         cannot answer. Proved by the recording runner, which spawns
         nothing and records everything it was asked to spawn."
        | work base runner result |
        work := self track: (GrammarFixtures
            sparseWorkDirNamed: 'gvt-refuse-index-work').
        base := self freshDir: 'gvt-refuse-index-base'.
        GrammarFixtures populateSparseBaseIn: base.
        runner := RecordingRunner new.
        result := self resultOf: (Array with: 'search' with: 'root'
            with: '--index' with: (SparseIndexFixtures baseUrlFor: base))
            in: work runner: runner.
        self assert: result exitCode = 1
            description: 'the sparse refusal answered exit ',
                result exitCode printString, ': ', result lines printString.
        self assert: result lines
            = (Array with: GrammarFixtures searchRefusalLine)
            description: 'the refusal answered ', result lines printString.
        self assert: runner commands = #()
            description: 'the refusal spawned ', runner commands printString
    ]

    testTheSparseRefusalNamesTheFlagsThatCanAnswer [
        "Naming the transport without naming the way out is a refusal
         that wastes the operator's time. Asserted on the SHIPPED line
         rather than on the fixture, which would only be checking its
         own wording: the flags come from the declared sourceFlags
         table, so a fourth source cannot drift out of the sentence."
        | work base line |
        work := self track: (GrammarFixtures
            sparseWorkDirNamed: 'gvt-refusalflags-work').
        base := self freshDir: 'gvt-refusalflags-base'.
        GrammarFixtures populateSparseBaseIn: base.
        line := (self resultOf: (Array with: 'search' with: 'root'
            with: '--index' with: (SparseIndexFixtures baseUrlFor: base))
            in: work runner: RecordingRunner new) lines first.
        self assert: line = GrammarFixtures searchRefusalLine
            description: 'the refusal line is ', line printString.
        CommandLine sourceFlags do: [:row |
            self assert: (CommandLineFixtures does: line include: (row at: 1))
                description: 'the refusal does not name ', (row at: 1)]
    ]

    "---- info ----"

    testInfoRendersEveryDeclaredField [
        "Every field, asserted as the WHOLE answer rather than field by
         field: a law that checked each line was present would pass on
         an answer carrying a tenth line nobody expected."
        | work index result |
        work := self freshDir: 'gvt-info-work'.
        index := self grammarIndex: 'gvt-info-index'.
        result := self over: index run: #('info' 'kernel-json') in: work.
        self assert: result exitCode = 0
            description: 'info answered exit ', result exitCode printString,
                ': ', result lines printString.
        self assert: result lines = GrammarFixtures jsonInfoLines
            description: 'info answered ', result lines printString
    ]

    testInfoMarksARetiredReleaseWithItsAuthorsReason [
        "The author's reason travels VERBATIM through the settled
         retirementReasonFor:version:, which gains its SECOND reader
         here - check was the first."
        | work index lines |
        work := self freshDir: 'gvt-inforetired-work'.
        index := self grammarIndex: 'gvt-inforetired-index'.
        lines := (self over: index run: #('info' 'kernel-json') in: work)
            lines.
        self assert: (lines includes: (GrammarFixtures
            infoRetiredVersionLineFor: '0.3.2'
            reason: GrammarFixtures json032Reason))
            description: 'the retired release is not marked: ',
                lines printString.
        self assert: (lines includes:
            (GrammarFixtures infoVersionLineFor: '0.3.1'))
            description: 'the live release lost its plain line'
    ]

    testInfoLatestIsTheNewestReleaseThatIsNotRetired [
        | work index lines |
        work := self freshDir: 'gvt-infolatest-work'.
        index := self grammarIndex: 'gvt-infolatest-index'.
        lines := (self over: index run: #('info' 'kernel-text') in: work)
            lines.
        self assert: (lines includes:
            (GrammarFixtures infoLatestLineFor: '2.0.0'))
            description: 'info named a different latest: ', lines printString
    ]

    testInfoOnAPackageTheIndexDoesNotPublishIsExitOne [
        | work index result |
        work := self freshDir: 'gvt-infounknown-work'.
        index := self grammarIndex: 'gvt-infounknown-index'.
        result := self over: index
            run: (Array with: 'info'
                with: GrammarFixtures absentPackageName) in: work.
        self assert: result exitCode = 1
            description: 'an unknown package answered exit ',
                result exitCode printString.
        self assert: result lines = (Array with: (GrammarFixtures
            notPublishedLineFor: GrammarFixtures absentPackageName))
            description: 'the diagnosis answered ', result lines printString
    ]

    testTheTwoNegativeAnswersKeepDifferentExitCodes [
        "Asserted side by side, because the claim is about the
         DIFFERENCE: a build that unified them fails on the comparison
         rather than on one of two distant literals. No match is a
         question answered; an unknown package is an assertion that
         turned out false."
        | work index empty unknown |
        work := self freshDir: 'gvt-codes-work'.
        index := self grammarIndex: 'gvt-codes-index'.
        empty := self over: index
            run: (Array with: 'search'
                with: GrammarFixtures absentSearchTerm) in: work.
        unknown := self over: index
            run: (Array with: 'info'
                with: GrammarFixtures absentPackageName) in: work.
        self assert: empty exitCode = 0
            description: 'search with no match answered exit ',
                empty exitCode printString.
        self assert: unknown exitCode = 1
            description: 'info on an unknown package answered exit ',
                unknown exitCode printString.
        self deny: empty exitCode = unknown exitCode
            description: 'the two negative answers were unified'
    ]

    "---- outdated ----"

    testOutdatedReportsTwoColumnsThatDisagree [
        "`You can upgrade` and `you would have to widen your constraint`
         are different facts with different actions. The fixture makes
         them differ for BOTH pins, so a build that reported one column
         answers half of this and passes nothing."
        | work index result |
        work := self track: (GrammarFixtures
            outdatedWorkDirNamed: 'gvt-outdated-work').
        index := self grammarIndex: 'gvt-outdated-index'.
        result := self over: index run: #('outdated') in: work.
        self assert: result exitCode = 0
            description: 'outdated answered exit ', result exitCode printString,
                ': ', result lines printString.
        self assert: result lines = GrammarFixtures outdatedLines
            description: 'outdated answered ', result lines printString
    ]

    testATransitivePinRendersTheDeclaredMarkerInItsAllowedColumn [
        "§8 decision 82. A column defined as `what YOUR constraint
         allows` has no value for a row the operator does not constrain,
         and BOTH tempting implementations lie.

         Letting absence collapse into `every version is admitted` makes
         the two columns coincide, so the row reads `you may move to
         2.0.0` about a version the dependency graph may forbid - the
         confident-wrong answer decisions 43, 52, 58 and 80 each refused
         on a different surface, arriving here by arithmetic rather than
         by anyone's intent. Omitting the pin lies the other way, saying
         `nothing is outdated` over a lock carrying a stale transitive
         release. So the pin is REPORTED and its allowed column renders
         the declared marker, while the published column is reported
         unchanged - that fact is true whoever owns the constraint.

         THE MARKER IS READ FROM THE RENDERER'S OWN DECLARATION, never
         restated here: a second copy in a fixture is a wording that
         drifts behind the one the operator actually sees (decision
         81's rule).

         THE DECLARED PIN IS CURRENT ON PURPOSE, so the answer is
         exactly one row and that row is the transitive one."
        | work index result |
        work := self track: (GrammarFixtures
            transitiveWorkDirNamed: 'gvt-transitive-work').
        index := self grammarIndex: 'gvt-transitive-index'.
        result := self over: index run: #('outdated') in: work.
        self assert: result exitCode = 0
            description: 'outdated over a transitive pin answered exit ',
                result exitCode printString, ': ', result lines printString.
        self assert: result lines = (Array with: (GrammarFixtures
            outdatedLineFor: 'kernel-text' pinned: '1.0.0'
            allowed: CLI unconstrainedAllowedMarker
            published: '2.0.0'))
            description: 'outdated answered ', result lines printString
    ]

    testOutdatedNeverOffersARetiredReleaseInEitherColumn [
        "A retired release is not an upgrade in either column, and a
         project whose only newer release is retired IS current."
        | work index result |
        work := self track: (GrammarFixtures
            currentWorkDirNamed: 'gvt-current-work').
        index := self grammarIndex: 'gvt-current-index'.
        result := self over: index run: #('outdated') in: work.
        self assert: result exitCode = 0
            description: 'a current project answered exit ',
                result exitCode printString.
        self assert: result lines
            = (Array with: GrammarFixtures nothingOutdatedLine)
            description: 'outdated answered ', result lines printString.
        self deny: (CommandLineFixtures does: result lines first
            include: '2.0.0')
            description: 'the retired release was offered'
    ]

    "---- all three read and explain, and change nothing ----"

    testTheThreeReadingVerbsWriteNothingAndSpawnNothing [
        "None of them writes a file, spawns a process or mutates the
         store. The lock is compared byte for byte, because a verb that
         rewrote an identical lock has still written to the operator's
         project."
        | index rows |
        index := self grammarIndex: 'gvt-readonly-index'.
        rows := (Array
            with: (Array with: 'gvt-readonly-search'
                with: #('search' 'kernel'))
            with: (Array with: 'gvt-readonly-info'
                with: #('info' 'kernel-text'))),
            (Array with: (Array with: 'gvt-readonly-outdated'
                with: #('outdated'))).
        rows do: [:row |
            | work runner before result |
            work := self track: (GrammarFixtures
                outdatedWorkDirNamed: (row at: 1)).
            before := PathFixtures contentsOf: work, '/parley.lock'.
            runner := RecordingRunner new.
            result := self resultOf: (row at: 2)
                , (Array with: '--source' with: index)
                in: work runner: runner.
            self assert: result exitCode = 0
                description: (row at: 2) printString, ' answered exit ',
                    result exitCode printString, ': ', result lines printString.
            self assert: runner commands = #()
                description: (row at: 2) printString, ' spawned ',
                    runner commands printString.
            self assert: (PathFixtures contentsOf: work, '/parley.lock')
                = before
                description: (row at: 2) printString, ' rewrote parley.lock']
    ]
]

Namespace current: Smalltalk.
