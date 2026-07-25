"Parley — LockError: a parley.lock that cannot be read.
 Spec: docs/design/execution-and-cli.md §4.1; issue #11 S1-S2.

 The lockfile is the OPERATOR's file. Until Sprint 9 a hand-edited one
 reached the §4.2 boundary as a raw IndexEntryParseError or
 IndexEntryFormatError — undiagnosed — and was answered with exit 70,
 'this is a defect in Parley, not in your project'. Nothing was wrong
 with the reader's message: it names the exact character position, and
 on a hand-edited file that position is the operator's only handle.
 What was wrong was who it blamed. This class is the reclassification,
 and it is decision 31 applied to the second of the operator's two
 files.

 It carries problems exactly as its batched siblings do, which is why
 the Sprint 8 boundary absorbs it with NO new mechanism: the handler is
 derived from CommandLine class >> batchedErrorClasses, so joining the
 declared diagnosed set is the whole change.

 Single-problem by nature, batched in shape: a lock read stops at the
 first thing it cannot understand — there is no second problem to find
 in a file that never parsed. The batch shape is kept because the
 boundary speaks it and because a future lock validation (a pin whose
 package no longer exists, say) would batch honestly.

 No value equality (=/hash) — the decision-23 precedent."

Namespace current: Parley.

Error subclass: LockError [
    | problems |

    <comment: 'The diagnosis for a parley.lock that cannot be read:
carries the problems found reading it — the lock path, the settled
reader''s own message, and the repair — as human-readable strings.
parley update is the repair the diagnosis names, because update is the
one verb that never reads the lock.'>

    LockError class >> signalProblems: aCollection [
        "Signal one error carrying every problem in aCollection."
        <category: 'instance creation'>
        | message |
        message := WriteStream on: String new.
        message nextPutAll: 'Lock has ';
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
        "The full list of lock problems, each naming the lock file, what
         could not be read, and the verb that rewrites it."
        <category: 'accessing'>
        ^problems
    ]
]

Namespace current: Smalltalk.
