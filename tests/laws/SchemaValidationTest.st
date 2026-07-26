"Parley Sprint 7 — §5.2 schema-shape validation in the DirectorySource
 scan (issue #9 S1-S3; Doc F §4, closing the Sprint 4 ruled gap).

 The Sprint 4 ruling: a literal-valid, tag-valid entry missing §5.2
 schema keys failed the scan with a RAW error — fail-stop, never
 fail-wrong — until validation landed here. It lands in the SCAN (the
 declared settled-class exception on DirectorySource); the reader stays
 a pure literals-only parser and is not touched.

 Protocol decisions pinned here (posted on issue #9 for confirmation):
   - the shape contract is Doc F §4 exactly: the eight keys
     #name #version #summary #author #license #fileIns #dependencies
     #archive, all present, in that fixed order, each with its schema
     kind — strings for the five scalar fields; #fileIns an array of
     strings; #dependencies an array of #(name constraint) string
     pairs; #archive either #() or #(<filename> #sha256 <hex>);
   - ONE problem per offending file (the settled scan style: the file
     contributes no entry and the scan continues), batched with every
     other scan problem into the ONE SourceError in sorted-filename
     order — Sprint 4 semantics, unchanged;
   - the pinned wordings live in PublishFixtures: schemaPairingProblem,
     missingKeyProblem, unknownKeyProblem, keyOrderProblem,
     scalarKindProblem, fileInsKindProblem, dependenciesKindProblem,
     archiveKindProblem;
   - validation runs AFTER the settled parse/tag checks and BEFORE
     duplicate detection (which needs a name and a version to compare),
     so the settled parse/tag/duplicate problem shapes are unchanged;
   - shape only: whether a #version string PARSES as a Version, and
     whether a dependency constraint parses, are value questions, not
     schema-shape questions — Doc F §4 scopes this to shape and they
     stay outside it.

 Every fixture directory lives under tmp/, is unique per test and is
 removed in tearDown. No process is spawned by this suite."

Namespace current: Parley.

TestCase subclass: SchemaValidationTest [
    | fixtureDirs |

    <comment: 'Laws for the §5.2 schema-shape validation folded into
the DirectorySource scan: one pinned problem per violation kind,
batching in sorted-filename order alongside the settled problem shapes,
and a schema-clean directory still scanning.'>

    setUp [
        fixtureDirs := OrderedCollection new
    ]

    tearDown [
        fixtureDirs isNil ifTrue: [^self].
        fixtureDirs do: [:each | ExecFixtures removeTree: each].
        fixtureDirs := nil
    ]

    freshDir: aLabel [
        | path |
        path := SourceFixtures directoryNamed: aLabel.
        fixtureDirs add: path.
        ^path
    ]

    version: aString [
        ^Version fromString: aString
    ]

    problemsFrom: aBlock [
        "The problems array of the SourceError aBlock signals; fails
         when no error, or a non-SourceError, is signaled."
        [aBlock value.
         self assert: false description: 'expected a SourceError']
            on: Error
            do: [:e |
                self assert: (e isKindOf: SourceError)
                    description: 'expected a SourceError, got ', e class name.
                ^e problems].
        ^#()
    ]

    dirWith: aContentsString as: aBaseName label: aLabel [
        "A directory holding exactly one offending entry file."
        | path |
        path := self freshDir: aLabel.
        SourceFixtures write: aContentsString toFile: aBaseName in: path.
        ^path
    ]

    assertOneProblem: aProblemString from: aContentsString as: aBaseName label: aLabel [
        | problems |
        problems := self problemsFrom: [
            (DirectorySource on:
                (self dirWith: aContentsString as: aBaseName label: aLabel))
                    snapshot].
        self assert: problems size = 1.
        self assert: (problems at: 1) = aProblemString
    ]

    "---- one pinned problem per violation kind ----"

    testUnpairedSchemaBodyIsOneProblem [
        self assertOneProblem:
            (PublishFixtures schemaPairingProblemFor: 'bad.st')
            from: PublishFixtures entryWithUnpairedBody
            as: 'bad.st'
            label: 'schema-pairing'
    ]

    testMissingSchemaKeyNamesTheKey [
        self assertOneProblem:
            (PublishFixtures missingKeyProblemFor: 'bad.st' key: #summary)
            from: PublishFixtures entryMissingSummary
            as: 'bad.st'
            label: 'schema-missing'
    ]

    testUnknownSchemaKeyNamesTheKey [
        self assertOneProblem:
            (PublishFixtures unknownKeyProblemFor: 'bad.st' key: #yanked)
            from: PublishFixtures entryWithUnknownKey
            as: 'bad.st'
            label: 'schema-unknown'
    ]

    testKeysOutOfOrderIsOneProblem [
        self assertOneProblem:
            (PublishFixtures keyOrderProblemFor: 'bad.st')
            from: PublishFixtures entryWithKeysOutOfOrder
            as: 'bad.st'
            label: 'schema-order'
    ]

    testScalarFieldKindsAreEnforced [
        self assertOneProblem:
            (PublishFixtures scalarKindProblemFor: 'bad.st' key: #name)
            from: PublishFixtures entryWithSymbolName
            as: 'bad.st'
            label: 'schema-name-kind'.
        self assertOneProblem:
            (PublishFixtures scalarKindProblemFor: 'bad.st' key: #version)
            from: PublishFixtures entryWithIntegerVersion
            as: 'bad.st'
            label: 'schema-version-kind'
    ]

    testFileInsMustBeAnArrayOfStrings [
        self assertOneProblem:
            (PublishFixtures fileInsKindProblemFor: 'bad.st')
            from: PublishFixtures entryWithBadFileIns
            as: 'bad.st'
            label: 'schema-fileins'
    ]

    testDependenciesMustBeStringPairs [
        self assertOneProblem:
            (PublishFixtures dependenciesKindProblemFor: 'bad.st')
            from: PublishFixtures entryWithBadDependencies
            as: 'bad.st'
            label: 'schema-deps'
    ]

    testArchiveMustBeEmptyOrASha256Triple [
        self assertOneProblem:
            (PublishFixtures archiveKindProblemFor: 'bad.st')
            from: PublishFixtures entryWithMalformedArchive
            as: 'bad.st'
            label: 'schema-archive'.
        self assertOneProblem:
            (PublishFixtures archiveKindProblemFor: 'bad.st')
            from: PublishFixtures entryWithArchiveWrongMarker
            as: 'bad.st'
            label: 'schema-archive-marker'
    ]

    "---- one problem per file: a shape violation stops at the file ----"

    testAShapeViolationYieldsExactlyOneProblemForItsFile [
        "The entry below violates the shape twice over (a missing key
         AND a malformed archive); the file still contributes exactly
         one problem, as every other scan problem kind does."
        | dir problems contents |
        dir := self freshDir: 'schema-one-per-file'.
        contents := '#(#''parley-index'' 1 #name ''p'' #version ''1.0.0'' #author '''' #license '''' #fileIns #(''P.st'') #dependencies #() #archive #(''p.star''))',
            SourceFixtures newline.
        SourceFixtures write: contents toFile: 'bad.st' in: dir.
        problems := self problemsFrom: [(DirectorySource on: dir) snapshot].
        self assert: problems size = 1
    ]

    "---- batching, sorted-filename order, alongside the settled shapes ----"

    testShapeProblemsBatchWithTheSettledProblemsInSortedOrder [
        "The settled parse, wrong-tag and duplicate shapes are
         unchanged and the new shape problems batch among them, in one
         SourceError, in sorted-filename order."
        | dir problems |
        dir := self freshDir: 'schema-batching'.
        SourceFixtures populateDiamondIn: dir.
        SourceFixtures write: SourceFixtures malformedContents
            toFile: 'ma-unparseable.st' in: dir.
        SourceFixtures write: PublishFixtures entryMissingSummary
            toFile: 'mb-missing-key.st' in: dir.
        SourceFixtures write: SourceFixtures lockArtifactContents
            toFile: 'mc-wrongtag.st' in: dir.
        SourceFixtures write: PublishFixtures entryWithMalformedArchive
            toFile: 'md-archive.st' in: dir.
        SourceFixtures write: SourceFixtures duplicateC24Contents
            toFile: 'me-dup.st' in: dir.
        problems := self problemsFrom: [(DirectorySource on: dir) snapshot].
        self assert: problems size = 5.
        self assert: (problems at: 1)
            = ('ma-unparseable.st: Parse error at position 1: artifact must open with a literal array - the micro-format accepts only literal arrays, strings, symbols and non-negative integers').
        self assert: (problems at: 2)
            = (PublishFixtures missingKeyProblemFor: 'mb-missing-key.st'
                key: #summary).
        self assert: (problems at: 3)
            = ('mc-wrongtag.st: wrong artifact tag #''parley-lock'' - a source directory holds #''parley-index'' 1 entries and #''parley-retired'' 1 records').
        self assert: (problems at: 4)
            = (PublishFixtures archiveKindProblemFor: 'md-archive.st').
        self assert: (problems at: 5)
            = 'me-dup.st: duplicate entry for ''c'' 2.4.0 (already declared in c-2.4.0.st)'
    ]

    testACleanDirectoryStillScansWhileAnotherDiagnoses [
        "Directory sources stop being operator-curated without becoming
         suspicious of clean ones: the schema-clean directory answers a
         working snapshot in the same law that diagnoses the malformed."
        | bad clean problems snap |
        bad := self freshDir: 'schema-clean-bad'.
        SourceFixtures write: PublishFixtures entryMissingSummary
            toFile: 'bad.st' in: bad.
        problems := self problemsFrom: [(DirectorySource on: bad) snapshot].
        self assert: problems size = 1.
        clean := self freshDir: 'schema-clean-good'.
        SourceFixtures populateDiamondIn: clean.
        SourceFixtures write: PublishFixtures validEntryP
            toFile: 'p-1.0.0.st' in: clean.
        snap := (DirectorySource on: clean) snapshot.
        self assert: (snap versionsOf: 'c') size = 3.
        self assert: (snap versionsOf: 'p') size = 1.
        self assert: ((snap versionsOf: 'p') at: 1) = (self version: '1.0.0').
        self assert: (snap sha256For: 'p' version: (self version: '1.0.0'))
            = ''
    ]

    testSourceErrorMessageTextCarriesEveryShapeProblem [
        | dir expected |
        dir := self freshDir: 'schema-message'.
        SourceFixtures write: PublishFixtures entryMissingSummary
            toFile: 'aa.st' in: dir.
        SourceFixtures write: PublishFixtures entryWithMalformedArchive
            toFile: 'zz.st' in: dir.
        expected := 'Source directory has 2 problem(s): ',
            (PublishFixtures missingKeyProblemFor: 'aa.st' key: #summary),
            '; ', (PublishFixtures archiveKindProblemFor: 'zz.st').
        [(DirectorySource on: dir) snapshot.
         self assert: false description: 'expected a SourceError']
            on: Error
            do: [:e |
                self assert: (e isKindOf: SourceError).
                self assert: e messageText = expected]
    ]

    "---- a shape violation is a diagnosis, not a crash ----"

    testAMalformedEntryNeverEscapesAsARawError [
        | dir raised |
        dir := self freshDir: 'schema-nocrash'.
        SourceFixtures write: PublishFixtures entryWithUnpairedBody
            toFile: 'bad.st' in: dir.
        raised := nil.
        [(DirectorySource on: dir) snapshot]
            on: Error do: [:e | raised := e].
        self deny: raised isNil description: 'expected a SourceError'.
        self assert: (raised isKindOf: SourceError)
            description: 'a malformed entry must be a diagnosis, not a crash'
    ]
]

Namespace current: Smalltalk.
