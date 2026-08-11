"Parley Sprint 19 — fixtures for the configuration half (issue #21;
 Doc B §5.7, Doc E §4.1/§4.2, §8 decisions 64 and 65).

 THE FILE THIS HALF ADDS. --source, --git and --index are retyped on
 every command, and nothing records the choice. parley.config.st is the
 operator's own file, at the PROJECT ROOT beside Package.st and
 parley.lock — deliberately not under .parley/, which is regenerable
 state a user may delete to clean a project (§8 decision 64).

 IT IS THE SETTLED MICRO-FORMAT AND THE SETTLED READER. No third-party
 serialization, ever (Doc B §2.4), and no second reader — a second
 reader would give one malformed file a second wording. The tag joins
 IndexEntryReader class >> formatTags as a DECLARED settled-class
 exception (the Sprint 10 / Sprint 14 precedent), which is why
 ConfigurationTest pins the widened rejection sentence too.

 THE BODY RULE, AS DOC B §5.7 STATES IT: all three declared keys
 present — #source #git #index, in that order — values Strings, the
 empty string recording absence exactly as §5.3 records an absent
 digest. A malformed body is a missing, misordered or unknown key, a
 non-String value, OR MORE THAN ONE NON-EMPTY SOURCE KEY. The last is
 refused in the settled mutually-exclusive shape rather than silently
 preferred: the flag grammar already answers --source with --git as a
 usage error, because silently preferring one would make a typo look
 like a working command, and a file that can be edited in silence has
 more need of that rule than a command line does, not less.

 FIVE HOSTILE SHAPES, NOT FOUR. Decision 65 names four (not a regular
 readable file, does not parse, wrong tag, malformed body); the
 two-source file is the SECOND malformed-body shape and is driven
 separately, because it is the one a reader would guess is a precedence
 question rather than a body defect.

 THE PINNED WORDINGS LIVE IN THE METHODS BELOW and are hand-written
 here rather than obtained from the code that will compose them — an
 oracle taken from the code under test proves only that the code equals
 itself. Every one opens with the path, states a cause that was checked,
 and offers the SAME remedy: fix it or remove it and try again. One
 remedy for all five is decision 58 rather than laziness — removing the
 file always works (Parley falls back to the flags it always had) and
 fixing it always works, for every one of the five states, and no
 Parley verb writes a config, so no verb can be named as the repair the
 way parley update repairs a lock.

 Every fixture path is under tmp/, unique per test via a label, and
 removed recursively by the caller's tearDown through
 PathFixtures removeTree:, which unlocks the tree first."

Namespace current: Parley.

