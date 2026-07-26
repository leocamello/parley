"Parley Sprint 9 — fixtures for the blame boundary (issue #11;
 Doc E §3, §4.1, §4.2 and Doc F §3).

 This is the sprint's ONE new support file. It carries the corrupt-lock
 contents, the vocabulary-typo Package.st, the git-repo-with-diamond
 fixture, the sourceFlags oracle and every pinned Sprint 9 wording. The
 settled ExecFixtures / SourceFixtures / InstallFixtures /
 PublishFixtures / CommandLineFixtures helpers are reused UNCHANGED —
 in particular PublishFixtures' git repository builders, which supply
 the committer identity per command so the developer's git config is
 never read for identity and never written.

 Filesystem discipline (as Sprints 4-8): every fixture path — working
 dirs, index dirs, repositories, the .parley/git/ cache a CommandLine
 wires under a working directory — lives under tmp/, is unique per test
 via a label, and is removed recursively in tearDown through
 ExecFixtures removeTree:; tmp/ is empty or absent after a clean run.
 The developer image is never mutated and no network is contacted: every
 repo path is a local path under tmp/ and every clone is a local clone.

 Process discipline (unchanged): ProcessRunner is the ONLY class that
 spawns, in src/ and in tests alike. This file composes command-line
 STRINGS as pure values and builds fixture repositories through the
 settled PublishFixtures builders, which run through ProcessRunner.

 Pinned wording and composition decisions (posted on issue #11 for
 confirmation) live in the methods:
   - the lock diagnosis — lockProblemFor:message: and the three
     concrete problems built on it;
   - the batched LockError message — lockErrorMessageFor:;
   - the authoring diagnosis — vocabularyMessageForSelector:, which is
     NOT a copy of the text but the vocabulary error's OWN message,
     obtained by signaling it (see the method comment);
   - the git cache path — gitCachePathIn:forRepo:;
   - the source drift law's enumeration — shippedSourceClassNames.

 ONE ARCHITECTURAL QUESTION IS OPEN AND POSTED ON ISSUE #11 (see
 vocabularyMessageForSelector:): the authoring-error boundary of Doc E
 §3 CANNOT be built where the doc places it, and needs a THIRD declared
 settled-class exception. The toolchain evidence is in that method's
 comment."

Namespace current: Parley.

