"Parley Sprint 21 — the shared home for path and dev dependency
 fixtures (issue #23; Doc B §2/§3.2/§5.3, Doc C §1.3/§2, Doc E §4.1,
 Doc F §1 step 0; §8 decisions 68, 69, 83).

 ONE SHARED BUILDER, NOT A COPY PER FILE. Five test files need a
 sibling directory holding a Package.st and its .st sources, and a root
 whose manifest declares a path dependency on it. Written once here for
 the reason ExecFixtures usageLines exists: five literal copies of one
 fixture are five movers no oracle grep can see (the F18 lesson this
 project has now paid for twice).

 SIBLINGS LIVE BESIDE THE WORKING DIRECTORY, UNDER tmp/, AND THE
 DECLARED PATH IS A RELATIVE STRING. That is not fixture convenience:
 §8 decision 69 requires the lock to byte-preserve the AUTHOR'S declared
 string — a lock travels with its checkout, so it carries '../kernel-text'
 and never one machine's absolute expansion — and a fixture that declared
 an absolute path could not fail when an implementation expanded it.
 So a working directory tmp/parley-<label> takes a sibling at
 tmp/parley-<label>-text and declares it as '../parley-<label>-text'.

 EVERY DIRECTORY IS LABELLED PER SCENARIO. Sprint 19 lost a scenario to
 one directory name colliding across two iterations of a driver loop;
 every builder here takes a label and every caller passes its own.

 THE PINNED WORDINGS LIVE HERE AS ORACLES, and each is asserted twice
 (§8 decision 81's rule): once against the src/ declaration that must
 equal it, and once against a real verb's rendered line. A wording
 composed at the site that refuses is the drift the idiom exists to
 prevent, so no law here composes one."

Namespace current: Parley.

Object subclass: PathDepFixtures [

    <comment: 'Sibling package builders, root manifests declaring path
and dev dependencies, the index entries that make precedence and the
reporting matrix falsifiable, the #path lock oracles, and the pinned
wordings of every refusal, marker and sentence this sprint declares.
Stateless; uniqueness comes from per-test labels.'>

    "---- sibling directories (the code you are developing) ----"

    PathDepFixtures class >> siblingNameFor: aLabel [
        "The sibling directory's path, beside the working directory
         tmp/parley-<aLabel> rather than inside it: a path dependency
         points at another checkout, and a fixture that nested one
         inside the project would prove nothing about '..'."
        <category: 'siblings'>
        ^'tmp/parley-', aLabel
    ]

    PathDepFixtures class >> declaredPathFor: aLabel [
        "The RELATIVE string a root manifest declares for the sibling
         tmp/parley-<aLabel>, from a working directory that is also
         directly under tmp/. This exact string is what the lock must
         byte-preserve."
        <category: 'siblings'>
        ^'../parley-', aLabel
    ]

    PathDepFixtures class >> aliasedDeclaredPathFor: aLabel through: aMidLabel [
        "The SAME directory as declaredPathFor: aLabel, spelled with a
         detour that textual canonicalisation collapses (§8 decision 68
         as amended at Sprint 21's Gate A): one <segment>/.. pair and
         one ./ segment, so a build implementing only one of the two
         collapse rules fails rather than passing by half.

         It is deliberately NOT the same bytes as declaredPathFor: —
         the whole claim is that two TEXTUALLY DISTINCT declared
         strings reaching one directory are one supplier."
        <category: 'siblings'>
        ^'../parley-', aMidLabel, '/.././parley-', aLabel
    ]

    PathDepFixtures class >> textSiblingContentsAt: aVersionString [
        "kernel-text, a library under development: one fileIn, no
         dependencies of its own."
        <category: 'siblings'>
        ^'Parley define: [:pkg |
    pkg
        name: ''kernel-text'';
        version: ''', aVersionString, ''';
        summary: ''text helpers, under development'';
        fileIns: #(''KernelText.st'') ]', SourceFixtures newline
    ]

    PathDepFixtures class >> textSourceAnswering: aString [
        "The sibling's one source file, written the way A PACKAGE AUTHOR
         writes one: the class is defined at TOP LEVEL, in no namespace
         of Parley's.

         AMENDED MID-SPRINT (GREEN step 4). It carried
         `Namespace current: Parley.` — the HARNESS's idiom, not an
         author's — and the curated child is a bare image in which
         Parley is not a namespace at all, so the probe script died on
         `DeferredVariableBinding>>resolvePathFrom:` before reaching the
         behaviour S9 and S10 exist to observe. A sibling author would
         never define into the package manager's own namespace, and the
         fixture now models what they actually write."
        <category: 'siblings'>
        ^'Object subclass: KernelText [
    KernelText class >> shout [ ^''', aString, ''' ]
]', SourceFixtures newline
    ]

    PathDepFixtures class >> textSiblingNamed: aLabel version: aVersionString answering: aString [
        "Create the kernel-text sibling and answer its directory path."
        <category: 'siblings'>
        | path |
        path := SourceFixtures directoryNamed: aLabel.
        ExecFixtures writePackage: (self textSiblingContentsAt: aVersionString)
            in: path.
        SourceFixtures write: (self textSourceAnswering: aString)
            toFile: 'KernelText.st' in: path.
        ^path
    ]

    PathDepFixtures class >> textSiblingNamed: aLabel [
        "The canonical sibling: kernel-text 1.2.0, shouting its own
         name."
        <category: 'siblings'>
        ^self textSiblingNamed: aLabel
            version: self siblingVersionString
            answering: self firstShout
    ]

    PathDepFixtures class >> siblingVersionString [
        "The version the canonical sibling DECLARES — the version the
         lock must pin, and the one check's drift leg compares against."
        <category: 'siblings'>
        ^'1.2.0'
    ]

    PathDepFixtures class >> driftedVersionString [
        "The version S23 and S34 move the sibling's declaration to,
         without touching the lock."
        <category: 'siblings'>
        ^'1.3.0'
    ]

    PathDepFixtures class >> firstShout [
        "What the sibling answers before the edit."
        <category: 'siblings'>
        ^'text-before'
    ]

    PathDepFixtures class >> secondShout [
        "What the sibling answers after the edit S10 makes — the
         workflow this sprint exists for, observed as a different byte
         string on the child's stdout with no publish in between."
        <category: 'siblings'>
        ^'text-after'
    ]

    "---- a sibling with its own path dependency, and a dev one ----"

    PathDepFixtures class >> walkingSiblingContentsOn: aDeclaredPath [
        "The S3 sibling: kernel-text declaring a path dependency of its
         OWN on kernel-b, and a devDependency the overlay must EXCLUDE
         exactly as publish would (§8 decision 69). Both in one file,
         because S3's whole claim is that the walk follows one and drops
         the other."
        <category: 'siblings'>
        ^'Parley define: [:pkg |
    pkg
        name: ''kernel-text'';
        version: ''1.2.0'';
        fileIns: #(''KernelText.st'');
        dependency: ''kernel-b'' path: ''', aDeclaredPath, ''';
        devDependency: ''kernel-lint'' constraint: ''^1.0.0'' ]',
            SourceFixtures newline
    ]

    PathDepFixtures class >> bSiblingContents [
        "The second hop of the walk: kernel-b 2.5.0, no dependencies."
        <category: 'siblings'>
        ^'Parley define: [:pkg |
    pkg
        name: ''kernel-b'';
        version: ''2.5.0'';
        fileIns: #(''KernelB.st'') ]', SourceFixtures newline
    ]

    PathDepFixtures class >> bSiblingSource [
        "Top level, for the reason textSourceAnswering: records: this is
         a package author's source, and no author defines into Parley's
         namespace. Nothing sends KernelB a message today, so the
         amendment is consistency rather than a repair — but a child
         that ever files this in would die exactly as S9's did."
        <category: 'siblings'>
        ^'Object subclass: KernelB [
    KernelB class >> mark [ ^''b-loaded'' ]
]', SourceFixtures newline
    ]

    PathDepFixtures class >> bSiblingNamed: aLabel [
        "Create the kernel-b sibling and answer its directory path."
        <category: 'siblings'>
        | path |
        path := SourceFixtures directoryNamed: aLabel.
        ExecFixtures writePackage: self bSiblingContents in: path.
        SourceFixtures write: self bSiblingSource
            toFile: 'KernelB.st' in: path.
        ^path
    ]

    PathDepFixtures class >> seedingSiblingContents [
        "The S4 sibling: it declares an INDEX dependency whose name the
         root names nowhere, so only the overlay's re-seed can put it in
         a sparse closure (Doc C §1.3)."
        <category: 'siblings'>
        ^'Parley define: [:pkg |
    pkg
        name: ''kernel-text'';
        version: ''1.2.0'';
        fileIns: #(''KernelText.st'');
        dependency: ''kernel-streams'' constraint: ''>=1.0.0 <2.0.0'' ]',
            SourceFixtures newline
    ]

    PathDepFixtures class >> seedingSiblingNamed: aLabel [
        <category: 'siblings'>
        | path |
        path := SourceFixtures directoryNamed: aLabel.
        ExecFixtures writePackage: self seedingSiblingContents in: path.
        SourceFixtures write: (self textSourceAnswering: self firstShout)
            toFile: 'KernelText.st' in: path.
        ^path
    ]

    PathDepFixtures class >> seedOnlyName [
        "The name that appears in NEITHER the root Package.st NOR
         parley.lock, and only in the sibling's own declaration. If it
         appeared in either, S4 would pass over a base that was seeded
         the settled way and the law would be vacuous — the trap the
         Sprint 20 S23 review named."
        <category: 'siblings'>
        ^'kernel-streams'
    ]

    PathDepFixtures class >> malformedSiblingContents [
        "A sibling whose Package.st fails validation: the settled
         authoring diagnosis must name the SIBLING's path, never the
         root's (§8 decision 68)."
        <category: 'siblings'>
        ^'Parley define: [:pkg |
    pkg
        name: ''kernel-text'';
        version: ''banana'';
        fileIns: #(''KernelText.st'') ]', SourceFixtures newline
    ]

    PathDepFixtures class >> malformedSiblingNamed: aLabel [
        <category: 'siblings'>
        | path |
        path := SourceFixtures directoryNamed: aLabel.
        ExecFixtures writePackage: self malformedSiblingContents in: path.
        ^path
    ]

    "---- root manifests ----"

    PathDepFixtures class >> rootDeclaring: aDeclaredPath [
        "my-app 1.0.0 with ONE path dependency and nothing else — the
         S1 fixture, and the smallest manifest that can carry the
         feature."
        <category: 'roots'>
        ^'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''kernel-text'' path: ''', aDeclaredPath, ''' ]',
            SourceFixtures newline
    ]

    PathDepFixtures class >> rootDeclaring: aDeclaredPath andIndexDependency: aName constraint: aConstraintString [
        "A root that needs BOTH a directory and an index — the mixed
         project S5, S13, S14, S21, S24 and S34 are built on."
        <category: 'roots'>
        ^'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''kernel-text'' path: ''', aDeclaredPath, ''';
        dependency: ''', aName, ''' constraint: ''', aConstraintString,
            ''' ]', SourceFixtures newline
    ]

    PathDepFixtures class >> rootDeclaringTwoPaths: aFirstPath and: aSecondPath [
        "Two path dependencies declaring THE SAME NAME from different
         directories — the S6 refusal fixture."
        <category: 'roots'>
        ^'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''kernel-text'' path: ''', aFirstPath, ''';
        dependency: ''kernel-text'' path: ''', aSecondPath, ''' ]',
            SourceFixtures newline
    ]

    PathDepFixtures class >> rootWithDevDependencyOn: aName constraint: aConstraintString [
        "A root whose only declaration beyond its own fields is a DEV
         dependency: resolved and installed for the root alone, never
         serialized into an entry (§8 decision 69)."
        <category: 'roots'>
        ^'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        devDependency: ''', aName, ''' constraint: ''', aConstraintString,
            ''' ]', SourceFixtures newline
    ]

    PathDepFixtures class >> libraryContentsWithDev: aBoolean [
        "ONE library manifest in two spellings: identical in every field
         an entry carries, differing only in whether it declares dev
         dependencies. S16 publishes both and requires BYTE-IDENTICAL
         entries — true by construction today, which is exactly how the
         last three drift families started (§8 decision 69)."
        <category: 'roots'>
        ^'Parley define: [:pkg |
    pkg
        name: ''kernel-json'';
        version: ''0.3.1'';
        summary: ''a reader and writer'';
        author: ''Leonardo'';
        license: ''MIT'';
        fileIns: #(''Json.st'')',
            (aBoolean
                ifTrue: [';
        devDependency: ''kernel-lint'' constraint: ''^1.0.0''']
                ifFalse: ['']),
            ' ]', SourceFixtures newline
    ]

    PathDepFixtures class >> librarySource [
        <category: 'roots'>
        ^'Namespace current: Parley.
Object subclass: KernelJson [
    KernelJson class >> mark [ ^''json'' ]
]
Namespace current: Smalltalk.', SourceFixtures newline
    ]

    PathDepFixtures class >> emptyRootContents [
        "What parley init writes, in effect: a manifest declaring NO
         dependency at all — decision 83's first state, and the first
         session's own project."
        <category: 'roots'>
        ^'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'') ]', SourceFixtures newline
    ]

    PathDepFixtures class >> indexNeedingRootContents [
        "Decision 83's third state: an index-needing dependency and no
         source wired."
        <category: 'roots'>
        ^'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''kernel-a'' constraint: ''^1.0.0'' ]',
            SourceFixtures newline
    ]

    PathDepFixtures class >> indexNeedingName [
        "The name the third state's refusal must name."
        <category: 'roots'>
        ^'kernel-a'
    ]

    PathDepFixtures class >> workDirNamed: aLabel contents: aContentsString [
        "A working directory holding aContentsString as its Package.st
         and an App.st beside it, so exec has something of the root's
         own to load."
        <category: 'roots'>
        | path |
        path := SourceFixtures directoryNamed: aLabel.
        ExecFixtures writePackage: aContentsString in: path.
        SourceFixtures write: 'Object subclass: App [ ]', SourceFixtures newline
            toFile: 'App.st' in: path.
        ^path
    ]

    "---- index entries that make the claims falsifiable ----"

    PathDepFixtures class >> textEntryAt: aVersionString [
        "An INDEX release of kernel-text. S2 needs one so precedence is
         proved where it could fail: an overlay that merely filled a gap
         would pass a fixture where the index publishes nothing."
        <category: 'index entries'>
        ^'#(#''parley-index'' 1 #name ''kernel-text'' #version ''',
            aVersionString,
            ''' #summary ''the index''''s own kernel-text'' #author '''' #license '''' #fileIns #(''KernelText.st'') #dependencies #() #archive #(''kernel-text-',
            aVersionString,
            '.star'' #sha256 ''aa11000000000000000000000000000000000000000000000000000000000000''))',
            SourceFixtures newline
    ]

    PathDepFixtures class >> appEntryRequiringTextAtLeastTwo [
        "kernel-app 1.0.0 requiring kernel-text >=2.0.0 — an index edge
         the sibling's 1.2.0 cannot satisfy. S5's conflict, and the
         proof there is never a silent fallback to the index's 2.0.0."
        <category: 'index entries'>
        ^'#(#''parley-index'' 1 #name ''kernel-app'' #version ''1.0.0'' #summary '''' #author '''' #license '''' #fileIns #(''KernelApp.st'') #dependencies #(#(''kernel-text'' ''>=2.0.0'')) #archive #(''kernel-app-1.0.0.star'' #sha256 ''bb22000000000000000000000000000000000000000000000000000000000000''))',
            SourceFixtures newline
    ]

    PathDepFixtures class >> plainEntryFor: aName version: aVersionString dependencies: aDependenciesText [
        "A minimal published entry, with an empty archive so no fixture
         here has to invent a digest for bytes that do not exist."
        <category: 'index entries'>
        ^'#(#''parley-index'' 1 #name ''', aName, ''' #version ''',
            aVersionString,
            ''' #summary '''' #author '''' #license '''' #fileIns #(''X.st'') #dependencies #(',
            aDependenciesText, ') #archive #())', SourceFixtures newline
    ]

    PathDepFixtures class >> retirementRecordForTextAt: aVersionString [
        "The index retiring the SAME name and version the path supplies
         — S24's fixture. The path pin must draw no retirement problem;
         a retired INDEX pin in the same run still must."
        <category: 'index entries'>
        ^'#(#''parley-retired'' 1 #retirements #(#(''kernel-text'' ''',
            aVersionString,
            ''' ''security: retired by the index owner'') #(''kernel-old'' ''1.0.0'' ''deprecated: renamed'')))',
            SourceFixtures newline
    ]

    "---- lock oracles (Doc B §5.3) ----"

    PathDepFixtures class >> pathTupleFor: aName version: aVersionString path: aDeclaredPath [
        "The declared ALTERNATIVE pin form: third position the literal
         symbol #path, fourth a non-empty String carrying the AUTHOR'S
         declared path byte for byte."
        <category: 'lock oracles'>
        ^'#(''', aName, ''' ''', aVersionString, ''' #path ''',
            aDeclaredPath, ''')'
    ]

    PathDepFixtures class >> lockTextRoot: aRootName packages: aTupleText [
        "A whole #'parley-lock' 1 artifact in the settled canonical
         rendering — single spaces, one line, one trailing newline."
        <category: 'lock oracles'>
        ^'#(#''parley-lock'' 1 #root ''', aRootName, ''' #packages #(',
            aTupleText, '))', SourceFixtures newline
    ]

    PathDepFixtures class >> soleTextPinLockFor: aDeclaredPath [
        "The S1 oracle, HAND-WRITTEN rather than computed by the writer
         under test: an oracle produced by the code it checks cannot
         fail when that code is wrong."
        <category: 'lock oracles'>
        ^self lockTextRoot: 'my-app'
            packages: (self pathTupleFor: 'kernel-text'
                version: self siblingVersionString
                path: aDeclaredPath)
    ]

    PathDepFixtures class >> preSprintLockText [
        "A lock written before this sprint existed: #sha256 pins only.
         It must keep validating unchanged, which is half of S11."
        <category: 'lock oracles'>
        ^self lockTextRoot: 'my-app'
            packages: '#(''kernel-a'' ''1.0.0'' #sha256 ''ab12000000000000000000000000000000000000000000000000000000000000'')'
    ]

    PathDepFixtures class >> emptyPathLockText [
        "A #path tuple whose fourth element is the EMPTY string — the
         shape violation Doc B §5.3 names: a non-empty String, or the
         boundary has accepted a pin that describes nothing."
        <category: 'lock oracles'>
        ^self lockTextRoot: 'my-app'
            packages: '#(''kernel-text'' ''1.2.0'' #path '''')'
    ]

    PathDepFixtures class >> wrongMarkerLockText [
        "A four-element tuple whose third element is neither #sha256 nor
         #path. The boundary accepts EXACTLY the two declared forms and
         nothing between them."
        <category: 'lock oracles'>
        ^self lockTextRoot: 'my-app'
            packages: '#(''kernel-text'' ''1.2.0'' #directory ''../parley-text'')'
    ]

    PathDepFixtures class >> writeLock: aLockText in: aWorkDir [
        <category: 'lock oracles'>
        SourceFixtures write: aLockText toFile: 'parley.lock' in: aWorkDir
    ]

    PathDepFixtures class >> lockTextIn: aWorkDir [
        <category: 'lock oracles'>
        ^(File name: aWorkDir, '/parley.lock') contents
    ]

    "---- the declared wordings (§8 decision 81: consumed twice) ----"

    PathDepFixtures class >> twoPathsRefusalFor: aName first: aFirstPath second: aSecondPath [
        "S6: one diagnosis naming BOTH paths. Naming one would leave the
         operator to find the other, and naming neither would be a
         refusal that does not say what to repair."
        <category: 'pinned wordings'>
        ^aName printString, ' is declared by two path dependencies - ',
            aFirstPath printString, ' and ', aSecondPath printString,
            ' - a name may be supplied by only one directory'
    ]

    PathDepFixtures class >> conflictProvenanceLineFor: aName path: aDeclaredPath [
        "S5: the line above the settled narration, in the held-pins-line
         placement (§8 decision 46's family). The resolver answered
         truthfully about the world it was given and cannot know a
         directory supplied one of its packages; the verb had that
         context and owes the sentence."
        <category: 'pinned wordings'>
        ^aName printString, ' is supplied by the path dependency ',
            aDeclaredPath printString,
            ' at the version that directory declares - the index''s releases of it were not considered'
    ]

    PathDepFixtures class >> infoPathProvenanceLineFor: aName path: aDeclaredPath [
        "S20: the settled unknown-package answer EXTENDED, never
         contradicted. The operator asked about the index, and the
         index's answer is still no — but a tool that knows why the
         project runs anyway owes the second half."
        <category: 'pinned wordings'>
        ^aName printString,
            ' is not published by the configured index - it is supplied by the path dependency ',
            aDeclaredPath printString
    ]

    PathDepFixtures class >> pathAllowedMarkerFor: aDeclaredPath [
        "S21: the SECOND declared marker in §8 decision 82's family. It
         must not read like the transitive one: the operator DECLARED
         this dependency, so the repair is in their hands and the marker
         says where it lives."
        <category: 'pinned wordings'>
        ^'(path ', aDeclaredPath printString, ' - the directory decides)'
    ]

    PathDepFixtures class >> whyHopTextFor: aName version: aVersionString path: aDeclaredPath [
        "S22: what why renders for the hop into a path-supplied pin. The
         operator asked why a pin exists, and a directory you declared
         is the answer — so the hop names the directory where an index
         pin names the constraint."
        <category: 'pinned wordings'>
        ^' -> ', aName, ' ', aVersionString, ' (path ',
            aDeclaredPath printString, ')'
    ]

    PathDepFixtures class >> driftProblemFor: aName pinned: aPinnedVersion declared: aDeclaredVersion path: aDeclaredPath [
        "S23: check's drift leg, in the settled check-problem shape the
         retirement leg already uses. The bound is stated in the
         sentence itself: it is the DECLARED version that moved, which
         is the only thing this leg reads."
        <category: 'pinned wordings'>
        ^'lock pins ', aName printString, ' at ', aPinnedVersion,
            ', which the path dependency ', aDeclaredPath printString,
            ' now declares as ', aDeclaredVersion,
            ' - run parley resolve to update it'
    ]

    PathDepFixtures class >> publishPathRefusalFor: aName path: aDeclaredPath [
        "S15: Doc F §1 step 0. A release cannot depend on somebody's
         laptop, and the refusal names the dependency and the path so
         the author knows which clause to remove."
        <category: 'pinned wordings'>
        ^aName printString, ' is a path dependency on ',
            aDeclaredPath printString,
            ' - a published release cannot depend on a directory'
    ]

    PathDepFixtures class >> needsIndexRefusalFor: someNames [
        "S32: decision 83's in-verb refusal, at exit 1 on decision 80's
         precedent — the argv is well formed and the project is the
         limit. It names what the manifest declares and the flags, the
         config file or the environment variables that can answer, and
         NEVER the usage block.

         RE-PINNED AT SPRINT 22 (§8 decision 85): the sentence gains
         the variables as its third remedy, composed from the declared
         table's own field — here through the EnvFixtures mirror, which
         the EnvLayerTest drift law holds equal to the table."
        <category: 'pinned wordings'>
        ^'no index is wired, and Package.st declares ',
            (CommandLine list: someNames conjunction: 'and'),
            ' - give ',
            (CommandLine list: CommandLine sourceFlagNames conjunction: 'or'),
            ', record one in parley.config.st, or set ',
            EnvFixtures variableListText
    ]

    PathDepFixtures class >> offlineRefusalFor: aFlag [
        "S25/S26: the --offline guard invariant, enforced at source
         wiring. It names the transport the invocation WANTED, because
         the operator gave a flag or wrote a config and is owed the
         reason those two disagree."
        <category: 'pinned wordings'>
        ^'--offline forbids the ', aFlag,
            ' source this invocation would use - it reaches the network, and nothing was run'
    ]

    PathDepFixtures class >> lockedRefusalFor: aName pinned: aPinnedText would: aWouldText [
        "S28/S29: the --locked guard invariant, enforced at the one
         lock-write site. It names the FIRST differing pin in sorted
         order — one name, because the operator is deciding whether to
         re-run without the flag, not auditing a diff."
        <category: 'pinned wordings'>
        ^'--locked forbids changing parley.lock - ', aName printString,
            ' is pinned at ', aPinnedText, ' and would become ',
            aWouldText, ', and nothing was written'
    ]

    PathDepFixtures class >> absentPinText [
        "What the --locked refusal renders for a pin the current lock
         does not carry at all — including the case of no lock, where
         every pin the resolution answers is new."
        <category: 'pinned wordings'>
        ^'nothing'
    ]

    "---- the mode flags ----"

    PathDepFixtures class >> offlineFlag [
        <category: 'mode flags'>
        ^'--offline'
    ]

    PathDepFixtures class >> lockedFlag [
        <category: 'mode flags'>
        ^'--locked'
    ]

    PathDepFixtures class >> modeFlagNames [
        "Both mode flags, as the drift law's oracle. They are VALUELESS
         and build nothing, which is exactly why they are a second
         declared table rather than sourceFlags rows: SourceFlagTest
         holds every row of that table to three columns, and forcing a
         flag that constructs no source into a (flag, Class, builder)
         shape would move a law this sprint declares a non-mover."
        <category: 'mode flags'>
        ^Array with: self offlineFlag with: self lockedFlag
    ]

    PathDepFixtures class >> networkFlagNames [
        "The declared source flags --offline forbids. --source is absent
         deliberately: a local directory is what offline MEANS, and a
         predicate that refused it would make the flag useless for the
         case it exists to serve."
        <category: 'mode flags'>
        ^Array with: '--git' with: '--index'
    ]

    "---- README documentation markers (the Sprint 15 shape) ----"

    PathDepFixtures class >> readmeMarkers [
        "What the README must say about this sprint's surface, as
         (description, needle) pairs. NO SETTLED LAW FORCES FLAG
         DOCUMENTATION — the settled README drift laws bind VERBS only,
         verified at staging — so this sprint declares the obligation
         and the law that keeps it. A limitation or a flag not written
         where users read is not stated at all (§8 decision 45's
         standard)."
        <category: 'readme'>
        ^(Array
            with: (Array with: 'the path dependency vocabulary'
                with: 'dependency:')
            with: (Array with: 'the path keyword itself' with: 'path:')
            with: (Array with: 'the dev dependency vocabulary'
                with: 'devDependency:')
            with: (Array with: 'the offline mode flag' with: '--offline')
            with: (Array with: 'the locked mode flag' with: '--locked'))
    ]

    "---- driving ----"

    PathDepFixtures class >> resultOf: anArgvArray in: aWorkDir runner: aRunner [
        "One invocation through the real composition root."
        <category: 'driving'>
        ^(CommandLine in: aWorkDir runner: aRunner) run: anArgvArray
    ]

    PathDepFixtures class >> resolveArgvOn: anIndexDir [
        <category: 'driving'>
        ^Array with: 'resolve' with: '--source' with: anIndexDir
    ]

    PathDepFixtures class >> flaglessResolveArgv [
        "resolve with no source flag at all — the argv decision 83
         makes legal, and the one every settled resolve-usage law is
         built on."
        <category: 'driving'>
        ^Array with: 'resolve'
    ]
]

Namespace current: Smalltalk.
