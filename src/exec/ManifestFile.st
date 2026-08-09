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
        | file previous |
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

        "THE FILE-IN ITSELF IS DELIBERATELY NOT WRAPPED (Sprint 17).
         The predicate above now lives in Parley.PathGuard, the single
         site performing file I/O, but the file-in below does NOT go
         through its translating seam and that is a ruling rather than
         an omission. The translation is broad, and broad is correct
         only while the block it guards contains nothing but the
         operation (§8 decision 52's discriminator). This block
         contains the AUTHOR'S WHOLE PROGRAM: guarding it would turn a
         vocabulary typo, or a division by zero in somebody's
         Package.st, into a sentence about a path that could not be
         read — the wrong blame, in the one place this project has been
         most careful about blame. What this sprint owes the boundary is
         the predicate; the authoring stream is Sprint 18's subject and
         has a ruling and a class of its own."
        recorded := nil.
        authoringProblems := nil.
        previous := Namespace current.
        loading := true.
        [Namespace current: (Smalltalk at: #Parley).
         FileStream fileIn: aPath]
            ensure: [Namespace current: previous. loading := false].
        "The captured authoring error is checked BEFORE recorded, and
         answered even when a later define: succeeded: otherwise the
         lying 'no manifest defined' diagnosis survives the fix, or a
         half-succeeding Package.st passes silently (Doc E §3, the
         ordering rules)."
        authoringProblems isNil ifFalse: [
            ^ManifestError signalProblems: authoringProblems].
        recorded isNil ifTrue: [
            ^ManifestError signalProblems: (Array with:
                aPath, ': no manifest defined - the file never sent Parley define:')].
        ^recorded
    ]
]

Namespace current: Smalltalk.
