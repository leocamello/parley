"Parley Sprint 18 — the laws of Parley.ManifestCapture (issue #20 S2,
 S3; Doc B §2.2, Doc E §3.1, §8 decisions 61 and 62).

 WHAT THE CLASS IS. It rebinds the global Transcript to a collector,
 evaluates A BLOCK ITS CALLER SUPPLIES, restores the previous binding
 UNCONDITIONALLY in an ensure: — including on non-local exit — and
 answers the collected text as a value. It performs no file I/O and
 makes no policy decision: it captures; the caller decides.

 THE FIRST LAW IN THIS FILE IS THE ONE THAT MATTERS MOST, and it is
 written first on purpose. §8 decision 61 rules that the FileStream
 fileIn: does NOT move into this class, on two independent grounds:

   - the settled Sprint 17 prohibition law searches comment-stripped
     source for four patterns, of which FileStream carries a deliberate
     trailing space so that every class-side send counts, and flags any
     matching class outside the eight-name census — so a ManifestCapture
     containing the file-in is a NINTH census class and
     Sprint17AcceptanceTest testS13 fails, by construction;

   - it would put THE AUTHOR'S WHOLE PROGRAM inside a class whose
     declared job is capture, which is §8 decision 73's precheck yes,
     translate no split re-created one level up, and §8 decision 52's
     discriminator broken: the block a capture guards must contain the
     operation and nothing else.

 testTheCaptureSitePerformsNoDirectFileIo asserts that directly, over
 this class's own source and the settled census patterns, so the ruling
 is a MECHANISM rather than a memory — and so the rejected design is
 caught here, by name, instead of being noticed one suite over as a
 census that grew to nine.

 RESTORATION IS THE WORST FAILURE MODE IN THE SPRINT, and it is why two
 laws drive it separately. A leaked swap does not fail loudly: IT
 SILENCES THE REST OF THE PROCESS. In this suite that means a whole run
 of laws asserting on output they can no longer see — and, one level up,
 scripts/run-tests.st writes its own PARLEY-VERIFY sentinel through
 Transcript, so a leak makes the gate report a suite that never
 finished. The ordinary failure path and the non-local-exit path are
 checked one law each.

 THE BOUND, STATED (§8 decision 43): these laws are about the binding
 and the value, and they say nothing about what the toolchain chooses to
 write. What text reaches which stream is asserted where it can be seen,
 on captured stdout and stderr from the shipped binary, in
 AuthoringDiagnosisTest.

 RED CLASSIFICATION (method finding F14, ruled at the Sprint 17
 close-out): every law here is fronted by a reference to
 Parley.ManifestCapture, which does not exist against the pre-sprint
 tree, so every one of them ABORTS AT ITS FIRST REFERENCE and is an
 ERROR rather than a FAILURE. Their drivers, oracles and assertions do
 not execute, and the red gate says nothing about them. Two real defects
 hid in exactly that blind spot last sprint. No law here is a declared
 pass in red."

Namespace current: Parley.

