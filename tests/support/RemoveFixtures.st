"Parley Sprint 20 - fixtures for parley remove and the manifest
 editor's deletion (issue #22; Doc B §2.1, Doc E §4.1, Doc C §2.2,
 §8 decisions 49 and 67).

 WHY THE EXPECTED TEXTS ARE AUTHORED LITERALS, not computed. Sprint
 13's rule, and it binds harder for deletion: an oracle produced by the
 same splice the implementation performs cannot fail when the splice is
 wrong, and the wrong splice HERE is the one that yields a Package.st
 that no longer loads. Every expected text below was written out by
 hand, character for character, from the original beside it, and the
 laws compare BYTES - never `the file got shorter`, never `the manifest
 has two dependencies`, each of which passes happily on a splice that
 left a dangling semicolon.

 AN INSERTION THAT RECOGNIZES TOO LITTLE REFUSES; A DELETION THAT
 RECOGNIZES TOO LITTLE DAMAGES (§8 decision 67). So the originals are
 chosen for the JOIN rather than for the clause:

   - authoredThreeContents declares three dependencies AND ENDS ON ONE.
     Removing the middle (S1) exercises an ordinary interior join;
     removing the last (S2) is the scenario a splice that deletes only
     the clause's own text passes S1 and then fails, because what is
     left behind is `;` immediately before the cascade's closing
     bracket. One original serves both, which is what S2 means by `the
     same manifest`.
   - It also carries a header comment, an INTERIOR comment above the
     tool-b clause, a blank line inside the cascade and six-space
     indentation. Removing tool-b takes that comment WITH IT - the
     comment sits inside tool-b's own clause span and is about tool-b -
     while removing anything else leaves every one of those bytes
     alone. Both halves are asserted, because `preserve every other
     byte` is a claim about what moves as well as about what stays.
   - soloContents declares exactly ONE dependency. What remains after
     removing it is a valid manifest that re-loads, which is ordinary
     success and not a special case.
   - receiverFirstContents puts the dependency in the cascade's FIRST
     clause. The settled recognizer splits clauses from bar + 1
     (ManifestEditor.st:149), so clause one contains the cascade
     RECEIVER, and a splice that deleted `the clause` verbatim would
     delete `pkg` and leave a file that does not parse. It is also the
     one position where the binding separator is the one AFTER the
     clause rather than the one before it: deleting the preceding join
     here would leave `pkg;` in front of the next clause, which is a
     cascade whose first message is missing. Decision 67's damage case,
     twice, in the position no other fixture reaches.
   - ghostContents declares a package the index never published, so a
     remove that has already REWRITTEN Package.st then fails to
     resolve. That is S6's atomicity, reached honestly rather than by
     breaking the editor to get there.
   - fourPinsContents is S7's project: four pins, one removed, the other
     three asserted TUPLE BY TUPLE against the lock as it stood.

 THE PRE-STATE LOCKS CARRY TRUE DIGESTS, computed at fixture time
 through the settled vector-anchored Sha256, because S7 compares the
 lock before against the lock after tuple by tuple - a pre-state lock
 with placeholder digests would make every tuple differ and the law
 would be asserting nothing about holding.

 The index is metadata plus real archive bytes, so install and register
 run exactly as they do for add; every runner is a RecordingRunner, so
 nothing spawns and no network is contacted. Every fixture path is
 under tmp/, unique per label, removed recursively by the caller."

Namespace current: Parley.

