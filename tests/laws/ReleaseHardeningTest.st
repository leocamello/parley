"Parley Sprint 15 — release hardening: parley --version, the README
 drift law, and §8 decision 52 cleared (issue #17; Doc E §4.1/§4.2).

 --version IS ONE DECLARED SPECIAL CASE, NOT A NEW GRAMMAR CLASS. The
 settled argv grammar reads --flag <value> pairs, and valueOf:in:
 deliberately treats a TRAILING flag as not a flag: it travels on to
 the settled CLI, which answers usage at exit 2. --version carries no
 value. Implementing it as a general 'valueless flags are grammar now'
 change would silently alter what every settled unknown-trailing-flag
 law is testing without touching one line of them — the law would keep
 passing and would no longer be about the same thing. So it is
 recognized once, ahead of verb dispatch, and the laws below hold the
 settled trailing-flag behaviour to exactly what it always answered.

 IT IS RECOGNIZED BEFORE THE STATE DIRECTORIES ARE CREATED. Asking a
 tool its version is not running a command in a project: it needs no
 working directory, and a .parley/ appearing because someone asked for
 a version number would be state created by a question.

 THE VERSION HAS EXACTLY ONE DEFINITION. The laws compare the printed
 line against Parley version rather than against a second literal —
 a version that can drift between the constant and the output drifts
 exactly when it matters, in a bug report.

 THE README IS GUARDED BY A LAW, NOT BY GOOD INTENTIONS. Its verb list
 is compared against the CLI's OWN usage verbs line, read live from the
 running tool, so a verb added without documentation fails the suite
 rather than quietly shipping undocumented. The §8 decision 45 consumer
 constraint is asserted with it: parley exec is a faithful pass-through
 of the child's exit code and is not a CI pass/fail signal without an
 explicit quit, and a README that dropped that sentence would document
 a promise the tool does not make.

 §8 DECISION 52, CLEARED AT ITS TRIGGER. CLI >> seedNames gathers the
 decision-51 seed set best-effort and is right to: resolve must ignore
 a corrupt lock (Doc E §4.1) and the missing-manifest sentence belongs
 to ManifestFile (decision 31). Both catches take Error, which also
 swallows what they never anticipated, and what a swallowed error
 leaves behind is not an exception but a silently PARTIAL SEED SET —
 under --index, decision 47's describability line turns that into a
 #noVersions conflict blaming the package. The rule, general beyond
 this site: a catch that exists to defer to another boundary names that
 boundary's errors and no others. The driver here is an operator state
 that really reaches it — a parley.lock that is a DIRECTORY, whose read
 raises a kernel error (probed against 3.2.5: SystemExceptions
 WrongClass) outside both declared boundaries. Two laws guard the
 narrowing from being an over-narrowing: a corrupt lock must still
 leave resolve at exit 0, and a missing Package.st must still answer
 the settled diagnosis.

 DECLARED PASSES IN RED (issue #17):
   testACorruptLockStillLeavesResolveAtExitZero and
   testAMissingManifestStillAnswersItsSettledDiagnosis — settled
     behaviour guards on the two catches being narrowed. They pass
     today and must keep passing; they exist to fail if the narrowing
     is done with too broad a hand, which is the one way this two-line
     change can go wrong.
   testTheReadmeCarriesTheExecConsumerConstraint — the README already
     carries §8 decision 45's sentence, and this law is what keeps it
     from being edited away.
   testATrailingVersionFlagOnAVerbIsStillUsage,
   testAnUnknownTrailingFlagIsStillUsage and
   testTheVersionFlagWithAnArgumentIsUsage — the settled trailing-flag
     grammar, which this sprint must leave exactly where it found it.
     They pass today and must keep passing; they are the laws that fail
     if --version is implemented as a general 'valueless flags are
     grammar now' change rather than as one declared special case.
     Named here because the prose above described them without listing
     them, and a guard that passes in red is only legitimate once it is
     DECLARED. (Operator amendment, Sprint 15 Gate A.)
 Every other law here fails against the pre-sprint tree: there is no
 version constant, --version is an unknown trailing flag, the README
 documents six of the ten verbs, and a seed-gathering failure is
 swallowed.

 Every fixture path is under tmp/, unique per test, removed recursively
 in tearDown; the laws that resolve run real curl against file:// trees
 and contact no network, ever."

Namespace current: Parley.

TestCase subclass: ReleaseHardeningTest [
    | fixtureDirs |

    <comment: 'Laws for parley --version as a declared special case
ahead of verb dispatch, the single definition of the version constant,
the README verb drift law with the exec consumer constraint, and the
decision-52 narrowing of seedNames with its two over-narrowing
guards.'>

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

    contentsOf: aPath [
        ^(File name: aPath) contents
    ]

    exists: aPath [
        ^(File name: aPath) exists
    ]

    runIn: aWorkDir argv: anArgvArray runner: aRunner [
        ^(CommandLine in: aWorkDir runner: aRunner) run: anArgvArray
    ]

    versionArgv [
        ^Array with: PublishLayoutFixtures versionFlag
    ]

    "---- parley --version (S12, S13) ----"

    testTheVersionFlagAnswersOneLineAtExitZeroWithoutSpawning [
        | result |
        result := self runIn: (self freshDir: 'version-plain')
            argv: self versionArgv
            runner: TrapRunner new.
        self assert: result exitCode = 0.
        self assert: result lines size = 1
            description: '--version answered ', result lines printString
    ]

    testTheVersionLineIsTheConstantAndNotASecondLiteral [
        "The single-definition rule that keeps a version from drifting
         the moment it matters: the assertion is built from
         Parley version itself."
        | result |
        result := self runIn: (self freshDir: 'version-constant')
            argv: self versionArgv
            runner: TrapRunner new.
        self assert: (result lines at: 1) = PublishLayoutFixtures versionLine.
        self assert: (CommandLineFixtures does: (result lines at: 1)
            include: Parley version)
            description: 'the printed line does not carry the constant'
    ]

    testTheVersionConstantIsAThreeComponentVersion [
        "It is the first thing every bug report needs, so it must be a
         version rather than a slogan: the settled parser is the
         authority, consumed and never re-implemented."
        self assert: (Version fromString: Parley version) printString
            = Parley version
    ]

    testTheVersionFlagCreatesNoStateDirectories [
        "Asking a tool its version is not running a command in a
         project. A .parley/ created by a question is state created by
         a question."
        | work |
        work := self freshDir: 'version-nostate'.
        self assert: (self runIn: work argv: self versionArgv
            runner: TrapRunner new) exitCode = 0.
        self deny: (self exists: (CommandLineFixtures parleyDirIn: work))
            description: '--version created the .parley state directory'
    ]

    testTheVersionFlagSurvivesTheLeadingMarker [
        "bin/parley execs gst -f <main> -- <argv>, so the argv really
         arrives with a leading marker. The special case is recognized
         after the settled strip and nowhere else."
        | result |
        result := self runIn: (self freshDir: 'version-marker')
            argv: (Array with: '--' with: PublishLayoutFixtures versionFlag)
            runner: TrapRunner new.
        self assert: result exitCode = 0.
        self assert: (result lines at: 1) = PublishLayoutFixtures versionLine
    ]

    "---- the settled trailing-flag grammar, unchanged (trap 2) ----"

    testATrailingVersionFlagOnAVerbIsStillUsage [
        "THE LAW THAT MAKES --version A SPECIAL CASE RATHER THAN A
         GRAMMAR: the settled valueOf:in: treats a trailing flag as not
         a flag, so it travels to the CLI, which answers usage. If
         valueless flags became grammar, this would keep passing and
         would silently be about something else — so it is asserted
         here, beside the feature that could have changed it."
        | result |
        result := self runIn: (self freshDir: 'version-trailing')
            argv: (Array with: 'resolve'
                with: PublishLayoutFixtures versionFlag)
            runner: TrapRunner new.
        self assert: result exitCode = 2
            description: 'resolve --version answered ',
                result exitCode printString
    ]

    testAnUnknownTrailingFlagIsStillUsage [
        "The settled behaviour for every OTHER valueless flag, asserted
         beside the one declared exception so the exception cannot
         quietly become the rule."
        self assert: (self runIn: (self freshDir: 'version-unknown')
            argv: (Array with: 'resolve' with: '--nonsense')
            runner: TrapRunner new) exitCode = 2
    ]

    testTheVersionFlagWithAnArgumentIsUsage [
        "One declared shape and one only: parley --version, alone.
         Anything else travels to the settled CLI as the unknown shape
         it is."
        self assert: (self runIn: (self freshDir: 'version-extra')
            argv: (Array with: PublishLayoutFixtures versionFlag
                with: 'extra')
            runner: TrapRunner new) exitCode = 2
    ]

    "---- the README drift law (S15) ----"

    usageVerbsLine [
        "The CLI's own verbs line, read LIVE from the running tool
         rather than from a pinned fixture: the README is compared
         against what the tool actually answers today.

         AMENDED AT SPRINT 20's RED (issue #22, §8 decision 79): it read
         `lines at: 2`, which stopped being the verbs row the moment a
         reason line arrived above the block. The failure would not have
         been loud in the useful way - indexOfSubstring: answers 0 when
         absent, so verbsIn: would have sliced the HEADER and split it
         on its three pipes, extracting `parley`, `--git` and `--index`
         as verbs and then reporting them as undocumented. The row is
         located by its own start instead."
        | result |
        result := self runIn: (self freshDir: 'readme-usage')
            argv: #()
            runner: TrapRunner new.
        ^GrammarFixtures verbsRowIn: result lines
    ]

    testTheReadmeNamesEveryVerbTheUsageLineDeclares [
        "A DRIFT LAW: a verb added without documentation fails the
         suite rather than quietly shipping undocumented. The guard is
         not ceremony — if the verb extraction answered nothing, the
         iteration would be vacuous and the law would pass over a
         README describing no verbs at all."
        | verbs readme undocumented |
        verbs := PublishLayoutFixtures verbsIn: self usageVerbsLine.
        self deny: verbs isEmpty
            description: 'no verbs were extracted from the usage line - the law would pass vacuously'.
        readme := PublishLayoutFixtures readmeSource.
        undocumented := verbs reject: [:verb |
            CommandLineFixtures does: readme include: 'parley ', verb].
        self assert: undocumented isEmpty
            description: undocumented printString,
                ' are verbs the CLI offers and the README does not name'
    ]

    testTheReadmeCarriesTheExecConsumerConstraint [
        "DECLARED PASS IN RED (issue #17): the README already carries
         §8 decision 45's sentence. The law exists to keep it there —
         parley exec is a faithful pass-through of the child's exit
         code, and without an explicit quit it is not a CI pass/fail
         signal."
        | readme |
        readme := PublishLayoutFixtures readmeSource.
        PublishLayoutFixtures execConstraintMarkers do: [:marker |
            self assert: (CommandLineFixtures does: readme include: marker)
                description: 'the README dropped the exec constraint marker: ',
                    marker printString]
    ]

    testTheReadmeDocumentsPublishingIntoBothLayouts [
        "A stranger has to be able to publish into either shape, which
         means the flag and both of its values are documented."
        | readme |
        readme := PublishLayoutFixtures readmeSource.
        PublishLayoutFixtures layoutDocumentationMarkers do: [:marker |
            self assert: (CommandLineFixtures does: readme include: marker)
                description: 'the README does not document ', marker printString]
    ]

    "---- §8 decision 52: a best-effort read swallows only what it
          defers to (S14) ----"

    seedFaultResultIn: aWorkDir base: aBaseDir [
        "The decision-52 fault, injected AT THE SEAM (Sprint 16, ruled
         on issue #18). This law was driven by a parley.lock that was a
         DIRECTORY, which was then the one operator state reaching the
         exit-70 branch; §8 decision 56 now diagnoses it at exit 1, and
         closed the equivalent ManifestFile hole with it, so no
         filesystem state reaches that branch any more — by design,
         since gst swallows anything raised by filed-in manifest code.
         Re-driving onto a surviving hole would make this law depend on
         that hole staying open. The claim is about what the CATCH does
         with an error it did not anticipate, so SeedFaultCLI raises one
         at the exact read the gathering goes through, inside a real run
         observed at the real boundary. ONLY THE DRIVER MOVED: every
         assertion below is the settled one."
        ^(SeedFaultCommandLine in: aWorkDir runner: ProcessRunner new)
            run: (Array with: 'resolve' with: '--index'
                with: (SparseIndexFixtures baseUrlFor: aBaseDir))
    ]

    testASeedGatheringFailureOutsideTheDeclaredBoundariesIsADefectNotAConflict [
        "The exact shape decision 52 names: the swallowed error leaves
         a partial seed set, the closure never reaches the missing
         name, and the verb answers a #noVersions conflict BLAMING THE
         PACKAGE at exit 1 — a confident wrong sentence about the
         operator's project. Narrowed, the error reaches the settled
         taxonomy and is reported as the software defect it is: one
         line, exit 70, never a backtrace and never exit 0."
        | base work result |
        base := self track: (SparseIndexFixtures baseTreeNamed: 'seed-base').
        SparseIndexFixtures publish: 'other-pkg' version: '1.0.0'
            dependencies: #() in: base.
        work := self track: (SparseIndexFixtures workDirNamed: 'seed-work'
            declaring: 'absent-pkg' constraint: '^1.0').
        result := self seedFaultResultIn: work base: base.
        self assert: result exitCode = 70
            description: 'a seed-gathering failure answered exit ',
                result exitCode printString, ': ', result lines printString.
        self assert: result lines size = 1.
        self assert: ((result lines at: 1) startsWith:
            LockBoundaryFixtures undiagnosedLinePrefix)
            description: 'the failure did not surface as the settled defect line'.
        self deny: (CommandLineFixtures does: (result lines at: 1)
            include: 'absent-pkg')
            description: 'the failure was reported as a conflict blaming the package'
    ]

    testACorruptLockStillLeavesResolveAtExitZero [
        "DECLARED PASS IN RED (issue #17) — the settled behaviour the
         narrowed catch must still produce (Doc E §4.1): resolve
         ignores a corrupt lock entirely, because the lock's diagnosis
         belongs to the verbs that read it. This is the guard against
         narrowing with too broad a hand."
        | base work result |
        base := self track: (SparseIndexFixtures baseTreeNamed: 'seed-corrupt-base').
        SparseIndexFixtures publish: 'root-dep' version: '1.0.0'
            dependencies: #() in: base.
        work := self track: (SparseIndexFixtures
            workDirNamed: 'seed-corrupt-work'
            declaring: 'root-dep' constraint: '^1.0').
        LockBoundaryFixtures
            writeLockContents: LockBoundaryFixtures unparseableLockContents
            in: work.
        result := self runIn: work
            argv: (Array with: 'resolve' with: '--index'
                with: (SparseIndexFixtures baseUrlFor: base))
            runner: ProcessRunner new.
        self assert: result exitCode = 0
            description: 'resolve no longer ignores a corrupt lock: ',
                result lines printString
    ]

    testAMissingManifestStillAnswersItsSettledDiagnosis [
        "DECLARED PASS IN RED (issue #17) — the other half of the
         guard: the missing-manifest sentence belongs to ManifestFile
         (§8 decision 31), and the narrowed catch must still defer to
         it rather than pre-empting it or letting it escape as a
         defect."
        | base work result |
        base := self track: (SparseIndexFixtures baseTreeNamed: 'seed-nomanifest-base').
        SparseIndexFixtures publish: 'root-dep' version: '1.0.0'
            dependencies: #() in: base.
        work := self freshDir: 'seed-nomanifest-work'.
        result := self runIn: work
            argv: (Array with: 'resolve' with: '--index'
                with: (SparseIndexFixtures baseUrlFor: base))
            runner: ProcessRunner new.
        self assert: result exitCode = 1
            description: 'a missing Package.st answered exit ',
                result exitCode printString.
        self deny: ((result lines at: 1) startsWith:
            LockBoundaryFixtures undiagnosedLinePrefix)
            description: 'the missing manifest was reported as a Parley defect'
    ]
]

Namespace current: Smalltalk.
