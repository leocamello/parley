"Parley Sprint 10 — fixtures for the retirement schema (issue #12;
 Doc B §5.5, Doc C §2.1, Doc F §4.2/§6).

 This is one of the sprint's two new support files. It carries the
 retirement-bearing index directories, the malformed-record corpus, the
 hand-built snapshots the purity proof needs, the fixture git repository
 and every pinned Sprint 10 retirement wording. The settled
 SourceFixtures / ExecFixtures / InstallFixtures / PublishFixtures /
 CommandLineFixtures / LockBoundaryFixtures / ResolverFixtures helpers
 are reused UNCHANGED — in particular PublishFixtures' git repository
 builders, which supply the committer identity per command so the
 developer's git config is never read for identity and never written,
 and ResolverFixtures release:version:sha256:dependencies:, which is
 the settled snapshot release-tuple protocol.

 THE SHAPE UNDER TEST. A retired release stays FETCHABLE and is
 EXCLUDED FROM FRESH RESOLUTION. The signal is an index-level record
 (Doc B §5.5) — never a key inside a published entry — so the fixtures
 below always hold the retirement in a SEPARATE artifact beside
 untouched entries. kernel-json 0.3.1 and 0.3.2 are the two releases;
 0.3.2 is the retired one; my-app depends on kernel-json ^0.3.0, so
 both are allowed by the constraint and only retirement can decide.

 Filesystem discipline (as Sprints 4-9): every fixture path — index
 directories, working dirs, repositories, stores — lives under tmp/, is
 unique per test via a label, and is removed recursively in tearDown
 through ExecFixtures removeTree:; tmp/ is empty or absent after a clean
 run. The developer image is never mutated and no network is contacted:
 every repo path is a local path under tmp/ and every clone is local.

 Process discipline (unchanged): ProcessRunner is the ONLY class that
 spawns, in src/ and in tests alike. This file composes command-line
 STRINGS as pure values and builds fixture repositories through the
 settled PublishFixtures builders, which run through ProcessRunner.

 Digest discipline (Doc E §5). The archive bytes here are AUTHORED
 opaque byte strings, so their digests are pinned literals an operator
 can verify by hand, exactly as the Sprint 5 InstallFixtures digests
 are. Each was produced with, e.g.:
   printf '%s' 'opaque archive bytes: kernel-json 0.3.1' | sha256sum
 (No trailing newline — the fixture writes exactly these bytes.)

 Pinned wording decisions (posted on issue #12 for confirmation) live
 in the methods:
   - the retirement record's canonical rendering —
     retirementRecordWith: (Doc B §5.5 §5.4 order and whitespace);
   - the malformed-record problems — recordPairingProblemFor: and its
     four siblings, which follow the settled DirectorySource schema
     grammar ('<basename>: <defect>') so an operator reads one voice."

Namespace current: Parley.

Object subclass: RetirementFixtures [

    <comment: 'Class-side factory for Sprint 10 retirement fixtures:
index directories holding entries plus retirement records (including
the record deliberately named like an entry), the malformed-record
corpus, hand-built snapshots with and without a retired release, the
kernel-json working directory and its lock oracles, a fixture git
repository, and every pinned retirement wording. Stateless;
uniqueness comes from per-test labels.'>

    "---- authored archive bytes and their pinned digests ----"

    RetirementFixtures class >> archiveBytesJson031 [
        <category: 'archive bytes'>
        ^'opaque archive bytes: kernel-json 0.3.1'
    ]

    RetirementFixtures class >> archiveBytesJson032 [
        <category: 'archive bytes'>
        ^'opaque archive bytes: kernel-json 0.3.2'
    ]

    RetirementFixtures class >> archiveBytesOld100 [
        <category: 'archive bytes'>
        ^'opaque archive bytes: kernel-old 1.0.0'
    ]

    RetirementFixtures class >> archiveBytesOld110 [
        <category: 'archive bytes'>
        ^'opaque archive bytes: kernel-old 1.1.0'
    ]

    RetirementFixtures class >> digestJson031 [
        "The true SHA-256 of archiveBytesJson031 (operator-verifiable)."
        <category: 'digests'>
        ^'5694bf7de6212014986f7e7c154ee23661620412791a93f8164cd2488c2201ad'
    ]

    RetirementFixtures class >> digestJson032 [
        "The true SHA-256 of archiveBytesJson032."
        <category: 'digests'>
        ^'f9c5c7360ad35da62006731534269119221ac07deaa585679001556f40ed92f4'
    ]

    RetirementFixtures class >> digestOld100 [
        "The true SHA-256 of archiveBytesOld100."
        <category: 'digests'>
        ^'97bd8b4c4c864ebf19447468a5b12a4ab121e4eb74ef2d42d0f55debd5ec7e5d'
    ]

    RetirementFixtures class >> digestOld110 [
        "The true SHA-256 of archiveBytesOld110."
        <category: 'digests'>
        ^'4828a2d23170046f521c3e738b9e188adfc33f580f6ab054b1c2ccbab04b6489'
    ]

    "---- the index entries (Doc B §5.2 schema-exact, untouched by retirement) ----"

    RetirementFixtures class >> entryNamed: aName version: aVersionString digest: aDigest [
        "One dependency-free entry naming its archive by the storage
         convention. Retirement never rewrites an entry — that is the
         §5.5 ruling — so these are ordinary entries in every sprint."
        <category: 'index entries'>
        ^'#(#''parley-index'' 1 #name ''', aName,
            ''' #version ''', aVersionString,
            ''' #summary '''' #author '''' #license '''' #fileIns #(''App.st'') #dependencies #() #archive #(''',
            aName, '-', aVersionString, '.star'' #sha256 ''',
            aDigest, '''))', SourceFixtures newline
    ]

    RetirementFixtures class >> entryJson031 [
        <category: 'index entries'>
        ^self entryNamed: 'kernel-json' version: '0.3.1'
            digest: self digestJson031
    ]

    RetirementFixtures class >> entryJson032 [
        <category: 'index entries'>
        ^self entryNamed: 'kernel-json' version: '0.3.2'
            digest: self digestJson032
    ]

    RetirementFixtures class >> entryOld100 [
        <category: 'index entries'>
        ^self entryNamed: 'kernel-old' version: '1.0.0'
            digest: self digestOld100
    ]

    RetirementFixtures class >> entryOld110 [
        <category: 'index entries'>
        ^self entryNamed: 'kernel-old' version: '1.1.0'
            digest: self digestOld110
    ]

    "---- the retirement record (Doc B §5.5) ----"

    RetirementFixtures class >> json032Reason [
        "The reason the index owner wrote. It travels verbatim to
         retirementReasonFor:version: and is used by nothing inside
         resolution."
        <category: 'retirement records'>
        ^'security: CVE-2026-1234 - stay on 0.3.1 until 0.3.3 lands'
    ]

    RetirementFixtures class >> json031Reason [
        <category: 'retirement records'>
        ^'security: CVE-2026-1234 affects every 0.3.x release'
    ]

    RetirementFixtures class >> old100Reason [
        <category: 'retirement records'>
        ^'deprecated: renamed to kernel-new'
    ]

    RetirementFixtures class >> retirementTupleFor: aName version: aVersionString reason: aReason [
        "Private — one rendered #(<name> <version> <reason>) triple."
        <category: 'retirement records'>
        ^'#(''', aName, ''' ''', aVersionString, ''' ''', aReason, ''')'
    ]

    RetirementFixtures class >> retirementRecordWith: aTupleCollection [
        "The canonical §5.5 rendering: the format tag and version first,
         the single key #retirements, the triples separated by single
         spaces, no trailing whitespace, one trailing newline — the
         §5.4 rules the two settled schemas already obey."
        <category: 'retirement records'>
        | out |
        out := WriteStream on: String new.
        out nextPutAll: '#(#''parley-retired'' 1 #retirements #('.
        aTupleCollection
            do: [:each | out nextPutAll: each]
            separatedBy: [out nextPut: Character space].
        out nextPutAll: '))'.
        ^out contents, SourceFixtures newline
    ]

    RetirementFixtures class >> retiredJson032Record [
        "The sprint's central artifact: kernel-json 0.3.2 retired, with
         the owner's reason."
        <category: 'retirement records'>
        ^self retirementRecordWith: (Array with:
            (self retirementTupleFor: 'kernel-json' version: '0.3.2'
                reason: self json032Reason))
    ]

    RetirementFixtures class >> retiredOld100Record [
        <category: 'retirement records'>
        ^self retirementRecordWith: (Array with:
            (self retirementTupleFor: 'kernel-old' version: '1.0.0'
                reason: self old100Reason))
    ]

    RetirementFixtures class >> retiredEveryJsonRecord [
        "Both kernel-json releases retired — the S6 shape. Sorted by
         name then version (§5.5), so the record is canonical even
         though nothing reads the order."
        <category: 'retirement records'>
        ^self retirementRecordWith: (Array
            with: (self retirementTupleFor: 'kernel-json' version: '0.3.1'
                reason: self json031Reason)
            with: (self retirementTupleFor: 'kernel-json' version: '0.3.2'
                reason: self json032Reason))
    ]

    RetirementFixtures class >> retiredUnknownReleaseRecord [
        "A retirement naming a release the index does not hold. An index
         owner may retire ahead of a deletion, so this is accepted
         silently — it is not a scan problem (Doc F §6)."
        <category: 'retirement records'>
        ^self retirementRecordWith: (Array with:
            (self retirementTupleFor: 'kernel-ghost' version: '9.9.9'
                reason: 'never published here'))
    ]

    "---- index directories ----"

    RetirementFixtures class >> writeJsonArchivesIn: aDirPath [
        "The two kernel-json archives, beside their entries, so an
         install can really fetch a retired release."
        <category: 'index directories'>
        SourceFixtures write: self archiveBytesJson031
            toFile: 'kernel-json-0.3.1.star' in: aDirPath.
        SourceFixtures write: self archiveBytesJson032
            toFile: 'kernel-json-0.3.2.star' in: aDirPath
    ]

    RetirementFixtures class >> populateRetiredIndexIn: aDirPath [
        "THE S1/S2 index: kernel-json 0.3.1 and 0.3.2 with their
         archives, and one retirement record retiring 0.3.2. Filenames
         follow the recommended layout; S3 is where the layout is
         deliberately subverted."
        <category: 'index directories'>
        SourceFixtures write: self entryJson031
            toFile: 'kernel-json-0.3.1.st' in: aDirPath.
        SourceFixtures write: self entryJson032
            toFile: 'kernel-json-0.3.2.st' in: aDirPath.
        SourceFixtures write: self retiredJson032Record
            toFile: 'retired.st' in: aDirPath.
        self writeJsonArchivesIn: aDirPath
    ]

    RetirementFixtures class >> populateLiveIndexIn: aDirPath [
        "The same index with NO retirement record — the control against
         which retirement's effect is measured, and the regression
         guard's input."
        <category: 'index directories'>
        SourceFixtures write: self entryJson031
            toFile: 'kernel-json-0.3.1.st' in: aDirPath.
        SourceFixtures write: self entryJson032
            toFile: 'kernel-json-0.3.2.st' in: aDirPath.
        self writeJsonArchivesIn: aDirPath
    ]

    RetirementFixtures class >> disguisedRecordFileName [
        "The filename that looks exactly like an entry: <name>-<version>
         for a release the index really holds. If the scan dispatches on
         the filename ANYWHERE, this is the fixture that catches it."
        <category: 'index directories'>
        ^'kernel-json-0.3.2.st'
    ]

    RetirementFixtures class >> populateDisguisedIndexIn: aDirPath [
        "THE S3 index: the retirement record wears an entry's name and
         the entries wear names that say nothing. Identity is contents,
         never filename (Doc C §1, Sprint 4)."
        <category: 'index directories'>
        SourceFixtures write: self entryJson031
            toFile: 'aa-first.st' in: aDirPath.
        SourceFixtures write: self entryJson032
            toFile: 'bb-second.st' in: aDirPath.
        SourceFixtures write: self retiredJson032Record
            toFile: self disguisedRecordFileName in: aDirPath.
        self writeJsonArchivesIn: aDirPath
    ]

    RetirementFixtures class >> populateTwoRecordIndexIn: aDirPath [
        "THE S4 index: two packages, two retirement records, each
         retiring a different release. Several records merge."
        <category: 'index directories'>
        SourceFixtures write: self entryJson031
            toFile: 'kernel-json-0.3.1.st' in: aDirPath.
        SourceFixtures write: self entryJson032
            toFile: 'kernel-json-0.3.2.st' in: aDirPath.
        SourceFixtures write: self entryOld100
            toFile: 'kernel-old-1.0.0.st' in: aDirPath.
        SourceFixtures write: self entryOld110
            toFile: 'kernel-old-1.1.0.st' in: aDirPath.
        SourceFixtures write: self retiredJson032Record
            toFile: 'retired-json.st' in: aDirPath.
        SourceFixtures write: self retiredOld100Record
            toFile: 'retired-old.st' in: aDirPath.
        self writeJsonArchivesIn: aDirPath
    ]

    RetirementFixtures class >> populateEveryVersionRetiredIn: aDirPath [
        "THE S6 index: every version of the required package retired. A
         value, never a crash — and never an empty-collection error."
        <category: 'index directories'>
        SourceFixtures write: self entryJson031
            toFile: 'kernel-json-0.3.1.st' in: aDirPath.
        SourceFixtures write: self entryJson032
            toFile: 'kernel-json-0.3.2.st' in: aDirPath.
        SourceFixtures write: self retiredEveryJsonRecord
            toFile: 'retired.st' in: aDirPath.
        self writeJsonArchivesIn: aDirPath
    ]

    RetirementFixtures class >> populateUnknownRetirementIndexIn: aDirPath [
        "An index retiring a release it does not hold."
        <category: 'index directories'>
        SourceFixtures write: self entryJson031
            toFile: 'kernel-json-0.3.1.st' in: aDirPath.
        SourceFixtures write: self retiredUnknownReleaseRecord
            toFile: 'retired-ghost.st' in: aDirPath.
        SourceFixtures write: self archiveBytesJson031
            toFile: 'kernel-json-0.3.1.star' in: aDirPath
    ]

    "---- the malformed-record corpus (Doc F §4.2) ----"

    RetirementFixtures class >> recordWithUnpairedBody [
        "The key with no value: the body does not pair up."
        <category: 'malformed records'>
        ^'#(#''parley-retired'' 1 #retirements)', SourceFixtures newline
    ]

    RetirementFixtures class >> recordMissingRetirements [
        "A tag-valid record whose one required key is absent."
        <category: 'malformed records'>
        ^'#(#''parley-retired'' 1 #retired #())', SourceFixtures newline
    ]

    RetirementFixtures class >> recordWithUnknownKey [
        "#retirements present, plus a key the schema does not define."
        <category: 'malformed records'>
        ^'#(#''parley-retired'' 1 #retirements #() #notes ''hello'')',
            SourceFixtures newline
    ]

    RetirementFixtures class >> recordWithShortTuple [
        "The S5 record: a TWO-element tuple where the schema fixes
         three. Shape-valid as an array of arrays of strings, and still
         not a retirement."
        <category: 'malformed records'>
        ^'#(#''parley-retired'' 1 #retirements #(#(''kernel-json'' ''0.3.2'')))',
            SourceFixtures newline
    ]

    RetirementFixtures class >> recordWithSymbolName [
        "A non-String field: in 3.2.5 Symbol is a String subclass, and
         the two are distinct literals in the micro-format grammar — the
         same distinction the settled entry validation already draws."
        <category: 'malformed records'>
        ^'#(#''parley-retired'' 1 #retirements #(#(#kerneljson ''0.3.2'' ''why'')))',
            SourceFixtures newline
    ]

    RetirementFixtures class >> recordWithNonArrayRetirements [
        <category: 'malformed records'>
        ^'#(#''parley-retired'' 1 #retirements ''kernel-json'')',
            SourceFixtures newline
    ]

    RetirementFixtures class >> recordWithUnparseableVersion [
        "Shape-perfect and meaningless: the Doc F §4.1 lesson applied to
         the third schema. The settled Version fromString: is what
         decides, consumed and never re-implemented."
        <category: 'malformed records'>
        ^'#(#''parley-retired'' 1 #retirements #(#(''kernel-json'' ''banana'' ''why'')))',
            SourceFixtures newline
    ]

    RetirementFixtures class >> unparseableRetirementVersionValue [
        <category: 'malformed records'>
        ^'banana'
    ]

    "---- pinned retirement-record problems (posted on issue #12) ----"

    RetirementFixtures class >> retirementKeyOrderText [
        "The record's schema vocabulary, rendered for a problem exactly
         as the settled entry validation renders its eight keys."
        <category: 'pinned wordings'>
        ^'the only key of a retirement record is #retirements'
    ]

    RetirementFixtures class >> recordPairingProblemFor: aBaseName [
        <category: 'pinned wordings'>
        ^aBaseName,
            ': malformed retirement record - the schema keys and values do not pair up'
    ]

    RetirementFixtures class >> missingRetirementsProblemFor: aBaseName [
        <category: 'pinned wordings'>
        ^aBaseName, ': missing schema key #retirements - ',
            self retirementKeyOrderText
    ]

    RetirementFixtures class >> unknownRecordKeyProblemFor: aBaseName key: aSymbol [
        <category: 'pinned wordings'>
        ^aBaseName, ': unknown schema key ', aSymbol printString, ' - ',
            self retirementKeyOrderText
    ]

    RetirementFixtures class >> retirementsKindProblemFor: aBaseName [
        "One wording for every structural defect of the triples — a
         non-Array #retirements, a tuple of the wrong arity, a
         non-String field. They are one question ('is this an array of
         three-String triples?') and the operator's repair is the same,
         so they are one sentence; the settled #dependencies and
         #archive problems are worded on exactly this principle."
        <category: 'pinned wordings'>
        ^aBaseName,
            ': #retirements must be an array of #(<name> <version> <reason>) string triples'
    ]

    RetirementFixtures class >> unparseableRetirementVersionProblemFor: aBaseName value: aString package: aName [
        <category: 'pinned wordings'>
        ^aBaseName, ': #retirements version ', aString printString,
            ' for ', aName printString, ' does not parse as a version'
    ]

    RetirementFixtures class >> malformedRecordRows [
        "The corpus as (contents, problem-tail builder) rows, so one law
         can walk every malformed-record kind and no kind can be
         forgotten. The second element is a one-argument block taking
         the basename, because every problem names its own file."
        <category: 'malformed records'>
        ^(Array
            with: (Array with: self recordWithUnpairedBody
                with: [:base | self recordPairingProblemFor: base])
            with: (Array with: self recordMissingRetirements
                with: [:base | self missingRetirementsProblemFor: base])
            with: (Array with: self recordWithUnknownKey
                with: [:base | self unknownRecordKeyProblemFor: base
                    key: #notes])
            with: (Array with: self recordWithNonArrayRetirements
                with: [:base | self retirementsKindProblemFor: base])),
            (Array
                with: (Array with: self recordWithShortTuple
                    with: [:base | self retirementsKindProblemFor: base])
                with: (Array with: self recordWithSymbolName
                    with: [:base | self retirementsKindProblemFor: base])
                with: (Array with: self recordWithUnparseableVersion
                    with: [:base |
                        self unparseableRetirementVersionProblemFor: base
                            value: self unparseableRetirementVersionValue
                            package: 'kernel-json']))
    ]

    RetirementFixtures class >> malformedEntryFileName [
        "The S5 malformed ENTRY, sorting before the malformed record so
         the batch's order is visible in the filenames."
        <category: 'malformed records'>
        ^'aa-entry.st'
    ]

    RetirementFixtures class >> malformedRecordFileName [
        <category: 'malformed records'>
        ^'bb-record.st'
    ]

    RetirementFixtures class >> populateMalformedMixIn: aDirPath [
        "THE S5 index: one malformed entry and one malformed retirement
         record. A retirement record is index content like any other, so
         both problems batch into the one SourceError."
        <category: 'malformed records'>
        SourceFixtures write: PublishFixtures entryMissingSummary
            toFile: self malformedEntryFileName in: aDirPath.
        SourceFixtures write: self recordWithShortTuple
            toFile: self malformedRecordFileName in: aDirPath
    ]

    RetirementFixtures class >> malformedMixProblems [
        "The two problems, in sorted-filename order: the settled Sprint 7
         entry-shape problem unchanged, and the new record problem
         batched beside it."
        <category: 'malformed records'>
        ^Array
            with: (PublishFixtures missingKeyProblemFor:
                self malformedEntryFileName key: #summary)
            with: (self retirementsKindProblemFor: self malformedRecordFileName)
    ]

    "---- the working directory, its lock oracles and pin lines ----"

    RetirementFixtures class >> jsonRootContents [
        "my-app 1.0.0 depending on kernel-json ^0.3.0 — a constraint
         that allows BOTH 0.3.1 and 0.3.2, so only retirement can decide
         which is chosen."
        <category: 'working dirs'>
        ^'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''kernel-json'' constraint: ''^0.3.0'' ]',
            SourceFixtures newline
    ]

    RetirementFixtures class >> jsonRootWorkDirNamed: aLabel [
        "A working directory whose Package.st is the kernel-json root.
         Answers the path; the caller tracks it for teardown."
        <category: 'working dirs'>
        | path |
        path := SourceFixtures directoryNamed: aLabel.
        ExecFixtures writePackage: self jsonRootContents in: path.
        ^path
    ]

    RetirementFixtures class >> jsonRootManifest [
        "The same root as a live manifest, for the value-level laws."
        <category: 'working dirs'>
        ^ResolverFixtures rootWith: (Array with:
            (Array with: 'kernel-json' with: '^0.3.0'))
    ]

    RetirementFixtures class >> lockPinning: aVersionString digest: aDigest [
        <category: 'lock oracles'>
        ^'#(#''parley-lock'' 1 #root ''my-app'' #packages #(#(''kernel-json'' ''',
            aVersionString, ''' #sha256 ''', aDigest, ''')))',
            SourceFixtures newline
    ]

    RetirementFixtures class >> lockPinningJson031String [
        "What a fresh resolution against the retirement-bearing index
         must write: the retired higher version is never selected."
        <category: 'lock oracles'>
        ^self lockPinning: '0.3.1' digest: self digestJson031
    ]

    RetirementFixtures class >> lockPinningJson032String [
        "A lock that ALREADY pins the retired release — the build that
         resolved before the retirement was published. It must keep
         installing, byte for byte unchanged."
        <category: 'lock oracles'>
        ^self lockPinning: '0.3.2' digest: self digestJson032
    ]

    RetirementFixtures class >> json031PinLines [
        <category: 'lock oracles'>
        ^Array with: 'kernel-json 0.3.1'
    ]

    RetirementFixtures class >> json032PinLines [
        <category: 'lock oracles'>
        ^Array with: 'kernel-json 0.3.2'
    ]

    "---- hand-built snapshots (Doc C §2.1) ----"

    RetirementFixtures class >> jsonReleases [
        "Private — the two kernel-json releases as settled snapshot
         release tuples, carrying the same digests the index entries
         declare, so a hand-built snapshot and a scanned one are the
         same value."
        <category: 'snapshots'>
        ^Array
            with: (ResolverFixtures release: 'kernel-json' version: '0.3.1'
                sha256: self digestJson031 dependencies: #())
            with: (ResolverFixtures release: 'kernel-json' version: '0.3.2'
                sha256: self digestJson032 dependencies: #())
    ]

    RetirementFixtures class >> retirement: aName version: aVersionString reason: aReason [
        "One snapshot retirement record. The construction protocol
         pinned for IndexSnapshot (issue #12): an Array of
           {name (String). Version. reason (String)}
         — the same shape as the settled release tuple, with the version
         already parsed, because the scan parses it to validate anyway."
        <category: 'snapshots'>
        ^Array
            with: aName
            with: (Version fromString: aVersionString)
            with: aReason
    ]

    RetirementFixtures class >> snapshotWithRetiredJson032 [
        "Both releases present; 0.3.2 retired. versionsOf: must exclude
         it while dependenciesOf:version: and sha256For:version: still
         answer for it — the two halves of the feature, in one value."
        <category: 'snapshots'>
        ^IndexSnapshot
            releases: self jsonReleases
            retirements: (Array with: (self retirement: 'kernel-json'
                version: '0.3.2' reason: self json032Reason))
    ]

    RetirementFixtures class >> snapshotWithDependentRetiredJson032 [
        "The same shape with the retired release carrying a DEPENDENCY,
         so 'dependenciesOf:version: still answers' is observable rather
         than indistinguishable from the unknown-release answer (both of
         which are the empty collection). Excluded from fresh resolution
         and still fully described: that pair is the feature."
        <category: 'snapshots'>
        ^IndexSnapshot
            releases: (Array
                with: (ResolverFixtures release: 'kernel-json'
                    version: '0.3.1' sha256: self digestJson031
                    dependencies: #())
                with: (ResolverFixtures release: 'kernel-json'
                    version: '0.3.2' sha256: self digestJson032
                    dependencies: #(#('kernel-streams' '^1.0')))
                with: (ResolverFixtures release: 'kernel-streams'
                    version: '1.2.0' sha256: 'aa12' dependencies: #()))
            retirements: (Array with: (self retirement: 'kernel-json'
                version: '0.3.2' reason: self json032Reason))
    ]

    RetirementFixtures class >> snapshotWithoutJson032 [
        "THE PURITY TWIN: 0.3.2 simply ABSENT, built through the settled
         releases: constructor. Resolving the same root against this and
         against snapshotWithRetiredJson032 must answer IDENTICAL
         Resolutions — which is what proves the resolver cannot observe
         retirement, rather than merely that it did not pick a retired
         version."
        <category: 'snapshots'>
        ^IndexSnapshot releases: (Array with: (self jsonReleases at: 1))
    ]

    RetirementFixtures class >> snapshotWithBothJsonRetired [
        "Every version of the required package retired — the candidate
         set is empty, and an empty candidate set is the settled
         #noVersions conflict, not an error."
        <category: 'snapshots'>
        ^IndexSnapshot
            releases: self jsonReleases
            retirements: (Array
                with: (self retirement: 'kernel-json' version: '0.3.1'
                    reason: self json031Reason)
                with: (self retirement: 'kernel-json' version: '0.3.2'
                    reason: self json032Reason))
    ]

    RetirementFixtures class >> snapshotWithNoRetirements [
        "The declared regression guard's input: a snapshot built through
         the settled releases: constructor behaves exactly as it did
         before Sprint 10."
        <category: 'snapshots'>
        ^IndexSnapshot releases: self jsonReleases
    ]

    "---- the fixture git repository (local paths only, never a network) ----"

    RetirementFixtures class >> buildRetiredRepoAt: aRepoPath [
        "A fixture git repository whose working tree is a retirement-
         bearing index directory, committed once. Built locally through
         the settled PublishFixtures builders — ProcessRunner,
         per-command committer identity, no network."
        <category: 'git fixtures'>
        PublishFixtures initRepoAt: aRepoPath.
        self populateRetiredIndexIn: aRepoPath.
        PublishFixtures commitAllIn: aRepoPath message: 'retired'.
        ^aRepoPath
    ]

    RetirementFixtures class >> retiredRepoNamed: aLabel [
        "Answers the repo path; the caller tracks it for teardown."
        <category: 'git fixtures'>
        ^self buildRetiredRepoAt: (SourceFixtures directoryNamed: aLabel)
    ]

    "---- store priming (a retired release installs from the cache) ----"

    RetirementFixtures class >> primeJson032Store: aStoreRoot [
        "Put the retired release's archive in the content store, so the
         install fast path is a cache hit and no fetch is needed."
        <category: 'store'>
        | store |
        store := ContentStore on: aStoreRoot.
        store store: self archiveBytesJson032.
        ^store
    ]

    RetirementFixtures class >> primeJson032StoreIn: aWorkDir [
        "The same, at the store the CommandLine wiring derives from a
         working directory. The settled ContentStore creates its root
         lazily and one level only, so the .parley/ directory above it
         is created here — the same directory the wiring would create on
         a real run."
        <category: 'store'>
        | parleyDir |
        parleyDir := CommandLineFixtures parleyDirIn: aWorkDir.
        (File name: parleyDir) exists ifFalse: [Directory create: parleyDir].
        ^self primeJson032Store: (CommandLineFixtures storeRootIn: aWorkDir)
    ]
]

Namespace current: Smalltalk.
