"Parley Sprint 10 — fixtures for the lock body/value boundary and the
 deserialization-boundary law (issue #12; Doc E §4.1, §4.2 and §5).

 This is the second of the sprint's two new support files. It carries
 one malformed lockfile per rejection ground, the pinned lock problems,
 the boundary-table oracle the drift law reads, and the S12
 operator-file corpus. The settled LockBoundaryFixtures /
 CommandLineFixtures / ExecFixtures / SourceFixtures / PublishFixtures /
 InstallFixtures helpers are reused UNCHANGED — in particular
 LockBoundaryFixtures lockProblemFor:message:, which is the settled
 three-part shape ('<path>: <defect> - run parley update to rewrite
 it'); the third rejection ground joins the two syntactic ones inside
 that shape rather than inventing a fourth voice.

 WHY THE THIRD GROUND EXISTS (§8 decision 35). The two settled grounds
 are syntactic: a lock that does not parse, and a lock that is not a
 #'parley-lock' 1 artifact. A lock that passes both and has a MALFORMED
 BODY — a missing #packages key, one hand-edit away — reached
 Resolution fromLockEntry: and died there as a KERNEL
 SystemExceptions.NotFound, answered with exit 70: 'this is a defect in
 Parley, not in your project.' The §4.2 closed-set law could not see it,
 because that law enumerates Parley error classes and this one is the
 kernel's. So the fix is not another error class; it is validating the
 shape before the constructor sees the value, and declaring every place
 Parley does that.

 THE BOUNDARY TABLE. CommandLine class >> deserializationBoundaries is
 a DECLARATION consumed twice, exactly as sourceFlags and
 diagnosedErrorClasses are: the drift law reads it against the senders
 of IndexEntryReader readFrom: in src/, and the per-boundary laws
 iterate it to drive one malformed input through each. The enumeration
 walks src/ SUBDIRECTORIES, and 3.2.5's File>>files answers regular
 files only and never recurses — so readerSenderNamesIn: uses namesDo:,
 and probeSenderFileNames records what the toolchain actually answered
 when this fixture was written.

 Filesystem discipline (as Sprints 4-9): every fixture path lives under
 tmp/, unique per test, removed recursively in tearDown through
 ExecFixtures removeTree:; tmp/ is empty or absent after a clean run.
 The developer image is never mutated and no network is contacted.

 Pinned wording decisions (posted on issue #12 for confirmation) live
 in the methods: lockPairingProblemFor: and its six siblings — the lock
 body/value defects, worded in the grammar the settled DirectorySource
 schema problems already use, because an operator repairing a file
 should hear one voice whichever file it is."

Namespace current: Parley.

Object subclass: LockSchemaFixtures [

    <comment: 'Class-side factory for Sprint 10 lock-schema fixtures:
malformed lockfile contents (one per rejection ground), the pinned
LockError problems, the deserialization-boundary table oracle and its
src/ sender enumeration, and the S12 operator-file corpus. Stateless;
uniqueness comes from per-test labels.'>

    "---- malformed lockfile contents, one per rejection ground ----"

    LockSchemaFixtures class >> malformedBodyLockContents [
        "THE S9 REPRODUCTION, verbatim from the Sprint 9 close-out: right
         tag, right format version, no #packages. It parses, it is a
         lock, and it is not one Parley can read."
        <category: 'malformed locks'>
        ^'#(#''parley-lock'' 1 #root ''my-app'')', SourceFixtures newline
    ]

    LockSchemaFixtures class >> unpairedBodyLockContents [
        "A key with no value: the body does not pair up."
        <category: 'malformed locks'>
        ^'#(#''parley-lock'' 1 #root ''my-app'' #packages)',
            SourceFixtures newline
    ]

    LockSchemaFixtures class >> unknownKeyLockContents [
        <category: 'malformed locks'>
        ^'#(#''parley-lock'' 1 #root ''my-app'' #packages #() #notes ''hello'')',
            SourceFixtures newline
    ]

    LockSchemaFixtures class >> keysOutOfOrderLockContents [
        "Both keys present, in the wrong order — §5.4 rule 2 fixes the
         order, and a lock Parley writes always has it."
        <category: 'malformed locks'>
        ^'#(#''parley-lock'' 1 #packages #() #root ''my-app'')',
            SourceFixtures newline
    ]

    LockSchemaFixtures class >> nonStringRootLockContents [
        <category: 'malformed locks'>
        ^'#(#''parley-lock'' 1 #root #myapp #packages #())',
            SourceFixtures newline
    ]

    LockSchemaFixtures class >> nonArrayPackagesLockContents [
        <category: 'malformed locks'>
        ^'#(#''parley-lock'' 1 #root ''my-app'' #packages ''none'')',
            SourceFixtures newline
    ]

    LockSchemaFixtures class >> shortTupleLockContents [
        "A package tuple of the wrong arity."
        <category: 'malformed locks'>
        ^'#(#''parley-lock'' 1 #root ''my-app'' #packages #(#(''c'' ''2.4.0'')))',
            SourceFixtures newline
    ]

    LockSchemaFixtures class >> missingMarkerLockContents [
        "Four elements, but the third is not the literal #sha256."
        <category: 'malformed locks'>
        ^'#(#''parley-lock'' 1 #root ''my-app'' #packages #(#(''c'' ''2.4.0'' #shazam ''abcd000000000000000000000000000000000000000000000000000000000000'')))',
            SourceFixtures newline
    ]

    LockSchemaFixtures class >> nonStringFieldLockContents [
        "A Symbol where the schema fixes a String. In 3.2.5 Symbol is a
         String subclass and the two are distinct literals in the
         micro-format grammar — the distinction the settled entry
         validation already draws."
        <category: 'malformed locks'>
        ^'#(#''parley-lock'' 1 #root ''my-app'' #packages #(#(#c ''2.4.0'' #sha256 ''abcd000000000000000000000000000000000000000000000000000000000000'')))',
            SourceFixtures newline
    ]

    LockSchemaFixtures class >> unparseableVersionLockContents [
        "THE S10 LOCK: correct in every key, order and tuple arity, and
         one version means nothing. A shape check never asks whether a
         string MEANS anything (Doc F §4.1), and the settled
         Version fromString: is what decides."
        <category: 'malformed locks'>
        ^'#(#''parley-lock'' 1 #root ''my-app'' #packages #(#(''c'' ''banana'' #sha256 ''abcd000000000000000000000000000000000000000000000000000000000000'')))',
            SourceFixtures newline
    ]

    LockSchemaFixtures class >> unparseableVersionValue [
        <category: 'malformed locks'>
        ^'banana'
    ]

    LockSchemaFixtures class >> unparseableVersionPackage [
        <category: 'malformed locks'>
        ^'c'
    ]

    "---- pinned lock body/value problems (posted on issue #12) ----"

    LockSchemaFixtures class >> lockKeyOrderText [
        "The fixed key order rendered for a problem, in the grammar of
         the settled DirectorySource schemaKeyOrderText."
        <category: 'pinned wordings'>
        ^'#root #packages'
    ]

    LockSchemaFixtures class >> lockProblemFor: aPath defect: aDefect [
        "Private — the settled three-part shape, reused unchanged: the
         lock PATH (which file), the defect (what is wrong), and
         parley update (what to do). The third rejection ground is a new
         ground, not a new voice."
        <category: 'pinned wordings'>
        ^LockBoundaryFixtures lockProblemFor: aPath message: aDefect
    ]

    LockSchemaFixtures class >> lockPairingProblemFor: aPath [
        <category: 'pinned wordings'>
        ^self lockProblemFor: aPath defect:
            'malformed lock - the schema keys and values do not pair up'
    ]

    LockSchemaFixtures class >> missingLockKeyProblemFor: aPath key: aSymbol [
        <category: 'pinned wordings'>
        ^self lockProblemFor: aPath defect:
            'missing schema key ', aSymbol printString,
            ' - the fixed key order is ', self lockKeyOrderText
    ]

    LockSchemaFixtures class >> unknownLockKeyProblemFor: aPath key: aSymbol [
        <category: 'pinned wordings'>
        ^self lockProblemFor: aPath defect:
            'unknown schema key ', aSymbol printString,
            ' - the fixed key order is ', self lockKeyOrderText
    ]

    LockSchemaFixtures class >> lockKeyOrderProblemFor: aPath [
        <category: 'pinned wordings'>
        ^self lockProblemFor: aPath defect:
            'schema keys out of order - the fixed key order is ',
            self lockKeyOrderText
    ]

    LockSchemaFixtures class >> lockRootKindProblemFor: aPath [
        <category: 'pinned wordings'>
        ^self lockProblemFor: aPath defect: '#root must be a string'
    ]

    LockSchemaFixtures class >> lockPackagesKindProblemFor: aPath [
        "One wording for every structural defect of #packages — not an
         Array, a tuple of the wrong arity, a missing #sha256 marker, a
         non-String field. They are one question and one repair, and the
         settled #dependencies and #archive problems are worded on
         exactly this principle."
        <category: 'pinned wordings'>
        ^self lockProblemFor: aPath defect:
            '#packages must be an array of #(<name> <version> #sha256 <hex digest>) tuples'
    ]

    LockSchemaFixtures class >> unparseableLockVersionProblemFor: aPath value: aString package: aName [
        <category: 'pinned wordings'>
        ^self lockProblemFor: aPath defect:
            '#packages version ', aString printString,
            ' for ', aName printString, ' does not parse as a version'
    ]

    LockSchemaFixtures class >> malformedLockRows [
        "The corpus as (contents, problem-builder) rows, so one law walks
         every rejection ground and no ground can be forgotten. The
         second element is a one-argument block taking the lock path,
         because every problem names the operator's own file."
        <category: 'malformed locks'>
        ^(Array
            with: (Array with: self unpairedBodyLockContents
                with: [:path | self lockPairingProblemFor: path])
            with: (Array with: self malformedBodyLockContents
                with: [:path | self missingLockKeyProblemFor: path
                    key: #packages])
            with: (Array with: self unknownKeyLockContents
                with: [:path | self unknownLockKeyProblemFor: path
                    key: #notes])
            with: (Array with: self keysOutOfOrderLockContents
                with: [:path | self lockKeyOrderProblemFor: path])),
            (Array
                with: (Array with: self nonStringRootLockContents
                    with: [:path | self lockRootKindProblemFor: path])
                with: (Array with: self nonArrayPackagesLockContents
                    with: [:path | self lockPackagesKindProblemFor: path])
                with: (Array with: self shortTupleLockContents
                    with: [:path | self lockPackagesKindProblemFor: path])
                with: (Array with: self missingMarkerLockContents
                    with: [:path | self lockPackagesKindProblemFor: path])
                with: (Array with: self nonStringFieldLockContents
                    with: [:path | self lockPackagesKindProblemFor: path])),
            (Array
                with: (Array with: InspectionFixtures malformedDigestLockString
                    with: [:path |
                        InspectionFixtures malformedLockDigestProblemFor: path]))
    ]

    "---- the deserialization-boundary table (Doc E §4.2) ----"

    LockSchemaFixtures class >> boundaryClassNames [
        "The five declared boundaries, sorted. Four are senders of
         IndexEntryReader readFrom: — the CLI's parley.lock read, the
         DirectorySource scan (which, from Sprint 10, also reads
         retirement records through the same sender, so the new schema
         is covered the moment it exists), from Sprint 14 the
         SparseIndexSource listing read, and from Sprint 15 the
         Publisher's read of the listing it is about to rewrite (Doc F
         §8.2 — publishing into an index that already holds the package
         means reading its versions.st first). The fifth, ManifestFile,
         is declared alongside them because it reads an
         operator-editable file by a DIFFERENT mechanism (file-in, not
         the reader) and is exactly the kind of boundary a
         reader-anchored enumeration would otherwise miss.

         The two listing readers are the same file kind read from
         opposite ends of the ecosystem, and each names it the way ITS
         operator can act on: the client by base-relative URL path, the
         publisher by the destination path the author typed.

         SPRINT 19 ADDS THE SIXTH, AND IT IS THE FIFTH SENDER OF THE
         READER: Configuration reads the operator's own
         parley.config.st, at the project root, under the new
         #'parley-config' 1 schema (Doc B §5.7). A new operator-editable
         file is two declarations and not one — this table and the path
         boundary table — and a row missing from either is a drift law
         that cannot see the boundary.

         SORTED THE WAY 3.2.5 SORTS IT: String <= folds case, so
         'CLI' still comes before 'Configuration' (cl before co). Taken
         from the toolchain rather than read off the page (finding
         F15)."
        <category: 'boundary table'>
        ^#('CLI' 'Configuration' 'DirectorySource' 'ManifestFile'
            'Publisher' 'SparseIndexSource')
    ]

    LockSchemaFixtures class >> boundaryFileFor: aClassName [
        "The operator-editable file each boundary reads — the second
         column of the table, and the reason each row is a boundary at
         all. A row that cannot name the operator's file is not a
         boundary; it is a reader."
        <category: 'boundary table'>
        aClassName = 'CLI' ifTrue: [^'parley.lock'].
        aClassName = 'Configuration' ifTrue: [^'parley.config.st'].
        aClassName = 'DirectorySource'
            ifTrue: [^'index entries and retirement records'].
        aClassName = 'ManifestFile' ifTrue: [^'Package.st'].
        aClassName = 'SparseIndexSource' ifTrue: [^'version listings'].
        aClassName = 'Publisher' ifTrue: [^'version listings'].
        ^nil
    ]

    LockSchemaFixtures class >> namesOfBoundaryClassesIn: aTable [
        "The class-name column of CommandLine class >>
         deserializationBoundaries, sorted, as Strings (3.2.5's
         Class>>name answers a Symbol)."
        <category: 'boundary table'>
        ^((aTable collect: [:row | (row at: 1) name asString])
            asSortedCollection: [:a :b | a <= b]) asArray
    ]

    LockSchemaFixtures class >> boundaryFilesIn: aTable [
        "The declared operator file of each row, paired with its class
         name so a law can assert the PAIRING and not only the names."
        <category: 'boundary table'>
        ^((aTable collect: [:row |
            (row at: 1) name asString, ' -> ', (row at: 2)])
                asSortedCollection: [:a :b | a <= b]) asArray
    ]

    LockSchemaFixtures class >> boundaryPairings [
        "The oracle for the same pairing, built from the two methods
         above so the fixture cannot claim a file the table does not."
        <category: 'boundary table'>
        ^(self boundaryClassNames collect: [:each |
            each, ' -> ', (self boundaryFileFor: each)]) asArray
    ]

    LockSchemaFixtures class >> tableWithout: aClassName in: aTable [
        "aTable with one row removed — the mutant the drift law is run
         against, so the law demonstrates that it DETECTS drift. A drift
         law that has never failed on purpose is a law about nothing."
        <category: 'boundary table'>
        ^aTable reject: [:row | (row at: 1) name asString = aClassName]
    ]

    "---- the src/ sender enumeration (the drift law's other half) ----"

    LockSchemaFixtures class >> readerSendSource [
        "The anchor: IndexEntryReader readFrom: is the SINGLE
         literals-only parser, so every sender of it in src/ is a
         deserialization boundary by construction."
        <category: 'drift law'>
        ^'IndexEntryReader readFrom:'
    ]

    LockSchemaFixtures class >> codeOf: aSourceString [
        "aSourceString with its Smalltalk COMMENTS and STRING LITERALS
         removed, so a search over it finds SENDS and not prose.

         Doc E §4.2 anchors the enumeration on senders of the reader,
         and a method comment that NAMES the send is not one. FOUND IN
         GREEN, by the law written to prevent exactly this class of
         mistake: CommandLine's own deserializationBoundaries comment
         quotes the send it is about, so the RED-phase raw-text search
         reported CommandLine as a third sender —
         testTheEnumerationSeesTheRealSenders failed and named it. The
         alternative fix was to contort the comment so it never spells
         the send, which would leave the next writer of an honest
         comment breaking a drift law for no reason.

         A character literal is consumed whole, so a quote character
         that is a VALUE rather than a delimiter never opens a literal
         region — the settled IndexEntryReader is full of them."
        <category: 'drift law'>
        | out stream ch |
        out := WriteStream on: String new.
        stream := ReadStream on: aSourceString.
        [stream atEnd] whileFalse: [
            ch := stream next.
            ch = $$
                ifTrue: [
                    out nextPut: ch.
                    stream atEnd ifFalse: [out nextPut: stream next]]
                ifFalse: [
                    (ch = $" or: [ch = $'])
                        ifTrue: [self skipLiteral: ch on: stream]
                        ifFalse: [out nextPut: ch]]].
        ^out contents
    ]

    LockSchemaFixtures class >> skipLiteral: aDelimiter on: aStream [
        "Private — consume up to and including the closing delimiter,
         honouring the doubled-delimiter escape both literal kinds use."
        <category: 'drift law'>
        | ch |
        [aStream atEnd] whileFalse: [
            ch := aStream next.
            ch = aDelimiter ifTrue: [
                (aStream atEnd not and: [aStream peek = aDelimiter])
                    ifTrue: [aStream next]
                    ifFalse: [^self]]]
    ]

    LockSchemaFixtures class >> srcSubdirectoryNames [
        "Every existing subdirectory of src/, sorted — the settled
         CommandLineFixtures enumeration, reused so both drift laws walk
         the same tree."
        <category: 'drift law'>
        ^CommandLineFixtures srcSubdirectoryNames
    ]

    LockSchemaFixtures class >> readerSenderFileNames [
        "Every .st file under src/ whose SOURCE TEXT sends
         IndexEntryReader readFrom:, as '<dir>/<file>', sorted —
         delegating to the parameterized walk so the S13 law can drive
         the SAME code path over a fabricated tree under tmp/.

         PROBED against the toolchain: the walk answers
         probeSenderFileNames, while
         (File name: 'src') files answers (). probeSenderFileNames
         records that answer, and
         testTheEnumerationSeesTheRealSenders holds this method to it."
        <category: 'drift law'>
        ^self readerSenderFileNamesUnder: 'src'
            subdirectories: self srcSubdirectoryNames
    ]

    LockSchemaFixtures class >> readerSenderFileNamesUnder: aRootPath subdirectories: someDirNames [
        "Every .st file under aRootPath/<dir> for each of someDirNames
         whose source text sends IndexEntryReader readFrom:, as
         '<dir>/<file>', sorted.

         3.2.5's File>>files answers REGULAR FILES ONLY and never
         recurses, so a walk written the obvious way sees NOTHING and
         the drift law passes vacuously — the trap that bit Sprint 8's
         bin/ law. namesDo: is the enumeration that sees directory
         entries (it also yields '.' and '..', which are filtered).

         The search runs over normalizedCodeOf: the file, never its
         raw text: a comment that names the send is not a sender (one
         such comment exists — CommandLine's own boundary-table
         declaration), and a sender whose receiver and selector are
         split across a line break is still a sender (§8 decision 43;
         the Sprint 10 walk matched one stripped line at a time and a
         legal reformat vanished from it).

         BOUNDED CLAIM (decision 38, corrected): this is a TEXTUAL
         search, hardened against whitespace. Reflective sender
         enumeration does not exist on 3.2.5 — whichSelectorsReferTo:
         searches a method's literals, not its send bytecodes — so a
         send assembled by perform: or interrupted by a comment
         between receiver and selector stays invisible. The law claims
         whitespace-robustness, nothing stronger."
        <category: 'drift law'>
        | names |
        names := OrderedCollection new.
        someDirNames do: [:dirName |
            (File name: aRootPath, '/', dirName) namesDo: [:fileName |
                ((fileName endsWith: '.st') and: [
                    self does: (self normalizedCodeOf:
                        (File name: aRootPath, '/', dirName, '/',
                            fileName) contents)
                        include: self readerSendSource])
                    ifTrue: [names add: dirName, '/', fileName]]].
        ^(names asSortedCollection: [:a :b | a <= b]) asArray
    ]

    LockSchemaFixtures class >> normalizedCodeOf: aSourceString [
        "codeOf: aSourceString with every run of whitespace collapsed
         to one space, so a send split across a line break reads as
         contiguous text (§8 decision 43)."
        <category: 'drift law'>
        | out stream ch pendingSpace started |
        out := WriteStream on: String new.
        stream := ReadStream on: (self codeOf: aSourceString).
        pendingSpace := false.
        started := false.
        [stream atEnd] whileFalse: [
            ch := stream next.
            ch isSeparator
                ifTrue: [pendingSpace := true]
                ifFalse: [
                    (pendingSpace and: [started])
                        ifTrue: [out nextPut: Character space].
                    pendingSpace := false.
                    started := true.
                    out nextPut: ch]].
        ^out contents
    ]

    LockSchemaFixtures class >> readerSenderClassNames [
        "The senders as class names: a src/ file is named for the class
         it defines, and both senders are. Sorted, as Strings."
        <category: 'drift law'>
        ^((self readerSenderFileNames collect: [:each |
            | base |
            base := each copyFrom: (each indexOf: $/) + 1 to: each size.
            base copyFrom: 1 to: base size - 3])
                asSortedCollection: [:a :b | a <= b]) asArray
    ]

    LockSchemaFixtures class >> probeSenderFileNames [
        "What the toolchain answered for readerSenderFileNames when this
         fixture was written — the fixture-correctness oracle. If a
         future sender lands, this list and the table both have to move,
         which is the point.

         SPRINT 19 IS THAT FUTURE SENDER, and the pair moved together:
         Configuration reads parley.config.st through the settled reader
         (Doc B §5.7), so it is a boundary by construction and the drift
         law forced the row the moment the send shipped. Sorted the way
         3.2.5 sorts, which folds case: exec/CLI.st still precedes
         exec/Configuration.st."
        <category: 'drift law'>
        ^#('exec/CLI.st' 'exec/Configuration.st' 'publish/Publisher.st'
            'source/DirectorySource.st' 'source/SparseIndexSource.st')
    ]

    LockSchemaFixtures class >> undeclaredSendersIn: aTable [
        "Every reader sender the table does not declare — the drift
         law's comparison, extracted so the law can run it TWICE: once
         against the real table (must be empty) and once against a table
         with a row removed (must not be)."
        <category: 'drift law'>
        | declared |
        declared := self namesOfBoundaryClassesIn: aTable.
        ^self readerSenderClassNames
            reject: [:each | declared includes: each]
    ]

    LockSchemaFixtures class >> does: aString include: aSubstring [
        "Private — substring containment, through the settled helper."
        <category: 'drift law'>
        ^CommandLineFixtures does: aString include: aSubstring
    ]

    "---- the S12 operator-file corpus ----"

    LockSchemaFixtures class >> operatorFileCorpusLabels [
        "Every operator-editable input Parley has, named. S12 drives each
         through a real verb and through the shipped binary, and asserts
         that NONE answers exit 70, prints a backtrace, or blames Parley.
         The list is the sprint's exit criterion written down: three lock
         grounds, two index-artifact kinds, three Package.st kinds."
        <category: 'operator corpus'>
        ^#('malformed-body lock' 'unparseable lock' 'wrong-tag lock'
           'malformed entry' 'malformed retirement record'
           'vocabulary typo' 'invalid declarations' 'missing Package.st')
    ]

    LockSchemaFixtures class >> writeLockContents: aString in: aWorkDir [
        "The settled helper, restated so a Sprint 10 law reads one
         fixture class."
        <category: 'operator corpus'>
        LockBoundaryFixtures writeLockContents: aString in: aWorkDir
    ]
]

Namespace current: Smalltalk.
