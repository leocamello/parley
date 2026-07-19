"Parley Sprint 4 — DirectorySource laws (amended Doc C §1/§1.1/§7;
 issue #6): snapshot correctness over a real directory, every
 SourceError problem shape and the batching/sorted-order law, the
 sealed-snapshot law, contents-not-filename identity, writer-authored
 entries, the PackageSource protocol surface, and the fetch stub.

 Protocol decisions pinned here (posted on issue #6 for confirmation):
   - constructor: DirectorySource on: <path String>; the path is held
     immutably; the public surface is exactly the Doc C §1 protocol
     (snapshot, versionsOf:, manifestFor:version:, fetch:version:);
   - versionsOf: answers the snapshot convention — a collection of
     Versions, empty when the package is unknown;
   - manifestFor:version: answers nil for an unknown (package, version);
   - only .st files are scanned; other directory entries are ignored;
   - problem strings (sorted-filename order, one per kind):
       reader-rejected file: '<basename>: <reader messageText>'
       wrong tag:            '<basename>: wrong artifact tag <tag
                             printString> - a source directory holds
                             only #''parley-index'' 1 entries'
       duplicate:            '<basename>: duplicate entry for ''<name>''
                             <version> (already declared in <first
                             basename>)'
       missing directory:    '<path>: missing or unreadable directory'
   - SourceError messageText: 'Source directory has <n> problem(s): '
     with the problems joined by '; ' (the ManifestError house style);
   - fetch stub message: 'fetch:version: is install-time only - the
     Installer does not exist yet' (superseded at Sprint 5 staging,
     issue #7: fetch:version: became real per Doc D §1.1; the stub law
     was removed by the operator)."

Namespace current: Parley.