Object subclass: ConfigFixtures [

    <comment: 'Class-side factory for the Sprint 19 configuration
fixtures: the well-formed file for each declared flag, the five hostile
shapes, the pinned diagnosis wordings, the declared key oracle, and the
enumeration of malformed drivers that both the law suite and the
acceptance suite iterate. Stateless; uniqueness comes from per-test
labels.'>

    "---- the file, and where it lives ----"

    ConfigFixtures class >> fileName [
        "AT THE PROJECT ROOT (§8 decision 64), never under .parley/.
         S12 is the scenario that holds it there: an operator may delete
         .parley entirely to clean a project, and a configuration file
         inside the disposable directory is how a tool eventually tells
         a user to delete their own settings."
        <category: 'the file'>
        ^'parley.config.st'
    ]

    ConfigFixtures class >> pathIn: aWorkDir [
        <category: 'the file'>
        ^aWorkDir, '/', self fileName
    ]

    ConfigFixtures class >> write: aContentsString in: aWorkDir [
        <category: 'the file'>
        SourceFixtures write: aContentsString
            toFile: self fileName in: aWorkDir
    ]

    ConfigFixtures class >> declaredKeys [
        "The body''s three keys, in Doc B §5.7''s fixed order — which is
         the settled sourceFlags order with the -- stripped. Declared
         here as the hand-written oracle; ConfigurationTest asserts the
         implementation''s own keys against the SETTLED FLAG TABLE, so
         neither this list nor the class can drift from the grammar."
        <category: 'the file'>
        ^#(#source #git #index)
    ]

    "---- the well-formed bodies ----"

    ConfigFixtures class >> contentsWithSource: aSource git: aRepo index: aBase [
        "The canonical rendering: the tag and format version, then all
         three keys in the fixed order, values Strings, the empty string
         recording absence. One line, single spaces, single trailing
         newline — Doc B §5.4 rules 1, 2 and 5."
        <category: 'well-formed bodies'>
        ^'#(#''parley-config'' 1 #source ''', aSource,
            ''' #git ''', aRepo, ''' #index ''', aBase, ''')',
            SourceFixtures newline
    ]

    ConfigFixtures class >> contentsDeclaring: aFlagString value: aValueString [
        "The file an operator writes to record ONE source: the flag''s
         own key carries the value and the other two record absence.
         Driven for all three declared flags by S9, so no flag can be
         honoured by accident of being first."
        <category: 'well-formed bodies'>
        aFlagString = '--source' ifTrue: [
            ^self contentsWithSource: aValueString git: '' index: ''].
        aFlagString = '--git' ifTrue: [
            ^self contentsWithSource: '' git: aValueString index: ''].
        aFlagString = '--index' ifTrue: [
            ^self contentsWithSource: '' git: '' index: aValueString].
        ^self error: 'no declared source flag named ', aFlagString
    ]

    ConfigFixtures class >> emptyContents [
        "A well-formed file that declares NOTHING — every key present,
         every value the empty string. It is not malformed and it is not
         a source: the operator wrote the file and left it blank, and
         the verb behaves exactly as it does with no file at all."
        <category: 'well-formed bodies'>
        ^self contentsWithSource: '' git: '' index: ''
    ]

    "---- the five hostile shapes ----"

    ConfigFixtures class >> unparseableContents [
        "SHAPE 2 — it does not parse: an unterminated array. Unlike the
         authoring boundary''s unparseable manifest, this one is SAFE to
         drive in-image: it is read by the literals-only reader, which
         answers a positioned Parley error, and the C-level parser never
         sees it. Nothing here can put the phrase the red gate greps for
         into the suite''s own output."
        <category: 'hostile shapes'>
        ^'#(#''parley-config'' 1 #source ''../idx''', SourceFixtures newline
    ]

    ConfigFixtures class >> wrongTagContents [
        "SHAPE 3 — a well-formed artifact of the wrong kind. An index
         entry copied into the config''s name is the realistic mistake,
         and it parses perfectly."
        <category: 'hostile shapes'>
        ^'#(#''parley-index'' 1 #name ''demo'')', SourceFixtures newline
    ]

    ConfigFixtures class >> missingKeyContents [
        "SHAPE 4a — a malformed body: #index is absent. The keys that
         are present are spelled right and in order, which is exactly
         why the check is over the WHOLE key list and not over
         membership."
        <category: 'hostile shapes'>
        ^'#(#''parley-config'' 1 #source ''../idx'' #git '''')',
            SourceFixtures newline
    ]

    ConfigFixtures class >> misorderedKeyContents [
        "SHAPE 4b — every key present, two of them swapped. Doc B §5.4
         rule 2 fixes the ORDER as well as the set, and a body check
         that only asked about membership would wave this through."
        <category: 'hostile shapes'>
        ^'#(#''parley-config'' 1 #git '''' #source ''../idx'' #index '''')',
            SourceFixtures newline
    ]

    ConfigFixtures class >> unknownKeyContents [
        "SHAPE 4c — a key nobody declared, in the right place. The
         operator guessed a spelling, and a boundary that ignored
         unknown keys would answer silence to a file that says something
         Parley will never act on."
        <category: 'hostile shapes'>
        ^'#(#''parley-config'' 1 #source ''../idx'' #git '''' #registry '''')',
            SourceFixtures newline
    ]

    ConfigFixtures class >> nonStringValueContents [
        "SHAPE 4d — the keys are right and a VALUE is not a String. The
         Doc F §4.1 lesson one level down: a shape check that never asks
         what a value IS hands an Integer to a source constructor."
        <category: 'hostile shapes'>
        ^'#(#''parley-config'' 1 #source 7 #git '''' #index '''')',
            SourceFixtures newline
    ]

    ConfigFixtures class >> twoSourceContents [
        "SHAPE 5 — the body is schema-perfect and declares TWO sources.
         Refused, in the settled mutually-exclusive shape: the flag
         grammar answers --source with --git as an error rather than
         preferring one, because a silent preference makes a typo look
         like a working command. The file has more need of that rule
         than the command line, because nobody retypes it."
        <category: 'hostile shapes'>
        ^self contentsWithSource: '../idx' git: 'git@example.com:me/i.git'
            index: ''
    ]

    "---- the pinned wordings (posted on issue #21 at the RED review) ----"

    ConfigFixtures class >> remedy [
        "THE ONE REMEDY EVERY CONFIG DIAGNOSIS OFFERS, and it is checked
         for all five states (§8 decision 58). Removing the file always
         works — the tool falls back to the flags it has always had —
         and fixing it always works. No verb is named, because NO PARLEY
         VERB WRITES A CONFIG: naming one would be the loop decision 58
         caught next door, where the corrupt-lock remedy named the verb
         that answers the same refusal."
        <category: 'pinned wordings'>
        ^'fix it or remove it and try again'
    ]

    ConfigFixtures class >> lineFor: aPath saying: aCauseString [
        "The settled '<path>: <cause> - <remedy>' grammar (§8 decision
         73): opens with the path, states a cause, offers the remedy."
        <category: 'pinned wordings'>
        ^aPath, ': ', aCauseString, ' - ', self remedy
    ]

    ConfigFixtures class >> unreadableLineFor: aPath [
        "SHAPE 1''s line. The cause names the PREDICATE that failed
         rather than guessing which way it failed — a directory, a
         device node, a file whose permissions deny the reader — because
         one sentence covers all of them and none is a different repair.
         The settled parley.lock readability line is the model."
        <category: 'pinned wordings'>
        ^self lineFor: aPath saying: 'not a regular readable file'
    ]

    ConfigFixtures class >> parseFailureLineFor: aPath reason: aReaderMessage [
        "SHAPE 2''s line. The reader''s own message travels VERBATIM: it
         names a character position, and on a hand-edited file that
         position is the operator''s only handle, so paraphrasing it
         would throw away the one thing that makes the line actionable.
         The settled lock boundary carries the reader''s message the
         same way."
        <category: 'pinned wordings'>
        ^self lineFor: aPath saying: aReaderMessage
    ]

    ConfigFixtures class >> wrongTagLineFor: aPath tag: aSymbol [
        "SHAPE 3''s line, in the settled wrong-tag shape the lock
         boundary uses: the offending tag, then what this file holds."
        <category: 'pinned wordings'>
        ^self lineFor: aPath
            saying: 'wrong artifact tag ', aSymbol printString, ', ',
                self fileName, ' holds only #''parley-config'' 1 artifacts'
    ]

    ConfigFixtures class >> malformedKeysLineFor: aPath [
        "SHAPE 4a-c''s line: one sentence for every way the key list can
         be wrong, because the repair is the same and the operator is
         fixing one file, not auditing it (§8 decision 44''s split — a
         report on one file names its first defect)."
        <category: 'pinned wordings'>
        ^self lineFor: aPath
            saying: 'malformed configuration, the keys must be ',
                self keyOrderText, ' in that order'
    ]

    ConfigFixtures class >> malformedValueLineFor: aPath [
        "SHAPE 4d''s line."
        <category: 'pinned wordings'>
        ^self lineFor: aPath
            saying: 'malformed configuration, every value must be a String'
    ]

    ConfigFixtures class >> twoSourceLineFor: aPath first: aFirstKey second: aSecondKey [
        "SHAPE 5''s line. It names BOTH keys, because the operator has to
         know which two to choose between, and it states the rule rather
         than only the violation."
        <category: 'pinned wordings'>
        ^self lineFor: aPath
            saying: aFirstKey printString, ' and ', aSecondKey printString,
                ' are both declared, ', self fileName,
                ' declares at most one source'
    ]

    ConfigFixtures class >> keyOrderText [
        "The declared key order rendered for a diagnosis, derived from
         the key list so the sentence and the check cannot drift — the
         settled lockKeyOrderText shape."
        <category: 'pinned wordings'>
        | out |
        out := WriteStream on: String new.
        self declaredKeys
            do: [:each | out nextPutAll: each printString]
            separatedBy: [out nextPut: Character space].
        ^out contents
    ]

    "---- the hostile shapes as ONE enumeration ----"

    ConfigFixtures class >> hostileShapesTracking: track labelled: aPrefix [
        "EVERY WAY A parley.config.st CAN BE WRONG, as one enumeration:
         the label, the working directory, the config path, and the line
         the boundary owes.

         ONE ENUMERATION RATHER THAN TWO, because two enumerations of
         one family is the defect the relational inventory records as
         row 22 — each correct alone and wrong with respect to the other,
         with nothing comparing them. ConfigurationTest and the
         acceptance suite's S10 both iterate this.

         THE PARSE SHAPE'S EXPECTED LINE IS COMPOSED WITH THE READER'S
         OWN MESSAGE, obtained by asking the settled reader to read the
         same bytes. That is not an oracle from the code under test: the
         reader is SETTLED and is not what this sprint changes, and its
         message is the part of the line the boundary is required to
         carry verbatim rather than to invent."
        <category: 'hostile shapes'>
        | rows |
        rows := OrderedCollection new.
        rows add: (self shapeRow: 'a directory'
            in: (self directoryShapedWorkDirTracking: track
                named: aPrefix, '-directory')
            line: [:path | self unreadableLineFor: path]).
        rows add: (self shapeRow: 'an unparseable file'
            in: (self workDirTracking: track named: aPrefix, '-unparseable'
                contents: self unparseableContents)
            line: [:path | self parseFailureLineFor: path
                reason: (self readerMessageFor: self unparseableContents)]).
        rows add: (self shapeRow: 'the wrong artifact tag'
            in: (self workDirTracking: track named: aPrefix, '-wrongtag'
                contents: self wrongTagContents)
            line: [:path | self wrongTagLineFor: path
                tag: #'parley-index']).
        rows add: (self shapeRow: 'a missing key'
            in: (self workDirTracking: track named: aPrefix, '-missingkey'
                contents: self missingKeyContents)
            line: [:path | self malformedKeysLineFor: path]).
        rows add: (self shapeRow: 'a misordered key'
            in: (self workDirTracking: track named: aPrefix, '-misordered'
                contents: self misorderedKeyContents)
            line: [:path | self malformedKeysLineFor: path]).
        rows add: (self shapeRow: 'an unknown key'
            in: (self workDirTracking: track named: aPrefix, '-unknownkey'
                contents: self unknownKeyContents)
            line: [:path | self malformedKeysLineFor: path]).
        rows add: (self shapeRow: 'a non-String value'
            in: (self workDirTracking: track named: aPrefix, '-nonstring'
                contents: self nonStringValueContents)
            line: [:path | self malformedValueLineFor: path]).
        rows add: (self shapeRow: 'two declared sources'
            in: (self workDirTracking: track named: aPrefix, '-twosource'
                contents: self twoSourceContents)
            line: [:path | self twoSourceLineFor: path
                first: #source second: #git]).
        ^rows asArray
    ]

    ConfigFixtures class >> shapeRow: aLabel in: aWorkDir line: aLineBlock [
        "Private — one row: label, working directory, config path, the
         expected line."
        <category: 'hostile shapes'>
        | path |
        path := self pathIn: aWorkDir.
        ^Array with: aLabel with: aWorkDir with: path
            with: (aLineBlock value: path)
    ]

    ConfigFixtures class >> hostileShapeLabels [
        "The family''s declared membership, so a shape added or dropped
         fails the law rather than quietly changing what it quantifies
         over.

         SORTED THE WAY 3.2.5 SORTS, WHICH IS NOT ASCII ORDER (probed).
         String <= on this toolchain FOLDS CASE — the Sprint 18 finding
         F15 — so this list is written from what the toolchain answers
         and not from an ASCII reading. Every label here begins with a
         lowercase letter for exactly that reason: a list whose order
         cannot be read off the page is a guard that fails first and
         tells the reader nothing about the claim it guards."
        <category: 'hostile shapes'>
        ^#('a directory' 'a misordered key' 'a missing key'
           'a non-String value' 'an unknown key' 'an unparseable file'
           'the wrong artifact tag' 'two declared sources')
    ]

    ConfigFixtures class >> readerMessageFor: aContentsString [
        "The settled reader''s own message for bytes it refuses —
         obtained by asking it, because the boundary is required to
         carry that message verbatim rather than to compose one."
        <category: 'hostile shapes'>
        ^[IndexEntryReader readFrom: (ReadStream on: aContentsString).
          nil]
            on: Error
            do: [:e | e return: e messageText]
    ]

    "---- working directories ----"

    ConfigFixtures class >> workDirTracking: track named: aLabel contents: aConfigContents [
        "A resolvable project — the settled diamond root — carrying
         aConfigContents as its parley.config.st."
        <category: 'working dirs'>
        | path |
        path := track value:
            (CommandLineFixtures diamondRootWorkDirNamed: aLabel).
        self write: aConfigContents in: path.
        ^path
    ]

    ConfigFixtures class >> plainWorkDirTracking: track named: aLabel [
        "The same project with NO config file — the byte-identity
         control (S11) and the usage control (S8)."
        <category: 'working dirs'>
        ^track value:
            (CommandLineFixtures diamondRootWorkDirNamed: aLabel)
    ]

    ConfigFixtures class >> directoryShapedWorkDirTracking: track named: aLabel [
        "A project whose parley.config.st is a DIRECTORY — a stray
         mkdir, a botched checkout, a volume mount. It exists, so every
         check written against existence waves it through, and 3.2.5''s
         File>>contents on one signals a kernel WrongClass that escapes
         a handler written for FileError."
        <category: 'working dirs'>
        | path |
        path := track value:
            (CommandLineFixtures diamondRootWorkDirNamed: aLabel).
        Directory create: (self pathIn: path).
        ^path
    ]

    "---- driving a verb ----"

    ConfigFixtures class >> resolveArgv [
        "resolve with NO source flag — the argv that answers usage
         today and resolves from the config from this sprint on."
        <category: 'driving'>
        ^Array with: 'resolve'
    ]

    ConfigFixtures class >> resolveArgvOn: anIndexDir [
        <category: 'driving'>
        ^Array with: 'resolve' with: '--source' with: anIndexDir
    ]

    ConfigFixtures class >> resultOf: anArgvArray in: aWorkDir [
        <category: 'driving'>
        ^(CommandLine in: aWorkDir runner: RecordingRunner new)
            run: anArgvArray
    ]

    ConfigFixtures class >> lockContentsIn: aWorkDir [
        <category: 'driving'>
        ^PathFixtures contentsOf: aWorkDir, '/parley.lock'
    ]

    "---- what the README owes (S15) ----"

    ConfigFixtures class >> readmeMarkers [
        "WHAT A STRANGER MUST BE ABLE TO READ, as label-and-marker pairs
         — the law prints the LABEL, so a failure names the thing that
         is missing rather than a needle out of context.

         A STATED BEHAVIOUR NOT WRITTEN WHERE USERS READ IS NOT STATED
         (§8 decision 45''s standard). Both halves of the sprint are
         here: the file, where it lives, the schema tag an operator must
         type, the precedence rule, and the flag that quietened exec.

         THE exec MARKER IS THE FLAG''S LONG SPELLING. The composition
         carries -g; --no-gc-message is what gst''s own --help calls it
         and what a reader can look up, and documenting a bare -g would
         send them to a manual page to find out what was done to their
         terminal."
        <category: 'readme'>
        ^Array
            with: (Array with: 'the configuration file'
                with: self fileName)
            with: (Array with: 'where the file lives'
                with: 'project root')
            with: (Array with: 'the schema tag'
                with: '#''parley-config''')
            with: (Array with: 'the flag-wins rule'
                with: 'always wins')
            with: (Array with: 'the flag that quietened exec'
                with: '--no-gc-message')
    ]

    ConfigFixtures class >> occurrencesOf: aNeedle in: aText [
        "How many times aNeedle appears in aText — the instrument for
         `extended, not rewritten`: a section that gained a SECOND
         heading would satisfy every containment law in the suite and
         confuse every reader of the page."
        <category: 'readme'>
        | count at rest |
        count := 0.
        rest := aText.
        [at := rest indexOfSubCollection: aNeedle.
         at = 0] whileFalse: [
            count := count + 1.
            rest := rest copyFrom: at + aNeedle size to: rest size].
        ^count
    ]
]

Namespace current: Smalltalk.
