"Parley Sprint 8 — fixtures and doubles for the CommandLine, diagnosis
 boundary, shipped-binary and value-validation suites (issue #10,
 Doc E §4.2/§4.3 and Doc F §1/§4.1).

 This is the sprint's ONE new support file; it carries every Sprint 8
 fixture, not only the CommandLine ones, per the kickoff instruction
 that new fixtures live here. The settled ExecFixtures /
 InstallFixtures / SourceFixtures / PublishFixtures helpers are reused
 unchanged (recursive teardown, star building, publishable working
 dirs, the schema fixtures).

 Filesystem discipline (as Sprints 4-7): every fixture path — working
 dirs, index dirs, destinations, the .parley/ state a CommandLine
 wires under a working directory, child output captures — lives under
 tmp/, is unique per test via a label, and is removed recursively in
 tearDown through ExecFixtures removeTree:; tmp/ is empty or absent
 after a clean run. The developer image is never mutated, and every
 child process this file composes a command line for runs with its cwd
 inside tmp/ and writes only there.

 Process discipline (unchanged): ProcessRunner is the ONLY class that
 spawns, in src/ and in tests alike. This file composes command-line
 STRINGS as pure values; the laws hand them to a real ProcessRunner.

 Pinned wording and composition decisions (posted on issue #10 for
 confirmation) live in the methods:
   - the boundary's undiagnosed line — internalErrorLineFor:message:;
   - the Publisher destination check — missingDestinationProblemFor:;
   - value-shape validation — unparseableVersionProblemFor:value: and
     unparseableConstraintProblemFor:dependency:value:;
   - the missing-Package.st diagnosis — missingManifestProblemFor:
     (see the class comment: this one rests on a THIRD settled-class
     exception requested on issue #10 and is not yet granted);
   - the shipped-binary command composition —
     shippedBinaryCommandIn:args: and its output-capturing variant;
   - the closed-set law's second list — undiagnosedErrorClassNames."

Namespace current: Parley.

Object subclass: CommandLineFixtures [

    <comment: 'Class-side factory for Sprint 8 fixtures: absolute-path
composition for the shipped-binary child processes, the .parley/ state
paths a CommandLine derives from a working directory, value-shape
violating entry files, the closed-set law''s declared lists, and every
pinned Sprint 8 wording. Stateless; uniqueness comes from per-test
labels.'>

    "---- absolute paths (the child''s cwd is a fixture directory) ----"

    CommandLineFixtures class >> repoRoot [
        "The Parley checkout the suite runs from. Tests run with the
         repository root as the process cwd (verify-sprint.sh cds
         there), so this is the PARLEY_ROOT a shipped-binary child
         needs."
        <category: 'absolute paths'>
        ^Directory workingName
    ]

    CommandLineFixtures class >> absolutePathOf: aRelativePath [
        "aRelativePath (always a tmp/ fixture path) as an absolute
         path. The shipped-binary laws cd into the fixture working
         directory, so every path they hand the child must be
         absolute."
        <category: 'absolute paths'>
        ^self repoRoot, '/', aRelativePath
    ]

    "---- the .parley/ state a CommandLine derives from the work dir ----"

    CommandLineFixtures class >> parleyDirIn: aWorkDir [
        "The state directory, derived from the WORKING directory and
         never from the process cwd — the whole point of the wiring
         laws."
        <category: 'wiring paths'>
        ^aWorkDir, '/.parley'
    ]

    CommandLineFixtures class >> storeRootIn: aWorkDir [
        <category: 'wiring paths'>
        ^(self parleyDirIn: aWorkDir), '/store'
    ]

    CommandLineFixtures class >> targetDirIn: aWorkDir [
        <category: 'wiring paths'>
        ^(self parleyDirIn: aWorkDir), '/packages'
    ]

    CommandLineFixtures class >> cwdStoreRoot [
        "The path the SHIPPED DEFECT would create beside the process
         cwd. The repository root legitimately holds .parley/ (the
         harness scope and loop state), so the laws assert the absence
         of these two paths, never of .parley/ itself."
        <category: 'wiring paths'>
        ^'.parley/store'
    ]

    CommandLineFixtures class >> cwdTargetDir [
        <category: 'wiring paths'>
        ^'.parley/packages'
    ]

    "---- the shipped-binary command composition (pinned) ----"

    CommandLineFixtures class >> shippedBinaryCommandIn: aWorkDir args: anArgsString [
        "The command a user actually runs, composed absolutely: the
         child's cwd is the fixture working directory, PARLEY_ROOT is
         the checkout, and the argv follows -a (3.2.5 passes every
         remaining argument to Smalltalk). Every path in anArgsString
         must already be absolute.

         THE DECLARED VARIABLES ARE PINNED EMPTY from Sprint 22 (§8
         decision 85): the shipped binary reads the process
         environment, the child inherits the harness's, and set-empty
         is unset — so the prefix is what keeps every shipped-binary
         law immune to a developer's exported PARLEY_SOURCE. A law
         driving an environment state exports its variable AFTER these
         pins (EnvFixtures)."
        <category: 'shipped binary'>
        ^'cd ', (self absolutePathOf: aWorkDir),
            ' && ', EnvFixtures pinnedEmptyPrefix,
            'PARLEY_ROOT=', self repoRoot,
            ' gst -q ', self repoRoot, '/bin/parley-main.st -a ',
            anArgsString
    ]

    CommandLineFixtures class >> shippedBinaryCommandIn: aWorkDir args: anArgsString outputTo: anOutputPath [
        "The same command with the child's whole output redirected to
         anOutputPath (an absolute tmp/ path), so a law can prove the
         child answered a DIAGNOSIS and not a backtrace. The redirect
         is a test-composed shell tail: ProcessRunner still captures
         nothing (output capture stays out of scope, issue #10)."
        <category: 'shipped binary'>
        ^(self shippedBinaryCommandIn: aWorkDir args: anArgsString),
            ' > ', anOutputPath, ' 2>&1'
    ]

    CommandLineFixtures class >> shellWrapperCommandIn: aWorkDir args: anArgsString [
        "bin/parley itself — the POSIX sh wrapper that finds the
         checkout from its own location and execs the main script with
         a leading '--'. The only path that exercises the leading-'--'
         strip end to end. The declared variables are pinned empty for
         the same reason the direct composition pins them (§8 decision
         85: set-empty is unset)."
        <category: 'shipped binary'>
        ^'cd ', (self absolutePathOf: aWorkDir),
            ' && ', EnvFixtures pinnedEmptyPrefix,
            self repoRoot, '/bin/parley ', anArgsString
    ]

    CommandLineFixtures class >> backtraceMarkers [
        "Substrings that appear in a 3.2.5 unhandled-error dump and in
         nothing Parley ever prints on purpose: the doesNotUnderstand:
         report and a backtrace frame's source location. Parley
         diagnoses; it does not dump."
        <category: 'shipped binary'>
        ^#('doesNotUnderstand' '(src/')
    ]

    "---- the src/ drift law (S8) ----"

    CommandLineFixtures class >> wrapperPath [
        <category: 'drift law'>
        ^'bin/parley-main.st'
    ]

    CommandLineFixtures class >> wrapperSource [
        "The wrapper read as TEXT — the law compares a script's own
         source against the directories that actually exist."
        <category: 'drift law'>
        ^(File name: self wrapperPath) contents
    ]

    CommandLineFixtures class >> srcSubdirectoryNames [
        "Every existing subdirectory of src/, in sorted order.

         3.2.5's File>>files answers REGULAR FILES ONLY — never a
         subdirectory — so src/, which holds nothing but directories,
         answers an empty Array through it and the drift law would
         enumerate nothing. namesDo: is the enumeration that sees
         directories (it also yields '.' and '..', which are filtered);
         it is the same idiom PublishFixtures fileNamesIn: already uses.
         Amended by the operator at the Sprint 8 RED review."
        <category: 'drift law'>
        | names |
        names := OrderedCollection new.
        (File name: 'src') namesDo: [:each |
            (#('.' '..') includes: each) ifFalse: [
                (File name: 'src/', each) isDirectory
                    ifTrue: [names add: each]]].
        ^(names asSortedCollection: [:a :b | a <= b]) asArray
    ]

    CommandLineFixtures class >> does: aString include: aSubstring [
        "Private — substring containment through the ANSI selector."
        <category: 'drift law'>
        ^(aString indexOfSubCollection: aSubstring) > 0
    ]

    "---- the closed-set law (S7) ----"

    CommandLineFixtures class >> parleyErrorClasses [
        "Every Error subclass defined in the Parley namespace, sorted
         by name. Enumerated from the loaded image, so a new error
         class appears here the moment it is filed in."
        <category: 'closed set'>
        ^((Error allSubclasses
            select: [:each | each environment == (Smalltalk at: #Parley)])
                asSortedCollection: [:a :b | a name asString <= b name asString])
                    asArray
    ]

    CommandLineFixtures class >> undiagnosedErrorClassNames [
        "The boundary's SECOND declared list: the Parley error classes
         that are NOT mapped to exit 1, each declared here by name so
         a new class can never drift into the exit-70 bucket silently
         — the law fails first.

         The bucket is 'declared undiagnosed, with its ground named'
         (Doc E §4.2). SPRINT 9 RESTORES THE STRONG CLAIM: with the lock
         boundary (§4.1) and the authoring-error boundary (§3) in place,
         every name below is 'provably never signaled out of a verb',
         and Sprint9AcceptanceTest testS7 demonstrates it by driving a
         real input through a real verb for each one. The weaker ground
         stays written down in the doc because the law must keep
         accepting it for the next class that legitimately needs it —
         but it has no members. The list's five names do not change;
         only their ground does. The law's guarantee is unchanged: no
         Parley error class reaches exit 70 without somebody having
         decided it should.

         Declared reasons, one per class (posted on issue #10):
           ConstraintFormatError — signaled only by
             VersionConstraint fromString:. Every caller inside a verb
             catches it: ManifestBuilder>>build batches it into a
             ManifestError, and the DirectorySource scan batches it
             into a SourceError (Doc F §4.1, this sprint). Never
             signaled out of a verb.
           VersionFormatError — signaled only by Version fromString:,
             with the same two catching callers.
           IndexEntryParseError, IndexEntryFormatError — signaled only
             by the literals-only reader; the DirectorySource scan
             catches both.
           ManifestVocabularyError — the ManifestBuilder DNU error
             path, raised while the author's OWN Package.st is being
             filed in.

         The Sprint 8 residue, CLOSED by Sprint 9 (issue #11): the
         reader errors escaped through the CLI's parley.lock read and
         landed on exit 70; the lock boundary of Doc E §4.1 turns them
         into a LockError diagnosis at exit 1. The vocabulary error's
         declared escape was stated inaccurately at Sprint 8 and is
         corrected here: on 3.2.5 it never escapes ManifestFile load: at
         all, because the doit context of a filed-in statement is
         parentless — gst prints its own backtrace and abandons the
         statement, and load: then answers the WRONG diagnosis ('no
         manifest defined'). The toolchain probe and the architectural
         consequence are recorded in LockBoundaryFixtures
         vocabularyMessageForSelector:."
        <category: 'closed set'>
        ^#('ConstraintFormatError' 'IndexEntryFormatError'
           'IndexEntryParseError' 'ManifestVocabularyError'
           'VersionFormatError')
    ]

    CommandLineFixtures class >> diagnosedErrorClassNames [
        "The declared Parley errors of Doc E §4.2, by name — the oracle
         the law holds the boundary's own declared set to.

         AMENDED FOR SPRINT 9 (issue #11): the set becomes SIX. LockError
         joins it, because a parley.lock that cannot be read is the
         OPERATOR's file and must be diagnosed at exit 1 rather than
         reported as a defect in Parley. This edit is the deliberate
         decision the closed-set drift law exists to force: the law
         fails first, and whoever moves the boundary must come here and
         say so. It lands in RED, so the two settled laws that read this
         oracle — DiagnosisBoundaryTest
         testTheBoundaryDeclaresExactlyTheDocumentedErrors and
         Sprint8AcceptanceTest testS7_theBoundaryIsAClosedSet — fail in
         red with the sprint and pass again in green. Declared on issue
         #11."
        <category: 'closed set'>
        ^#('ExecutionError' 'InstallError' 'LockError' 'ManifestError'
           'PublishError' 'SourceError')
    ]

    CommandLineFixtures class >> namesOf: aCollectionOfClasses [
        "Sorted class names as Strings. 3.2.5's Class>>name answers a
         SYMBOL, and a Symbol never equals an equal-looking String, so
         every comparison against a declared name goes through
         asString — here and in the laws."
        <category: 'closed set'>
        ^((aCollectionOfClasses collect: [:each | each name asString])
            asSortedCollection: [:a :b | a <= b]) asArray
    ]

    CommandLineFixtures class >> nameOf: aClass [
        "One class name as a String (see namesOf:)."
        <category: 'closed set'>
        ^aClass name asString
    ]

    "---- pinned boundary wordings (posted on issue #10) ----"

    CommandLineFixtures class >> internalErrorLineFor: aClassName message: aMessageText [
        "The exit-70 line: ONE line naming the error's class and its
         message text, and saying whose defect it is. Never a
         backtrace — Parley diagnoses, it does not dump."
        <category: 'pinned wordings'>
        ^'internal error: ', aClassName, ': ', aMessageText,
            ' - this is a defect in Parley, not in your project'
    ]

    CommandLineFixtures class >> plainErrorMessage [
        "The message text the plain-Error runner double signals."
        <category: 'pinned wordings'>
        ^'the process seam broke'
    ]

    CommandLineFixtures class >> plainErrorLine [
        <category: 'pinned wordings'>
        ^self internalErrorLineFor: 'Error' message: self plainErrorMessage
    ]

    CommandLineFixtures class >> derivedSourceProblem [
        "The single problem the DerivedSourceError double carries — a
         SUBCLASS of a declared error, diagnosed at exit 1 because the
         boundary classifies by handling (on:do:) and not by kind."
        <category: 'pinned wordings'>
        ^'a subclass of a declared Parley error reached the boundary'
    ]

    CommandLineFixtures class >> missingManifestProblemFor: aPath [
        "The diagnosis a verb answers for a working directory with no
         Package.st (issue #10 S4: exit 1, the ManifestError's
         problems).

         ASSUMPTION, posted on issue #10 and NOT yet ruled: reaching
         this requires ManifestFile load: to check the path before
         filing it in — 3.2.5's FileStream fileIn: signals
         SystemExceptions.FileError on a missing file (probed against
         the toolchain), which is a kernel error and therefore an
         exit-70 outcome, not the exit-1 ManifestError S4 requires.
         That makes ManifestFile a THIRD settled-class exception, which
         only the operator can declare."
        <category: 'pinned wordings'>
        ^aPath, ': missing or unreadable Package.st - run parley init to write one'
    ]

    CommandLineFixtures class >> missingDestinationProblemFor: aDestDir [
        "The Publisher destination check (Doc F §1, Sprint 8): the
         DirectorySource ': missing or unreadable directory' precedent
         applied to the write side, plus the reason publish does not
         simply create it — a typo must not be indistinguishable from
         an intent."
        <category: 'pinned wordings'>
        ^aDestDir, ': missing or unreadable destination directory - publish does not create it'
    ]

    CommandLineFixtures class >> unparseableVersionProblemFor: aBaseName value: aString [
        "Value-shape validation (Doc F §4.1): one problem naming the
         file and the unparseable value, in the grammar of its shape
         siblings."
        <category: 'pinned wordings'>
        ^aBaseName, ': #version ', aString printString,
            ' does not parse as a version'
    ]

    CommandLineFixtures class >> unparseableConstraintProblemFor: aBaseName dependency: aName value: aString [
        <category: 'pinned wordings'>
        ^aBaseName, ': #dependencies constraint ', aString printString,
            ' for ', aName printString,
            ' does not parse as a version constraint'
    ]

    CommandLineFixtures class >> duplicateProblemFor: aBaseName name: aName version: aVersionString in: anOtherBaseName [
        "The settled duplicate wording, restated here so the S14 batch
         can assert every problem shape in one place."
        <category: 'pinned wordings'>
        ^aBaseName, ': duplicate entry for ''', aName, ''' ', aVersionString,
            ' (already declared in ', anOtherBaseName, ')'
    ]

    CommandLineFixtures class >> malformedProblemFor: aBaseName [
        "The settled literals-only reader rejection, restated."
        <category: 'pinned wordings'>
        ^aBaseName,
            ': Parse error at position 1: artifact must open with a literal array',
            ' - the micro-format accepts only literal arrays, strings, symbols and non-negative integers'
    ]

    CommandLineFixtures class >> wrongTagProblemFor: aBaseName [
        <category: 'pinned wordings'>
        ^aBaseName,
            ': wrong artifact tag #''parley-lock'' - a source directory holds #''parley-index'' 1 entries and #''parley-retired'' 1 records'
    ]

    "---- value-shape violating entry files (Doc F §4.1) ----"

    CommandLineFixtures class >> unparseableVersionValue [
        <category: 'value entries'>
        ^'banana'
    ]

    CommandLineFixtures class >> unparseableConstraintValue [
        <category: 'value entries'>
        ^'banana'
    ]

    CommandLineFixtures class >> entryWithUnparseableVersion [
        "Literal-valid, tag-valid and SHAPE-valid — #version is a
         string, as the schema fixes. It simply does not mean
         anything, which is the whole point of §4.1."
        <category: 'value entries'>
        ^'#(#''parley-index'' 1 #name ''p'' #version ''banana'' #summary '''' #author '''' #license '''' #fileIns #(''P.st'') #dependencies #() #archive #())',
            SourceFixtures newline
    ]

    CommandLineFixtures class >> entryWithUnparseableConstraint [
        "Shape-valid #dependencies — an array of string pairs — whose
         constraint does not parse."
        <category: 'value entries'>
        ^'#(#''parley-index'' 1 #name ''p'' #version ''1.0.0'' #summary '''' #author '''' #license '''' #fileIns #(''P.st'') #dependencies #(#(''q'' ''banana'')) #archive #())',
            SourceFixtures newline
    ]

    CommandLineFixtures class >> entryWithUnparseableSecondConstraint [
        "The FIRST dependency parses and the second does not — one
         problem per file names the defect that is actually there."
        <category: 'value entries'>
        ^'#(#''parley-index'' 1 #name ''p'' #version ''1.0.0'' #summary '''' #author '''' #license '''' #fileIns #(''P.st'') #dependencies #(#(''q'' ''^1.0'') #(''r'' ''banana'')) #archive #())',
            SourceFixtures newline
    ]

    CommandLineFixtures class >> populateEveryProblemKindIn: aDirPath [
        "The S14 directory: one unparseable file, one wrong-tag file,
         one shape-violating file, one unparseable-version file, and a
         duplicate of a valid entry — five problems, one per file, in
         sorted-filename order. Filenames are chosen so sorted order
         and problem order are the same and visibly so."
        <category: 'value entries'>
        SourceFixtures write: SourceFixtures malformedContents
            toFile: 'aa-unparseable.st' in: aDirPath.
        SourceFixtures write: SourceFixtures lockArtifactContents
            toFile: 'bb-wrongtag.st' in: aDirPath.
        SourceFixtures write: PublishFixtures entryMissingSummary
            toFile: 'cc-shape.st' in: aDirPath.
        SourceFixtures write: self entryWithUnparseableVersion
            toFile: 'dd-value.st' in: aDirPath.
        SourceFixtures write: PublishFixtures validEntryP
            toFile: 'ee-valid.st' in: aDirPath.
        SourceFixtures write: PublishFixtures validEntryP
            toFile: 'ff-duplicate.st' in: aDirPath
    ]

    CommandLineFixtures class >> everyProblemKindProblems [
        "The five problems the S14 directory answers, in sorted-
         filename order: the settled parse, tag and duplicate shapes
         unchanged, the Sprint 7 shape problem unchanged, and the new
         value problem batched among them."
        <category: 'value entries'>
        ^Array
            with: (self malformedProblemFor: 'aa-unparseable.st')
            with: (self wrongTagProblemFor: 'bb-wrongtag.st')
            with: (PublishFixtures missingKeyProblemFor: 'cc-shape.st'
                key: #summary)
            with: (self unparseableVersionProblemFor: 'dd-value.st'
                value: self unparseableVersionValue)
            with: (self duplicateProblemFor: 'ff-duplicate.st'
                name: 'p' version: '1.0.0' in: 'ee-valid.st')
    ]

    "---- working-dir trees carrying .parley/ state ----"

    CommandLineFixtures class >> probeRootWorkDirNamed: aLabel [
        "A working directory whose Package.st depends on the
         toolchain-built parley-probe package — the install-wiring
         fixture. Answers the path; the caller tracks it for teardown."
        <category: 'working dirs'>
        | path |
        path := SourceFixtures directoryNamed: aLabel.
        ExecFixtures writePackage: ExecFixtures probeRootContents in: path.
        ^path
    ]

    CommandLineFixtures class >> diamondRootWorkDirNamed: aLabel [
        "A working directory whose Package.st is the settled diamond
         root — the resolve-wiring fixture."
        <category: 'working dirs'>
        | path |
        path := SourceFixtures directoryNamed: aLabel.
        ExecFixtures writePackage: ExecFixtures diamondRootContents in: path.
        ^path
    ]

    CommandLineFixtures class >> consumerWorkDirNamed: aLabel [
        "Author B's working directory: my-app depending on author A's
         published kernel-greeting."
        <category: 'working dirs'>
        | path |
        path := SourceFixtures directoryNamed: aLabel.
        ExecFixtures writePackage: PublishFixtures greetingRootContents
            in: path.
        ^path
    ]

    CommandLineFixtures class >> diamondPinLines [
        "The resolve/install success lines for the settled diamond
         root: one '<name> <version>' per pin, sorted by name."
        <category: 'working dirs'>
        ^#('a 1.0.0' 'b 1.0.0' 'c 2.4.0')
    ]

    CommandLineFixtures class >> probePinLines [
        <category: 'working dirs'>
        ^#('parley-probe 1.0.0')
    ]

    CommandLineFixtures class >> greetingPinLines [
        <category: 'working dirs'>
        ^#('kernel-greeting 1.0.0')
    ]
]

Object subclass: RaisingRunner [
    | errorBlock commands |

    <comment: 'The boundary probe: a runner double that spawns nothing
and signals whatever its block signals. Handing it to a CommandLine
and running a verb that reaches the process seam puts an arbitrary
error on the boundary''s doorstep — the only honest way to prove the
exit-1 / exit-70 split, including for a SUBCLASS of a declared error.
An edge object like the settled RecordingRunner: its recording is
mutable, and it is never domain.'>

    RaisingRunner class >> raising: aBlock [
        "A runner whose every run: evaluates aBlock — which signals."
        <category: 'instance creation'>
        ^self new setErrorBlock: aBlock
    ]

    setErrorBlock: aBlock [
        "Private — initialization from the class-side constructor."
        <category: 'private'>
        errorBlock := aBlock.
        commands := OrderedCollection new
    ]

    run: aCommandString [
        <category: 'runner protocol'>
        commands add: aCommandString.
        ^errorBlock value
    ]

    commands [
        "Every command line the double was asked to run, in order."
        <category: 'accessing'>
        ^commands asArray
    ]
]

SourceError subclass: DerivedSourceError [

    <comment: 'A SUBCLASS of the declared SourceError, defined only for
the boundary laws: on:do: catches it because Smalltalk''s exception
system already IS the taxonomy, where a chain comparing exception
classes for identity would miss it. It adds nothing — the settled
signalProblems: and problems are inherited — so the law observes
exactly the superclass''s protocol arriving at the boundary under a
different class.

It is deliberately a subclass of a DECLARED error, so the closed-set
law accounts for it the same way the boundary does: by coverage, not
by an extra name in a list.'>
]

Namespace current: Smalltalk.