TestCase subclass: DirectorySourceTest [
    | fixtureDirs |

    <comment: 'Laws for DirectorySource and SourceError per amended
Doc C §1.1/§7. Fixture directories live under tmp/ and are removed in
tearDown.'>

    setUp [
        fixtureDirs := OrderedCollection new
    ]

    tearDown [
        fixtureDirs isNil ifTrue: [^self].
        fixtureDirs do: [:each | SourceFixtures removeTree: each].
        fixtureDirs := nil
    ]

    freshDir: aLabel [
        | path |
        path := SourceFixtures directoryNamed: aLabel.
        fixtureDirs add: path.
        ^path
    ]

    diamondDir: aLabel [
        | path |
        path := self freshDir: aLabel.
        SourceFixtures populateDiamondIn: path.
        ^path
    ]

    version: aString [
        ^Version fromString: aString
    ]

    constraint: aString [
        ^VersionConstraint fromString: aString
    ]

    assertVersions: aCollection are: versionStrings [
        | sorted expected |
        sorted := (aCollection asSortedCollection: [:a :b | a < b]) asArray.
        expected := versionStrings collect: [:each | self version: each].
        self assert: sorted = expected
    ]

    problemsFrom: aBlock [
        "The problems array of the SourceError aBlock signals; fails
         when no error, or a non-SourceError, is signaled."
        [aBlock value.
         self assert: false description: 'expected a SourceError']
            on: Error
            do: [:e |
                self assert: (e isKindOf: SourceError)
                    description: 'expected a SourceError'.
                ^e problems].
        ^#()
    ]

    readerRejectionTail [
        "The fixed suffix of every IndexEntryParseError message."
        ^' - the micro-format accepts only literal arrays, strings, symbols and non-negative integers'
    ]

    malformedProblemFor: aBaseName [
        ^aBaseName,
            ': Parse error at position 1: artifact must open with a literal array',
            self readerRejectionTail
    ]

    wrongTagProblemFor: aBaseName [
        ^aBaseName,
            ': wrong artifact tag #''parley-lock'' - a source directory holds only #''parley-index'' 1 entries'
    ]

    duplicateC24ProblemFor: aBaseName [
        ^aBaseName,
            ': duplicate entry for ''c'' 2.4.0 (already declared in c-2.4.0.st)'
    ]

    missingDirectoryProblemFor: aPath [
        ^aPath, ': missing or unreadable directory'
    ]

    "---- snapshot correctness (Doc C §7: versions, parsed constraints, hashes) ----"

    testSnapshotAnswersVersionsParsedConstraintsAndHashes [
        | snap deps |
        snap := (DirectorySource on: (self diamondDir: 'law-correctness'))
            snapshot.
        self assert: (snap isKindOf: IndexSnapshot).
        self assertVersions: (snap versionsOf: 'a') are: #('1.0.0').
        self assertVersions: (snap versionsOf: 'b') are: #('1.0.0').
        self assertVersions: (snap versionsOf: 'c')
            are: #('1.5.0' '2.4.0' '3.0.0').
        deps := snap dependenciesOf: 'a' version: (self version: '1.0.0').
        self assert: deps size = 1.
        self assert: (deps at: 1) name = 'c'.
        self assert: (deps at: 1) constraint
            = (self constraint: '>=1.0.0 <3.0.0').
        deps := snap dependenciesOf: 'b' version: (self version: '1.0.0').
        self assert: deps size = 1.
        self assert: (deps at: 1) constraint
            = (self constraint: '>=2.0.0 <3.0.0').
        self assert: (snap dependenciesOf: 'c' version: (self version: '2.4.0'))
            isEmpty.
        self assert: (snap sha256For: 'a' version: (self version: '1.0.0'))
            = 'ab12'.
        self assert: (snap sha256For: 'b' version: (self version: '1.0.0'))
            = 'cd34'.
        self assert: (snap sha256For: 'c' version: (self version: '2.4.0'))
            = 'ef56'
    ]

    "---- every SourceError problem shape ----"

    testUnparseableFileProblemCarriesThePositionedReaderReason [
        | dir problems |
        dir := self diamondDir: 'law-unparseable'.
        SourceFixtures write: SourceFixtures malformedContents
            toFile: 'zz-bad.st' in: dir.
        problems := self problemsFrom: [(DirectorySource on: dir) snapshot].
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = (self malformedProblemFor: 'zz-bad.st')
    ]

    testWrongTagFileProblemNamesTheFileAndTheTag [
        | dir problems |
        dir := self diamondDir: 'law-wrongtag'.
        SourceFixtures write: SourceFixtures lockArtifactContents
            toFile: 'zz-lock.st' in: dir.
        problems := self problemsFrom: [(DirectorySource on: dir) snapshot].
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = (self wrongTagProblemFor: 'zz-lock.st')
    ]

    testUnsupportedFormatVersionProblemCarriesTheReaderReason [
        | dir problems |
        dir := self diamondDir: 'law-badversion'.
        SourceFixtures write: SourceFixtures unsupportedVersionContents
            toFile: 'zz-v2.st' in: dir.
        problems := self problemsFrom: [(DirectorySource on: dir) snapshot].
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = ('zz-v2.st: unsupported #''parley-index'' format version 2: this Parley reads format version 1')
    ]

    testDuplicateNameVersionProblemNamesBothFiles [
        | dir problems |
        dir := self diamondDir: 'law-duplicate'.
        SourceFixtures write: SourceFixtures duplicateC24Contents
            toFile: 'zz-dup.st' in: dir.
        problems := self problemsFrom: [(DirectorySource on: dir) snapshot].
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = (self duplicateC24ProblemFor: 'zz-dup.st')
    ]

    testMissingDirectoryProblemNamesThePath [
        | path problems |
        path := SourceFixtures missingPathNamed: 'law-nowhere'.
        problems := self problemsFrom: [(DirectorySource on: path) snapshot].
        self assert: problems size = 1.
        self assert: (problems at: 1)
            = (self missingDirectoryProblemFor: path)
    ]

    "---- the batching law: one error, all problems, sorted-filename order ----"

    testProblemsBatchIntoOneErrorInSortedFilenameOrder [
        | dir problems |
        dir := self diamondDir: 'law-batching'.
        SourceFixtures write: SourceFixtures malformedContents
            toFile: 'aa-bad.st' in: dir.
        SourceFixtures write: SourceFixtures lockArtifactContents
            toFile: 'mm-lock.st' in: dir.
        SourceFixtures write: SourceFixtures duplicateC24Contents
            toFile: 'zz-dup.st' in: dir.
        problems := self problemsFrom: [(DirectorySource on: dir) snapshot].
        self assert: problems size = 3.
        self assert: (problems at: 1)
            = (self malformedProblemFor: 'aa-bad.st').
        self assert: (problems at: 2)
            = (self wrongTagProblemFor: 'mm-lock.st').
        self assert: (problems at: 3)
            = (self duplicateC24ProblemFor: 'zz-dup.st')
    ]

    testSourceErrorMessageTextCarriesEveryProblem [
        | dir |
        dir := self diamondDir: 'law-message'.
        SourceFixtures write: SourceFixtures malformedContents
            toFile: 'aa-bad.st' in: dir.
        SourceFixtures write: SourceFixtures duplicateC24Contents
            toFile: 'zz-dup.st' in: dir.
        [(DirectorySource on: dir) snapshot.
         self assert: false description: 'expected a SourceError']
            on: Error
            do: [:e |
                self assert: (e isKindOf: SourceError).
                self assert: e messageText
                    = ('Source directory has 2 problem(s): ',
                        (self malformedProblemFor: 'aa-bad.st'), '; ',
                        (self duplicateC24ProblemFor: 'zz-dup.st'))]
    ]

    testNoPartialSnapshotWhenTheScanFails [
        | dir snap signaled |
        dir := self diamondDir: 'law-nopartial'.
        SourceFixtures write: SourceFixtures malformedContents
            toFile: 'zz-bad.st' in: dir.
        snap := nil.
        signaled := nil.
        [snap := (DirectorySource on: dir) snapshot]
            on: Error do: [:e | signaled := e].
        self deny: signaled isNil
            description: 'expected a SourceError'.
        self assert: (signaled isKindOf: SourceError)
            description: 'expected a SourceError'.
        self assert: signaled problems size = 1.
        self assert: snap isNil
    ]

    "---- the sealed-snapshot law (the one-I/O-moment contract) ----"

    testSnapshotIsASealedValue [
        | dir sealed control |
        dir := self diamondDir: 'law-sealed'.
        sealed := (DirectorySource on: dir) snapshot.
        SourceFixtures write: SourceFixtures lateEntryDContents
            toFile: 'zz-late.st' in: dir.
        control := (DirectorySource on: dir) snapshot.
        self assertVersions: (control versionsOf: 'd') are: #('1.0.0').
        self assert: (sealed versionsOf: 'd') isEmpty.
        self assertVersions: (sealed versionsOf: 'c')
            are: #('1.5.0' '2.4.0' '3.0.0')
    ]

    "---- identity from contents, not filenames ----"

    testIdentityComesFromEntryContentsNotFilenames [
        | dir snap |
        dir := self freshDir: 'law-contents'.
        SourceFixtures populateDiamondIn: dir with24As: 'zz-anything.st'.
        snap := (DirectorySource on: dir) snapshot.
        self assertVersions: (snap versionsOf: 'c')
            are: #('1.5.0' '2.4.0' '3.0.0').
        self assert: (snap sha256For: 'c' version: (self version: '2.4.0'))
            = 'ef56'
    ]

    "---- writer-authored entries converge with hand-built values ----"

    testWriterAuthoredEntriesConvergeWithHandBuiltValues [
        | dir manifest snap deps |
        dir := self diamondDir: 'law-writer'.
        manifest := Parley define: [:pkg |
            pkg name: 'd'; version: '1.0.0'; fileIns: #('D.st');
                dependency: 'c' constraint: '^2.0'].
        SourceFixtures writeManifest: manifest as: 'd-1.0.0.st' in: dir.
        snap := (DirectorySource on: dir) snapshot.
        self assertVersions: (snap versionsOf: 'd') are: #('1.0.0').
        self assert: (snap sha256For: 'd' version: (self version: '1.0.0'))
            = ''.
        deps := snap dependenciesOf: 'd' version: (self version: '1.0.0').
        self assert: deps size = 1.
        self assert: (deps at: 1) name = 'c'.
        self assert: (deps at: 1) constraint = (self constraint: '^2.0')
    ]

    "---- the PackageSource protocol surface ----"

    testVersionsOfSpeaksTheSnapshotConvention [
        | dir source |
        dir := self diamondDir: 'law-versionsof'.
        source := DirectorySource on: dir.
        self assertVersions: (source versionsOf: 'c')
            are: #('1.5.0' '2.4.0' '3.0.0').
        self assertVersions: (source versionsOf: 'a') are: #('1.0.0').
        self assert: (source versionsOf: 'unknown') isEmpty
    ]

    testManifestForConvergesWithFromIndexEntry [
        | dir found direct |
        dir := self diamondDir: 'law-manifestfor'.
        found := (DirectorySource on: dir)
            manifestFor: 'a' version: (self version: '1.0.0').
        direct := LibraryManifest fromIndexEntry:
            (IndexEntryReader readFrom:
                (ReadStream on: SourceFixtures diamondEntryA)).
        self assert: (found isKindOf: LibraryManifest).
        self assert: found name = direct name.
        self assert: found version = direct version.
        self assert: found summary = direct summary.
        self assert: found author = direct author.
        self assert: found license = direct license.
        self assert: found fileIns = direct fileIns.
        self assert: found dependencies size = direct dependencies size.
        1 to: found dependencies size do: [:i |
            self assert: (found dependencies at: i) name
                = ((direct dependencies at: i) name).
            self assert: (found dependencies at: i) constraint
                = ((direct dependencies at: i) constraint)]
    ]

    testManifestForUnknownPackageOrVersionAnswersNil [
        | source |
        source := DirectorySource on: (self diamondDir: 'law-unknown').
        self assert: (source manifestFor: 'unknown'
            version: (self version: '1.0.0')) isNil.
        self assert: (source manifestFor: 'c'
            version: (self version: '9.9.9')) isNil
    ]

    "---- empty directories and non-entry files ----"

    testEmptyDirectoryAnswersAnEmptySnapshot [
        | snap |
        snap := (DirectorySource on: (self freshDir: 'law-empty')) snapshot.
        self assert: (snap isKindOf: IndexSnapshot).
        self assert: (snap versionsOf: 'a') isEmpty
    ]

    testNonStFilesAreIgnoredByTheScan [
        | dir snap |
        dir := self diamondDir: 'law-nonst'.
        SourceFixtures write: 'this is not an artifact at all'
            toFile: 'NOTES.txt' in: dir.
        snap := (DirectorySource on: dir) snapshot.
        self assertVersions: (snap versionsOf: 'c')
            are: #('1.5.0' '2.4.0' '3.0.0')
    ]
]

Namespace current: Smalltalk.
