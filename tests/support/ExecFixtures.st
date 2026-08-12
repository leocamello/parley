"Parley Sprint 6 — runtime fixtures and doubles for the execution and
 CLI suites (issue #8, Doc E).

 Filesystem discipline (as Sprints 4-5): every fixture path — working
 dirs, entry dirs, store roots, targets, child images, scripts,
 sentinels — lives under tmp/, unique per test via a label, and is
 removed in tearDown; tmp/ is empty or absent after a clean run.
 Targets grow a .parley-staging/ subdirectory (the Doc D §4 staged
 plan) and the curated child writes parley.im into them, so removal
 here is recursive (removeTree:), unlike the settled flat helpers.

 Real archives (Doc E §5 as amended by the issue #8 ruling): the
 parley-probe star is BUILT by the toolchain at fixture time —
 'gst-package --target-directory <dir> <pkgdir>/package.xml' answers
 <dir>/parley-probe.star — through ProcessRunner, the one process
 pathway in all of Parley. That also keeps the red phase spawn-free:
 the fixture fails on the missing runner class before any process
 could start. Star bytes vary by machine and by build (zip
 timestamps), so their digests are computed per test through the
 settled, vector-anchored Sha256 — never pinned as literals, never
 used to test Sha256 itself.

 Authored opaque bytes keep pinned literal digests: archiveBytesC15
 below is the byte string whose true SHA-256 is the settled
 InstallFixtures digestC15 (operator-verified against sha256sum at
 Sprint 5); it lands on disk for the stale-pin and update scenarios.

 Pinned wording and byte decisions (posted on issue #8 for
 confirmation) live in the methods: usageLines, initSuccessLines,
 initRefusalLines, initTemplateContents, corruptionLineFor:,
 executionErrorMessageFor:code:, defineLessProblemFor:, and the lock
 oracles (diamondLockString, lockPinningC15String,
 lockPinningC24String, probeLockStringWithDigest:)."

Namespace current: Parley.

Object subclass: ExecFixtures [

    <comment: 'Class-side factory for Sprint 6 fixtures: Package.st
contents, lock-file oracles, the toolchain-built parley-probe star,
child scripts, the pinned CLI wordings, and recursive tmp/ teardown.
Stateless; uniqueness comes from per-test labels.'>

    "---- recursive teardown (targets contain .parley-staging/) ----"

    ExecFixtures class >> removeTree: aPath [
        "Remove aPath — a file, or a directory tree of any depth —
         then sweep tmp/ itself when it is left empty. Silent when the
         path does not exist."
        <category: 'directories'>
        self deepRemove: aPath.
        SourceFixtures removeTmpWhenEmpty
    ]

    ExecFixtures class >> deepRemove: aPath [
        "Private — depth-first removal of a file or directory tree."
        <category: 'private'>
        | entry names |
        entry := File name: aPath.
        entry exists ifFalse: [^self].
        entry isDirectory ifTrue: [
            names := OrderedCollection new.
            entry namesDo: [:each |
                (#('.' '..') includes: each) ifFalse: [names add: each]].
            names do: [:each | self deepRemove: aPath, '/', each]].
        entry remove
    ]

    "---- Package.st contents (Doc B §2 authoring syntax) ----"

    ExecFixtures class >> diamondRootContents [
        "The settled diamond root as an authored Package.st: my-app
         1.0.0 depending on a ^1.0 and b ^1.0."
        <category: 'package files'>
        ^'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''a'' constraint: ''^1.0'';
        dependency: ''b'' constraint: ''^1.0'' ]', SourceFixtures newline
    ]

    ExecFixtures class >> cOnlyRootContents: aConstraintString [
        "my-app 1.0.0 depending only on c under aConstraintString —
         the stale-pin ('^1.0') and update ('>=1.0 <3.0') roots; with
         '^9.0' it is the unsatisfiable conflict root."
        <category: 'package files'>
        ^'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''c'' constraint: ''', aConstraintString, ''' ]',
            SourceFixtures newline
    ]

    ExecFixtures class >> probeRootContents [
        "my-app 1.0.0 depending on the toolchain-built parley-probe
         star package — the S7 end-to-end root."
        <category: 'package files'>
        ^'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''parley-probe'' constraint: ''^1.0'' ]',
            SourceFixtures newline
    ]

    ExecFixtures class >> minimalManifestContents [
        "The S8 shape: name, version, one dependency (plus the
         required fileIns) — nothing optional."
        <category: 'package files'>
        ^'Parley define: [:pkg |
    pkg
        name: ''kernel-json'';
        version: ''0.3.1'';
        fileIns: #(''Reader.st'');
        dependency: ''kernel-streams'' constraint: ''>=1.0 <2.0'' ]',
            SourceFixtures newline
    ]

    ExecFixtures class >> noDependencyRootContents [
        "A valid manifest declaring NO dependencies — the shape `parley
         init` now writes, and the shape a first resolve actually meets."
        <category: 'package files'>
        ^'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''0.1.0'';
        fileIns: #(''App.st'') ]', SourceFixtures newline
    ]

    ExecFixtures class >> noDependenciesLine [
        "The pinned confirmation a dependency-free resolve answers."
        <category: 'pinned wordings'>
        ^'no dependencies to resolve - wrote parley.lock'
    ]

    ExecFixtures class >> emptyLockString [
        "The byte-stable lock a dependency-free project produces."
        <category: 'pinned wordings'>
        ^'#(#''parley-lock'' 1 #root ''my-app'' #packages #())',
            SourceFixtures newline
    ]

    ExecFixtures class >> definelessContents [
        "Valid Smalltalk that never sends define: — the S9 fixture."
        <category: 'package files'>
        ^'"a valid Smalltalk file that never defines a package"
Object new.', SourceFixtures newline
    ]

    ExecFixtures class >> docBTemplateContents [
        "Doc B §2's illustration, verbatim — the full authoring
         vocabulary including two dependencies. This used to be what
         `parley init` wrote, and the round-trip law below still proves
         the DOCUMENTED syntax loads. It stopped being the init template
         when that template became a starter skeleton: an example that
         declares packages nobody has is a fine illustration and a bad
         starting point."
        <category: 'package files'>
        ^'"Package.st"
Parley define: [:pkg |
    pkg
        name: ''kernel-json'';
        version: ''0.3.1'';
        summary: ''A JSON reader/writer speaking pure message sends'';
        author: ''Leonardo'';
        license: ''MIT'';
        fileIns: #(''Reader.st'' ''Writer.st'' ''Extensions.st'');
        dependency: ''kernel-streams'' constraint: ''>=1.0 <2.0'';
        dependency: ''kernel-strings'' constraint: ''^0.4.2'' ]',
            SourceFixtures newline
    ]

    ExecFixtures class >> initTemplateContents [
        "The exact bytes parley init writes: the starter skeleton,
         verbatim, single trailing newline (pinned). NOT Doc B §2's
         illustration — see CLI>>templateContents for why."
        <category: 'package files'>
        ^'"Package.st — the manifest Parley reads.
 Edit the values below, then:  parley resolve --source <index-dir>
 Add a dependency with:        dependency: ''name'' constraint: ''^1.0.0''"
Parley define: [:pkg |
    pkg
        name: ''my-package'';
        version: ''0.1.0'';
        summary: '''';
        author: '''';
        license: '''';
        fileIns: #(''MyPackage.st'') ]',
            SourceFixtures newline
    ]

    ExecFixtures class >> writePackage: aContentsString in: aWorkDir [
        "Write aContentsString as <aWorkDir>/Package.st."
        <category: 'package files'>
        SourceFixtures write: aContentsString
            toFile: 'Package.st' in: aWorkDir
    ]

    "---- lock oracles (composed from the settled pinned digests) ----"

    ExecFixtures class >> diamondLockString [
        "The byte-stable lock for the install diamond resolution
         (a 1.0.0, b 1.0.0, c 2.4.0 with their true digests) — the
         Sprint 5 oracle, unchanged."
        <category: 'lock oracles'>
        ^'#(#''parley-lock'' 1 #root ''my-app'' #packages #(#(''a'' ''1.0.0'' #sha256 ''',
            InstallFixtures digestA,
            ''') #(''b'' ''1.0.0'' #sha256 ''',
            InstallFixtures digestB,
            ''') #(''c'' ''2.4.0'' #sha256 ''',
            InstallFixtures digestC24, ''')))', SourceFixtures newline
    ]

    ExecFixtures class >> lockPinningC15String [
        "The lock for my-app resolving to c 1.5.0 alone."
        <category: 'lock oracles'>
        ^'#(#''parley-lock'' 1 #root ''my-app'' #packages #(#(''c'' ''1.5.0'' #sha256 ''',
            InstallFixtures digestC15, ''')))', SourceFixtures newline
    ]

    ExecFixtures class >> lockPinningC24String [
        "The lock for my-app resolving to c 2.4.0 alone."
        <category: 'lock oracles'>
        ^'#(#''parley-lock'' 1 #root ''my-app'' #packages #(#(''c'' ''2.4.0'' #sha256 ''',
            InstallFixtures digestC24, ''')))', SourceFixtures newline
    ]

    ExecFixtures class >> probeLockStringWithDigest: aDigest [
        "The lock for my-app resolving to parley-probe 1.0.0 whose
         star digest is aDigest (computed at fixture time, per test)."
        <category: 'lock oracles'>
        ^'#(#''parley-lock'' 1 #root ''my-app'' #packages #(#(''parley-probe'' ''1.0.0'' #sha256 ''',
            aDigest, ''')))', SourceFixtures newline
    ]

    ExecFixtures class >> writeLock: aLockString in: aWorkDir [
        "Write aLockString as <aWorkDir>/parley.lock."
        <category: 'lock oracles'>
        SourceFixtures write: aLockString
            toFile: 'parley.lock' in: aWorkDir
    ]

    "---- the c 1.5.0 archive (settled pinned digest, now on disk) ----"

    ExecFixtures class >> archiveBytesC15 [
        "The opaque byte string whose true SHA-256 is the settled
         InstallFixtures digestC15."
        <category: 'archive bytes'>
        ^'opaque archive bytes: c 1.5.0'
    ]

    ExecFixtures class >> addArchiveC15To: aDirPath [
        "Write the c 1.5.0 archive next to the diamond entries so a
         re-resolution landing on c 1.5.0 can fetch it."
        <category: 'archive bytes'>
        SourceFixtures write: self archiveBytesC15
            toFile: 'c-1.5.0.star' in: aDirPath
    ]

    "---- the toolchain-built parley-probe star (Doc E §5) ----"

    ExecFixtures class >> probePackageXml [
        <category: 'probe star'>
        ^'<package>
  <name>parley-probe</name>
  <filein>Probe.st</filein>
</package>', SourceFixtures newline
    ]

    ExecFixtures class >> probeWitnessSource [
        "The one class the probe star defines — its visibility in the
         curated child is the S7 proof."
        <category: 'probe star'>
        ^'Object subclass: ParleyProbeWitness [
    ParleyProbeWitness class >> greeting [ ^''loaded from the curated target'' ]
]', SourceFixtures newline
    ]

    ExecFixtures class >> probeStarBytesLabeled: aLabel [
        "Build parley-probe.star with the toolchain itself in scratch
         directories under tmp/, answer its raw bytes, and remove the
         scratch. The build runs through ProcessRunner — the one
         process pathway — so in the red phase this fails on the
         missing class before any process is spawned."
        <category: 'probe star'>
        | pkgDir outDir code bytes |
        pkgDir := SourceFixtures directoryNamed: aLabel, '-star-src'.
        outDir := SourceFixtures directoryNamed: aLabel, '-star-out'.
        SourceFixtures write: self probePackageXml
            toFile: 'package.xml' in: pkgDir.
        SourceFixtures write: self probeWitnessSource
            toFile: 'Probe.st' in: pkgDir.
        code := ProcessRunner new run:
            'gst-package --target-directory ', outDir, ' ',
                pkgDir, '/package.xml'.
        code = 0 ifFalse: [
            ^self error: 'fixture star build failed with exit ',
                code printString].
        bytes := (File name: outDir, '/parley-probe.star') contents.
        self removeTree: pkgDir.
        self removeTree: outDir.
        ^bytes
    ]

    ExecFixtures class >> probeEntryWithDigest: aDigest [
        "The parley-probe 1.0.0 index entry, schema-exact, carrying
         the star's fixture-time digest."
        <category: 'probe star'>
        ^'#(#''parley-index'' 1 #name ''parley-probe'' #version ''1.0.0'' #summary '''' #author '''' #license '''' #fileIns #(''Probe.st'') #dependencies #() #archive #(''parley-probe-1.0.0.star'' #sha256 ''',
            aDigest, '''))', SourceFixtures newline
    ]

    ExecFixtures class >> populateProbeSourceIn: aDirPath bytes: starBytes digest: aDigest [
        "The S7 source directory: the parley-probe entry and the real
         star bytes, side by side."
        <category: 'probe star'>
        SourceFixtures write: (self probeEntryWithDigest: aDigest)
            toFile: 'parley-probe-1.0.0.st' in: aDirPath.
        SourceFixtures write: starBytes
            toFile: 'parley-probe-1.0.0.star' in: aDirPath
    ]

    "---- child scripts ----"

    ExecFixtures class >> sentinelScriptContentsFor: aSentinelPath [
        "A child script writing the sentinel file — the S6 witness."
        <category: 'child scripts'>
        ^'| stream |
stream := (File name: ''', aSentinelPath, ''') writeStream.
stream nextPutAll: ''curated child ran''.
stream close', SourceFixtures newline
    ]

    ExecFixtures class >> quitScriptContentsFor: anInteger [
        "A child script exiting with anInteger — a nonzero child is an
         answer, never an error."
        <category: 'child scripts'>
        ^'ObjectMemory quit: ', anInteger printString,
            SourceFixtures newline
    ]

    ExecFixtures class >> proofScriptContentsFor: aProofPath [
        "The S7 proof script: load parley-probe through PackageLoader
         and record whether its class became visible."
        <category: 'child scripts'>
        ^'| ok stream |
ok := [PackageLoader fileInPackage: ''parley-probe''.
    Smalltalk includesKey: #ParleyProbeWitness] on: Error do: [:e | false].
stream := (File name: ''', aProofPath, ''') writeStream.
stream nextPutAll: (ok ifTrue: [''present''] ifFalse: [''absent'']).
stream close', SourceFixtures newline
    ]

    "---- pinned CLI wordings (posted on issue #8) ----"

    ExecFixtures class >> usageLines [
        "THE BLOCK: six lines, and from Sprint 20 the ONE definition of
         it in the whole suite. The verbs: line gained the three
         inspection verbs at Sprint 11 (issue #13) and update's optional
         package at Sprint 12 (issue #14); the header and flags: lines
         gained --index at Sprint 14 (issue #16); the flags: block
         gained --layout at Sprint 15 (issue #17), while the verbs: line
         did not move, because --layout is a flag on a settled verb.

         SPRINT 20 (issue #22) re-pins the verbs: line from TEN verbs to
         FOURTEEN — remove, search, info and outdated join it in Doc E
         §4's own grammar order — and re-pins it IN RED rather than in
         GREEN, where the operator can review the new row beside the
         laws that rest on it.

         WHAT THIS FIXTURE STOPPED BEING IS ALSO PART OF THE RE-PIN. It
         is no longer `the whole usage answer`: under §8 decision 79 a
         usage error is one REASON LINE followed by this block, and
         --help is this block ALONE at exit 0. Its twenty consumers were
         amended in the same change, and the four literal copies of this
         block or its verbs row that lived in ManifestEditFixtures,
         SelectiveUpdateFixtures, InspectionFixtures and
         ReleaseHardeningTest now delegate here — five copies of one
         sentence were five movers no oracle grep could see, which is
         the F18 lesson this sprint paid for.

         SPRINT 21 (issue #23) RE-PINS IT FROM SIX LINES TO EIGHT, and
         re-pins it IN RED for Sprint 20's own stated reason: the
         operator reviews the new rows beside the laws that rest on
         them. The header gains the two MODE FLAGS and the flags: block
         gains a row for each. Neither is a sourceFlags row - they are
         valueless and build nothing (§8 decisions 68, 69, 83; Doc E
         §4.2) - and the verbs: row does NOT move, because this sprint
         adds no verb. A flag the help hides is a flag that does not
         exist, which is why the block grows rather than these two
         living only in the README.

         THE FLAG COLUMN IS SIXTEEN CHARACTERS WIDE and every row pads
         to it; the two new rows state the GUARD INVARIANT each flag
         asserts rather than describing a thing it builds, because
         neither builds anything."
        <category: 'pinned wordings'>
        ^(Array
            with: 'usage: parley <verb> [--source <dir> | --git <repo> | --index <base>] [--offline] [--locked]'
            with: 'verbs: init | resolve | install | update [<pkg>] | add <pkg> <constraint> | remove <pkg> | search <term> | info <pkg> | outdated | exec <script> | publish <dir> | why <pkg> | tree | check'
            with: 'flags: --source <dir>  index entries in a local directory'
            with: '       --git <repo>    index entries in a git repository'
            with: '       --index <base>  index entries fetched per package from a sparse index'),
            (Array
                with: '       --layout <name> flat (default) or sparse, the index layout publish writes'
                with: '       --offline       this invocation spawns no git and no curl'
                with: '       --locked        this invocation does not change parley.lock')
    ]

    ExecFixtures class >> initSuccessLines [
        <category: 'pinned wordings'>
        ^Array with: 'wrote Package.st'
    ]

    ExecFixtures class >> initRefusalLines [
        <category: 'pinned wordings'>
        ^Array with: 'Package.st already exists - refusing to overwrite'
    ]

    ExecFixtures class >> corruptionLineFor: aHexString [
        "The install fail-stop line for a store entry that no longer
         verifies (detection only — Doc D §3)."
        <category: 'pinned wordings'>
        ^'store corruption: ', aHexString,
            ' no longer matches its content address - the store never repairs itself'
    ]

    ExecFixtures class >> executionErrorMessageFor: aCommandString code: anInteger [
        "The pinned ExecutionError messageText: the exit code and the
         exact failing command line."
        <category: 'pinned wordings'>
        ^'Execution failed with exit code ', anInteger printString,
            ': ', aCommandString
    ]

    ExecFixtures class >> defineLessProblemFor: aPath [
        "The pinned one-problem wording for a Package.st that never
         sent define:."
        <category: 'pinned wordings'>
        ^aPath, ': no manifest defined - the file never sent Parley define:'
    ]

    "---- narration splitting ----"

    ExecFixtures class >> linesOf: aString [
        "aString split at newlines, as an Array — the shape CliResult
         lines carries for a ConflictReport narration."
        <category: 'narration'>
        | lines stream |
        lines := OrderedCollection new.
        stream := ReadStream on: aString.
        [stream atEnd] whileFalse: [
            lines add: (stream upTo: Character nl)].
        ^lines asArray
    ]
]

Object subclass: RecordingRunner [
    | exitCode commands |

    <comment: 'The runner test double: records every command line it
is asked to run, spawns nothing, and answers a fixed exit code (0 by
default). The mutable recording makes it an edge object like the
settled fixture doubles — never domain.'>

    RecordingRunner class >> new [
        <category: 'instance creation'>
        ^self answering: 0
    ]

    RecordingRunner class >> answering: anInteger [
        "A runner whose every run: answers anInteger."
        <category: 'instance creation'>
        ^self basicNew setExitCode: anInteger
    ]

    setExitCode: anInteger [
        "Private — initialization from the class-side constructor."
        <category: 'private'>
        exitCode := anInteger.
        commands := OrderedCollection new
    ]

    run: aCommandString [
        <category: 'runner protocol'>
        commands add: aCommandString.
        ^exitCode
    ]

    commands [
        "Every recorded command line, in run order, as an Array."
        <category: 'accessing'>
        ^commands asArray
    ]
]

Object subclass: SnapshotAndFetchTrapSource [

    <comment: 'The S14/S16 source double: signals on BOTH snapshot and
fetch:version:, proving the valid-pin fast path consumes no snapshot
and a primed (or corrupt) store never reaches the fetch path.'>

    snapshot [
        <category: 'source protocol'>
        ^self error: 'fast-path law violated: the source snapshot was consumed'
    ]

    fetch: aPackageName version: aVersion [
        <category: 'source protocol'>
        ^self error: 'fast-path law violated: fetch:version: was touched for ',
            aPackageName
    ]
]

Namespace current: Smalltalk.
