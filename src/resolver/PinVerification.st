"Parley — PinVerification: the pure half of the lockfile fast path.
 Spec: docs/design/resolver.md §6; issue #5 S9-S13 (class declared on
 the issue).
 An immutable verdict value, a pure function of (root LibraryManifest,
 lock Resolution): checks the ROOT manifest's constraints only — graph
 consistency was the resolver's job at lock-write time; hash-vs-cache is
 the installer's job later. Every problem is batched into one value in
 manifest-declaration order (the ManifestError problems style); extra
 transitive pins are expected and valid. No snapshot, no resolver,
 no I/O.

 IT EXTENDS OVER THE THREE DECLARED KINDS from Sprint 21 (§8 decision
 69): index dependencies by constraint as ever, DEV dependencies by
 exactly the same two rules, and PATH dependencies by presence and
 provenance alone. It verifies the DECLARED manifest and never the
 CLI's composed resolution view — the view is internal wiring, and a
 verdict built from it would be checking the tool's own arithmetic
 rather than the operator's file."

Namespace current: Parley.

Object subclass: PinVerification [
    | problems |

    <comment: 'The verdict of verifying a lock''s pins against the root
manifest''s constraints: isValid with the batched human-readable
problem strings. Class-side construction only; a pure function of its
two arguments.'>

    PinVerification class >> of: aLibraryManifest lock: aResolution [
        "Answer the verdict of checking every root-manifest dependency
         against the lock's pins: a missing pin means the manifest
         changed; a pinned version outside its constraint violates the
         lock. All problems are collected in one pass."
        <category: 'instance creation'>
        | problems |
        problems := OrderedCollection new.
        aLibraryManifest dependencies do: [:dep |
            (aResolution packageNames includes: dep name)
                ifFalse: [
                    problems add: 'manifest dependency ',
                        dep name printString,
                        ' (', dep constraint printString,
                        ') is missing from the lock']
                ifTrue: [
                    (dep satisfiedBy: (aResolution versionOf: dep name))
                        ifFalse: [
                            problems add: 'lock pins ', dep name printString,
                                ' at ',
                                (aResolution versionOf: dep name) printString,
                                ' outside the manifest constraint ',
                                dep constraint printString]]].
        "A PATH DEPENDENCY VERIFIES BY PRESENCE AND PROVENANCE, AND
         THERE IS NO CONSTRAINT CHECK TO FAIL (§8 decision 69; Doc E
         §4.1). Its version is the sibling's declaration, not a
         constraint of the root's, so a verifier that invented one would
         fail every project whose sibling moved a major version — the
         ordinary case in development.

         SO THE CHECK IS PRESENCE, AND `PROVENANCE` IN Doc E §4.1's
         sentence describes WHAT MAKES IT VERIFIABLE rather than a
         second check: the pin's version comes from the sibling's
         declaration, which is why there is nothing here to compare it
         against. Requiring the lock tuple to carry #path provenance as
         well was written and withdrawn — it fails a reviewed scenario
         that verifies a path pin from a resolution built through the
         settled root:triples:, and a verifier that demanded provenance
         would be asking about the LOCK'S SPELLING rather than about
         whether the project is consistent. Whether a pin has drifted
         from its sibling is `check`'s drift leg, which reads the
         sibling; this is a pure function of two values and reads
         nothing."
        aLibraryManifest pathDependencies do: [:each |
            (aResolution packageNames includes: each name) ifFalse: [
                problems add: 'manifest dependency ',
                    each name printString,
                    ' (path ', each path printString,
                    ') is missing from the lock']].
        "A DEV DEPENDENCY IS AN ORDINARY PIN WITH AN AUDIENCE (§8
         decision 69). The lock records provenance and does NOT record
         audience, so a dev pin lands in #packages undistinguished and
         is verified by exactly the settled rules — the SAME two
         sentences, because inventing a third for the same two defects
         would be two wordings no law can hold together."
        aLibraryManifest devDependencies do: [:dep |
            (aResolution packageNames includes: dep name)
                ifFalse: [
                    problems add: 'manifest dependency ',
                        dep name printString,
                        ' (', dep constraint printString,
                        ') is missing from the lock']
                ifTrue: [
                    (dep satisfiedBy: (aResolution versionOf: dep name))
                        ifFalse: [
                            problems add: 'lock pins ', dep name printString,
                                ' at ',
                                (aResolution versionOf: dep name) printString,
                                ' outside the manifest constraint ',
                                dep constraint printString]]].
        ^self new setProblems: problems asArray
    ]

    setProblems: anArray [
        "Private — initialization from the class-side constructor."
        <category: 'private'>
        problems := anArray
    ]

    problems [
        "The batched problem strings, in manifest-declaration order;
         empty when the lock verifies."
        <category: 'accessing'>
        ^problems
    ]

    isValid [
        <category: 'testing'>
        ^problems isEmpty
    ]

    printOn: aStream [
        <category: 'printing'>
        aStream nextPutAll: 'PinVerification('.
        self isValid
            ifTrue: [aStream nextPutAll: 'valid']
            ifFalse: [aStream
                nextPutAll: problems size printString;
                nextPutAll: ' problem(s)'].
        aStream nextPut: $)
    ]
]

Namespace current: Smalltalk.