Object subclass: LockBoundaryFixtures [

    <comment: 'Class-side factory for Sprint 9 fixtures: corrupt
parley.lock contents, the vocabulary-typo Package.st, fixture git
repositories carrying the settled install diamond, the .parley/git/
cache paths a CommandLine derives from a working directory, the source
flag-table oracle, and every pinned Sprint 9 wording. Stateless;
uniqueness comes from per-test labels.'>

    "---- corrupt parley.lock contents ----"

    LockBoundaryFixtures class >> unparseableLockContents [
        "Not a literal artifact at all: a message send, rejected by the
         settled reader at position 1. The shape a hand-edited lockfile
         takes when an editor mangles it."
        <category: 'corrupt locks'>
        ^SourceFixtures malformedContents
    ]

    LockBoundaryFixtures class >> wrongTagLockContents [
        "A well-formed #'parley-index' 1 artifact — the reader accepts
         it (the pair owns both schemas), so nothing below the boundary
         rejects it; parley.lock is simply not where it belongs."
        <category: 'corrupt locks'>
        ^PublishFixtures validEntryP
    ]

    LockBoundaryFixtures class >> unsupportedVersionLockContents [
        "A #'parley-lock' artifact at format version 2 — the reader's
         forward-evolution check, and the IndexEntryFormatError half of
         the lock boundary."
        <category: 'corrupt locks'>
        ^'#(#''parley-lock'' 2)', SourceFixtures newline
    ]

    LockBoundaryFixtures class >> writeLockContents: aString in: aWorkDir [
        "Write aString as <aWorkDir>/parley.lock."
        <category: 'corrupt locks'>
        SourceFixtures write: aString toFile: 'parley.lock' in: aWorkDir
    ]

    "---- pinned lock diagnoses (posted on issue #11) ----"

    LockBoundaryFixtures class >> lockRepairAdvice [
        "The repair the diagnosis names. update is the ONE verb that
         never reads the lock — it resolves fresh and rewrites it — so
         the advice is true by construction, and S3 proves it rather
         than asserting it. The decision-31 shape: '<path>: <what is
         wrong> - run parley <verb> to <fix>'."
        <category: 'pinned wordings'>
        ^' - run parley update to rewrite it'
    ]

    LockBoundaryFixtures class >> lockProblemFor: aPath message: aMessage [
        "The LockError's single problem: the lock path, the reader's own
         message VERBATIM, and the repair. The reader's message names a
         character position, and on a hand-edited file that position is
         the operator's only handle — paraphrasing it would throw away
         the one thing that makes the diagnosis actionable."
        <category: 'pinned wordings'>
        ^aPath, ': ', aMessage, self lockRepairAdvice
    ]

    LockBoundaryFixtures class >> unparseableLockProblemFor: aPath [
        "The settled literals-only reader's own rejection, restated here
         exactly as CommandLineFixtures malformedProblemFor: restates it
         for the directory scan."
        <category: 'pinned wordings'>
        ^self lockProblemFor: aPath message:
            'Parse error at position 1: artifact must open with a literal array',
            ' - the micro-format accepts only literal arrays, strings, symbols and non-negative integers'
    ]

    LockBoundaryFixtures class >> wrongTagLockProblemFor: aPath [
        "The boundary's own tag check, in the grammar of the settled
         DirectorySource wrong-tag problem with the two roles swapped.
         The asymmetry is real and stays: from Sprint 10 a source
         directory holds entries AND retirement records, while
         parley.lock holds only lock artifacts — so only the lock side
         can still say 'only'."
        <category: 'pinned wordings'>
        ^self lockProblemFor: aPath message:
            'wrong artifact tag #''parley-index'' - parley.lock holds only #''parley-lock'' 1 artifacts'
    ]

    LockBoundaryFixtures class >> unsupportedVersionLockProblemFor: aPath [
        "The reader's forward-evolution message, verbatim."
        <category: 'pinned wordings'>
        ^self lockProblemFor: aPath message:
            'unsupported #''parley-lock'' format version 2: this Parley reads format version 1'
    ]

    LockBoundaryFixtures class >> lockErrorMessageFor: aCollection [
        "The batched house style, as ManifestError / SourceError /
         InstallError / PublishError before it. LockError carries
         problems exactly as its batched siblings do, so the Sprint 8
         boundary absorbs it with no new mechanism."
        <category: 'pinned wordings'>
        | message |
        message := WriteStream on: String new.
        message nextPutAll: 'Lock has ';
            nextPutAll: aCollection size printString;
            nextPutAll: ' problem(s): '.
        aCollection
            do: [:p | message nextPutAll: p]
            separatedBy: [message nextPutAll: '; '].
        ^message contents
    ]

    "---- the vocabulary-typo Package.st (the authoring boundary) ----"

    LockBoundaryFixtures class >> vocabularyTypoSelector [
        "The typo the fixture Package.st commits: #nmae: for #name:.
         One character transposed — the most ordinary authoring error
         there is, and the one the settled ManifestVocabularyError
         already diagnoses perfectly."
        <category: 'authoring errors'>
        ^'nmae:'
    ]

    LockBoundaryFixtures class >> vocabularyTypoPackageContents [
        "The settled diamond root with #name: mistyped. Everything else
         about the file is valid, so the ONLY thing the diagnosis can be
         about is the vocabulary."
        <category: 'authoring errors'>
        ^'Parley define: [:pkg |
    pkg
        ', self vocabularyTypoSelector, ' ''my-app'';
        version: ''1.0.0'';
        fileIns: #(''App.st'');
        dependency: ''c'' constraint: ''^1.0'' ]', SourceFixtures newline
    ]

    LockBoundaryFixtures class >> vocabularyTypoWorkDirNamed: aLabel [
        "A working directory whose Package.st commits the typo. Answers
         the path; the caller tracks it for teardown."
        <category: 'authoring errors'>
        | path |
        path := SourceFixtures directoryNamed: aLabel.
        ExecFixtures writePackage: self vocabularyTypoPackageContents
            in: path.
        ^path
    ]

    "---- the invalid-declaration Package.st (the widened arm) ----"

    LockBoundaryFixtures class >> invalidDeclarationPackageContents [
        "A Package.st that DOES send define: and whose declarations then
         fail validation — TWO of them, so the law can prove the batch
         survives. Before Sprint 9 this printed a backtrace and was
         reported as 'the file never sent Parley define:': a provable
         lie about a file that did. Ruled into scope by the operator at
         the Sprint 9 RED review (§8 decision 34)."
        <category: 'authoring errors'>
        ^'Parley define: [:pkg |
    pkg
        name: ''my-app'';
        version: ''banana'';
        fileIns: #(''App.st'');
        dependency: ''c'' constraint: ''banana'' ]', SourceFixtures newline
    ]

    LockBoundaryFixtures class >> invalidDeclarationWorkDirNamed: aLabel [
        <category: 'authoring errors'>
        | path |
        path := SourceFixtures directoryNamed: aLabel.
        ExecFixtures writePackage: self invalidDeclarationPackageContents
            in: path.
        ^path
    ]

    LockBoundaryFixtures class >> invalidDeclarationProblems [
        "The settled ManifestBuilder>>build batch, in build's own order
         (version before dependencies), carried through the boundary
         INTACT. An author fixes a Package.st per edit-run cycle, not
         per error — flattening the batch to one line would throw away
         exactly what ManifestError exists for (Doc B §3.3)."
        <category: 'authoring errors'>
        ^Array
            with: 'invalid version ''banana'''
            with: 'invalid constraint ''banana'' for dependency ''c'''
    ]

    LockBoundaryFixtures class >> vocabularyMessageForSelector: aSelectorString [
        "The oracle for the authoring diagnosis: the vocabulary error's
         OWN messageText, obtained by signaling it against the settled
         ManifestBuilder. It is deliberately NOT a pinned copy of the
         text — S4 requires the diagnosis to carry the vocabulary
         error's message VERBATIM, so the law must be an identity
         between the two, and an oracle holding a second copy would
         prove only that copying works. The suggestion travels with it;
         vocabularySuggestionText below pins the part S4 names.

         TOOLCHAIN EVIDENCE, and the open architectural question posted
         on issue #11. Doc E §3 places this boundary on the file-in
         inside ManifestFile load: — 'the file-in of step 2 is wrapped'.
         That cannot work on 3.2.5, and the probe says why: the doit
         context of a filed-in statement is PARENTLESS. Probing
         'thisContext parentContext printString' from inside a filed-in
         file answers 'UndefinedObject>>__terminate' — not the caller of
         fileIn: — so an on:do: wrapped around FileStream fileIn: is not
         in the signaling chain and never runs. Probed directly: with a
         handler around the file-in, the vocabulary error was NOT
         caught; gst printed its own backtrace (including the
         'doesNotUnderstand' and '(src/' markers CommandLineFixtures
         backtraceMarkers looks for) and abandoned the statement, after
         which load: answers the WRONG diagnosis — 'no manifest defined'.
         So Sprint 8's declared escape path is also inaccurate: the
         error never reaches the §4.2 boundary at all.

         A handler installed in a method CALLED BY the filed-in
         statement does catch it — probed, with the message recorded
         intact and the file-in continuing afterwards. Inside Parley the
         only such frame is Parley.Parley class >> define:, which
         already carries Sprint 6's declared one-send exception. Making
         S4/S5/S7 true therefore needs a THIRD declared settled-class
         exception, on Parley.Parley class >> define: — one on:do:
         around the author-block evaluation that hands the message to
         ManifestFile (where all recording state already lives) so that
         load: signals the ManifestError from its own frame. Only the
         operator can declare it. The laws below are written against the
         BEHAVIOUR — exit 1 and the verbatim message — so they hold
         whichever site is granted."
        <category: 'authoring errors'>
        ^[ManifestBuilder new perform: aSelectorString asSymbol with: 'x'.
          nil]
            on: ManifestVocabularyError
            do: [:e | e return: e messageText]
    ]

    LockBoundaryFixtures class >> vocabularyTypoProblem [
        "The single ManifestError problem the typo must produce: the
         vocabulary error's message, unchanged. Reclassified, never
         rewritten."
        <category: 'authoring errors'>
        ^self vocabularyMessageForSelector: self vocabularyTypoSelector
    ]

    LockBoundaryFixtures class >> vocabularySuggestionText [
        "The part of the message S4 names explicitly — the selector and
         the nearest-selector suggestion. Pinned as a SUBSTRING so the
         reflected 'Known messages:' list stays free to grow with the
         vocabulary without dragging this oracle along."
        <category: 'pinned wordings'>
        ^'Package.st sent #nmae: - not part of the manifest vocabulary. Did you mean #name:?'
    ]

    "---- the git cache the wiring derives from the working dir ----"

    LockBoundaryFixtures class >> gitCacheRootIn: aWorkDir [
        "Derived from the WORKING directory, never from the process
         cwd — the same rule the store and target already follow."
        <category: 'wiring paths'>
        ^(CommandLineFixtures parleyDirIn: aWorkDir), '/git'
    ]

    LockBoundaryFixtures class >> gitCachePathIn: aWorkDir forRepo: aRepoPath [
        "The checkout directory of one repo: keyed through the settled
         Sha256, so any repo string — a path, a URL, anything git clone
         accepts — becomes one deterministic filesystem-safe name and no
         escaping layer is invented."
        <category: 'wiring paths'>
        ^(self gitCacheRootIn: aWorkDir), '/',
            (Sha256 hexDigestOf: aRepoPath)
    ]

    LockBoundaryFixtures class >> cwdGitCacheRoot [
        "The path a cwd-derived wiring would create beside the process
         cwd. The repository root legitimately holds .parley/ (the
         harness scope and loop state), so the laws assert the absence
         of this path, never of .parley/ itself — the Sprint 8
         cwdStoreRoot precedent."
        <category: 'wiring paths'>
        ^'.parley/git'
    ]

    "---- fixture git repositories (local paths only, never a network) ----"

    LockBoundaryFixtures class >> diamondRepoNamed: aLabel [
        "A fixture git repository whose working tree is an index
         directory holding the settled install diamond (entries with
         true digests, and their archives). Built locally through the
         settled PublishFixtures builders — ProcessRunner, per-command
         committer identity, no network. Answers the repo path; the
         caller tracks it for teardown."
        <category: 'git fixtures'>
        ^PublishFixtures buildDiamondRepoAt:
            (SourceFixtures directoryNamed: aLabel)
    ]

    LockBoundaryFixtures class >> indexRepoNamed: aLabel fromIndex: anIndexDir [
        "A fixture git repository carrying a copy of a published index
         directory — the git leg of the ecosystem loop."
        <category: 'git fixtures'>
        ^PublishFixtures buildRepoAt: (SourceFixtures directoryNamed: aLabel)
            fromIndex: anIndexDir
    ]

    "---- the source flag table and its drift law (S11) ----"

    LockBoundaryFixtures class >> sourceDirectory [
        <category: 'drift law'>
        ^'src/source'
    ]

    LockBoundaryFixtures class >> shippedSourceClassNames [
        "Every *Source class Parley ships in src/source/, in sorted
         order, read from the checkout itself.

         File>>files is CORRECT here and namesDo: is not needed: 3.2.5's
         File>>files answers regular files only, and src/source/ holds
         nothing but .st files. Probed against the toolchain before this
         fixture was written — (File name: 'src/source') files answers
         three entries: DirectorySource.st, GitIndexSource.st and
         SourceError.st. (Contrast CommandLineFixtures
         srcSubdirectoryNames, which enumerates DIRECTORIES and must use
         namesDo: for exactly that reason.)

         SourceError.st is filtered out by the '*Source' name rule: an
         error class is not a source. The rule is the class NAME, not
         the directory, because the directory is the reachability
         question Sprint 8's bin/ drift law already answers."
        <category: 'drift law'>
        | names |
        names := OrderedCollection new.
        (File name: self sourceDirectory) files do: [:each |
            | base |
            base := each stripPath.
            ((base endsWith: 'Source.st') and: [base ~= 'Source.st'])
                ifTrue: [names add: (base copyFrom: 1 to: base size - 3)]].
        ^(names asSortedCollection: [:a :b | a <= b]) asArray
    ]

    LockBoundaryFixtures class >> sourceFlagNames [
        "The flags the table declares, sorted — the oracle for the
         grammar half of Doc E §4.2."
        <category: 'drift law'>
        ^#('--git' '--source')
    ]

    LockBoundaryFixtures class >> sourceClassNames [
        "The source classes the table builds, sorted. Every shipped
         *Source class must appear; a class inside a named directory
         that no flag builds is exactly the GitIndexSource gap."
        <category: 'drift law'>
        ^#('DirectorySource' 'GitIndexSource')
    ]

    LockBoundaryFixtures class >> namesOfSourceClassesIn: aFlagTable [
        "The class-name column of CommandLine class >> sourceFlags,
         sorted, as Strings (3.2.5's Class>>name answers a Symbol)."
        <category: 'drift law'>
        ^((aFlagTable collect: [:row | (row at: 2) name asString])
            asSortedCollection: [:a :b | a <= b]) asArray
    ]

    LockBoundaryFixtures class >> flagNamesIn: aFlagTable [
        "The flag column of the table, sorted."
        <category: 'drift law'>
        ^((aFlagTable collect: [:row | row at: 1])
            asSortedCollection: [:a :b | a <= b]) asArray
    ]

    "---- the undiagnosed shape, as a thing a law can look for ----"

    LockBoundaryFixtures class >> undiagnosedLinePrefix [
        "The opening of the exit-70 line. A law proving a diagnosis
         reached the operator asserts this NEVER opens any of its
         lines — the blame must not land on Parley."
        <category: 'pinned wordings'>
        ^'internal error: '
    ]
]

Namespace current: Smalltalk.
