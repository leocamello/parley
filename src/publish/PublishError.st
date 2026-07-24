"Parley — PublishError: the single batched error signaled by a publish
 that found problems.
 Spec: docs/design/publish-and-sources.md §1; issue #9 S8-S10.
 The ManifestError problems house style: one error carrying every
 problem found in one publish attempt as human-readable strings, so an
 author fixes a release per attempt, not per problem. Refusal and build
 failure are single-problem errors by nature (a republish is a category
 error, and a failed build is fail-stop); the pre-flight is the batching
 one, its problems in sorted filename order.
 No value equality (=/hash) — the decision-23 precedent."

Namespace current: Parley.

Error subclass: PublishError [
    | problems |

    <comment: 'The single batched error of one publish attempt:
carries the complete list of problems — the refusal of an already
published release, missing fileIns, a failed toolchain build — as
human-readable strings.'>

    PublishError class >> signalProblems: aCollection [
        "Signal one error carrying every problem in aCollection."
        <category: 'instance creation'>
        | message |
        message := WriteStream on: String new.
        message nextPutAll: 'Publish has ';
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
        "The full list of publish problems, each a descriptive string
         opening with the offending package, file name or defect."
        <category: 'accessing'>
        ^problems
    ]
]

Namespace current: Smalltalk.
