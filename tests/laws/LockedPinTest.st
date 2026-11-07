"Sprint 25 / issue #27: the lock-write guard compares persisted meaning.
 Nine laws. Three declared RED passes protect existing behavior:
 testACurrentSemanticLockIsAcceptedWithoutRewritingItsBytes;
 testAPathPinIgnoresTheDigestThatItsWireFormDoesNotContain;
 testACorruptLockKeepsItsExistingBoundaryDiagnosis.
 The other six fail against the version-only comparator. All filesystem
 inputs are isolated under tmp/; runners record rather than spawn."

Namespace current: Parley.

TestCase subclass: LockedPinTest [
    | fixtureDirs |

    <comment: 'Persisted pin identity, deterministic diagnosis, root and
existence obligations, byte preservation, and the semantic comparison
bound of the shared locked write site. These laws do not promise that
nonwriting commands take a fresh snapshot.'>

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

    cliIn: aWorkDir runner: aRunner [
        "The private write boundary needs only its lock path and modes.
         Nil collaborators ensure these value-level laws cannot silently
         acquire a source, store or installation dependency."
        ^(CLI in: aWorkDir source: nil store: nil
            target: aWorkDir, '/target' runner: aRunner)
                withModes: #(#locked)
    ]

    problemsFrom: aBlock [
        [aBlock value] on: LockError do: [:error | ^error problems].
        ^#()
    ]

    assertRefusal: expected for: aResolution lock: original in: work [
        | runner cli problems |
        PathDepFixtures writeLock: original in: work.
        runner := RecordingRunner new.
        cli := self cliIn: work runner: runner.
        problems := self problemsFrom: [cli writeLock: aResolution].
        self assert: problems = (Array with: expected)
            description: 'expected ', expected printString,
                ', got ', problems printString.
        self assert: (PathDepFixtures lockTextIn: work) = original
            description: 'a refused locked write changed the original bytes'.
        self assert: runner commands = #()
            description: 'a refused write spawned a command'
    ]

    resolutionWithKind: aKind payload: aPayload [
        ^LockedPinFixtures resolutionRoot: 'my-app'
            tuples: (Array with: (Array with: 'kernel-a' with: '1.0.0'
                with: aKind with: aPayload))
    ]

    testEverySameVersionArchiveDigestChangeIsRefused [
        "Complete digest-state boundary: present-to-present, absent-to-
         present and present-to-absent. Empty is recorded archive
         absence, not a wildcard that accepts replacement bytes."
        | rows |
        rows := Array
            with: (Array with: LockedPinFixtures digestA
                with: LockedPinFixtures digestB)
            with: (Array with: '' with: LockedPinFixtures digestA)
            with: (Array with: LockedPinFixtures digestA with: '').
        1 to: rows size do: [:i |
            | row old new work original expected |
            row := rows at: i.
            old := row at: 1.
            new := row at: 2.
            work := self freshDir: 'lp-digest-', i printString.
            original := LockedPinFixtures lockTextRoot: 'my-app'
                packages: '#(''kernel-a'' ''1.0.0'' #sha256 ',
                    old printString, ')'.
            expected := LockedPinFixtures provenanceRefusalFor: 'kernel-a'
                pinned: '#sha256 ', old printString
                would: '#sha256 ', new printString.
            self assertRefusal: expected
                for: (self resolutionWithKind: #sha256 payload: new)
                lock: original in: work].
        self assert: (CommandLine lockedProvenanceRefusalFor: 'kernel-a'
            pinned: '#sha256 ', '' printString
            would: '#sha256 ', LockedPinFixtures digestA printString)
            = (LockedPinFixtures provenanceRefusalFor: 'kernel-a'
                pinned: '#sha256 ', '' printString
                would: '#sha256 ', LockedPinFixtures digestA printString)
    ]

    testPathChangesKeepLiteralSpellingAndQuotedPayloads [
        "Paths are author-declared strings. An alias spelling and an
         embedded apostrophe are not normalized away, and the diagnosis
         must delimit the complete old and new payloads. No directory
         lookup belongs to the lock comparison itself."
        | rows |
        rows := Array
            with: (Array with: '../first' with: '../second')
            with: (Array with: '../first' with: '.././first')
            with: (Array with: '../author''s first' with: '../author''s second').
        1 to: rows size do: [:i |
            | row work original expected |
            row := rows at: i.
            work := self freshDir: 'lp-path-', i printString.
            original := LockedPinFixtures lockTextRoot: 'my-app'
                packages: '#(''kernel-a'' ''1.0.0'' #path ',
                    (row at: 1) printString, ')'.
            expected := LockedPinFixtures provenanceRefusalFor: 'kernel-a'
                pinned: '#path ', (row at: 1) printString
                would: '#path ', (row at: 2) printString.
            self assertRefusal: expected
                for: (self resolutionWithKind: #path payload: (row at: 2))
                lock: original in: work]
    ]

    testProvenanceKindParticipatesWhenPayloadBytesAreEqual [
        "A digest-shaped relative path and the identical checksum text
         remain different pin forms. Both conversion directions are
         required: comparing only the fourth tuple element passes both
         values while accepting a different source of executable code."
        | kinds payload |
        kinds := #(#path #sha256).
        payload := LockedPinFixtures digestA.
        1 to: 2 do: [:i |
            | oldKind newKind work original expected |
            oldKind := kinds at: i.
            newKind := kinds at: 3 - i.
            work := self freshDir: 'lp-kind-', i printString.
            original := LockedPinFixtures lockTextRoot: 'my-app'
                packages: '#(''kernel-a'' ''1.0.0'' #', oldKind asString,
                    ' ', payload printString, ')'.
            expected := LockedPinFixtures provenanceRefusalFor: 'kernel-a'
                pinned: '#', oldKind asString, ' ', payload printString
                would: '#', newKind asString, ' ', payload printString.
            self assertRefusal: expected
                for: (self resolutionWithKind: newKind payload: payload)
                lock: original in: work]
    ]

    testTheFirstDifferenceComesFromTheSortedUnionOfPinNames [
        "An earlier removal must outrank a later provenance change.
         Conversely an earlier provenance change outranks a later new
         pin. Pin diagnoses precede a root-name difference, retaining
         the already-established package-level diagnosis when possible."
        | work original candidate expected |
        work := self freshDir: 'lp-order-remove'.
        original := LockedPinFixtures lockTextRoot: 'my-app'
            packages: '#(''kernel-z'' ''1.0.0'' #path ''../old'') #(''kernel-a'' ''1.0.0'' #sha256 '''')'.
        candidate := LockedPinFixtures resolutionRoot: 'renamed-app'
            tuples: #(#('kernel-z' '1.0.0' #path '../new')).
        expected := PathDepFixtures lockedRefusalFor: 'kernel-a'
            pinned: '1.0.0' would: PathDepFixtures absentPinText.
        self assertRefusal: expected for: candidate lock: original in: work.
        work := self freshDir: 'lp-order-provenance'.
        original := LockedPinFixtures lockTextRoot: 'my-app'
            packages: '#(''kernel-a'' ''1.0.0'' #path ''../old'')'.
        candidate := LockedPinFixtures resolutionRoot: 'renamed-app'
            tuples: #(#('kernel-z' '1.0.0' #sha256 '')
                #('kernel-a' '1.0.0' #path '../new')).
        expected := LockedPinFixtures provenanceRefusalFor: 'kernel-a'
            pinned: '#path ''../old''' would: '#path ''../new'''.
        self assertRefusal: expected for: candidate lock: original in: work
    ]

    testACurrentSemanticLockIsAcceptedWithoutRewritingItsBytes [
        "Declared RED pass: formatting and tuple discovery order do
         not change a pin. A read-only lock makes an attempted rewrite
         observable even if the writer would emit equivalent values."
        | work original candidate runner cli |
        work := self freshDir: 'lp-semantic-current'.
        original := '#( #''parley-lock'' 1
 #root ''my-app''
 #packages #( #(''kernel-z'' ''1.0.0'' #path ''../z'')
   #(''kernel-a'' ''1.0.0'' #sha256 '''') ) )', SourceFixtures newline.
        PathDepFixtures writeLock: original in: work.
        PathFixtures makeReadOnly: work, '/parley.lock'.
        self deny: (File name: work, '/parley.lock') isWriteable
            description: 'the read-only fixture does not deny writes'.
        candidate := LockedPinFixtures resolutionRoot: 'my-app'
            tuples: #(#('kernel-a' '1.0.0' #sha256 '')
                #('kernel-z' '1.0.0' #path '../z')).
        runner := RecordingRunner new.
        cli := self cliIn: work runner: runner.
        self assert: (self problemsFrom: [cli writeLock: candidate]) = #().
        self assert: (PathDepFixtures lockTextIn: work) = original.
        self assert: runner commands = #()
    ]

    testAPathPinIgnoresTheDigestThatItsWireFormDoesNotContain [
        "Declared RED pass. A path-bearing Resolution can retain an
         internal triple digest, but the writer persists only the path.
         Resolution equality or a blind all-accessors comparison would
         reject a value that writes precisely the same tuple."
        | work original triples paths candidate cli |
        work := self freshDir: 'lp-irrelevant-digest'.
        original := LockedPinFixtures lockTextRoot: 'my-app'
            packages: '#(''kernel-a'' ''1.0.0'' #path ''../a'')'.
        PathDepFixtures writeLock: original in: work.
        triples := Dictionary new.
        triples at: 'kernel-a' put: (Array
            with: (Version fromString: '1.0.0')
            with: LockedPinFixtures digestB).
        paths := Dictionary new.
        paths at: 'kernel-a' put: '../a'.
        candidate := (Resolution root: 'my-app' triples: triples)
            withPaths: paths.
        cli := self cliIn: work runner: RecordingRunner new.
        self assert: (self problemsFrom: [cli writeLock: candidate]) = #().
        self assert: (PathDepFixtures lockTextIn: work) = original
    ]

    testARootOnlyChangeIsRefusedWithTheRootDiagnosis [
        | work original candidate expected |
        work := self freshDir: 'lp-root-only'.
        original := LockedPinFixtures lockTextRoot: 'old-app' packages: ''.
        candidate := LockedPinFixtures resolutionRoot: 'new-app' tuples: #().
        expected := LockedPinFixtures rootRefusalFrom: 'old-app' to: 'new-app'.
        self assertRefusal: expected for: candidate lock: original in: work.
        self assert: (CommandLine lockedRootRefusalFrom: 'old-app' to: 'new-app')
            = expected
    ]

    testAnAbsentLockCannotSatisfyEvenAnEmptyResolution [
        | work candidate cli problems |
        work := self freshDir: 'lp-empty-absent'.
        candidate := LockedPinFixtures resolutionRoot: 'my-app' tuples: #().
        cli := self cliIn: work runner: RecordingRunner new.
        problems := self problemsFrom: [cli writeLock: candidate].
        self assert: problems = (Array with: LockedPinFixtures missingLockedFileText)
            description: problems printString.
        self deny: (File name: work, '/parley.lock') exists.
        self assert: CommandLine missingLockedFileText
            = LockedPinFixtures missingLockedFileText
    ]

    testACorruptLockKeepsItsExistingBoundaryDiagnosis [
        "Declared RED pass. A lock read must remain the settled trust
         boundary before comparison. An invalid artifact cannot be
         treated as an absent pin or repaired by a locked invocation."
        | work original result runner |
        work := self freshDir: 'lp-corrupt-boundary'.
        ExecFixtures writePackage: PathDepFixtures emptyRootContents in: work.
        original := LockBoundaryFixtures unparseableLockContents.
        PathDepFixtures writeLock: original in: work.
        runner := RecordingRunner new.
        result := PathDepFixtures resultOf: #('resolve' '--locked')
            in: work runner: runner.
        self assert: result exitCode = 1.
        self assert: result lines = (Array with:
            (LockBoundaryFixtures unparseableLockProblemFor: work, '/parley.lock')).
        self assert: (PathDepFixtures lockTextIn: work) = original.
        self assert: runner commands = #()
    ]
]

Namespace current: Smalltalk.
