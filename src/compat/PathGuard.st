"Parley — PathGuard: the single site in Parley that performs file I/O.
 Spec: docs/design/execution-and-cli.md §4.1; docs/design/publish-and-sources.md
 §1; §8 decisions 59 (as amended), 60 and 72; issue #19.

 WHY THIS CLASS EXISTS. Decision 56 ruled that a boundary reading a
 file must first require a regular readable path, and Sprint 16 applied
 it to three boundaries. Six ordinary filesystem states still answered
 internal error: ... - this is a defect in Parley, not in your project
 at exit 70, three of them naming no path at all, and five of the six
 were the rule's mirror: decision 56 governs READING, and nothing
 governed WRITING. A read-only checkout, a root-owned file and a
 chmod -R a-w cache are OPERATOR states; exit 70's sentence is a false
 attribution of blame in every one of them.

 IT DOES TWO THINGS, AND NEITHER ONE ALONE IS ENOUGH.

 It PRECHECKS, so a refusal happens BEFORE anything is created. That is
 the atomicity publish and add need: a check folded into the write can
 only report a failure the write already caused, and by then the stage
 directory exists and the manifest has been replaced.

 And it TRANSLATES, wrapping the operation itself in a BROAD catch that
 turns any error into the boundary's own declared refusal naming the
 path. A precheck alone would enumerate the failure modes somebody
 thought of — the mistake one level down from the one this class
 exists to correct — and on this toolchain it demonstrably does not
 hold: a write to a read-only file and a create in a read-only
 directory both raise a catchable SystemExceptions.FileError, but
 reading a DIRECTORY raises SystemExceptions.WrongClass and escapes a
 handler written for FileError. Enumerating error classes is the same
 trap as enumerating states, so nothing here enumerates either.

 BROAD IS CORRECT HERE, AND IT DOES NOT CONTRADICT §8 DECISION 52.
 That decision governs a catch that DEFERS to another boundary, which
 must name that boundary's errors and no others. This catch OWNS the
 diagnosis, and the block it guards contains nothing but the operation.
 THE DISCRIMINATOR IS WHETHER THE GUARDED BLOCK CONTAINS ANYTHING
 BESIDES THE OPERATION, which is why every operation below opens its
 own stream and why a caller that must serialize renders to a String
 first and hands the bytes here: a writer's failure is the writer's
 diagnosis, not this path's.

 The refusal block is evaluated OUTSIDE the guarded block — it is the
 handler, not part of what is protected — so a boundary's own declared
 error travels out unmolested and can never be re-translated.

 TWO PREDICATES, BECAUSE THE TOOLCHAIN FORCES TWO (probed, 3.2.5).
 Overwriting an existing file needs isFile and isWriteable; creating a
 new one needs its PARENT directory to satisfy isDirectory and
 isWriteable, because isWriteable answers FALSE for a path that does
 not exist exactly as isFile does. ABSENCE IS NOT UNWRITABILITY: a
 single-predicate write check would turn every first resolve in a fresh
 project into a permissions error, which is the Sprint 16 isFile trap
 one predicate over. Note the spelling — 3.2.5 has isWriteable, with
 an e; isWritable does not exist and raises a DNU.

 IT LIVES IN src/compat/ because it is toolchain adaptation: 3.2.5's
 spelling, its absent-path semantics, and the traps both carry. It
 references no other Parley class — every diagnosis is composed by the
 caller's own refusal block, which is what lets each settled read
 sentence stay byte-identical while the write side gains a new one.

 THE PRECHECK IS NOT A LOCK, and the translation is what makes that
 harmless (Doc E §4.1). A path can become unwritable between the check
 and the write, and Parley claims nothing about that window. What it
 does claim is the narrower thing: if the window is hit — or if a
 read-only mount, a full disk or an immutable flag fails — the caller
 still receives its own declared error naming the path, at exit 1, and
 never the sentence that says the tool is broken."

Namespace current: Parley.

