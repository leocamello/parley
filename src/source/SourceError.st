"Parley — SourceError: the single batched error signaled by a source
 whose scan found problems.
 Spec: docs/design/resolver.md §1.1 (amended); issue #6.
 The ManifestError problems style: one error carrying every problem
 found in one directory scan as human-readable strings in
 sorted-filename order — never an exception per file."

Namespace current: Parley.

Error subclass: SourceError [
    | problems |

    <comment: 'The single batched error signaled by a package source
whose scan failed: carries the complete list of problems found in one
pass over the directory, in sorted-filename order, so an operator fixes
a source directory per scan, not per file.'>

    SourceError class >> signalProblems: aCollection [
        "Signal one error carrying every problem in aCollection."
        <category: 'instance creation'>
        | message |
        message := WriteStream on: String new.
        message nextPutAll: 'Source directory has ';
            nextPutAll: aCollection size printString;
            nextPutAll: ' problem(s): '.
        aCollection
            do: [:p | message nextPutAll: p]
            separatedBy: [message nextPutAll: '; '].
        ^self new setProblems: aCollection asArray;
            signal: message contents
    ]

    setProblems: anArray [
        "Private — initialization before signaling."
        <category: 'private'>
        problems := anArray
    ]

    problems [
        "The full list of scan problems, each a descriptive string
         opening with the offending file name or path."
        <category: 'accessing'>
        ^problems
    ]
]

Namespace current: Smalltalk.
