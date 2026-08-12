"Parley Sprint 13 - fixtures for parley add and the manifest editor
 (issue #15; Doc B §2.1, Doc E §4.1/§5, Doc C §2.2, §8 decision 49).

 This is the sprint's one new support file. It carries the authored
 Package.st variants the recognizer meets, the byte-exact expected
 texts after one insertion, the index/lock fixtures for S9-S11, the
 deleted-held-pin fixture S13 shares with update <pkg>, and every
 pinned Sprint 13 wording. The settled SourceFixtures / ExecFixtures /
 InstallFixtures / SelectiveUpdateFixtures / InspectionFixtures /
 CommandLineFixtures / ResolverFixtures helpers are reused UNCHANGED -
 the tools index, the held-conflict index, their archives and their
 operator-verifiable digests are all Sprint 12 values, consumed as they
 stand.

 WHY THE EXPECTED TEXTS ARE AUTHORED LITERALS, not computed. An oracle
 produced by the same splice the implementation performs cannot fail
 when the splice is wrong; it would only re-state the implementation.
 Every expected text below was written out by hand, character for
 character, from the original beside it. The laws then compare BYTES -
 never `the text got longer`, never `the file still parses`, never
 `the manifest has three dependencies`, each of which passes happily on
 an editor that silently reflowed the file.

 THE THREE ORIGINALS ARE DELIBERATELY DIFFERENT SHAPES.
   - initTemplateContents is the settled parley init skeleton,
     delegated to ExecFixtures so the template has ONE definition. Its
     cascade ends `fileIns: #(...) ]` and it declares nothing, so it is
     the first-dependency insertion point (S1). It also carries the
     sprint's best trap for free: its HEADER COMMENT spells both the
     token `Parley` and a full `dependency: 'name' constraint:
     '^1.0.0'` clause, so a recognizer that scans text without skipping
     comments will miscount the define sends and invent a declaration
     that is not there.
   - withDependenciesContents already ends with a dependency clause, so
     the new clause lands after it and declaration order is observable
     (S2). It doubles as the S9/S11 root - one root, two jobs.
   - authoredContents is the scenario decision 49 exists for (S3): a
     header comment, an interior comment above a clause, a blank line
     inside the cascade, and six-space indentation instead of eight. A
     ManifestBuilder round-trip passes S1, S2 and S4 and destroys every
     one of them.

 THE REFUSAL FIXTURES. noDefineContents is the settled ExecFixtures
 define-less file, reused; twoDefinesContents holds two complete
 cascades. Both must reach the SHAPE refusal rather than any other
 diagnosis, which is why the verb recognizes before it loads: a
 define-less file would otherwise answer the settled no-manifest line,
 which is true and unhelpful when the operator asked to add something.

 THE DELETED HELD PIN (S13, the Sprint 12 carried gap). The deleted-pin
 index publishes tool-a 1.0.0/1.1.0 and app-y 1.1.0 - never app-y
 1.0.0, which the lock pins. That is the state an index owner leaves
 behind by deleting an old entry, and §8 decision 47 makes holding it
 offer nothing rather than write a lock tuple with an empty digest. The
 lock also pins tool-a 1.0.0 so that `update tool-a` gets past the
 is-it-pinned check and reaches the same held-pin computation the add
 half reaches; the root declares app-y alone, because add tool-a
 requires tool-a to be undeclared. A lock pinning a package the root
 does not declare is the settled Sprint 12 S4 shape.

 Filesystem discipline (as Sprints 4-12): every fixture path lives
 under tmp/, unique per test via a label, removed recursively in
 tearDown through ExecFixtures removeTree:; tmp/ is empty or absent
 after a clean run. The developer image is never mutated, nothing here
 spawns, and no network is contacted.

 Digest discipline (Doc E §5). Every true digest is a settled Sprint 12
 literal, consumed unchanged. The one new digest - app-y 1.0.0 in the
 deleted-pin lock - is a shape-valid padded mnemonic on the settled
 SourceFixtures rule: it names a release no archive exists for, so
 nothing ever verifies it, and it must stay shape-valid or the Sprint
 11 lock boundary would answer instead of this sprint.

 Pinned wording decisions (posted on issue #15 for the RED review) live
 in the methods:
   - unrecognizedLineFor:constraint:in: - the shape refusal, which must
     name the file AND the exact text to paste;
   - alreadyDeclaredRefusalFor:constraint: - the different-constraint
     refusal, naming the constraint already in the file;
   - alreadyDeclaredSuccessFor:constraint: - the idempotent success;
   - deletedHeldPinLineFor:version: - the shared diagnosis S13 proves
     on BOTH add and update <pkg>;
   - editVerificationLineFor: - the reload-disagrees refusal;
   - heldPinsLine and missingManifestProblemFor: DELEGATE to the
     settled SelectiveUpdateFixtures and CommandLineFixtures wordings:
     add answers the operator's same questions in one voice, and each
     sentence keeps a single definition;
   - usageVerbsLine / addUsageLines - the usage block once the verbs:
     line names add <pkg> <constraint>. ExecFixtures usageLines,
     SelectiveUpdateFixtures usageVerbsLine and InspectionFixtures
     usageVerbsLine are re-pinned to match in GREEN, together with the
     CLI change - re-pinning them in RED would fail every settled usage
     law against a CLI that has not moved yet (the Sprint 11/12
     precedent)."

Namespace current: Parley.

Object subclass: ManifestEditFixtures [

    <comment: 'Class-side factory for Sprint 13 fixtures: the authored
Package.st variants and their byte-exact edited counterparts, the
refusal shapes, the roots/locks/indexes for the add pipeline, the
deleted-held-pin fixture shared with update <pkg>, line-splitting
helpers for the comment-by-comment assertions, and every pinned Sprint
13 wording. Stateless; uniqueness comes from per-test labels.'>

    "---- the package under addition, and its constraint ----"

    ManifestEditFixtures class >> addedName [
        "The package every scenario adds."
        <category: 'the addition'>
        ^'tool-a'
    ]

    ManifestEditFixtures class >> addedConstraint [
        "The constraint every scenario adds it under."
        <category: 'the addition'>
        ^'^1.0'
    ]

    ManifestEditFixtures class >> addedClauseText [
        "The exact clause one insertion must produce - the same text the
         shape refusal tells the operator to paste."
        <category: 'the addition'>
        ^'dependency: ''', self addedName, ''' constraint: ''',
            self addedConstraint, ''''
    ]

    "---- original 1: the settled parley init template (S1) ----"

    ManifestEditFixtures class >> initTemplateContents [
        "The byte-exact skeleton parley init writes, DELEGATED to the
         settled ExecFixtures so the template keeps one definition. Its
         cascade ends with fileIns: and it declares no dependency, so
         this is the first-dependency insertion point."
        <category: 'originals'>
        ^ExecFixtures initTemplateContents
    ]

    ManifestEditFixtures class >> initTemplateEdited [
        "The init template after one tool-a insertion, written out by
         hand from the original: the fileIns: clause gains its
         semicolon, the new clause follows at the same eight-space
         indent, and the closing bracket, the trailing newline and every
         byte of the header comment are untouched."
        <category: 'edited texts'>
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
        fileIns: #(''MyPackage.st'');
        dependency: ''tool-a'' constraint: ''^1.0'' ]',
            SourceFixtures newline
    ]

    "---- original 2: a cascade that already declares a dependency (S2) ----"

    ManifestEditFixtures class >> withDependenciesContents [
        "my-app 1.0.0 declaring tool-b ^2.0 as the LAST clause of the
         cascade. Also the S9/S11 root: tool-b is pinned, tool-a is what
         gets added, and the tools index publishes a newer tool-b that
         holding must keep out of the lock."
        <category: 'originals'>
        ^'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''tool-b'' constraint: ''^2.0'' ]',
            SourceFixtures newline
    ]

    ManifestEditFixtures class >> withDependenciesEdited [
        "The same file after one tool-a insertion, written out by hand:
         the new clause FOLLOWS the existing tool-b clause, which is
         byte-identical apart from the semicolon it gained. Doc B §6
         says dependency order is not semantic; stability is still a
         property of the file, and an editor that sorted them would be
         re-rendering."
        <category: 'edited texts'>
        ^'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''tool-b'' constraint: ''^2.0'';
        dependency: ''tool-a'' constraint: ''^1.0'' ]',
            SourceFixtures newline
    ]

    "---- original 3: the author's own file (S3) ----"

    ManifestEditFixtures class >> authoredContents [
        "The scenario decision 49 exists for: a header comment, an
         interior comment above a clause, a blank line inside the
         cascade, and six-space indentation instead of the template's
         eight. Every one of these is invisible to the manifest, so a
         round-trip through ManifestBuilder answers an equal manifest
         and destroys the file."
        <category: 'originals'>
        ^'"my-app - the application manifest.
 The pins below are deliberate; read docs/DEPS.md before changing them."
Parley define: [:pkg |
  pkg
      name: ''my-app'';
      version: ''1.0.0'';

      "tool-b stays on 2.x: 3.0 dropped the streaming reader we use"
      dependency: ''tool-b'' constraint: ''^2.0'';
      fileIns: #(''App.st'') ]',
            SourceFixtures newline
    ]

    ManifestEditFixtures class >> authoredEdited [
        "The authored file after one tool-a insertion, written out by
         hand: both comments, the blank line and the six-space indent
         survive byte for byte, and the new clause adopts the author's
         indentation rather than imposing the template's."
        <category: 'edited texts'>
        ^'"my-app - the application manifest.
 The pins below are deliberate; read docs/DEPS.md before changing them."
Parley define: [:pkg |
  pkg
      name: ''my-app'';
      version: ''1.0.0'';

      "tool-b stays on 2.x: 3.0 dropped the streaming reader we use"
      dependency: ''tool-b'' constraint: ''^2.0'';
      fileIns: #(''App.st'');
      dependency: ''tool-a'' constraint: ''^1.0'' ]',
            SourceFixtures newline
    ]

    ManifestEditFixtures class >> authoredHeaderCommentLine [
        "The first line of the authored file's header comment, asserted
         to survive on its own rather than inside a whole-text compare."
        <category: 'originals'>
        ^'"my-app - the application manifest.'
    ]

    ManifestEditFixtures class >> authoredInteriorCommentLine [
        "The interior comment line, with the author's indentation."
        <category: 'originals'>
        ^'      "tool-b stays on 2.x: 3.0 dropped the streaming reader we use"'
    ]

    "---- the shapes the recognizer refuses ----"

    ManifestEditFixtures class >> noDefineContents [
        "Valid Smalltalk that never sends define: - the settled
         ExecFixtures file, reused so the define-less shape keeps one
         definition."
        <category: 'refused shapes'>
        ^ExecFixtures definelessContents
    ]

    ManifestEditFixtures class >> twoDefinesContents [
        "Two complete cascades in one file. There is no way to choose
         between them that is not a guess, so the editor refuses."
        <category: 'refused shapes'>
        ^'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'') ].

Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''2.0.0'';
        fileIns: #(''App2.st'') ]',
            SourceFixtures newline
    ]

    ManifestEditFixtures class >> unclosedBlockContents [
        "A define: whose block is never closed - the file cannot be a
         cascade, so there is no last clause to insert after."
        <category: 'refused shapes'>
        ^'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'')',
            SourceFixtures newline
    ]

    ManifestEditFixtures class >> computedCascadeContents [
        "A cascade with a second statement inside the block: the file
         computes, and inserting a clause after `last clause` is no
         longer a well-defined act."
        <category: 'refused shapes'>
        ^'Parley define: [:pkg |
    | extra |
    extra := ''App.st''.
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: (Array with: extra) ]',
            SourceFixtures newline
    ]

    ManifestEditFixtures class >> outsideVocabularyContents [
        "A cascade carrying a clause that is not a manifest vocabulary
         word. The editor recognizes ONE shape - a cascade of vocabulary
         sends - and this is not it."
        <category: 'refused shapes'>
        ^'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        yourself;
        fileIns: #(''App.st'') ]',
            SourceFixtures newline
    ]

    ManifestEditFixtures class >> computedDependencyContents [
        "A dependency clause whose name is computed rather than
         literal. The editor cannot know what is already declared, so it
         must not risk declaring it twice."
        <category: 'refused shapes'>
        ^'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: (''tool'', ''-b'') constraint: ''^2.0'' ]',
            SourceFixtures newline
    ]

    ManifestEditFixtures class >> sugarDependencyContents [
        "The Doc B §3.2 sugar: dependency: with no constraint, which
         records the unconstrained ''*''. Already-declared detection must
         see it, or add would declare the package a second time."
        <category: 'originals'>
        ^'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''tool-b'' ]',
            SourceFixtures newline
    ]

    ManifestEditFixtures class >> selfDependencyName [
        "The root's own name. Adding it produces a file that inserts
         cleanly and REFUSES TO LOAD (ManifestBuilder rejects a
         self-dependency), which is how the reload-and-rollback path is
         reached without breaking the editor to reach it."
        <category: 'refused shapes'>
        ^'my-app'
    ]

    ManifestEditFixtures class >> unparseableConstraint [
        "A constraint the settled parser rejects. add never parses a
         constraint itself; this one travels into the file and is
         caught by the reload, which is the whole point of verifying an
         edit semantically."
        <category: 'refused shapes'>
        ^'banana'
    ]

    "---- line splitting, for the comment-by-comment assertions ----"

    ManifestEditFixtures class >> textLinesOf: aString [
        "aString split at newlines, as an Array. A trailing newline
         yields no extra empty element, so a file and its edit are
         compared as the lines an author would see."
        <category: 'line comparison'>
        | lines stream |
        lines := OrderedCollection new.
        stream := ReadStream on: aString.
        [stream atEnd] whileFalse: [
            lines add: (stream upTo: Character nl)].
        ^lines asArray
    ]

    ManifestEditFixtures class >> contains: aString line: aLine [
        "Whether aLine appears as a COMPLETE line of aString - byte for
         byte, not as a substring of a longer line."
        <category: 'line comparison'>
        ^(self textLinesOf: aString) includes: aLine
    ]

    ManifestEditFixtures class >> indentOf: aLine [
        "The leading whitespace of aLine - what an inserted clause must
         adopt, because imposing an indentation is a small re-render."
        <category: 'line comparison'>
        | i |
        i := 1.
        [i <= aLine size and: [(aLine at: i) isSeparator]]
            whileTrue: [i := i + 1].
        ^aLine copyFrom: 1 to: i - 1
    ]

    ManifestEditFixtures class >> blankLineCountIn: aString [
        "How many empty lines aString holds. The authored file has
         exactly one, inside the cascade, and an editor that reflowed
         the file would not."
        <category: 'line comparison'>
        ^((self textLinesOf: aString) select: [:each | each isEmpty]) size
    ]

    "---- working directories and their Package.st ----"

    ManifestEditFixtures class >> packageContentsIn: aWorkDir [
        "The working directory's Package.st, as bytes."
        <category: 'working dirs'>
        ^(File name: aWorkDir, '/Package.st') contents
    ]

    ManifestEditFixtures class >> lockContentsIn: aWorkDir [
        <category: 'working dirs'>
        ^SelectiveUpdateFixtures lockContentsIn: aWorkDir
    ]

    ManifestEditFixtures class >> heldVersionsIn: aWorkDir [
        "Every pinned package as name -> Version: the Doc C §2.2
         narrowing input add uses, where update <pkg> excludes the one
         package it is moving. Composed through the settled Sprint 12
         helper so the law suites build the expected narrowed world
         exactly as the verb must."
        <category: 'working dirs'>
        ^SelectiveUpdateFixtures heldVersionsIn: aWorkDir except: nil
    ]

    ManifestEditFixtures class >> workDirNamed: aLabel contents: aContentsString [
        "A working directory holding aContentsString as Package.st and
         no lock. Answers the path; the caller tracks it for teardown."
        <category: 'working dirs'>
        | path |
        path := SourceFixtures directoryNamed: aLabel.
        ExecFixtures writePackage: aContentsString in: path.
        ^path
    ]

    ManifestEditFixtures class >> workDirNamed: aLabel contents: aContentsString lock: aLockString [
        <category: 'working dirs'>
        | path |
        path := self workDirNamed: aLabel contents: aContentsString.
        ExecFixtures writeLock: aLockString in: path.
        ^path
    ]

    ManifestEditFixtures class >> toolBWorkDirNamed: aLabel [
        "The S9/S11 state: the root declares tool-b ^2.0 alone and the
         lock pins tool-b 2.0.0, which the tools index has already moved
         past. Adding tool-a must leave that pin exactly where it is."
        <category: 'working dirs'>
        ^self workDirNamed: aLabel
            contents: self withDependenciesContents
            lock: self toolBOnlyLockString
    ]

    ManifestEditFixtures class >> declaredWorkDirNamed: aLabel [
        "The S7/S8 state: tool-a is ALREADY declared at ^1.0 and pinned
         at 1.0.0. Adding it again identically is idempotent; adding it
         under ^2.0 is a refusal that names the ^1.0 already there."
        <category: 'working dirs'>
        ^self workDirNamed: aLabel
            contents: self declaredRootContents
            lock: self declaredLockString
    ]

    ManifestEditFixtures class >> heldConflictWorkDirNamed: aLabel [
        "The S10 state over the settled held-conflict index: the root
         declares app-y ^1.0, the lock pins app-y 1.0.0 and core 1.0.0.
         Adding app-x - whose only published release needs core ^2.0 -
         cannot resolve while core is held at 1.0.0."
        <category: 'working dirs'>
        ^self workDirNamed: aLabel
            contents: self heldConflictRootContents
            lock: self heldConflictLockString
    ]

    ManifestEditFixtures class >> deletedPinWorkDirNamed: aLabel [
        "The S13 state: the lock pins app-y 1.0.0, which the index no
         longer publishes at all, plus tool-a 1.0.0 so update tool-a
         reaches the same held-pin computation add reaches."
        <category: 'working dirs'>
        ^self workDirNamed: aLabel
            contents: self deletedPinRootContents
            lock: self deletedPinLockString
    ]

    "---- roots ----"

    ManifestEditFixtures class >> declaredRootContents [
        "my-app declaring tool-a ^1.0 already - the S7/S8 input."
        <category: 'roots'>
        ^'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''tool-a'' constraint: ''^1.0'' ]',
            SourceFixtures newline
    ]

    ManifestEditFixtures class >> heldConflictRootContents [
        "my-app declaring app-y ^1.0 alone; app-x is what gets added."
        <category: 'roots'>
        ^'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''app-y'' constraint: ''^1.0'' ]',
            SourceFixtures newline
    ]

    ManifestEditFixtures class >> heldConflictRootManifestAfterAdd [
        "The root as a live manifest AFTER the app-x clause is appended,
         in the file's own declaration order, so the expected narration
         is composed through the identical resolution the verb performs."
        <category: 'roots'>
        ^ResolverFixtures rootWith: (Array
            with: (Array with: 'app-y' with: '^1.0')
            with: (Array with: 'app-x' with: '^1.0'))
    ]

    ManifestEditFixtures class >> deletedPinRootContents [
        "my-app declaring app-y ^1.0 alone; tool-a is what gets added,
         so it must NOT be declared here."
        <category: 'roots'>
        ^'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''app-y'' constraint: ''^1.0'' ]',
            SourceFixtures newline
    ]

    "---- the deleted-pin index (S13) ----"

    ManifestEditFixtures class >> digestAppY100Deleted [
        "The lock digest for app-y 1.0.0 - a release the deleted-pin
         index does not publish, so no archive hashes to it and nothing
         ever verifies it. Shape-valid on the settled padded-mnemonic
         rule, because a lock offending the Sprint 11 digest boundary
         would answer instead of this sprint."
        <category: 'deleted-pin index'>
        ^'de1e000000000000000000000000000000000000000000000000000000000000'
    ]

    ManifestEditFixtures class >> digestAppY110Deleted [
        "The entry digest for app-y 1.1.0 - the release the index DOES
         publish. No archive is written for it either: the run answers
         the deleted-pin diagnosis before any fetch."
        <category: 'deleted-pin index'>
        ^'de11000000000000000000000000000000000000000000000000000000000000'
    ]

    ManifestEditFixtures class >> entryAppY110Deleted [
        <category: 'deleted-pin index'>
        ^SelectiveUpdateFixtures
            entryNamed: 'app-y'
            version: '1.1.0'
            dependencies: '#()'
            digest: self digestAppY110Deleted
    ]

    ManifestEditFixtures class >> populateDeletedPinIndexIn: aDirPath [
        "tool-a 1.0.0/1.1.0 with their real archives (the settled Sprint
         12 values) plus app-y at 1.1.0 ONLY. app-y 1.0.0 - the version
         the lock pins - is absent, which is exactly what deleting an
         old entry leaves behind."
        <category: 'deleted-pin index'>
        SourceFixtures write: SelectiveUpdateFixtures entryToolA100
            toFile: 'tool-a-1.0.0.st' in: aDirPath.
        SourceFixtures write: SelectiveUpdateFixtures entryToolA110
            toFile: 'tool-a-1.1.0.st' in: aDirPath.
        SourceFixtures write: self entryAppY110Deleted
            toFile: 'app-y-1.1.0.st' in: aDirPath.
        SourceFixtures write: SelectiveUpdateFixtures archiveBytesToolA100
            toFile: 'tool-a-1.0.0.star' in: aDirPath.
        SourceFixtures write: SelectiveUpdateFixtures archiveBytesToolA110
            toFile: 'tool-a-1.1.0.star' in: aDirPath
    ]

    "---- lock oracles (writer-format, byte-exact) ----"

    ManifestEditFixtures class >> toolBOnlyLockString [
        "The S9/S11 pre-state: tool-b 2.0.0 alone."
        <category: 'lock oracles'>
        ^SelectiveUpdateFixtures lockWithTuples: (Array
            with: (SelectiveUpdateFixtures tupleFor: 'tool-b'
                version: '2.0.0'
                digest: SelectiveUpdateFixtures digestToolB200))
    ]

    ManifestEditFixtures class >> toolBMovedLockString [
        "The S9 contrast oracle: what PLAIN update writes against the
         identical fixture - tool-b at 2.1.0, proving it was movable and
         that holding is the only reason add left it alone."
        <category: 'lock oracles'>
        ^SelectiveUpdateFixtures lockWithTuples: (Array
            with: (SelectiveUpdateFixtures tupleFor: 'tool-b'
                version: '2.1.0'
                digest: SelectiveUpdateFixtures digestToolB210))
    ]

    ManifestEditFixtures class >> addedLockString [
        "What add tool-a ^1.0 must write: tool-a at 1.1.0, tool-b
         byte-identical at 2.0.0. This is the settled Sprint 12
         toolsMovedLockString, reached by a different verb - the same
         resolved world, so the same bytes."
        <category: 'lock oracles'>
        ^SelectiveUpdateFixtures toolsMovedLockString
    ]

    ManifestEditFixtures class >> declaredLockString [
        "The S7 pre-state: tool-a already pinned at 1.0.0. Adding what is
         already declared rewrites this to identical bytes, because
         every pin is held."
        <category: 'lock oracles'>
        ^SelectiveUpdateFixtures lockWithTuples: (Array
            with: (SelectiveUpdateFixtures tupleFor: 'tool-a'
                version: '1.0.0'
                digest: SelectiveUpdateFixtures digestToolA100))
    ]

    ManifestEditFixtures class >> heldConflictLockString [
        "The S10 pre-state: app-y 1.0.0 and core 1.0.0, both still
         published, so the run reaches the resolution rather than the
         deleted-pin diagnosis."
        <category: 'lock oracles'>
        ^SelectiveUpdateFixtures lockWithTuples: (Array
            with: (SelectiveUpdateFixtures tupleFor: 'app-y'
                version: '1.0.0'
                digest: SelectiveUpdateFixtures digestAppY100)
            with: (SelectiveUpdateFixtures tupleFor: 'core'
                version: '1.0.0'
                digest: SelectiveUpdateFixtures digestCore100))
    ]

    ManifestEditFixtures class >> deletedPinLockString [
        "The S13 pre-state: app-y pinned at a version the index no
         longer publishes, plus tool-a 1.0.0."
        <category: 'lock oracles'>
        ^SelectiveUpdateFixtures lockWithTuples: (Array
            with: (SelectiveUpdateFixtures tupleFor: 'app-y'
                version: '1.0.0'
                digest: self digestAppY100Deleted)
            with: (SelectiveUpdateFixtures tupleFor: 'tool-a'
                version: '1.0.0'
                digest: SelectiveUpdateFixtures digestToolA100))
    ]

    "---- the registration-plan oracle ----"

    ManifestEditFixtures class >> addedRegistrationPlanIn: aWorkDir [
        "The S11 oracle: the settled Doc D §4 plan over the WHOLE
         resolved set - the added tool-a 1.1.0 and the held tool-b
         2.0.0 - which is the settled Sprint 12 plan for the same set."
        <category: 'registration plans'>
        ^SelectiveUpdateFixtures toolsMovedRegistrationPlanIn: aWorkDir
    ]

    "---- pinned wordings (posted on issue #15 for the RED review) ----"

    ManifestEditFixtures class >> unrecognizedLineFor: aName constraint: aConstraint in: aPackagePath [
        "The shape refusal (Doc B §2.1). It names the file and THE EXACT
         TEXT TO PASTE, because a refusal that does not say what to type
         has cost the operator more than it saved. Recognize or refuse:
         an editor that guessed at an unfamiliar file is how a package
         manager earns a reputation for eating manifests."
        <category: 'pinned wordings'>
        ^aPackagePath,
            ': no single Parley define: cascade to edit - add this clause by hand: dependency: ''',
            aName, ''' constraint: ''', aConstraint, ''''
    ]

    ManifestEditFixtures class >> alreadyDeclaredRefusalFor: aName constraint: aConstraint [
        "The different-constraint refusal, naming the constraint already
         in the file. Changing a constraint is an EDIT, and a verb that
         silently overwrote one would be a different verb wearing this
         name (Doc E §4.1)."
        <category: 'pinned wordings'>
        ^aName printString, ' is already declared with constraint ',
            aConstraint printString,
            ' - changing a constraint is an edit, not an add: change it in Package.st by hand'
    ]

    ManifestEditFixtures class >> alreadyDeclaredSuccessFor: aName constraint: aConstraint [
        "The idempotent success line - the update <pkg> already-newest
         precedent: a verb that prints nothing reads as a verb that did
         nothing, and idempotence is what makes add safe in a script."
        <category: 'pinned wordings'>
        ^aName, ' ', aConstraint,
            ' is already declared in Package.st - wrote parley.lock'
    ]

    ManifestEditFixtures class >> deletedHeldPinLineFor: aName version: aVersionString [
        "The Sprint 12 carried gap, closed (S13). A held pin the index
         no longer publishes narrates today as an ordinary version
         conflict - sound under §8 decision 47, and misleading, because
         the real defect is a missing index entry. ONE diagnosis serves
         both add and update <pkg>, and the repair named is parley
         update: the verb that holds nothing and re-resolves."
        <category: 'pinned wordings'>
        ^'parley.lock pins ', aName printString, ' at ', aVersionString,
            ', which the index no longer publishes - run parley update to move off it'
    ]

    ManifestEditFixtures class >> editVerificationLineFor: aPackagePath [
        "The refusal when the reload disagrees with the edit (Doc B
         §2.1): a textual edit that is not checked by the reader that
         owns the meaning is a hope, and the operator must never be left
         a half-edited file."
        <category: 'pinned wordings'>
        ^aPackagePath,
            ': the edited manifest did not load as the edit intended - Package.st was restored unchanged'
    ]

    ManifestEditFixtures class >> selfDependencyProblem [
        "The settled ManifestBuilder problem an inserted self-dependency
         produces. It travels to the operator UNCHANGED - the reload
         boundary reports the author''s own diagnosis, it does not
         paraphrase it."
        <category: 'pinned wordings'>
        ^'package ''my-app'' cannot depend on itself'
    ]

    ManifestEditFixtures class >> unparseableConstraintProblemFor: aName [
        "The settled ManifestBuilder problem an unparseable inserted
         constraint produces. add never parses a constraint itself, so
         this is the one and only place the spelling is judged."
        <category: 'pinned wordings'>
        ^'invalid constraint ', self unparseableConstraint printString,
            ' for dependency ', aName printString
    ]

    ManifestEditFixtures class >> heldPinsLine [
        "The sentence add prepends to a conflict under held pins -
         DELEGATED to the settled Sprint 12 wording, because add holds
         pins by the same mechanism update <pkg> does and the two verbs
         owe the operator the same sentence in one voice."
        <category: 'pinned wordings'>
        ^SelectiveUpdateFixtures heldPinsLine
    ]

    ManifestEditFixtures class >> missingManifestProblemFor: aPath [
        "The S6 diagnosis - the settled missing-manifest line naming
         parley init (§8 decision 31), delegated so every verb answers
         that question with one sentence rather than inventing a second."
        <category: 'pinned wordings'>
        ^CommandLineFixtures missingManifestProblemFor: aPath
    ]

    ManifestEditFixtures class >> usageVerbsLine [
        "The verbs: row. Sprint 13 pinned it here as a LITERAL, in the
         RED that added add to the grammar, and the settled oracle was
         re-pinned to match in GREEN.

         AMENDED AT SPRINT 20's RED (issue #22): it delegates. A second
         literal copy of one sentence is a mover no oracle grep can see
         — `grep ExecFixtures usageLines` finds neither this method nor
         its consumers — and this suite carried FIVE such copies until
         the pre-RED ruling enumerated them. The row is located by its
         START rather than by an offset, because §8 decision 79 forbids
         a law claiming a neighbour's position.

         AMENDED BY THE REVIEWER AT GATE A: it located the row with its
         own inline detect:, which was a SIXTH implementation of the
         locator in the sprint that removed the other five, and it
         carried no ifNone: - so a block that lost its verbs row would
         have failed here with 3.2.5's generic detect: error instead of
         naming what was missing. It delegates like its two siblings."
        <category: 'pinned wordings'>
        ^GrammarFixtures usageVerbsLine
    ]

    ManifestEditFixtures class >> addUsageLines [
        "The whole usage answer for an argv that names no verb Parley
         has in that shape.

         AMENDED AT SPRINT 20's RED: it is no longer the block alone. A
         usage error is one REASON LINE followed by the block (§8
         decision 79), and the four consumers of this fixture drive an
         add argv of the wrong arity WITH a source wired — so the ground
         is #wrongArguments and the subject is the verb. The block half
         delegates to the one oracle.

         ITS TWO NO-SOURCE CONSUMERS MOVED TO A SIBLING, because they
         are a different ground and the ruling that split them is the
         reason this sprint exists: `add tool-a ^1.0` has exactly the
         arguments add takes and lacks only an index, and telling that
         operator their arguments are wrong would be a sentence nothing
         checked."
        <category: 'pinned wordings'>
        ^GrammarFixtures usageAnswerFor: #wrongArguments subject: 'add'
    ]

    ManifestEditFixtures class >> addNoSourceUsageLines [
        "The answer for a well-formed add with no index (§8 decision
         81's #needsIndex ground)."
        <category: 'pinned wordings'>
        ^GrammarFixtures usageAnswerFor: #needsIndex subject: 'add'
    ]
]

Namespace current: Smalltalk.
