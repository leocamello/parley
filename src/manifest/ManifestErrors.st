"Parley — manifest authoring errors: ManifestError (the batch report
 from ManifestBuilder>>build) and ManifestVocabularyError (the
 doesNotUnderstand: error path for the manifest DSL).
 Spec: docs/design/manifest-and-serialization.md §3.3-§3.4."

Namespace current: Parley.

Error subclass: ManifestError [
    | problems |

    <comment: 'The single batched error signaled by ManifestBuilder>>build:
carries the complete list of problems found in one validation pass, so an
author fixes a Package.st per edit-run cycle, not per error.'>

    ManifestError class >> signalProblems: aCollection [
        "Signal one error carrying every problem in aCollection."
        <category: 'instance creation'>
        | message |
        message := WriteStream on: String new.
        message nextPutAll: 'Manifest has ';
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
        "The full list of validation problems, each a descriptive string
         naming the offending value."
        <category: 'accessing'>
        ^problems
    ]
]

Error subclass: ManifestVocabularyError [
    | unknownSelector suggestion vocabulary |

    <comment: 'Signaled when a Package.st block sends a selector outside
the manifest vocabulary. Carries the unknown selector, a nearest-selector
suggestion, and the full vocabulary reflected from the manifest
vocabulary method category.'>

    ManifestVocabularyError class >> signalUnknown: aSelector vocabulary: aCollection [
        "Signal a vocabulary error for aSelector against the known
         vocabulary in aCollection."
        <category: 'instance creation'>
        | nearest message |
        nearest := self nearestTo: aSelector in: aCollection.
        message := WriteStream on: String new.
        message nextPutAll: 'Package.st sent #';
            nextPutAll: aSelector;
            nextPutAll: ' - not part of the manifest vocabulary.'.
        nearest notNil ifTrue: [
            message nextPutAll: ' Did you mean #';
                nextPutAll: nearest;
                nextPutAll: '?'].
        message nextPutAll: ' Known messages:'.
        aCollection
            do: [:sel | message nextPutAll: ' #'; nextPutAll: sel]
            separatedBy: [message nextPut: $,].
        message nextPut: $..
        ^self new
            setUnknownSelector: aSelector
            suggestion: nearest
            vocabulary: aCollection;
            signal: message contents
    ]

    ManifestVocabularyError class >> nearestTo: aSelector in: aCollection [
        "Private — a cheap nearest-selector heuristic: prefer selectors
         with the same keyword count, ranked by shared prefix length."
        <category: 'private'>
        | targetColons best bestScore |
        targetColons := aSelector occurrencesOf: $:.
        best := nil.
        bestScore := -1.
        aCollection do: [:candidate |
            | score |
            score := self sharedPrefixLengthOf: aSelector and: candidate.
            (candidate occurrencesOf: $:) = targetColons
                ifTrue: [score := score + 100].
            score > bestScore
                ifTrue: [best := candidate. bestScore := score]].
        ^best
    ]

    ManifestVocabularyError class >> sharedPrefixLengthOf: aSymbol and: otherSymbol [
        "Private — the length of the common character prefix."
        <category: 'private'>
        | limit |
        limit := aSymbol size min: otherSymbol size.
        1 to: limit do: [:i |
            (aSymbol at: i) = (otherSymbol at: i) ifFalse: [^i - 1]].
        ^limit
    ]

    setUnknownSelector: aSelector suggestion: aSuggestion vocabulary: aCollection [
        "Private — initialization before signaling."
        <category: 'private'>
        unknownSelector := aSelector.
        suggestion := aSuggestion.
        vocabulary := aCollection
    ]

    unknownSelector [
        <category: 'accessing'>
        ^unknownSelector
    ]

    suggestion [
        <category: 'accessing'>
        ^suggestion
    ]

    vocabulary [
        <category: 'accessing'>
        ^vocabulary
    ]
]

Namespace current: Smalltalk.