TestCase subclass: ManifestCaptureTest [
    | previousTranscript |

    <comment: 'Laws for Parley.ManifestCapture: the collected text
answered as a value, restoration on the ordinary path, on the failure
path and on a non-local exit, and the prohibition — asserted over this
class''s own source — that the capture site performs no direct file
I/O.'>

    setUp [
        previousTranscript := Smalltalk at: #Transcript
    ]

    tearDown [
        "A LEAK HERE WOULD SILENCE EVERY SUITE THAT RUNS AFTER THIS ONE,
         including the runner's own sentinel, so the teardown restores
         the binding whatever the law did. It is a safety net, never the
         thing under test: each law asserts restoration itself, because
         a net that fixes the defect would also hide it."
        previousTranscript isNil ifFalse: [
            Smalltalk at: #Transcript put: previousTranscript]
    ]

    realTranscript [
        ^previousTranscript
    ]

    assertTranscriptRestored: aLabel [
        "Restoration, asserted twice over: the binding IS the object it
         was, and a send through it still reaches the real collector
         rather than a stream nobody is reading."
        self assert: (Smalltalk at: #Transcript) == self realTranscript
            description: aLabel,
                ' left Transcript bound to something else'.
        self assert: (Smalltalk at: #Transcript) class
            == self realTranscript class
            description: aLabel, ' left Transcript a ',
                (Smalltalk at: #Transcript) class name
    ]

    "---- the law that makes decision 61 a mechanism ----"

    testTheCaptureSitePerformsNoDirectFileIo [
        "§8 DECISION 61, ASSERTED RATHER THAN REMEMBERED. The class
         introduced to OBSERVE this boundary must not acquire the
         boundary's I/O in order to observe it, or the observer becomes
         a site the prohibition has to exempt — and the census, which
         §8 decision 60 fixes at eight, would have to grow to nine.

         It is measured with the settled patterns rather than with new
         ones: PathFixtures directIoSendSources is the same declaration
         Sprint 17's prohibition searches with, so this law and that one
         cannot disagree about what direct file I/O is.

         THE BOUND IS THE SETTLED ONE (decision 43): a textual search
         over comment-stripped, whitespace-normalized source. I/O
         reached through a temporary or assembled by perform: stays
         invisible here exactly as it does there, and the behaviour half
         of the sprint is what holds the class to it."
        | code offenders |
        code := LockSchemaFixtures normalizedCodeOf:
            (PathFixtures contentsOf: self captureSourcePath).
        self deny: code isEmpty
            description: 'the capture class has no source to search - the law would pass over nothing'.
        offenders := PathFixtures directIoSendSources
            select: [:each | LockSchemaFixtures does: code include: each].
        self assert: offenders isEmpty
            description: 'ManifestCapture performs direct file I/O: ',
                offenders printString,
                ' - the file-in stays in ManifestFile and the census stays at eight'.
        self deny: (PathFixtures ioSiteClassNames
            includes: self captureClassName)
            description: 'the src/ I/O census now names the capture class - it has become a ninth site'
    ]

    captureSourcePath [
        "The class's own source, where §8 decision 61 puts it: with the
         manifest classes, whose directory scripts/run-tests.st already
         files in AND files in before src/exec/, where its one caller
         lives — so the harness is unchanged."
        ^'src/manifest/ManifestCapture.st'
    ]

    captureClassName [
        ^'ManifestCapture'
    ]

    "---- the collected text is answered as a value ----"

    testTheCollectedTextIsAnsweredAsAValue [
        "The whole of what the class answers: what the block wrote
         through Transcript, as a String the caller owns. A capture that
         printed, logged or stored anything would be making the policy
         decision the caller makes."
        | text |
        text := ManifestCapture textFrom: [Transcript showCr: 'muttered'].
        self assert: (CommandLineFixtures does: text include: 'muttered')
            description: 'the capture answered ', text printString.
        self assertTranscriptRestored: 'a captured showCr:'
    ]

    testAQuietBlockIsCapturedAsEmptyText [
        "A block that says nothing answers empty text rather than nil —
         the caller asks the text a question, and nil would make every
         caller test for it. This is also the shape the parse path takes
         (Doc B §2.2): fileIn: returns normally, nothing is recorded,
         and the capture is empty, which is why the settled
         no manifest defined literal is not re-toned."
        | text |
        text := ManifestCapture textFrom: [17 factorial].
        self assert: text isEmpty
            description: 'a quiet block was captured as ', text printString.
        self assertTranscriptRestored: 'a quiet capture'
    ]

    testTheBlocksOwnWritingNeverReachesTheRealTranscript [
        "The point of the class, stated as a law: text written inside the
         window goes to the collector, and the terminal never sees it.
         Asserted by capturing the OUTER Transcript around an inner
         capture — if the swap leaked through, the outer capture would
         hold the inner text."
        | outer |
        outer := ManifestCapture textFrom: [
            ManifestCapture textFrom: [Transcript showCr: 'inner']].
        self deny: (CommandLineFixtures does: outer include: 'inner')
            description: 'the inner text escaped its own capture: ',
                outer printString.
        self assertTranscriptRestored: 'nested captures'
    ]

    "---- S3: restoration on the ordinary failure path ----"

    testTranscriptIsRestoredWhenTheBlockSignals [
        "The ordinary failure path: the block raises and the error
         travels out. The binding must be back before the handler runs,
         because the handler is where a diagnosis gets composed and
         printed.

         THE HANDLER NAMES ManifestError AND NOT Error, and that is not a
         stylistic preference: an on: Error handler here also catches the
         doesNotUnderstand: this law raises against the pre-sprint tree,
         where ManifestCapture does not exist — so the law would PASS in
         red, trivially, and be an undeclared pass (finding F10) in the
         one file whose every law must fail. It is the same rule §8
         decision 52 states for product code, applied to a test: a catch
         names the errors it exists for and no others."
        | escaped |
        escaped := false.
        [ManifestCapture textFrom: [ManifestError signalProblems:
            (Array with: 'the author''s program failed')]]
            on: ManifestError
            do: [:e |
                escaped := true.
                self assertTranscriptRestored: 'a signaling block, inside the handler'.
                e return: nil].
        self assert: escaped
            description: 'the error never left the capture - the capture is swallowing errors, which is the caller''s decision to make'.
        self assertTranscriptRestored: 'a signaling block'
    ]

    "---- S2: restoration on a non-local exit ----"

    testTranscriptIsRestoredOnANonLocalExit [
        "THE WORST FAILURE MODE IN THE SPRINT, driven directly. A method
         return out of the captured block unwinds past the capture
         without signaling anything, so nothing but an ensure: can put
         the binding back — and a leak here is silent: it does not fail,
         it makes every later law blind."
        | answer |
        answer := self escapeThroughACapture.
        self assert: answer == #escaped
            description: 'the non-local exit did not carry: ',
                answer printString.
        self assertTranscriptRestored: 'a non-local exit'
    ]

    escapeThroughACapture [
        "A method return from inside the captured block. The ^ leaves
         this method, unwinding through the capture on the way."
        ManifestCapture textFrom: [^#escaped].
        ^#fellThrough
    ]

    testTranscriptIsRestoredWhenTheBlockIsNonLocalAndTheCaptureIsNested [
        "The same unwind through TWO capture windows, because a
         restoration written as a single assignment rather than a saved
         previous binding passes the one-level law and fails here."
        | answer |
        answer := self escapeThroughNestedCaptures.
        self assert: answer == #escaped
            description: 'the nested non-local exit did not carry: ',
                answer printString.
        self assertTranscriptRestored: 'a nested non-local exit'
    ]

    escapeThroughNestedCaptures [
        ManifestCapture textFrom: [
            ManifestCapture textFrom: [^#escaped]].
        ^#fellThrough
    ]
]

Namespace current: Smalltalk.
