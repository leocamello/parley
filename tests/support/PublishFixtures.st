"Parley Sprint 7 — runtime fixtures for the publish, schema-validation
 and GitIndexSource suites (issue #9, Doc F).

 Filesystem discipline (as Sprints 4-6): every fixture path — working
 dirs, destinations, repositories, caches, stores, targets — lives
 under tmp/, is unique per test via a label, and is removed
 recursively in tearDown through ExecFixtures removeTree: (fixture
 repositories and publish stages are directory TREES, never flat); tmp/
 is empty or absent after a clean run. The developer image is never
 mutated.

 Git discipline (issue #9): fixture repositories are built locally
 through ProcessRunner — the one process pathway in all of Parley —
 with the committer identity supplied PER COMMAND via
 'git -c user.name=... -c user.email=...', so the developer's git
 config is never read for identity and never written. Every repo path
 is a local path under tmp/ and every clone is a local-path clone: no
 network is contacted, ever. Because the builders run through
 ProcessRunner, the red phase spawns nothing — each law touches the
 missing Publisher/GitIndexSource class before any fixture builder is
 reached.

 Digest discipline (unchanged from Sprint 6): the toolchain-built
 star's digest is computed per test through the settled, vector-
 anchored Sha256 — never pinned as a literal. Authored opaque bytes
 keep pinned literals; the writer oracle's digest (archiveDigest) is
 authored INPUT to the writer, not a star's digest.

 Pinned wording and byte decisions (posted on issue #9 for
 confirmation) live in the methods: the schema-violation problems
 (schemaPairingProblemFor:, missingKeyProblemFor:key:,
 unknownKeyProblemFor:key:, keyOrderProblemFor:,
 scalarKindProblemFor:key:, fileInsKindProblemFor:,
 dependenciesKindProblemFor:, archiveKindProblemFor:), the publish
 problems (refusalProblemFor:version:in:, missingFileInProblemFor:in:,
 buildFailureProblemFor:code:), the git failure problem
 (gitFailureProblemFor:code:), the publish success line
 (publishSuccessLineFor:version:), the composed package.xml
 (greetingPackageXml), the published entry oracle
 (greetingEntryWithDigest:) and the writer oracle
 (templateArchiveEntryString)."

Namespace current: Parley.

Object subclass: PublishFixtures [

    <comment: 'Class-side factory for Sprint 7 fixtures: publishable
working directories, the composed package.xml and published entry byte
oracles, schema-violating entry files one per violation kind, locally
built fixture git repositories, and the pinned Sprint 7 wordings.
Stateless; uniqueness comes from per-test labels. Directory creation
and recursive teardown delegate to the settled SourceFixtures and
ExecFixtures helpers.'>

    "---- paths ----"

    PublishFixtures class >> absentPathNamed: aLabel [
        "Answer tmp/parley-<aLabel> WITHOUT creating it, sweeping any
         leftover from a crashed run. The shape a clone destination
         needs: GitIndexSource clones when the cache is ABSENT, so the
         cache path must not exist before the first snapshot."
        <category: 'paths'>
        | path |
        path := 'tmp/parley-', aLabel.
        ExecFixtures removeTree: path.
        (File name: 'tmp') exists ifFalse: [Directory create: 'tmp'].
        ^path
    ]

    "---- author A's publishable working directory ----"

    PublishFixtures class >> greetingPackageContents [
        "kernel-greeting 1.0.0 — two fileIns in an order that is NOT
         alphabetical, so the composed package.xml proves load order is
         preserved rather than sorted."
        <category: 'working dirs'>
        ^'Parley define: [:pkg |
    pkg
        name: ''kernel-greeting'';
        version: ''1.0.0'';
        summary: ''A greeting speaking pure message sends'';
        author: ''Author A'';
        license: ''MIT'';
        fileIns: #(''Greeting.st'' ''Extra.st'') ]', SourceFixtures newline
    ]

    PublishFixtures class >> greetingManifest [
        "The same manifest as a value, for the laws that need no
         Package.st on disk."
        <category: 'working dirs'>
        ^Parley define: [:pkg |
            pkg
                name: 'kernel-greeting';
                version: '1.0.0';
                summary: 'A greeting speaking pure message sends';
                author: 'Author A';
                license: 'MIT';
                fileIns: #('Greeting.st' 'Extra.st')]
    ]

    PublishFixtures class >> greetingSource [
        "The one class whose visibility in author B's curated child is
         the ecosystem-loop proof."
        <category: 'working dirs'>
        ^'Object subclass: KernelGreeting [
    KernelGreeting class >> greeting [ ^''published by Parley'' ]
]', SourceFixtures newline
    ]

    PublishFixtures class >> greetingExtraSource [
        "The second fileIn — its presence proves multi-filein archives
         build and load."
        <category: 'working dirs'>
        ^'Object subclass: KernelGreetingExtra [
    KernelGreetingExtra class >> marker [ ^''extra'' ]
]', SourceFixtures newline
    ]

    PublishFixtures class >> populateGreetingWorkDirIn: aDirPath [
        "Package.st and both declared fileIns, side by side — a
         complete publishable working directory."
        <category: 'working dirs'>
        ExecFixtures writePackage: self greetingPackageContents
            in: aDirPath.
        SourceFixtures write: self greetingSource
            toFile: 'Greeting.st' in: aDirPath.
        SourceFixtures write: self greetingExtraSource
            toFile: 'Extra.st' in: aDirPath
    ]

    PublishFixtures class >> greetingRootContents [
        "Author B's Package.st: my-app depending on author A's
         published package."
        <category: 'working dirs'>
        ^'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''kernel-greeting'' constraint: ''^1.0'' ]',
            SourceFixtures newline
    ]

    PublishFixtures class >> greetingRootManifest [
        "Author B's manifest as a value — the resolution input of the
         git leg."
        <category: 'working dirs'>
        ^Parley define: [:pkg |
            pkg
                name: 'my-app';
                version: '1.0.0';
                fileIns: #('App.st');
                dependency: 'kernel-greeting' constraint: '^1.0']
    ]

    PublishFixtures class >> greetingProofScriptContentsFor: aProofPath [
        "The ecosystem-loop proof script: load the published package
         through PackageLoader and record whether author A's class
         became visible in author B's curated child."
        <category: 'working dirs'>
        ^'| ok stream |
ok := [PackageLoader fileInPackage: ''kernel-greeting''.
    Smalltalk includesKey: #KernelGreeting] on: Error do: [:e | false].
stream := (File name: ''', aProofPath, ''') writeStream.
stream nextPutAll: (ok ifTrue: [''present''] ifFalse: [''absent'']).
stream close', SourceFixtures newline
    ]

    "---- the missing-fileIns working directory (pre-flight) ----"

    PublishFixtures class >> absentFileInsPackageContents [
        "kernel-absent 0.1.0 declaring two fileIns that are never
         written — declared in an order that is not sorted, so the
         batched problems prove sorted-filename ordering."
        <category: 'working dirs'>
        ^'Parley define: [:pkg |
    pkg
        name: ''kernel-absent'';
        version: ''0.1.0'';
        fileIns: #(''Zebra.st'' ''Alpha.st'') ]', SourceFixtures newline
    ]

    PublishFixtures class >> absentFileInsManifest [
        <category: 'working dirs'>
        ^Parley define: [:pkg |
            pkg
                name: 'kernel-absent';
                version: '0.1.0';
                fileIns: #('Zebra.st' 'Alpha.st')]
    ]

    "---- byte oracles ----"

    PublishFixtures class >> greetingPackageXml [
        "The Doc F §1.1 composition, byte-exact: one <filein> per
         manifest fileIn IN MANIFEST ORDER, two-space indentation,
         single trailing newline. Nothing else of the manifest enters
         the archive — versions, dependencies and prose live in the
         index entry."
        <category: 'byte oracles'>
        ^'<package>
  <name>kernel-greeting</name>
  <filein>Greeting.st</filein>
  <filein>Extra.st</filein>
</package>', SourceFixtures newline
    ]

    PublishFixtures class >> greetingEntryWithDigest: aDigest [
        "The published kernel-greeting 1.0.0 entry: the settled §5.2
         canonical bytes with a POPULATED #archive naming the landed
         star and carrying its runtime-computed digest."
        <category: 'byte oracles'>
        ^'#(#''parley-index'' 1 #name ''kernel-greeting'' #version ''1.0.0'' #summary ''A greeting speaking pure message sends'' #author ''Author A'' #license ''MIT'' #fileIns #(''Greeting.st'' ''Extra.st'') #dependencies #() #archive #(''kernel-greeting-1.0.0.star'' #sha256 ''',
            aDigest, '''))', SourceFixtures newline
    ]

    PublishFixtures class >> archiveFileName [
        "The storage convention of Doc F §1 step 5 for the published
         star (Doc B §5.2's example shape)."
        <category: 'byte oracles'>
        ^'kernel-greeting-1.0.0.star'
    ]

    PublishFixtures class >> entryFileName [
        <category: 'byte oracles'>
        ^'kernel-greeting-1.0.0.st'
    ]

    PublishFixtures class >> archiveDigest [
        "An AUTHORED 64-character digest — input to the writer oracle,
         never a star's true digest (those are computed per test)."
        <category: 'byte oracles'>
        ^'0f1e2d3c4b5a69788796a5b4c3d2e1f00f1e2d3c4b5a69788796a5b4c3d2e1f0'
    ]

    PublishFixtures class >> templateArchiveFileName [
        <category: 'byte oracles'>
        ^'kernel-json-0.3.1.star'
    ]

    PublishFixtures class >> templateManifest [
        "The Doc B §2 template manifest — the manifest both writer
         oracles render."
        <category: 'byte oracles'>
        ^Parley define: [:pkg |
            pkg
                name: 'kernel-json';
                version: '0.3.1';
                summary: 'A JSON reader/writer speaking pure message sends';
                author: 'Leonardo';
                license: 'MIT';
                fileIns: #('Reader.st' 'Writer.st' 'Extensions.st');
                dependency: 'kernel-streams' constraint: '>=1.0 <2.0';
                dependency: 'kernel-strings' constraint: '^0.4.2']
    ]

    PublishFixtures class >> templateEntryString [
        "The SETTLED write:on: oracle (Sprint 1, S9) — byte-identical
         here so the new selector cannot drift the old output."
        <category: 'byte oracles'>
        ^'#(#''parley-index'' 1 #name ''kernel-json'' #version ''0.3.1'' #summary ''A JSON reader/writer speaking pure message sends'' #author ''Leonardo'' #license ''MIT'' #fileIns #(''Reader.st'' ''Writer.st'' ''Extensions.st'') #dependencies #(#(''kernel-streams'' ''>=1.0.0 <2.0.0'') #(''kernel-strings'' ''>=0.4.2 <0.5.0'')) #archive #())',
            SourceFixtures newline
    ]

    PublishFixtures class >> templateArchiveEntryString [
        "The NEW write:archive:sha256:on: oracle: identical to the
         settled bytes except #archive carries the filename and digest."
        <category: 'byte oracles'>
        ^'#(#''parley-index'' 1 #name ''kernel-json'' #version ''0.3.1'' #summary ''A JSON reader/writer speaking pure message sends'' #author ''Leonardo'' #license ''MIT'' #fileIns #(''Reader.st'' ''Writer.st'' ''Extensions.st'') #dependencies #(#(''kernel-streams'' ''>=1.0.0 <2.0.0'') #(''kernel-strings'' ''>=0.4.2 <0.5.0'')) #archive #(''kernel-json-0.3.1.star'' #sha256 ''',
            self archiveDigest, '''))', SourceFixtures newline
    ]

    "---- staging and destination paths (Doc F §1) ----"

    PublishFixtures class >> stageDirIn: aDestDir [
        "The destination-confined staging directory."
        <category: 'byte oracles'>
        ^aDestDir, '/.parley-publish-stage'
    ]

    PublishFixtures class >> buildCommandFor: aDestDir [
        "The pinned toolchain build command line: the stage is both the
         target directory and the home of the composed package.xml."
        <category: 'pinned wordings'>
        ^'gst-package --target-directory ', (self stageDirIn: aDestDir),
            ' ', (self stageDirIn: aDestDir), '/package.xml'
    ]

    "---- schema-violating entry files, one per violation kind ----"

    PublishFixtures class >> validEntryP [
        "The schema-exact control: p 1.0.0, every key present, in the
         fixed order, each with its schema kind."
        <category: 'schema entries'>
        ^'#(#''parley-index'' 1 #name ''p'' #version ''1.0.0'' #summary '''' #author '''' #license '''' #fileIns #(''P.st'') #dependencies #(#(''q'' ''^1.0'')) #archive #())',
            SourceFixtures newline
    ]

    PublishFixtures class >> entryWithUnpairedBody [
        "A trailing key with no value: the schema keys and values do
         not pair up."
        <category: 'schema entries'>
        ^'#(#''parley-index'' 1 #name ''p'' #version)', SourceFixtures newline
    ]

    PublishFixtures class >> entryMissingSummary [
        "#summary absent — seven keys where the schema fixes eight."
        <category: 'schema entries'>
        ^'#(#''parley-index'' 1 #name ''p'' #version ''1.0.0'' #author '''' #license '''' #fileIns #(''P.st'') #dependencies #() #archive #())',
            SourceFixtures newline
    ]

    PublishFixtures class >> entryWithUnknownKey [
        "All eight schema keys in order, plus a ninth key the schema
         does not define."
        <category: 'schema entries'>
        ^'#(#''parley-index'' 1 #name ''p'' #version ''1.0.0'' #summary '''' #author '''' #license '''' #fileIns #(''P.st'') #dependencies #() #archive #() #yanked '''')',
            SourceFixtures newline
    ]

    PublishFixtures class >> entryWithKeysOutOfOrder [
        "All eight keys present, #version before #name — the fixed
         order is part of the schema, not a rendering preference."
        <category: 'schema entries'>
        ^'#(#''parley-index'' 1 #version ''1.0.0'' #name ''p'' #summary '''' #author '''' #license '''' #fileIns #(''P.st'') #dependencies #() #archive #())',
            SourceFixtures newline
    ]

    PublishFixtures class >> entryWithSymbolName [
        "#name carries a symbol where the schema fixes a string."
        <category: 'schema entries'>
        ^'#(#''parley-index'' 1 #name #p #version ''1.0.0'' #summary '''' #author '''' #license '''' #fileIns #(''P.st'') #dependencies #() #archive #())',
            SourceFixtures newline
    ]

    PublishFixtures class >> entryWithIntegerVersion [
        "#version carries an integer where the schema fixes a string."
        <category: 'schema entries'>
        ^'#(#''parley-index'' 1 #name ''p'' #version 1 #summary '''' #author '''' #license '''' #fileIns #(''P.st'') #dependencies #() #archive #())',
            SourceFixtures newline
    ]

    PublishFixtures class >> entryWithBadFileIns [
        "#fileIns is an array carrying a non-string element."
        <category: 'schema entries'>
        ^'#(#''parley-index'' 1 #name ''p'' #version ''1.0.0'' #summary '''' #author '''' #license '''' #fileIns #(''P.st'' 3) #dependencies #() #archive #())',
            SourceFixtures newline
    ]

    PublishFixtures class >> entryWithBadDependencies [
        "#dependencies carries a one-element array where the schema
         fixes #(name constraint) string pairs."
        <category: 'schema entries'>
        ^'#(#''parley-index'' 1 #name ''p'' #version ''1.0.0'' #summary '''' #author '''' #license '''' #fileIns #(''P.st'') #dependencies #(#(''q'')) #archive #())',
            SourceFixtures newline
    ]

    PublishFixtures class >> entryWithMalformedArchive [
        "#archive is neither #() nor #(<filename> #sha256 <hex>)."
        <category: 'schema entries'>
        ^'#(#''parley-index'' 1 #name ''p'' #version ''1.0.0'' #summary '''' #author '''' #license '''' #fileIns #(''P.st'') #dependencies #() #archive #(''p-1.0.0.star''))',
            SourceFixtures newline
    ]

    PublishFixtures class >> entryWithArchiveWrongMarker [
        "#archive is a three-element array whose middle element is not
         the #sha256 marker."
        <category: 'schema entries'>
        ^'#(#''parley-index'' 1 #name ''p'' #version ''1.0.0'' #summary '''' #author '''' #license '''' #fileIns #(''P.st'') #dependencies #() #archive #(''p-1.0.0.star'' #md5 ''ab12''))',
            SourceFixtures newline
    ]

    "---- pinned schema-violation problems (posted on issue #9) ----"

    PublishFixtures class >> schemaKeyOrderText [
        "The fixed key order, rendered once and shared by the wordings
         that must state it."
        <category: 'pinned wordings'>
        ^'#name #version #summary #author #license #fileIns #dependencies #archive'
    ]

    PublishFixtures class >> schemaPairingProblemFor: aBaseName [
        <category: 'pinned wordings'>
        ^aBaseName, ': malformed entry - the schema keys and values do not pair up'
    ]

    PublishFixtures class >> missingKeyProblemFor: aBaseName key: aSymbol [
        <category: 'pinned wordings'>
        ^aBaseName, ': missing schema key ', aSymbol printString,
            ' - the fixed key order is ', self schemaKeyOrderText
    ]

    PublishFixtures class >> unknownKeyProblemFor: aBaseName key: aSymbol [
        <category: 'pinned wordings'>
        ^aBaseName, ': unknown schema key ', aSymbol printString,
            ' - the fixed key order is ', self schemaKeyOrderText
    ]

    PublishFixtures class >> keyOrderProblemFor: aBaseName [
        <category: 'pinned wordings'>
        ^aBaseName, ': schema keys out of order - the fixed key order is ',
            self schemaKeyOrderText
    ]

    PublishFixtures class >> scalarKindProblemFor: aBaseName key: aSymbol [
        <category: 'pinned wordings'>
        ^aBaseName, ': ', aSymbol printString, ' must be a string'
    ]

    PublishFixtures class >> fileInsKindProblemFor: aBaseName [
        <category: 'pinned wordings'>
        ^aBaseName, ': #fileIns must be an array of strings'
    ]

    PublishFixtures class >> dependenciesKindProblemFor: aBaseName [
        <category: 'pinned wordings'>
        ^aBaseName, ': #dependencies must be an array of #(name constraint) string pairs'
    ]

    PublishFixtures class >> archiveKindProblemFor: aBaseName [
        <category: 'pinned wordings'>
        ^aBaseName, ': #archive must be #() or #(<filename> #sha256 <hex digest>)'
    ]

    "---- pinned publish problems (posted on issue #9) ----"

    PublishFixtures class >> refusalProblemFor: aName version: aVersionString in: aDestDir [
        "Releases are immutable: republishing is a category error, not
         a batch member."
        <category: 'pinned wordings'>
        ^aName, ' ', aVersionString,
            ': already published - releases are immutable (',
            aDestDir, '/', aName, '-', aVersionString, '.st exists)'
    ]

    PublishFixtures class >> missingFileInProblemFor: aFileName in: aWorkingDir [
        "One pre-flight problem per absent fileIn, opening with the
         file name so the batch sorts by filename."
        <category: 'pinned wordings'>
        ^aFileName, ': missing from the working directory ', aWorkingDir
    ]

    PublishFixtures class >> buildFailureProblemFor: aCommandString code: anInteger [
        "Fail-stop: the exact command line and the exit code, never the
         child's stderr text (the runner captures none)."
        <category: 'pinned wordings'>
        ^'package build failed with exit code ', anInteger printString,
            ': ', aCommandString
    ]

    PublishFixtures class >> publishErrorMessageFor: aCollection [
        "The batched house style, as ManifestError/SourceError/
         InstallError before it."
        <category: 'pinned wordings'>
        | message |
        message := WriteStream on: String new.
        message nextPutAll: 'Publish has ';
            nextPutAll: aCollection size printString;
            nextPutAll: ' problem(s): '.
        aCollection
            do: [:p | message nextPutAll: p]
            separatedBy: [message nextPutAll: '; '].
        ^message contents
    ]

    PublishFixtures class >> publishSuccessLineFor: aName version: aVersionString [
        "The CLI publish verb's single success line, exit 0."
        <category: 'pinned wordings'>
        ^'published ', aName, ' ', aVersionString
    ]

    "---- pinned git commands and the git failure problem ----"

    PublishFixtures class >> cloneCommandFor: aRepoPath cache: aCacheDir [
        <category: 'pinned wordings'>
        ^'git clone ', aRepoPath, ' ', aCacheDir
    ]

    PublishFixtures class >> pullCommandFor: aCacheDir [
        <category: 'pinned wordings'>
        ^'git -C ', aCacheDir, ' pull --ff-only'
    ]

    PublishFixtures class >> gitFailureProblemFor: aCommandString code: anInteger [
        "A broken transport and a broken entry are both 'this source
         cannot answer' — one SourceError, one problem, carrying the
         command line and the exit code and no stderr text."
        <category: 'pinned wordings'>
        ^'git command failed with exit code ', anInteger printString,
            ': ', aCommandString
    ]

    "---- fixture git repositories, built locally through ProcessRunner ----"

    PublishFixtures class >> gitIdentity [
        "Committer identity supplied PER COMMAND — the developer's git
         config is never touched."
        <category: 'git fixtures'>
        ^'-c user.name=Parley -c user.email=parley@example.invalid'
    ]

    PublishFixtures class >> git: aTail [
        "Private — one git command through ProcessRunner, the one
         process pathway; a nonzero exit is a broken fixture, not a
         law under test."
        <category: 'git fixtures'>
        | code |
        code := ProcessRunner new run: 'git ', aTail.
        code = 0 ifFalse: [
            ^self error: 'fixture git command failed with exit ',
                code printString, ': git ', aTail].
        ^code
    ]

    PublishFixtures class >> initRepoAt: aRepoPath [
        "Create aRepoPath as a git repository (local, no network)."
        <category: 'git fixtures'>
        ^self git: 'init -q ', aRepoPath
    ]

    PublishFixtures class >> commitAllIn: aRepoPath message: aWord [
        "Stage everything and commit it with the per-command identity.
         aWord carries no spaces: Parley composes no shell-quoting
         layer, in tests exactly as in src/."
        <category: 'git fixtures'>
        self git: '-C ', aRepoPath, ' add -A'.
        ^self git: '-C ', aRepoPath, ' ', self gitIdentity,
            ' commit -q -m ', aWord
    ]

    PublishFixtures class >> buildDiamondRepoAt: aRepoPath [
        "A fixture repository whose working tree is an index directory:
         the settled install diamond (entries with true digests and
         their archives), committed once."
        <category: 'git fixtures'>
        self initRepoAt: aRepoPath.
        InstallFixtures populateInstallDiamondIn: aRepoPath.
        self commitAllIn: aRepoPath message: 'diamond'.
        ^aRepoPath
    ]

    PublishFixtures class >> growDiamondRepoAt: aRepoPath [
        "Commit one new upstream entry (the settled d 1.0.0) — the
         growth a later --ff-only pull must reveal."
        <category: 'git fixtures'>
        SourceFixtures write: SourceFixtures lateEntryDContents
            toFile: 'd-1.0.0.st' in: aRepoPath.
        ^self commitAllIn: aRepoPath message: 'grow'
    ]

    "---- the fetch-runs-no-git fixture (S14) ----"

    PublishFixtures class >> checkoutArchiveBytes [
        "The archive bytes committed BEFORE the clone — what
         fetch:version: must still answer after upstream moves on."
        <category: 'git fixtures'>
        ^'opaque archive bytes: pinned checkout'
    ]

    PublishFixtures class >> movedArchiveBytes [
        "Different bytes committed upstream AFTER the clone; a
         fetch:version: that answered these would prove a git command
         ran on the fetch path."
        <category: 'git fixtures'>
        ^'opaque archive bytes: moved upstream'
    ]

    PublishFixtures class >> archiveEntryFWithDigest: aDigest [
        "f 1.0.0, no dependencies, naming f-1.0.0.star with the digest
         computed at fixture time through the settled Sha256."
        <category: 'git fixtures'>
        ^'#(#''parley-index'' 1 #name ''f'' #version ''1.0.0'' #summary '''' #author '''' #license '''' #fileIns #(''F.st'') #dependencies #() #archive #(''f-1.0.0.star'' #sha256 ''',
            aDigest, '''))', SourceFixtures newline
    ]

    PublishFixtures class >> buildArchiveRepoAt: aRepoPath [
        "A one-package repository whose archive bytes are the pinned
         checkout bytes."
        <category: 'git fixtures'>
        self initRepoAt: aRepoPath.
        SourceFixtures
            write: (self archiveEntryFWithDigest:
                (Sha256 hexDigestOf: self checkoutArchiveBytes))
            toFile: 'f-1.0.0.st' in: aRepoPath.
        SourceFixtures write: self checkoutArchiveBytes
            toFile: 'f-1.0.0.star' in: aRepoPath.
        self commitAllIn: aRepoPath message: 'archive'.
        ^aRepoPath
    ]

    PublishFixtures class >> moveArchiveUpstreamAt: aRepoPath [
        "Replace the archive bytes (and the entry's digest) upstream."
        <category: 'git fixtures'>
        SourceFixtures
            write: (self archiveEntryFWithDigest:
                (Sha256 hexDigestOf: self movedArchiveBytes))
            toFile: 'f-1.0.0.st' in: aRepoPath.
        SourceFixtures write: self movedArchiveBytes
            toFile: 'f-1.0.0.star' in: aRepoPath.
        ^self commitAllIn: aRepoPath message: 'move'
    ]

    PublishFixtures class >> buildRepoAt: aRepoPath fromIndex: anIndexDir [
        "A fixture repository carrying a copy of an index directory's
         published files — the git leg of the ecosystem loop."
        <category: 'git fixtures'>
        self initRepoAt: aRepoPath.
        (File name: anIndexDir) files do: [:each |
            each isDirectory ifFalse: [
                SourceFixtures write: each contents
                    toFile: each stripPath in: aRepoPath]].
        self commitAllIn: aRepoPath message: 'index'.
        ^aRepoPath
    ]

    "---- destination inspection ----"

    PublishFixtures class >> fileNamesIn: aDirPath [
        "Every entry name of aDirPath in sorted order, as an Array;
         empty for an absent directory. The oracle for 'the
         destination is byte-unchanged' and 'nothing was written'."
        <category: 'inspection'>
        | dir names |
        dir := File name: aDirPath.
        (dir exists and: [dir isDirectory]) ifFalse: [^#()].
        names := OrderedCollection new.
        dir namesDo: [:each |
            (#('.' '..') includes: each) ifFalse: [names add: each]].
        ^(names asSortedCollection: [:a :b | a <= b]) asArray
    ]
]

Object subclass: TrapRunner [

    <comment: 'The runner test double that must never be asked to run
anything: it signals on run:. It proves a message runs NO process —
the fetch:version:/versionsOf:/manifestFor: delegation of
GitIndexSource, where a git command would break the metadata/archive
split.'>

    run: aCommandString [
        <category: 'runner protocol'>
        ^self error: 'no-process law violated: a command was run - ',
            aCommandString
    ]
]

Namespace current: Smalltalk.
