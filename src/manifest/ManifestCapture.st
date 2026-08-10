"Parley — ManifestCapture: the toolchain's own voice, captured as a value.
 Spec: docs/design/manifest-and-serialization.md §2.2;
 docs/design/execution-and-cli.md §3.1; §8 decisions 61 and 62; issue #20.

 WHY THIS CLASS EXISTS. Package.st is EXECUTED, which makes the authoring
 boundary the one place in Parley where text reaches the user's terminal
 that Parley did not write. A manifest whose define: block raises answered
 eleven lines of kernel backtrace — four of them absolute paths into
 Parley's own source tree — above one correct sentence, and a user reading
 that concludes Parley crashed. The tool's own laws denied backtraces and
 PASSED, because they assert over the CliResult's composed lines while
 that text reaches the terminal by another route entirely. This class is
 that other route, made into a value.

 IT DOES ONE THING. It rebinds the global Transcript to a collector,
 evaluates A BLOCK ITS CALLER SUPPLIES, restores the previous binding
 unconditionally through an ensure:, and answers the collected text. It
 captures; THE CALLER DECIDES. No policy lives here: what is discarded,
 what is mined, and what is composed are all ManifestFile's business
 (§8 decision 62).

 IT PERFORMS NO FILE I/O, AND THAT IS THE LOAD-BEARING HALF OF ITS SHAPE
 RATHER THAN AN INCIDENTAL PROPERTY (§8 decision 61). The file-in stays
 in ManifestFile. Two independent reasons, and the ruling rejected the
 alternative on both. First, §8 decision 60's prohibition law searches
 comment-stripped source for four send shapes and flags any matching class
 outside the eight-name census, so a capture class holding the file-in
 would be a NINTH census class and Sprint17AcceptanceTest testS13 would
 fail by construction. Second, it would put THE AUTHOR'S WHOLE PROGRAM
 inside a class whose declared job is capture — §8 decision 73's
 precheck yes, translate no split re-created one level up, and §8 decision
 52's discriminator broken: the block a capture guards must contain the
 operation and nothing else. THE CENSUS STAYS AT EIGHT, and
 ManifestCaptureTest asserts that over this file's own source so the rule
 is a mechanism rather than a memory.

 RESTORATION IS UNCONDITIONAL, AND IT IS THE WORST FAILURE MODE IN THE
 SPRINT. A leaked swap does not fail loudly: IT SILENCES THE REST OF THE
 PROCESS. In the shipped binary that means a verb whose diagnosis never
 reaches the terminal while its exit code says something went wrong; in
 the test suite it means a whole run of laws asserting on output they can
 no longer see, and scripts/run-tests.st writes its own PARLEY-VERIFY
 sentinel through Transcript, so a leak makes the gate report a suite that
 never finished. Hence the ensure:, hence the SAVED previous binding
 rather than an assumed one — nested captures restore in the right order
 only if each remembers what it displaced — and hence two laws driving the
 ordinary failure path and the non-local exit separately.

 THE COLLECTOR IS FLUSHED BEFORE THE BINDING IS PUT BACK, and the order is
 deliberate: a TextCollector buffers, so text written without a trailing
 newline is still in the collector when the window closes (probed on
 3.2.5). Flushing after the restore would flush the REAL Transcript and
 lose the tail. The flush is the first statement of the ensure: block so
 it runs on the non-local-exit path too.

 THE SCOPING IS THE FLAG'S SCOPING, and that is ManifestFile's
 responsibility rather than this class's: a live Parley define: outside a
 load still signals to its own caller (Doc E §3, the settled Sprint 1
 contract, the hole Sprint 9 GREEN reopened by taking a ruling
 literally). This class captures whatever window it is handed."

Namespace current: Parley.

Object subclass: ManifestCapture [

    <comment: 'The authoring boundary observed as a value: rebinds the
global Transcript to a collector for the duration of a block its caller
supplies, restores the previous binding unconditionally in an ensure:,
and answers the collected text. Performs no file I/O and makes no policy
decision - it captures, the caller decides. Stateless and class-side.'>

    ManifestCapture class >> textFrom: aBlock [
        "Evaluate aBlock with the global Transcript rebound to a
         collector, and answer everything aBlock wrote through it.

         The block's own value is deliberately NOT answered: the caller
         asks this class one question, which is what the toolchain said.
         ManifestFile's block files a manifest in for its recording side
         effect and has no value worth carrying.

         An error raised inside aBlock TRAVELS OUT untouched — a capture
         that swallowed it would be making the caller's decision (§8
         decision 61).

         WHEN THE BINDING COMES BACK, STATED PRECISELY (§8 decision 75,
         probed on 3.2.5; the imprecise version of this sentence is what
         made a reviewed law unsatisfiable at GREEN). An ensure: block
         runs on the UNWIND, and a handler runs on top of the still-live
         signaling context, so the measured order is block, handler,
         ensure. For an error signaled INSIDE this window the binding is
         therefore still the collector while a handler for it runs, and
         it is back by the time that handler returns and the caller
         resumes. UNCONDITIONAL IS NOT IMMEDIATE.

         No ensure:-based capture can do better. The alternative —
         catching the error here and sending pass, which really does
         restore before the outer handler — is NOT refused for
         swallowing, because pass swallows nothing. It is refused because
         it would wrap THE AUTHOR'S WHOLE PROGRAM in a broad catch, where
         §8 decision 61 requires the block a capture guards to contain
         the operation and nothing else and where §8 decision 52's
         discriminator turns; and because re-signaling across this
         boundary disturbs the signaling chain Doc E §3's isLoading
         scoping rests on — the hole Sprint 9 GREEN reopened.

         THE CONSUMER CONSTRAINT, STATED RATHER THAN DISCOVERED
         (decision 43): any handler for an error raised inside this
         window runs with Transcript still swapped and MUST NOT PRINT.

         THE BOUNDARY IS NOT AFFECTED BY THAT, and this is why it is
         worth stating rather than glossing: ManifestFile signals its
         authoring diagnoses from its OWN frame, after the window has
         closed, so every handler that composes a diagnosis already sees
         the real Transcript. Composing is printing one frame later, and
         the capture is gone by then."
        <category: 'capturing'>
        | collected previous |
        collected := WriteStream on: String new.
        previous := Smalltalk at: #Transcript.
        [Smalltalk at: #Transcript put:
            (TextCollector message: collected -> #nextPutAll:).
         aBlock value]
            ensure: [
                Transcript flush.
                Smalltalk at: #Transcript put: previous].
        ^collected contents
    ]
]

Namespace current: Smalltalk.
