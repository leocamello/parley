"Parley Sprint 17 — acceptance scenarios S1-S20 plus S14a (issue #19).

 THE SPRINT THAT MAKES THE TOOL STOP BLAMING ITSELF FOR THE OPERATOR'S
 FILESYSTEM. Sprint 16 ruled §8 decision 56 as a general rule — a
 boundary that reads a file begins by requiring that path to be a
 regular readable file — and applied it to three boundaries. Its
 close-out probed the rest of the domain through the shipped binary and
 found SIX ordinary states still answering
 internal error: … - this is a defect in Parley, not in your project
 at exit 70, three of them naming no path at all. A SEVENTH was probed
 at the Gate C amendment and is worse: the canonical installation — a
 symlink from a directory on PATH — printed gst's own message and
 exited 0, a total failure reported as success on the first command a
 new user runs.

 FIVE OF THE SIX ARE THE RULE'S MIRROR. Decision 56 governs reading;
 nothing in the tool governed writing. A read-only checkout, a
 root-owned file and a chmod -R a-w cache are OPERATOR states, and exit
 70's sentence is a false attribution of blame in every one of them.

 AND THE DEEPER REASON THIS IS A SPRINT RATHER THAN SEVEN PATCHES.
 ManifestFile said missing or unreadable Package.st from Sprint 8 while
 its predicate tested exists alone — eight sprints of a right sentence
 over a missing predicate, invisible because reviewers read the
 sentence and nothing in this repository could compare a sentence
 against a check. So the deliverable is ONE chokepoint and ONE declared
 boundary table with laws over it (S12, S13, S15), which is what stops
 the eighth boundary from arriving in the same blind spot.

 DECLARED PASSES IN RED (issue #19) — six, each a SETTLED-BEHAVIOUR
 GUARD that passes today and must keep passing, never a new claim:
   testS3_AWritableLockStillResolves — the precheck must not become a
     gate on the path it exists to protect.
   testS4_AnAbsentLockInAWritableDirectoryStillResolves — isWriteable
     answers false for an absent path exactly as it does for a
     read-only one, so the naive one-predicate check turns every FIRST
     resolve into a permissions error. The guard the obvious
     implementation breaks first, and the direct descendant of Sprint
     16's absent-lock law.
   testS6_AddOnAWritableManifestStillEditsAndResolves — the same guard
     on the manifest write.
   testS9_PublishIntoAWritableDestinationStillWritesBothArtifacts — the
     same guard on the publish destination, through the real toolchain.
   testS16_TheSettledExitSeventyBoundaryStillExists — exit 70 is NOT
     being deleted; it is being made unreachable by FILESYSTEM STATES,
     which is a different claim. The guard against implementing S14 as
     remove the branch.
   testS20_TheWrapperStillRunsWhenInvokedDirectly — the guard against
     implementing S18 as compute harder and breaking the ordinary path.
 Every other scenario here fails against the pre-sprint tree.

 COST, DECLARED: every scenario runs in-image against tmp/ fixtures
 with in-image chmod (File>>mode: is a real chmod on 3.2.5, so no
 process is spawned to build a hostile state) EXCEPT: S9 runs the real
 toolchain (gst-package builds the archive); S14 spawns the shipped
 binary once per probed state, six children; and S18-S20 spawn the
 wrapper, four children between them. No scenario contacts a network
 and none runs git. S12 is the expensive one and deliberately so: each
 of the twelve rows is driven TWICE — once under its own direction's
 hostile state and once under the mirror — for twenty-four in-image
 verb runs over twenty-four fixture trees.

 TEARDOWN IS THE ONE THING TO GET RIGHT BEFORE ANYTHING ELSE. A
 read-only fixture DIRECTORY survives the settled recursive remover —
 on POSIX the permission to unlink an entry belongs to the containing
 directory — so it stays on disk, the next run's directoryNamed: finds
 it, and failures appear in suites this sprint never touched. This bit
 the Sprint 16 close-out probe. Every teardown here goes through
 PathFixtures removeTree:, which unlocks the tree first."

Namespace current: Parley.

TestCase subclass: Sprint17AcceptanceTest [
    | fixtureDirs captureDir |

    <comment: 'The Sprint 17 acceptance scenarios: the write-side
refusals with their no-partial-write assertions and their
must-still-work guards, the two read boundaries decision 56 did not
reach, the boundary table driven through both hostile states, the
prohibition on direct File I/O outside PathGuard, the structural
diagnosis guarantee, the six probed states through the shipped binary,
the exit-70 boundary held in place, the README, and the wrapper''s
location contract.'>

    setUp [
        fixtureDirs := OrderedCollection new.
        captureDir := nil
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

    workDir: aLabel [
        ^self track: (CommandLineFixtures diamondRootWorkDirNamed: aLabel)
    ]

    diamondIndex: aLabel [
        "The settled diamond index WITH its archives — the pairing
         CliTest has used since Sprint 6, and the one whose resolution
         is ExecFixtures diamondLockString. add and install both run
         the full pipeline, so an archive-less index answers a fetch
         refusal these scenarios must never be able to confuse with
         their own."
        | path |
        path := self freshDir: aLabel.
        InstallFixtures populateInstallDiamondIn: path.
        ^path
    ]

    resultOf: anArgvArray in: aWorkDir [
        ^self resultOf: anArgvArray in: aWorkDir runner: RecordingRunner new
    ]

    resultOf: anArgvArray in: aWorkDir runner: aRunner [
        ^(CommandLine in: aWorkDir runner: aRunner) run: anArgvArray
    ]

    resolveArgvOn: anIndexDir [
        ^Array with: 'resolve' with: '--source' with: anIndexDir
    ]

    exists: aPath [
        ^PathFixtures exists: aPath
    ]

    contentsOf: aPath [
        ^PathFixtures contentsOf: aPath
    ]

    denyBlamesParley: aResult [
        "No diagnosis this sprint answers blames Parley, dumps a
         backtrace, or puts a kernel class name on the operator's
         screen. The last is not hypothetical: three of the six probed
         states printed a kernel FileError and named no path at all."
        self deny: aResult exitCode = 70
            description: 'the command answered exit 70: ',
                aResult lines printString.
        aResult lines do: [:line |
            self deny: (CommandLineFixtures does: line
                include: LockBoundaryFixtures undiagnosedLinePrefix)
                description: 'the diagnosis blames Parley: ', line.
            self deny: (CommandLineFixtures does: line
                include: ReadinessFixtures kernelErrorMarker)
                description: 'the diagnosis names a kernel error: ', line.
            CommandLineFixtures backtraceMarkers do: [:marker |
                self deny: (CommandLineFixtures does: line include: marker)
                    description: 'the diagnosis dumped a backtrace: ', line]]
    ]

    assertOneLine: aResult is: aLine [
        self assert: aResult exitCode = 1
            description: 'the refusal answered exit ',
                aResult exitCode printString, ': ',
                aResult lines printString.
        self assert: aResult lines = (Array with: aLine)
            description: 'the refusal answered ', aResult lines printString.
        self denyBlamesParley: aResult
    ]

    captures [
        "A writable directory for child-output captures, kept OUTSIDE
         the fixture working directories because two of the probed
         states make the working directory read-only and a shell
         redirect into one of those would fail before the child ran."
        captureDir isNil ifTrue: [
            captureDir := self freshDir: 's17-captures'].
        ^captureDir
    ]

    shippedOutputIn: aWorkDir args: anArgsString labelled: aLabel [
        "Run the SHIPPED binary and answer {exit code. output lines}.
         The child writes to a capture file the test owns."
        | outPath code |
        outPath := (CommandLineFixtures absolutePathOf: self captures),
            '/', aLabel, '.txt'.
        code := ProcessRunner new run: (CommandLineFixtures
            shippedBinaryCommandIn: aWorkDir
            args: anArgsString
            outputTo: outPath).
        ^Array with: code
            with: (ExecFixtures linesOf: (self contentsOf:
                self captures, '/', aLabel, '.txt'))
    ]

    absolute: aPath [
        ^CommandLineFixtures absolutePathOf: aPath
    ]

    "---- S1: resolve refuses a read-only parley.lock ----"

    testS1_ResolveRefusesAReadOnlyLock [
        "Today: exit 70, FileError: could not open <path>, blaming
         Parley for a file the operator made read-only. The lock's
         BYTES are asserted unchanged, not merely its presence: a
         refusal that truncated the file first would answer the same
         line and the same code."
        | work index lock before result |
        work := self workDir: 's17-s1-work'.
        index := self diamondIndex: 's17-s1-index'.
        SourceFixtures write: ExecFixtures diamondLockString
            toFile: 'parley.lock' in: work.
        lock := PathFixtures lockPathIn: work.
        before := self contentsOf: lock.
        PathFixtures makeReadOnly: lock.
        result := self resultOf: (self resolveArgvOn: index) in: work.
        self assertOneLine: result is: (PathFixtures unwritableLineFor: lock).
        self assert: (self contentsOf: lock) = before
            description: 'the refused resolve changed the lock bytes'
    ]

    "---- S2: resolve refuses an unwritable project directory ----"

    testS2_ResolveRefusesAnUnwritableProjectDirectoryWithNoLock [
        "THE CREATE PREDICATE, not the overwrite one: there is no lock
         to overwrite, and the path that fails is the DIRECTORY the lock
         would be created in. Today: exit 70, FileError: Permission
         denied, naming nothing at all — which is worse than the state
         decision 56 was ruled to fix, because the operator cannot even
         tell which directory the tool means."
        | work index result |
        work := self workDir: 's17-s2-work'.
        index := self diamondIndex: 's17-s2-index'.
        self deny: (self exists: (PathFixtures lockPathIn: work))
            description: 'the fixture already has a lock - the scenario would be the overwrite case'.
        PathFixtures makeReadOnly: work.
        result := self resultOf: (self resolveArgvOn: index) in: work.
        self assertOneLine: result is: (PathFixtures unwritableLineFor: work).
        PathFixtures unlock: work.
        self deny: (self exists: (PathFixtures lockPathIn: work))
            description: 'the refused resolve created a lock'
    ]

    "---- S3: a writable lock still resolves ----"

    testS3_AWritableLockStillResolves [
        "DECLARED PASS IN RED (issue #19) — the settled behaviour, and
         the guard that stops the precheck from becoming a gate on the
         ordinary path it exists to protect."
        | work index result |
        work := self workDir: 's17-s3-work'.
        index := self diamondIndex: 's17-s3-index'.
        SourceFixtures write: ExecFixtures diamondLockString
            toFile: 'parley.lock' in: work.
        result := self resultOf: (self resolveArgvOn: index) in: work.
        self assert: result exitCode = 0
            description: 'resolve over a writable lock answered exit ',
                result exitCode printString, ': ',
                result lines printString.
        self assert: (self contentsOf: (PathFixtures lockPathIn: work))
            = ExecFixtures diamondLockString
            description: 'the byte-stable lock moved'
    ]

    "---- S4: an absent lock in a writable directory still resolves ----"

    testS4_AnAbsentLockInAWritableDirectoryStillResolves [
        "DECLARED PASS IN RED (issue #19), AND THE GUARD THE OBVIOUS
         IMPLEMENTATION BREAKS FIRST. Probed on 3.2.5: isWriteable
         answers FALSE for a path that does not exist, exactly as it
         does for a read-only one — the Sprint 16 isFile trap one
         predicate over. A write check written as one send on the lock
         itself refuses every first resolve a project ever makes, which
         is the single most common command in the tool."
        | work index result |
        work := self workDir: 's17-s4-work'.
        index := self diamondIndex: 's17-s4-index'.
        self deny: (self exists: (PathFixtures lockPathIn: work))
            description: 'the fixture already has a lock - the scenario would be vacuous'.
        result := self resultOf: (self resolveArgvOn: index) in: work.
        self assert: result exitCode = 0
            description: 'the first resolve answered exit ',
                result exitCode printString, ': ',
                result lines printString.
        self assert: (self contentsOf: (PathFixtures lockPathIn: work))
            = ExecFixtures diamondLockString
            description: 'the first resolve did not write the byte-stable lock'
    ]

    "---- S5: add refuses a read-only Package.st, and writes nothing ----"

    testS5_AddRefusesAReadOnlyManifestAndWritesNothing [
        "THE REFUSAL IS ASSERTED ON THE ARTIFACT, NOT ON THE EXIT CODE.
         add is atomic across the manifest and the lock (Doc B §2.1), so
         an implementation that edited the manifest, failed, and put it
         back would answer this same line and this same code — and would
         still have to leave parley.lock byte-identical, which is what
         this scenario checks."
        | work index manifest lockBefore manifestBefore result |
        work := self workDir: 's17-s5-work'.
        index := self diamondIndex: 's17-s5-index'.
        SourceFixtures write: ExecFixtures diamondLockString
            toFile: 'parley.lock' in: work.
        manifest := PathFixtures packagePathIn: work.
        manifestBefore := self contentsOf: manifest.
        lockBefore := self contentsOf: (PathFixtures lockPathIn: work).
        PathFixtures makeReadOnly: manifest.
        result := self resultOf: (Array with: 'add' with: 'c'
            with: '^2.0' with: '--source' with: index) in: work.
        self assertOneLine: result
            is: (PathFixtures unwritableLineFor: manifest).
        self assert: (self contentsOf: (PathFixtures lockPathIn: work))
            = lockBefore
            description: 'the refused add moved parley.lock'.
        self assert: (self contentsOf: manifest) = manifestBefore
            description: 'the refused add changed Package.st'
    ]

    "---- S6: add on a writable manifest still edits and resolves ----"

    testS6_AddOnAWritableManifestStillEditsAndResolves [
        "DECLARED PASS IN RED (issue #19) — the settled Sprint 13 verb,
         unchanged. What add does when the path is fine must not change
         by one byte."
        | work index result manifest |
        work := self workDir: 's17-s6-work'.
        index := self diamondIndex: 's17-s6-index'.
        result := self resultOf: (Array with: 'add' with: 'c'
            with: '^2.0' with: '--source' with: index) in: work.
        self assert: result exitCode = 0
            description: 'add answered exit ', result exitCode printString,
                ': ', result lines printString.
        manifest := self contentsOf: (PathFixtures packagePathIn: work).
        self assert: (CommandLineFixtures does: manifest
            include: 'dependency: ''c'' constraint: ''^2.0''')
            description: 'add did not declare the dependency: ', manifest.
        self assert: (self exists: (PathFixtures lockPathIn: work))
            description: 'add wrote no lock'
    ]

    "---- S7: init refuses an unwritable directory ----"

    testS7_InitRefusesAnUnwritableDirectory [
        "Today: exit 70, Permission denied, naming nothing. A command
         that refuses to run leaves the filesystem exactly as it found
         it (§8 decision 57's second half), so BOTH artifacts are
         asserted absent — the manifest init would have written, and the
         .parley/ state the wiring creates before any verb runs."
        | work result |
        work := self freshDir: 's17-s7-work'.
        PathFixtures makeReadOnly: work.
        result := self resultOf: #('init') in: work.
        self assertOneLine: result is: (PathFixtures unwritableLineFor: work).
        PathFixtures unlock: work.
        self deny: (self exists: (PathFixtures packagePathIn: work))
            description: 'the refused init wrote a Package.st'.
        self deny: (self exists: (PathFixtures parleyDirIn: work))
            description: 'the refused init created .parley/'
    ]

    "---- S8: publish refuses an unwritable destination ----"

    testS8_PublishRefusesAnUnwritableDestinationCreatingNothing [
        "Doc F §1's fail-stop, which until now never got the chance to
         apply: the destination check ran BEFORE the stage was created,
         and then the write blew up with a kernel FileError naming
         nothing. The assertion is on the DESTINATION, not on the exit
         code — an implementation that created the stage and then failed
         answers the same line and the same code and must still fail
         here."
        | work dest result |
        work := self freshDir: 's17-s8-work'.
        PublishFixtures populateGreetingWorkDirIn: work.
        dest := self freshDir: 's17-s8-dest'.
        PathFixtures makeReadOnly: dest.
        result := self resultOf: (Array with: 'publish' with: dest)
            in: work.
        self assertOneLine: result is: (PathFixtures unwritableLineFor: dest).
        PathFixtures unlock: dest.
        self assert: (PublishFixtures fileNamesIn: dest) = #()
            description: 'the refused publish left ',
                (PublishFixtures fileNamesIn: dest) printString,
                ' in the destination'
    ]

    "---- S9: publish into a writable destination still works ----"

    testS9_PublishIntoAWritableDestinationStillWritesBothArtifacts [
        "DECLARED PASS IN RED (issue #19) — the settled Sprint 7
         pipeline through the real toolchain, unchanged. The precheck
         must refuse a destination it cannot write and get out of the
         way of one it can."
        | work dest result digest |
        work := self freshDir: 's17-s9-work'.
        PublishFixtures populateGreetingWorkDirIn: work.
        dest := self freshDir: 's17-s9-dest'.
        result := self resultOf: (Array with: 'publish' with: dest)
            in: work runner: ProcessRunner new.
        self assert: result exitCode = 0
            description: 'publish answered exit ',
                result exitCode printString, ': ',
                result lines printString.
        self assert: (PublishFixtures fileNamesIn: dest)
            = (Array
                with: PublishFixtures entryFileName
                with: PublishFixtures archiveFileName)
            description: 'publish landed ',
                (PublishFixtures fileNamesIn: dest) printString.
        digest := Sha256 hexDigestOf: (self contentsOf:
            dest, '/', PublishFixtures archiveFileName).
        self assert: (self contentsOf:
            dest, '/', PublishFixtures entryFileName)
            = (PublishFixtures greetingEntryWithDigest: digest)
            description: 'the landed entry is not the byte oracle'
    ]

    "---- S10: an unreadable index entry answers the declared error ----"

    testS10_AnUnreadableIndexEntryAnswersTheDeclaredSourceError [
        "Decision 56's OWN domain, unapplied for a sprint: the scan
         validates what every entry SAYS and presumed the bytes could be
         obtained. An entry the reader lacks permission to open EXISTS,
         so the scan waved it through and died in File>>contents."
        | work index result |
        work := self workDir: 's17-s10-work'.
        index := self diamondIndex: 's17-s10-index'.
        PathFixtures makeUnreadable: index, '/c-2.4.0.st'.
        result := self resultOf: (self resolveArgvOn: index) in: work.
        self assert: result exitCode = 1
            description: 'the unreadable entry answered exit ',
                result exitCode printString, ': ',
                result lines printString.
        self assert: (result lines includes:
            (PathFixtures unreadableEntryProblemFor: 'c-2.4.0.st'))
            description: 'the scan answered ', result lines printString.
        self denyBlamesParley: result
    ]

    "---- S11: an unreadable .star answers the declared archive error ----"

    testS11_AnUnreadableArchiveAnswersTheDeclaredArchiveError [
        "The sentence DirectorySource already carries — missing or
         unreadable archive file — finally gets the predicate behind it.
         Sprint 8's ManifestFile defect, in a second place: a right
         sentence over a check that only tested existence."
        | work index result |
        work := self workDir: 's17-s11-work'.
        index := self diamondIndex: 's17-s11-index'.
        PathFixtures makeUnreadable: index, '/a-1.0.0.star'.
        result := self resultOf:
            (Array with: 'install' with: '--source' with: index)
            in: work.
        self assert: result exitCode = 1
            description: 'the unreadable archive answered exit ',
                result exitCode printString, ': ',
                result lines printString.
        self assert: (result lines includes:
            (PathFixtures unreadableArchiveProblemFor: 'a-1.0.0.star'))
            description: 'install answered ', result lines printString.
        self denyBlamesParley: result
    ]

    "---- S12: every declared row answers its own error ----"

    testS12_EveryDeclaredBoundaryRowAnswersItsOwnErrorUnderAHostileState [
        "THE LAW THAT MAKES THE TABLE REAL RATHER THAN DOCUMENTATION.
         Every row of CommandLine class >> pathBoundaries is driven
         twice: through the hostile state its DIRECTION defines, and
         through the MIRROR of that state.

         THE TWO DRIVES CARRY DIFFERENT CLAIMS, and the difference is
         the point rather than a weakening. Under its own direction —
         an unreadable path for a read row, an unwritable one for a
         write row — the row must answer a diagnosis at exit 1 naming
         its own path. Under the MIRROR state it must answer only that
         it never blames Parley: a read row over a readable-but-
         read-only file is not refused at all, and asserting exit 1
         there would assert a bug.

         NEVER-70 UNDER THE MIRROR IS NOT A NICETY. It is the sprint's
         exit criterion — no operator filesystem state answers the
         wrong exit code ANYWHERE — checked where an unrouted site is
         most likely to survive: resolve reads Package.st and then
         WRITES parley.lock, so a read row whose read boundary is
         satisfied still has to cross its write boundary, and no
         single-direction driver exercises that crossing.

         Both driver sets are held to the declared table, so a mirror
         driver cannot drift from it either."
        | drivers mirrors |
        drivers := (PathFixtures readRowDriversTracking:
                [:path | self track: path]),
            (PathFixtures writeRowDriversTracking:
                [:path | self track: path]).
        mirrors := (PathFixtures readRowMirrorDriversTracking:
                [:path | self track: path]),
            (PathFixtures writeRowMirrorDriversTracking:
                [:path | self track: path]).
        self assert: (self rolesOf: drivers)
            = (PathFixtures namesOfBoundaryRolesIn: CommandLine pathBoundaries)
            description: 'the drivers and the declared table disagree: ',
                (self rolesOf: drivers) printString.
        self assert: (self rolesOf: mirrors)
            = (PathFixtures namesOfBoundaryRolesIn: CommandLine pathBoundaries)
            description: 'the mirror drivers and the declared table disagree: ',
                (self rolesOf: mirrors) printString.
        drivers do: [:row |
            | result |
            result := (row at: 3) value.
            self assert: result exitCode = 1
                description: (row at: 1), ' answered exit ',
                    result exitCode printString, ': ',
                    result lines printString.
            self assert: (result lines anySatisfy: [:line |
                CommandLineFixtures does: line include: (row at: 2)])
                description: (row at: 1), ' never named ', (row at: 2),
                    ': ', result lines printString.
            self denyBlamesParley: result].
        mirrors do: [:row |
            | result |
            result := (row at: 3) value.
            self deny: result isNil
                description: (row at: 1),
                    ' answered nothing under its mirror state'.
            self denyBlamesParley: result]
    ]

    rolesOf: someDrivers [
        ^((someDrivers collect: [:row | row at: 1])
            asSortedCollection: [:a :b | a <= b]) asArray
    ]

    "---- S13: the table has no unlisted boundaries ----"

    testS13_TheTableHasNoUnlistedBoundaries [
        "THE ROW-21 DRIFT LAW, written as a PROHIBITION rather than an
         enumeration: nothing outside PathGuard performs direct File
         I/O, with the Gate C census as the exemption list (§8 decision
         60). Narrowing it to no I/O outside PathGuard AT A DECLARED
         BOUNDARY ROW is the disqualified implementation — it would
         still pass, and it would restore the enumeration this sprint
         exists to abolish.

         THE BOUND IS STATED HERE, not implied (decision 43's standard):
         the search is TEXTUAL over comment-stripped,
         whitespace-normalized source, because 3.2.5 offers no
         reflective alternative; and naming eight exempt classes makes
         the live claim that a NINTH never starts doing direct File I/O.

         The non-empty guard is asserted first. A comparison that
         enumerates nothing passes while proving nothing, which is the
         Sprint 8 src/ drift-law lesson and the one failure mode that
         would make every law in this sprint decorative."
        | offenders |
        self deny: PathFixtures ioSiteClassNames isEmpty
            description: 'the src/ walk found no direct File I/O at all — File>>files does not recurse; the walk must use namesDo:'.
        self assert: (PathFixtures ioSiteClassNames
            includes: PathFixtures guardClassName)
            description: 'the walk cannot see the chokepoint itself, which is the one class that MUST do file I/O'.
        offenders := PathFixtures
            classesDoingIoIn: PathFixtures ioSiteClassNames
            outside: PathFixtures ioCensusClassNames.
        self assert: offenders isEmpty
            description: offenders printString,
                ' perform direct File I/O in src/ but are neither PathGuard nor declared in the §8 decision 60 census'
    ]

    "---- S14a: an unenumerated failure still answers a good diagnosis ----"

    testS14a_AnUnenumeratedFailureStillAnswersTheBoundarysOwnError [
        "THE LAW THAT MAKES THE RULE TOTAL RATHER THAN ENUMERATED, and
         the one that proves the TOCTOU window cannot produce a bad
         diagnosis. The driver is deliberately NOT one of the six probed
         states and NOT a FileError: an archive path that is a
         DIRECTORY passes File>>exists, and File>>contents on a
         directory raises a kernel SystemExceptions.WrongClass which
         walks straight past a handler written for FileError.

         Parley makes no claim about the racing window itself — the
         guard is a precheck, not a lock (Doc E §4.1). What it does
         claim is exactly this: if the window is hit, or if any other
         unforeseen mode fails, the caller still receives the boundary's
         own error naming the path at exit 1, and never the sentence
         that says the tool is broken."
        | work index result |
        work := self workDir: 's17-s14a-work'.
        index := self diamondIndex: 's17-s14a-index'.
        (File name: index, '/a-1.0.0.star') remove.
        Directory create: index, '/a-1.0.0.star'.
        result := self resultOf:
            (Array with: 'install' with: '--source' with: index)
            in: work.
        self assert: result exitCode = 1
            description: 'a directory-shaped archive answered exit ',
                result exitCode printString, ': ',
                result lines printString.
        self assert: (result lines anySatisfy: [:line |
            CommandLineFixtures does: line include: 'a-1.0.0.star'])
            description: 'the diagnosis never named the archive: ',
                result lines printString.
        self denyBlamesParley: result
    ]

    "---- S14: no operator filesystem state answers exit 70 ----"

    testS14_NoOperatorFilesystemStateAnswersExitSeventy [
        "THE REGRESSION GUARD FOR THE WHOLE CLASS: the six states from
         the Sprint 16 close-out probe, run as one law through the
         SHIPPED BINARY — which is how they were probed, and the only
         level at which the exit code the operator's shell sees is the
         thing under test.

         Each state asserts exit 1, a named path, and no
         internal error: prefix. Together they are the sentence this
         sprint exists to make true: no ordinary operator filesystem
         state tells the user their tool is broken."
        | states |
        states := self probedStates.
        self assert: states size = 6
            description: 'the probe set is ', states size printString,
                ' states, not the six the close-out found'.
        states do: [:state |
            | answer |
            answer := self shippedOutputIn: (state at: 2)
                args: (state at: 3)
                labelled: (state at: 1).
            self assert: (answer at: 1) = 1
                description: (state at: 1), ' answered exit ',
                    (answer at: 1) printString, ': ',
                    (answer at: 2) printString.
            self assert: ((answer at: 2) anySatisfy: [:line |
                CommandLineFixtures does: line include: (state at: 4)])
                description: (state at: 1), ' never named ',
                    (state at: 4), ': ', (answer at: 2) printString.
            (answer at: 2) do: [:line |
                self deny: (CommandLineFixtures does: line
                    include: LockBoundaryFixtures undiagnosedLinePrefix)
                    description: (state at: 1), ' blamed Parley: ', line]]
    ]

    probedStates [
        "The six states of the close-out probe, each as
         {label. work dir. argv string. the path its diagnosis must
         name}. Every path handed to the child is absolute, because the
         child's cwd is the fixture working directory."
        | lockWork lockIndex dirWork dirIndex addWork addIndex initWork pubWork pubDest entryWork entryIndex |
        lockWork := self workDir: 's17-s14-lock-work'.
        lockIndex := self diamondIndex: 's17-s14-lock-index'.
        SourceFixtures write: ExecFixtures diamondLockString
            toFile: 'parley.lock' in: lockWork.
        PathFixtures makeReadOnly: (PathFixtures lockPathIn: lockWork).

        dirWork := self workDir: 's17-s14-dir-work'.
        dirIndex := self diamondIndex: 's17-s14-dir-index'.
        PathFixtures makeReadOnly: dirWork.

        addWork := self workDir: 's17-s14-add-work'.
        addIndex := self diamondIndex: 's17-s14-add-index'.
        PathFixtures makeReadOnly: (PathFixtures packagePathIn: addWork).

        initWork := self freshDir: 's17-s14-init-work'.
        PathFixtures makeReadOnly: initWork.

        pubWork := self freshDir: 's17-s14-pub-work'.
        PublishFixtures populateGreetingWorkDirIn: pubWork.
        pubDest := self freshDir: 's17-s14-pub-dest'.
        PathFixtures makeReadOnly: pubDest.

        entryWork := self workDir: 's17-s14-entry-work'.
        entryIndex := self diamondIndex: 's17-s14-entry-index'.
        PathFixtures makeUnreadable: entryIndex, '/c-2.4.0.st'.

        ^(Array
            with: (Array with: 'readonly-lock' with: lockWork
                with: 'resolve --source ', (self absolute: lockIndex)
                with: (self absolute: (PathFixtures lockPathIn: lockWork)))
            with: (Array with: 'readonly-directory' with: dirWork
                with: 'resolve --source ', (self absolute: dirIndex)
                with: (self absolute: dirWork))
            with: (Array with: 'readonly-manifest' with: addWork
                with: 'add c ^2.0 --source ', (self absolute: addIndex)
                with: (self absolute: (PathFixtures packagePathIn: addWork)))
            with: (Array with: 'readonly-init' with: initWork
                with: 'init'
                with: (self absolute: initWork))),
            (Array
                with: (Array with: 'readonly-destination' with: pubWork
                    with: 'publish ', (self absolute: pubDest)
                    with: (self absolute: pubDest))
                with: (Array with: 'unreadable-entry' with: entryWork
                    with: 'resolve --source ', (self absolute: entryIndex)
                    with: 'c-2.4.0.st'))
    ]

    "---- S15: every diagnosis names a path, a cause and a remedy ----"

    testS15_EveryDiagnosisNamesAPathACauseAndACheckedRemedy [
        "§8 decision 58's standard asserted STRUCTURALLY rather than
         sentence by sentence — what makes a first user's refusal
         legible instead of merely correct.

         THE REMEDY HALF IS SCOPED, AND THE SCOPE IS THE POINT. Every
         WRITE refusal is a state the operator owns and can repair, so
         every write row owes a remedy. The read rows that report on
         somebody ELSE's index — an unreadable entry, an unreadable
         archive — owe none, and inventing one for them would be the
         very defect decision 58 rules against: a diagnosis that names a
         cause has made a claim, and a tool may only make claims it has
         checked."
        | reads writes |
        reads := self firstLinesOf: (PathFixtures readRowDriversTracking:
            [:path | self track: path]).
        writes := self firstLinesOf: (PathFixtures writeRowDriversTracking:
            [:path | self track: path]).
        self deny: reads isEmpty
            description: 'no read row produced a diagnosis to check'.
        self deny: writes isEmpty
            description: 'no write row produced a diagnosis to check'.
        reads, writes do: [:triple |
            self assert: ((PathFixtures pathPartOf: (triple at: 3))
                startsWith: (triple at: 2))
                description: (triple at: 1), ' opens with ',
                    (PathFixtures pathPartOf: (triple at: 3)) printString,
                    ' rather than the path it is about: ', (triple at: 3).
            self deny: (PathFixtures causePartOf: (triple at: 3)) isEmpty
                description: (triple at: 1), ' states no cause: ',
                    (triple at: 3)].
        writes do: [:triple |
            self deny: (PathFixtures remedyPartOf: (triple at: 3)) isEmpty
                description: (triple at: 1), ' offers no remedy: ',
                    (triple at: 3)]
    ]

    firstLinesOf: someDrivers [
        "Private — for each driver, {role. its path. the first answered
         line naming that path}. The batching rows answer several
         problems; the one about THIS path is the one the structure law
         is about.

         The path travels with the line because the law asserts the line
         OPENS with it, not merely that it has some path part: the
         pre-sprint exit-70 sentence
         internal error: FileError: could not open <path> - … contains
         the path, has a colon and has a dash, so a structural law that
         only counted parts would pass over exactly the diagnosis this
         sprint exists to abolish."
        | pairs |
        pairs := OrderedCollection new.
        someDrivers do: [:row |
            | named |
            named := (row at: 3) value lines
                detect: [:line | CommandLineFixtures does: line
                    include: (row at: 2)]
                ifNone: [nil].
            named isNil ifFalse: [
                pairs add: (Array
                    with: (row at: 1) with: (row at: 2) with: named)]].
        ^pairs asArray
    ]

    "---- S16: the settled exit-70 boundary still exists ----"

    testS16_TheSettledExitSeventyBoundaryStillExists [
        "DECLARED PASS IN RED (issue #19). Exit 70 is NOT being deleted.
         It is being made unreachable BY FILESYSTEM STATES, which is a
         different claim, and this is the guard against implementing
         S14 as remove the branch. A non-declared error injected at the
         process seam must still answer exit 70, one line, the settled
         prefix, and no backtrace."
        | work result |
        work := self freshDir: 's17-s16-work'.
        ExecFixtures writePackage: ExecFixtures noDependencyRootContents
            in: work.
        SourceFixtures write: 'ObjectMemory quit: 0'
            toFile: 'run.st' in: work.
        result := self resultOf:
            (Array with: 'exec' with: work, '/run.st')
            in: work
            runner: (RaisingRunner raising:
                [Error new signal: CommandLineFixtures plainErrorMessage]).
        self assert: result exitCode = 70
            description: 'an undiagnosed error answered exit ',
                result exitCode printString.
        self assert: result lines
            = (Array with: CommandLineFixtures plainErrorLine)
            description: 'the boundary answered ', result lines printString.
        CommandLineFixtures backtraceMarkers do: [:marker |
            self deny: (CommandLineFixtures does: (result lines at: 1)
                include: marker)
                description: 'the boundary dumped a backtrace']
    ]

    "---- S17: the README describes the tool that exists ----"

    testS17_TheReadmeDescribesTheToolThatExists [
        "The settled Sprint 15 verb drift law still passes — every verb
         the CLI's OWN usage line declares appears in the README, read
         live from the running tool — and the two new subjects are
         documented: the permission diagnostics, and the installation
         route, which was pointless to document while it was broken."
        | verbs readme undocumented |
        verbs := PublishLayoutFixtures verbsIn:
            ((self resultOf: #() in: (self freshDir: 's17-s17-work')
                runner: TrapRunner new) lines at: 2).
        self deny: verbs isEmpty
            description: 'no verbs were extracted - the scenario would be vacuous'.
        readme := PublishLayoutFixtures readmeSource.
        undocumented := verbs reject: [:verb |
            CommandLineFixtures does: readme include: 'parley ', verb].
        self assert: undocumented isEmpty
            description: undocumented printString,
                ' are verbs the CLI offers and the README does not name'.
        PathFixtures permissionDocumentationMarkers do: [:marker |
            self assert: (CommandLineFixtures does: readme include: marker)
                description: 'the README does not document the permission diagnostics: ',
                    marker printString].
        PathFixtures installationDocumentationMarkers do: [:marker |
            self assert: (CommandLineFixtures does: readme include: marker)
                description: 'the README does not document the installation route: ',
                    marker printString]
    ]

    "---- S18: the shipped wrapper runs through a symlink ----"

    testS18_TheShippedWrapperRunsThroughASymlink [
        "THE CANONICAL INSTALLATION, WHICH DID NOT WORK AND SAID IT DID:
         bin/parley computed PARLEY_ROOT from dirname $0 without
         resolving symlinks, so a link from a directory on PATH pointed
         PARLEY_ROOT at the LINK's directory and gst printed
         Couldn't open file — at exit 0. A symlink to a symlink is
         asserted beside it because one hop is not a contract."
        | work bin direct chained |
        work := self freshDir: 's17-s18-work'.
        bin := self freshDir: 's17-s18-bin'.
        direct := PathFixtures symlinkAt: bin, '/parley'
            to: self absoluteWrapper.
        chained := PathFixtures symlinkAt: bin, '/parley-chained'
            to: (self absolute: direct).
        (Array with: direct with: chained) do: [:each |
            | answer |
            answer := self wrapperOutputAt: (self absolute: each)
                in: work labelled: 's18'.
            self assert: (answer at: 1) = 0
                description: 'the wrapper at ', each, ' answered exit ',
                    (answer at: 1) printString, ': ',
                    (answer at: 2) printString.
            self assert: (answer at: 2)
                = (Array with: CommandLine versionLine)
                description: 'the wrapper at ', each, ' printed ',
                    (answer at: 2) printString]
    ]

    "---- S19: a wrapper that cannot find its main script exits 70 ----"

    testS19_AWrapperThatCannotFindItsMainScriptExitsSeventyNamingIt [
        "70 and not 1: an installation missing its own main script is a
         defect in Parley, which is exactly what 70 means in the settled
         §4.2 taxonomy. The wrapper must CHECK rather than delegate,
         because gst -f <missing file> prints its own message and exits
         0 (probed, 3.2.5), so a wrapper that passed gst's status
         through would report every broken installation as a success.

         The Given also exercises the obligation that makes it
         constructible at all: a pre-set PARLEY_ROOT is HONOURED rather
         than overwritten."
        | work emptyRoot missing outPath code text |
        work := self freshDir: 's17-s19-work'.
        emptyRoot := self freshDir: 's17-s19-root'.
        missing := (self absolute: emptyRoot), '/',
            PathFixtures mainScriptRelativePath.
        outPath := (self absolute: self captures), '/s19.txt'.
        code := ProcessRunner new run: (PathFixtures
            wrapperCommandAt: self absoluteWrapper
            in: work
            args: '--version'
            root: (self absolute: emptyRoot)
            outputTo: outPath).
        text := self contentsOf: self captures, '/s19.txt'.
        self assert: code = PathFixtures wrapperExitCode
            description: 'a wrapper with no main script answered exit ',
                code printString, ': ', text.
        self assert: (ExecFixtures linesOf: text)
            = (Array with: (PathFixtures wrapperMissingScriptLineFor: missing))
            description: 'the wrapper printed ', text printString.
        self deny: (CommandLineFixtures does: text
            include: PathFixtures gstMissingFileMarker)
            description: 'gst spoke to the operator instead of the wrapper: ', text
    ]

    "---- S20: the wrapper still runs when invoked directly ----"

    testS20_TheWrapperStillRunsWhenInvokedDirectly [
        "DECLARED PASS IN RED (issue #19) — the guard against
         implementing S18 as compute harder and breaking the ordinary
         path. The wrapper invoked by a relative path from the checkout
         and by an absolute path must both keep working exactly as they
         do today."
        | work outPath commands |
        work := self freshDir: 's17-s20-work'.
        outPath := (self absolute: self captures), '/s20.txt'.
        commands := Array
            with: (PathFixtures relativeWrapperCommandWithArgs: '--version'
                outputTo: outPath)
            with: (PathFixtures wrapperCommandAt: self absoluteWrapper
                in: work args: '--version' outputTo: outPath).
        commands do: [:each |
            | code text |
            code := ProcessRunner new run: each.
            text := self contentsOf: self captures, '/s20.txt'.
            self assert: code = 0
                description: each, ' answered exit ', code printString,
                    ': ', text.
            self assert: (ExecFixtures linesOf: text)
                = (Array with: CommandLine versionLine)
                description: each, ' printed ', text printString]
    ]

    absoluteWrapper [
        ^CommandLineFixtures repoRoot, '/', PathFixtures wrapperPath
    ]

    wrapperOutputAt: aWrapperPath in: aWorkDir labelled: aLabel [
        "Private — run the wrapper at aWrapperPath and answer
         {exit code. output lines}."
        | outPath code |
        outPath := (self absolute: self captures), '/', aLabel, '.txt'.
        code := ProcessRunner new run: (PathFixtures
            wrapperCommandAt: aWrapperPath
            in: aWorkDir
            args: '--version'
            outputTo: outPath).
        ^Array with: code
            with: (ExecFixtures linesOf: (self contentsOf:
                self captures, '/', aLabel, '.txt'))
    ]
]

Namespace current: Smalltalk.
