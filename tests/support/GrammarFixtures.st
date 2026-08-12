"Parley Sprint 20 - fixtures for the usage grounds and the three
 reading verbs (issue #22; Doc E §4/§4.1/§4.2, Doc C §2, Doc F §7.3,
 §8 decisions 79, 80 and 81).

 Two families live here, and they share one file because they share one
 index: the USAGE surface (the block, the six declared reasons, and the
 answers each ground composes) and the three verbs that only READ -
 search, info and outdated. parley remove has its own fixture file,
 because it is the only verb here that writes.

 THE BLOCK AND THE REASON ARE DIFFERENT ARTIFACTS (§8 decision 79). A
 usage error is one reason line followed by the block; --help is the
 block ALONE at exit 0. So this file pins them apart: usageBlockLines
 is the shared text, reasonFor:subject: is the line that names what
 happened, and usageAnswerFor:subject: is the composition. Nothing here
 pins a whole usage answer as one literal - a fixture that did could not
 tell a moved block from a moved reason.

 THE SIX REASONS ARE THE OPERATOR'S, PINNED AT THE PRE-RED RULING
 (§8 decision 81) and not re-worded here. Four of the six interpolate
 their subject - the verb, or the layout name - so each is a message
 taking one argument rather than a literal, exactly as the shipped
 table's rows are.

 THE GRAMMAR INDEX IS BUILT FOR THE TWO COLUMNS. outdated must report
 two facts that are different facts, so the index publishes a package
 where BOTH are true at once (kernel-text: the constraint allows a
 newer release AND a newer one still exists outside it), a package
 where only widening helps (kernel-lint), and a leaf package that is
 fully current beside a RETIRED newer release (kernel-solo). A fixture
 with one movable package cannot fail a build that conflates the
 columns, and a current-project fixture with a transitive pin would
 drag that pin's own two columns into the answer.

 EVERY ENTRY IS METADATA-ONLY (#archive #()) and every lock digest is
 the empty string the writer itself renders for an unpublished archive
 (Doc B §5.3, §8 decision 42). None of these three verbs installs
 anything, so an archive would be fixture furniture that no assertion
 could ever see.

 THE GIT CHATTER HALF drives the SHIPPED BINARY with stdout and stderr
 captured SEPARATELY through Sprint 18's runShippedIn:args:captures:
 label: - the settled runners merge with 2>&1 and cannot tell text
 Parley kept on one stream from text it must remove from the other. The
 markers are what must NOT appear; the fixture repositories are the
 settled PublishFixtures ones, built locally, no network.

 Stateless; uniqueness comes from per-test labels, and every label is
 per-flag as well as per-scenario - Sprint 19 lost a scenario to one
 directory name colliding across two iterations of a driver loop."

Namespace current: Parley.

Object subclass: GrammarFixtures [

    <comment: 'Class-side factory for Sprint 20 usage and reading-verb
fixtures: the usage block, the six declared reason lines and the answer
each ground composes, the grammar index and its roots and locks, the
pinned search/info/outdated renderings, the sparse base trees for the
capability refusal and the outside-the-closure info, and the git
chatter markers. Stateless.'>

    "---- the usage block (§8 decision 79 - the SHARED artifact) ----"

    GrammarFixtures class >> usageBlockLines [
        "The block: the six lines every usage answer ends with and
         --help answers ALONE. SIX, not seven - probed through the
         shipped binary at 476 B, and §8 decision 79 is amended to say
         so.

         IT ADDS NO SECOND COPY, AND THAT IS THE POINT. The suite
         already carried FIVE literal copies of this block or its verbs
         row - ExecFixtures usageLines plus one each in
         ManifestEditFixtures, SelectiveUpdateFixtures,
         InspectionFixtures and ReleaseHardeningTest - and every one of
         them was a mover no oracle grep could see. A sixth would be the
         same defect committed by the sprint that found it, so this
         answers the settled oracle and the four duplicates are amended
         to delegate to it. ONE literal, in ExecFixtures, amended in RED
         where its verbs row goes from ten verbs to fourteen."
        <category: 'usage block'>
        ^ExecFixtures usageLines
    ]

    GrammarFixtures class >> usageVerbsLine [
        "The verbs row, located in the block by name rather than by
         offset, so no law here indexes a neighbour (§8 decision 79)."
        <category: 'usage block'>
        ^self verbsRowIn: self usageBlockLines
    ]

    GrammarFixtures class >> verbsRowIn: someLines [
        "The verbs row of ANY answer - a usage error's or --help's -
         found by its own start rather than at an index. Eleven settled
         methods read `lines at: 2` for this and every one of them moved
         when a reason line arrived above the block; that offset was
         always a claim about a neighbour rather than about the row
         being asserted (§8 decision 79)."
        <category: 'usage block'>
        ^someLines
            detect: [:line | line startsWith: 'verbs: ']
            ifNone: [self error: 'no verbs row in ', someLines printString]
    ]

    GrammarFixtures class >> headerRowIn: someLines [
        "The usage header, found the same way and for the same reason."
        <category: 'usage block'>
        ^someLines
            detect: [:line | line startsWith: 'usage: ']
            ifNone: [self error: 'no usage header in ', someLines printString]
    ]

    "---- the six declared reasons (§8 decision 81 - PINNED by the
          operator at the pre-RED ruling; not re-worded here) ----"

    GrammarFixtures class >> noVerbReason [
        <category: 'usage reasons'>
        ^'no verb given'
    ]

    GrammarFixtures class >> unknownVerbReasonFor: aWord [
        <category: 'usage reasons'>
        ^aWord, ' is not a parley verb'
    ]

    GrammarFixtures class >> wrongArgumentsReasonFor: aVerb [
        <category: 'usage reasons'>
        ^aVerb, ' does not take those arguments'
    ]

    GrammarFixtures class >> needsIndexReasonFor: aVerb [
        <category: 'usage reasons'>
        ^aVerb, ' needs an index - give --source, --git or --index'
    ]

    GrammarFixtures class >> bothSourceFlagsReason [
        <category: 'usage reasons'>
        ^'--source, --git and --index are mutually exclusive - give one'
    ]

    GrammarFixtures class >> unknownLayoutReasonFor: aName [
        <category: 'usage reasons'>
        ^aName, ' is not an index layout - give flat or sparse'
    ]

    GrammarFixtures class >> reasonFor: aGroundSymbol subject: aSubject [
        "The declared reason for one ground. The subject is the verb for
         three of the six, the layout name for one, and unused for the
         two that name no subject at all."
        <category: 'usage reasons'>
        aGroundSymbol = #noVerb ifTrue: [^self noVerbReason].
        aGroundSymbol = #unknownVerb
            ifTrue: [^self unknownVerbReasonFor: aSubject].
        aGroundSymbol = #wrongArguments
            ifTrue: [^self wrongArgumentsReasonFor: aSubject].
        aGroundSymbol = #needsIndex
            ifTrue: [^self needsIndexReasonFor: aSubject].
        aGroundSymbol = #bothSourceFlags
            ifTrue: [^self bothSourceFlagsReason].
        aGroundSymbol = #unknownLayout
            ifTrue: [^self unknownLayoutReasonFor: aSubject].
        ^self error: 'no declared reason for ground ', aGroundSymbol printString
    ]

    GrammarFixtures class >> declaredGroundSymbols [
        "The six grounds, in the order the shipped table declares them.
         The drift law reads this beside CommandLine class >>
         usageReasons so a seventh ground cannot arrive undeclared."
        <category: 'usage reasons'>
        ^#(#noVerb #unknownVerb #wrongArguments #needsIndex
            #bothSourceFlags #unknownLayout)
    ]

    GrammarFixtures class >> usageAnswerFor: aGroundSymbol subject: aSubject [
        "One reason line, then the block. THE COMPOSITION, spelled once
         here so no law has to restate it and no law has to index into
         the result."
        <category: 'usage reasons'>
        ^(Array with: (self reasonFor: aGroundSymbol subject: aSubject)),
            self usageBlockLines
    ]

    "---- the grammar index: the world search, info and outdated read ----"

    GrammarFixtures class >> jsonSummary [
        <category: 'index metadata'>
        ^'A JSON reader and writer speaking pure message sends'
    ]

    GrammarFixtures class >> jsonAuthor [
        <category: 'index metadata'>
        ^'Leonardo'
    ]

    GrammarFixtures class >> jsonLicense [
        <category: 'index metadata'>
        ^'MIT'
    ]

    GrammarFixtures class >> textSummary [
        <category: 'index metadata'>
        ^'String utilities that do not allocate'
    ]

    GrammarFixtures class >> lintSummary [
        <category: 'index metadata'>
        ^'A style checker for authored packages'
    ]

    GrammarFixtures class >> json032Reason [
        "The reason the index owner wrote for retiring 0.3.2. It travels
         VERBATIM through the settled retirementReasonFor:version: to
         the operator, which is the whole of §8 decision 37''s consumer
         story - and info is its second reader."
        <category: 'index metadata'>
        ^'the nested-array reader mis-parsed empty arrays - use 0.3.1'
    ]

    GrammarFixtures class >> entryFor: aName version: aVersionString summary: aSummary author: anAuthor license: aLicense dependencies: someDepPairs [
        "A Doc B §5.2 schema-exact metadata-only entry: fixed key order,
         all keys present, dependencies sorted by name, #archive #()."
        <category: 'index directories'>
        | out |
        out := WriteStream on: String new.
        out nextPutAll: '#(#''parley-index'' 1 #name ''';
            nextPutAll: aName;
            nextPutAll: ''' #version ''';
            nextPutAll: aVersionString;
            nextPutAll: ''' #summary ''';
            nextPutAll: aSummary;
            nextPutAll: ''' #author ''';
            nextPutAll: anAuthor;
            nextPutAll: ''' #license ''';
            nextPutAll: aLicense;
            nextPutAll: ''' #fileIns #(''Lib.st'') #dependencies #('.
        someDepPairs
            do: [:pair | out nextPutAll: '#(''';
                nextPutAll: (pair at: 1);
                nextPutAll: ''' ''';
                nextPutAll: (pair at: 2);
                nextPutAll: ''')']
            separatedBy: [out nextPutAll: ' '].
        out nextPutAll: ') #archive #())'.
        ^out contents, SourceFixtures newline
    ]

    GrammarFixtures class >> populateGrammarIndexIn: aDirPath [
        "The index all three reading verbs read.

         kernel-json 0.3.1 carries EVERY declared field - the S17
         fixture - and depends on kernel-text, so info has a dependency
         to render. kernel-json 0.3.2 is RETIRED, so the same package is
         S16''s current-with-a-retired-newer-release and S18''s marked
         version in one artifact.

         kernel-text publishes 1.0.0, 1.2.0 and 2.0.0: under ^1.0 the
         pin can move to 1.2.0 AND a newer release exists outside the
         constraint, so ONE pin makes both outdated columns differ.

         kernel-lint publishes 1.0.0 and 2.0.0 only: under ^1.0 nothing
         moves, and 2.0.0 is reachable only by widening. That is the
         second column with the first standing still - the pair that
         makes conflating them observable."
        <category: 'index directories'>
        SourceFixtures write: (self entryFor: 'kernel-json' version: '0.3.1'
                summary: self jsonSummary
                author: self jsonAuthor
                license: self jsonLicense
                dependencies: (Array with: #('kernel-text' '^1.0')))
            toFile: 'kernel-json-0.3.1.st' in: aDirPath.
        SourceFixtures write: (self entryFor: 'kernel-json' version: '0.3.2'
                summary: self jsonSummary
                author: self jsonAuthor
                license: self jsonLicense
                dependencies: (Array with: #('kernel-text' '^1.0')))
            toFile: 'kernel-json-0.3.2.st' in: aDirPath.
        SourceFixtures write: (self entryFor: 'kernel-text' version: '1.0.0'
                summary: self textSummary author: '' license: ''
                dependencies: #())
            toFile: 'kernel-text-1.0.0.st' in: aDirPath.
        SourceFixtures write: (self entryFor: 'kernel-text' version: '1.2.0'
                summary: self textSummary author: '' license: ''
                dependencies: #())
            toFile: 'kernel-text-1.2.0.st' in: aDirPath.
        SourceFixtures write: (self entryFor: 'kernel-text' version: '2.0.0'
                summary: self textSummary author: '' license: ''
                dependencies: #())
            toFile: 'kernel-text-2.0.0.st' in: aDirPath.
        SourceFixtures write: (self entryFor: 'kernel-lint' version: '1.0.0'
                summary: self lintSummary author: '' license: ''
                dependencies: #())
            toFile: 'kernel-lint-1.0.0.st' in: aDirPath.
        SourceFixtures write: (self entryFor: 'kernel-lint' version: '2.0.0'
                summary: self lintSummary author: '' license: ''
                dependencies: #())
            toFile: 'kernel-lint-2.0.0.st' in: aDirPath.
        SourceFixtures write: (self entryFor: 'kernel-solo' version: '1.0.0'
                summary: self soloSummary author: '' license: ''
                dependencies: #())
            toFile: 'kernel-solo-1.0.0.st' in: aDirPath.
        SourceFixtures write: (self entryFor: 'kernel-solo' version: '2.0.0'
                summary: self soloSummary author: '' license: ''
                dependencies: #())
            toFile: 'kernel-solo-2.0.0.st' in: aDirPath.
        SourceFixtures write: self retirementRecord
            toFile: 'retired.st' in: aDirPath
    ]

    GrammarFixtures class >> soloSummary [
        <category: 'index metadata'>
        ^'A leaf package with nothing newer to move to'
    ]

    GrammarFixtures class >> solo200Reason [
        "kernel-solo 2.0.0 is retired, so a project pinned at 1.0.0 is
         CURRENT even though the index carries a higher version number.
         That is S16's whole subject: a retired newer release is not an
         upgrade in either column."
        <category: 'index metadata'>
        ^'2.0.0 shipped an incompatible loader - stay on 1.0.0'
    ]

    GrammarFixtures class >> retirementRecord [
        "The Doc B §5.5 record, rendered through the settled
         RetirementFixtures composer so the schema keeps one definition.
         TWO retirements, and they do different jobs: kernel-json 0.3.2
         is the release info must LIST and MARK, and kernel-solo 2.0.0
         is the newer release outdated must offer in NEITHER column."
        <category: 'index directories'>
        ^RetirementFixtures retirementRecordWith: (Array
            with: (RetirementFixtures retirementTupleFor: 'kernel-json'
                version: '0.3.2'
                reason: self json032Reason)
            with: (RetirementFixtures retirementTupleFor: 'kernel-solo'
                version: '2.0.0'
                reason: self solo200Reason))
    ]

    "---- roots and locks ----"

    GrammarFixtures class >> outdatedRootContents [
        "The S15 root: kernel-text ^1.0 (can move under the constraint
         AND further outside it) and kernel-lint ^1.0 (can move only if
         the constraint widens)."
        <category: 'roots'>
        ^'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''kernel-lint'' constraint: ''^1.0'';
        dependency: ''kernel-text'' constraint: ''^1.0'' ]',
            SourceFixtures newline
    ]

    GrammarFixtures class >> currentRootContents [
        "The S16 root: kernel-solo ^1.0 and nothing else.

         ONE DEPENDENCY, AND IT HAS NO DEPENDENCIES OF ITS OWN, because
         `fully current` has to be true of EVERY pin in the lock and a
         transitive pin would drag its own two columns into the answer.
         kernel-solo publishes 1.0.0 and a RETIRED 2.0.0, so this
         project is current while the index carries a higher version
         number - which is the only shape that can fail a build offering
         retired releases as upgrades."
        <category: 'roots'>
        ^'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''kernel-solo'' constraint: ''^1.0'' ]',
            SourceFixtures newline
    ]

    GrammarFixtures class >> lockWithTuples: aTupleCollection [
        "Private - a #'parley-lock' 1 artifact in the §5.4 canonical
         rendering."
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

    GrammarFixtures class >> tupleFor: aName version: aVersionString [
        "Private - one lock tuple with the EMPTY digest the settled
         writer itself renders for a pin whose entry publishes no
         archive (Doc B §5.3). Shape-valid by the §4.1 boundary''s own
         rule, so these locks read through it unchanged."
        <category: 'locks'>
        ^'#(''', aName, ''' ''', aVersionString, ''' #sha256 '''')'
    ]

    GrammarFixtures class >> outdatedLockString [
        "Both pins at their oldest published release, so both columns
         have somewhere to go."
        <category: 'locks'>
        ^self lockWithTuples: (Array
            with: (self tupleFor: 'kernel-lint' version: '1.0.0')
            with: (self tupleFor: 'kernel-text' version: '1.0.0'))
    ]

    GrammarFixtures class >> currentLockString [
        "kernel-solo at its only live release - nothing outdated, with a
         retired 2.0.0 one version number above it."
        <category: 'locks'>
        ^self lockWithTuples: (Array with:
            (self tupleFor: 'kernel-solo' version: '1.0.0'))
    ]

    GrammarFixtures class >> transitiveRootContents [
        "The §8 decision 82 root: it declares kernel-json and NOTHING
         ELSE, so the kernel-text release the lock also carries is
         there because kernel-json depends on it - a TRANSITIVE pin the
         operator never named and has no constraint over."
        <category: 'roots'>
        ^'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''kernel-json'' constraint: ''^0.3'' ]',
            SourceFixtures newline
    ]

    GrammarFixtures class >> transitiveLockString [
        "kernel-json at its newest live release - so the DECLARED pin is
         current and reports nothing - beside kernel-text stranded at
         1.0.0 while the index publishes 1.2.0 and 2.0.0.

         The declared pin is deliberately current: it leaves exactly one
         row in the answer, and that row is the transitive one, so the
         law cannot pass by accident on a neighbour's line."
        <category: 'locks'>
        ^self lockWithTuples: (Array
            with: (self tupleFor: 'kernel-json' version: '0.3.1')
            with: (self tupleFor: 'kernel-text' version: '1.0.0'))
    ]

    GrammarFixtures class >> transitiveWorkDirNamed: aLabel [
        <category: 'working dirs'>
        ^self workDirNamed: aLabel
            contents: self transitiveRootContents
            lock: self transitiveLockString
    ]

    GrammarFixtures class >> workDirNamed: aLabel contents: aContentsString lock: aLockString [
        "A working directory holding one Package.st and one parley.lock.
         Answers the path; the caller tracks it for RECURSIVE teardown."
        <category: 'working dirs'>
        | path |
        path := SourceFixtures directoryNamed: aLabel.
        ExecFixtures writePackage: aContentsString in: path.
        ExecFixtures writeLock: aLockString in: path.
        ^path
    ]

    GrammarFixtures class >> outdatedWorkDirNamed: aLabel [
        <category: 'working dirs'>
        ^self workDirNamed: aLabel
            contents: self outdatedRootContents
            lock: self outdatedLockString
    ]

    GrammarFixtures class >> currentWorkDirNamed: aLabel [
        <category: 'working dirs'>
        ^self workDirNamed: aLabel
            contents: self currentRootContents
            lock: self currentLockString
    ]

    "---- pinned renderings: search ----"

    GrammarFixtures class >> searchLineFor: aName version: aVersionString summary: aSummary [
        "One hit: the name, the latest version the index publishes that
         is not retired, and the summary, two spaces between columns."
        <category: 'pinned wordings'>
        ^aName, '  ', aVersionString, '  ', aSummary
    ]

    GrammarFixtures class >> kernelSearchLines [
        "Every hit for the term kernel over the grammar index, in sorted
         package-name order. kernel-json shows 0.3.1 rather than 0.3.2
         because 0.3.2 is retired and latest means the newest release an
         operator may actually take."
        <category: 'pinned wordings'>
        ^(Array
            with: (self searchLineFor: 'kernel-json' version: '0.3.1'
                summary: self jsonSummary)
            with: (self searchLineFor: 'kernel-lint' version: '2.0.0'
                summary: self lintSummary)),
            (Array
                with: (self searchLineFor: 'kernel-solo' version: '1.0.0'
                    summary: self soloSummary)
                with: (self searchLineFor: 'kernel-text' version: '2.0.0'
                    summary: self textSummary))
    ]

    GrammarFixtures class >> absentSearchTerm [
        <category: 'pinned wordings'>
        ^'zzz'
    ]

    GrammarFixtures class >> noMatchLineFor: aTerm [
        "No match is an ANSWER, not an error (§8 decision 57): one line
         naming the term and the index, at exit 0, exactly as apt,
         cargo, npm and gem all answer it."
        <category: 'pinned wordings'>
        ^'no package matching ', aTerm printString, ' in the configured index'
    ]

    GrammarFixtures class >> searchRefusalLine [
        "The §8 decision 80 refusal: the transport, why it cannot answer,
         and the flags that can - in the settled '<subject>: <cause> -
         <remedy>' grammar every other boundary uses. Exit 1 rather than
         2, because the argv is well formed and the transport is the
         limit."
        <category: 'pinned wordings'>
        ^'--index: a sparse index publishes one listing per package and no catalogue - use --source or --git to search'
    ]

    "---- pinned renderings: info ----"

    GrammarFixtures class >> infoNameLineFor: aName [
        <category: 'pinned wordings'>
        ^'name: ', aName
    ]

    GrammarFixtures class >> infoLatestLineFor: aVersionString [
        <category: 'pinned wordings'>
        ^'latest: ', aVersionString
    ]

    GrammarFixtures class >> infoSummaryLineFor: aSummary [
        <category: 'pinned wordings'>
        ^'summary: ', aSummary
    ]

    GrammarFixtures class >> infoAuthorLineFor: anAuthor [
        <category: 'pinned wordings'>
        ^'author: ', anAuthor
    ]

    GrammarFixtures class >> infoLicenseLineFor: aLicense [
        <category: 'pinned wordings'>
        ^'license: ', aLicense
    ]

    GrammarFixtures class >> infoDependenciesLineFor: aText [
        <category: 'pinned wordings'>
        ^'dependencies: ', aText
    ]

    GrammarFixtures class >> infoVersionsHeaderLine [
        <category: 'pinned wordings'>
        ^'versions:'
    ]

    GrammarFixtures class >> infoVersionLineFor: aVersionString [
        <category: 'pinned wordings'>
        ^'  ', aVersionString
    ]

    GrammarFixtures class >> infoRetiredVersionLineFor: aVersionString reason: aReason [
        "A retired release is LISTED and MARKED, never hidden: info
         reports what the index PUBLISHED, which is a different question
         from what resolution may select (Doc C §2)."
        <category: 'pinned wordings'>
        ^'  ', aVersionString, '  retired: ', aReason
    ]

    GrammarFixtures class >> jsonInfoLines [
        "Every field of kernel-json, in the order info renders them.
         Written out here as the whole answer, because S17''s claim is
         that EVERY declared field renders - a law asserting field by
         field could pass while the answer carried a tenth line nobody
         expected."
        <category: 'pinned wordings'>
        ^(Array
            with: (self infoNameLineFor: 'kernel-json')
            with: (self infoLatestLineFor: '0.3.1')
            with: (self infoSummaryLineFor: self jsonSummary)
            with: (self infoAuthorLineFor: self jsonAuthor)
            with: (self infoLicenseLineFor: self jsonLicense)),
            (Array
                with: (self infoDependenciesLineFor: 'kernel-text >=1.0.0 <2.0.0')
                with: self infoVersionsHeaderLine
                with: (self infoVersionLineFor: '0.3.1')
                with: (self infoRetiredVersionLineFor: '0.3.2'
                    reason: self json032Reason))
    ]

    GrammarFixtures class >> absentPackageName [
        <category: 'pinned wordings'>
        ^'kernel-nowhere'
    ]

    GrammarFixtures class >> notPublishedLineFor: aName [
        "The opposite case from search''s empty answer, and the reason
         the two exit codes differ: the operator ASSERTED a package
         exists and it does not, so this is exit 1 while no match is
         exit 0."
        <category: 'pinned wordings'>
        ^aName printString, ' is not published by the configured index'
    ]

    "---- pinned renderings: outdated ----"

    GrammarFixtures class >> outdatedLineFor: aName pinned: aPinned allowed: anAllowed published: aPublished [
        "One pin, TWO COLUMNS, labelled apart. `you can upgrade` and
         `you would have to widen your constraint` are different facts
         with different actions, so they are never merged into one
         arrow: allowed is the newest non-retired release the manifest''s
         constraint still admits, published is the newest non-retired
         release the index carries at all."
        <category: 'pinned wordings'>
        ^aName, ' ', aPinned, '  allowed ', anAllowed,
            '  published ', aPublished
    ]

    GrammarFixtures class >> outdatedLines [
        "The S15 answer, in sorted package-name order. kernel-lint moves
         in the published column ONLY - its constraint admits nothing
         newer - while kernel-text moves in both, and the two columns
         disagree for both packages. A build that reported one column
         answers half of this and passes nothing."
        <category: 'pinned wordings'>
        ^Array
            with: (self outdatedLineFor: 'kernel-lint' pinned: '1.0.0'
                allowed: '1.0.0' published: '2.0.0')
            with: (self outdatedLineFor: 'kernel-text' pinned: '1.0.0'
                allowed: '1.2.0' published: '2.0.0')
    ]

    GrammarFixtures class >> nothingOutdatedLine [
        "A fully current project answers a LINE, not silence - the
         resolve-with-no-dependencies precedent: a verb that prints
         nothing reads as a verb that did nothing."
        <category: 'pinned wordings'>
        ^'nothing is outdated - every pin is the newest the index publishes'
    ]

    "---- the sparse base trees (S13, S19 and S23) ----"

    GrammarFixtures class >> outsideClosureName [
        "A package the sparse index publishes that appears in NEITHER
         the manifest NOR the lock. info must reach it anyway, by
         seeding the queried name through the settled seededSourceAdding:
         - and a build that seeds only from manifest-plus-lock answers
         `not published` about a package the index publishes, which is
         §8 decision 80''s harm class one door down."
        <category: 'sparse trees'>
        ^'unrelated'
    ]

    GrammarFixtures class >> populateSparseBaseIn: aBasePath [
        "The settled two-level tree plus the package outside the
         closure, both through the settled SparseIndexFixtures builders
         so the sparse layout keeps one definition."
        <category: 'sparse trees'>
        SparseIndexFixtures populateTwoLevelTreeIn: aBasePath.
        SparseIndexFixtures addUnrelatedTo: aBasePath
    ]

    GrammarFixtures class >> sparseRootContents [
        "A root naming root-dep alone: the closure reaches root-dep and
         deep, and never unrelated."
        <category: 'sparse trees'>
        ^'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''root-dep'' constraint: ''^1.0'' ]',
            SourceFixtures newline
    ]

    GrammarFixtures class >> sparseWorkDirNamed: aLabel [
        "A sparse-index working directory with NO lock: the seed set is
         the manifest''s declared names alone, which is what makes the
         outside-the-closure package genuinely outside it."
        <category: 'sparse trees'>
        | path |
        path := SourceFixtures directoryNamed: aLabel.
        ExecFixtures writePackage: self sparseRootContents in: path.
        ^path
    ]

    GrammarFixtures class >> unrelatedInfoLines [
        "What info must answer for the package outside the closure. The
         settled SparseIndexFixtures entry builder writes an empty
         summary, author and license and one fileIn, so the fields
         render empty rather than absent - the shape is the claim here,
         not the metadata."
        <category: 'sparse trees'>
        ^(Array
            with: (self infoNameLineFor: self outsideClosureName)
            with: (self infoLatestLineFor: '1.0.0')
            with: (self infoSummaryLineFor: '')
            with: (self infoAuthorLineFor: '')
            with: (self infoLicenseLineFor: '')),
            (Array
                with: (self infoDependenciesLineFor: 'none')
                with: self infoVersionsHeaderLine
                with: (self infoVersionLineFor: '1.0.0'))
    ]

    "---- the git chatter half (S20-S22, finding F19) ----"

    GrammarFixtures class >> gitChatterMarkers [
        "Text the toolchain writes that Parley did not compose, as
         (description, needle) pairs. The cache-path needle is the
         directory Parley invented and the operator never chose, which
         is the half of F19 that is not merely noise: it names an
         implementation detail as if it were the operator''s business."
        <category: 'git chatter'>
        ^(Array
            with: #('git clone progress' 'Cloning into')
            with: #('git clone completion' 'done.')
            with: #('an unchanged pull' 'Already up to date.')),
            (Array
                with: #('a fast-forward header' 'Fast-forward')
                with: #('a diffstat' 'files changed')
                with: #('the invented cache path' '.parley/git/'))
    ]

    GrammarFixtures class >> gitFailureMarker [
        "What must STILL reach the operator when the transport really
         fails: silencing chatter must never silence failure."
        <category: 'git chatter'>
        ^'git command failed with exit code'
    ]

    GrammarFixtures class >> quietCloneCommandFor: aRepoPath cache: aCacheDir [
        "The composed clone line once F19 closes. Delegated to the
         settled PublishFixtures oracle, which is amended in RED, so the
         command line keeps ONE definition across the suite."
        <category: 'git chatter'>
        ^PublishFixtures cloneCommandFor: aRepoPath cache: aCacheDir
    ]

    GrammarFixtures class >> quietPullCommandFor: aCacheDir [
        <category: 'git chatter'>
        ^PublishFixtures pullCommandFor: aCacheDir
    ]

    GrammarFixtures class >> quietFlag [
        "The flag itself, asserted to be present in both composed lines
         by a law that does not restate either whole command - a law
         that only compared whole strings could not say WHICH half of
         the composition it was protecting."
        <category: 'git chatter'>
        ^'--quiet'
    ]
]

IndexSnapshot subclass: ReportingAccessorTrapSnapshot [

    <comment: 'The S14 companion double: a snapshot whose two REPORTING
accessors signal instead of answering. The resolver is a pure function
of (root manifest, snapshot) and these two accessors exist for verbs
that read and explain, so a resolution that completes through this
value has proved the resolver calls neither - mechanically, rather than
by reading the search loop and believing it. An edge double, never
domain: it overrides nothing the resolver uses.'>

    packageNames [
        <category: 'reporting accessors'>
        ^self error: ReportingAccessorTrapSnapshot trapMessage
    ]

    allVersionsOf: aName [
        <category: 'reporting accessors'>
        ^self error: ReportingAccessorTrapSnapshot trapMessage
    ]

    ReportingAccessorTrapSnapshot class >> trapMessage [
        <category: 'accessing'>
        ^'purity violated: the resolver consumed a reporting accessor'
    ]
]

Namespace current: Smalltalk.
