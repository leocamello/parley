"Parley — Configuration: the project's own parley.config.st, read as values.
 Spec: docs/design/manifest-and-serialization.md §5.7; docs/design/execution-and-cli.md
 §4.1 and §4.2; §8 decisions 64 and 65; issue #21 S6, S7, S9, S10, S12.

 WHY IT EXISTS. --source, --git and --index were retyped on every
 command, with no way to record the choice, so the first thing anyone
 learned about Parley was that it would not remember where their index
 is. Every package manager this project benchmarks against has a
 project-level configuration file.

 IT READS AND ANSWERS VALUES. IT DECIDES NO PRECEDENCE (§8 decision 64).
 CommandLine decides, because precedence is wiring and wiring is already
 CommandLine's declared job — and because a class that both read the
 file and chose when to prefer it would be the only place in the tool
 where a policy hid inside a reader.

 THE FILE IS AT THE PROJECT ROOT, NOT UNDER .parley/ (§8 decision 64).
 That directory is regenerable state — the store, the caches, the
 packages target — which an operator may delete to clean a project, and
 configuration is theirs and must survive it. The three root files then
 have three clear owners: the author writes Package.st, Parley writes
 parley.lock, the operator writes parley.config.st.

 THE FORMAT IS THE SETTLED MICRO-FORMAT AND THE READER IS THE SETTLED
 READER (Doc B §5.7). No third-party serialization, ever (Doc B §2.4),
 and no second reader — a second reader would give one malformed file a
 second wording. #'parley-config' joins IndexEntryReader's whitelist as
 a DECLARED settled-class exception, because the whitelist is enforced
 inside readFrom: and an unlisted tag is refused there.

 THE READ IS A BOUNDARY LIKE EVERY OTHER (§8 decision 65), held to the
 settled shape from the day it exists rather than after it fails: a
 regular readable file, parsing, carrying the tag and a supported format
 version, and BODY-SHAPE VALIDATED before any value reaches a consumer.
 Each failure answers ONE line naming the path, stating a cause that was
 checked and offering a remedy that works, at exit 1 — never a kernel
 class and never exit 70.

 ABSENCE IS NOT A DEFECT. A project with no configuration file answers
 nil for every flag, which is what keeps the whole feature additive:
 every settled scenario runs without one.

 THE CENSUS STAYS AT EIGHT (§8 decision 60). Every byte this class reads
 comes through Parley.PathGuard, the single site in Parley performing
 file I/O. A File, FileStream or Directory send of its own would make
 this a NINTH class and fail the settled prohibition by construction.

 ONE REMEDY SERVES ALL FIVE FAILURES, and that is §8 decision 58 applied
 rather than avoided: NO PARLEY VERB WRITES A CONFIGURATION FILE, so
 there is no verb to name the way the corrupt-lock diagnosis names
 parley update. Removing the file always works — the tool falls back to
 the flags it has always had — and fixing it always works. A remedy
 naming a verb that cannot help is the loop decision 58 caught one
 boundary over."

Namespace current: Parley.

