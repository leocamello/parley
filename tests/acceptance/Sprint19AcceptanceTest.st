"Parley Sprint 19 — acceptance scenarios S1-S15 (issue #21).

 THE SPRINT THAT STOPS THE COMMANDS SHOUTING AND MAKES THE PROJECT
 REMEMBER ITS INDEX. Two defects and one carried gap, all three on the
 path a new operator walks in their first hour.

 ONE: publish prints FIVE FOREIGN LINES above its own composed line —
 mkdir, mkdir, ln -s -f, rm -f, cd … && zip — leaking /tmp/gstar-* and
 Parley's staging directory, and install prints an /usr/bin/install -c
 line. Sprint 18's defect at the execution boundary: text on the
 operator's terminal that Parley did not write. The mechanism is a
 stdout redirect appended to the composed line AT EXECUTION (§8 decision
 63), so the plan value and both settled diagnoses stay byte-identical
 underneath it. exec is not a redirect: its one child is both the
 plumbing and the author's program on one stream, so its GC chatter is
 stopped at the source by -g in the pinned composition (§8 decision 77).

 TWO: --source, --git and --index are retyped on every command, with no
 way to record the choice. parley.config.st records it, at the PROJECT
 ROOT and not under .parley/ — regenerable state a user may delete to
 clean a project — in the settled literal micro-format, read by the
 settled reader, held to the settled boundary shape from the day it
 exists (§8 decisions 64 and 65). AN EXPLICIT FLAG ALWAYS WINS, which
 is what keeps every settled law byte-identical: every settled test
 passes a flag, so the file is never on any of those paths.

 AND THE CARRIED GAP RIDES ALONG (§8 decision 76): a Package.st that
 sends define: twice, where EITHER send raises, exited 0 with two orphan
 Object: nil fragments and no diagnosis. Doc E §3 has said since Sprint
 9 that such a file must never half-succeed; the ordering rules beneath
 that sentence govern the captured-error slot, which a
 doesNotUnderstand never reaches. The sentence was true and nothing
 below it could make it false.

 DECLARED PASSES IN RED (issue #21) — TWO SCENARIOS, S8 and S11, and in
 this file that is exactly two selectors:
   testS8_NoConfigAndNoFlagAnswersTheSettledUsageLines — the settled
     usage answer, byte-identical. It passes today and must keep
     passing: the config read is inserted BEFORE the usage
     determination, and this is the law that says inserting it did not
     turn a person who forgot a flag into a person with a broken file.
   testS11_EverySettledScenarioIsByteIdenticalWithNoConfigFile — the
     config can only ADD. With no file present the settled pins, the
     settled lock bytes, the settled usage lines and the settled
     version line are unchanged.
 S4 LEFT THIS SET when §8 decision 77 re-ruled the exec carve-out: the
 GC message is present on the pre-sprint tree, so asserting its ABSENCE
 fails in red. Every other scenario here fails against the pre-sprint
 tree, and the law suites declare their own passes by selector.

 COST, DECLARED. S1, S2, S3 and S4 spawn the shipped binary once each
 and are the only instrument that can see text Parley did not write; S1,
 S2 and S3 additionally build a real .star with the toolchain (S2
 through the settled probe fixture, S1 and S3 through the publish
 pipeline itself), because a child that never runs gst-package cannot
 echo the lines this sprint removes. S3 spawns rather than running
 in-image on purpose: an artifact guard measured on a run that was never
 silenced is a guard over a different pipeline. Everything else runs
 in-image against tmp/ fixtures with a RecordingRunner. No scenario
 contacts a network and none runs git.

 S3 MEASURES THE ARTIFACT AS FAR AS THIS TOOLCHAIN ALLOWS, and says so
 rather than overclaiming (§8 decision 43). A toolchain-built .star
 embeds the staged files' modification times, so two builds of one
 project answer different bytes — probed pre-RED: they differ at byte 11
 of the archive and at byte 164 of the entry, which is the digest. A
 byte comparison against a second build is therefore not available, and
 the settled digest discipline already says so. What IS measured: the
 entry is byte-identical to a hand-written oracle, and the digest it
 records verifies against the landed archive through the settled,
 vector-anchored Sha256. Silencing changed the terminal and nothing
 else.

 TEARDOWN GOES THROUGH PathFixtures removeTree:, WHICH UNLOCKS FIRST.
 The Transcript binding is restored in tearDown as a safety net, because
 S13 and S14 drive the capture path and a leaked swap does not fail
 loudly — it silences every suite after this one."

Namespace current: Parley.

TestCase subclass: Sprint19AcceptanceTest [
    | fixtureDirs previousTranscript |

    <comment: 'The Sprint 19 acceptance scenarios: the silenced plumbing
children measured on captured stdout and stderr from the shipped binary,
the artifacts and the failure diagnosis held in place underneath, the
quiet exec child that still passes its script''s stderr and exit code
through, the project configuration with its flag-wins precedence and its
five hostile shapes, the state directory proved regenerable, the
half-succeeding manifest closed, and the README.'>

    setUp [
        fixtureDirs := OrderedCollection new.
        previousTranscript := Smalltalk at: #Transcript
    ]

    tearDown [
        previousTranscript isNil ifFalse: [
            Smalltalk at: #Transcript put: previousTranscript].
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

    absolute: aPath [
        ^CommandLineFixtures absolutePathOf: aPath
    ]

    captures: aLabel [
        ^AuthoringFixtures captureDirTracking: self tracker named: aLabel
    ]

    resultOf: anArgvArray in: aWorkDir [
        ^ConfigFixtures resultOf: anArgvArray in: aWorkDir
    ]

    denyForeign: someMarkers in: aText stream: aStreamName [
        someMarkers do: [:row |
            self deny: (CommandLineFixtures does: aText include: (row at: 2))
                description: aStreamName, ' carried ', (row at: 1),
                    ' (', (row at: 2), ')']
    ]

    "---- S1: publish writes its own line and nothing else ----"

    testS1_PublishWritesOnlyItsOwnComposedLine [
        "THE OPENING DEFECT, driven through the shipped binary with both
         streams captured SEPARATELY — the only instrument that can see
         it. The settled runners merge with 2>&1 and cannot tell text
         Parley kept on one stream from text it must remove from the
         other.

         STDOUT IS ASSERTED EXACTLY, NOT BY CONTAINMENT. Five lines
         removed and one kept is a claim about the WHOLE stream, and
         containment cannot tell one composed line from one composed
         line with five foreign ones above it.

         THE BOUND ON THE MARKER SET IS STATED (§8 decision 43): the
         /tmp/ needle is spelled /tmp/gstar-, the toolchain's own
         scratch directory, because every fixture in this suite lives
         under <repo>/tmp/ and the bare form would be matched by
         Parley's own legitimate paths."
        | work dest run |
        work := ChatterFixtures publishableWorkDirTracking: self tracker
            named: 's19-1-work'.
        dest := self freshDir: 's19-1-dest'.
        run := AuthoringFixtures runShippedIn: work
            args: 'publish ', (self absolute: dest)
            captures: (self captures: 's19-1-captures')
            label: 's19-1'.
        self assert: (run at: 1) = 0
            description: 'publish exited ', (run at: 1) printString,
                ' with stdout ', (run at: 2) printString,
                ' and stderr ', (run at: 3) printString.
        self assert: (ExecFixtures linesOf: (run at: 2))
            = (Array with: ChatterFixtures publishedLine)
            description: 'the captured stdout is ',
                (ExecFixtures linesOf: (run at: 2)) printString.
        self denyForeign: ChatterFixtures publishChatterMarkers
            in: (run at: 2) stream: 'stdout'.
        self denyForeign: ChatterFixtures publishChatterMarkers
            in: (run at: 3) stream: 'stderr'
    ]

    "---- S2: install writes only its pins ----"

    testS2_InstallWritesOnlyItsOwnPinLines [
        "THE SECOND HALF OF THE SAME DEFECT, and the one whose ORIGIN the
         issue named wrongly until it was probed: the /usr/bin/install -c
         line is gst-package's own echo from the REGISTRATION child, not
         Parley's staging line — which is silent — and not Installer,
         which composes no command line at all.

         The index carries a real toolchain-built .star, because a
         registration child that never runs gst-package cannot echo the
         line this scenario removes."
        | work index run |
        index := ChatterFixtures probeIndexTracking: self tracker
            named: 's19-2-index'.
        work := self track:
            (CommandLineFixtures probeRootWorkDirNamed: 's19-2-work').
        run := AuthoringFixtures runShippedIn: work
            args: 'install --source ', (self absolute: index)
            captures: (self captures: 's19-2-captures')
            label: 's19-2'.
        self assert: (run at: 1) = 0
            description: 'install exited ', (run at: 1) printString,
                ' with stdout ', (run at: 2) printString,
                ' and stderr ', (run at: 3) printString.
        self assert: (ExecFixtures linesOf: (run at: 2))
            = (Array with: ChatterFixtures probePinLine)
            description: 'the captured stdout is ',
                (ExecFixtures linesOf: (run at: 2)) printString.
        self denyForeign: ChatterFixtures installChatterMarkers
            in: (run at: 2) stream: 'stdout'.
        self denyForeign: ChatterFixtures installChatterMarkers
            in: (run at: 3) stream: 'stderr'
    ]

    "---- S3: the artifacts did not move ----"

    testS3_TheProducedArchiveAndEntryAreUnchanged [
        "SILENCING CHANGED THE TERMINAL AND NOTHING ELSE. A guard, and
         the one a redirect written into the wrong place fails: a tail
         appended to the package.xml path rather than to the command
         would still quieten the terminal and would build the archive
         somewhere else, or not at all.

         Measured with the settled digest discipline (see this file's
         header for why a zip cannot be compared byte-for-byte across
         builds): the entry is byte-identical to a hand-written oracle
         carrying the landed archive's own digest, and that digest is
         computed from the landed bytes through the settled Sha256.

         IT IS DRIVEN THROUGH THE SHIPPED BINARY BECAUSE THE SCENARIO
         SAYS 'THE SAME PUBLISH'. An artifact guard measured on a run
         that was never silenced is a guard over a different pipeline —
         so this scenario establishes the terminal was quiet FIRST, and
         then asks what the quiet run left on disk."
        | work dest run archive digest entry |
        work := ChatterFixtures publishableWorkDirTracking: self tracker
            named: 's19-3-work'.
        dest := self freshDir: 's19-3-dest'.
        run := AuthoringFixtures runShippedIn: work
            args: 'publish ', (self absolute: dest)
            captures: (self captures: 's19-3-captures')
            label: 's19-3'.
        self assert: (run at: 1) = 0
            description: 'publish exited ', (run at: 1) printString.
        self assert: (ExecFixtures linesOf: (run at: 2))
            = (Array with: ChatterFixtures publishedLine)
            description: 'the publish this scenario measures was not the silenced one: ',
                (ExecFixtures linesOf: (run at: 2)) printString.
        archive := PathFixtures contentsOf:
            dest, '/', ChatterFixtures archiveFileName.
        entry := PathFixtures contentsOf:
            dest, '/', ChatterFixtures entryFileName.
        digest := Sha256 hexDigestOf: archive.
        self deny: archive isEmpty
            description: 'the published archive is empty'.
        "OPERATOR AMENDMENT, Sprint 19 RED review: the archive is asserted
         on its CONTENT and not only on its size. `not empty` plus a
         digest computed FROM the landed bytes is satisfied by whatever
         landed — including junk — because the digest half agrees with
         itself by construction. gst-package builds with zip -n .st:.xml,
         which stores those suffixes uncompressed (probed), so the
         witness source survives into the archive verbatim and its
         absence means the quiet run built something else."
        self assert: (CommandLineFixtures does: archive
            include: ChatterFixtures witnessMarker)
            description: 'the published archive does not carry the witness source - the silenced run built something else'.
        self assert: entry = (ChatterFixtures entryOracleWithDigest: digest)
            description: 'the published entry is ', entry printString
    ]

    "---- S4: exec goes quiet by flag, and only the plumbing does ----"

    testS4_ExecSilencesThePlumbingAndNotTheProgram [
        "§8 decision 77, and the scenario that flipped when it landed.
         The GC message is ABSENT from captured stderr; the SCRIPT'S OWN
         stderr line survives on the same stream; its stdout is
         untouched; and the child's exit code passes through unchanged,
         which is decision 45 held in place.

         The script writes to both streams ON PURPOSE. A flag that
         silenced the child's stderr wholesale would pass a law that
         only denied the GC message — this is what tells the two apart."
        | work run |
        work := ChatterFixtures execWorkDirTracking: self tracker
            named: 's19-4-work'.
        run := AuthoringFixtures runShippedIn: work
            args: 'exec ', (self absolute:
                work, '/', ChatterFixtures execScriptFileName)
            captures: (self captures: 's19-4-captures')
            label: 's19-4'.
        self assert: (run at: 1) = ChatterFixtures execScriptExitCode
            description: 'exec exited ', (run at: 1) printString,
                ' rather than passing the child''s code through'.
        self deny: (CommandLineFixtures does: (run at: 3)
            include: ChatterFixtures gcMessageMarker)
            description: 'the captured stderr still carries the plumbing chatter: ',
                (run at: 3) printString.
        self assert: (ExecFixtures linesOf: (run at: 3))
            = (Array with: ChatterFixtures execScriptStderrLine)
            description: 'the captured stderr is ',
                (ExecFixtures linesOf: (run at: 3)) printString.
        self assert: (ExecFixtures linesOf: (run at: 2))
            = (Array with: ChatterFixtures execScriptStdoutLine)
            description: 'the captured stdout is ',
                (ExecFixtures linesOf: (run at: 2)) printString
    ]

    "---- S5: a silenced child that fails is still diagnosed ----"

    testS5_AFailingPlumbingChildIsStillDiagnosed [
        "THE SCENARIO A CARELESS REDIRECT FAILS. S1 and S2 pass for a
         tail carrying 2>&1; this one does not. The child's exit code is
         still checked, the settled diagnosis still names the command
         Parley composed, and the run that produced it really was
         silenced — asserted here, because a diagnosis that survives
         because nothing was redirected proves nothing."
        | work dest runner result expected |
        work := ChatterFixtures publishableWorkDirTracking: self tracker
            named: 's19-5-work'.
        dest := self freshDir: 's19-5-dest'.
        runner := RecordingRunner answering: 2.
        result := (CommandLine in: work runner: runner)
            run: (Array with: 'publish' with: dest).
        expected := PublishFixtures
            buildFailureProblemFor: (PublishFixtures buildCommandFor: dest)
            code: 2.
        self assert: result exitCode = 1
            description: 'a failing build answered exit ',
                result exitCode printString.
        self assert: result lines = (Array with: expected)
            description: 'a failing build answered ',
                result lines printString.
        self deny: runner commands isEmpty
            description: 'no command was run at all'.
        runner commands do: [:line |
            self assert: (line endsWith: ChatterFixtures stdoutRedirectTail)
                description: 'the failing child was not silenced: ', line]
    ]

    "---- S6: the project remembers its index ----"

    testS6_AConfiguredSourceResolvesWithNoFlag [
        "THE POINT OF THE SPRINT'S SECOND HALF. The lock is asserted
         byte-identical to the flagged run's rather than merely written:
         a default that produced a different artifact would not be a
         default."
        | index work control |
        index := self diamondIndex: 's19-6-index'.
        work := ConfigFixtures workDirTracking: self tracker
            named: 's19-6-work'
            contents: (ConfigFixtures contentsDeclaring: '--source'
                value: (self absolute: index)).
        control := ConfigFixtures plainWorkDirTracking: self tracker
            named: 's19-6-control'.
        self assert: (self resultOf: ConfigFixtures resolveArgv in: work)
            exitCode = 0
            description: 'the configured resolve answered ',
                (self resultOf: ConfigFixtures resolveArgv in: work)
                    lines printString.
        self assert: (self resultOf: (ConfigFixtures resolveArgvOn: index)
            in: control) exitCode = 0
            description: 'the flagged control did not succeed'.
        self assert: (ConfigFixtures lockContentsIn: work)
            = (ConfigFixtures lockContentsIn: control)
            description: 'the configured lock differs from the flagged lock'
    ]

    "---- S7: an explicit flag always wins ----"

    testS7_AnExplicitFlagWinsOverTheConfiguredSource [
        "TWO INDEXES AND ONE PROJECT, and the LOCK says which was
         consulted — an exit code cannot, because both indexes resolve.
         The two carry different archive digests, so the lock bytes
         differ, and the first assertion is the FIXTURE-CORRECTNESS
         GUARD that says so: if the two oracles were equal this scenario
         would pass whichever index was read, which is the shape of a
         law about nothing.

         BOTH DIRECTIONS ARE DRIVEN IN ONE PROJECT. With the flag, the
         lock is the flagged index's — true today, and the invariant
         that keeps every settled law byte-identical. Without it, the
         same file supplies the source and the lock is the configured
         index's. Only the pair says the flag WINS rather than that the
         file is never read."
        | configured flagged work configuredLock flaggedLock |
        configured := self freshDir: 's19-7-configured-index'.
        SourceFixtures populateDiamondIn: configured.
        flagged := self diamondIndex: 's19-7-flagged-index'.
        configuredLock := self lockFromResolving: configured
            labelled: 's19-7-configured-oracle'.
        flaggedLock := self lockFromResolving: flagged
            labelled: 's19-7-flagged-oracle'.
        self deny: configuredLock = flaggedLock
            description: 'the two indexes answer the same lock - this scenario could not tell them apart'.
        work := ConfigFixtures workDirTracking: self tracker
            named: 's19-7-work'
            contents: (ConfigFixtures contentsDeclaring: '--source'
                value: (self absolute: configured)).
        self assert: (self resultOf: (ConfigFixtures resolveArgvOn: flagged)
            in: work) exitCode = 0
            description: 'the flagged run did not succeed'.
        self assert: (ConfigFixtures lockContentsIn: work) = flaggedLock
            description: 'the flag did not win: the lock is ',
                (ConfigFixtures lockContentsIn: work) printString.
        self assert: (self resultOf: ConfigFixtures resolveArgv in: work)
            exitCode = 0
            description: 'the same project did not resolve from its config'.
        self assert: (ConfigFixtures lockContentsIn: work) = configuredLock
            description: 'the config was not consulted when the flag was absent: the lock is ',
                (ConfigFixtures lockContentsIn: work) printString
    ]

    lockFromResolving: anIndexDir labelled: aLabel [
        "The lock a flagged resolve against anIndexDir writes, taken in
         a project of its own so it is an oracle and not a leftover."
        | control |
        control := ConfigFixtures plainWorkDirTracking: self tracker
            named: aLabel.
        self resultOf: (ConfigFixtures resolveArgvOn: anIndexDir)
            in: control.
        ^ConfigFixtures lockContentsIn: control
    ]

    "---- S8: no config, no flag — the settled usage answer ----"

    testS8_NoConfigAndNoFlagAnswersTheSettledUsageLines [
        "A DECLARED PASS IN RED. The config read is inserted BEFORE the
         usage determination — it has to be, or a malformed file would
         be reported as an operator who forgot a flag — and this is the
         law that says the insertion did not turn the ordinary mistake
         into a file defect.

         RE-PINNED IN GREEN (§8 decision 83), AND THE GROUND IS WHAT
         SURVIVES. The answer moved because resolve left the grammar:
         this work directory is the settled DIAMOND ROOT, so it declares
         index-needing dependencies and no path ones, and a flagless
         resolve over it now reaches the verb and composes the declared
         in-verb refusal at exit 1 rather than the usage block at exit 2.

         THE CLAIM IS UNCHANGED AND IS STILL THE POINT: an operator who
         forgot a flag is told they forgot a flag. The refusal names
         what the manifest declares AND names parley.config.st as one of
         the two places that can answer — which is this scenario's own
         subject reaching the operator — and it is not, in any spelling,
         a report that their configuration file is broken. That last is
         asserted rather than assumed: this directory has NO config
         file, and neither malformed-file line may appear.

         WHAT WAS DROPPED AND WHY. The old third assertion compared this
         answer's tail against the bare-argv usage answer's tail, to
         catch the two silently ceasing to share the block. That
         comparison cannot survive the ruling — the refusal is ONE line
         and carries no block at all — so its intent is kept in the
         stronger direction available here: the block must be ABSENT.
         The shared-block relationship itself is not left unguarded; it
         is UsageGroundTest's subject, over argvs that still answer
         usage."
        | work result |
        work := ConfigFixtures plainWorkDirTracking: self tracker
            named: 's19-8-work'.
        result := self resultOf: ConfigFixtures resolveArgv in: work.
        self assert: result exitCode = 1
            description: 'a source-less resolve answered exit ',
                result exitCode printString, ': ',
                result lines printString.
        "the two names ExecFixtures diamondRootContents DECLARES"
        self assert: result lines = (Array with: (PathDepFixtures
            needsIndexRefusalFor: (Array with: 'a' with: 'b')))
            description: 'the declared refusal moved: ', result lines printString.
        self assert: (CommandLineFixtures does: result lines first
            include: 'parley.config.st')
            description: 'the refusal stopped naming this sprint''s file: ',
                result lines first printString.
        result lines do: [:line |
            self deny: (CommandLineFixtures does: line
                include: 'usage: parley')
                description: 'the refusal carried the usage block'.
            self deny: line = (ConfigFixtures malformedKeysLineFor:
                (ConfigFixtures pathIn: work))
                description: 'a project with no config file was told its keys are malformed'.
            self deny: line = (ConfigFixtures malformedValueLineFor:
                (ConfigFixtures pathIn: work))
                description: 'a project with no config file was told its values are malformed']
    ]

    "---- S9: all three declared flags, honoured identically ----"

    testS9_EveryDeclaredFlagIsHonouredExactlyAsItsFlag [
        "DRIVEN THROUGH ALL THREE DECLARED FLAGS, and the comparison is
         against the FLAGGED RUN ITSELF rather than against a
         hand-written expectation — 'honoured exactly as the equivalent
         flag' is a claim about equality, so it is measured as equality.

         ONE working directory per flag, used twice: the flagged run
         first, then the configured run in the same directory, so no
         path can differ between them and a diagnosis naming a cache
         path compares byte-for-byte.

         The runner is a double, so --git and --index spawn nothing:
         whatever the two runs answer, they must answer the same thing.

         THE WORK-DIR LABEL CARRIES -work- (corrected in GREEN, and the
         correction is a fixture label rather than a claim). Written as
         's19-9-<flag>' it collided with the --source index fixture,
         's19-9-index': the third iteration's directoryNamed: swept and
         recreated the very directory the first iteration had populated,
         and tearDown then removed one path twice and raised out of
         PathFixtures unlock:. Every assertion in this scenario passed
         both before and after; what failed was teardown, reported as an
         ERROR against the scenario."
        CommandLine sourceFlags do: [:row |
            | flag value work flagged configured |
            flag := row at: 1.
            value := self valueForFlag: flag.
            work := ConfigFixtures workDirTracking: self tracker
                named: 's19-9-work-', (flag copyFrom: 3 to: flag size)
                contents: (ConfigFixtures contentsDeclaring: flag
                    value: value).
            flagged := self resultOf: (Array with: 'resolve'
                with: flag with: value) in: work.
            configured := self resultOf: ConfigFixtures resolveArgv
                in: work.
            self assert: configured exitCode = flagged exitCode
                description: flag, ' configured answered exit ',
                    configured exitCode printString, ' and flagged ',
                    flagged exitCode printString.
            self assert: configured lines = flagged lines
                description: flag, ' configured answered ',
                    configured lines printString, ' and flagged ',
                    flagged lines printString]
    ]

    valueForFlag: aFlagString [
        "The value each declared flag is driven with. --source names a
         real diamond index, so the pair really resolves; --git and
         --index name locations nothing serves, so the pair really
         fails — and both runs must fail identically, which is the same
         claim as both succeeding identically."
        aFlagString = '--source'
            ifTrue: [^self absolute: (self diamondIndex: 's19-9-index')].
        aFlagString = '--git'
            ifTrue: [^self absolute:
                (SourceFixtures missingPathNamed: 's19-9-repo')].
        ^'file://', (self absolute:
            (SourceFixtures missingPathNamed: 's19-9-base'))
    ]

    "---- S10: every hostile config shape is a diagnosis ----"

    testS10_EveryMalformedConfigAnswersOneLineNamingThePath [
        "THE BOUNDARY AS THE OPERATOR MEETS IT (§8 decision 65). Five
         shapes — a directory, a file that does not parse, the wrong
         tag, four malformed bodies and a file declaring two sources —
         each answering ONE line naming the path with a checked remedy
         at exit 1, and never exit 70, a kernel class or a backtrace.

         The two-source file is a BODY defect and not a precedence
         question (Doc B §5.7): the flag grammar refuses --source with
         --git rather than preferring one, because a silent preference
         makes a typo look like a working command, and a file nobody
         retypes has more need of that rule than a command line."
        | shapes |
        shapes := ConfigFixtures hostileShapesTracking: self tracker
            labelled: 's19-10'.
        self assert: (((shapes collect: [:row | row at: 1])
            asSortedCollection: [:a :b | a <= b]) asArray)
                = ConfigFixtures hostileShapeLabels
            description: 'the hostile family is not the declared one'.
        shapes do: [:row |
            | result |
            result := self resultOf: ConfigFixtures resolveArgv
                in: (row at: 2).
            self assert: result exitCode = 1
                description: (row at: 1), ' answered exit ',
                    result exitCode printString, ': ',
                    result lines printString.
            self assert: result lines = (Array with: (row at: 4))
                description: (row at: 1), ' answered ',
                    result lines printString.
            result lines do: [:line |
                self deny: (CommandLineFixtures does: line
                    include: LockBoundaryFixtures undiagnosedLinePrefix)
                    description: (row at: 1), ' blamed Parley: ', line.
                self deny: (CommandLineFixtures does: line
                    include: ReadinessFixtures kernelErrorMarker)
                    description: (row at: 1), ' named a kernel error: ', line.
                CommandLineFixtures backtraceMarkers do: [:marker |
                    self deny: (CommandLineFixtures does: line
                        include: marker)
                        description: (row at: 1),
                            ' dumped a backtrace: ', line]]]
    ]

    "---- S11: with no config, nothing settled moved ----"

    testS11_EverySettledScenarioIsByteIdenticalWithNoConfigFile [
        "A DECLARED PASS IN RED, and the law that makes the whole sprint
         additive. THE CONFIG CAN ONLY ADD: with no file present, the
         settled pins, the settled lock bytes, the settled usage answer
         and the settled version line are what they always were.

         It is a representative drive rather than a re-run of 876 laws —
         the suite itself is the exhaustive form, and this is the
         scenario that says so in one place: a resolve that writes an
         artifact, a usage error, and a question flag."
        | index work resolved |
        index := self diamondIndex: 's19-11-index'.
        work := ConfigFixtures plainWorkDirTracking: self tracker
            named: 's19-11-work'.
        self deny: (PathFixtures exists: (ConfigFixtures pathIn: work))
            description: 'the fixture left a config file behind'.
        resolved := self resultOf: (ConfigFixtures resolveArgvOn: index)
            in: work.
        self assert: resolved exitCode = 0
            description: 'the settled resolve answered ',
                resolved lines printString.
        self assert: resolved lines = CommandLineFixtures diamondPinLines
            description: 'the settled pins are now ',
                resolved lines printString.
        self assert: (ConfigFixtures lockContentsIn: work)
            = ExecFixtures diamondLockString
            description: 'the settled lock bytes moved'.
        self assert: (self resultOf: #() in: work) exitCode = 2
            description: 'the settled usage exit code moved'.
        self assert: (self resultOf: (Array with: '--version') in: work)
            lines = (Array with: CommandLine versionLine)
            description: 'the settled version line moved'
    ]

    "---- S12: configuration is not regenerable state ----"

    testS12_TheConfigSurvivesDeletingTheStateDirectory [
        "WHY THE FILE IS AT THE PROJECT ROOT (§8 decision 64). .parley/
         is regenerable state — the store, the caches, the packages
         target — and an operator may delete it to clean a project. A
         configuration file inside the disposable directory is how a
         tool eventually tells a user to delete their own settings.

         The whole directory is removed, not one entry, and the second
         run must answer what the first did — including the lock, which
         proves the source was found again and not merely that nothing
         crashed."
        | index work first second |
        index := self diamondIndex: 's19-12-index'.
        work := ConfigFixtures workDirTracking: self tracker
            named: 's19-12-work'
            contents: (ConfigFixtures contentsDeclaring: '--source'
                value: (self absolute: index)).
        first := self resultOf: ConfigFixtures resolveArgv in: work.
        self assert: first exitCode = 0
            description: 'the first configured resolve answered ',
                first lines printString.
        PathFixtures removeTree: (PathFixtures parleyDirIn: work).
        self deny: (PathFixtures exists: (PathFixtures parleyDirIn: work))
            description: 'the state directory survived removal'.
        self assert: (PathFixtures exists: (ConfigFixtures pathIn: work))
            description: 'removing .parley removed the configuration file'.
        second := self resultOf: ConfigFixtures resolveArgv in: work.
        self assert: second exitCode = 0
            description: 'the resolve after the wipe answered ',
                second lines printString.
        self assert: second lines = first lines
            description: 'the resolve after the wipe answered ',
                second lines printString
    ]

    "---- S13/S14: a broken define: never half-succeeds ----"

    testS13_ASecondDefineThatRaisesIsRefused [
        "§8 decision 76, the carried gap. The first define: succeeds and
         the second raises, so recorded is non-nil and the anchor the
         capture recovered was thrown away: the verb exited 0 with two
         orphan Object: nil fragments and no diagnosis at all.

         A RECOVERED ANCHOR IS ITSELF A FAILURE SIGNAL, checked before
         recorded. The re-voiced diagnosis names the file and the line
         the author must open — the settled Sprint 18 wording, reused
         rather than re-toned, because it is the same event."
        | work index result |
        work := AuthoringFixtures workDirTracking: self tracker
            named: 's19-13-work'
            contents: AuthoringFixtures secondDefineRaisesContents.
        index := self freshDir: 's19-13-index'.
        result := self resultOf:
            (ConfigFixtures resolveArgvOn: index) in: work.
        self assert: result exitCode = 1
            description: 'a half-succeeding manifest answered exit ',
                result exitCode printString, ': ',
                result lines printString.
        self assert: result lines = (Array with: (AuthoringFixtures
            anchorLineFor: (AuthoringFixtures manifestPathIn: work)
            line: AuthoringFixtures secondDefineRaisesLineNumber))
            description: 'it answered ', result lines printString
    ]

    testS14_AFirstDefineThatRaisesIsRefusedToo [
        "THE MIRROR, and the case Doc E §3's settled sentence names in
         so many words: where a file sends define: more than once, the
         FIRST authoring error wins and is reported even if a later
         define: succeeds. The sentence has been true since Sprint 9;
         this is the first test that can make it false."
        | work index result |
        work := AuthoringFixtures workDirTracking: self tracker
            named: 's19-14-work'
            contents: AuthoringFixtures firstDefineRaisesContents.
        index := self freshDir: 's19-14-index'.
        result := self resultOf:
            (ConfigFixtures resolveArgvOn: index) in: work.
        self assert: result exitCode = 1
            description: 'a half-succeeding manifest answered exit ',
                result exitCode printString, ': ',
                result lines printString.
        self assert: result lines = (Array with: (AuthoringFixtures
            anchorLineFor: (AuthoringFixtures manifestPathIn: work)
            line: AuthoringFixtures firstDefineRaisesLineNumber))
            description: 'it answered ', result lines printString
    ]

    "---- S15: the README ----"

    testS15_TheReadmeDocumentsTheConfigurationAndTheQuietChild [
        "A STATED BEHAVIOUR THAT IS NOT WRITTEN WHERE USERS READ IS NOT
         STATED (§8 decision 45's standard). The file, where it lives,
         its schema tag, the flag-wins rule and the flag that quietened
         exec.

         ## INSTALLING IS EXTENDED, NOT REWRITTEN: the settled Sprint 17
         markers must still be there, and the section must still appear
         exactly once — a rewrite that produced a second heading would
         satisfy a containment law and confuse every reader."
        | readme |
        readme := PublishLayoutFixtures readmeSource.
        ConfigFixtures readmeMarkers do: [:row |
            self assert: (CommandLineFixtures does: readme
                include: (row at: 2))
                description: 'the README does not document ', (row at: 1)].
        PathFixtures installationDocumentationMarkers do: [:marker |
            self assert: (CommandLineFixtures does: readme include: marker)
                description: 'the README dropped the settled installation marker: ',
                    marker printString].
        self assert: (ConfigFixtures occurrencesOf: '## Installing'
            in: readme) = 1
            description: 'the README declares the Installing section ',
                (ConfigFixtures occurrencesOf: '## Installing' in: readme)
                    printString, ' times'
    ]
]

Namespace current: Smalltalk.
