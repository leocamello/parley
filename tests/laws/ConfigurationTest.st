"Parley Sprint 19 — the configuration laws (issue #21 S6, S7, S9, S10,
 S12; Doc B §5.7, Doc E §4.1/§4.2, §8 decisions 64 and 65).

 WHAT THIS CLASS IS FOR. --source, --git and --index are retyped on
 every command and nothing records the choice. Parley.Configuration
 reads <workdir>/parley.config.st and ANSWERS VALUES. It decides no
 precedence: CommandLine decides, because precedence is wiring and
 wiring is already CommandLine's declared job. The laws below are split
 along exactly that line — the value laws ask Configuration, the
 precedence laws drive a real verb.

 THE READ IS A BOUNDARY LIKE EVERY OTHER (§8 decision 65), held to the
 settled shape from the day it exists rather than after it fails, which
 is the only moment when nothing has shipped depending on the wrong
 behaviour. Five hostile shapes, one line each, naming the path, at exit
 1 — never a kernel class, never exit 70.

 THE CENSUS STAYS AT EIGHT (§8 decision 60). The read routes through
 PathGuard; if Configuration acquired a File send of its own it would be
 a NINTH class and the settled prohibition would fail by construction.

 ONE LAW HERE IS S10'S LAW-SUITE COUNTERPART, DECLARED AS SUCH. The
 acceptance suite drives the five hostile shapes through a real verb and
 measures what the OPERATOR gets;
 testEveryHostileShapeAnswersOneLineNamingThePath measures the same five
 shapes AT THE BOUNDARY, where the declared carrier and the exact
 sentence are visible and an exit code is not. One scenario, two
 selectors, counted as selectors (the Sprint 18 correction).

 THE RED PHASE, LAW BY LAW — the ERROR/FAILURE split (finding F14) and,
 for each FAILURE, WHICH ASSERTION PRODUCES IT (finding F15):

   ERROR in red — the law reaches Parley.Configuration, which does not
   exist on the pre-sprint tree, so it aborts at that reference and the
   red gate says nothing about its interior:
     testTheSchemaKeysAreTheDeclaredSourceFlags (at Configuration keys)
     testEachDeclaredFlagIsAnsweredFromTheFileThatDeclaresIt
     testAnEmptyConfigAnswersNoSource
     testAnAbsentConfigAnswersNoSource

   FAILURE in red, with the assertion that produces it:
     testTheReaderWhitelistCarriesTheConfigTag — assertion 1, the
       whitelist does not include #'parley-config'.
     testEveryHostileShapeAnswersOneLineNamingThePath — assertion 2, the
       raised error is a MessageNotUnderstood rather than the declared
       ExecutionError. It is a FAILURE and not an ERROR because the
       reference to the absent class happens INSIDE the law's own
       handler, which catches it: the law therefore does reach its
       interior, and says so.
     testTheConfigSuppliesTheSourceWhenNoFlagIsGiven — assertion 1, the
       configured resolve answers exit 2.
     testAnExplicitFlagWinsAndTheConfigIsNeverConsulted — assertion 3.
       THE FIRST TWO PASS IN RED AND MUST: they assert the settled
       flag path still works with a malformed config sitting beside it,
       which is true today because nothing reads the file. The claim
       that fails is the other half — that the same file IS diagnosed
       when no flag is given, which is what makes 'never consulted'
       mean something rather than 'never read at all'.
     testAnExplicitFlagIsNotMergedWithADifferentConfiguredFlag —
       assertion 4 (OPERATOR AMENDMENT at the RED review). Assertions
       1-3 pass in red and must: they are the guard against an
       implementation that fills each ABSENT key from the file
       independently, which would wire --git alongside an explicit
       --source and answer the settled mutually-exclusive usage error at
       exit 2. Assertion 4 is the claim — the same file IS consulted
       when no flag is given — and it fails today.
     testTheConfigReadIsDeclaredAtBothTables — assertion 1, the
       pathBoundaries table declares no 'parley.config.st (read)' row.

   PASSES in red — declared here, as selectors, because an undeclared
   pass is finding F10 even when it is a legitimate guard. Neither is a
   scenario; both are guards inside a law suite:
     testTheHostileShapeFamilyIsTheDeclaredOne — a FIXTURE-CORRECTNESS
       guard in the shape Sprint 10's testTheEnumerationSeesTheRealSenders
       and Sprint 17's testTheProhibitionDetectsANinthClass have. It
       builds the hostile family and compares its labels against
       ConfigFixtures hostileShapeLabels; it calls nothing this sprint
       adds, so it passes from the first day. That is the point: it is
       what stops the two family-driven laws above from iterating a
       family that quietly lost a member. String <= FOLDS CASE on 3.2.5,
       so the declared order was taken from the toolchain and not from
       an ASCII reading (finding F15's Sprint 18 lesson).
     testConfigurationPerformsNoDirectFileIo — passes because a class
       that does not exist performs no I/O. It becomes a real claim the
       moment the class exists, and it names here the failure a reader
       would otherwise meet as a puzzling Sprint 17 acceptance failure.

 Every fixture path is under tmp/, unique per test, removed recursively
 in tearDown through PathFixtures removeTree:, which unlocks first.
 Nothing here spawns a process: RecordingRunner answers 0 and records."

Namespace current: Parley.

TestCase subclass: ConfigurationTest [
    | fixtureDirs |

    <comment: 'Laws for Parley.Configuration: the declared schema keys,
the value answered for each declared flag, absence, the five hostile
shapes and their pinned lines, the flag-wins precedence rule that keeps
every settled law byte-identical, the two table declarations, and the
guard that the read did not become a ninth I/O site.'>

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

    diamondIndex: aLabel [
        | path |
        path := self freshDir: aLabel.
        InstallFixtures populateInstallDiamondIn: path.
        ^path
    ]

    configurationIn: aWorkDir [
        ^Configuration in: aWorkDir
    ]

    "---- the schema ----"

    testTheSchemaKeysAreTheDeclaredSourceFlags [
        "THE KEYS ARE NOT A SECOND LIST OF FLAGS (Doc B §5.7). The body
         carries the DECLARED source flags, so the schema is derived
         from the settled sourceFlags table with the -- stripped, in the
         table's own order. A hand-kept key list is how a fourth source
         flag ships with a config file that cannot record it.

         The fixture's own oracle is asserted against the same
         derivation, so neither can drift alone."
        | derived |
        derived := CommandLine sourceFlagNames collect: [:flag |
            (flag copyFrom: 3 to: flag size) asSymbol].
        self assert: Configuration keys asArray = derived asArray
            description: 'the schema keys are ',
                Configuration keys printString,
                ' and the declared flags derive ', derived printString.
        self assert: Configuration keys asArray
            = ConfigFixtures declaredKeys
            description: 'the schema keys and the fixture oracle disagree: ',
                Configuration keys printString
    ]

    testTheReaderWhitelistCarriesTheConfigTag [
        "A DECLARED SETTLED-CLASS EXCEPTION, NEVER A SILENT WIDENING
         (Doc B §7; the Sprint 10 and Sprint 14 precedent). The whitelist
         is enforced inside readFrom:, so without this the settled reader
         refuses the operator's own configuration file — and the
         rejection sentence is the only place an operator learns what a
         build accepts, so it must name the new tag too.

         Sprint14AcceptanceTest testS6 is re-pinned in the same change
         and holds the sentence's exact bytes; this law holds the pairing
         that makes the re-pin forced rather than remembered."
        self assert: (IndexEntryReader formatTags
            includes: #'parley-config')
            description: 'the reader does not accept the configuration tag: ',
                IndexEntryReader formatTags printString.
        self assert: (CommandLineFixtures
            does: IndexEntryReader formatTagsText
            include: '#''parley-config''')
            description: 'the rejection sentence does not name the new tag: ',
                IndexEntryReader formatTagsText
    ]

    "---- the values ----"

    testEachDeclaredFlagIsAnsweredFromTheFileThatDeclaresIt [
        "ALL THREE FLAGS, DRIVEN (S9). A file records exactly one source
         and the other two keys record absence, so no flag can be
         honoured by accident of being first in the table — which is the
         one way a three-row table passes a law written for one row."
        CommandLine sourceFlagNames do: [:flag |
            | work config |
            work := ConfigFixtures workDirTracking: self tracker
                named: 'config-value-', (flag copyFrom: 3 to: flag size)
                contents: (ConfigFixtures contentsDeclaring: flag
                    value: 'the-recorded-value').
            config := self configurationIn: work.
            self assert: (config valueFor: flag) = 'the-recorded-value'
                description: flag, ' answered ',
                    (config valueFor: flag) printString.
            CommandLine sourceFlagNames do: [:other |
                other = flag ifFalse: [
                    self assert: (config valueFor: other) isNil
                        description: 'a file declaring ', flag,
                            ' answered ', (config valueFor: other) printString,
                            ' for ', other]]]
    ]

    testAnEmptyConfigAnswersNoSource [
        "The empty string RECORDS ABSENCE (Doc B §5.7, the §5.3 digest
         precedent) — it is not a source named by the empty path. A
         boundary that answered '' here would hand an empty directory
         path to a source constructor."
        | work config |
        work := ConfigFixtures workDirTracking: self tracker
            named: 'config-empty'
            contents: ConfigFixtures emptyContents.
        config := self configurationIn: work.
        CommandLine sourceFlagNames do: [:flag |
            self assert: (config valueFor: flag) isNil
                description: 'an empty config answered ',
                    (config valueFor: flag) printString, ' for ', flag]
    ]

    testAnAbsentConfigAnswersNoSource [
        "ABSENCE IS NOT A DEFECT, and this is the law that keeps the
         config additive. Every settled scenario runs in a project with
         no config at all; if the read treated absence as a hostile shape
         the whole suite would answer exit 1."
        | work config |
        work := ConfigFixtures plainWorkDirTracking: self tracker
            named: 'config-absent'.
        config := self configurationIn: work.
        self deny: (PathFixtures exists: config path)
            description: 'the fixture left a config file behind'.
        CommandLine sourceFlagNames do: [:flag |
            self assert: (config valueFor: flag) isNil
                description: 'an absent config answered ',
                    (config valueFor: flag) printString, ' for ', flag]
    ]

    "---- the boundary: the five hostile shapes ----"

    testTheHostileShapeFamilyIsTheDeclaredOne [
        "A FIXTURE-CORRECTNESS GUARD, DECLARED AS ONE, and a declared
         pass in red. A guard that fails first leaves the law it guards
         unrun and reports a FAILURE that says nothing about the claim
         (finding F15, Sprint 18) — so this one is separated from the
         laws it guards rather than folded into them as a first
         assertion.

         WHAT IT COMPARES: the labels the family builder produces,
         sorted the way 3.2.5 sorts them, against
         ConfigFixtures hostileShapeLabels. String <= FOLDS CASE on this
         toolchain, which is why the declared list was written from what
         the toolchain answers rather than from an ASCII reading."
        | shapes labels |
        shapes := ConfigFixtures hostileShapesTracking: self tracker
            labelled: 'config-family'.
        labels := ((shapes collect: [:row | row at: 1])
            asSortedCollection: [:a :b | a <= b]) asArray.
        self assert: labels = ConfigFixtures hostileShapeLabels
            description: 'the family builds ', labels printString
    ]

    testEveryHostileShapeAnswersOneLineNamingThePath [
        "THE BOUNDARY, ITERATED (§8 decision 65) — S10's law-suite
         counterpart at the level where the carrier is visible. Each
         shape is asked for a value and must answer the declared
         ExecutionError, the composition root's settled carrier for a
         filesystem precondition and a carrier rather than an
         attribution (§8 decision 72), carrying ONE line that opens with
         the path, states a cause and offers the checked remedy.

         The expected line is asserted as BYTES rather than by
         containment: a boundary that named the path and then said
         something else would satisfy containment, and the sentence is
         the whole of what the operator reads."
        | shapes |
        shapes := ConfigFixtures hostileShapesTracking: self tracker
            labelled: 'config-shape'.
        shapes do: [:row |
            | label path expected raised |
            label := row at: 1.
            path := row at: 3.
            expected := row at: 4.
            raised := nil.
            [(self configurationIn: (row at: 2)) valueFor: '--source']
                on: Error
                do: [:e | raised := e. e return: nil].
            self deny: raised isNil
                description: label, ' was accepted rather than refused'.
            self assert: (raised isKindOf: ExecutionError)
                description: label, ' answered ',
                    (CommandLineFixtures nameOf: raised class),
                    ' rather than the declared carrier'.
            self assert: raised messageText = expected
                description: label, ' answered ',
                    raised messageText printString,
                    ' rather than ', expected printString.
            self assert: (expected startsWith: path)
                description: label, ' does not open with its path: ',
                    expected.
            self assert: (expected endsWith: ConfigFixtures remedy)
                description: label, ' offers no remedy: ', expected]
    ]

    "---- precedence, which lives in CommandLine ----"

    testTheConfigSuppliesTheSourceWhenNoFlagIsGiven [
        "S6 AT THE LAW LEVEL: a project that records its index resolves
         without one, and the lock it writes is BYTE-IDENTICAL to the
         lock the flagged run writes. Byte-identity is the claim rather
         than 'it resolved', because a DEFAULT means the two paths must
         produce the same artifact and not merely the same exit code."
        | index configured flagged |
        index := self diamondIndex: 'config-default-index'.
        configured := ConfigFixtures workDirTracking: self tracker
            named: 'config-default-work'
            contents: (ConfigFixtures contentsDeclaring: '--source'
                value: (CommandLineFixtures absolutePathOf: index)).
        flagged := ConfigFixtures plainWorkDirTracking: self tracker
            named: 'config-default-control'.
        self assert: (ConfigFixtures resultOf: ConfigFixtures resolveArgv
            in: configured) exitCode = 0
            description: 'the configured resolve did not succeed'.
        self assert: (ConfigFixtures
            resultOf: (ConfigFixtures resolveArgvOn: index)
            in: flagged) exitCode = 0
            description: 'the flagged control did not succeed'.
        self assert: (ConfigFixtures lockContentsIn: configured)
            = (ConfigFixtures lockContentsIn: flagged)
            description: 'the configured lock and the flagged lock differ'
    ]

    testAnExplicitFlagWinsAndTheConfigIsNeverConsulted [
        "AN EXPLICIT FLAG ALWAYS WINS (§8 decision 64), and 'never
         consulted' is proved MECHANICALLY rather than asserted: the
         config in this project is MALFORMED, so a run that read it
         could not answer exit 0.

         BOTH HALVES, BECAUSE ONE HALF IS TRUE OF A TOOL THAT NEVER READS
         THE FILE AT ALL. Assertions 1 and 2 — the flagged run succeeds
         with its settled pins — pass on the pre-sprint tree and must
         keep passing: they are the invariant that keeps all 876 settled
         laws byte-identical, since every settled test passes a flag.
         Assertion 3 is the claim: the SAME file, in the SAME project,
         IS diagnosed when no flag is given. Together they say the file
         is read exactly when the flag is absent."
        | index work flagged unflagged |
        index := self diamondIndex: 'config-flagwins-index'.
        work := ConfigFixtures workDirTracking: self tracker
            named: 'config-flagwins-work'
            contents: ConfigFixtures unparseableContents.
        flagged := ConfigFixtures
            resultOf: (ConfigFixtures resolveArgvOn: index)
            in: work.
        self assert: flagged exitCode = 0
            description: 'the flag did not win over a malformed config: ',
                flagged lines printString.
        self assert: flagged lines = CommandLineFixtures diamondPinLines
            description: 'the flagged run answered ',
                flagged lines printString.
        unflagged := ConfigFixtures resultOf: ConfigFixtures resolveArgv
            in: work.
        self assert: unflagged exitCode = 1
            description: 'the same malformed config was not diagnosed without a flag - answered exit ',
                unflagged exitCode printString, ': ',
                unflagged lines printString
    ]

    testAnExplicitFlagIsNotMergedWithADifferentConfiguredFlag [
        "OPERATOR AMENDMENT, Sprint 19 RED review. Doc E §4.2 rules the
         whole rule and not half of it: 'an explicit flag always wins,
         AND THE CONFIG IS THEN NEVER CONSULTED'. Every other precedence
         law in this sprint drives the flag and the file declaring THE
         SAME KEY, or a file that is malformed — and both of those pass
         for an implementation that fills each ABSENT key independently
         from the file.

         THAT IMPLEMENTATION IS THE DEFECT THIS LAW EXISTS FOR, and it is
         invisible everywhere else. A project that records --git and is
         then overridden with an explicit --source would have BOTH keys
         wired, and the settled mutually-exclusive grammar answers that
         with the usage lines at exit 2 — so recording a source would
         break overriding it, on the first command anyone types after
         writing the file. No settled law can see this: every settled
         test runs with no config at all.

         ASSERTIONS 1-3 PASS IN RED AND MUST. They are the guard, and on
         the pre-sprint tree they hold because nothing reads the file.
         ASSERTION 4 IS WHAT FAILS: the same file, in the same project,
         IS consulted when no flag is given — without which 'not merged'
         would be satisfied by 'never read'."
        | index work control flagged controlRun unflagged controlUnflagged |
        index := self diamondIndex: 'config-crossflag-index'.
        work := ConfigFixtures workDirTracking: self tracker
            named: 'config-crossflag-work'
            contents: (ConfigFixtures contentsDeclaring: '--git'
                value: (SourceFixtures missingPathNamed: 'config-crossflag-repo')).
        control := ConfigFixtures plainWorkDirTracking: self tracker
            named: 'config-crossflag-control'.
        flagged := ConfigFixtures
            resultOf: (ConfigFixtures resolveArgvOn: index) in: work.
        controlRun := ConfigFixtures
            resultOf: (ConfigFixtures resolveArgvOn: index) in: control.
        self assert: flagged exitCode = 0
            description: 'a --source flag over a --git config answered exit ',
                flagged exitCode printString, ': ', flagged lines printString.
        self assert: flagged lines = CommandLineFixtures diamondPinLines
            description: 'the flagged run answered ', flagged lines printString.
        self assert: flagged lines = controlRun lines
            description: 'the flagged run differs from the same run in a project with no config: ',
                flagged lines printString, ' and ', controlRun lines printString.
        controlUnflagged := ConfigFixtures
            resultOf: ConfigFixtures resolveArgv in: control.
        unflagged := ConfigFixtures
            resultOf: ConfigFixtures resolveArgv in: work.
        self deny: unflagged lines = controlUnflagged lines
            description: 'a project recording --git answered the same as a project recording nothing - the file was not consulted when the flag was absent: ',
                unflagged lines printString
    ]

    "---- the two declarations, and the census ----"

    testTheConfigReadIsDeclaredAtBothTables [
        "A NEW OPERATOR-EDITABLE FILE IS TWO DECLARATIONS, NOT ONE, and
         a row missing from either is a drift law that cannot see this
         boundary. pathBoundaries carries its role, direction, carrier
         and guarding; deserializationBoundaries carries the class and
         the file, because Configuration is the FIFTH sender of the
         settled reader."
        | row |
        row := CommandLine pathBoundaries
            detect: [:each | (each at: 1) = 'parley.config.st (read)']
            ifNone: [nil].
        self deny: row isNil
            description: 'the boundary table declares no configuration row'.
        self assert: (row at: 2) = #read
            description: 'the configuration row declares direction ',
                (row at: 2) printString.
        self assert: (row at: 3) == ExecutionError
            description: 'the configuration row declares carrier ',
                (CommandLineFixtures nameOf: (row at: 3)).
        self assert: (row at: 4) = #guarded
            description: 'the configuration row declares guarding ',
                (row at: 4) printString.
        self assert: ((LockSchemaFixtures namesOfBoundaryClassesIn:
            CommandLine deserializationBoundaries)
                includes: 'Configuration')
            description: 'Configuration is not a declared deserialization boundary'
    ]

    testConfigurationPerformsNoDirectFileIo [
        "THE CENSUS STAYS AT EIGHT (§8 decision 60). The config read goes
         through PathGuard like every other boundary; a File, FileStream
         or Directory send of its own would make Configuration a NINTH
         class and fail the settled prohibition.

         A DECLARED PASS IN RED: a class that does not exist performs no
         I/O. That is the honest reading rather than a weakness — it
         becomes a real claim the moment the class exists, and it names
         here the failure a reader would otherwise meet as a puzzling
         acceptance failure in a suite this sprint never touched."
        self deny: (PathFixtures ioSiteClassNames
            includes: 'Configuration')
            description: 'Configuration performs direct File I/O - the decision-60 census would grow to nine and Sprint17AcceptanceTest testS13 fails by construction'
    ]
]

Namespace current: Smalltalk.
