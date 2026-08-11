"Parley Sprint 19 — fixtures for the plumbing-chatter half (issue #21;
 Doc E §1, §2.1, §2.2, §8 decisions 63 and 77).

 THE BOUNDARY THIS HALF OWNS. Parley spawns children, and some of those
 children TALK. gst-package echoes every command it runs: five lines
 above publish's one composed line, leaking /tmp/gstar-* and the staging
 directory, and one /usr/bin/install -c line above install's pins. It is
 Sprint 18's defect at the execution boundary — text on the operator's
 terminal that Parley did not write.

 WHOSE PROCESS IS IT (§8 decision 63). A redirect is safe exactly when
 the process on the other end is Parley's own plumbing. publish's build
 child and the registration children are plumbing; exec's child is the
 author's program, and it goes quiet by FLAG rather than by redirect
 (§8 decision 77 — the pinned composition gains -g, which stops the GC
 message being written at all rather than throwing a stream away).

 WHERE THE install -c LINE COMES FROM, PROBED (pre-RED, and the reason
 the exception table names ExecutionScope rather than Installer):
 Installer composes no command line at all, and Parley's own staging
 line — install -D -m 644 <store> <staged> — is SILENT. The echo is
 gst-package's own, emitted by the registration child whose plan line
 InstalledSet composes and ExecutionScope>>register runs.

 THE REDIRECT IS APPENDED AT EXECUTION, NEVER INTO THE COMPOSED VALUE.
 The registration plan stays the pure value Doc D §4 pins, and a failing
 line's ExecutionError names the PLAN line — so the settled plan laws
 and the settled diagnosis wordings stay byte-identical, and this file
 pins both halves separately.

 THE MARKER SETS ARE BOUNDED, AND THE BOUND IS STATED (§8 decision 43).
 Issue #21 names a /tmp/ path among the things that may not appear. The
 marker declared here is /tmp/gstar- rather than bare /tmp/, because
 every fixture in this suite lives under <repo>/tmp/ and the bare form
 would be matched by Parley's own legitimate paths. What the scenario is
 about is the toolchain's scratch directory, and that is what is denied.

 Every fixture path is under tmp/, unique per test via a label, and
 removed recursively by the caller's tearDown through
 PathFixtures removeTree:, which unlocks the tree first."

Namespace current: Parley.