Object subclass: Configuration [
    | workingDir values read |

    <comment: 'The project configuration at <workingDir>/parley.config.st:
reads the settled literal micro-format through the settled reader and
answers the value each declared source flag records, or nil. Decides no
precedence — CommandLine does. Class-side construction; pathname-passive
until a value is asked for; every failure is one ExecutionError naming
the path.'>

    Configuration class >> in: aWorkingDir [
        "Answer the configuration of the project at aWorkingDir.
         PATHNAME-PASSIVE: nothing is read here. The file is opened when
         a value is asked for, so constructing one costs nothing and a
         verb that never needs a source never meets its diagnosis."
        <category: 'instance creation'>
        ^self new setWorkingDir: aWorkingDir
    ]

    "---- the schema (Doc B §5.7) ----"

    Configuration class >> fileName [
        "The operator's file, at the project root beside Package.st and
         parley.lock."
        <category: 'schema'>
        ^'parley.config.st'
    ]

    Configuration class >> formatTag [
        <category: 'schema'>
        ^#'parley-config'
    ]

    Configuration class >> flagMarker [
        "The two characters a flag opens with, declared once so the key
         derivation below is not a magic 3."
        <category: 'schema'>
        ^'--'
    ]

    Configuration class >> keys [
        "THE BODY'S KEYS ARE THE DECLARED SOURCE FLAGS, DERIVED AND NEVER
         RESTATED (Doc B §5.7). A hand-kept list here is how a fourth
         source flag would ship with a configuration file that cannot
         record it — the drift sourceFlags itself exists to prevent, one
         level up. The order is the table's own, which is the fixed key
         order §5.4 rule 2 requires."
        <category: 'schema'>
        ^CommandLine sourceFlagNames collect: [:flag | self keyFor: flag]
    ]

    Configuration class >> keyFor: aFlagString [
        "The body key a flag records under: the flag without its marker."
        <category: 'schema'>
        ^(aFlagString
            copyFrom: self flagMarker size + 1
            to: aFlagString size) asSymbol
    ]

    Configuration class >> keyOrderText [
        "The declared key order rendered for a diagnosis, derived from
         the keys so the sentence and the check cannot drift apart — the
         settled lockKeyOrderText shape."
        <category: 'schema'>
        | out |
        out := WriteStream on: String new.
        self keys
            do: [:each | out nextPutAll: each printString]
            separatedBy: [out nextPut: Character space].
        ^out contents
    ]

    "---- the pinned diagnoses (issue #21, RED review) ----"

    Configuration class >> remedy [
        "THE ONE REMEDY, and it is checked for every one of the five
         failures (§8 decision 58). No Parley verb writes a
         configuration file, so no verb can be named as the repair;
         removing the file always works and fixing it always works."
        <category: 'diagnosis'>
        ^'fix it or remove it and try again'
    ]

    Configuration class >> lineFor: aPath saying: aCauseString [
        "The settled '<path>: <cause> - <remedy>' grammar (§8 decision
         73): the line opens with the path, states a cause in plain
         words, and offers the remedy."
        <category: 'diagnosis'>
        ^aPath, ': ', aCauseString, ' - ', self remedy
    ]

    Configuration class >> unreadableTail [
        "The cause names the PREDICATE that failed rather than guessing
         which way it failed — a directory, a device node, a file whose
         permissions deny the reader. One sentence covers all of them
         and none of them is a different repair. The settled parley.lock
         readability line is the model."
        <category: 'diagnosis'>
        ^'not a regular readable file'
    ]

    Configuration class >> wrongTagTailFor: aTag [
        "The settled wrong-tag shape: the offending tag, then what this
         file holds. It names the tag rather than only rejecting it,
         because an operator who pasted the wrong artifact needs to see
         which one they pasted."
        <category: 'diagnosis'>
        ^'wrong artifact tag ', aTag printString, ', ', self fileName,
            ' holds only #''parley-config'' 1 artifacts'
    ]

    Configuration class >> malformedKeysTail [
        "One sentence for every way the key list can be wrong — missing,
         misordered, unknown. The operator is repairing one file, not
         auditing it, and the repair is the same whichever way it is
         wrong (§8 decision 44's split)."
        <category: 'diagnosis'>
        ^'malformed configuration, the keys must be ', self keyOrderText,
            ' in that order'
    ]

    Configuration class >> malformedValueTail [
        "The Doc F §4.1 lesson one level down: a shape check that never
         asks what a value IS hands an Integer to a source constructor."
        <category: 'diagnosis'>
        ^'malformed configuration, every value must be a String'
    ]

    Configuration class >> twoSourcesTailFor: aKey and: anotherKey [
        "REFUSED IN THE SETTLED MUTUALLY-EXCLUSIVE SHAPE, never silently
         preferred (Doc B §5.7). The flag grammar answers --source with
         --git as a usage error because a silent preference makes a typo
         look like a working command, and a file nobody retypes has more
         need of that rule than a command line does, not less.

         BOTH KEYS ARE NAMED, because the operator has to know which two
         to choose between, and the rule is stated rather than only the
         violation."
        <category: 'diagnosis'>
        ^aKey printString, ' and ', anotherKey printString,
            ' are both declared, ', self fileName,
            ' declares at most one source'
    ]

    setWorkingDir: aWorkingDir [
        "Private — initialization from the class-side constructor."
        <category: 'private'>
        workingDir := aWorkingDir.
        read := false
    ]

    "---- accessing ----"

    path [
        "The configuration file this project would record its source in,
         whether or not it exists."
        <category: 'accessing'>
        ^workingDir, '/', self class fileName
    ]

    valueFor: aFlagString [
        "The value the file records for aFlagString, or nil when the
         file records none, records the empty string for it, or is not
         there at all. Signals one ExecutionError naming the path when
         the file exists and is not a well-formed configuration.

         THE EMPTY STRING RECORDS ABSENCE (Doc B §5.7, the §5.3 digest
         precedent) — it is not a source named by the empty path."
        <category: 'accessing'>
        | index value |
        self readOnce.
        values isNil ifTrue: [^nil].
        index := self class keys indexOf: (self class keyFor: aFlagString).
        index = 0 ifTrue: [^nil].
        value := values at: index.
        ^value isEmpty ifTrue: [nil] ifFalse: [value]
    ]

    "---- the boundary (§8 decision 65) ----"

    readOnce [
        "Private — read and validate the file at most once per instance.
         A verb asks for up to three values and the file has one state;
         reading it three times would give one malformed file three
         chances to be diagnosed differently."
        <category: 'private-boundary'>
        read ifTrue: [^self].
        read := true.
        (PathGuard exists: self path) ifFalse: [^self].
        values := self readValues
    ]

    readValues [
        "Private — the declared values, in key order, from a file that
         exists. Every rejection ground is checked in the order a reader
         meets them: can the bytes be obtained, do they parse, is this
         the right artifact, is the body the declared shape, and does it
         declare at most one source."
        <category: 'private-boundary'>
        | entry |
        entry := self parsedEntry.
        (entry at: 1) = self class formatTag ifFalse: [
            ^self refuse: (self class wrongTagTailFor: (entry at: 1))].
        ^self validatedValuesIn: entry
    ]

    parsedEntry [
        "Private — the file's literal structure through the SETTLED
         reader, which is the fifth sender of readFrom: in src/ and the
         sixth declared deserialization boundary.

         THE READER'S OWN MESSAGE TRAVELS VERBATIM: it names a character
         position, and on a hand-edited file that position is the
         operator's only handle, so paraphrasing it would throw away the
         one thing that makes the line actionable. The settled lock
         boundary carries it the same way.

         THE BYTES COME THROUGH PathGuard, which prechecks the read
         predicate and translates anything the operation raises into
         this boundary's own refusal — so a directory at this path
         answers the readability line rather than a kernel WrongClass at
         exit 70, and the census stays at eight."
        <category: 'private-boundary'>
        | bytes |
        bytes := PathGuard contentsOf: self path
            ifRefused: [:each |
                self refuse: self class unreadableTail].
        ^[IndexEntryReader readFrom: (ReadStream on: bytes)]
            on: IndexEntryParseError, IndexEntryFormatError
            do: [:e | self refuse: e messageText]
    ]

    validatedValuesIn: anEntry [
        "Private — the body shape, before any value reaches a consumer
         (§8 decision 65; Doc B §5.7). All three declared keys present,
         in the fixed order, values Strings, and at most one of them
         non-empty.

         THE KEYS ARE CHECKED BEFORE THE VALUES, and both before the
         mutual exclusion: a file whose keys are wrong has no values to
         speak of, and one whose value is an Integer cannot be asked
         whether it is empty."
        <category: 'private-boundary'>
        | keys declared |
        keys := self class keys.
        anEntry size = (2 + (2 * keys size)) ifFalse: [
            ^self refuse: self class malformedKeysTail].
        1 to: keys size do: [:i |
            (anEntry at: 2 * i + 1) = (keys at: i) ifFalse: [
                ^self refuse: self class malformedKeysTail]].
        1 to: keys size do: [:i |
            (SchemaShape isString: (anEntry at: 2 * i + 2)) ifFalse: [
                ^self refuse: self class malformedValueTail]].
        declared := (1 to: keys size)
            select: [:i | (anEntry at: 2 * i + 2) isEmpty not].
        declared size > 1 ifTrue: [
            ^self refuse: (self class
                twoSourcesTailFor: (keys at: (declared at: 1))
                and: (keys at: (declared at: 2)))].
        ^(1 to: keys size) collect: [:i | anEntry at: 2 * i + 2]
    ]

    refuse: aCauseString [
        "Private — one ExecutionError carrying the whole line.

         THE CARRIER IS A CARRIER, NOT AN ATTRIBUTION (§8 decision 72,
         applied a second time). ExecutionError is the composition
         root's settled carrier for a filesystem precondition in the
         '<path>: ...' grammar, and the §4.2 boundary already maps it to
         one line at exit 1. A malformed configuration has nothing to do
         with executing anything; the boundary table says so in its own
         comment, exactly as it does for the wiring state directory."
        <category: 'private-boundary'>
        ^ExecutionError new signal:
            (self class lineFor: self path saying: aCauseString)
    ]
]

Namespace current: Smalltalk.
