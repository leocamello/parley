"Parley Sprint 21 — acceptance scenarios S1-S34 (issue #23).

 DEPENDENCIES YOU ARE DEVELOPING. Two directories side by side is the
 workflow, and today it costs a parley publish after every edit. The
 shape is §8 decision 68 — a path dependency is an OVERLAY computed by
 the source layer, the fifth put-it-in-the-source application, so
 Resolver, both strategies, ConstraintLedger and every settled source
 class are untouched. The vocabulary is §8 decision 69 — path: and
 devDependency: are root-manifest-only and NEVER serialized, so
 #'parley-index' 1 is byte-identical and every entry published to date
 stays valid. The rider is §8 decision 83 — needs an index becomes a
 property of the manifest, so parley init then parley resolve stops
 failing by grammar.

 RISKIEST WORK LOWEST-NUMBERED. The overlay entering the snapshot
 (S1-S8) is the core surgery and every later scenario rests on it;
 exec (S9-S10), the lock and pipeline (S11-S14), publish and the dev
 audience (S15-S18), the reporting matrix (S19-S24), the flags
 (S25-S29) and the rider (S30-S33) build outward from it.

 FOUR SCENARIOS EXIST BECAUSE A CHEAPER BUILD PASSES ALL THE OTHERS.
 S2 is the one an overlay that merely FILLS A GAP fails after passing
 S1, because there the index publishes the same name at a higher
 version. S4 is the one a re-seed that forwards only the caller's own
 seeds fails, because the sibling's dependency is named in NEITHER the
 root Package.st NOR parley.lock. S14 is the one a build that conflated
 a #path pin with decision 25's empty-sha256 pin fails. And S34 is the
 one a NARROW-TO-LOCKED build fails after passing S1-S33: holding a
 drifted path pin at its locked version narrows to a version the
 overlay no longer describes, which is §8 decision 47's collapse
 arriving by composition rather than by anyone's intent.

 DECLARED PASSES IN RED (issue #23): EXACTLY ONE — testS33_..., the
 bound guard. A source-less parley install answering the #needsIndex
 usage error is true before this sprint's code exists, and that is the
 point: it is what holds the deferred mirror. Every other scenario
 drives vocabulary, a class, a flag or a tuple form the pre-sprint tree
 does not have.

 Every fixture directory is under tmp/, labelled per scenario — Sprint
 19 lost a scenario to one directory name colliding across two
 iterations of a driver loop — and removed recursively in tearDown,
 which unlocks before it removes. SIBLINGS SIT BESIDE THE WORKING
 DIRECTORY, never inside it, and are declared as RELATIVE strings: the
 lock must byte-preserve the author's own path, and a fixture declaring
 an absolute one could not fail when an implementation expanded it.
 Real processes appear only where the law under test IS execution
 (S9, S10, S13, S17), IN S29, whose fixture must PUBLISH real archives
 so decision 25 cannot refuse before the mode flag is consulted
 (amended at Gate B, from the probe that found the flag being ignored),
 AND IN S4, where the law under test is a sparse
 CLOSURE and the sparse transport reaches its base through curl —
 amended at GREEN step 11, from the probe rather than from the plan.
 A recording double there does not make the scenario cheaper, it makes
 it impossible: it records the fetch instead of performing it, and the
 verb then answers a missing-listing diagnosis over a listing that is
 demonstrably present in the base. No network is contacted anywhere,
 S4 included — its base is a file:// URL over a tmp/ directory."

Namespace current: Parley.

TestCase subclass: Sprint21AcceptanceTest [
    | fixtureDirs |

    <comment: 'The Sprint 21 acceptance scenarios: the overlay walk,
precedence, re-seed and refusals; exec loading a sibling fresh; the
#path lock tuple through the boundary and the install pipeline; the
publish refusal and the dev audience; the reporting matrix; the two
mode flags; decision 83''s three resolve states with its bound guard;
and the holding-map exclusion that a narrow-to-locked build fails.'>

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

    workDir: aLabel contents: aContentsString [
        ^self track:
            (PathDepFixtures workDirNamed: aLabel contents: aContentsString)
    ]

    sibling: aLabel [
        ^self track: (PathDepFixtures textSiblingNamed: aLabel)
    ]

    resultOf: anArgvArray in: aWorkDir runner: aRunner [
        ^PathDepFixtures resultOf: anArgvArray in: aWorkDir runner: aRunner
    ]

    resultOf: anArgvArray in: aWorkDir [
        ^self resultOf: anArgvArray in: aWorkDir runner: RecordingRunner new
    ]

    exists: aPath [
        ^(File name: aPath) exists
    ]

    lockTextIn: aWorkDir [
        ^PathDepFixtures lockTextIn: aWorkDir
    ]

    publishInto: aDestDir name: aName version: aVersionString label: aLabel [
        "Publish a REAL archive for aName at aVersionString into
         aDestDir — S13's precedent. An entry written with an empty
         #archive cannot install, and a scenario whose verb INSTALLS
         needs one that can; decision 25's no-published-archive answer
         is proved where it belongs, in S14."
        | author |
        author := self freshDir: aLabel.
        ExecFixtures writePackage: 'Parley define: [:pkg |
    pkg
        name: ''', aName, ''';
        version: ''', aVersionString, ''';
        summary: ''a fixture library'';
        author: ''fixture'';
        license: ''MIT'';
        fileIns: #(''Lib.st'') ]', SourceFixtures newline in: author.
        SourceFixtures write: 'Object subclass: Lib [ ]', SourceFixtures newline
            toFile: 'Lib.st' in: author.
        self assert: (self resultOf: (Array with: 'publish' with: aDestDir)
            in: author runner: ProcessRunner new) exitCode = 0
            description: 'the fixture library ', aName, ' ', aVersionString,
                ' did not publish'
    ]

    linesCarry: someLines needed: aNeedle [
        "Whether any line of someLines contains aNeedle as a substring
         — the settled containment idiom, used where a scenario asserts
         one line INSIDE a rendered answer whose other lines belong to a
         settled composition."
        ^someLines anySatisfy: [:line |
            CommandLineFixtures does: line include: aNeedle]
    ]

    "---- S1-S8: the overlay entering the snapshot ----"

    testS1_APathDependencyResolvesAndLocksItsDeclaredPath [
        "S1. The smallest whole feature: a manifest declaring
         dependency:path: resolves against the sibling's own
         declaration, and the lock records the pin with the #path tuple
         carrying the declared string BYTE-PRESERVED.

         The oracle is HAND-WRITTEN, never computed by the writer under
         test (Doc B §2.1's rule): an oracle produced by the code it
         checks cannot fail when that code is wrong."
        | work result declared |
        self sibling: 's21-1-text'.
        declared := PathDepFixtures declaredPathFor: 's21-1-text'.
        work := self workDir: 's21-1-work'
            contents: (PathDepFixtures rootDeclaring: declared).
        result := self resultOf: PathDepFixtures flaglessResolveArgv in: work.
        self assert: result exitCode = 0
            description: 'a path-only resolve answered exit ',
                result exitCode printString, ': ', result lines printString.
        self assert: (self lockTextIn: work)
            = (PathDepFixtures soleTextPinLockFor: declared)
            description: 'the lock reads ', (self lockTextIn: work) printString
    ]

    testS2_APathDependencyWinsOverAnIndexReleaseOfTheSameName [
        "S2. PRECEDENCE, PROVED WHERE IT COULD FAIL. The index publishes
         kernel-text 2.0.0 and the sibling declares 1.2.0; the pin is
         1.2.0. An overlay that merely filled a gap passes S1 and fails
         here, which is the whole reason this fixture publishes the same
         name at a higher version."
        | work index result declared |
        self sibling: 's21-2-text'.
        declared := PathDepFixtures declaredPathFor: 's21-2-text'.
        index := self freshDir: 's21-2-index'.
        SourceFixtures write: (PathDepFixtures textEntryAt: '2.0.0')
            toFile: 'kernel-text-2.0.0.st' in: index.
        work := self workDir: 's21-2-work'
            contents: (PathDepFixtures rootDeclaring: declared).
        result := self resultOf: (PathDepFixtures resolveArgvOn: index)
            in: work.
        self assert: result exitCode = 0
            description: result lines printString.
        self assert: (self lockTextIn: work)
            = (PathDepFixtures soleTextPinLockFor: declared)
            description: 'the path lost to the index: ',
                (self lockTextIn: work) printString
    ]

    testS3_TheWalkFollowsASiblingsPathAndDropsItsDevDependencies [
        "S3. The fixpoint walk follows a sibling's OWN path dependency
         and excludes its dev dependencies exactly as publish would (§8
         decision 69): the overlay is the development-time reading of
         the same projection publish makes at release time, which is
         also why it FOLLOWS a sibling's path dependency while publish
         REFUSES one."
        | work text b result lock |
        b := self track: (PathDepFixtures bSiblingNamed: 's21-3-b').
        text := self freshDir: 's21-3-text'.
        ExecFixtures writePackage: (PathDepFixtures walkingSiblingContentsOn:
            (PathDepFixtures declaredPathFor: 's21-3-b')) in: text.
        SourceFixtures write:
            (PathDepFixtures textSourceAnswering: PathDepFixtures firstShout)
            toFile: 'KernelText.st' in: text.
        work := self workDir: 's21-3-work'
            contents: (PathDepFixtures rootDeclaring:
                (PathDepFixtures declaredPathFor: 's21-3-text')).
        result := self resultOf: PathDepFixtures flaglessResolveArgv in: work.
        self assert: result exitCode = 0
            description: result lines printString.
        lock := self lockTextIn: work.
        self assert: (CommandLineFixtures does: lock include:
            (PathDepFixtures pathTupleFor: 'kernel-b' version: '2.5.0'
                path: (PathDepFixtures declaredPathFor: 's21-3-b')))
            description: 'the walk did not follow the sibling''s own path dependency: ', lock printString.
        self deny: (CommandLineFixtures does: lock include: 'kernel-lint')
            description: 'a sibling''s dev dependency reached the lock: ', lock printString
    ]

    testS4_TheReSeedReachesASparseBaseForANameOnlyTheSiblingDeclares [
        "S4. The re-seed, proved over the one transport that can fail
         it. The sibling declares an INDEX dependency named in NEITHER
         the root Package.st NOR parley.lock, so a sparse closure can
         only fetch its listing if the overlay's re-seed named it — the
         caller's decision-51 seeds union the siblings' declared
         dependency names, through the settled seededWith:.

         The fixture is built so the law cannot be vacuous: if
         kernel-streams appeared in either file, a base seeded the
         settled way would already have fetched it and this scenario
         would pass over an overlay that re-seeded nothing."
        | work base result runner baseUrl |
        self track: (PathDepFixtures seedingSiblingNamed: 's21-4-text').
        base := self freshDir: 's21-4-base'.
        SparseIndexFixtures publish: PathDepFixtures seedOnlyName
            version: '1.4.0' dependencies: #() in: base.
        work := self workDir: 's21-4-work'
            contents: (PathDepFixtures rootDeclaring:
                (PathDepFixtures declaredPathFor: 's21-4-text')).
        self deny: (CommandLineFixtures does: (ManifestEditFixtures packageContentsIn: work)
            include: PathDepFixtures seedOnlyName)
            description: 'the fixture names the sibling''s dependency in the root manifest, which makes this law vacuous'.
        self deny: (self exists: work, '/parley.lock')
            description: 'the fixture has a lock, which makes this law vacuous'.
        "--index TAKES A URL, NOT A DIRECTORY (amended mid-sprint, GREEN
         step 6). Every settled sparse law passes
         SparseIndexFixtures baseUrlFor:, which is a file:// URL over an
         ABSOLUTE path; this fixture was the odd one out and handed the
         bare directory, so the source never fetched anything.

         AND IT SPAWNS, which was the SECOND cause and the one that
         outlived the first (probed at GREEN step 11). The sparse
         transport reaches its base through curl; the default driver
         here wires a RecordingRunner, which records the command instead
         of running it, so nothing ever landed in the cache and the
         resolve answered `kernel-streams/versions.st: missing or
         unreadable listing'.

         THAT DIAGNOSIS NAMES THE CACHE PATH, NOT THE BASE PATH, and
         reading it the other way is the trap this comment exists to
         close: it looks exactly like an unpublished listing, and the
         repair it invites — publish kernel-streams' listing into the
         base tree — is a NO-OP, because SparseIndexFixtures publish:
         writes the listing and the entry together. Probed directly: the
         base already holds kernel-streams/versions.st carrying
         #(#'parley-listing' 1 #versions #('1.4.0')) before the verb
         runs. The transport was never given a way to fetch it.

         SO THE RUNNER IS THE COUNTING ONE, which delegates to the
         settled ProcessRunner and records what it delegated. That buys
         the law its MECHANISM assertion rather than only its outcome:
         the closure is made to show the curl it issued for the listing
         of a name that appears in neither the root manifest nor the
         lock. A base that had been seeded the settled way could not
         have issued it."
        baseUrl := SparseIndexFixtures baseUrlFor: base.
        runner := CountingProcessRunner new.
        result := self resultOf: (Array with: 'resolve' with: '--index'
            with: baseUrl) in: work runner: runner.
        self assert: result exitCode = 0
            description: result lines printString.
        self assert: (CommandLineFixtures does: (self lockTextIn: work)
            include: PathDepFixtures seedOnlyName)
            description: 'the closure never fetched the sibling''s dependency: ',
                (self lockTextIn: work) printString.
        self deny: (SparseIndexFixtures commands: runner commands
            naming: (SparseIndexFixtures listingUrlFor: baseUrl
                name: PathDepFixtures seedOnlyName)) isEmpty
            description: 'no curl fetched the re-seeded name''s listing: ',
                runner commands printString
    ]

    testS5_AConflictOverAnOverlaidNameNamesThePathProvenance [
        "S5. An index edge the sibling cannot satisfy is an ordinary
         conflict — never a silent fallback to the index's own 2.0.0 —
         and it carries ONE LINE naming the path provenance above the
         settled narration, in the held-pins-line placement: the
         resolver answered truthfully about the world it was given and
         cannot know a directory supplied one of its packages."
        | work index result declared |
        self sibling: 's21-5-text'.
        declared := PathDepFixtures declaredPathFor: 's21-5-text'.
        index := self freshDir: 's21-5-index'.
        SourceFixtures write: PathDepFixtures appEntryRequiringTextAtLeastTwo
            toFile: 'kernel-app-1.0.0.st' in: index.
        SourceFixtures write: (PathDepFixtures textEntryAt: '2.0.0')
            toFile: 'kernel-text-2.0.0.st' in: index.
        work := self workDir: 's21-5-work'
            contents: (PathDepFixtures rootDeclaring: declared
                andIndexDependency: 'kernel-app' constraint: '^1.0.0').
        result := self resultOf: (PathDepFixtures resolveArgvOn: index)
            in: work.
        self assert: result exitCode = 1
            description: 'the resolve answered exit ',
                result exitCode printString, ': ', result lines printString.
        self assert: result lines first = (PathDepFixtures
            conflictProvenanceLineFor: 'kernel-text' path: declared)
            description: 'the conflict opened with ',
                result lines first printString.
        self deny: (self exists: work, '/parley.lock')
            description: 'a conflict wrote a lock'
    ]

    testS6_OneNameFromTwoPathsIsRefusedNamingBothPaths [
        "S6. Two path dependencies declaring the same name from
         different directories: ONE diagnosis naming BOTH paths, exit 1,
         nothing written. Naming one would leave the operator to find
         the other.

         THE COLLISION IS CROSS-MANIFEST, and it has to be (amended
         mid-sprint, GREEN step 5). Declared TWICE IN ONE FILE this is
         an AUTHORING error, and build's duplicate rule (Doc B §3.4 item
         5, which quantifies over all three kinds) fires first with a
         better diagnosis — one file, one problem, naming the duplicate.
         That behaviour is correct and stays. The overlay's refusal
         governs the case a single manifest cannot express: the ROOT
         declares kernel-text at one directory and a SIBLING declares
         the same name at another, so no one file is wrong and only the
         composition can see it. This is the end-to-end driver for
         PathOverlayTest>>testOneNameFromTwoDirectoriesIsRefusedNaming
         Both, which proves the same refusal at the overlay's own level."
        | work result first second mid |
        self sibling: 's21-6-one'.
        self sibling: 's21-6-two'.
        mid := self track: (PathDepFixtures bSiblingNamed: 's21-6-mid').
        first := PathDepFixtures declaredPathFor: 's21-6-one'.
        second := PathDepFixtures declaredPathFor: 's21-6-two'.
        ExecFixtures writePackage: 'Parley define: [:pkg |
    pkg
        name: ''kernel-b'';
        version: ''2.5.0'';
        fileIns: #(''KernelB.st'');
        dependency: ''kernel-text'' path: ''', second, ''' ]',
            SourceFixtures newline in: mid.
        work := self workDir: 's21-6-work' contents: 'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''kernel-text'' path: ''', first, ''';
        dependency: ''kernel-b'' path: ''',
            (PathDepFixtures declaredPathFor: 's21-6-mid'), ''' ]',
            SourceFixtures newline.
        result := self resultOf: PathDepFixtures flaglessResolveArgv in: work.
        self assert: result exitCode = 1
            description: 'two paths for one name answered exit ',
                result exitCode printString, ': ', result lines printString.
        self assert: result lines = (Array with: (PathDepFixtures
            twoPathsRefusalFor: 'kernel-text' first: first second: second))
            description: result lines printString.
        self deny: (self exists: work, '/parley.lock')
            description: 'the refusal wrote a lock'
    ]

    testS7_AMissingSiblingDirectoryIsDiagnosedNamingTheDeclaredPath [
        "S7. A path dependency pointing at a directory that is not
         there: the boundary diagnosis NAMING THE DECLARED PATH, at
         exit 1, reached where the path is USED and never at build (Doc
         B §3.4 records the path raw; existence is not that pass's
         question)."
        | work result declared |
        declared := PathDepFixtures declaredPathFor: 's21-7-absent'.
        work := self workDir: 's21-7-work'
            contents: (PathDepFixtures rootDeclaring: declared).
        result := self resultOf: PathDepFixtures flaglessResolveArgv in: work.
        self assert: result exitCode = 1
            description: 'a missing sibling answered exit ',
                result exitCode printString, ': ', result lines printString.
        self assert: (self linesCarry: result lines needed: declared)
            description: 'the diagnosis never names the declared path: ',
                result lines printString.
        self deny: (self exists: work, '/parley.lock')
    ]

    testS8_AMalformedSiblingAnswersTheAuthoringDiagnosisNamingTheSibling [
        "S8. The settled authoring boundary is reused WHOLE, so a
         sibling whose Package.st fails validation answers the settled
         authoring diagnosis naming the SIBLING's path — never the
         root's. A diagnosis that named the root would send the operator
         to the wrong file, which is the blame failure this project has
         been most careful about."
        | work result |
        self track: (PathDepFixtures malformedSiblingNamed: 's21-8-text').
        work := self workDir: 's21-8-work'
            contents: (PathDepFixtures rootDeclaring:
                (PathDepFixtures declaredPathFor: 's21-8-text')).
        result := self resultOf: PathDepFixtures flaglessResolveArgv in: work.
        self assert: result exitCode = 1
            description: 'a malformed sibling answered exit ',
                result exitCode printString, ': ', result lines printString.
        self assert: (self linesCarry: result lines
            needed: 'parley-s21-8-text')
            description: 'the diagnosis never names the sibling: ',
                result lines printString.
        self deny: (self linesCarry: result lines needed: 's21-8-work/Package.st')
            description: 'the diagnosis blames the root manifest: ',
                result lines printString
    ]

    "---- S9-S10: exec reads the sibling fresh ----"

    testS9_ExecLoadsThePathDependencysClass [
        "S9. The child really loads the sibling's fileIns: a script
         sending a message defined only in the sibling runs and answers
         its result. A real process, because the law under test IS
         execution."
        | work captures answer |
        self sibling: 's21-9-text'.
        work := self workDir: 's21-9-work'
            contents: (PathDepFixtures rootDeclaring:
                (PathDepFixtures declaredPathFor: 's21-9-text')).
        self resultOf: PathDepFixtures flaglessResolveArgv in: work.
        SourceFixtures write: 'Transcript showCr: KernelText shout.',
            SourceFixtures newline
            toFile: 'probe.st' in: work.
        captures := AuthoringFixtures captureDirTracking: self tracker
            named: 's21-9-cap'.
        answer := AuthoringFixtures runShippedIn: work
            args: 'exec probe.st' captures: captures label: 's21-9'.
        self assert: (answer at: 1) = 0
            description: 'exec answered exit ', (answer at: 1) printString.
        self assert: (CommandLineFixtures does: (answer at: 2)
            include: PathDepFixtures firstShout)
            description: 'the child never loaded the sibling: ',
                (answer at: 2) printString
    ]

    testS10_EditingTheSiblingIsPickedUpOnTheNextExecWithNoPublish [
        "S10. THE WORKFLOW THIS SPRINT EXISTS FOR. Edit the sibling's
         SOURCE, re-run exec, and the change is picked up — with no
         publish, no rebuild and no re-registration in between. The
         alternative (rebuild and re-register the sibling's star per
         run) is named and ruled out in §8 decision 68 on stated
         grounds, and it is publish-per-edit in mechanism.

         The second half is the composed line: through a recording
         runner, the child invocation files in the sibling's own files
         AHEAD of the script, which is the mechanism the first half
         observes."
        | work text captures before after runner |
        text := self sibling: 's21-10-text'.
        work := self workDir: 's21-10-work'
            contents: (PathDepFixtures rootDeclaring:
                (PathDepFixtures declaredPathFor: 's21-10-text')).
        self resultOf: PathDepFixtures flaglessResolveArgv in: work.
        SourceFixtures write: 'Transcript showCr: KernelText shout.',
            SourceFixtures newline
            toFile: 'probe.st' in: work.
        captures := AuthoringFixtures captureDirTracking: self tracker
            named: 's21-10-cap'.
        before := AuthoringFixtures runShippedIn: work
            args: 'exec probe.st' captures: captures label: 's21-10-before'.
        SourceFixtures write:
            (PathDepFixtures textSourceAnswering: PathDepFixtures secondShout)
            toFile: 'KernelText.st' in: text.
        after := AuthoringFixtures runShippedIn: work
            args: 'exec probe.st' captures: captures label: 's21-10-after'.
        self assert: (CommandLineFixtures does: (before at: 2)
            include: PathDepFixtures firstShout)
            description: 'the first run answered ', (before at: 2) printString.
        self assert: (CommandLineFixtures does: (after at: 2)
            include: PathDepFixtures secondShout)
            description: 'the edit was not picked up: ',
                (after at: 2) printString.
        "THE IN-PROCESS HALF SPELLS ITS SCRIPT WORKDIR-RELATIVE, the
         same bare spelling the shipped-binary halves above prove
         (re-pinned at Sprint 22, closing the carried gap this
         comment's earlier form documented: the precondition now
         resolves the argv against the WORKING DIRECTORY, never the
         process cwd, so the bare 'probe.st' resolves under work and
         is no longer refused in-process). The needle carries the
         workdir-resolved path; the claim — the sibling's file-ins
         PRECEDE the script on the composed line — is unchanged and
         still falsifiable, since a build composing them in the other
         order fails it."
        runner := RecordingRunner new.
        self resultOf: (Array with: 'exec' with: 'probe.st')
            in: work runner: runner.
        self assert: runner commands size = 1
            description: runner commands printString.
        self assert: (CommandLineFixtures does: runner commands first
            include: 'KernelText.st ', work, '/probe.st')
            description: 'the sibling''s files do not precede the script: ',
                runner commands first printString
    ]

    "---- S11-S14: the lock and the install pipeline ----"

    testS11_ThePathTupleRoundTripsAndAPreSprintLockStillValidates [
        "S11. The tuple written by S1 validates through the settled lock
         boundary on the next verb — written, read, re-verified — and a
         PRE-SPRINT-21 lock carrying only #sha256 pins still validates
         unchanged, which is the half that proves the boundary WIDENED
         rather than moved."
        | work declared checked legacy old |
        self sibling: 's21-11-text'.
        declared := PathDepFixtures declaredPathFor: 's21-11-text'.
        work := self workDir: 's21-11-work'
            contents: (PathDepFixtures rootDeclaring: declared).
        self resultOf: PathDepFixtures flaglessResolveArgv in: work.
        checked := self resultOf: (Array with: 'check') in: work.
        self assert: checked exitCode = 0
            description: 'the written #path lock did not validate: ',
                checked lines printString.
        legacy := self workDir: 's21-11-legacy'
            contents: PathDepFixtures indexNeedingRootContents.
        PathDepFixtures writeLock: PathDepFixtures preSprintLockText
            in: legacy.
        old := self resultOf: (Array with: 'tree') in: legacy.
        self deny: old exitCode = 70
            description: 'a pre-Sprint-21 lock reached the undiagnosed boundary: ',
                old lines printString.
        self deny: (self linesCarry: old lines needed: 'parley.lock: ')
            description: 'a pre-Sprint-21 lock was refused by the boundary: ',
                old lines printString
    ]

    testS12_PinVerificationCoversTheThreeDeclaredKinds [
        "S12. PinVerification extends over the three declared kinds: a
         devDependency: declared in the manifest but MISSING from the
         lock is the settled missing-pin problem, and a PRESENT path pin
         verifies clean with NO CONSTRAINT CHECK — its version is the
         sibling's declaration, not a constraint of the root's, so there
         is nothing to fail."
        | pathOnly missing clean |
        pathOnly := PinVerification
            of: (ManifestFile load:
                (self manifestPathOfPathOnlyProject: 's21-12-a'))
            lock: (Resolution root: 'my-app'
                triples: (self pathTriplesFor: 'kernel-text')).
        self assert: pathOnly isValid
            description: 'a present path pin was reported as a problem: ',
                pathOnly problems printString.
        missing := PinVerification
            of: (ManifestFile load:
                (self manifestPathOfDevProject: 's21-12-b'))
            lock: (Resolution root: 'my-app' triples: Dictionary new).
        self deny: missing isValid
            description: 'a dev dependency missing from the lock verified clean'.
        self assert: missing problems size = 1
            description: missing problems printString.
        clean := PinVerification
            of: (ManifestFile load:
                (self manifestPathOfDevProject: 's21-12-c'))
            lock: (Resolution root: 'my-app'
                triples: (self indexTriplesFor: 'kernel-lint'
                    version: '1.4.0')).
        self assert: clean isValid
            description: clean problems printString
    ]

    manifestPathOfPathOnlyProject: aLabel [
        | work |
        self sibling: aLabel, '-text'.
        work := self workDir: aLabel
            contents: (PathDepFixtures rootDeclaring:
                (PathDepFixtures declaredPathFor: aLabel, '-text')).
        ^work, '/Package.st'
    ]

    manifestPathOfDevProject: aLabel [
        | work |
        work := self workDir: aLabel
            contents: (PathDepFixtures rootWithDevDependencyOn: 'kernel-lint'
                constraint: '^1.0.0').
        ^work, '/Package.st'
    ]

    pathTriplesFor: aName [
        | triples |
        triples := Dictionary new.
        triples at: aName put: (Array
            with: (Version fromString: PathDepFixtures siblingVersionString)
            with: '').
        ^triples
    ]

    indexTriplesFor: aName version: aVersionString [
        | triples |
        triples := Dictionary new.
        triples at: aName put: (Array
            with: (Version fromString: aVersionString)
            with: 'ab12000000000000000000000000000000000000000000000000000000000000').
        ^triples
    ]

    testS13_InstallSkipsAPathPinEntirely [
        "S13. Over a MIXED lock, index pins fetch, verify, store and
         register exactly as ever, while the #path pin is
         no-fetch/no-store/no-register: the CLI hands the Installer the
         PATH-FREE VIEW, so a path pin never enters the Doc D pipeline
         and Installer, InstalledSet and ContentStore never learn that
         paths exist.

         THE INDEX HALF IS A REAL PUBLISHED ARCHIVE, not an entry with
         an empty #archive: an index pin that could not install anyway
         would make the whole scenario vacuous — every command line
         would be absent, including the ones that must name kernel-json
         and must not name kernel-text."
        | author dest work runner result |
        self sibling: 's21-13-text'.
        author := self freshDir: 's21-13-author'.
        ExecFixtures writePackage:
            (PathDepFixtures libraryContentsWithDev: false) in: author.
        SourceFixtures write: PathDepFixtures librarySource
            toFile: 'Json.st' in: author.
        dest := self freshDir: 's21-13-index'.
        self assert: (self resultOf: (Array with: 'publish' with: dest)
            in: author runner: ProcessRunner new) exitCode = 0
            description: 'the fixture library did not publish'.
        work := self workDir: 's21-13-work'
            contents: (PathDepFixtures rootDeclaring:
                (PathDepFixtures declaredPathFor: 's21-13-text')
                andIndexDependency: 'kernel-json' constraint: '^0.3.0').
        self resultOf: (PathDepFixtures resolveArgvOn: dest) in: work.
        runner := RecordingRunner new.
        result := self resultOf: (Array with: 'install' with: '--source'
            with: dest) in: work runner: runner.
        self assert: result exitCode = 0
            description: 'install answered exit ',
                result exitCode printString, ': ', result lines printString.
        self assert: (runner commands anySatisfy: [:command |
            CommandLineFixtures does: command include: 'kernel-json'])
            description: 'the index pin never reached registration: ',
                runner commands printString.
        runner commands do: [:command |
            self deny: (CommandLineFixtures does: command
                include: 'kernel-text')
                description: 'a path pin reached the install pipeline: ',
                    command printString]
    ]

    testS14_AnEmptyDigestIndexPinStillAnswersItsSettledDiagnosis [
        "S14. THE DECISION-25 DISTINCTNESS GUARD. On a fixture that also
         carries a path pin, an INDEX pin whose entry declares
         #archive #() still answers the settled no-published-archive
         diagnosis. The two states are different and answer differently:
         '' records an index release that published no archive, #path
         records a pin no index supplied, and a build that conflated
         them would either lose this diagnosis or manufacture it for
         every sibling."
        | work index result |
        self sibling: 's21-14-text'.
        index := self freshDir: 's21-14-index'.
        SourceFixtures write: (PathDepFixtures plainEntryFor: 'kernel-a'
            version: '1.0.0' dependencies: '')
            toFile: 'kernel-a-1.0.0.st' in: index.
        work := self workDir: 's21-14-work'
            contents: (PathDepFixtures rootDeclaring:
                (PathDepFixtures declaredPathFor: 's21-14-text')
                andIndexDependency: 'kernel-a' constraint: '^1.0.0').
        result := self resultOf: (Array with: 'install' with: '--source'
            with: index) in: work.
        self assert: result exitCode = 1
            description: 'the empty-digest index pin answered exit ',
                result exitCode printString, ': ', result lines printString.
        self assert: (self linesCarry: result lines
            needed: 'no published archive')
            description: 'the settled empty-sha256 diagnosis was lost: ',
                result lines printString.
        self deny: (self linesCarry: result lines needed: 'kernel-text')
            description: 'the path pin drew the empty-digest diagnosis: ',
                result lines printString
    ]

    "---- S15-S18: publish refuses, and the dev audience ----"

    testS15_PublishRefusesAPathDeclaringManifestBeforeAnyProcess [
        "S15. Doc F §1 STEP 0: a release cannot depend on somebody's
         laptop. One PublishError problem naming the dependency and its
         declared path, nothing written, NO PROCESS SPAWNED — the
         refusal is step 0, ahead of the destination check, the
         pre-flight and the build, so the recording runner must be
         empty."
        | work dest runner result declared |
        self sibling: 's21-15-text'.
        declared := PathDepFixtures declaredPathFor: 's21-15-text'.
        dest := self freshDir: 's21-15-dest'.
        work := self workDir: 's21-15-work'
            contents: (PathDepFixtures rootDeclaring: declared).
        runner := RecordingRunner new.
        result := self resultOf: (Array with: 'publish' with: dest)
            in: work runner: runner.
        self assert: result exitCode = 1
            description: 'publish answered exit ',
                result exitCode printString, ': ', result lines printString.
        self assert: result lines = (Array with: (PathDepFixtures
            publishPathRefusalFor: 'kernel-text' path: declared))
            description: result lines printString.
        self assert: runner commands = #()
            description: 'publish spawned ', runner commands printString.
        self assert: (File name: dest) files isEmpty
            description: 'publish wrote into the destination it refused'
    ]

    testS16_AnEntryIsByteIdenticalWithAndWithoutDevDependencies [
        "S16. ONE manifest in two spellings — identical in every field an
         entry carries, differing only in whether it declares dev
         dependencies — writes BYTE-IDENTICAL #'parley-index' 1 entries.

         True by construction today, and that is exactly why it is a
         law: dev dependencies live in their own manifest collection the
         entry writer never reads, and true-by-construction is how the
         last three drift families started (§8 decision 69)."
        | withDev withoutDev first second |
        withDev := self loadedLibraryWithDev: true label: 's21-16-with'.
        withoutDev := self loadedLibraryWithDev: false label: 's21-16-without'.
        first := WriteStream on: String new.
        second := WriteStream on: String new.
        IndexEntryWriter write: withDev
            archive: 'kernel-json-0.3.1.star'
            sha256: 'ab12000000000000000000000000000000000000000000000000000000000000'
            on: first.
        IndexEntryWriter write: withoutDev
            archive: 'kernel-json-0.3.1.star'
            sha256: 'ab12000000000000000000000000000000000000000000000000000000000000'
            on: second.
        self deny: withDev devDependencies isEmpty
            description: 'the with-dev fixture declares no dev dependency, which makes this law vacuous'.
        self assert: withoutDev devDependencies isEmpty.
        self assert: first contents = second contents
            description: 'the entries differ: ', first contents printString,
                ' versus ', second contents printString
    ]

    loadedLibraryWithDev: aBoolean label: aLabel [
        | work |
        work := self freshDir: aLabel.
        ExecFixtures writePackage:
            (PathDepFixtures libraryContentsWithDev: aBoolean) in: work.
        SourceFixtures write: PathDepFixtures librarySource
            toFile: 'Json.st' in: work.
        ^ManifestFile load: work, '/Package.st'
    ]

    testS17_ADevDependencyIsResolvedPinnedAndInstalledForTheRoot [
        "S17. Dev dependencies are resolved and installed FOR THE ROOT
         MANIFEST ALONE: kernel-lint is pinned in #packages
         UNDISTINGUISHED (the lock records provenance and does not
         record audience, §8 decision 69) and reaches the same pipeline
         every other pin does."
        | work index result |
        index := self freshDir: 's21-17-index'.
        SourceFixtures write: (PathDepFixtures plainEntryFor: 'kernel-lint'
            version: '1.4.0' dependencies: '')
            toFile: 'kernel-lint-1.4.0.st' in: index.
        work := self workDir: 's21-17-work'
            contents: (PathDepFixtures rootWithDevDependencyOn: 'kernel-lint'
                constraint: '^1.0.0').
        result := self resultOf: (PathDepFixtures resolveArgvOn: index)
            in: work.
        self assert: result exitCode = 0
            description: result lines printString.
        self assert: (self lockTextIn: work) = (PathDepFixtures
            lockTextRoot: 'my-app'
            packages: '#(''kernel-lint'' ''1.4.0'' #sha256 '''')')
            description: 'the dev pin is not an undistinguished #packages row: ',
                (self lockTextIn: work) printString
    ]

    testS18_AConsumerNeverReceivesTheAuthorsDevDependencies [
        "S18. A consumer of a published package receives no dev
         dependency of its author's: publish the library, then resolve
         it from a SECOND working directory. kernel-lint is in neither
         the consumer's resolution nor its lock — and the mechanism is
         that it was never serialized, so there is nothing for the
         consumer to reconstruct."
        | author dest consumer result |
        author := self freshDir: 's21-18-author'.
        ExecFixtures writePackage:
            (PathDepFixtures libraryContentsWithDev: true) in: author.
        SourceFixtures write: PathDepFixtures librarySource
            toFile: 'Json.st' in: author.
        dest := self freshDir: 's21-18-dest'.
        self assert: (self resultOf: (Array with: 'publish' with: dest)
            in: author runner: ProcessRunner new) exitCode = 0
            description: 'the library did not publish'.
        consumer := self workDir: 's21-18-consumer'
            contents: 'Parley define: [:pkg |
    pkg
        name: ''consumer'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''kernel-json'' constraint: ''^0.3.0'' ]',
            SourceFixtures newline.
        result := self resultOf: (PathDepFixtures resolveArgvOn: dest)
            in: consumer.
        self assert: result exitCode = 0
            description: result lines printString.
        self deny: (CommandLineFixtures does: (self lockTextIn: consumer)
            include: 'kernel-lint')
            description: 'the author''s dev dependency reached the consumer: ',
                (self lockTextIn: consumer) printString
    ]

    "---- S19-S24: the reporting matrix ----"

    testS19_SearchNeverReportsAPathSuppliedName [
        "S19. search enumerates INDEX names only. A path-supplied name
         the index does not publish never appears — reporting it would
         be §8 decision 80's confident partial answer inverted: a result
         claiming the index publishes something it does not."
        | work index result |
        self sibling: 's21-19-text'.
        index := self freshDir: 's21-19-index'.
        SourceFixtures write: (PathDepFixtures plainEntryFor: 'kernel-a'
            version: '1.0.0' dependencies: '')
            toFile: 'kernel-a-1.0.0.st' in: index.
        work := self workDir: 's21-19-work'
            contents: (PathDepFixtures rootDeclaring:
                (PathDepFixtures declaredPathFor: 's21-19-text')
                andIndexDependency: 'kernel-a' constraint: '^1.0.0').
        "The overlay must really supply the name, or this scenario
         proves only that search omits a package nothing offers."
        self assert: (self resultOf: (PathDepFixtures resolveArgvOn: index)
            in: work) exitCode = 0
            description: 'the fixture never overlaid kernel-text at all'.
        result := self resultOf: (Array with: 'search' with: 'kernel'
            with: '--source' with: index) in: work.
        self assert: result exitCode = 0
            description: result lines printString.
        self deny: (self linesCarry: result lines needed: 'kernel-text')
            description: 'search reported a path-supplied name: ',
                result lines printString.
        self assert: (self linesCarry: result lines needed: 'kernel-a')
            description: 'search lost the index''s own name: ',
                result lines printString
    ]

    testS20_InfoOnAPathSuppliedNameAnswersTheRuledSentence [
        "S20. info answers the INDEX's publications. On a name supplied
         only by a path it answers one ruled sentence naming the path
         provenance and that the index does not publish it, at exit 1 —
         the settled unknown-package answer EXTENDED, never
         contradicted."
        | work index result declared |
        self sibling: 's21-20-text'.
        declared := PathDepFixtures declaredPathFor: 's21-20-text'.
        index := self freshDir: 's21-20-index'.
        SourceFixtures write: (PathDepFixtures plainEntryFor: 'kernel-a'
            version: '1.0.0' dependencies: '')
            toFile: 'kernel-a-1.0.0.st' in: index.
        work := self workDir: 's21-20-work'
            contents: (PathDepFixtures rootDeclaring: declared).
        result := self resultOf: (Array with: 'info' with: 'kernel-text'
            with: '--source' with: index) in: work.
        self assert: result exitCode = 1
            description: 'info answered exit ', result exitCode printString.
        self assert: result lines = (Array with: (PathDepFixtures
            infoPathProvenanceLineFor: 'kernel-text' path: declared))
            description: result lines printString
    ]

    testS21_OutdatedRendersThePathMarkerBesideTheTransitiveOne [
        "S21. outdated renders a path pin's allowed column as the SECOND
         declared marker in §8 decision 82's family, naming the path,
         while its published column stays the index's answer. The two
         markers are distinguished ON ONE FIXTURE, because a build that
         reused the transitive marker for a path pin would pass every
         law that drove them apart."
        | work index result pathLine transitiveLine declared |
        self sibling: 's21-21-text'.
        declared := PathDepFixtures declaredPathFor: 's21-21-text'.
        index := self freshDir: 's21-21-index'.
        SourceFixtures write: (PathDepFixtures textEntryAt: '2.0.0')
            toFile: 'kernel-text-2.0.0.st' in: index.
        "kernel-a PINS kernel-dep EXACTLY (amended mid-sprint, GREEN
         step 5). Under the caret the resolver picked kernel-dep 1.9.0,
         the newest published, so the transitive pin was never behind
         anything and the contrast half of this law could not be
         satisfied on any build. An exact edge lands the transitive pin
         at 1.0.0 while 1.9.0 exists — which is what makes it OUTDATED
         and its allowed column a marker rather than a version. Nothing
         moves after the resolve; the fixture is arranged before it."
        SourceFixtures write: (PathDepFixtures plainEntryFor: 'kernel-a'
            version: '1.0.0' dependencies: '#(''kernel-dep'' ''=1.0.0'')')
            toFile: 'kernel-a-1.0.0.st' in: index.
        SourceFixtures write: (PathDepFixtures plainEntryFor: 'kernel-dep'
            version: '1.0.0' dependencies: '')
            toFile: 'kernel-dep-1.0.0.st' in: index.
        SourceFixtures write: (PathDepFixtures plainEntryFor: 'kernel-dep'
            version: '1.9.0' dependencies: '')
            toFile: 'kernel-dep-1.9.0.st' in: index.
        work := self workDir: 's21-21-work'
            contents: (PathDepFixtures rootDeclaring: declared
                andIndexDependency: 'kernel-a' constraint: '=1.0.0').
        self resultOf: (PathDepFixtures resolveArgvOn: index) in: work.
        result := self resultOf: (Array with: 'outdated' with: '--source'
            with: index) in: work.
        self assert: result exitCode = 0
            description: result lines printString.
        pathLine := result lines detect: [:line |
            CommandLineFixtures does: line include: 'kernel-text']
            ifNone: [nil].
        transitiveLine := result lines detect: [:line |
            CommandLineFixtures does: line include: 'kernel-dep']
            ifNone: [nil].
        self deny: pathLine isNil
            description: 'outdated omitted the path pin: ',
                result lines printString.
        self deny: transitiveLine isNil
            description: 'the fixture carries no transitive pin, which makes the contrast vacuous: ',
                result lines printString.
        self assert: (CommandLineFixtures does: pathLine include:
            (PathDepFixtures pathAllowedMarkerFor: declared))
            description: 'the path pin rendered ', pathLine printString.
        self assert: (CommandLineFixtures does: pathLine include: '2.0.0')
            description: 'the published column is not the index''s answer: ',
                pathLine printString.
        self assert: (CommandLineFixtures does: transitiveLine include:
            CLI unconstrainedAllowedMarker)
            description: 'the transitive marker moved: ',
                transitiveLine printString
    ]

    testS22_WhyNamesTheDeclaredDirectoryInTheChainHop [
        "S22. why names the declared directory in the chain hop, FROM
         THE LOCK'S OWN PROVENANCE. The operator asked why a pin exists,
         and a directory you declared is the answer — where an index pin
         names the constraint that demanded it."
        | work result declared |
        self sibling: 's21-22-text'.
        declared := PathDepFixtures declaredPathFor: 's21-22-text'.
        work := self workDir: 's21-22-work'
            contents: (PathDepFixtures rootDeclaring: declared).
        self resultOf: PathDepFixtures flaglessResolveArgv in: work.
        result := self resultOf: (Array with: 'why' with: 'kernel-text')
            in: work.
        self assert: result exitCode = 0
            description: result lines printString.
        self assert: result lines size = 1
            description: result lines printString.
        self assert: (CommandLineFixtures does: result lines first include:
            (PathDepFixtures whyHopTextFor: 'kernel-text'
                version: PathDepFixtures siblingVersionString
                path: declared))
            description: 'the hop reads ', result lines first printString
    ]

    testS23_CheckDiagnosesADriftedDeclarationAndIgnoresAContentEdit [
        "S23. check's DRIFT LEG, with its bound proved on the same
         fixture. Bump the sibling's DECLARED version without touching
         the lock and check reports a problem naming parley resolve, at
         exit 1 — the lock is then a stale statement about the code exec
         actually loads. Edit the sibling's file CONTENTS with the
         declared version unchanged and check stays clean: the leg
         compares the declared version through the settled ManifestFile
         and NEVER file contents, because loading fresh content is
         exec's job and diagnosing a stale pin is this one's."
        | work text declared drifted edited |
        text := self sibling: 's21-23-text'.
        declared := PathDepFixtures declaredPathFor: 's21-23-text'.
        work := self workDir: 's21-23-work'
            contents: (PathDepFixtures rootDeclaring: declared).
        self resultOf: PathDepFixtures flaglessResolveArgv in: work.
        SourceFixtures write:
            (PathDepFixtures textSourceAnswering: PathDepFixtures secondShout)
            toFile: 'KernelText.st' in: text.
        edited := self resultOf: (Array with: 'check') in: work.
        self assert: edited exitCode = 0
            description: 'a contents edit was diagnosed as drift: ',
                edited lines printString.
        ExecFixtures writePackage: (PathDepFixtures textSiblingContentsAt:
            PathDepFixtures driftedVersionString) in: text.
        drifted := self resultOf: (Array with: 'check') in: work.
        self assert: drifted exitCode = 1
            description: 'a drifted declaration answered exit ',
                drifted exitCode printString, ': ', drifted lines printString.
        self assert: (drifted lines includes: (PathDepFixtures
            driftProblemFor: 'kernel-text'
            pinned: PathDepFixtures siblingVersionString
            declared: PathDepFixtures driftedVersionString
            path: declared))
            description: drifted lines printString
    ]

    testS24_ChecksRetirementLegPassesPathPinsBy [
        "S24. check's retirement leg passes path pins by — retirement is
         an index owner's assertion, and NO INDEX PUBLISHED THIS PIN.
         The index publishes AND retires kernel-text at the very version
         the path supplies, so a leg that keyed on (name, version) alone
         would report it; a retired INDEX pin in the same fixture still
         must be reported, which is what stops this scenario from
         passing over a leg that was simply deleted."
        | work index result |
        self sibling: 's21-24-text'.
        index := self freshDir: 's21-24-index'.
        SourceFixtures write: (PathDepFixtures textEntryAt:
            PathDepFixtures siblingVersionString)
            toFile: 'kernel-text-1.2.0.st' in: index.
        SourceFixtures write: (PathDepFixtures plainEntryFor: 'kernel-old'
            version: '1.0.0' dependencies: '')
            toFile: 'kernel-old-1.0.0.st' in: index.
        work := self workDir: 's21-24-work'
            contents: (PathDepFixtures rootDeclaring:
                (PathDepFixtures declaredPathFor: 's21-24-text')
                andIndexDependency: 'kernel-old' constraint: '^1.0.0').
        self resultOf: (PathDepFixtures resolveArgvOn: index) in: work.
        "THE RETIREMENT LANDS AFTER THE LOCK, which is the only order in
         which a PINNED retired release exists at all (amended
         mid-sprint, GREEN step 5). Written before the resolve, the
         record retired kernel-old 1.0.0 — the sole published version of
         the root's only index dependency — so fresh resolution could
         pick nothing, no lock was written, and check answered the
         missing-lock line instead of its retirement leg. Retiring after
         the lock is the ordinary real sequence and the one the settled
         retirement laws build."
        SourceFixtures write: (PathDepFixtures retirementRecordForTextAt:
            PathDepFixtures siblingVersionString)
            toFile: 'retired.st' in: index.
        result := self resultOf: (Array with: 'check' with: '--source'
            with: index) in: work.
        self assert: result exitCode = 1
            description: 'the retired index pin drew no problem: ',
                result lines printString.
        self assert: (self linesCarry: result lines
            needed: 'which the index has retired')
            description: result lines printString.
        result lines do: [:line |
            self deny: ((CommandLineFixtures does: line
                include: 'which the index has retired')
                and: [CommandLineFixtures does: line include: 'kernel-text'])
                description: 'the path pin drew a retirement problem: ',
                    line printString]
    ]

    "---- S25-S29: the two mode flags ----"

    testS25_OfflineRefusesAWiredGitAndIndexSourceSpawningNothing [
        "S25. --offline means THIS INVOCATION SPAWNS NO git AND NO curl,
         enforced at source wiring: a wired --git or --index answers one
         declared line naming the transport, at exit 1, with the runner
         empty. --source is unaffected, because a local directory is
         what offline MEANS — and that half is the contrast that makes
         the claim falsifiable rather than a blanket refusal."
        | work index runner |
        work := self workDir: 's21-25-work'
            contents: PathDepFixtures emptyRootContents.
        (Array with: '--git' with: '--index') do: [:flag |
            | result |
            runner := RecordingRunner new.
            result := self resultOf: (Array with: 'resolve' with: flag
                with: 'tmp/parley-s21-25-remote'
                with: PathDepFixtures offlineFlag)
                in: work runner: runner.
            self assert: result exitCode = 1
                description: flag, ' under --offline answered exit ',
                    result exitCode printString, ': ', result lines printString.
            self assert: result lines
                = (Array with: (PathDepFixtures offlineRefusalFor: flag))
                description: result lines printString.
            self assert: runner commands = #()
                description: flag, ' under --offline spawned ',
                    runner commands printString].
        index := self freshDir: 's21-25-index'.
        self assert: (self resultOf: (Array with: 'resolve' with: '--source'
            with: index with: PathDepFixtures offlineFlag) in: work)
            exitCode = 0
            description: '--source under --offline was refused'
    ]

    testS26_OfflineRefusesAConfigSuppliedNetworkSourceIdentically [
        "S26. The guard is keyed off the settled sourceFlags and knows
         nothing about ROUTES: a source declared in parley.config.st is
         refused exactly as one given on the argv, with the same line
         and the same empty runner. A guard that read only the argv
         would let the commonest real setup — the flag written down once
         in the project — walk straight past it."
        | work runner result |
        work := self workDir: 's21-26-work'
            contents: PathDepFixtures emptyRootContents.
        SourceFixtures write:
            '#(#''parley-config'' 1 #source '''' #git ''tmp/parley-s21-26-remote'' #index '''')',
            SourceFixtures newline
            toFile: 'parley.config.st' in: work.
        runner := RecordingRunner new.
        result := self resultOf: (Array with: 'resolve'
            with: PathDepFixtures offlineFlag) in: work runner: runner.
        self assert: result exitCode = 1
            description: 'the config-supplied git source answered exit ',
                result exitCode printString, ': ', result lines printString.
        self assert: result lines
            = (Array with: (PathDepFixtures offlineRefusalFor: '--git'))
            description: result lines printString.
        self assert: runner commands = #()
            description: 'the refusal spawned ', runner commands printString
    ]

    testS27_LockedWithACurrentLockIsOrdinarySuccess [
        "S27. --locked means THIS INVOCATION DOES NOT CHANGE
         parley.lock. A current lock is ordinary success at exit 0 with
         the file byte-identical — a flag that refused a lock it agreed
         with would be useless in the CI job it exists for."
        | work before after result |
        self sibling: 's21-27-text'.
        work := self workDir: 's21-27-work'
            contents: (PathDepFixtures rootDeclaring:
                (PathDepFixtures declaredPathFor: 's21-27-text')).
        self resultOf: PathDepFixtures flaglessResolveArgv in: work.
        before := self lockTextIn: work.
        result := self resultOf: (Array with: 'resolve'
            with: PathDepFixtures lockedFlag) in: work.
        after := self lockTextIn: work.
        self assert: result exitCode = 0
            description: 'a current lock under --locked answered exit ',
                result exitCode printString, ': ', result lines printString.
        self assert: after = before
            description: 'the lock moved under --locked: ', after printString
    ]

    testS28_LockedRefusesAMovedManifestNamingTheFirstDifferingPin [
        "S28. When the manifest has moved, --locked answers exit 1
         naming the FIRST DIFFERING PIN in sorted order and writes
         NOTHING. Sorted order rather than discovery order, because the
         answer must be the same on every machine — the byte-stability
         rule applied to a diagnosis."
        | work index before result |
        index := self freshDir: 's21-28-index'.
        SourceFixtures write: (PathDepFixtures plainEntryFor: 'kernel-a'
            version: '1.0.0' dependencies: '')
            toFile: 'kernel-a-1.0.0.st' in: index.
        SourceFixtures write: (PathDepFixtures plainEntryFor: 'kernel-a'
            version: '2.0.0' dependencies: '')
            toFile: 'kernel-a-2.0.0.st' in: index.
        work := self workDir: 's21-28-work' contents: 'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''kernel-a'' constraint: ''=1.0.0'' ]',
            SourceFixtures newline.
        self resultOf: (PathDepFixtures resolveArgvOn: index) in: work.
        before := self lockTextIn: work.
        ExecFixtures writePackage: 'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''kernel-a'' constraint: ''=2.0.0'' ]',
            SourceFixtures newline in: work.
        result := self resultOf: (Array with: 'resolve' with: '--source'
            with: index with: PathDepFixtures lockedFlag) in: work.
        self assert: result exitCode = 1
            description: 'a moved manifest under --locked answered exit ',
                result exitCode printString, ': ', result lines printString.
        self assert: result lines = (Array with: (PathDepFixtures
            lockedRefusalFor: 'kernel-a' pinned: '1.0.0' would: '2.0.0'))
            description: result lines printString.
        self assert: (self lockTextIn: work) = before
            description: 'the lock changed under --locked: ',
                (self lockTextIn: work) printString
    ]

    testS29_AddUnderLockedLeavesTheManifestAndLockByteIdentical [
        "S29. --locked composes with every verb that writes the lock,
         add included: the manifest and the lock move together or not at
         all (Doc B §2.1), so a refused add under the mode flag leaves
         BOTH byte-identical. A build that enforced --locked only at the
         write itself would leave the edited Package.st behind, which is
         precisely the state PinVerification exists to call broken.

         STRENGTHENED AT GATE B, AND IT WAS GREEN BY CONSTRUCTION UNTIL
         NOW — the sprint's FOURTH instance of that class. Two defects
         compounded. The entries were written with plainEntryFor:, whose
         #archive is empty, so add answered decision 25's
         no-published-archive diagnosis at exit 1 and never reached the
         mode flag at all; and this law asserted only the EXIT CODE and
         the byte-identity, both of which that wrong refusal satisfies.
         Driven with --locked REMOVED the law passed identically, which
         is the definition of proving nothing about the flag.

         So: REAL ARCHIVES, so the verb runs far enough to reach the one
         enforcement site; and the answer is asserted against the
         DECLARED lockedRefusalFor: wording, not merely against exit 1.
         The portable half — wherever two refusal paths share an exit
         code, assert the diagnosis's own line and never just the code.

         What it caught: add and remove under --locked answered exit 0
         with the ordinary success pin-lines while writing nothing,
         because gst 3.2.5's Exception>>pass RESUMES after the inner
         on:do: instead of unwinding (see CLI>>addResolving:). The
         atomicity half of this law was always true; the exit code and
         the lines were not."
        | work index manifestBefore lockBefore result |
        index := self freshDir: 's21-29-index'.
        "REAL ARCHIVES (S13's precedent, S34's amendment). An entry with
         an empty #archive cannot install, and decision 25's diagnosis
         would refuse BEFORE --locked is ever consulted — which is
         exactly how this law came to pass against a build that ignored
         the flag."
        self publishInto: index name: 'kernel-a' version: '1.0.0'
            label: 's21-29-a'.
        self publishInto: index name: 'kernel-b' version: '1.0.0'
            label: 's21-29-b'.
        work := self workDir: 's21-29-work' contents: 'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''kernel-a'' constraint: ''^1.0.0'' ]',
            SourceFixtures newline.
        self resultOf: (PathDepFixtures resolveArgvOn: index) in: work.
        manifestBefore := ManifestEditFixtures packageContentsIn: work.
        lockBefore := self lockTextIn: work.
        "THE ARGV IS BUILT IN TWO GROUPS AND CONCATENATED: 3.2.5's
         Array class answers with:with:with:with:with: and nothing
         longer, so a sixth keyword in one chain is a
         doesNotUnderstand at the first send of this method — the
         declared-table group idiom, applied to a six-element argv."
        result := self resultOf: ((Array with: 'add' with: 'kernel-b'
            with: '^1.0.0'), (Array with: '--source' with: index
                with: PathDepFixtures lockedFlag)) in: work.
        self assert: result exitCode = 1
            description: 'add under --locked answered exit ',
                result exitCode printString, ': ', result lines printString.
        "THE DIAGNOSIS'S OWN LINE, not merely the exit code. kernel-b is
         a pin the lock does not carry, so the declared refusal names it
         with the absent side rendered as such — and no OTHER refusal
         that happens to exit 1 can satisfy this."
        self assert: result lines = (Array with: (PathDepFixtures
            lockedRefusalFor: 'kernel-b'
            pinned: PathDepFixtures absentPinText would: '1.0.0'))
            description: 'add under --locked answered ',
                result lines printString.
        self assert: (ManifestEditFixtures packageContentsIn: work) = manifestBefore
            description: 'add under --locked changed Package.st'.
        self assert: (self lockTextIn: work) = lockBefore
            description: 'add under --locked changed parley.lock'
    ]

    "---- S30-S33: decision 83's three states, and the bound ----"

    testS30_InitThenFlaglessResolveSucceeds [
        "S30. THE FIRST-SESSION SEQUENCE, CLOSED. parley init followed
         by a flagless parley resolve answers the settled confirmation
         line at exit 0 and writes the (empty) lock. It used to fail by
         GRAMMAR rather than by need: the template declares no
         dependency, so there was never an index to want."
        | work init result |
        work := self freshDir: 's21-30-work'.
        init := self resultOf: (Array with: 'init') in: work.
        self assert: init exitCode = 0
            description: init lines printString.
        result := self resultOf: PathDepFixtures flaglessResolveArgv in: work.
        self assert: result exitCode = 0
            description: 'init then resolve answered exit ',
                result exitCode printString, ': ', result lines printString.
        self assert: result lines
            = (Array with: 'no dependencies to resolve - wrote parley.lock')
            description: result lines printString.
        self assert: (self exists: work, '/parley.lock')
            description: 'resolve answered success without writing the lock'
    ]

    testS31_APathOnlyManifestResolvesFlaglessOverTheOverlayAlone [
        "S31. The second state: a path-only manifest resolves with NO
         base source wired at all — the overlay stands alone (Doc C
         §1.3), and the lock carries the #path pins."
        | work result declared |
        self sibling: 's21-31-text'.
        declared := PathDepFixtures declaredPathFor: 's21-31-text'.
        work := self workDir: 's21-31-work'
            contents: (PathDepFixtures rootDeclaring: declared).
        result := self resultOf: PathDepFixtures flaglessResolveArgv in: work.
        self assert: result exitCode = 0
            description: 'a path-only flagless resolve answered exit ',
                result exitCode printString, ': ', result lines printString.
        self assert: (self lockTextIn: work)
            = (PathDepFixtures soleTextPinLockFor: declared)
            description: (self lockTextIn: work) printString
    ]

    testS32_AnIndexNeedingManifestWithNoSourceRefusesInsideTheVerb [
        "S32. The third state: an index-needing dependency and no source
         wired is ONE DECLARED REFUSAL at exit 1 on §8 decision 80's
         precedent — the argv is well formed and the project is the
         limit. It names what the manifest declares and the flags or
         parley.config.st that can answer, NEVER the usage block, and
         writes nothing."
        | work result |
        work := self workDir: 's21-32-work'
            contents: PathDepFixtures indexNeedingRootContents.
        result := self resultOf: PathDepFixtures flaglessResolveArgv in: work.
        self assert: result exitCode = 1
            description: 'the third state answered exit ',
                result exitCode printString, ': ', result lines printString.
        self assert: result lines = (Array with: (PathDepFixtures
            needsIndexRefusalFor: (Array with:
                PathDepFixtures indexNeedingName)))
            description: result lines printString.
        result lines do: [:line |
            self deny: (CommandLineFixtures does: line include: 'usage: parley')
                description: 'the refusal answered the usage block: ',
                    line printString].
        self deny: (self exists: work, '/parley.lock')
            description: 'the refusal wrote a lock'
    ]

    testS33_ASourceLessInstallStillAnswersTheNeedsIndexUsageError [
        "S33. THE BOUND GUARD, AND THE SPRINT'S ONE DECLARED
         PASS-IN-RED. The mirror is deferred with its trigger (§8
         decision 83): install, update, add, remove, why, tree and check
         keep requiring a source BY GRAMMAR. This law is what holds that
         bound — it is true before this sprint's code exists, and it
         must still be true after, which is the only way an
         over-narrowing resolve change gets caught rather than
         discovered by a user."
        | work result |
        work := self workDir: 's21-33-work'
            contents: PathDepFixtures indexNeedingRootContents.
        result := self resultOf: (Array with: 'install') in: work.
        self assert: result exitCode = 2
            description: 'a source-less install answered exit ',
                result exitCode printString, ': ', result lines printString.
        self assert: result lines first
            = (GrammarFixtures needsIndexReasonFor: 'install')
            description: result lines first printString.
        self assert: (result lines copyFrom: 2 to: result lines size)
            = (self resultOf: (Array with: '--help') in: work) lines
            description: 'the bound guard no longer answers reason line plus block'
    ]

    "---- S34: a path pin is never held ----"

    testS34_APathPinIsNeverHeldByASelectiveUpdate [
        "S34. THE FALSIFIER FOR A NARROW-TO-LOCKED BUILD, which passes
         S1-S33 and collapses here. With the sibling's declared version
         moved since the lock was written, update <index-pkg> moves the
         named index package under the ordinary hold rules while THE
         PATH PIN LANDS AT THE SIBLING'S CURRENT VERSION — never the
         stale locked one — and every unrelated index pin is
         byte-identical, asserted tuple by tuple.

         The exclusion is the mechanism, not a preference (§8 decision
         68): holding a drifted path pin at its locked version would
         narrow to a version the overlay no longer describes, which is
         §8 decision 47's collapse arriving by composition."
        | work text index before after result zStart zTuple |
        text := self sibling: 's21-34-text'.
        index := self freshDir: 's21-34-index'.
        "REAL ARCHIVES, because this scenario's verb INSTALLS (amended
         mid-sprint, GREEN step 6). Written with plainEntryFor:, every
         entry carried an empty #archive, so update answered decision
         25's no-published-archive diagnosis at exit 1 for kernel-a and
         kernel-z — correctly, and that answer is proved in S14 where it
         belongs. Here it masked the exit code this law asserts. With
         real archives the verb runs end to end and the assertion below
         strengthens from 'not the collapse' to exit 0."
        self publishInto: index name: 'kernel-a' version: '1.0.0'
            label: 's21-34-a0'.
        self publishInto: index name: 'kernel-a' version: '1.1.0'
            label: 's21-34-a1'.
        self publishInto: index name: 'kernel-z' version: '1.0.0'
            label: 's21-34-z'.
        work := self workDir: 's21-34-work' contents: 'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''kernel-text'' path: ''',
            (PathDepFixtures declaredPathFor: 's21-34-text'), ''';
        dependency: ''kernel-a'' constraint: ''^1.0.0'';
        dependency: ''kernel-z'' constraint: ''^1.0.0'' ]',
            SourceFixtures newline.
        self resultOf: (PathDepFixtures resolveArgvOn: index) in: work.
        before := self lockTextIn: work.
        self assert: (CommandLineFixtures does: before include:
            (PathDepFixtures pathTupleFor: 'kernel-text'
                version: PathDepFixtures siblingVersionString
                path: (PathDepFixtures declaredPathFor: 's21-34-text')))
            description: 'the first resolve did not pin the sibling at its declared version: ', before printString.
        ExecFixtures writePackage: (PathDepFixtures textSiblingContentsAt:
            PathDepFixtures driftedVersionString) in: text.
        result := self resultOf: (Array with: 'update' with: 'kernel-a'
            with: '--source' with: index) in: work.
        self assert: result exitCode = 0
            description: 'the drifted path pin collapsed the selective update: ',
                result lines printString.
        after := self lockTextIn: work.
        self assert: (CommandLineFixtures does: after include:
            (PathDepFixtures pathTupleFor: 'kernel-text'
                version: PathDepFixtures driftedVersionString
                path: (PathDepFixtures declaredPathFor: 's21-34-text')))
            description: 'the path pin was held at its stale locked version: ',
                after printString.
        "THE UNRELATED PIN IS COMPARED BEFORE-TO-AFTER, which is what
         this scenario's own words ask for and what a real archive makes
         necessary: the digest is produced by the publish above and
         cannot be written into a law. Extracting kernel-z's tuple from
         the lock BEFORE the update and requiring those exact bytes
         after it is a stronger claim than the hardcoded empty digest
         ever was — it fails on any change to the tuple, not just on the
         one spelling the law happened to name."
        zStart := before indexOfSubCollection: '#(''kernel-z'''.
        self deny: zStart = 0
            description: 'the first resolve pinned no kernel-z: ', before printString.
        zTuple := before copyFrom: zStart to: (before indexOf: $) startingAt: zStart).
        self assert: (CommandLineFixtures does: after include: zTuple)
            description: 'an unrelated index pin moved: ', zTuple printString,
                ' is not in ', after printString
    ]
]

Namespace current: Smalltalk.
