"Parley Sprint 12 — fixtures for selective update (issue #14;
 Doc C §2.2, Doc E §4.1/§5, §8 decision 46).

 This is the sprint's one new support file. It carries the
 two-movable-packages index (tool-a 1.0.0/1.1.0 and tool-b
 2.0.0/2.1.0), the S8 held-conflict index (app-x/app-y/core), the S10
 retired-held index (built over the settled RetirementFixtures
 entries and record), the S4 diamond lock pinning c 1.5.0, and every
 pinned Sprint 12 rendering. The settled SourceFixtures / ExecFixtures
 / InstallFixtures / RetirementFixtures / InspectionFixtures /
 CommandLineFixtures / ResolverFixtures helpers are reused UNCHANGED.

 THE SHAPE UNDER TEST. parley update <pkg> resolves the ordinary way
 against a snapshot narrowed to hold every OTHER pinned package at its
 locked version — a selective update is a normal resolution of a
 smaller world. The contrast fixtures are therefore the point: in the
 tools index BOTH packages are movable, so holding is the only thing
 that keeps tool-b at 2.0.0; in the held-conflict index the named
 package is only unmovable BECAUSE the rest is held (plain update
 succeeds by moving app-y); in the retired-held index the held pin is
 retired, and only decision 46 keeps the selective update from failing
 on it. A fixture where the different outcome is impossible would
 prove nothing.

 THE HELD-CONFLICT INDEX never publishes app-x 1.0.0 at all: the lock
 pins a release the index has moved past, exactly the state an index
 owner leaves behind by deleting an old entry. Selective update app-x
 must then take 1.1.0 (needing core ^2.0) against a held core 1.0.0 —
 the conflict holding causes — while plain update takes app-y 1.1.0
 and core 2.0.0 and succeeds. The lock digest for app-x 1.0.0 is a
 shape-valid padded mnemonic, never verified: that pin exists only to
 be released.

 Filesystem discipline (as Sprints 4-11): every fixture path lives
 under tmp/, unique per test via a label, removed recursively in
 tearDown through ExecFixtures removeTree:; tmp/ is empty or absent
 after a clean run. The developer image is never mutated, nothing here
 spawns, and no network is contacted.

 Digest discipline (Doc E §5). Archive bytes are AUTHORED opaque byte
 strings, so their digests are pinned literals an operator can verify
 by hand, exactly as the Sprint 5 InstallFixtures digests are. Each
 was produced with, e.g.:
   printf '%s' 'opaque archive bytes: tool-a 1.1.0' | sha256sum
 (No trailing newline — the fixture writes exactly these bytes.) The
 kernel-json bytes and digests are the settled RetirementFixtures
 ones, consumed unchanged.

 Pinned wording decisions (posted on issue #14 for the RED review)
 live in the methods:
   - heldPinsLine — the sentence the verb prepends to a conflict
     under held pins (Doc C §2.2: provenance at the CLI);
   - alreadyNewestLineFor:version: — the success line for a package
     already at the newest version its constraints allow (the
     resolve-with-no-dependencies precedent);
   - notPinnedLineFor: and missingLockLine DELEGATE to the settled
     InspectionFixtures wordings — the why precedent and the
     inspection-verb line, one voice, single definition;
   - usageVerbsLine / selectiveUsageLines — the usage block once the
     verbs: line names update [<pkg>]. ExecFixtures usageLines is
     re-pinned to match in GREEN, together with the CLI change —
     re-pinning it in RED would fail every settled usage law against
     a CLI that has not moved yet (the Sprint 11 precedent)."

Namespace current: Parley.

Object subclass: SelectiveUpdateFixtures [

    <comment: 'Class-side factory for Sprint 12 selective-update
fixtures: the tools index where both packages are movable, the
held-conflict index where holding is what makes the named package
unmovable, the retired-held index where decision 46 is the only thing
keeping the update alive, the S4 diamond lock pinning c 1.5.0, lock
oracles, held-pin dictionaries, registration-plan oracles and every
pinned Sprint 12 wording. Stateless; uniqueness comes from per-test
labels.'>

    "---- the tools index: archive bytes and their pinned true digests ----"

    SelectiveUpdateFixtures class >> archiveBytesToolA100 [
        <category: 'archive bytes'>
        ^'opaque archive bytes: tool-a 1.0.0'
    ]

    SelectiveUpdateFixtures class >> archiveBytesToolA110 [
        <category: 'archive bytes'>
        ^'opaque archive bytes: tool-a 1.1.0'
    ]

    SelectiveUpdateFixtures class >> archiveBytesToolB200 [
        <category: 'archive bytes'>
        ^'opaque archive bytes: tool-b 2.0.0'
    ]

    SelectiveUpdateFixtures class >> archiveBytesToolB210 [
        <category: 'archive bytes'>
        ^'opaque archive bytes: tool-b 2.1.0'
    ]

    SelectiveUpdateFixtures class >> digestToolA100 [
        "The true SHA-256 of archiveBytesToolA100 (operator-verifiable)."
        <category: 'digests'>
        ^'26116cdc845a49b8faebd31972dd42b51fe19c58cc6de4539510b439d3ee9abd'
    ]

    SelectiveUpdateFixtures class >> digestToolA110 [
        "The true SHA-256 of archiveBytesToolA110."
        <category: 'digests'>
        ^'be1f811a074cb963a3eca17dd78964e599b162c1bd2a59d6cfbab7ae129f54d8'
    ]

    SelectiveUpdateFixtures class >> digestToolB200 [
        "The true SHA-256 of archiveBytesToolB200."
        <category: 'digests'>
        ^'3b6ed457e1321d9c4bfa5ba6b208fb623c8d074971b31ff6954c3686b2829180'
    ]

    SelectiveUpdateFixtures class >> digestToolB210 [
        "The true SHA-256 of archiveBytesToolB210."
        <category: 'digests'>
        ^'f1483634ae912c8dad1256992271a442ccfcb55275b3524e7a01e57b4e8533b7'
    ]

    "---- the held-conflict index: archive bytes and their pinned true digests ----"

    SelectiveUpdateFixtures class >> archiveBytesAppX110 [
        <category: 'archive bytes'>
        ^'opaque archive bytes: app-x 1.1.0'
    ]

    SelectiveUpdateFixtures class >> archiveBytesAppY100 [
        <category: 'archive bytes'>
        ^'opaque archive bytes: app-y 1.0.0'
    ]

    SelectiveUpdateFixtures class >> archiveBytesAppY110 [
        <category: 'archive bytes'>
        ^'opaque archive bytes: app-y 1.1.0'
    ]

    SelectiveUpdateFixtures class >> archiveBytesCore100 [
        <category: 'archive bytes'>
        ^'opaque archive bytes: core 1.0.0'
    ]

    SelectiveUpdateFixtures class >> archiveBytesCore200 [
        <category: 'archive bytes'>
        ^'opaque archive bytes: core 2.0.0'
    ]

    SelectiveUpdateFixtures class >> digestAppX110 [
        "The true SHA-256 of archiveBytesAppX110."
        <category: 'digests'>
        ^'9ce2a5cc40f8c49e64435d4849a404006e654ff4fbcee61cb8f394cb8098168d'
    ]

    SelectiveUpdateFixtures class >> digestAppY100 [
        "The true SHA-256 of archiveBytesAppY100."
        <category: 'digests'>
        ^'c7ae8473b31eabbf4b26fed535034ef440d0e29f5acc39f9bcde40290c04a51b'
    ]

    SelectiveUpdateFixtures class >> digestAppY110 [
        "The true SHA-256 of archiveBytesAppY110."
        <category: 'digests'>
        ^'b0c75f3f3358b44b9091b215002d1306957d49e346967426afcc820a3e33d976'
    ]

    SelectiveUpdateFixtures class >> digestCore100 [
        "The true SHA-256 of archiveBytesCore100."
        <category: 'digests'>
        ^'b6374965c49537fe811a94fc3495568a93d15ef37c78785190e87e97d9858f5a'
    ]

    SelectiveUpdateFixtures class >> digestCore200 [
        "The true SHA-256 of archiveBytesCore200."
        <category: 'digests'>
        ^'02edcd8322dae353b2d7dbcedd69f26bb57aefc3fb0b748cf521853739b1087c'
    ]

    SelectiveUpdateFixtures class >> heldDigestAppX100 [
        "The lock digest for app-x 1.0.0 — a release the held-conflict
         index no longer publishes, so no archive hashes to it and
         nothing ever verifies it. Shape-valid (64 lowercase hex): the
         SourceFixtures padded-mnemonic rule, because a lock offending
         the digest boundary would fail Sprint 11 laws instead of
         feeding this sprint."
        <category: 'digests'>
        ^'ea10000000000000000000000000000000000000000000000000000000000000'
    ]

    "---- index entries (Doc B §5.2 schema-exact) ----"

    SelectiveUpdateFixtures class >> entryNamed: aName version: aVersionString dependencies: aDepsLiteral digest: aDigest [
        "Private — one full eight-key entry naming its archive by the
         storage convention. aDepsLiteral is the rendered #dependencies
         literal, sorted by name as §5.4 rule 4 fixes."
        <category: 'index entries'>
        ^'#(#''parley-index'' 1 #name ''', aName,
            ''' #version ''', aVersionString,
            ''' #summary '''' #author '''' #license '''' #fileIns #(''App.st'') #dependencies ',
            aDepsLiteral, ' #archive #(''',
            aName, '-', aVersionString, '.star'' #sha256 ''',
            aDigest, '''))', SourceFixtures newline
    ]

    SelectiveUpdateFixtures class >> entryToolA100 [
        <category: 'index entries'>
        ^self entryNamed: 'tool-a' version: '1.0.0'
            dependencies: '#()' digest: self digestToolA100
    ]

    SelectiveUpdateFixtures class >> entryToolA110 [
        <category: 'index entries'>
        ^self entryNamed: 'tool-a' version: '1.1.0'
            dependencies: '#()' digest: self digestToolA110
    ]

    SelectiveUpdateFixtures class >> entryToolB200 [
        <category: 'index entries'>
        ^self entryNamed: 'tool-b' version: '2.0.0'
            dependencies: '#()' digest: self digestToolB200
    ]

    SelectiveUpdateFixtures class >> entryToolB210 [
        <category: 'index entries'>
        ^self entryNamed: 'tool-b' version: '2.1.0'
            dependencies: '#()' digest: self digestToolB210
    ]

    SelectiveUpdateFixtures class >> entryAppX110 [
        "app-x 1.1.0 needs core ^2.0 — the S8 hinge. The index holds NO
         app-x 1.0.0: the lock pins a release the index moved past."
        <category: 'index entries'>
        ^self entryNamed: 'app-x' version: '1.1.0'
            dependencies: '#(#(''core'' ''^2.0''))'
            digest: self digestAppX110
    ]

    SelectiveUpdateFixtures class >> entryAppY100 [
        "The held app-y 1.0.0 needs core ^1.0 — the other S8 hinge."
        <category: 'index entries'>
        ^self entryNamed: 'app-y' version: '1.0.0'
            dependencies: '#(#(''core'' ''^1.0''))'
            digest: self digestAppY100
    ]

    SelectiveUpdateFixtures class >> entryAppY110 [
        "app-y 1.1.0 needs core ^2.0 — what plain update moves TO,
         which is the S8 contrast: the index is satisfiable, holding is
         what makes it not."
        <category: 'index entries'>
        ^self entryNamed: 'app-y' version: '1.1.0'
            dependencies: '#(#(''core'' ''^2.0''))'
            digest: self digestAppY110
    ]

    SelectiveUpdateFixtures class >> entryCore100 [
        <category: 'index entries'>
        ^self entryNamed: 'core' version: '1.0.0'
            dependencies: '#()' digest: self digestCore100
    ]

    SelectiveUpdateFixtures class >> entryCore200 [
        <category: 'index entries'>
        ^self entryNamed: 'core' version: '2.0.0'
            dependencies: '#()' digest: self digestCore200
    ]

    "---- populating index directories ----"

    SelectiveUpdateFixtures class >> populateToolsIndexIn: aDirPath [
        "The two-movable-packages index: tool-a 1.0.0/1.1.0 and tool-b
         2.0.0/2.1.0, no dependencies, all four archives real. BOTH
         packages can move — which is what makes holding observable."
        <category: 'index directories'>
        SourceFixtures write: self entryToolA100
            toFile: 'tool-a-1.0.0.st' in: aDirPath.
        SourceFixtures write: self entryToolA110
            toFile: 'tool-a-1.1.0.st' in: aDirPath.
        SourceFixtures write: self entryToolB200
            toFile: 'tool-b-2.0.0.st' in: aDirPath.
        SourceFixtures write: self entryToolB210
            toFile: 'tool-b-2.1.0.st' in: aDirPath.
        SourceFixtures write: self archiveBytesToolA100
            toFile: 'tool-a-1.0.0.star' in: aDirPath.
        SourceFixtures write: self archiveBytesToolA110
            toFile: 'tool-a-1.1.0.star' in: aDirPath.
        SourceFixtures write: self archiveBytesToolB200
            toFile: 'tool-b-2.0.0.star' in: aDirPath.
        SourceFixtures write: self archiveBytesToolB210
            toFile: 'tool-b-2.1.0.star' in: aDirPath
    ]

    SelectiveUpdateFixtures class >> populateHeldConflictIndexIn: aDirPath [
        "The S8 index: app-x only at 1.1.0 (needs core ^2.0), app-y at
         1.0.0 (core ^1.0) and 1.1.0 (core ^2.0), core at 1.0.0 and
         2.0.0. Archives are written for the set plain update resolves
         to — app-x 1.1.0, app-y 1.1.0, core 2.0.0 — because the
         contrast half really installs; the selective half conflicts
         before any fetch."
        <category: 'index directories'>
        SourceFixtures write: self entryAppX110
            toFile: 'app-x-1.1.0.st' in: aDirPath.
        SourceFixtures write: self entryAppY100
            toFile: 'app-y-1.0.0.st' in: aDirPath.
        SourceFixtures write: self entryAppY110
            toFile: 'app-y-1.1.0.st' in: aDirPath.
        SourceFixtures write: self entryCore100
            toFile: 'core-1.0.0.st' in: aDirPath.
        SourceFixtures write: self entryCore200
            toFile: 'core-2.0.0.st' in: aDirPath.
        SourceFixtures write: self archiveBytesAppX110
            toFile: 'app-x-1.1.0.star' in: aDirPath.
        SourceFixtures write: self archiveBytesAppY110
            toFile: 'app-y-1.1.0.star' in: aDirPath.
        SourceFixtures write: self archiveBytesCore200
            toFile: 'core-2.0.0.star' in: aDirPath
    ]

    SelectiveUpdateFixtures class >> populateRetiredHeldIndexIn: aDirPath [
        "The S10 index: the settled retirement fixture (kernel-json
         0.3.1 and 0.3.2 with their archives, one record retiring
         0.3.2) PLUS the movable tool-a — the unrelated package whose
         selective update the retirement must never fail. Entries,
         record and kernel-json digests are the settled
         RetirementFixtures values, consumed unchanged."
        <category: 'index directories'>
        RetirementFixtures populateRetiredIndexIn: aDirPath.
        SourceFixtures write: self entryToolA100
            toFile: 'tool-a-1.0.0.st' in: aDirPath.
        SourceFixtures write: self entryToolA110
            toFile: 'tool-a-1.1.0.st' in: aDirPath.
        SourceFixtures write: self archiveBytesToolA100
            toFile: 'tool-a-1.0.0.star' in: aDirPath.
        SourceFixtures write: self archiveBytesToolA110
            toFile: 'tool-a-1.1.0.star' in: aDirPath
    ]

    "---- Package.st roots ----"

    SelectiveUpdateFixtures class >> toolsRootContents [
        "my-app 1.0.0 depending on tool-a ^1.0 and tool-b ^2.0 — both
         constraints allow the newer release, so only holding decides."
        <category: 'working dirs'>
        ^'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''tool-a'' constraint: ''^1.0'';
        dependency: ''tool-b'' constraint: ''^2.0'' ]',
            SourceFixtures newline
    ]

    SelectiveUpdateFixtures class >> heldConflictRootContents [
        <category: 'working dirs'>
        ^'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''app-x'' constraint: ''^1.0'';
        dependency: ''app-y'' constraint: ''^1.0'' ]',
            SourceFixtures newline
    ]

    SelectiveUpdateFixtures class >> retiredHeldRootContents [
        <category: 'working dirs'>
        ^'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''kernel-json'' constraint: ''^0.3.0'';
        dependency: ''tool-a'' constraint: ''^1.0'' ]',
            SourceFixtures newline
    ]

    SelectiveUpdateFixtures class >> heldConflictRootManifest [
        "The same root as a live manifest, for composing the expected
         narration through the settled resolver seam."
        <category: 'working dirs'>
        ^ResolverFixtures rootWith: (Array
            with: (Array with: 'app-x' with: '^1.0')
            with: (Array with: 'app-y' with: '^1.0'))
    ]

    "---- lock oracles (writer-format, byte-exact) ----"

    SelectiveUpdateFixtures class >> lockWithTuples: aTupleTextCollection [
        "Private — the settled writer rendering: fixed key order,
         packages sorted by name, single spaces, one trailing newline."
        <category: 'lock oracles'>
        | out |
        out := WriteStream on: String new.
        out nextPutAll: '#(#''parley-lock'' 1 #root ''my-app'' #packages #('.
        aTupleTextCollection
            do: [:each | out nextPutAll: each]
            separatedBy: [out nextPut: Character space].
        out nextPutAll: '))'.
        ^out contents, SourceFixtures newline
    ]

    SelectiveUpdateFixtures class >> tupleFor: aName version: aVersionString digest: aDigest [
        "Private — one rendered lock package tuple."
        <category: 'lock oracles'>
        ^'#(''', aName, ''' ''', aVersionString, ''' #sha256 ''',
            aDigest, ''')'
    ]

    SelectiveUpdateFixtures class >> toolsLockString [
        "The pre-update state: tool-a 1.0.0 and tool-b 2.0.0."
        <category: 'lock oracles'>
        ^self lockWithTuples: (Array
            with: (self tupleFor: 'tool-a' version: '1.0.0'
                digest: self digestToolA100)
            with: (self tupleFor: 'tool-b' version: '2.0.0'
                digest: self digestToolB200))
    ]

    SelectiveUpdateFixtures class >> toolsMovedLockString [
        "What update tool-a must write: tool-a moved to 1.1.0, tool-b
         byte-identical at 2.0.0. Also the S7 pre-state: tool-a already
         at the newest version its constraint allows."
        <category: 'lock oracles'>
        ^self lockWithTuples: (Array
            with: (self tupleFor: 'tool-a' version: '1.1.0'
                digest: self digestToolA110)
            with: (self tupleFor: 'tool-b' version: '2.0.0'
                digest: self digestToolB200))
    ]

    SelectiveUpdateFixtures class >> toolsAllMovedLockString [
        "What PLAIN update writes against the same index — the S2
         contrast oracle: tool-b really was movable, so holding is the
         only reason it stayed."
        <category: 'lock oracles'>
        ^self lockWithTuples: (Array
            with: (self tupleFor: 'tool-a' version: '1.1.0'
                digest: self digestToolA110)
            with: (self tupleFor: 'tool-b' version: '2.1.0'
                digest: self digestToolB210))
    ]

    SelectiveUpdateFixtures class >> heldConflictLockString [
        "The S8 pre-state: app-x 1.0.0 (a release the index no longer
         publishes), app-y 1.0.0, core 1.0.0."
        <category: 'lock oracles'>
        ^self lockWithTuples: (Array
            with: (self tupleFor: 'app-x' version: '1.0.0'
                digest: self heldDigestAppX100)
            with: (self tupleFor: 'app-y' version: '1.0.0'
                digest: self digestAppY100)
            with: (self tupleFor: 'core' version: '1.0.0'
                digest: self digestCore100))
    ]

    SelectiveUpdateFixtures class >> heldConflictMovedLockString [
        "The S8 contrast oracle: plain update succeeds by moving app-y
         to 1.1.0 (and core to 2.0.0) — the conflict was caused by
         holding, not by the index."
        <category: 'lock oracles'>
        ^self lockWithTuples: (Array
            with: (self tupleFor: 'app-x' version: '1.1.0'
                digest: self digestAppX110)
            with: (self tupleFor: 'app-y' version: '1.1.0'
                digest: self digestAppY110)
            with: (self tupleFor: 'core' version: '2.0.0'
                digest: self digestCore200))
    ]

    SelectiveUpdateFixtures class >> retiredHeldLockString [
        "The S10 pre-state: kernel-json pinned at the release the index
         has since retired, plus the movable tool-a 1.0.0."
        <category: 'lock oracles'>
        ^self lockWithTuples: (Array
            with: (self tupleFor: 'kernel-json' version: '0.3.2'
                digest: RetirementFixtures digestJson032)
            with: (self tupleFor: 'tool-a' version: '1.0.0'
                digest: self digestToolA100))
    ]

    SelectiveUpdateFixtures class >> retiredHeldMovedLockString [
        "What update tool-a must write: tool-a moved, the retired held
         pin KEPT at 0.3.2 (§8 decision 46 — held beats retired)."
        <category: 'lock oracles'>
        ^self lockWithTuples: (Array
            with: (self tupleFor: 'kernel-json' version: '0.3.2'
                digest: RetirementFixtures digestJson032)
            with: (self tupleFor: 'tool-a' version: '1.1.0'
                digest: self digestToolA110))
    ]

    SelectiveUpdateFixtures class >> retiredHeldFreshLockString [
        "The S10 contrast oracle: plain update moves OFF the retired
         0.3.2, because fresh resolution IS where the retirement filter
         applies (§8 decision 37)."
        <category: 'lock oracles'>
        ^self lockWithTuples: (Array
            with: (self tupleFor: 'kernel-json' version: '0.3.1'
                digest: RetirementFixtures digestJson031)
            with: (self tupleFor: 'tool-a' version: '1.1.0'
                digest: self digestToolA110))
    ]

    SelectiveUpdateFixtures class >> diamondLockPinningC15String [
        "The S4 pre-state over the settled install diamond: a 1.0.0 and
         b 1.0.0 with their true digests, c pinned at 1.5.0. The root
         declares no c at all — what is PINNED is updatable; being
         declared is not the test. update c must then write exactly the
         settled ExecFixtures diamondLockString."
        <category: 'lock oracles'>
        ^self lockWithTuples: (Array
            with: (self tupleFor: 'a' version: '1.0.0'
                digest: InstallFixtures digestA)
            with: (self tupleFor: 'b' version: '1.0.0'
                digest: InstallFixtures digestB)
            with: (self tupleFor: 'c' version: '1.5.0'
                digest: InstallFixtures digestC15))
    ]

    "---- working directories ----"

    SelectiveUpdateFixtures class >> toolsWorkDirNamed: aLabel [
        "The tools root with NO lock — the S6 lockless state. Answers
         the path; the caller tracks it for teardown."
        <category: 'working dirs'>
        | path |
        path := SourceFixtures directoryNamed: aLabel.
        ExecFixtures writePackage: self toolsRootContents in: path.
        ^path
    ]

    SelectiveUpdateFixtures class >> pinnedToolsWorkDirNamed: aLabel [
        "The tools root with the pre-update lock — the state S1-S3, S5,
         S11 and S12 start from."
        <category: 'working dirs'>
        | path |
        path := self toolsWorkDirNamed: aLabel.
        ExecFixtures writeLock: self toolsLockString in: path.
        ^path
    ]

    SelectiveUpdateFixtures class >> newestToolsWorkDirNamed: aLabel [
        "The S7 state: tool-a already pinned at the newest version its
         constraint allows."
        <category: 'working dirs'>
        | path |
        path := self toolsWorkDirNamed: aLabel.
        ExecFixtures writeLock: self toolsMovedLockString in: path.
        ^path
    ]

    SelectiveUpdateFixtures class >> heldConflictWorkDirNamed: aLabel [
        <category: 'working dirs'>
        | path |
        path := SourceFixtures directoryNamed: aLabel.
        ExecFixtures writePackage: self heldConflictRootContents in: path.
        ExecFixtures writeLock: self heldConflictLockString in: path.
        ^path
    ]

    SelectiveUpdateFixtures class >> retiredHeldWorkDirNamed: aLabel [
        <category: 'working dirs'>
        | path |
        path := SourceFixtures directoryNamed: aLabel.
        ExecFixtures writePackage: self retiredHeldRootContents in: path.
        ExecFixtures writeLock: self retiredHeldLockString in: path.
        ^path
    ]

    SelectiveUpdateFixtures class >> diamondPinnedWorkDirNamed: aLabel [
        "The S4 state: the settled diamond root (which declares only a
         and b), locked with c at 1.5.0."
        <category: 'working dirs'>
        | path |
        path := SourceFixtures directoryNamed: aLabel.
        ExecFixtures writePackage: ExecFixtures diamondRootContents in: path.
        ExecFixtures writeLock: self diamondLockPinningC15String in: path.
        ^path
    ]

    "---- reading a lock back as tuples (the S3 comparison shape) ----"

    SelectiveUpdateFixtures class >> lockContentsIn: aWorkDir [
        <category: 'lock reading'>
        ^(File name: aWorkDir, '/parley.lock') contents
    ]

    SelectiveUpdateFixtures class >> packageTuplesIn: aWorkDir [
        "The lock as a Dictionary of package name -> its four-element
         #(<name> <version> #sha256 <digest>) tuple, read through the
         settled literals-only reader. Comparing two of these tuple by
         tuple is the only proof S3 accepts: the weak forms — the lock
         changed, the lock contains tool-b 2.0.0 — both pass on a lock
         whose digest silently changed."
        <category: 'lock reading'>
        | entry map packages |
        entry := IndexEntryReader readFrom:
            (ReadStream on: (self lockContentsIn: aWorkDir)).
        packages := nil.
        3 to: entry size - 1 by: 2 do: [:i |
            (entry at: i) = #packages
                ifTrue: [packages := entry at: i + 1]].
        map := Dictionary new.
        packages do: [:tuple | map at: (tuple at: 1) put: tuple].
        ^map
    ]

    SelectiveUpdateFixtures class >> heldVersionsIn: aWorkDir except: aName [
        "The held-pin Dictionary (name -> Version) for every pinned
         package OTHER than aName — the Doc C §2.2 narrowing input,
         composed here so law suites can build the expected narrowed
         world exactly as the verb must."
        <category: 'lock reading'>
        | held |
        held := Dictionary new.
        (self packageTuplesIn: aWorkDir) keysAndValuesDo: [:name :tuple |
            name = aName ifFalse: [
                held at: name put: (Version fromString: (tuple at: 2))]].
        ^held
    ]

    "---- the registration-plan oracle (the settled Doc D §4 shape) ----"

    SelectiveUpdateFixtures class >> registrationPlanFor: namesAndDigests target: aTargetDir storeRoot: aStoreRoot [
        "Private — two lines per package, pair-adjacent, staging first,
         in sorted package-name order, exactly as the settled
         ExecutionScope composes them. namesAndDigests is an Array of
         #(<name> <digest>) pairs, already sorted."
        <category: 'registration plans'>
        | plan |
        plan := OrderedCollection new.
        namesAndDigests do: [:pair |
            plan add: 'install -D -m 644 ', aStoreRoot, '/',
                (pair at: 2), '.star ', aTargetDir,
                '/.parley-staging/', (pair at: 1), '.star'.
            plan add: 'gst-package --target-directory ',
                aTargetDir, ' ', aTargetDir,
                '/.parley-staging/', (pair at: 1), '.star'].
        ^plan asArray
    ]

    SelectiveUpdateFixtures class >> toolsMovedRegistrationPlanIn: aWorkDir [
        "The S11 oracle: the plan for the moved set — tool-a 1.1.0 and
         the held tool-b 2.0.0 — over the CommandLine wiring's store
         and target beneath aWorkDir."
        <category: 'registration plans'>
        ^self registrationPlanFor: (Array
                with: (Array with: 'tool-a' with: self digestToolA110)
                with: (Array with: 'tool-b' with: self digestToolB200))
            target: (CommandLineFixtures targetDirIn: aWorkDir)
            storeRoot: (CommandLineFixtures storeRootIn: aWorkDir)
    ]

    "---- pinned wordings (posted on issue #14 for the RED review) ----"

    SelectiveUpdateFixtures class >> heldPinsLine [
        "The sentence the verb prepends to a conflict under held pins
         (Doc C §2.2): the resolver answered truthfully about a world
         with few candidates but cannot know WHY the world was small —
         the verb had that context and owes the sentence. It names what
         was held and the verb that moves everything."
        <category: 'pinned wordings'>
        ^'the other pins were held at their locked versions - run parley update to move everything'
    ]

    SelectiveUpdateFixtures class >> alreadyNewestLineFor: aName version: aVersionString [
        "The S7 success line: the resolve-with-no-dependencies
         precedent — a verb that prints nothing reads as a verb that
         did nothing, and the lock really is rewritten (to identical
         bytes)."
        <category: 'pinned wordings'>
        ^aName, ' ', aVersionString,
            ' is already the newest version its constraints allow - wrote parley.lock'
    ]

    SelectiveUpdateFixtures class >> notPinnedLineFor: aName [
        "The S5 diagnosis — the settled why wording, DELEGATED so the
         two verbs answer the operator''s same question in one voice
         and the wording has a single definition."
        <category: 'pinned wordings'>
        ^InspectionFixtures notPinnedLineFor: aName
    ]

    SelectiveUpdateFixtures class >> missingLockLine [
        "The S6 diagnosis — the settled inspection-verb line, delegated
         for the same single-definition reason. The repair is resolve:
         there is nothing to hold selectively when nothing is pinned."
        <category: 'pinned wordings'>
        ^InspectionFixtures missingLockLine
    ]

    SelectiveUpdateFixtures class >> usageVerbsLine [
        "What the verbs: usage line becomes when update learns its
         optional package. ExecFixtures usageLines is re-pinned to
         match in GREEN, together with the CLI change (the Sprint 11
         precedent)."
        <category: 'pinned wordings'>
        ^'verbs: init | resolve | install | update [<pkg>] | add <pkg> <constraint> | exec <script> | publish <dir> | why <pkg> | tree | check'
    ]

    SelectiveUpdateFixtures class >> selectiveUsageLines [
        "The full pinned usage block with the new verbs: line — the
         other lines are the settled ones, --index re-pinned at Sprint 14."
        <category: 'pinned wordings'>
        ^Array
            with: 'usage: parley <verb> [--source <dir> | --git <repo> | --index <base>]'
            with: self usageVerbsLine
            with: 'flags: --source <dir>  index entries in a local directory'
            with: '       --git <repo>    index entries in a git repository'
            with: '       --index <base>  index entries fetched per package from a sparse index'
    ]
]

Namespace current: Smalltalk.
