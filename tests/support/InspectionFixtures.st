"Parley Sprint 11 — fixtures for the inspection verbs (issue #13;
 Doc E §4.1, Doc B §5.3/§7.1, Doc F §4).

 THE INSPECTION DIAMOND. The settled diamonds carry single-letter
 names; the sprint's scenarios name kernel-a, kernel-b and kernel-c,
 so this fixture builds its own: my-app 1.0.0 depends on kernel-a ^1.0
 and kernel-b ^1.0, both 1.0.0 depend on kernel-c ^2.0, and kernel-c
 2.4.0 closes the diamond. Every entry carries a 64-lowercase-hex
 archive digest — arbitrary bytes-truth, deliberate shape-truth: the
 inspection verbs never verify a digest against bytes (that is
 ContentStore verifyHash: and nothing else), but from this sprint the
 scan validates the SHAPE (§8 decision 42), so a fixture entry that is
 not shape-valid would fail the very boundary this sprint builds.

 EVERY PINNED RENDERING for why, tree and check lives here, exactly as
 ExecFixtures holds the settled CLI wordings. The chain hop grammar is
 '-> <name> <version> (<constraint printString>)' — the constraint in
 the parentheses is the one that DEMANDED the node it follows, so each
 hop names why the walk took it. Constraints render in normal form
 (^1.0 as >=1.0.0 <2.0.0): the normal form is the wire form (Doc B
 §5.4 rule 6), and the operator asked about the lock, which speaks it.

 ResolverTrapCLI at the bottom is the S9 double: a CLI whose
 resolveAndLock: — the ONE funnel through which resolve, update and
 the invalid-pin fallback reach the resolver — signals instead. why
 and tree succeeding through it is the proof that the graph came from
 the lock plus the snapshot (§8 decision 40), and the guard law that
 resolve trips it is the proof the trap sits on the real path.

 Every path handed in comes from the caller, who tracks it for
 teardown; nothing here spawns and no network is contacted."

Namespace current: Parley.

