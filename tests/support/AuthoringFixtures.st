"Parley Sprint 18 — fixtures for the authoring boundary (issue #20;
 Doc B §2.2, Doc E §3.1, §8 decisions 61, 62 and 74).

 THE BOUNDARY THIS SPRINT OWNS. Package.st is EXECUTED, which makes the
 authoring boundary the one place in Parley where text reaches the
 terminal that Parley did not write. Probed through the shipped binary
 at staging and re-probed here: a manifest whose top-level statement
 raises answers ELEVEN lines of kernel backtrace, FOUR of them absolute
 paths into Parley's own source tree, above one correct sentence. (FOUR,
 re-probed at the RED review: SIX was the staging plan's count, it reached
 the issue and two comments in this suite, and it is corrected here and in
 Doc B §2.2. Nothing asserts the number — the laws deny the markers.) The
 tool's own laws deny backtraces and pass, because they assert over the
 CliResult's composed result lines while this text reaches the terminal
 by another route entirely. That gap is why the marker-absence law here
 is measured on CAPTURED STDOUT AND STDERR FROM THE SHIPPED BINARY,
 separately, and never on result lines.

 ONE FIXTURE MUST NEVER BE FILED IN INSIDE THE HARNESS, and it is the
 first thing to know about this file. unparseableContents holds a
 Package.st with a syntax error, and 3.2.5's parser reports it on
 STDERR as a line containing the words the red gate greps for. The
 harness captures the suite's own stderr, so filing that fixture in
 IN-IMAGE makes verify-sprint.sh refuse the run in BOTH phases — not
 because a law failed, but because the gate cannot tell a fixture's
 syntax error from the suite's. It is therefore driven ONLY through the
 shipped binary as a child process with its stderr redirected to a
 capture file the test owns. Every other manifest here is ordinary
 Smalltalk and files in safely.

 THE FOUR NAMED PROBLEM LITERALS CANNOT ALL COME FROM ONE MANIFEST, and
 that is a defect in the scenario text rather than in the builder.
 Issue #20 S4 names them as one file's batch — missing required field
 name, missing required field version, invalid version ''nope'',
 invalid constraint ''garbage'' for dependency ''demo'' — but the
 settled ManifestBuilder>>build reports a version as MISSING or as
 INVALID and never as both, so no manifest produces that set. Two
 four-problem manifests are declared instead, each reachable, and
 between them they cover all four named literals against hand-written
 oracles. Raised for the operator at the RED review; the mechanism, the
 header shape and the byte-identity claim are the same under either
 reading.

 Pinned wordings (posted on issue #20 for confirmation at the RED
 review) live in the methods:
   - the batch header — batchHeaderFor:count:;
   - the re-voiced file-and-line anchor — anchorLineFor:line:.

 Every fixture path is under tmp/, unique per test via a label, and
 removed recursively by the caller's tearDown through
 PathFixtures removeTree:, which unlocks the tree first."

Namespace current: Parley.