Object subclass: ChatterFixtures [

    <comment: 'Class-side factory for the Sprint 19 chatter fixtures:
the publishable project and its artifact oracles, the pinned stdout
redirect and the pinned -g flag, the foreign-output marker sets for
publish and install, and the exec script that writes to both streams.
Stateless; uniqueness comes from per-test labels.'>

    "---- the declared silencing (pinned in RED) ----"

    ChatterFixtures class >> stdoutRedirectTail [
        "THE WHOLE OF THE MECHANISM (§8 decision 63), written here by
         hand as the oracle rather than read back from the code that
         composes it.

         STDOUT ONLY, AND THE ABSENCE OF 2> IS THE POINT. A child''s
         chatter is discarded; a child''s FAILURE is not. gst-package
         reports its own failures on stderr — probed: a non-archive
         answers gst-package: Invalid argument there, at exit 1 — so a
         tail that carried 2>&1 would silence the diagnosis along with
         the noise, which is the fail-wrong this project exists to
         prevent. The law testTheRedirectDiscardsStdoutAndTouchesNoStderr
         asserts exactly that about this string."
        <category: 'declared silencing'>
        ^' > /dev/null'
    ]

    ChatterFixtures class >> noGcMessageFlag [
        "The toolchain flag decision 77 found in gst''s own --help, and
         the reason exec needed neither of the two routes decision 63
         enumerated. Probed pre-RED on the exact composed shape: stderr
         drops from 55 bytes to 19 — the script''s own line and nothing
         else — stdout is byte-identical and the exit code is unchanged."
        <category: 'declared silencing'>
        ^'-g'
    ]

    ChatterFixtures class >> silenced: aCommandString [
        "aCommandString as the runner really receives it from Sprint 19
         on: the composed line with the declared stdout redirect."
        <category: 'declared silencing'>
        ^aCommandString, self stdoutRedirectTail
    ]

    ChatterFixtures class >> silencedPlan: someCommandLines [
        "A registration plan as the RECORDING RUNNER sees it — every
         plan line silenced (§8 decision 63).

         IT TAKES THE PLAN AND MAPS IT, which is the whole point of the
         shape: the settled plan oracles keep answering THE PLAN,
         byte-identical, and the six settled laws that assert what the
         runner recorded say `the plan, silenced` rather than carrying a
         second copy of the plan with a tail baked in. The plan is a
         pure value Doc D §4 pins; silencing is a property of running
         one."
        <category: 'declared silencing'>
        ^someCommandLines collect: [:each | self silenced: each]
    ]

    ChatterFixtures class >> gcMessageMarker [
        "The plumbing fragment that must be ABSENT from exec''s captured
         stderr from this sprint on. Spelled as the words the toolchain
         writes; the surrounding quotation marks are the toolchain''s and
         are deliberately not part of the needle."
        <category: 'declared silencing'>
        ^'Global garbage collection'
    ]

    "---- the publishable project ----"

    ChatterFixtures class >> packageName [
        <category: 'publishable project'>
        ^'demo'
    ]

    ChatterFixtures class >> packageVersion [
        <category: 'publishable project'>
        ^'1.0.0'
    ]

    ChatterFixtures class >> witnessFileName [
        <category: 'publishable project'>
        ^'Demo.st'
    ]

    ChatterFixtures class >> witnessMarker [
        "A byte sequence that appears in the witness source and NOWHERE
         ELSE in a published archive — the instrument S3's archive half
         needs (operator amendment, Sprint 19 RED review).

         IT SURVIVES INTO THE .star VERBATIM, AND THAT IS PROBED RATHER
         THAN ASSUMED. gst-package builds the archive with
         zip -n .st:.xml, which STORES those suffixes uncompressed, so
         the member''s bytes appear in the archive unchanged. Probed on
         this toolchain against this exact source: both the member name
         and this string are present in the built archive.

         WHY S3 NEEDS IT. Its archive claim was `not empty`, which a
         redirect written into the wrong place can satisfy with junk —
         and the digest half cannot help, because the digest is computed
         FROM the landed bytes and therefore agrees with whatever landed.
         One assertion over content is what makes `the artifacts did not
         move` a claim about the artifact rather than about its size."
        <category: 'publishable project'>
        ^'published by parley'
    ]

    ChatterFixtures class >> witnessSource [
        "The one class the published package defines. Lowercase internal
         name, per Doc B §3.4 and the name-equality constraint — the
         archive is loadable only as <name>.star.

         The greeting literal is witnessMarker rather than a second
         spelling of it: S3 asserts the marker survives into the archive,
         and two copies of one literal is the shape inventory row 22
         records."
        <category: 'publishable project'>
        ^'Object subclass: ParleyDemoWitness [
    ParleyDemoWitness class >> greeting [ ^''', self witnessMarker, ''' ]
]', SourceFixtures newline
    ]

    ChatterFixtures class >> publishableContents [
        "A manifest with no dependencies, one fileIn, and nothing
         optional: the smallest thing an author can publish, so the
         scenario measures the terminal rather than the manifest."
        <category: 'publishable project'>
        ^'Parley define: [:pkg |
    pkg
        name: ''', self packageName, ''';
        version: ''', self packageVersion, ''';
        fileIns: #(''', self witnessFileName, ''') ]',
            SourceFixtures newline
    ]

    ChatterFixtures class >> publishableWorkDirTracking: track named: aLabel [
        "A fresh tmp/ working directory holding the publishable
         manifest and the file it declares."
        <category: 'publishable project'>
        | path |
        path := track value: (SourceFixtures directoryNamed: aLabel).
        ExecFixtures writePackage: self publishableContents in: path.
        SourceFixtures write: self witnessSource
            toFile: self witnessFileName in: path.
        ^path
    ]

    "---- what publish composes, and what it lands ----"

    ChatterFixtures class >> publishedLine [
        "The ONE line publish may write to stdout — the settled
         composition, restated here as this sprint''s oracle because S1
         asserts the captured stdout EXACTLY rather than by
         containment."
        <category: 'publish artifacts'>
        ^'published ', self packageName, ' ', self packageVersion
    ]

    ChatterFixtures class >> releaseName [
        <category: 'publish artifacts'>
        ^self packageName, '-', self packageVersion
    ]

    ChatterFixtures class >> archiveFileName [
        <category: 'publish artifacts'>
        ^self releaseName, '.star'
    ]

    ChatterFixtures class >> entryFileName [
        <category: 'publish artifacts'>
        ^self releaseName, '.st'
    ]

    ChatterFixtures class >> entryOracleWithDigest: aDigest [
        "THE PUBLISHED ENTRY, HAND-WRITTEN (S3). Schema-exact, in Doc B
         §5.2''s fixed key order, with every key present and the empty
         string where the manifest declared nothing.

         THE DIGEST IS A PARAMETER AND NEVER A LITERAL, and that is the
         settled digest discipline rather than a convenience: a
         toolchain-built .star embeds the staged files'' modification
         times, so two builds of the same package answer DIFFERENT bytes
         and different digests. Probed pre-RED: two publishes of one
         project differ at byte 11 of the archive and at byte 164 of the
         entry, which is the digest. That is why S3 measures the artifact
         half as the entry being byte-identical to this oracle and the
         recorded digest verifying against the landed archive, rather
         than as a byte comparison against a second build — a comparison
         this toolchain cannot support for a zip."
        <category: 'publish artifacts'>
        ^'#(#''parley-index'' 1 #name ''', self packageName,
            ''' #version ''', self packageVersion,
            ''' #summary '''' #author '''' #license '''' #fileIns #(''',
            self witnessFileName, ''') #dependencies #() #archive #(''',
            self archiveFileName, ''' #sha256 ''', aDigest, '''))',
            SourceFixtures newline
    ]

    "---- the foreign output, as label-and-marker pairs ----"

    ChatterFixtures class >> publishChatterMarkers [
        "WHAT gst-package ECHOES WHILE IT BUILDS AN ARCHIVE, probed
         through the shipped binary: five lines on STDOUT, above the one
         line Parley composed.

         Pairs rather than bare needles so a failing law prints the LABEL
         and the needle together — the reader of a red suite should not
         have to guess which of five lines came back."
        <category: 'foreign markers'>
        ^Array
            with: (Array with: 'the scratch mkdir' with: 'mkdir /')
            with: (Array with: 'the staged symlink' with: 'ln -s -f')
            with: (Array with: 'the archive removal' with: 'rm -f')
            with: (Array with: 'the zip invocation' with: '&& zip')
            with: (Array with: 'the toolchain scratch directory'
                with: '/tmp/gstar-')
    ]

    ChatterFixtures class >> installChatterMarkers [
        "WHAT gst-package ECHOES WHILE IT REGISTERS AN ARCHIVE: its own
         copy line, naming Parley''s staging directory — a path the
         operator never chose and cannot act on."
        <category: 'foreign markers'>
        ^Array
            with: (Array with: 'the toolchain copy line'
                with: '/usr/bin/install -c')
            with: (Array with: 'the staging directory'
                with: '.parley-staging')
    ]

    "---- the exec script, which writes to BOTH streams (S4) ----"

    ChatterFixtures class >> execScriptStdoutLine [
        <category: 'exec script'>
        ^'the script speaks on stdout'
    ]

    ChatterFixtures class >> execScriptStderrLine [
        <category: 'exec script'>
        ^'the script complains on stderr'
    ]

    ChatterFixtures class >> execScriptExitCode [
        "A nonzero code the child chooses for itself, so S4 measures
         decision 45''s pass-through in the same run that measures the
         silencing. 3 rather than 1: it can be confused with no other
         code the boundary produces."
        <category: 'exec script'>
        ^3
    ]

    ChatterFixtures class >> execScriptContents [
        "A child script that writes one line to each stream and then
         quits with its own code.

         IT WRITES TO STDERR ON PURPOSE, and that is the whole of what
         S4 gained when decision 77 replaced the carve-out. A flag that
         silenced the child''s stderr wholesale would pass a law that
         only asserted the GC message absent; this script is what tells
         the two apart. FileStream stderr is 3.2.5''s spelling, probed."
        <category: 'exec script'>
        ^'Transcript showCr: ''', self execScriptStdoutLine, '''.
FileStream stderr nextPutAll: ''', self execScriptStderrLine,
            '''; nl; flush.
ObjectMemory quit: ', self execScriptExitCode printString,
            SourceFixtures newline
    ]

    ChatterFixtures class >> execScriptFileName [
        <category: 'exec script'>
        ^'speak.st'
    ]

    ChatterFixtures class >> execWorkDirTracking: track named: aLabel [
        "A working directory holding a resolvable manifest and the
         speaking script. The manifest is the settled dependency-free
         root: exec needs no index, and a scenario about streams must
         not be able to fail on resolution."
        <category: 'exec script'>
        | path |
        path := track value: (SourceFixtures directoryNamed: aLabel).
        ExecFixtures writePackage: ExecFixtures noDependencyRootContents
            in: path.
        SourceFixtures write: self execScriptContents
            toFile: self execScriptFileName in: path.
        ^path
    ]

    "---- the probe package, for the install half (S2) ----"

    ChatterFixtures class >> probeIndexTracking: track named: aLabel [
        "An index directory holding the parley-probe entry and a REAL
         toolchain-built .star — the settled Sprint 6 fixture, because
         the registration child must actually run gst-package for the
         echo this scenario is about to exist at all."
        <category: 'probe package'>
        | path bytes |
        path := track value: (SourceFixtures directoryNamed: aLabel).
        bytes := ExecFixtures probeStarBytesLabeled: aLabel.
        ExecFixtures populateProbeSourceIn: path
            bytes: bytes
            digest: (Sha256 hexDigestOf: bytes).
        ^path
    ]

    ChatterFixtures class >> probePinLine [
        "The one line install may write for the probe package."
        <category: 'probe package'>
        ^'parley-probe 1.0.0'
    ]
]

Namespace current: Smalltalk.