Object subclass: PathGuard [

    <comment: 'The single site in Parley performing file I/O: the two
write predicates and the read predicate, the diagnosis composition,
and every filesystem operation the tool makes — each prechecked and
each wrapped in a broad translation that answers the caller''s own
refusal naming the path. Stateless and class-side throughout; it holds
no policy and makes no choice about whose fault anything is.'>

    "---- the predicates (§8 decision 59; probed against 3.2.5) ----"

    PathGuard class >> isReadableFile: aPath [
        "Whether aPath is a REGULAR READABLE file — decision 56's rule,
         in the one place it now lives. False for a directory (which
         answers true to exists, and signals a kernel WrongClass from
         contents), false for a file whose permissions deny the reader
         (which also answers true to exists), and false for a path that
         is simply not there."
        <category: 'predicates'>
        | file |
        file := File name: aPath.
        ^file isFile and: [file isReadable]
    ]

    PathGuard class >> isReadableDirectory: aPath [
        "Whether aPath is a directory whose entries can be listed. The
         scan's predicate: a directory the reader cannot open answers
         true to isDirectory and fails inside files."
        <category: 'predicates'>
        | file |
        file := File name: aPath.
        ^file isDirectory and: [file isReadable]
    ]

    PathGuard class >> isWritableFile: aPath [
        "THE OVERWRITE PREDICATE: an existing regular file this process
         may replace. A directory fails isFile, and an absent path fails
         both halves — absence is answered by the CREATE predicate,
         and keeping the two apart is what stops either from covering
         for the other."
        <category: 'predicates'>
        | file |
        file := File name: aPath.
        ^file isFile and: [file isWriteable]
    ]

    PathGuard class >> isWritableDirectory: aPath [
        "Whether aPath is a directory this process may create entries
         in. False for a read-only directory AND for one that is not
         there — isWriteable cannot tell those apart on its own, which
         is why every caller asks this rather than isWriteable."
        <category: 'predicates'>
        | file |
        file := File name: aPath.
        ^file isDirectory and: [file isWriteable]
    ]

    PathGuard class >> isCreatable: aPath [
        "THE CREATE PREDICATE: whether aPath can be brought into
         existence, which is a question about its PARENT directory and
         never about aPath itself. isWriteable answers false for a path
         that does not exist, so asking it of the path being created
         refuses every first write a project ever makes."
        <category: 'predicates'>
        ^self isWritableDirectory: (self parentOf: aPath)
    ]

    PathGuard class >> isWritablePath: aPath [
        "The two predicates as one question, for a caller that does not
         know yet whether it is overwriting or creating — resolve
         writing parley.lock is exactly that caller. An existing file
         must be overwritable; anything else must be absent AND
         creatable, so a path that exists as a DIRECTORY is refused
         rather than mistaken for a first write."
        <category: 'predicates'>
        (self exists: aPath) ifTrue: [^self isWritableFile: aPath].
        ^self isCreatable: aPath
    ]

    "---- path arithmetic (no I/O) ----"

    PathGuard class >> parentOf: aPath [
        "The directory aPath lives in. '.' when aPath names no
         directory at all, '/' when it lives at the root. 3.2.5 has no
         lastIndexOf:, so the scan is explicit."
        <category: 'paths'>
        | last |
        last := self lastSlashIn: aPath.
        last = 0 ifTrue: [^'.'].
        last = 1 ifTrue: [^'/'].
        ^aPath copyFrom: 1 to: last - 1
    ]

    PathGuard class >> baseNameOf: aPath [
        "The last component of aPath — how a batched diagnosis names
         the file its operator can act on."
        <category: 'paths'>
        | last |
        last := self lastSlashIn: aPath.
        ^aPath copyFrom: last + 1 to: aPath size
    ]

    PathGuard class >> lastSlashIn: aPath [
        "Private — the index of the last $/ in aPath, or 0."
        <category: 'paths'>
        | last |
        last := 0.
        1 to: aPath size do: [:i |
            (aPath at: i) = $/ ifTrue: [last := i]].
        ^last
    ]

    "---- the diagnosis composition ----"

    PathGuard class >> lineFor: aPath saying: aTailString [
        "The settled '<path>: <cause>' grammar every file diagnosis in
         the tool uses, composed in ONE place so no two boundaries can
         spell the same shape differently. The tail is the caller's:
         each settled read sentence stays byte-identical, and the write
         side gets the one below."
        <category: 'diagnosis'>
        ^aPath, ': ', aTailString
    ]

    PathGuard class >> unwritableTail [
        "THE WRITE-SIDE CAUSE AND REMEDY, defined once for every write
         boundary (§8 decision 59). It names the OUTCOME rather than the
         state because one sentence serves both the precheck and the
         translation: the precheck knows the path failed isWriteable,
         but the translation path — the TOCTOU window, a read-only
         mount, a full disk, an immutable flag — knows only that the
         write did not happen. Saying the path is not writable would be
         a claim the translation has not checked, which is §8 decision
         58's standard broken inside the sprint that makes it a law.
         The remedy directs the reader where to look; it asserts no
         cause, so it claims nothing either."
        <category: 'diagnosis'>
        ^'could not be written - check its permissions and try again'
    ]

    PathGuard class >> unreadableTail [
        "The read-side cause and remedy for a boundary that has no
         settled sentence of its own — the TOCTOU mirror of the tail
         above, and true on the same terms: it names the outcome, not a
         state nobody checked. The boundaries that DO carry a settled
         sentence keep it; this exists so a new read site never has to
         invent one."
        <category: 'diagnosis'>
        ^'could not be read - check its permissions and try again'
    ]

    PathGuard class >> unwritableLineFor: aPath [
        "The whole write refusal for aPath. Every write boundary uses
         this rather than restating the tail: a second copy of a
         sentence is the drift this sprint exists to prevent, exactly
         as a second copy of a predicate would be."
        <category: 'diagnosis'>
        ^self lineFor: aPath saying: self unwritableTail
    ]

    "---- the seams: translation, and precheck-then-translation ----"

    PathGuard class >> at: aPath do: anOperationBlock ifRefused: aRefusalBlock [
        "THE TRANSLATION SEAM, and the whole of the broad catch. Answer
         anOperationBlock's value; on ANY error, answer
         aRefusalBlock value: aPath — which signals the boundary's own
         declared error and therefore does not return.

         The refusal is evaluated in the HANDLER, outside the protected
         block, so the declared error it signals travels out rather
         than being caught and re-translated by this same guard.

         Enumerating error classes here would be the trap this class
         exists to close: a write to a read-only file raises
         SystemExceptions.FileError, but reading a directory raises
         SystemExceptions.WrongClass, and the modes nobody listed — a
         full disk, an immutable flag, a vanished mount — raise
         whatever they raise."
        <category: 'seams'>
        ^[anOperationBlock value]
            on: Error
            do: [:e | aRefusalBlock value: aPath]
    ]

    PathGuard class >> reading: aPath do: anOperationBlock ifRefused: aRefusalBlock [
        "Precheck the read predicate, then translate. The precheck is
         what turns the common cases — a directory, an unreadable file,
         an absent one — into the boundary's own sentence rather than a
         kernel error at exit 70."
        <category: 'seams'>
        (self isReadableFile: aPath) ifFalse: [^aRefusalBlock value: aPath].
        ^self at: aPath do: anOperationBlock ifRefused: aRefusalBlock
    ]

    PathGuard class >> readingDirectory: aPath do: anOperationBlock ifRefused: aRefusalBlock [
        "The same, for a boundary that lists a directory rather than
         reading a file."
        <category: 'seams'>
        (self isReadableDirectory: aPath)
            ifFalse: [^aRefusalBlock value: aPath].
        ^self at: aPath do: anOperationBlock ifRefused: aRefusalBlock
    ]

    PathGuard class >> writing: aPath do: anOperationBlock ifRefused: aRefusalBlock [
        "Precheck whichever write predicate aPath calls for, then
         translate. The refusal happens BEFORE the operation, which is
         the atomicity publish and add need: a refused write leaves the
         filesystem exactly as it found it."
        <category: 'seams'>
        (self isWritablePath: aPath) ifFalse: [^aRefusalBlock value: aPath].
        ^self at: aPath do: anOperationBlock ifRefused: aRefusalBlock
    ]

    PathGuard class >> creating: aPath do: anOperationBlock ifRefused: aRefusalBlock [
        "Precheck the CREATE predicate — the parent directory — then
         translate. For a path that must not exist yet: a new directory,
         a staged file."
        <category: 'seams'>
        (self isCreatable: aPath) ifFalse: [^aRefusalBlock value: aPath].
        ^self at: aPath do: anOperationBlock ifRefused: aRefusalBlock
    ]

    "---- the operations: every file I/O the tool performs ----"

    PathGuard class >> contentsOf: aPath ifRefused: aRefusalBlock [
        "The whole bytes of aPath."
        <category: 'operations'>
        ^self reading: aPath
            do: [(File name: aPath) contents]
            ifRefused: aRefusalBlock
    ]

    PathGuard class >> write: aByteString to: aPath ifRefused: aRefusalBlock [
        "aByteString as the complete contents of aPath.

         A caller that SERIALIZES renders to a String first and hands
         the bytes here, rather than handing a stream to a writer: the
         guarded block must contain nothing but the operation, or a
         writer's own failure would be translated into a path refusal
         and the blame would land on the wrong party (§8 decision 52's
         discriminator)."
        <category: 'operations'>
        ^self writing: aPath
            do: [| stream |
                stream := (File name: aPath) writeStream.
                [stream nextPutAll: aByteString] ensure: [stream close]]
            ifRefused: aRefusalBlock
    ]

    PathGuard class >> createDirectory: aPath ifRefused: aRefusalBlock [
        "Create aPath as a directory. 3.2.5's Directory create: signals
         a FileError on an existing path, so callers that mean ensure
         send ensureDirectory:ifRefused: instead."
        <category: 'operations'>
        ^self creating: aPath
            do: [Directory create: aPath]
            ifRefused: aRefusalBlock
    ]

    PathGuard class >> ensureDirectory: aPath ifRefused: aRefusalBlock [
        "Create aPath when it is absent; answer quietly when it is
         already a directory."
        <category: 'operations'>
        (self isDirectory: aPath) ifTrue: [^aPath].
        ^self createDirectory: aPath ifRefused: aRefusalBlock
    ]

    PathGuard class >> remove: aPath ifRefused: aRefusalBlock [
        "Remove aPath — a file, or a directory already emptied. Silent
         when it is not there, because removing what is not there is
         what the caller asked for."
        <category: 'operations'>
        (self exists: aPath) ifFalse: [^aPath].
        ^self at: aPath
            do: [(File name: aPath) remove]
            ifRefused: aRefusalBlock
    ]

    PathGuard class >> filePathsIn: aPath ifRefused: aRefusalBlock [
        "The REGULAR FILES of the directory aPath, as full paths, in
         sorted order. 3.2.5's File>>files answers regular files only
         and never recurses — the enumeration trap Sprint 8's drift law
         was bitten by, recorded here because this is now the only place
         the send lives."
        <category: 'operations'>
        ^self readingDirectory: aPath
            do: [((File name: aPath) files collect: [:each | each name])
                asSortedCollection asArray]
            ifRefused: aRefusalBlock
    ]

    PathGuard class >> entryNamesIn: aPath ifRefused: aRefusalBlock [
        "Every entry name of the directory aPath except . and .., in
         sorted order — the enumeration that SEES subdirectories, which
         File>>files does not."
        <category: 'operations'>
        ^self readingDirectory: aPath
            do: [| names |
                names := OrderedCollection new.
                (File name: aPath) namesDo: [:each |
                    (#('.' '..') includes: each)
                        ifFalse: [names add: each]].
                (names asSortedCollection: [:a :b | a <= b]) asArray]
            ifRefused: aRefusalBlock
    ]

    "---- the questions: predicates a caller asks without operating ----"

    PathGuard class >> exists: aPath [
        "Whether anything at all is at aPath. Deliberately NOT a
         readability or writability question: every boundary that goes
         on to read or write asks one of the predicates above, and this
         one exists for the callers whose whole question is presence —
         init refusing an existing Package.st, publish refusing an
         existing release."
        <category: 'questions'>
        ^(File name: aPath) exists
    ]

    PathGuard class >> isFile: aPath [
        <category: 'questions'>
        ^(File name: aPath) isFile
    ]

    PathGuard class >> isDirectory: aPath [
        <category: 'questions'>
        ^(File name: aPath) isDirectory
    ]

    PathGuard class >> workingDirectory [
        "The process working directory. It is here rather than at its
         one caller because this class is the single site performing
         file I/O, and a directory the process is standing in is a
         filesystem question like any other."
        <category: 'questions'>
        ^Directory workingName
    ]
]

Namespace current: Smalltalk.
