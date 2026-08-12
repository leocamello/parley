"Parley Sprint 16 — fixtures for the v1.0 readiness audit (issue #18;
 Doc E §4.1/§4.2, §8 decisions 56, 57 and 58).

 This is the sprint's ONE new support file. It carries the four pinned
 wordings the sprint adds, the operator states that reach them, and the
 README markers the settled Sprint 15 drift law is extended with. The
 settled SourceFixtures / ExecFixtures / InstallFixtures /
 CommandLineFixtures / LockBoundaryFixtures / SelectiveUpdateFixtures /
 ManifestEditFixtures / PublishLayoutFixtures / ResolverFixtures
 helpers are reused UNCHANGED — every index, archive, digest and lock
 oracle below is a settled Sprint 12/13 value, consumed as it stands.

 THE UNREADABLE LOCK IS A DIRECTORY, and that is the whole point.
 File>>exists answers TRUE for a directory (probed against 3.2.5 at
 RED, and again below in the method comment), so every settled shape
 check ran on a path whose bytes could not be obtained, and
 File>>contents signalled a KERNEL SystemExceptions.WrongClass that
 escaped every handler written for the declared boundary errors. One
 mkdir is the whole reproduction, so the fixture is one line.

 THE THREE HELD-PINS FIXTURES ARE A TRIPLE, not three fixtures.
 nosuch is a name the index does not publish AT ALL, so the conflict
 survives the unheld re-resolution and holding was never the reason;
 the settled ManifestEditFixtures held-conflict fixture is the case
 where holding IS the reason and the line must stay; and the
 unsatisfiable-tools root is the update <pkg> half, where a constraint
 no release satisfies fails whether or not anything is held. A fix that
 cannot keep all three right is over-narrowed in one direction or the
 other, which is why they are separate scenarios.

 Filesystem discipline (as Sprints 4-15): every fixture path lives
 under tmp/, unique per test via a label, removed recursively in
 tearDown through ExecFixtures removeTree:; tmp/ is empty or absent
 after a clean run. The developer image is never mutated, and no
 network is contacted — every index is a local directory and every
 child process runs under tmp/.

 Pinned wording decisions (posted on issue #18 for the RED review) live
 in the methods:
   - execRefusalLineFor: — the exec precondition refusal, in the
     settled missing-file grammar every other file diagnosis uses;
   - unreadableLockDefect / unreadableLockProblemFor: — the lock
     readability defect, carried through the SETTLED three-part
     LockError shape (path, defect, parley update) rather than a
     second shape invented beside it;
   - helpSpellings — the three accepted spellings of one question;
   - execPreconditionMarkers / helpDocumentationMarkers — what the
     README must carry, in the shape the settled Sprint 15 drift law
     already reads it."

Namespace current: Parley.

Object subclass: ReadinessFixtures [

    <comment: 'Class-side factory for Sprint 16 fixtures: the pinned
exec-precondition and lock-readability wordings, the directory-shaped
parley.lock, the three held-pins states, the question-flag spellings,
the README markers and the working directories each scenario needs.
Stateless; uniqueness comes from per-test labels.'>

    "---- the exec precondition (Doc E §4.1, §8 decision 56) ----"

    ReadinessFixtures class >> execRefusalLineFor: aScriptPath [
        "The one line parley exec answers for a script that is not an
         existing regular readable file, at exit 1, with NOTHING
         spawned.

         It is the settled missing-file grammar, not a new one: the
         manifest boundary says
         <path>: missing or unreadable Package.st - run parley init to
         write one, the directory source says
         <dir>: missing or unreadable directory, and publish says
         <dest>: missing or unreadable destination directory - publish
         does not create it. Same opening, same dash, and the tail is
         the one true thing this verb can add — a remedy it has not
         checked would be the decision-58 defect committed in the same
         sprint that fixes it, and nothing Parley could suggest fixes a
         path only the operator knows the right spelling of. What the
         operator needs is the fact that no work happened, because the
         shipped behaviour was exit 0 and a child that printed
         gst: Couldn't open file."
        <category: 'pinned wordings'>
        ^aScriptPath, ': missing or unreadable script - nothing was run'
    ]

    ReadinessFixtures class >> missingScriptPathIn: aWorkDir [
        "A script path inside aWorkDir that is never written — the
         typo an operator actually makes."
        <category: 'exec precondition'>
        ^aWorkDir, '/typo.st'
    ]

    ReadinessFixtures class >> directoryScriptPathIn: aWorkDir [
        "A DIRECTORY handed to exec as a script. It exists, so
         File>>exists answers true and every check written against
         existence passes it through; the shipped tool spawned a child
         that answered exit 0 in complete silence, which is the worse
         of the two shapes because there is nothing on screen at all."
        <category: 'exec precondition'>
        ^aWorkDir, '/adir'
    ]

    ReadinessFixtures class >> makeDirectoryScriptIn: aWorkDir [
        "Create the directory the exec precondition must refuse, and
         answer its path."
        <category: 'exec precondition'>
        | path |
        path := self directoryScriptPathIn: aWorkDir.
        Directory create: path.
        ^path
    ]

    ReadinessFixtures class >> quitThreeScriptPathIn: aWorkDir [
        <category: 'exec precondition'>
        ^aWorkDir, '/quit-three.st'
    ]

    ReadinessFixtures class >> writeQuitThreeScriptIn: aWorkDir [
        "A script that really runs and really quits 3 — the settled
         ExecFixtures child script, written into aWorkDir so the S3
         pass-through guard drives a file that EXISTS. Answers its
         path."
        <category: 'exec precondition'>
        SourceFixtures write: (ExecFixtures quitScriptContentsFor: 3)
            toFile: 'quit-three.st' in: aWorkDir.
        ^self quitThreeScriptPathIn: aWorkDir
    ]

    "---- the lock readability check (Doc E §4.1, §8 decision 56) ----"

    ReadinessFixtures class >> lockPathIn: aWorkDir [
        "The lock the CLI reads, named the way the diagnosis must name
         it."
        <category: 'lock readability'>
        ^aWorkDir, '/parley.lock'
    ]

    ReadinessFixtures class >> makeLockADirectoryIn: aWorkDir [
        "The whole reproduction, in one line: a botched checkout, a
         volume mount or a stray mkdir leaves parley.lock a DIRECTORY.

         Probed against 3.2.5 at RED: (File name: <dir>) exists answers
         true, isDirectory answers true, isFile answers FALSE, and
         contents signals SystemExceptions.WrongClass reading
         Invalid argument -9223372036854771711: must be a SmallInteger
         — a kernel error, outside every handler the settled boundary
         writes for its own declared errors. That integer is what
         reached the operator's screen, under a sentence claiming a
         defect in Parley, with the offending file never named."
        <category: 'lock readability'>
        Directory create: (self lockPathIn: aWorkDir).
        ^self lockPathIn: aWorkDir
    ]

    ReadinessFixtures class >> unreadableLockDefect [
        "The defect half of the diagnosis. It states the PREDICATE that
         failed rather than guessing which of the several ways to fail
         it was: a directory, a device node, a file whose permissions
         deny the reader. One sentence covers all of them and none of
         them is a different repair."
        <category: 'pinned wordings'>
        ^'not a regular readable file'
    ]

    ReadinessFixtures class >> unreadableLockRepairAdvice [
        "The repair half — RULED AT THE SPRINT 16 RED REVIEW, and the
         one place this diagnosis departs from the settled lock
         diagnoses.

         The settled LockBoundaryFixtures lockRepairAdvice names
         parley update, and its own comment states why that advice is
         true BY CONSTRUCTION: update is the one verb that never READS
         the lock, so it can always rewrite one. A directory-shaped
         lock is exactly the state that breaks the construction —
         update's WRITE cannot succeed against a directory either,
         which is precisely what
         testPlainUpdateRefusesAnUnreadableLockItCannotRewrite asserts.
         Pinning parley update here would answer the defect by naming
         the verb this same sprint makes answer the same refusal: a
         remedy that loops back to the diagnosis, and §8 decision 58's
         own standard — a remedy line is asserted only when it has been
         checked — broken by the sentence next door to it.

         So the readability defect names the two-step repair that
         actually works, and its second half is the SETTLED missing-lock
         repair (InspectionFixtures missingLockLine): once the path is
         removed the lock is MISSING, not corrupt, and resolve is the
         verb that writes a first one."
        <category: 'pinned wordings'>
        ^' - remove it and run parley resolve to write a new one'
    ]

    ReadinessFixtures class >> unreadableLockProblemFor: aPath [
        "The whole diagnosis in the SETTLED three-part LockError shape —
         the path, the defect, the repair, one dash, one sentence — so
         an operator who has seen one lock diagnosis does not have to
         learn a second grammar for the next one.

         The shape is restated rather than delegated to
         LockBoundaryFixtures lockProblemFor:message: because that
         helper hard-codes the corrupt-lock repair, and this case has a
         different one for a checked reason (see
         unreadableLockRepairAdvice). Everything else about the shape is
         identical, deliberately."
        <category: 'pinned wordings'>
        ^aPath, ': ', self unreadableLockDefect, self unreadableLockRepairAdvice
    ]

    ReadinessFixtures class >> kernelErrorMarker [
        "The substring that betrays a kernel error on the operator's
         screen. S4 denies it, because exit 1 with the right sentence
         is not enough if the sentence is a kernel class name."
        <category: 'pinned wordings'>
        ^'WrongClass'
    ]

    "---- the question flags (Doc E §4.2, §8 decision 57) ----"

    ReadinessFixtures class >> helpFlag [
        <category: 'question flags'>
        ^'--help'
    ]

    ReadinessFixtures class >> shortHelpFlag [
        <category: 'question flags'>
        ^'-h'
    ]

    ReadinessFixtures class >> helpVerb [
        <category: 'question flags'>
        ^'help'
    ]

    ReadinessFixtures class >> helpSpellings [
        "The three spellings of ONE question. A user who guesses any of
         them has asked the same thing, so all three answer the same
         lines at the same exit code — asserted against each OTHER, not
         against three literals."
        <category: 'question flags'>
        ^Array with: self helpFlag with: self shortHelpFlag
            with: self helpVerb
    ]

    ReadinessFixtures class >> usageErrorArgvs [
        "The settled usage-error grammar Sprint 16 had to leave exactly
         where it found it: no argv at all, an unknown verb, and a
         TRAILING question flag on a verb. Failing to say what you want
         is an error even though asking for help is not, and the
         settled valueOf:in: treats a trailing flag as not a flag —
         which is the mechanism a general valueless-flag grammar would
         silently change without touching a line of the laws that rest
         on it."
        <category: 'question flags'>
        ^self usageErrorRows collect: [:row | row at: 1]
    ]

    ReadinessFixtures class >> usageErrorRows [
        "THE SAME ARGVS, EACH WITH THE GROUND IT NOW ANSWERS FOR, and
         its subject: (argv, ground, subject).

         AMENDED AT SPRINT 20's RED (issue #22, §8 decisions 79 and 81).
         The list above was a list of argvs because every one of them
         answered BYTE-IDENTICAL output; once a usage error names what
         was wrong, they stop being interchangeable and the fixture has
         to say which ground each one is.

         THE LAST TWO ARE THE FOURTH GROUND, and the ruling that
         restored it. This fixture's own comment calls them `a trailing
         question flag on a verb`, which describes the ARGV and not the
         GROUND: `resolve --help` names a verb the tool really has, and
         probed with a source wired it STILL answers usage — so its
         ground is the arity and never the index."
        <category: 'question flags'>
        ^(Array
            with: (Array with: #() with: #noVerb with: '')
            with: (Array with: (Array with: 'nonsense')
                with: #unknownVerb with: 'nonsense'))
            , (Array
                with: (Array with: (Array with: 'resolve' with: '--help')
                    with: #wrongArguments with: 'resolve')
                with: (Array with: (Array with: 'resolve' with: '--version')
                    with: #wrongArguments with: 'resolve'))
    ]

    ReadinessFixtures class >> stateCreatingUsageArgvs [
        "The three argvs the readiness audit caught creating
         <cwd>/.parley/packages BEFORE answering the usage they were
         always going to answer (§8 decision 57, second half). It was
         found when a bare parley run from the repository root left a
         directory in Parley's own checkout and broke two settled
         laws — the tool contaminating itself, caught by the suite
         rather than by anyone noticing."
        <category: 'question flags'>
        ^Array
            with: #()
            with: (Array with: 'nonsense')
            with: (Array with: 'resolve')
    ]

    "---- the checked held-pins line (Doc E §4.1, §8 decision 58) ----"

    ReadinessFixtures class >> absentPackageName [
        "A package name the index does not publish at any version — a
         typo''d dependency, the commonest way to reach the held-pins
         path at all, and the one where holding is irrelevant and
         parley update cannot help."
        <category: 'held pins'>
        ^'nosuch'
    ]

    ReadinessFixtures class >> absentPackageConstraint [
        <category: 'held pins'>
        ^'^1.0'
    ]

    ReadinessFixtures class >> rootAfterAddingAbsentPackage [
        "The S12 root as a live manifest AFTER the nosuch clause is
         appended, in the file's own declaration order, so the expected
         narration is composed through the IDENTICAL resolution the
         verb performs rather than through a second description of it.

         The base is the settled ManifestEditFixtures
         withDependenciesContents: my-app 1.0.0 declaring tool-b ^2.0,
         whose pin is what gets held."
        <category: 'held pins'>
        ^ResolverFixtures rootWith: (Array
            with: (Array with: 'tool-b' with: '^2.0')
            with: (Array with: self absentPackageName
                with: self absentPackageConstraint))
    ]

    ReadinessFixtures class >> unsatisfiableToolsRootContents [
        "The S14 root: my-app declares tool-a ^1.0 — movable, and the
         package update <pkg> names — beside tool-b ^9.0, which NO
         release of tool-b satisfies in the settled tools index.

         The point of the shape: tool-b is still PINNED at 2.0.0 and
         still held, so the verb really does narrow the world and
         really does reach the held-pins path, and the conflict is
         nonetheless nothing to do with holding — the unheld world
         publishes 2.0.0 and 2.1.0 and satisfies ^9.0 no better. This
         is the ordinary state after an operator edits a constraint by
         hand and then asks for one package to move."
        <category: 'held pins'>
        ^'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''tool-a'' constraint: ''^1.0'';
        dependency: ''tool-b'' constraint: ''^9.0'' ]',
            SourceFixtures newline
    ]

    ReadinessFixtures class >> unsatisfiableToolsManifest [
        "The same root as a live manifest, for composing the expected
         narration through the settled resolver seam."
        <category: 'held pins'>
        ^ResolverFixtures rootWith: (Array
            with: (Array with: 'tool-a' with: '^1.0')
            with: (Array with: 'tool-b' with: '^9.0'))
    ]

    ReadinessFixtures class >> unsatisfiableToolsWorkDirNamed: aLabel [
        "The S14 working directory: the unsatisfiable root over the
         SETTLED tools lock (tool-a 1.0.0, tool-b 2.0.0), so every held
         pin is describable and the run reaches the resolution rather
         than the deleted-held-pin diagnosis."
        <category: 'working dirs'>
        ^ManifestEditFixtures workDirNamed: aLabel
            contents: self unsatisfiableToolsRootContents
            lock: SelectiveUpdateFixtures toolsLockString
    ]

    ReadinessFixtures class >> heldPinsLine [
        "The sentence under audit, DELEGATED to its settled Sprint 12
         definition. This sprint does not change one character of it —
         it changes when the tool is entitled to say it."
        <category: 'pinned wordings'>
        ^SelectiveUpdateFixtures heldPinsLine
    ]

    "---- roots and working directories for the lock laws ----"

    ReadinessFixtures class >> toolARootContents [
        "my-app declaring tool-a ^1.0 alone — the smallest root the
         settled tools index satisfies, used wherever a lock defect is
         the thing under test and the resolution must simply succeed."
        <category: 'working dirs'>
        ^'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''tool-a'' constraint: ''^1.0'' ]',
            SourceFixtures newline
    ]

    ReadinessFixtures class >> toolAResolvedLockString [
        "What a fresh resolution of that root writes against the
         settled tools index: tool-a at 1.1.0, the newest its
         constraint allows. The S6 oracle — resolve must not merely
         answer exit 0 over a corrupt lock, it must REPLACE it."
        <category: 'lock oracles'>
        ^SelectiveUpdateFixtures lockWithTuples: (Array
            with: (SelectiveUpdateFixtures tupleFor: 'tool-a'
                version: '1.1.0'
                digest: SelectiveUpdateFixtures digestToolA110))
    ]

    ReadinessFixtures class >> initSessionLockWithDigest: aDigest [
        "The byte-stable lock the S16 first session writes: the root is
         my-package, which is what parley init names a new project,
         pinning the one dependency the session added.

         The settled ExecFixtures probeLockStringWithDigest: names
         my-app and cannot be reused here — a session that starts from
         init starts from the skeleton's own name, and asserting on the
         other oracle would be asserting on a project this walk never
         had."
        <category: 'lock oracles'>
        ^'#(#''parley-lock'' 1 #root ''my-package'' #packages #(#(''parley-probe'' ''1.0.0'' #sha256 ''',
            aDigest, ''')))', SourceFixtures newline
    ]

    ReadinessFixtures class >> toolAWorkDirNamed: aLabel [
        "A working directory holding the tool-a root and NO lock."
        <category: 'working dirs'>
        ^ManifestEditFixtures workDirNamed: aLabel
            contents: self toolARootContents
    ]

    ReadinessFixtures class >> unreadableLockWorkDirNamed: aLabel [
        "The S4/S5/S7 state: a valid Package.st beside a parley.lock
         that is a DIRECTORY. Answers the path; the caller tracks it
         for teardown (ExecFixtures removeTree: is recursive, which is
         what a directory-shaped lock needs)."
        <category: 'working dirs'>
        | path |
        path := self toolAWorkDirNamed: aLabel.
        self makeLockADirectoryIn: path.
        ^path
    ]

    ReadinessFixtures class >> corruptLockWorkDirNamed: aLabel [
        "The S6 guard state: the same root beside a lock that is
         READABLE and unparseable. The line between the two fixtures is
         the line the whole lock half of this sprint turns on — this
         one must still leave resolve at exit 0."
        <category: 'working dirs'>
        ^ManifestEditFixtures workDirNamed: aLabel
            contents: self toolARootContents
            lock: LockBoundaryFixtures unparseableLockContents
    ]

    "---- the README, under the settled Sprint 15 drift law ----"

    ReadinessFixtures class >> execPreconditionMarkers [
        "What the README must say about the exec precondition, BESIDE
         the settled §8 decision 45 consumer constraint rather than
         instead of it. The two claims are neighbours and are easy to
         confuse: Parley refuses a script that is not there, and Parley
         still makes no claim about a script that ran."
        <category: 'readme markers'>
        ^Array
            with: 'missing or unreadable script - nothing was run'
            with: 'before anything is spawned'
    ]

    ReadinessFixtures class >> helpDocumentationMarkers [
        "--help must appear wherever --version does, in all three
         spellings, because a user who guesses one of them has asked
         the same question and the README is where they check."
        <category: 'readme markers'>
        ^Array
            with: 'parley --help'
            with: 'parley -h'
            with: 'parley help'
    ]
]

CLI subclass: SeedFaultCLI [

    <comment: 'The Sprint 16 re-driver for the two settled decision-52
laws: a CLI whose lock read — one of the two reads seedNames gathers
through — signals an error OUTSIDE the two boundaries that gathering
defers to, so the narrowed catch has to let it past and the settled
taxonomy has to answer it.

WHY THE FAULT IS INJECTED RATHER THAN STAGED ON DISK. Those laws used
to be driven by a parley.lock that was a DIRECTORY, which was then the
one operator state reaching the exit-70 branch. §8 decision 56 closed
it, and closed the equivalent hole in ManifestFile with it, so — since
gst swallows anything raised by filed-in manifest code — no filesystem
state reaches that branch any more, BY DESIGN. A law re-driven onto a
surviving hole would be a law underwritten by a defect, and would keep
passing exactly as long as the defect lived. The claim is about what
the CATCH does with an error it did not anticipate, so the error is
put there directly. An edge double, never domain.'>

    pinnedResolution [
        "Private — the injected fault, at the exact seam seedNames
         gathers through. A plain Error is deliberately neither a
         ManifestError nor a LockError: those are the two boundaries
         the gathering defers to, and the whole claim is that anything
         else reaches CommandLine's exit 70 rather than leaving a
         silently partial seed set behind."
        <category: 'private'>
        ^self error: self class faultMessage
    ]

    SeedFaultCLI class >> faultMessage [
        <category: 'accessing'>
        ^'seed gathering met an error no boundary declared'
    ]
]

CommandLine subclass: SeedFaultCommandLine [

    <comment: 'The composition root that wires SeedFaultCLI, so the
fault is raised inside a real run and observed at the real §4.2
boundary — which is where exit 70 and the one-line diagnosis live, and
therefore the only place the two laws can assert what they assert. An
edge double, never domain.'>

    cliWithSource: aPackageSource [
        "Private — the settled wiring with the fault-injecting CLI in
         place of the real one. The collaborators are restated rather
         than delegated because the CLASS is the only thing that
         changes and construction is where a class is chosen; every
         path still comes from the inherited private accessors, so the
         store and the target stay derived from the WORKING directory
         exactly as the settled wiring laws require."
        <category: 'private-wiring'>
        ^SeedFaultCLI
            in: workingDir
            source: aPackageSource
            store: (ContentStore on: self storePath)
            target: self targetPath
            runner: runner
    ]
]

Namespace current: Smalltalk.
