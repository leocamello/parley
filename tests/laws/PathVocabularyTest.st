"Parley Sprint 21 — the two vocabulary words, the manifest collections
 they land in, and the two things that must NOT move because of them
 (issue #23; Doc B §2/§3.2/§3.4/§4/§5.2, Doc F §1 step 0; §8 decision
 69).

 THE WHOLE OF DECISION 69 IS A PAIR OF CLAIMS, AND THIS FILE HOLDS
 BOTH. The words exist and validate (the first half), and NOTHING
 SERIALIZED MOVES because of them (the second). The second half is the
 one that is true by construction today — dev dependencies live in
 their own collection the entry writer never reads, and a path
 dependency is refused before publish composes anything — which is
 exactly why it is a law: true-by-construction is how the last three
 drift families in this project started.

 THE VOCABULARY IS EXPLICIT METHODS, NEVER DNU (§8 decision 17). Both
 words must appear in the reflected vocabulary, because that list is
 what a typo's error message offers the author, and a word missing from
 it is a word tooling cannot see.

 EVERY PROBLEM SENTENCE IS BATCHED, NEVER SIGNALED ONE AT A TIME (Doc B
 §3.4): an author fixes a Package.st per edit-run cycle, not per
 error."

Namespace current: Parley.

TestCase subclass: PathVocabularyTest [
    | fixtureDirs |

    <comment: 'Laws over dependency:path: and devDependency:constraint::
the reflected vocabulary, the raw recording, build validation across
all three declared kinds, the two manifest collections, the entry
writer''s blindness to both, fromIndexEntry: reconstructing neither,
and the publish pre-flight refusal.'>

    setUp [
        fixtureDirs := OrderedCollection new
    ]

    tearDown [
        fixtureDirs isNil ifTrue: [^self].
        fixtureDirs do: [:each | PathFixtures removeTree: each].
        fixtureDirs := nil
    ]

    freshDir: aLabel [
        | path |
        path := SourceFixtures directoryNamed: aLabel.
        fixtureDirs add: path.
        ^path
    ]

    manifestFrom: aBlock [
        "Build a manifest through the settled gateway, so every law here
         goes through the path an author's own Package.st takes."
        ^Parley define: aBlock
    ]

    problemsOf: aBlock [
        "The batched problems of a manifest that fails validation."
        ^[self manifestFrom: aBlock. #()]
            on: ManifestError
            do: [:e | e return: e problems]
    ]

    "---- the vocabulary itself ----"

    testBothWordsAreReflectedVocabularyRatherThanDoesNotUnderstand [
        "The vocabulary list is reflected from the 'manifest vocabulary'
         category and is what a typo's error offers the author. A word
         reached through doesNotUnderstand: would be invisible to
         senders, implementors, completion and that list at once."
        self assert: (ManifestBuilder vocabulary includes: #dependency:path:)
            description: 'the vocabulary is ',
                ManifestBuilder vocabulary printString.
        self assert: (ManifestBuilder vocabulary
            includes: #devDependency:constraint:)
            description: 'the vocabulary is ',
                ManifestBuilder vocabulary printString
    ]

    testEachNewWordCarriesAMethodComment [
        "Comments become hover documentation, and the DSL surface is API
         (§8 decision 17). A vocabulary word without one is a word the
         author can send and cannot read about.

         THE CHECK IS TEXTUAL, AND THE BOUND IS STATED WITH IT (§8
         decision 43's shape; amended mid-sprint, GREEN step 1). As first
         written this law sent `methodComment` to a CompiledMethod —
         a Pharo-shaped selector 3.2.5 DOES NOT HAVE, and it has no
         `comment` either (both probed). The law could never pass on this
         toolchain: it was a protocol assumed rather than probed, and the
         obligation Doc B §3.2 states went unchecked behind it.

         `methodSourceString` DOES retain the leading double-quoted block
         after file-in — probed on both methods under test, at 876 and
         730 characters with the comment opening immediately after the
         body bracket — so the comment is read out of the source text.

         WHAT THIS CLAIMS, and what it does not: the source carries a
         terminated, non-blank double-quoted block. It does NOT parse
         Smalltalk, so a double quote inside a string literal placed
         ahead of the comment would fool it. No vocabulary word is
         written that way, the check is scoped to the two this sprint
         declares, and the honest statement of that limit is the point of
         decision 43's standard rather than a caveat on it."
        (Array with: #dependency:path: with: #devDependency:constraint:)
            do: [:selector |
                | source open close |
                source := (ManifestBuilder compiledMethodAt: selector)
                    methodSourceString.
                open := source indexOf: $".
                self deny: open = 0
                    description: selector printString, ' has no comment'.
                close := source indexOf: $" startingAt: open + 1.
                self deny: close = 0
                    description: selector printString,
                        ' has an unterminated comment'.
                self deny: (source copyFrom: open + 1 to: close - 1)
                    trimSeparators isEmpty
                    description: selector printString, ' has an empty comment']
    ]

    testAPathDependencyRecordsTheDeclaredStringUnchanged [
        "The path is recorded RAW — the author's own string, resolved
         relative to the manifest's directory at USE, never expanded
         here. A builder that normalized it would make the lock's
         byte-preservation impossible one layer down."
        | manifest declared |
        declared := '../kernel-text'.
        manifest := self manifestFrom: [:pkg |
            pkg
                name: 'my-app';
                version: '1.0.0';
                fileIns: #('App.st');
                dependency: 'kernel-text' path: declared].
        self assert: manifest pathDependencies size = 1
            description: manifest pathDependencies printString.
        self assert: manifest pathDependencies first name = 'kernel-text'.
        self assert: manifest pathDependencies first path = declared
            description: 'the recorded path is ',
                manifest pathDependencies first path printString
    ]

    testADevDependencyLandsInItsOwnCollectionAndParsesItsConstraint [
        "Dev dependencies are ordinary Dependency values in their OWN
         collection: the entry writer reads the other one, which is what
         makes the exclusion structural rather than a filter somebody
         has to remember."
        | manifest |
        manifest := self manifestFrom: [:pkg |
            pkg
                name: 'my-app';
                version: '1.0.0';
                fileIns: #('App.st');
                devDependency: 'kernel-lint' constraint: '^1.0.0'].
        self assert: manifest dependencies isEmpty
            description: 'a dev dependency reached the ordinary collection: ',
                manifest dependencies printString.
        self assert: manifest devDependencies size = 1.
        self assert: manifest devDependencies first name = 'kernel-lint'.
        self assert: manifest devDependencies first constraint
            = (VersionConstraint fromString: '^1.0.0')
            description: 'the dev constraint parsed as ',
                manifest devDependencies first constraint printString
    ]

    "---- build validation (Doc B §3.4 items 4-6) ----"

    testADevDependencyConstraintIsParsedAtBuild [
        "Item 4, widened: EVERY dependency constraint parses, dev
         dependencies included. A word whose constraint was never parsed
         would fail later, in a place that could not name the clause."
        self assert: (self problemsOf: [:pkg |
            pkg
                name: 'my-app';
                version: '1.0.0';
                fileIns: #('App.st');
                devDependency: 'kernel-lint' constraint: 'garbage'])
            = (Array with:
                'invalid constraint ''garbage'' for dependency ''kernel-lint''')
            description: (self problemsOf: [:pkg |
                pkg name: 'my-app'; version: '1.0.0'; fileIns: #('App.st');
                    devDependency: 'kernel-lint' constraint: 'garbage'])
                        printString
    ]

    testAPathMustBeANonEmptyString [
        "Item 6. Existence is not this pass's question — a missing
         sibling is diagnosed where the path is USED — but a path that
         is not a string at all describes nothing anywhere."
        | problems |
        problems := self problemsOf: [:pkg |
            pkg
                name: 'my-app';
                version: '1.0.0';
                fileIns: #('App.st');
                dependency: 'kernel-text' path: ''].
        self assert: problems size = 1
            description: problems printString.
        self assert: (CommandLineFixtures does: problems first
            include: 'kernel-text')
            description: problems first printString
    ]

    testDuplicateAndSelfRulesQuantifyOverAllThreeKindsTogether [
        "Item 5. A name may be declared as an index dependency, a path
         dependency or a dev dependency, and only as ONE of them —
         because all three end up as pins in one lock, and a name
         claimed twice is a project that cannot say which it meant.
         Three pairings, each proved, because a rule enforced within
         each collection separately passes every single-kind fixture."
        | rows |
        rows := (Array
            with: (Array with: 'index and path' with: [:pkg |
                pkg name: 'my-app'; version: '1.0.0'; fileIns: #('App.st');
                    dependency: 'kernel-text' constraint: '^1.0.0';
                    dependency: 'kernel-text' path: '../kernel-text'])
            with: (Array with: 'index and dev' with: [:pkg |
                pkg name: 'my-app'; version: '1.0.0'; fileIns: #('App.st');
                    dependency: 'kernel-lint' constraint: '^1.0.0';
                    devDependency: 'kernel-lint' constraint: '^1.0.0'])
            with: (Array with: 'path and dev' with: [:pkg |
                pkg name: 'my-app'; version: '1.0.0'; fileIns: #('App.st');
                    dependency: 'kernel-text' path: '../kernel-text';
                    devDependency: 'kernel-text' constraint: '^1.0.0'])).
        rows do: [:row |
            | problems |
            problems := self problemsOf: (row at: 2).
            self deny: problems isEmpty
                description: (row at: 1), ' declared one name twice and built cleanly'.
            self assert: (problems anySatisfy: [:each |
                CommandLineFixtures does: each include: 'duplicate'])
                description: (row at: 1), ' answered ', problems printString]
    ]

    testSelfDependencyIsRejectedThroughEveryKind [
        "The same rule's other half: a package may not depend on itself
         by any of the three spellings."
        (Array
            with: [:pkg |
                pkg name: 'my-app'; version: '1.0.0'; fileIns: #('App.st');
                    dependency: 'my-app' path: '../my-app']
            with: [:pkg |
                pkg name: 'my-app'; version: '1.0.0'; fileIns: #('App.st');
                    devDependency: 'my-app' constraint: '^1.0.0'])
                do: [:block |
                    | problems |
                    problems := self problemsOf: block.
                    self assert: (problems anySatisfy: [:each |
                        CommandLineFixtures does: each
                            include: 'cannot depend on itself'])
                        description: problems printString]
    ]

    testEveryProblemStillArrivesInOneBatch [
        "The batching rule is unchanged by the two new words: a manifest
         wrong in three ways answers ONE ManifestError carrying all
         three."
        | problems |
        problems := self problemsOf: [:pkg |
            pkg
                name: 'my-app';
                version: 'banana';
                fileIns: #('App.st');
                dependency: 'kernel-text' path: '';
                devDependency: 'kernel-lint' constraint: 'garbage'].
        self assert: problems size = 3
            description: problems printString
    ]

    "---- what does NOT move (§8 decision 69's second half) ----"

    testTheEntryWriterReadsNeitherNewCollection [
        "The schema does not move. One manifest declaring BOTH new kinds
         renders the same entry bytes as the same manifest declaring
         neither — proved against a HAND-WRITTEN oracle rather than
         against the writer's own other output, so a writer that learned
         about both collections could not satisfy it.

         THE ORACLE COMPARISON IS PARENTHESISED, AND IT HAS TO BE
         (amended mid-sprint, GREEN step 1). As first written the second
         assertion read `= '#(...)', SourceFixtures newline` — and `=`
         and `,` are both BINARY, so it parsed as
         `(contents = '#(...)') , newline`, sending `,` to a Boolean.
         The law could never pass in either direction: it was not a weak
         pin, it was no pin at all. This is Sprint 11's hexDigestCorpus
         defect returned — a binary comma binding past what the author
         meant — and that one was caught at Gate A while this one shipped
         through it. The oracle bytes themselves were correct and are
         probed: the writer's real output for the rich manifest equals
         this string plus one newline, exactly."
        | rich plain richBytes plainBytes |
        rich := self manifestFrom: [:pkg |
            pkg
                name: 'kernel-json';
                version: '0.3.1';
                summary: 'a reader and writer';
                author: 'Leonardo';
                license: 'MIT';
                fileIns: #('Json.st');
                dependency: 'kernel-text' path: '../kernel-text';
                devDependency: 'kernel-lint' constraint: '^1.0.0'].
        plain := self manifestFrom: [:pkg |
            pkg
                name: 'kernel-json';
                version: '0.3.1';
                summary: 'a reader and writer';
                author: 'Leonardo';
                license: 'MIT';
                fileIns: #('Json.st')].
        richBytes := WriteStream on: String new.
        plainBytes := WriteStream on: String new.
        IndexEntryWriter write: rich on: richBytes.
        IndexEntryWriter write: plain on: plainBytes.
        self assert: richBytes contents = plainBytes contents
            description: 'the entries differ: ', richBytes contents printString.
        self assert: richBytes contents = ('#(#''parley-index'' 1 #name ''kernel-json'' #version ''0.3.1'' #summary ''a reader and writer'' #author ''Leonardo'' #license ''MIT'' #fileIns #(''Json.st'') #dependencies #() #archive #())',
            SourceFixtures newline)
            description: 'the settled entry rendering moved: ',
                richBytes contents printString
    ]

    testFromIndexEntryReconstructsNeitherCollection [
        "An entry never carries either kind, so there is nothing to
         reconstruct and both collections are EMPTY on that path by
         construction. Asserted rather than assumed, because a
         reconstruction that invented an empty collection lazily and a
         reconstruction that answered nil read the same at every call
         site until one of them is sent isEmpty."
        | manifest |
        manifest := LibraryManifest fromIndexEntry: (IndexEntryReader
            readFrom: (ReadStream on: (PathDepFixtures plainEntryFor: 'kernel-a'
                version: '1.0.0' dependencies: ''))).
        self assert: manifest pathDependencies isEmpty
            description: manifest pathDependencies printString.
        self assert: manifest devDependencies isEmpty
            description: manifest devDependencies printString
    ]

    testPublishRefusesAPathDeclaringManifestBeforeAnythingElse [
        "Doc F §1 STEP 0, driven at the Publisher rather than through
         the verb: the refusal is step ZERO, so it fires before the
         destination check — and the fixture's destination DOES NOT
         EXIST, which is what makes the ordering falsifiable. A
         publisher that ran the destination check first would answer the
         settled missing-destination problem instead."
        | work runner problems |
        work := self freshDir: 'pv-publish-work'.
        ExecFixtures writePackage: (PathDepFixtures rootDeclaring:
            '../kernel-text') in: work.
        runner := RecordingRunner new.
        problems := [(Publisher
            manifest: (ManifestFile load: work, '/Package.st')
            in: work
            to: 'tmp/parley-pv-absent-dest'
            runner: runner) publish. #()]
                on: PublishError
                do: [:e | e return: e problems].
        self assert: problems = (Array with: (PathDepFixtures
            publishPathRefusalFor: 'kernel-text' path: '../kernel-text'))
            description: problems printString.
        self assert: runner commands = #()
            description: 'the refusal spawned ', runner commands printString
    ]

    testADevDeclaringManifestPublishesNormally [
        "The other half of the refusal, and the reason it is narrow: dev
         dependencies do NOT refuse. They are simply never serialized,
         so a library that declares them publishes exactly as one that
         does not — and a refusal that covered both would have made the
         commonest real library unpublishable."
        | work manifest |
        work := self freshDir: 'pv-dev-work'.
        ExecFixtures writePackage:
            (PathDepFixtures libraryContentsWithDev: true) in: work.
        SourceFixtures write: PathDepFixtures librarySource
            toFile: 'Json.st' in: work.
        manifest := ManifestFile load: work, '/Package.st'.
        self deny: manifest devDependencies isEmpty
            description: 'the fixture declares no dev dependency, which makes this law vacuous'.
        self assert: manifest pathDependencies isEmpty.
        self assert: ((Publisher
            manifest: manifest
            in: work
            to: (self freshDir: 'pv-dev-dest')
            runner: ProcessRunner new) publish) isString
            description: 'a dev-declaring manifest did not publish'
    ]
]

Namespace current: Smalltalk.
