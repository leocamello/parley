"Parley — InstallError: the single batched error signaled by an
 install pass that found problems.
 Spec: docs/design/installer.md §1/§4; issue #7 S13-S14.
 The ManifestError problems house style: one error carrying every
 problem found across the whole pass as human-readable strings in
 sorted package-name order — never an exception per package."

Namespace current: Parley.

Error subclass: InstallError [
    | problems |

    <comment: 'The single batched error of one Installer pass: carries
the complete list of install problems — no published archive, fetch
failure, hash mismatch — in sorted package-name order, so an operator
fixes an install per pass, not per package.'>

    InstallError class >> signalProblems: aCollection [
        "Signal one error carrying every problem in aCollection."
        <category: 'instance creation'>
        | message |
        message := WriteStream on: String new.
        message nextPutAll: 'Install has ';
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
        "The full list of install problems, each a descriptive string
         opening with the package name and version."
        <category: 'accessing'>
        ^problems
    ]
]

Namespace current: Smalltalk.