Object subclass: RemoveFixtures [

    <comment: 'Class-side factory for Sprint 20 remove fixtures: the
five originals chosen for the joins they exercise, their hand-written
removed counterparts, the four-package index with real archives, the
pre-state locks with true digests, and every pinned remove wording.
Stateless; uniqueness comes from per-test labels.'>

    "---- the package every scenario removes ----"

    RemoveFixtures class >> removedName [
        "The middle dependency of the three - S1's subject."
        <category: 'the removal'>
        ^'tool-c'
    ]

    RemoveFixtures class >> lastName [
        "The dependency that is also the cascade's LAST clause - S2."
        <category: 'the removal'>
        ^'tool-d'
    ]

    RemoveFixtures class >> firstName [
        "The dependency the interior comment is about, and the first of
         the three."
        <category: 'the removal'>
        ^'tool-b'
    ]

    RemoveFixtures class >> undeclaredName [
        "A package no fixture manifest declares - S5's subject."
        <category: 'the removal'>
        ^'tool-z'
    ]

    "---- original 1: three dependencies, ending on one (S1, S2) ----"

    RemoveFixtures class >> authoredThreeContents [
        "The author's own file: a header comment, an interior comment
         above the tool-b clause, a blank line inside the cascade, and
         six-space indentation instead of eight. The cascade's last
         clause is a dependency, which is what makes S2 reachable from
         the same original S1 uses."
        <category: 'originals'>
        ^'"my-app - the application manifest.
 The pins below are deliberate; read docs/DEPS.md before changing them."
Parley define: [:pkg |
  pkg
      name: ''my-app'';
      version: ''1.0.0'';
      fileIns: #(''App.st'');

      "tool-b stays on 2.x: 3.0 dropped the streaming reader we use"
      dependency: ''tool-b'' constraint: ''^2.0'';
      dependency: ''tool-c'' constraint: ''^1.0'';
      dependency: ''tool-d'' constraint: ''^3.0'' ]',
            SourceFixtures newline
    ]

    RemoveFixtures class >> authoredThreeWithoutMiddle [
        "S1, written out by hand from the original: the tool-c clause
         and the semicolon that joined it to tool-b are gone, and every
         other byte stands - both comments, the blank line, the
         six-space indent, the closing bracket and the trailing
         newline."
        <category: 'removed texts'>
        ^'"my-app - the application manifest.
 The pins below are deliberate; read docs/DEPS.md before changing them."
Parley define: [:pkg |
  pkg
      name: ''my-app'';
      version: ''1.0.0'';
      fileIns: #(''App.st'');

      "tool-b stays on 2.x: 3.0 dropped the streaming reader we use"
      dependency: ''tool-b'' constraint: ''^2.0'';
      dependency: ''tool-d'' constraint: ''^3.0'' ]',
            SourceFixtures newline
    ]

    RemoveFixtures class >> authoredThreeWithoutLast [
        "S2, written out by hand: the tool-d clause AND the semicolon
         that joined it to tool-c are gone, so the cascade now ends on
         tool-c. A splice that deleted only the clause would leave
         `;` immediately before ` ]` and the file would not parse."
        <category: 'removed texts'>
        ^'"my-app - the application manifest.
 The pins below are deliberate; read docs/DEPS.md before changing them."
Parley define: [:pkg |
  pkg
      name: ''my-app'';
      version: ''1.0.0'';
      fileIns: #(''App.st'');

      "tool-b stays on 2.x: 3.0 dropped the streaming reader we use"
      dependency: ''tool-b'' constraint: ''^2.0'';
      dependency: ''tool-c'' constraint: ''^1.0'' ]',
            SourceFixtures newline
    ]

    RemoveFixtures class >> authoredThreeWithoutFirst [
        "Removing tool-b, written out by hand. The blank line and the
         interior comment go WITH the clause, because both sit inside
         tool-b's own span and both are about tool-b. The header
         comment, the six-space indent and the other two clauses stand
         untouched."
        <category: 'removed texts'>
        ^'"my-app - the application manifest.
 The pins below are deliberate; read docs/DEPS.md before changing them."
Parley define: [:pkg |
  pkg
      name: ''my-app'';
      version: ''1.0.0'';
      fileIns: #(''App.st'');
      dependency: ''tool-c'' constraint: ''^1.0'';
      dependency: ''tool-d'' constraint: ''^3.0'' ]',
            SourceFixtures newline
    ]

    RemoveFixtures class >> authoredHeaderCommentLine [
        "The header comment's first line, asserted to survive on its own
         rather than only inside a whole-text compare."
        <category: 'originals'>
        ^'"my-app - the application manifest.'
    ]

    RemoveFixtures class >> authoredInteriorCommentLine [
        "The interior comment, with the author's own indentation."
        <category: 'originals'>
        ^'      "tool-b stays on 2.x: 3.0 dropped the streaming reader we use"'
    ]

    "---- original 2: exactly one dependency (S3, S5) ----"

    RemoveFixtures class >> soloContents [
        "One dependency and nothing else to remove. Also S5's manifest:
         a recognized cascade that does not declare tool-z."
        <category: 'originals'>
        ^'Parley define: [:pkg |
    pkg
        name: ''solo-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''tool-b'' constraint: ''^2.0'' ]',
            SourceFixtures newline
    ]

    RemoveFixtures class >> soloWithoutDependency [
        "S3, written out by hand: the cascade now ends on fileIns:, the
         semicolon that joined the dependency to it is gone, and what
         remains is a valid manifest that re-loads."
        <category: 'removed texts'>
        ^'Parley define: [:pkg |
    pkg
        name: ''solo-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'') ]',
            SourceFixtures newline
    ]

    "---- original 3: the dependency is the FIRST clause ----"

    RemoveFixtures class >> receiverFirstContents [
        "The cascade receiver and the dependency share clause one. A
         splice that deletes the clause span verbatim deletes `pkg`;
         a splice that takes the PRECEDING join leaves `pkg;`. Both
         produce a file that does not parse."
        <category: 'originals'>
        ^'Parley define: [:pkg |
    pkg dependency: ''tool-b'' constraint: ''^2.0'';
        name: ''first-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'') ]',
            SourceFixtures newline
    ]

    RemoveFixtures class >> receiverFirstWithoutDependency [
        "Written out by hand: the receiver stays, the message and the
         semicolon AFTER it go, and name: becomes the cascade's first
         message on its own line."
        <category: 'removed texts'>
        ^'Parley define: [:pkg |
    pkg
        name: ''first-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'') ]',
            SourceFixtures newline
    ]

    "---- original 4: a resolution that fails after the write (S6) ----"

    RemoveFixtures class >> ghostContents [
        "Declares a package the index never published beside two it did.
         Removing tool-c rewrites Package.st and THEN fails to resolve,
         which is the only honest way to reach the rollback: the editor
         is never broken to get there."
        <category: 'originals'>
        ^'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''ghost'' constraint: ''^9.0'';
        dependency: ''tool-b'' constraint: ''^2.0'';
        dependency: ''tool-c'' constraint: ''^1.0'' ]',
            SourceFixtures newline
    ]

    "---- original 5: four pins (S7) ----"

    RemoveFixtures class >> fourPinsContents [
        <category: 'originals'>
        ^'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''tool-a'' constraint: ''^1.0'';
        dependency: ''tool-b'' constraint: ''^2.0'';
        dependency: ''tool-c'' constraint: ''^1.0'';
        dependency: ''tool-d'' constraint: ''^3.0'' ]',
            SourceFixtures newline
    ]

    "---- the index: four packages, real archive bytes ----"

    RemoveFixtures class >> archiveBytesFor: aName version: aVersionString [
        "Opaque authored bytes, distinct per release so no two digests
         can collide by accident."
        <category: 'index directories'>
        ^'opaque archive bytes: ', aName, ' ', aVersionString
    ]

    RemoveFixtures class >> digestFor: aName version: aVersionString [
        "Computed at fixture time through the SETTLED, vector-anchored
         Sha256 - the Sprint 14/15 precedent. Never used to test Sha256
         itself, and never hand-copied: a pinned literal here would be a
         second definition of the same digest with nothing comparing
         them."
        <category: 'index directories'>
        ^Sha256 hexDigestOf: (self archiveBytesFor: aName
            version: aVersionString)
    ]

    RemoveFixtures class >> entryFor: aName version: aVersionString [
        "A Doc B §5.2 schema-exact entry naming its archive by the
         storage convention, with no dependencies of its own."
        <category: 'index directories'>
        ^'#(#''parley-index'' 1 #name ''', aName,
            ''' #version ''', aVersionString,
            ''' #summary '''' #author '''' #license '''' #fileIns #(''Lib.st'') #dependencies #() #archive #(''',
            aName, '-', aVersionString, '.star'' #sha256 ''',
            (self digestFor: aName version: aVersionString),
            '''))', SourceFixtures newline
    ]

    RemoveFixtures class >> releases [
        "The four packages the fixtures declare, plus a SECOND tool-a
         release its ^1.0 constraint also admits.

         The second release is what makes holding observable. With one
         version per package nothing could move whatever the verb did,
         so a law asserting `the other pins did not move` would pass
         against an implementation that re-resolved everything freely -
         the fixture would prove nothing, which is the defect Sprint
         13's contrast law exists to prevent."
        <category: 'index directories'>
        ^(Array
            with: #('tool-a' '1.0.0')
            with: #('tool-a' '1.5.0')
            with: #('tool-b' '2.0.0')),
            (Array
                with: #('tool-c' '1.0.0')
                with: #('tool-d' '3.0.0'))
    ]

    RemoveFixtures class >> movableName [
        "The package a plain update would move and a remove must not."
        <category: 'index directories'>
        ^'tool-a'
    ]

    RemoveFixtures class >> movableHeldVersion [
        <category: 'index directories'>
        ^'1.0.0'
    ]

    RemoveFixtures class >> movableFreeVersion [
        <category: 'index directories'>
        ^'1.5.0'
    ]

    RemoveFixtures class >> populateRemoveIndexIn: aDirPath [
        "Four dependency-free packages with their archives, so a remove
         that resolves really installs and registers the pins it kept -
         exactly as add does."
        <category: 'index directories'>
        self releases do: [:each |
            | name version |
            name := each at: 1.
            version := each at: 2.
            SourceFixtures write: (self entryFor: name version: version)
                toFile: name, '-', version, '.st' in: aDirPath.
            SourceFixtures
                write: (self archiveBytesFor: name version: version)
                toFile: name, '-', version, '.star' in: aDirPath]
    ]

    "---- the pre-state locks ----"

    RemoveFixtures class >> tupleFor: aName version: aVersionString [
        "One lock tuple carrying the release's TRUE digest, so a lock
         written by resolve over this index is byte-identical to the
         pre-state - which is what lets S7 assert the untouched pins
         tuple by tuple rather than merely `the lock changed`."
        <category: 'locks'>
        ^'#(''', aName, ''' ''', aVersionString, ''' #sha256 ''',
            (self digestFor: aName version: aVersionString), ''')'
    ]

    RemoveFixtures class >> lockWithTuples: aTupleCollection [
        <category: 'locks'>
        | out |
        out := WriteStream on: String new.
        out nextPutAll: '#(#''parley-lock'' 1 #root ''my-app'' #packages #('.
        aTupleCollection
            do: [:each | out nextPutAll: each]
            separatedBy: [out nextPut: Character space].
        out nextPutAll: '))'.
        ^out contents, SourceFixtures newline
    ]

    RemoveFixtures class >> threeLockString [
        "tool-b, tool-c and tool-d pinned - the state authoredThree
         starts from."
        <category: 'locks'>
        ^self lockWithTuples: (Array
            with: (self tupleFor: 'tool-b' version: '2.0.0')
            with: (self tupleFor: 'tool-c' version: '1.0.0')
            with: (self tupleFor: 'tool-d' version: '3.0.0'))
    ]

    RemoveFixtures class >> soloLockString [
        <category: 'locks'>
        ^self lockWithTuples: (Array with:
            (self tupleFor: 'tool-b' version: '2.0.0'))
    ]

    RemoveFixtures class >> emptyLockString [
        "What remains after removing the only dependency: a lock the
         settled writer really wrote, with no pins at all."
        <category: 'locks'>
        ^self lockWithTuples: #()
    ]

    RemoveFixtures class >> ghostLockString [
        "Pins the two packages the index publishes; ghost is declared
         and never pinned, which is the state that makes the
         re-resolution fail after the edit."
        <category: 'locks'>
        ^self lockWithTuples: (Array
            with: (self tupleFor: 'tool-b' version: '2.0.0')
            with: (self tupleFor: 'tool-c' version: '1.0.0'))
    ]

    RemoveFixtures class >> fourLockString [
        <category: 'locks'>
        ^self lockWithTuples: (Array
            with: (self tupleFor: 'tool-a' version: '1.0.0')
            with: (self tupleFor: 'tool-b' version: '2.0.0')
            with: (self tupleFor: 'tool-c' version: '1.0.0')
            with: (self tupleFor: 'tool-d' version: '3.0.0'))
    ]

    "---- working directories ----"

    RemoveFixtures class >> workDirNamed: aLabel contents: aContentsString [
        <category: 'working dirs'>
        | path |
        path := SourceFixtures directoryNamed: aLabel.
        ExecFixtures writePackage: aContentsString in: path.
        ^path
    ]

    RemoveFixtures class >> workDirNamed: aLabel contents: aContentsString lock: aLockString [
        <category: 'working dirs'>
        | path |
        path := self workDirNamed: aLabel contents: aContentsString.
        ExecFixtures writeLock: aLockString in: path.
        ^path
    ]

    RemoveFixtures class >> authoredWorkDirNamed: aLabel [
        <category: 'working dirs'>
        ^self workDirNamed: aLabel
            contents: self authoredThreeContents
            lock: self threeLockString
    ]

    RemoveFixtures class >> soloWorkDirNamed: aLabel [
        <category: 'working dirs'>
        ^self workDirNamed: aLabel
            contents: self soloContents
            lock: self soloLockString
    ]

    RemoveFixtures class >> receiverFirstWorkDirNamed: aLabel [
        <category: 'working dirs'>
        ^self workDirNamed: aLabel
            contents: self receiverFirstContents
            lock: self soloLockString
    ]

    RemoveFixtures class >> ghostWorkDirNamed: aLabel [
        <category: 'working dirs'>
        ^self workDirNamed: aLabel
            contents: self ghostContents
            lock: self ghostLockString
    ]

    RemoveFixtures class >> fourPinsWorkDirNamed: aLabel [
        <category: 'working dirs'>
        ^self workDirNamed: aLabel
            contents: self fourPinsContents
            lock: self fourLockString
    ]

    RemoveFixtures class >> unrecognizedWorkDirNamed: aLabel [
        "A shape the settled recognizer refuses - two complete define:
         cascades, reused from the Sprint 13 fixture so `unrecognized`
         keeps one definition across the two verbs that share the
         recognizer."
        <category: 'working dirs'>
        ^self workDirNamed: aLabel
            contents: ManifestEditFixtures twoDefinesContents
    ]

    "---- pinned wordings ----"

    RemoveFixtures class >> unrecognizedLineFor: aName in: aPackagePath [
        "The shape refusal. It names the file AND the clause to delete,
         because a refusal that does not say what to do has cost the
         operator more than it saved (§8 decisions 31 and 44). It names
         the CLAUSE BY ITS PACKAGE rather than by its exact bytes,
         because a shape the recognizer could not read is a shape whose
         constraint it could not read either - a refusal quoting a
         constraint it never parsed would be asserting something it did
         not check."
        <category: 'pinned wordings'>
        ^aPackagePath,
            ': no single Parley define: cascade to edit - delete the dependency: ''',
            aName, ''' clause by hand'
    ]

    RemoveFixtures class >> notDeclaredLineFor: aName [
        "The why precedent: the operator asked about a package they do
         not have. Nothing is written - not the manifest, not the lock."
        <category: 'pinned wordings'>
        ^aName printString, ' is not declared in Package.st'
    ]

    RemoveFixtures class >> pinLineFor: aName version: aVersionString [
        "One line of the settled pin report - remove reports what the
         project now has, exactly as add and update do."
        <category: 'pinned wordings'>
        ^aName, ' ', aVersionString
    ]

    RemoveFixtures class >> pinsAfterRemovingMiddle [
        "S1's success lines: tool-b and tool-d, in sorted name order."
        <category: 'pinned wordings'>
        ^Array
            with: (self pinLineFor: 'tool-b' version: '2.0.0')
            with: (self pinLineFor: 'tool-d' version: '3.0.0')
    ]

    RemoveFixtures class >> pinsAfterRemovingLast [
        <category: 'pinned wordings'>
        ^Array
            with: (self pinLineFor: 'tool-b' version: '2.0.0')
            with: (self pinLineFor: 'tool-c' version: '1.0.0')
    ]

    "---- reading the artifacts back ----"

    RemoveFixtures class >> packageIn: aWorkDir [
        <category: 'artifacts'>
        ^PathFixtures contentsOf: aWorkDir, '/Package.st'
    ]

    RemoveFixtures class >> lockIn: aWorkDir [
        <category: 'artifacts'>
        ^PathFixtures contentsOf: aWorkDir, '/parley.lock'
    ]

    RemoveFixtures class >> lockTuplesIn: aWorkDir [
        "The lock's package tuples as (name, version, digest) triples,
         read through the SETTLED literals-only reader rather than by
         string matching - S7 compares pins tuple by tuple, and a
         substring comparison would call two different locks equal the
         moment one was a prefix of the other."
        <category: 'artifacts'>
        | entry packages |
        entry := IndexEntryReader readFrom:
            (ReadStream on: (self lockIn: aWorkDir)).
        packages := nil.
        1 to: entry size - 1 do: [:i |
            (entry at: i) = #packages ifTrue: [packages := entry at: i + 1]].
        ^packages collect: [:tuple |
            Array with: (tuple at: 1) with: (tuple at: 2) with: (tuple at: 4)]
    ]

    RemoveFixtures class >> tupleNamed: aName in: aTupleCollection [
        "One package's tuple, or nil when the lock does not pin it."
        <category: 'artifacts'>
        ^aTupleCollection
            detect: [:tuple | (tuple at: 1) = aName]
            ifNone: [nil]
    ]
]

Namespace current: Smalltalk.