Object subclass: AuthoringFixtures [

    <comment: 'Class-side factory for the Sprint 18 authoring-boundary
fixtures: the malformed manifests, the pinned batch header and
file-and-line wordings, the hand-written problem oracles, the
shipped-binary runner that captures stdout and stderr SEPARATELY, and
the marker sets the structural laws are measured with. Stateless;
uniqueness comes from per-test labels.'>

    "---- the manifests ----"

    AuthoringFixtures class >> raisingContents [
        "THE FIRST DEFECT, in its smallest form: a Package.st whose
         top-level statement raises. The author sent define:, the block
         started running, and the second line of their own file asked
         nil for something it does not answer.

         The error is on LINE 2 deliberately: the anchor Parley must
         recover is the line the AUTHOR has to open, not the line the
         define: send sits on."
        <category: 'manifests'>
        ^'Parley define: [:pkg |
    nil foo.
    pkg
        name: ''demo'';
        version: ''1.0.0'';
        fileIns: #(''App.st'') ]', SourceFixtures newline
    ]

    AuthoringFixtures class >> raisingLineNumber [
        "The line raisingContents raises on — the anchor the capture
         carries and the diagnosis must name."
        <category: 'manifests'>
        ^2
    ]

    AuthoringFixtures class >> fourProblemContents [
        "FOUR problems, and every one of them reachable together: no
         name, a version that does not parse, no fileIns, and a
         constraint that does not parse.

         The dependency is named demo and the package is NOT, because a
         package that depends on itself is a fifth problem and this
         manifest declares exactly four."
        <category: 'manifests'>
        ^'Parley define: [:pkg |
    pkg
        version: ''nope'';
        dependency: ''demo'' constraint: ''garbage'' ]',
            SourceFixtures newline
    ]

    AuthoringFixtures class >> fourProblemProblems [
        "THE HAND-WRITTEN ORACLE (S5), typed out here rather than
         obtained from the composer that produced it. An oracle taken
         from the code under test proves only that the code equals
         itself; these four are read off the settled ManifestBuilder
         source and written by hand, in build''s own declaration order —
         name, version, fileIns, dependencies.

         Array with: stops at five arguments on 3.2.5, which is not a
         problem at four and is the reason the second oracle below
         concatenates."
        <category: 'oracles'>
        ^Array
            with: 'missing required field name'
            with: 'invalid version ''nope'''
            with: 'fileIns must declare at least one file to load'
            with: 'invalid constraint ''garbage'' for dependency ''demo'''
    ]

    AuthoringFixtures class >> missingVersionContents [
        "The second four-problem manifest: the one that reaches
         missing required field version, which the first cannot —
         build reports a version as missing or as invalid, never both.
         Declared so all four literals issue #20 names are covered by a
         hand-written oracle."
        <category: 'manifests'>
        ^'Parley define: [:pkg |
    pkg dependency: ''demo'' constraint: ''garbage'' ]',
            SourceFixtures newline
    ]

    AuthoringFixtures class >> missingVersionProblems [
        "The second hand-written oracle, same rule as the first."
        <category: 'oracles'>
        ^Array
            with: 'missing required field name'
            with: 'missing required field version'
            with: 'fileIns must declare at least one file to load'
            with: 'invalid constraint ''garbage'' for dependency ''demo'''
    ]

    AuthoringFixtures class >> oneProblemContents [
        "EXACTLY ONE problem (S6). It answers the batch shape too:
         decision 44 gives a file one shape, not two, and a bare line
         for N=1 is how a shape acquires a second form nobody
         declared."
        <category: 'manifests'>
        ^'Parley define: [:pkg |
    pkg
        name: ''demo'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''other'' constraint: ''garbage'' ]',
            SourceFixtures newline
    ]

    AuthoringFixtures class >> oneProblemProblems [
        "The one-problem oracle, hand-written."
        <category: 'oracles'>
        ^Array with: 'invalid constraint ''garbage'' for dependency ''other'''
    ]

    AuthoringFixtures class >> unparseableContents [
        "A Package.st WITH A SYNTAX ERROR — the unclosed block.

         NEVER FILE THIS IN INSIDE THE HARNESS. 3.2.5 reports the
         syntax error on STDERR at C level, verify-sprint.sh captures
         the suite''s stderr, and the red gate refuses any run whose
         output carries a parser complaint — it cannot tell a
         fixture''s from the suite''s own, and it must not have to.
         Drive it through the shipped binary with stderr redirected to
         a capture file, which is also the only instrument that can see
         the kept fragment S12 asserts."
        <category: 'manifests'>
        ^'Parley define: [:pkg |
    pkg name: ''demo''', SourceFixtures newline
    ]

    AuthoringFixtures class >> validContents [
        "A manifest that loads, resolves and pins nothing — the guard
         (S11) that the capture never becomes a gate on the path it
         exists to protect. It is the settled dependency-free root, so
         its lock oracle is the settled one."
        <category: 'manifests'>
        ^ExecFixtures noDependencyRootContents
    ]

    "---- working directories ----"

    AuthoringFixtures class >> workDirTracking: track named: aLabel contents: aContentsString [
        "A fresh tmp/ working directory holding aContentsString as its
         Package.st."
        <category: 'working dirs'>
        | path |
        path := track value: (SourceFixtures directoryNamed: aLabel).
        ExecFixtures writePackage: aContentsString in: path.
        ^path
    ]

    AuthoringFixtures class >> manifestPathIn: aWorkDir [
        <category: 'working dirs'>
        ^aWorkDir, '/Package.st'
    ]

    "---- the pinned wordings (posted on issue #20) ----"

    AuthoringFixtures class >> batchHeaderFor: aPath count: anInteger [
        "THE BATCH HEADER, and the whole of what this sprint adds to the
         authoring diagnoses (§8 decision 44''s settled shape; Doc E
         §3.1).

         ManifestBuilder''s problems are the only diagnosis family in
         the tool that never names the file the author must open. They
         are not re-toned — each one stays byte-identical — and the path
         is added AROUND them, as a header problem prepended by
         ManifestFile. CommandLine already renders a ManifestError''s
         problems as the lines, so this is a problem entry rather than a
         new mechanism: composing it in CommandLine would silently
         change the shape of SourceError, InstallError, PublishError and
         LockError too.

         IT OFFERS NO REMEDY, and that is decision 58 rather than an
         omission: the actionable content is the problem lines
         underneath, each of which already names the field to fix.
         Inventing a remedy for the header would be a claim nothing
         checked."
        <category: 'pinned wordings'>
        ^aPath, ': ', anInteger printString, ' problem(s) in this manifest'
    ]

    AuthoringFixtures class >> anchorLineFor: aPath line: anInteger [
        "THE RE-VOICED ANCHOR (§8 decision 62): Parley''s own sentence,
         composed in the settled ''<path>: <cause> - <remedy>'' grammar
         from the one piece of the capture worth keeping.

         The capture''s own frame line carries (<basename>:<line>), so
         the pre-sprint tool was throwing away a FILE AND A LINE NUMBER
         for the commonest authoring mistake there is. Only the LINE is
         mined; the path is the one Parley already knows, because the
         frame spells the file relative to the child''s working
         directory and a diagnosis must open with the path the operator
         gave.

         THE ERROR''S OWN TEXT IS NOT CARRIED, and that is the ruling
         rather than a shortfall: the capture is evidence, never output,
         and echoing any of it would reintroduce the four Parley source
         paths this boundary exists to remove."
        <category: 'pinned wordings'>
        ^aPath, ': line ', anInteger printString,
            ' raised an error while the manifest was being read',
            ' - fix that line and try again'
    ]

    "---- the stated fragments (§8 decision 62, in decision 45's shape) ----"

    AuthoringFixtures class >> keptStdoutFragment [
        "primError''s receiver prefix, which reaches STDOUT at C level
         and which no in-image rebinding can reach. A STATED BOUNDED
         LIMITATION, not a bug to chase: it carries no backtrace frame
         and no Parley source path, so the marker-absence law passes
         over it BY ITS STATED BOUND rather than by accident.

         A STATED FRAGMENT IS A FRAGMENT, NOT A LINE, AND THAT
         DIFFERENCE IS LOAD-BEARING (§8 decision 62 as amended at the
         RED review). primError emits NO TRAILING NEWLINE, so left alone
         this prefix does not occupy a line at all — it fuses with
         whatever Parley prints next, and the operator reads
         Object: nil<path>: line 2 raised an error ... : neither a line
         Parley composed nor one it deliberately kept, but a third thing
         made by the two colliding.

         SO IT IS TERMINATED, NOT MERELY STATED: when ManifestFile
         recovers a file-and-line anchor from the capture it ends the
         dangling line before composing. The predicate is THE ANCHOR WAS
         FOUND rather than THE CAPTURE IS NON-EMPTY, because a manifest
         that merely printed on its own behalf leaves no residue.
         ManifestCapture is untouched by this — it captures, the caller
         decides (§8 decision 61). That is what lets S1 assert the
         captured stdout as EXACT LINES rather than by substring
         containment."
        <category: 'stated fragments'>
        ^'Object: '
    ]

    AuthoringFixtures class >> keptStdoutLineForANilReceiver [
        "THE WHOLE FIRST LINE of captured stdout once the fragment is
         terminated, for a manifest whose raising statement is nil foo.

         The receiver is part of what primError writes, so this is
         composed from the fragment rather than spelled a second time:
         the fragment has one definition and the receiver belongs to the
         fixture that chose it. A different raisingContents would answer
         a different receiver, which is why this method names the one it
         is about."
        <category: 'stated fragments'>
        ^self keptStdoutFragment, 'nil'
    ]

    AuthoringFixtures class >> expectedStdoutLinesFor: aManifestPath [
        "THE EXACT CAPTURED STDOUT of a shipped run over
         raisingContents — two lines, and the whole of them: the
         terminated stated fragment, then Parley''s own diagnosis.

         Probed rather than assumed. This is the shape §8 decision 62''s
         termination clause buys, and asserting it as an exact Array is
         what makes the ruling CHECKABLE: substring containment cannot
         tell a terminated fragment from a fused one, which is precisely
         how the fusion survived to the RED review."
        <category: 'stated fragments'>
        ^Array
            with: self keptStdoutLineForANilReceiver
            with: (self anchorLineFor: aManifestPath
                line: self raisingLineNumber)
    ]

    AuthoringFixtures class >> keptStderrFragmentWords [
        "The C-level parser complaint, DELIBERATELY KEPT: it names the
         author''s file AND the line, and suppressing it would destroy
         information Parley cannot reconstruct.

         It is spelled as its two words rather than as the whole line
         for one mechanical reason: verify-sprint.sh greps the suite''s
         own output for that phrase, so a failure description carrying
         it would make the gate refuse the run. Every law here asserts
         with it and no law prints it."
        <category: 'stated fragments'>
        ^Array with: 'parse' with: 'error'
    ]

    AuthoringFixtures class >> does: aText carryTheKeptStderrFragmentFor: aPath [
        "Whether aText carries the kept parser line about aPath — the
         two words in order, on a line naming the file. Assembled from
         the words so this file never contains the phrase the gate
         greps for."
        <category: 'stated fragments'>
        | needle |
        needle := ': ', (self keptStderrFragmentWords at: 1), ' ',
            (self keptStderrFragmentWords at: 2).
        ^(CommandLineFixtures does: aText include: needle)
            and: [CommandLineFixtures does: aText
                include: (PathGuard baseNameOf: aPath)]
    ]

    "---- what the README owes (S14) ----"

    AuthoringFixtures class >> readmeMarkers [
        "WHAT A STRANGER MUST BE ABLE TO READ, as label-and-marker pairs.

         THE PAIRING IS MECHANICAL, NOT DECORATIVE: the law prints the
         LABEL and never the marker. One of the markers is the phrase
         verify-sprint.sh greps the suite''s own output for, so a failure
         description carrying it would make the gate refuse the run
         instead of reporting the failed law — the same trap that keeps
         the unparseable manifest out of the image.

         A stated limitation that is not written down where users read is
         not stated at all (§8 decision 45''s standard, §8 decision 62''s
         obligation). Both C-level fragments are named here, alongside
         the two diagnoses this sprint composes."
        <category: 'readme'>
        ^Array
            with: (Array with: 'the batch header'
                with: 'problem(s) in this manifest')
            with: (Array with: 'the file-and-line diagnosis'
                with: 'raised an error while the manifest was being read')
            with: (Array with: 'the kept stdout fragment'
                with: self keptStdoutFragment)
            with: (Array with: 'the kept stderr fragment'
                with: (self keptStderrFragmentWords at: 1), ' ',
                    (self keptStderrFragmentWords at: 2))
            with: (Array with: 'the stream the kept fragment reaches'
                with: 'standard error')
    ]

    "---- the marker set the structural claim is measured with ----"

    AuthoringFixtures class >> terminalMarkers [
        "WHAT MAY NEVER REACH THE TERMINAL from this boundary (§8
         decision 62, extending decision 73''s bound onto a wider
         instrument). The settled backtrace markers, plus the kernel
         frame files a 3.2.5 dump names, plus the frame selector of a
         filed-in statement, plus Parley''s own absolute source
         directory — FOUR of the lines the shipped defect printed were
         absolute paths into it.

         THE ABSOLUTE PATH IS WHY THE SETTLED SET IS NOT ENOUGH ON ITS
         OWN: bin/parley always absolutizes PARLEY_ROOT, so the settled
         marker (src/ can never match a frame from a shipped run, and all
         four Parley paths would have slipped past a law that trusted it.

         THE BOUND IS STATED (decision 43). This set deliberately does
         NOT include the two kept fragments: primError''s Object:
         prefix on stdout is a stated bounded limitation, and the
         parser''s complaint on stderr is deliberately kept. The law
         passes over both BY THIS STATED BOUND rather than by luck, and
         S12 asserts the second is still there."
        <category: 'markers'>
        ^CommandLineFixtures backtraceMarkers,
            (Array
                with: 'ExcHandling.st:'
                with: 'SysExcept.st:'
                with: 'BlkClosure.st:'
                with: 'executeStatements'
                with: CommandLineFixtures repoRoot, '/src/')
    ]

    "---- the shipped binary, stdout and stderr captured SEPARATELY ----"

    AuthoringFixtures class >> shippedCommandIn: aWorkDir args: anArgsString stdoutTo: anOutPath stderrTo: anErrPath [
        "The settled shipped-binary command with its two streams
         redirected to SEPARATE files.

         SEPARATELY IS THE WHOLE POINT. The settled
         shippedBinaryCommandIn:args:outputTo: merges them with 2>&1,
         and a merged capture cannot tell the fragment Parley keeps on
         stderr from the frames it must remove from stdout — which is
         exactly the confusion that let eleven lines of kernel text
         ship past laws that deny backtraces. The redirect is a
         test-composed shell tail; ProcessRunner still captures
         nothing."
        <category: 'shipped binary'>
        ^(CommandLineFixtures shippedBinaryCommandIn: aWorkDir
            args: anArgsString),
            ' > ', anOutPath, ' 2> ', anErrPath
    ]

    AuthoringFixtures class >> captureDirTracking: track named: aLabel [
        "A capture directory OUTSIDE the fixture working directories: a
         hostile state may make a working directory unwritable, and a
         shell redirect into one of those fails before the child ever
         runs."
        <category: 'shipped binary'>
        ^track value: (SourceFixtures directoryNamed: aLabel)
    ]

    AuthoringFixtures class >> runShippedIn: aWorkDir args: anArgsString captures: aCaptureDir label: aLabel [
        "Run the shipped binary and answer an Array of three: the exit
         code, the captured STDOUT text, the captured STDERR text."
        <category: 'shipped binary'>
        | base outPath errPath code |
        base := (CommandLineFixtures absolutePathOf: aCaptureDir),
            '/', aLabel.
        outPath := base, '-out.txt'.
        errPath := base, '-err.txt'.
        code := ProcessRunner new run: (self
            shippedCommandIn: aWorkDir
            args: anArgsString
            stdoutTo: outPath
            stderrTo: errPath).
        ^Array with: code
            with: (PathFixtures contentsOf: outPath)
            with: (PathFixtures contentsOf: errPath)
    ]

    AuthoringFixtures class >> resolveArgsOn: anIndexDir [
        "The argv string the shipped runs use, with the index absolute
         because the child runs in the working directory."
        <category: 'shipped binary'>
        ^'resolve --source ',
            (CommandLineFixtures absolutePathOf: anIndexDir)
    ]

    "---- the authoring family, enumerated once (S7) ----"

    AuthoringFixtures class >> familyDriversTracking: track [
        "EVERY DIAGNOSIS THE AUTHORING PATH CAN PRODUCE, as one
         enumeration: the label, the manifest path, and a block
         answering the CliResult a real verb reaches it with.

         One enumeration rather than two, because two enumerations of
         one family is the defect the relational inventory records as
         row 22 — each correct alone and wrong with respect to the
         other, with nothing comparing them.

         THE UNPARSEABLE MANIFEST IS ABSENT ON PURPOSE and it is not an
         omission in the family: it cannot be filed in inside the
         harness (see unparseableContents), and its diagnosis is the
         settled define-less line, which the define-less row already
         drives. S12 covers it through the shipped binary."
        <category: 'family'>
        | index rows raising four missing one typo invalid defineless absent |
        index := track value: (SourceFixtures directoryNamed:
            'authoring-family-index').
        raising := self workDirTracking: track
            named: 'authoring-family-raising'
            contents: self raisingContents.
        four := self workDirTracking: track
            named: 'authoring-family-four'
            contents: self fourProblemContents.
        missing := self workDirTracking: track
            named: 'authoring-family-missing-version'
            contents: self missingVersionContents.
        one := self workDirTracking: track
            named: 'authoring-family-one'
            contents: self oneProblemContents.
        typo := track value: (LockBoundaryFixtures
            vocabularyTypoWorkDirNamed: 'authoring-family-typo').
        invalid := track value: (LockBoundaryFixtures
            invalidDeclarationWorkDirNamed: 'authoring-family-invalid').
        defineless := self workDirTracking: track
            named: 'authoring-family-defineless'
            contents: ExecFixtures definelessContents.
        absent := track value: (SourceFixtures directoryNamed:
            'authoring-family-absent').
        rows := OrderedCollection new.
        rows add: (self familyRow: 'a raising statement' in: raising
            index: index).
        rows add: (self familyRow: 'four problems' in: four
            index: index).
        rows add: (self familyRow: 'a missing version' in: missing
            index: index).
        rows add: (self familyRow: 'one problem' in: one index: index).
        rows add: (self familyRow: 'a vocabulary typo' in: typo
            index: index).
        rows add: (self familyRow: 'invalid declarations' in: invalid
            index: index).
        rows add: (self familyRow: 'no define:' in: defineless
            index: index).
        rows add: (self familyRow: 'no Package.st' in: absent
            index: index).
        ^rows asArray
    ]

    AuthoringFixtures class >> familyRow: aLabel in: aWorkDir index: anIndexDir [
        "Private — one row of the authoring family."
        <category: 'family'>
        ^Array with: aLabel
            with: (self manifestPathIn: aWorkDir)
            with: [(CommandLine in: aWorkDir runner: RecordingRunner new)
                run: (Array with: 'resolve' with: '--source'
                    with: anIndexDir)]
    ]

    AuthoringFixtures class >> familyLabels [
        "The family''s declared membership, so a driver added or dropped
         fails the law rather than quietly changing what it quantifies
         over.

         SORTED THE WAY 3.2.5 SORTS, WHICH IS NOT ASCII ORDER (probed,
         and it cost a verifier increment to find). String <= on this
         toolchain FOLDS CASE, so ''no define:'' comes BEFORE
         ''no Package.st'' — d before p — where an ASCII comparison puts
         the capital P first. This list was first written in ASCII order,
         which made the membership assertion fail FIRST and the law''s
         driver loop never run at all: in red AND in green it reported a
         failure that said nothing about the diagnoses it exists to
         check. That is method finding F14''s blind spot INSIDE a law
         rather than in front of one — a FAILURE whose cause is not the
         claim — which is why this comment names the collation instead of
         leaving the order looking arbitrary."
        <category: 'family'>
        ^#('a missing version' 'a raising statement' 'a vocabulary typo'
           'four problems' 'invalid declarations' 'no define:'
           'no Package.st' 'one problem')
    ]
]

Namespace current: Smalltalk.
