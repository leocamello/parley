"Parley — PinVerification: the pure half of the lockfile fast path.
 Spec: docs/design/resolver.md §6; issue #5 S9-S13 (class declared on
 the issue).
 An immutable verdict value, a pure function of (root LibraryManifest,
 lock Resolution): checks the ROOT manifest's constraints only — graph
 consistency was the resolver's job at lock-write time; hash-vs-cache is
 the installer's job later. Every problem is batched into one value in
 manifest-declaration order (the ManifestError problems style); extra
 transitive pins are expected and valid. No snapshot, no resolver,
 no I/O."

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
