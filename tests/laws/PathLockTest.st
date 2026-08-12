"Parley Sprint 21 — the #path lock tuple family (issue #23; Doc B §5.3,
 Doc E §4.1; §8 decisions 25, 42, 47, 69).

 THE LOCK RECORDS PROVENANCE AND DOES NOT RECORD AUDIENCE. The pin
 tuple gains ONE declared alternative form beside the settled #sha256
 one, and nothing else moves: the tag, the format version and the two
 keys are unchanged, every pre-Sprint-21 lock is valid unchanged, and a
 lock written for a manifest with no path dependencies is BYTE-IDENTICAL
 to what Sprint 20 wrote. Dev pins land in #packages undistinguished —
 §8 decision 69 states the condition any re-proposal of a lock-side dev
 key must meet, and no law here creates one.

 THE BOUNDARY ACCEPTS EXACTLY TWO FORMS AND NOTHING BETWEEN THEM. A
 widening that accepted any symbol in third position, or an empty
 fourth element, would let the tool write down a pin that describes
 nothing — which is the corruption check exists to catch, manufactured
 by the tool itself (§8 decision 47's own argument, one layer down).

 THE PATH-FREE VIEW IS WHY Installer, InstalledSet AND ContentStore
 NEVER LEARN THAT PATHS EXIST. §8 decision 25's empty-sha256 diagnosis
 keeps governing exactly the index pins it was written about, and the
 two states answer differently because they are different: '' records
 an index release that published no archive, #path records a pin no
 index supplied.

 THE BYTE ORACLES ARE HAND-WRITTEN. An oracle computed by the writer
 under test cannot fail when that writer is wrong, and the wrong writer
 here is the one that renders a tuple the boundary then rejects."

Namespace current: Parley.

TestCase subclass: PathLockTest [
    | fixtureDirs |

    <comment: 'Laws over the #path pin tuple: the writer''s rendering,
the boundary''s two accepted forms and its refusals, Resolution
provenance and the path-free view, PinVerification over the three
declared kinds, and the byte-identity of a path-free lock with Sprint
20''s.'>

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

    resolutionWithPathPin [
        "A Resolution carrying one index pin and one path pin, built
         through the settled constructor and then given provenance —
         which is the shape the CLI produces, because the strategies
         answer triples that know nothing about paths and are NOT this
         sprint's subjects."
        | triples paths |
        triples := Dictionary new.
        triples at: 'kernel-a' put: (Array
            with: (Version fromString: '1.0.0')
            with: 'ab12000000000000000000000000000000000000000000000000000000000000').
        triples at: 'kernel-text' put: (Array
            with: (Version fromString: '1.2.0') with: '').
        paths := Dictionary new.
        paths at: 'kernel-text' put: '../kernel-text'.
        ^(Resolution root: 'my-app' triples: triples) withPaths: paths
    ]

    provenanceOfText [
        | paths |
        paths := Dictionary new.
        paths at: 'kernel-text' put: '../kernel-text'.
        ^paths
    ]

    bytesOf: aResolution [
        | out |
        out := WriteStream on: String new.
        IndexEntryWriter writeLock: aResolution on: out.
        ^out contents
    ]

    lockResultIn: aWorkDir [
        "Drive a verb that READS the lock, so the boundary is exercised
         at the site that owns it rather than through a private."
        ^PathDepFixtures resultOf: (Array with: 'tree')
            in: aWorkDir runner: RecordingRunner new
    ]

    "---- the writer ----"

    testTheWriterRendersThePathTupleInTheDeclaredForm [
        "Third position the literal symbol #path, fourth the author's
         declared string BYTE-PRESERVED, packages still sorted by name,
         single spaces, one trailing newline."
        self assert: (self bytesOf: self resolutionWithPathPin)
            = (PathDepFixtures lockTextRoot: 'my-app'
                packages: '#(''kernel-a'' ''1.0.0'' #sha256 ''ab12000000000000000000000000000000000000000000000000000000000000'') ',
                    (PathDepFixtures pathTupleFor: 'kernel-text'
                        version: '1.2.0' path: '../kernel-text'))
            description: 'the lock reads ',
                (self bytesOf: self resolutionWithPathPin) printString
    ]

    testAPathFreeLockIsByteIdenticalToSprintTwentys [
        "THE DECLARED NON-MOVER, ASSERTED RATHER THAN ASSUMED. A
         resolution with no path provenance renders exactly the bytes
         the settled writer always rendered — the same claim every
         settled lock oracle makes, restated here against a
         hand-written literal so this sprint's own file carries it."
        | triples |
        triples := Dictionary new.
        triples at: 'kernel-a' put: (Array
            with: (Version fromString: '1.0.0')
            with: 'ab12000000000000000000000000000000000000000000000000000000000000').
        self assert: (self bytesOf: ((Resolution root: 'my-app'
            triples: triples) withPaths: Dictionary new))
            = PathDepFixtures preSprintLockText
            description: (self bytesOf: ((Resolution root: 'my-app'
                triples: triples) withPaths: Dictionary new)) printString
    ]

    testAResolutionGivenNoPathsRendersUnchangedBytes [
        "withPaths: answers a NEW value and an EMPTY provenance map
         changes nothing — the structural-immutability shape every
         operation in this domain has, and the guard against a
         provenance slot that renders differently when it is merely
         present."
        | triples plain decorated |
        triples := Dictionary new.
        triples at: 'kernel-a' put: (Array
            with: (Version fromString: '1.0.0')
            with: 'ab12000000000000000000000000000000000000000000000000000000000000').
        plain := Resolution root: 'my-app' triples: triples.
        decorated := plain withPaths: Dictionary new.
        self deny: decorated == plain
            description: 'withPaths: answered the receiver'.
        self assert: (self bytesOf: decorated) = (self bytesOf: plain)
            description: (self bytesOf: decorated) printString
    ]

    "---- the boundary ----"

    testAWrittenPathLockReadsBackAsTheSameResolution [
        "Write, read, rebuild: the round-trip the settled #sha256 form
         has always had, now over the alternative form. fromLockEntry:
         stays TRUSTING — it is fed only values the boundary accepted —
         so this law is what proves the boundary let the right ones
         through."
        | work text rebuilt |
        work := self freshDir: 'pl-roundtrip-work'.
        text := self bytesOf: self resolutionWithPathPin.
        PathDepFixtures writeLock: text in: work.
        rebuilt := Resolution fromLockEntry: (IndexEntryReader
            readFrom: (ReadStream on: text)).
        self assert: (rebuilt versionOf: 'kernel-text')
            = (Version fromString: '1.2.0').
        self assert: (rebuilt provenanceOf: 'kernel-text') = '../kernel-text'
            description: 'the provenance read back as ',
                (rebuilt provenanceOf: 'kernel-text') printString.
        self assert: (rebuilt provenanceOf: 'kernel-a') isNil
            description: 'an index pin acquired a path provenance'.
        self assert: (self bytesOf: rebuilt) = text
            description: 'the round trip is not the identity: ',
                (self bytesOf: rebuilt) printString
    ]

    testAPathPinAnswersTheEmptyDigestRatherThanSignalling [
        "sha256Of: still answers for every pin, because settled callers
         send it unconditionally. A path pin answers '' — which is
         precisely why it must never reach the Installer, and why the
         path-free view exists rather than a branch inside the
         pipeline."
        self assert: (self resolutionWithPathPin sha256Of: 'kernel-text') = ''
            description: (self resolutionWithPathPin sha256Of: 'kernel-text')
                printString
    ]

    testTheBoundaryRefusesAnEmptyDeclaredPath [
        "Doc B §5.3: the fourth element is a NON-EMPTY String. An empty
         one records nothing at all, and a boundary that accepted it
         would hand a consumer a pin it cannot resolve against any
         directory."
        | work result |
        work := self freshDir: 'pl-empty-work'.
        ExecFixtures writePackage: PathDepFixtures emptyRootContents in: work.
        PathDepFixtures writeLock: PathDepFixtures emptyPathLockText in: work.
        result := self lockResultIn: work.
        self assert: result exitCode = 1
            description: 'an empty declared path answered exit ',
                result exitCode printString, ': ', result lines printString.
        self assert: result lines = (Array with: (LockSchemaFixtures
            lockPackagesKindProblemFor: work, '/parley.lock'))
            description: result lines printString
    ]

    testTheBoundaryRefusesAThirdSymbolThatIsNeitherForm [
        "EXACTLY the two declared forms and nothing between them. A
         boundary that accepted any symbol would let a future spelling
         through silently, which is the forward-evolution point the tag
         whitelist exists to keep real."
        | work result |
        work := self freshDir: 'pl-marker-work'.
        ExecFixtures writePackage: PathDepFixtures emptyRootContents in: work.
        PathDepFixtures writeLock: PathDepFixtures wrongMarkerLockText in: work.
        result := self lockResultIn: work.
        self assert: result exitCode = 1
            description: 'an unknown tuple marker answered exit ',
                result exitCode printString, ': ', result lines printString.
        self assert: result lines = (Array with: (LockSchemaFixtures
            lockPackagesKindProblemFor: work, '/parley.lock'))
            description: result lines printString
    ]

    testTheTupleShapeWordingNamesBothAcceptedForms [
        "THE WORDING IS THE ONLY PLACE AN OPERATOR LEARNS WHAT THIS
         BUILD ACCEPTS, so widening the acceptance without widening the
         sentence would make it state something false — the Sprint 10
         and Sprint 14 tag-whitelist rule, applied to the tuple family.
         Read off the LINE THE OPERATOR IS SHOWN rather than off the
         oracle, so a fixture re-pinned ahead of the code cannot make
         this law true on its own."
        | work result line |
        work := self freshDir: 'pl-wording-work'.
        ExecFixtures writePackage: PathDepFixtures emptyRootContents in: work.
        PathDepFixtures writeLock: PathDepFixtures wrongMarkerLockText in: work.
        result := self lockResultIn: work.
        self assert: result lines size = 1
            description: result lines printString.
        line := result lines first.
        self assert: (CommandLineFixtures does: line
            include: '#(<name> <version> #path <declared path>)')
            description: 'the sentence does not name the alternative form: ',
                line printString.
        self assert: (CommandLineFixtures does: line
            include: '#(<name> <version> #sha256 <hex digest>)')
            description: 'the settled form left the sentence: ',
                line printString
    ]

    testAPreSprintLockKeepsValidatingUnchanged [
        "Every existing lock is valid unchanged: the widening is
         ADDITIVE. A boundary that had replaced the settled form rather
         than joining it would fail here and nowhere else, because every
         other law in this file is about the new form."
        | work result |
        work := self freshDir: 'pl-legacy-work'.
        ExecFixtures writePackage: PathDepFixtures indexNeedingRootContents
            in: work.
        PathDepFixtures writeLock: PathDepFixtures preSprintLockText in: work.
        result := self lockResultIn: work.
        self deny: (result lines anySatisfy: [:line |
            CommandLineFixtures does: line include: 'parley.lock: '])
            description: 'a pre-Sprint-21 lock was refused: ',
                result lines printString.
        self assert: ((Resolution fromLockEntry: (IndexEntryReader readFrom:
            (ReadStream on: PathDepFixtures preSprintLockText)))
            provenanceOf: 'kernel-a') isNil
            description: 'a settled #sha256 pin acquired a path provenance'
    ]

    "---- the path-free view ----"

    testThePathFreeViewDropsExactlyThePathPins [
        "The CLI hands the Installer the path-free view, so a path pin
         never enters the Doc D pipeline. Index pins — INCLUDING one
         whose digest is '' — survive untouched, which is the half that
         keeps §8 decision 25's diagnosis reachable for exactly the pins
         it was written about."
        | view |
        view := self resolutionWithPathPin pathFreeView.
        self assert: view packageNames = (Array with: 'kernel-a')
            description: view packageNames printString.
        self assert: (view versionOf: 'kernel-a')
            = (Version fromString: '1.0.0').
        self assert: view rootName = 'my-app'
            description: 'the path-free view lost the root name'
    ]

    testAPathFreeResolutionsViewIsTheResolutionItself [
        "A resolution with no path pins views to an equal value, which
         is what makes the CLI able to send pathFreeView
         unconditionally — no caller has to ask whether paths are
         involved, and no branch exists to get wrong."
        | triples resolution |
        triples := Dictionary new.
        triples at: 'kernel-a' put: (Array
            with: (Version fromString: '1.0.0') with: '').
        resolution := Resolution root: 'my-app' triples: triples.
        self assert: resolution pathFreeView = resolution
            description: resolution pathFreeView printString
    ]

    "---- PinVerification over the three declared kinds ----"

    testAPathPinVerifiesByPresenceWithNoConstraintCheck [
        "A path dependency verifies by PRESENCE and provenance: its
         version is the sibling's declaration, not a constraint of the
         root's, so there is no constraint check to fail. A verifier
         that invented one would fail every project whose sibling moved
         a major version — the ordinary case in development."
        | work manifest verdict |
        work := self freshDir: 'pl-pin-work'.
        ExecFixtures writePackage: (PathDepFixtures rootDeclaring:
            '../kernel-text') in: work.
        manifest := ManifestFile load: work, '/Package.st'.
        verdict := PinVerification of: manifest
            lock: self resolutionWithPathPin.
        self assert: verdict isValid
            description: verdict problems printString
    ]

    testAPathDependencyMissingFromTheLockIsAProblem [
        "Presence is checked, and this is the half that proves it: a
         declared path dependency with no pin at all means the manifest
         moved since the lock was written."
        | work manifest verdict |
        work := self freshDir: 'pl-missing-work'.
        ExecFixtures writePackage: (PathDepFixtures rootDeclaring:
            '../kernel-text') in: work.
        manifest := ManifestFile load: work, '/Package.st'.
        verdict := PinVerification of: manifest
            lock: (Resolution root: 'my-app' triples: Dictionary new).
        self deny: verdict isValid
            description: 'a missing path pin verified clean'.
        self assert: verdict problems size = 1
            description: verdict problems printString
    ]

    testADevDependencyMissingFromTheLockIsTheSettledProblem [
        "A devDependency: missing from the lock is the SETTLED
         missing-pin problem, byte for byte: dev dependencies are
         ordinary pins with an audience, and inventing a second sentence
         for them would be two wordings for one defect."
        | work manifest verdict |
        work := self freshDir: 'pl-dev-work'.
        ExecFixtures writePackage: (PathDepFixtures
            rootWithDevDependencyOn: 'kernel-lint' constraint: '^1.0.0')
            in: work.
        manifest := ManifestFile load: work, '/Package.st'.
        verdict := PinVerification of: manifest
            lock: (Resolution root: 'my-app' triples: Dictionary new).
        self assert: verdict problems = (Array with:
            'manifest dependency ''kernel-lint'' (>=1.0.0 <2.0.0) is missing from the lock')
            description: verdict problems printString
    ]

    testTheSettledIndexPinWordingsAreByteIdentical [
        "THE DECLARED NON-MOVER for this class: extending over three
         kinds must not re-tone the two sentences the settled kind
         already has."
        | work manifest triples verdict |
        work := self freshDir: 'pl-settled-work'.
        ExecFixtures writePackage: (PathDepFixtures rootDeclaring:
            '../kernel-text' andIndexDependency: 'kernel-a'
            constraint: '^1.0.0') in: work.
        manifest := ManifestFile load: work, '/Package.st'.
        self deny: manifest pathDependencies isEmpty
            description: 'the fixture declares no path dependency, so the three-kind extension is not exercised'.
        triples := Dictionary new.
        triples at: 'kernel-a' put: (Array
            with: (Version fromString: '3.0.0') with: '').
        triples at: 'kernel-text' put: (Array
            with: (Version fromString: '1.2.0') with: '').
        verdict := PinVerification of: manifest
            lock: ((Resolution root: 'my-app' triples: triples)
                withPaths: (self provenanceOfText)).
        self assert: verdict problems = (Array with:
            'lock pins ''kernel-a'' at 3.0.0 outside the manifest constraint >=1.0.0 <2.0.0')
            description: verdict problems printString
    ]
]

Namespace current: Smalltalk.
