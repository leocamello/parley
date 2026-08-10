"Parley — ManifestFile: loading the developer's OWN Package.st.
 Spec: docs/design/execution-and-cli.md §3; §8 decision 19; issue #8
 S8/S9.
 load: clears the recorded manifest, files the path in with the
 Parley namespace current — inside the namespace the token Parley
 resolves to the Parley.Parley gateway (issue #3), so the Doc B §2
 authoring syntax works verbatim — and answers the manifest recorded
 by define:. A file that recorded nothing signals one ManifestError
 whose single problem names the path (wording pinned in RED).

 The path is checked FIRST (Doc E §3 step 0, Sprint 8 — the third
 declared settled-class exception, granted at the Sprint 8 RED
 review): 3.2.5's FileStream fileIn: signals a kernel
 SystemExceptions.FileError on a missing file, so without this check
 the most ordinary user error in the tool — resolve before parley
 init — reaches the Doc E §4.2 boundary UNDIAGNOSED and is answered
 with exit 70, 'this is a defect in Parley, not in your project'.
 That is the fail-wrong disease in its second form: not a lying exit
 code, but a lying attribution of blame. A missing Package.st is the
 operator's problem, so Parley says so — exit 1, one problem, naming
 the verb that writes one.
 All recording state lives here; the gateway's sole change is the
 declared one-send exception (ManifestFile record: before answering).
 Trust boundary unchanged (architecture §2.2): only the root
 application's own manifest — the file its author owns and runs — is
 ever loaded this way; third-party Package.st files are never
 evaluated by anything, and third-party bytes never reach this class."

Namespace current: Parley.

Object subclass: ManifestFile [

    <comment: 'The decision-19 resolution: files the owner''s own
Package.st in with the Parley namespace current and answers the
LibraryManifest the file''s define: recorded. Holds the recording as
class-side state, cleared per load; a define-less file is a
one-problem ManifestError naming the path.'>

    ManifestFile class [ | recorded authoringProblems loading | ]

    ManifestFile class >> isLoading [
        "Whether a load: is in progress. The authoring boundary in the
         Parley.Parley gateway asks, because it must capture in exactly
         one context — a filed-in Package.st, whose signaling chain is
         cut — and must leave a live `Parley define:` signaling to its
         own caller, which is the settled Sprint 1 contract."
        <category: 'recording'>
        ^loading == true
    ]

    ManifestFile class >> record: aManifest [
        "Remember the manifest a define: just built — the one send the
         Parley.Parley gateway makes before answering (the declared
         settled-class exception, Doc E §3)."
        <category: 'recording'>
        recorded := aManifest
    ]

    ManifestFile class >> recordAuthoringProblems: aCollection [
        "Remember the problems of an authoring error the gateway's
         boundary caught inside a filed-in Package.st (Doc E §3, Sprint
         9). The FIRST one wins: where a file sends define: more than
         once, a broken define: must never be papered over by a later
         one that happens to succeed."
        <category: 'recording'>
        authoringProblems isNil
            ifTrue: [authoringProblems := aCollection asArray]
    ]

    ManifestFile class >> load: aPath [
        "File the developer's own Package.st at aPath in with the
         Parley namespace current and answer the recorded manifest.
         Signals one ManifestError naming the path when the path does
         not exist, and another when the file never sent define:.

         An authoring error the gateway's boundary captured — a
         vocabulary typo, or declarations that failed validation — is
         signaled from HERE, in a frame whose handlers are real (Doc E
         §3, Sprint 9). The problems travel unchanged: the vocabulary
         error's message with its suggestion, or the builder's whole
         batch. Both slots are cleared at entry, so no error and no
         manifest ever leaks from a previous load."
        <category: 'loading'>
        | previous captured anchor |
        "THE PREDICATE IS BROUGHT INTO LINE WITH THE SENTENCE (Doc E §3
         step 0, §8 decision 56, Sprint 16 — the declared settled-class
         exception on this class). This step has read 'does not exist or
         is not readable' since Sprint 8, and the diagnosis below has
         promised 'missing or unreadable Package.st' for just as long,
         while the code checked exists alone. The tool was asserting a
         check it had not made — this sprint's own governing standard,
         broken by a sentence written eight sprints before the standard
         existed.

         Probed against 3.2.5 at the Sprint 16 GREEN review: a
         Package.st the reader lacks permission to open answers
         internal error: FileError: could not open <path> - this is a
         defect in Parley, not in your project, at exit 70, and a
         DIRECTORY-shaped one answers the same with PrimitiveFailed.
         Both are ordinary operator states — a bad umask, a root-owned
         checkout, a stray mkdir — and both were answered by Parley
         blaming itself. The predicate is now the one decision 56 gives
         every file boundary, a regular readable file, and THE WORDING
         DOES NOT MOVE: it was already telling the truth about what this
         step was supposed to do."
        (PathGuard isReadableFile: aPath) ifFalse: [
            ^ManifestError signalProblems: (Array with:
                aPath, ': missing or unreadable Package.st - run parley init to write one')].

        "THE FILE-IN ITSELF IS STILL NOT ROUTED THROUGH PathGuard'S
         TRANSLATING SEAM (Sprint 17), AND IT IS NOW WRAPPED IN A
         Transcript CAPTURE (Sprint 18). The two are different
         mechanisms and the distinction is the ruling.
         The predicate above lives in Parley.PathGuard, the single site
         performing file I/O, but the file-in below does NOT go through
         its translating seam. The translation is broad, and broad is
         correct only while the block it guards contains nothing but the
         operation (§8 decision 52's discriminator). This block
         contains the AUTHOR'S WHOLE PROGRAM: guarding it would turn a
         vocabulary typo, or a division by zero in somebody's
         Package.st, into a sentence about a path that could not be
         read — the wrong blame, in the one place this project has been
         most careful about blame.
         WHAT SPRINT 18 ADDS IS NOT A CATCH BUT A CAPTURE (§8 decision
         61; Doc B §2.2, Doc E §3.1). Parley.ManifestCapture rebinds the
         global Transcript for the duration of a block THIS METHOD
         supplies, and answers what the toolchain wrote as a VALUE. It
         intercepts no error and decides nothing: the file-in and the
         namespace swap stay here, so ManifestFile keeps its seat in the
         §8 decision 60 census and THE CENSUS STAYS AT EIGHT. Putting the
         file-in inside the capture class was rejected on exactly the
         grounds the paragraph above states, one level up.
         THE CAPTURE IS SCOPED TO THE SAME WINDOW AS THE FLAG (Doc E §3).
         isLoading is unchanged: a live Parley define: in an image or a
         test still signals to its own caller, which is the settled
         Sprint 1 contract and the hole Sprint 9 GREEN reopened by
         taking a ruling literally."
        recorded := nil.
        authoringProblems := nil.
        previous := Namespace current.
        loading := true.
        captured := ManifestCapture textFrom: [
            [Namespace current: (Smalltalk at: #Parley).
             FileStream fileIn: aPath]
                ensure: [Namespace current: previous. loading := false]].
        "THE STATED FRAGMENT IS TERMINATED BEFORE ANYTHING IS COMPOSED
         (§8 decision 62 as amended at the RED review). primError writes
         its Object: <receiver> prefix to stdout at C level with NO
         TRAILING NEWLINE, so no rebinding reaches it and, left alone, it
         does not occupy a line at all — it fuses with whatever Parley
         prints next, and the operator reads a third thing that is
         neither composed nor kept.
         THE PREDICATE IS THAT AN ANCHOR WAS RECOVERED, NEVER THAT THE
         CAPTURE IS NON-EMPTY. A Package.st that merely printed on its
         own behalf leaves a non-empty capture and no dangling residue,
         so the weaker predicate would emit a stray blank line on a
         SUCCESSFUL load — at exit 0, where the pin lines are the only
         thing on screen. It fires before the success branch as well as
         the failure ones, because a raise AFTER a successful define:
         leaves the residue just the same; and it fires whoever ends up
         catching the error, because by then the residue is already on
         the terminal."
        anchor := self anchorLineIn: captured.
        anchor isNil ifFalse: [self terminateStatedFragment].
        "The captured authoring error is checked BEFORE recorded, and
         answered even when a later define: succeeded: otherwise the
         lying 'no manifest defined' diagnosis survives the fix, or a
         half-succeeding Package.st passes silently (Doc E §3, the
         ordering rules)."
        authoringProblems isNil ifFalse: [
            ^ManifestError signalProblems:
                (self batchFor: aPath problems: authoringProblems)].
        recorded isNil ifTrue: [
            "THE ANCHOR OUTRANKS THE DEFINE-LESS LINE WHEN THERE IS ONE,
             and it is the same sentence's subject seen properly (§8
             decision 62). Both states record nothing, so both used to
             answer 'no manifest defined' — true of a file that never
             sent define:, and true in the letter about a file whose
             define: block died half way, which is not what its author
             needs to read. When the capture yielded a line number Parley
             says which line, in its own voice. When it did not — the
             parse path, where fileIn: returns normally and the capture is
             empty — the settled literal stands unretoned, because it is
             true of both and the information separating them is already
             on the operator's terminal, on stderr."
            anchor isNil ifFalse: [
                ^ManifestError signalProblems: (Array with:
                    (self anchorProblemFor: aPath line: anchor))].
            ^ManifestError signalProblems: (Array with:
                aPath, ': no manifest defined - the file never sent Parley define:')].
        ^recorded
    ]

    ManifestFile class >> batchFor: aPath problems: someProblems [
        "The authoring problems as ONE PER-FILE BATCH, headed by a
         problem naming the path and the count (§8 decision 44's settled
         shape; Doc E §3.1).

         THE PATH IS ADDED AROUND THE SENTENCES, NEVER INTO THEM. The
         builder's four literals — missing required field name, missing
         required field version, invalid version '...', invalid
         constraint '...' for dependency '...' — and the vocabulary
         error's own message travel through BYTE-IDENTICAL. They are the
         only diagnosis family in the tool that never named the file the
         author must open, and they already say the right thing about
         each field: an author fixes a Package.st per edit-run cycle, not
         per error.

         THE HEADER IS A PROBLEM ENTRY, NOT A NEW MECHANISM. CommandLine
         already renders a ManifestError's problems as the operator's
         lines, so prepending one costs nothing at the §4.2 boundary.
         Composing it in CommandLine instead would have changed the shape
         of SourceError, InstallError, PublishError and LockError too —
         the Sprint 14 add defect's shape, and the reason this lands
         here.

         A SINGLE-PROBLEM MANIFEST GETS THE BATCH SHAPE TOO: decision 44
         gives a file ONE shape, not two, and a bare line for N=1 is how
         a shape acquires a second form nobody declared — the form that
         leaves the commonest single-problem manifest with no path on
         screen."
        <category: 'private-diagnosis'>
        ^(Array with: aPath, ': ', someProblems size printString,
            ' problem(s) in this manifest'), someProblems asArray
    ]

    ManifestFile class >> anchorProblemFor: aPath line: anInteger [
        "Parley's own sentence about a manifest whose statement raised,
         in the settled '<path>: <cause> - <remedy>' grammar (§8 decision
         62).

         IT OPENS WITH THE PATH PARLEY WAS GIVEN, and carries the line
         number the capture yielded. The error's own text is deliberately
         absent: the capture is evidence rather than output, and echoing
         any of it would put the four absolute Parley source paths this
         boundary exists to remove back on the operator's screen — the
         defect moved rather than fixed.

         The remedy directs the reader to the line and asserts no cause
         beyond the one that was measured (§8 decision 58): a statement on
         that line raised, which is exactly what the frame says."
        <category: 'private-diagnosis'>
        ^aPath, ': line ', anInteger printString,
            ' raised an error while the manifest was being read',
            ' - fix that line and try again'
    ]

    ManifestFile class >> anchorLineIn: aCapturedText [
        "The line number of the author's own statement that raised, mined
         from the capture — or nil when the capture carries no such
         frame.

         THIS IS THE ONE THING WORTH KEEPING OUT OF THE CAPTURE (§8
         decision 62). A 3.2.5 dump names its innermost frames first, and
         the innermost frame belonging to the AUTHOR'S file reads
         UndefinedObject>>executeStatements (<file>:<line>) — so the
         FIRST occurrence is the line the author must open, not the line
         the define: send sits on. The doesNotUnderstand: frame one line
         above spells UndefinedObject(...Object)>> and cannot be mistaken
         for it.
         ONLY THE LINE IS MINED, NEVER THE FILE. gst spells the frame's
         file relative to the process working directory, so the capture's
         idea of the path is not the path the operator gave; the
         diagnosis must open with the path Parley already knows. Taking
         the file from here would put a second, different spelling of the
         manifest's name into a diagnosis whose whole point is naming it.
         Nothing else is mined. The error's own text stays in the capture
         with the four absolute Parley source paths beside it, which is
         what this boundary exists to remove."
        <category: 'private-capture'>
        | frameAt closeAt frame digits |
        aCapturedText isNil ifTrue: [^nil].
        frameAt := aCapturedText
            indexOfSubCollection: self authorFrameMarker.
        frameAt = 0 ifTrue: [^nil].
        frame := aCapturedText
            copyFrom: frameAt + self authorFrameMarker size
            to: aCapturedText size.
        closeAt := frame indexOf: $).
        closeAt = 0 ifTrue: [^nil].
        frame := frame copyFrom: 1 to: closeAt - 1.
        digits := frame copyFrom: (self lastColonIn: frame) + 1
            to: frame size.
        ^self lineNumberFrom: digits
    ]

    ManifestFile class >> authorFrameMarker [
        "The frame shape that belongs to a filed-in statement. It carries
         the >> deliberately: the doesNotUnderstand: frame beside it
         reads UndefinedObject(Smalltalk.Object)>>, and matching on the
         class name alone would mine the wrong frame's line."
        <category: 'private-capture'>
        ^'UndefinedObject>>executeStatements ('
    ]

    ManifestFile class >> lastColonIn: aString [
        "Private — the index of the last $: in aString, or 0. 3.2.5 has
         no lastIndexOf:, so the scan is explicit, exactly as
         PathGuard lastSlashIn: is."
        <category: 'private-capture'>
        | last |
        last := 0.
        1 to: aString size do: [:i |
            (aString at: i) = $: ifTrue: [last := i]].
        ^last
    ]

    ManifestFile class >> lineNumberFrom: aString [
        "Private — aString as a positive Integer, or nil when it is not
         all digits. A frame Parley did not recognize must answer NO
         anchor rather than a wrong one: the diagnosis it feeds names a
         line the author is told to open, and a confident wrong line
         number is the fail-wrong this boundary exists to abolish."
        <category: 'private-capture'>
        | value |
        aString isEmpty ifTrue: [^nil].
        value := 0.
        aString do: [:ch |
            (ch isDigit) ifFalse: [^nil].
            value := value * 10 + ch digitValue].
        ^value
    ]

    ManifestFile class >> terminateStatedFragment [
        "End the line primError left dangling on stdout (§8 decision 62
         as amended). One newline through the REAL Transcript — the
         capture has already been restored by the time this runs, which
         is why it is a statement here and not inside the captured
         block.
         It writes a newline and nothing else: the fragment is the
         toolchain's, deliberately kept, and Parley neither echoes nor
         suppresses it. All it does is stop it running into the sentence
         Parley is about to compose."
        <category: 'private-capture'>
        Transcript nl
    ]
]

Namespace current: Smalltalk.