Object subclass: InspectionFixtures [

    <comment: 'Class-side fixtures for Sprint 11: the kernel-a/b/c
inspection diamond (entries, root Package.st, lock), the pinned
renderings of why, tree and check, the malformed-digest lock and entry
fixtures with their pinned problem wordings, the S8 digest-tree helper
and the S13 line-split sender tree.'>

    "---- the inspection diamond: digests (shape-valid, 64 lowercase hex) ----"

    InspectionFixtures class >> digestKernelA [
        <category: 'digests'>
        ^String new: 64 withAll: $a
    ]

    InspectionFixtures class >> digestKernelB [
        <category: 'digests'>
        ^String new: 64 withAll: $b
    ]

    InspectionFixtures class >> digestKernelC [
        <category: 'digests'>
        ^String new: 64 withAll: $c
    ]

    "---- the inspection diamond: index entries ----"

    InspectionFixtures class >> entryNamed: aName version: aVersionString dependencies: aDepsLiteral digest: aDigest [
        "Private — one full eight-key entry. aDepsLiteral is the
         rendered #dependencies literal, sorted by name as §5.4 rule 4
         fixes."
        <category: 'index entries'>
        ^'#(#''parley-index'' 1 #name ''', aName,
            ''' #version ''', aVersionString,
            ''' #summary '''' #author '''' #license '''' #fileIns #(''App.st'') #dependencies ',
            aDepsLiteral, ' #archive #(''',
            aName, '-', aVersionString, '.star'' #sha256 ''',
            aDigest, '''))', SourceFixtures newline
    ]

    InspectionFixtures class >> entryKernelA [
        <category: 'index entries'>
        ^self entryNamed: 'kernel-a' version: '1.0.0'
            dependencies: '#(#(''kernel-c'' ''^2.0''))'
            digest: self digestKernelA
    ]

    InspectionFixtures class >> entryKernelB [
        <category: 'index entries'>
        ^self entryNamed: 'kernel-b' version: '1.0.0'
            dependencies: '#(#(''kernel-c'' ''^2.0''))'
            digest: self digestKernelB
    ]

    InspectionFixtures class >> entryKernelC [
        <category: 'index entries'>
        ^self entryNamed: 'kernel-c' version: '2.4.0'
            dependencies: '#()'
            digest: self digestKernelC
    ]

    InspectionFixtures class >> populateInspectionIndexIn: aDirPath [
        "The three diamond entries, filenames by the storage
         convention."
        <category: 'index directories'>
        SourceFixtures write: self entryKernelA
            toFile: 'kernel-a-1.0.0.st' in: aDirPath.
        SourceFixtures write: self entryKernelB
            toFile: 'kernel-b-1.0.0.st' in: aDirPath.
        SourceFixtures write: self entryKernelC
            toFile: 'kernel-c-2.4.0.st' in: aDirPath
    ]

    "---- the inspection diamond: working directory and lock ----"

    InspectionFixtures class >> inspectionRootContents [
        "my-app 1.0.0 depending on kernel-a ^1.0 and kernel-b ^1.0."
        <category: 'working dirs'>
        ^'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''kernel-a'' constraint: ''^1.0'';
        dependency: ''kernel-b'' constraint: ''^1.0'' ]',
            SourceFixtures newline
    ]

    InspectionFixtures class >> inspectionWorkDirNamed: aLabel [
        "A working directory whose Package.st is the inspection root.
         Answers the path; the caller tracks it for teardown."
        <category: 'working dirs'>
        | path |
        path := SourceFixtures directoryNamed: aLabel.
        ExecFixtures writePackage: self inspectionRootContents in: path.
        ^path
    ]

    InspectionFixtures class >> inspectionLockString [
        "The lock pinning the whole diamond, packages sorted by name
         (§5.4 rule 4), carrying the entries'' digests."
        <category: 'lock oracles'>
        ^'#(#''parley-lock'' 1 #root ''my-app'' #packages #(#(''kernel-a'' ''1.0.0'' #sha256 ''',
            self digestKernelA,
            ''') #(''kernel-b'' ''1.0.0'' #sha256 ''',
            self digestKernelB,
            ''') #(''kernel-c'' ''2.4.0'' #sha256 ''',
            self digestKernelC, ''')))', SourceFixtures newline
    ]

    InspectionFixtures class >> pinnedInspectionWorkDirNamed: aLabel [
        "The inspection root with its lock already written — the state
         every why/tree/check scenario starts from."
        <category: 'working dirs'>
        | path |
        path := self inspectionWorkDirNamed: aLabel.
        ExecFixtures writeLock: self inspectionLockString in: path.
        ^path
    ]

    "---- pinned renderings: why (posted on issue #13) ----"

    InspectionFixtures class >> whyChainThrough: aMiddleName [
        "Private — one diamond chain: root, the middle hop, kernel-c.
         Each hop is ''-> <name> <version> (<constraint>)'' where the
         constraint is the one that demanded that node."
        <category: 'pinned wordings'>
        ^'my-app 1.0.0 -> ', aMiddleName,
            ' 1.0.0 (>=1.0.0 <2.0.0) -> kernel-c 2.4.0 (>=2.0.0 <3.0.0)'
    ]

    InspectionFixtures class >> whyKernelCLines [
        "The S1 answer: two chains, sorted, byte-stable."
        <category: 'pinned wordings'>
        ^Array
            with: (self whyChainThrough: 'kernel-a')
            with: (self whyChainThrough: 'kernel-b')
    ]

    InspectionFixtures class >> whyKernelALines [
        "The S2 answer: a root-only dependency is one short chain."
        <category: 'pinned wordings'>
        ^Array with: 'my-app 1.0.0 -> kernel-a 1.0.0 (>=1.0.0 <2.0.0)'
    ]

    InspectionFixtures class >> notPinnedLineFor: aName [
        "The S3 diagnosis: the operator asked about a package the lock
         does not hold — their question, never a defect."
        <category: 'pinned wordings'>
        ^aName printString, ' is not pinned in parley.lock'
    ]

    "---- pinned renderings: tree ----"

    InspectionFixtures class >> repeatMarker [
        <category: 'pinned wordings'>
        ^' (repeat)'
    ]

    InspectionFixtures class >> treeLines [
        "The S4 answer: root first, two-space indent per level,
         children sorted by name, the shared node marked at its second
         site and not re-expanded."
        <category: 'pinned wordings'>
        ^Array
            with: 'my-app 1.0.0'
            with: '  kernel-a 1.0.0'
            with: '    kernel-c 2.4.0'
            with: '  kernel-b 1.0.0'
            with: '    kernel-c 2.4.0', self repeatMarker
    ]

    "---- pinned renderings: check ----"

    InspectionFixtures class >> healthyLine [
        "The S5 confirmation: exit 0 says the same thing, but a verb
         that prints nothing reads as a verb that did nothing (the
         noDependenciesLine precedent)."
        <category: 'pinned wordings'>
        ^'parley.lock is healthy - pins satisfy Package.st and nothing pinned is retired'
    ]

    InspectionFixtures class >> missingLockLine [
        "check on a lockless project: exit 1, and the repair is
         resolve — the verb that writes a first lock — not update,
         which is the repair for a CORRUPT one."
        <category: 'pinned wordings'>
        ^'parley.lock is missing - run parley resolve to write it'
    ]

    InspectionFixtures class >> retiredPinLineFor: aName version: aVersionString reason: aReason [
        "The S7 line: the package, the version, and the author''s
         reason VERBATIM — Sprint 10''s retirementReasonFor:version:
         reaching a human for the first time (§8 decision 37)."
        <category: 'pinned wordings'>
        ^'lock pins ', aName printString, ' at ', aVersionString,
            ', which the index has retired: ', aReason
    ]

    InspectionFixtures class >> retiredJson032Line [
        <category: 'pinned wordings'>
        ^self retiredPinLineFor: 'kernel-json' version: '0.3.2'
            reason: RetirementFixtures json032Reason
    ]

    "---- pinned renderings: usage (the GREEN re-pin target) ----"

    InspectionFixtures class >> usageVerbsLine [
        "What the verbs: usage line becomes when the three inspection
         verbs join it. ExecFixtures usageLines is re-pinned to match
         in GREEN, together with the CLI change — re-pinning it in RED
         would fail every settled usage law against a CLI that has not
         moved yet. Re-pinned again at Sprint 12 (issue #14) when
         update gained its optional package — the same sanctioned
         GREEN re-pin, in the same increment as the CLI usage change;
         SelectiveUpdateFixtures usageVerbsLine pinned the new
         rendering in that sprint's RED."
        <category: 'pinned wordings'>
        ^'verbs: init | resolve | install | update [<pkg>] | exec <script> | publish <dir> | why <pkg> | tree | check'
    ]

    "---- the malformed-digest lock (S10, Doc B §5.3) ----"

    InspectionFixtures class >> malformedDigestValue [
        <category: 'malformed digests'>
        ^'nothex'
    ]

    InspectionFixtures class >> malformedDigestLockString [
        "Correct in every key, order and tuple arity; the digest is
         not 64 lowercase hex. The root satisfies the cOnly ''^2.0''
         manifest so nothing else can explain a rejection."
        <category: 'malformed digests'>
        ^'#(#''parley-lock'' 1 #root ''my-app'' #packages #(#(''c'' ''2.4.0'' #sha256 ''',
            self malformedDigestValue, ''')))', SourceFixtures newline
    ]

    InspectionFixtures class >> lockDigestDefectFor: aDigestString package: aName [
        "Private — the defect tail, in the grammar of the settled
         #packages version wording."
        <category: 'malformed digests'>
        ^'#packages digest ', aDigestString printString,
            ' for ', aName printString,
            ' must be 64 lowercase hex characters'
    ]

    InspectionFixtures class >> malformedLockDigestProblemFor: aLockPath [
        "The full S10 problem: the settled three-part LockError shape,
         the digest defect as its middle."
        <category: 'malformed digests'>
        ^LockBoundaryFixtures lockProblemFor: aLockPath message:
            (self lockDigestDefectFor: self malformedDigestValue
                package: 'c')
    ]

    InspectionFixtures class >> emptyDigestLockString [
        "A lock whose pin carries #sha256 '''' — exactly what the
         settled writer produces for an archiveless entry (#archive
         #() renders as the empty digest, and the Installer owns the
         ''no published archive'' diagnosis later). The boundary must
         keep accepting it or Parley rejects its own writer''s output.
         ASSUMPTION posted on issue #13 for the RED review."
        <category: 'malformed digests'>
        ^'#(#''parley-lock'' 1 #root ''my-app'' #packages #(#(''c'' ''2.4.0'' #sha256 '''')))',
            SourceFixtures newline
    ]

    "---- the malformed-digest entry (S11, Doc F §4) ----"

    InspectionFixtures class >> badDigestEntryContents [
        "Literal-valid, tag-valid, schema-shaped — and the #archive
         digest is not 64 lowercase hex."
        <category: 'malformed digests'>
        ^'#(#''parley-index'' 1 #name ''kernel-bad'' #version ''1.0.0'' #summary '''' #author '''' #license '''' #fileIns #(''App.st'') #dependencies #() #archive #(''kernel-bad-1.0.0.star'' #sha256 ''',
            self malformedDigestValue, '''))', SourceFixtures newline
    ]

    InspectionFixtures class >> entryDigestDefectFor: aDigestString [
        "Private — the defect tail, in the grammar of the settled
         #archive shape wording."
        <category: 'malformed digests'>
        ^'#archive digest ', aDigestString printString,
            ' must be 64 lowercase hex characters'
    ]

    InspectionFixtures class >> badDigestProblemFor: aBaseName [
        "The full S11 problem: the file and the defect, batched with
         every other scan problem in sorted-filename order."
        <category: 'malformed digests'>
        ^aBaseName, ': ',
            (self entryDigestDefectFor: self malformedDigestValue)
    ]

    "---- the S12 value corpus ----"

    InspectionFixtures class >> hexDigestCorpus [
        "Value/verdict rows for isHexDigest:. Covers the shape rule
         from every side: length, case, alphabet, and kind (a Symbol
         is a String subclass in 3.2.5 and must still be rejected)."
        <category: 'value corpus'>
        "The two groups are each parenthesized: a binary comma binds
         TIGHTER than the keyword message, so an unparenthesized
         'with: <row>, (Array ...)' would concatenate the LAST ROW with
         the second group and answer four rows instead of eight — with
         at: 1 and at: 2 still lining up, so every law over the corpus
         would pass while never seeing the case, alphabet, empty and
         Symbol rows (probed on 3.2.5; operator amendment at the RED
         review)."
        ^(Array
            with: (Array with: (String new: 64 withAll: $a) with: true)
            with: (Array with: '4da43d9155a1c841dd267a01a54cd0670bcabcdd6a29c46f455ea5e6e93a5edd' with: true)
            with: (Array with: (String new: 63 withAll: $a) with: false)
            with: (Array with: (String new: 65 withAll: $a) with: false)),
        (Array
            with: (Array with: (String new: 64 withAll: $A) with: false)
            with: (Array with: (String new: 64 withAll: $g) with: false)
            with: (Array with: '' with: false)
            with: (Array with: ((String new: 64 withAll: $a) asSymbol) with: false))
    ]

    InspectionFixtures class >> stringCorpus [
        "Value/verdict rows for isString: — the settled predicate the
         two validators each kept a private copy of."
        <category: 'value corpus'>
        ^Array
            with: (Array with: 'kernel-json' with: true)
            with: (Array with: '' with: true)
            with: (Array with: #root with: false)
            with: (Array with: 42 with: false)
            with: (Array with: #('a') with: false)
    ]

    "---- the S8 digest tree ----"

    InspectionFixtures class >> digestTreeOf: aDirPath [
        "Every regular file under aDirPath, recursively, as a
         Dictionary of relative path -> settled Sha256 hex digest.
         Comparing two of these proves BYTE-IDENTITY of the whole
         tree: same file set, same bytes — the only proof S8 accepts,
         because ''no exception was raised'' proves nothing about
         writes. Directories are not recorded: the composition root
         creates empty state directories on every run by design."
        <category: 'digest tree'>
        | map |
        map := Dictionary new.
        self addFilesUnder: aDirPath prefix: '' into: map.
        ^map
    ]

    InspectionFixtures class >> addFilesUnder: aDirPath prefix: aPrefix into: aMap [
        "Private — namesDo: at every level; File>>files never recurses
         (the settled trap)."
        <category: 'private'>
        (File name: aDirPath) namesDo: [:each |
            (#('.' '..') includes: each) ifFalse: [
                | full |
                full := aDirPath, '/', each.
                (File name: full) isDirectory
                    ifTrue: [self addFilesUnder: full
                        prefix: aPrefix, each, '/' into: aMap]
                    ifFalse: [aMap at: aPrefix, each
                        put: (Sha256 hexDigestOf: (File name: full) contents)]]]
    ]

    "---- the S13 line-split sender tree ----"

    InspectionFixtures class >> lineSplitSenderSource [
        "A source file whose send of the reader splits receiver and
         selector across two lines — never filed in, only read as
         text by the enumeration."
        <category: 'line split'>
        ^'Object subclass: FakeSplitBoundary [
    poke: aStream [
        <category: ''reading''>
        ^IndexEntryReader
            readFrom: aStream
    ]
]', SourceFixtures newline
    ]

    InspectionFixtures class >> quietSource [
        "A neighbour that never sends the reader — the walk must not
         report it."
        <category: 'line split'>
        ^'Object subclass: FakeQuietValue [
    answer [
        <category: ''answering''>
        ^42
    ]
]', SourceFixtures newline
    ]

    InspectionFixtures class >> lineSplitSubdirectoryNames [
        <category: 'line split'>
        ^#('domain' 'exec')
    ]

    InspectionFixtures class >> populateLineSplitTreeIn: aRootPath [
        "A miniature src/ layout under aRootPath: exec/ holds the
         line-split sender, domain/ holds the quiet neighbour."
        <category: 'line split'>
        Directory create: aRootPath, '/exec'.
        Directory create: aRootPath, '/domain'.
        SourceFixtures write: self lineSplitSenderSource
            toFile: 'FakeSplitBoundary.st' in: aRootPath, '/exec'.
        SourceFixtures write: self quietSource
            toFile: 'FakeQuietValue.st' in: aRootPath, '/domain'
    ]

    InspectionFixtures class >> lineSplitSenderFileNames [
        "What the hardened enumeration must answer over that tree."
        <category: 'line split'>
        ^#('exec/FakeSplitBoundary.st')
    ]
]

CLI subclass: ResolverTrapCLI [

    <comment: 'The S9 double: a CLI whose resolveAndLock: — the one
funnel through which resolve, update and the invalid-pin fallback
reach the resolver — signals instead of resolving. why and tree
succeeding through it proves the graph came from the lock plus the
snapshot (§8 decision 40); the guard law that resolve trips it proves
the trap sits on the real path. An edge double, never domain.'>

    resolveAndLock: aManifest [
        "Private — the trap."
        <category: 'private'>
        ^self error: self class trapMessage
    ]

    ResolverTrapCLI class >> trapMessage [
        <category: 'accessing'>
        ^'purity violated: an inspection verb entered the resolver'
    ]
]

Namespace current: Smalltalk.
