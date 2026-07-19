"Parley Sprint 1 — ManifestBuilder laws: vocabulary reflection, the
 doesNotUnderstand: error path, and batch validation in build.
 Spec: docs/design/manifest-and-serialization.md §3."

Namespace current: Parley.

TestCase subclass: ManifestBuilderTest [

    <comment: 'Laws for the one sanctioned mutable edge object: the DSL
vocabulary is reflected from the manifest vocabulary method category,
unknown selectors answer a rich ManifestVocabularyError, and build
batches every problem into one ManifestError.'>

    validBuilder [
        "A builder carrying the minimal valid declarations."
        | builder |
        builder := ManifestBuilder new.
        builder name: 'kernel-json'.
        builder version: '0.3.1'.
        builder fileIns: #('Reader.st').
        ^builder
    ]

    problemsOf: aBlock [
        "Evaluate aBlock, which must signal a ManifestError, and answer
         the error's problem list."
        aBlock on: ManifestError do: [:e | ^e problems].
        self assert: false description: 'expected a ManifestError'.
        ^nil
    ]

    problems: aCollection mention: aString [
        ^(aCollection detect: [:p |
            (p indexOfSubCollection: aString) > 0] ifNone: [nil]) notNil
    ]

    testVocabularyMatchesCategoryReflection [
        "class >> vocabulary is derived from the actual methods in the
         'manifest vocabulary' category — the list cannot drift."
        | reflected |
        reflected := ManifestBuilder selectors asSortedCollection select:
            [:sel | (ManifestBuilder compiledMethodAt: sel) methodCategory
                        asString = 'manifest vocabulary'].
        self assert: ManifestBuilder vocabulary asSortedCollection asArray
            = reflected asArray
    ]

    testVocabularyContainsTheDocumentedWords [
        | vocabulary |
        vocabulary := ManifestBuilder vocabulary asSortedCollection.
        #(#name: #version: #summary: #author: #license: #fileIns:
          #dependency:constraint: #dependency:) do: [:sel |
            self assert: (vocabulary includes: sel)]
    ]

    testUnknownSelectorSignalsVocabularyError [
        self should: [ManifestBuilder new depends: 'a' on: 'b']
            raise: ManifestVocabularyError
    ]

    testVocabularyErrorCarriesSelectorSuggestionAndVocabulary [
        [ManifestBuilder new depends: 'a' on: 'b']
            on: ManifestVocabularyError
            do: [:e |
                self assert: e unknownSelector = #depends:on:.
                self assert: e suggestion = #dependency:constraint:.
                self assert: e vocabulary asSortedCollection asArray
                    = ManifestBuilder vocabulary asSortedCollection asArray.
                ^self].
        self assert: false description: 'expected ManifestVocabularyError'
    ]

    testVocabularyMessagesRecordWithoutParsing [
        "Raw strings only mid-cascade: garbage version and constraint
         strings must not signal until build."
        | builder |
        builder := ManifestBuilder new.
        builder name: 'kernel-json'.
        builder version: 'x.y'.
        builder fileIns: #('Reader.st').
        builder dependency: 'a' constraint: 'not-a-constraint'.
        self should: [builder build] raise: ManifestError
    ]

    testBuildBatchesAllProblemsIntoOneError [
        | builder problems |
        builder := ManifestBuilder new.
        builder version: 'x.y'.
        builder fileIns: #('Reader.st').
        builder dependency: 'a' constraint: 'not-a-constraint'.
        problems := self problemsOf: [builder build].
        self assert: problems size = 3.
        self assert: (self problems: problems mention: 'name').
        self assert: (self problems: problems mention: 'x.y').
        self assert: (self problems: problems mention: 'not-a-constraint')
    ]

    testBuildRequiresNameVersionAndFileIns [
        | problems |
        problems := self problemsOf: [ManifestBuilder new build].
        self assert: (self problems: problems mention: 'name').
        self assert: (self problems: problems mention: 'version').
        self assert: (self problems: problems mention: 'fileIns')
    ]

    testBuildRejectsEmptyFileIns [
        | builder |
        builder := self validBuilder.
        builder fileIns: #().
        self assert: (self problems: (self problemsOf: [builder build])
            mention: 'fileIns')
    ]

    testNameFormatRule [
        "Lowercase letters, digits, hyphens; must start with a letter."
        #('Kernel_JSON' '9lives' 'has space' '-lead' 'UPPER') do: [:bad |
            | builder problems |
            builder := self validBuilder.
            builder name: bad.
            problems := self problemsOf: [builder build].
            self assert: (self problems: problems mention: bad)].
        #('kernel-json' 'a' 'a1' 'x2-y3') do: [:good |
            | builder |
            builder := self validBuilder.
            builder name: good.
            self assert: builder build name = good]
    ]

    testDuplicateDependencyRejected [
        | builder problems |
        builder := self validBuilder.
        builder dependency: 'kernel-streams' constraint: '>=1.0 <2.0'.
        builder dependency: 'kernel-streams'.
        problems := self problemsOf: [builder build].
        self assert: (self problems: problems mention: 'kernel-streams')
    ]

    testSelfDependencyRejected [
        | builder problems |
        builder := self validBuilder.
        builder dependency: 'kernel-json'.
        problems := self problemsOf: [builder build].
        self assert: (self problems: problems mention: 'kernel-json')
    ]

    testUnconstrainedDependencySugarMeansAny [
        | builder manifest dep |
        builder := self validBuilder.
        builder dependency: 'kernel-streams'.
        manifest := builder build.
        dep := manifest dependencies detect: [:d |
            d name = 'kernel-streams'].
        self assert: dep constraint = VersionConstraint any
    ]

    testBuildAnswersImmutableManifestWithParsedValues [
        | builder manifest dep |
        builder := self validBuilder.
        builder summary: 'A JSON reader'.
        builder author: 'Leonardo'.
        builder license: 'MIT'.
        builder dependency: 'kernel-strings' constraint: '^0.4.2'.
        manifest := builder build.
        self assert: (manifest isKindOf: LibraryManifest).
        self assert: manifest name = 'kernel-json'.
        self assert: manifest version = (Version fromString: '0.3.1').
        self assert: manifest summary = 'A JSON reader'.
        self assert: manifest author = 'Leonardo'.
        self assert: manifest license = 'MIT'.
        self assert: manifest fileIns = #('Reader.st').
        dep := manifest dependencies detect: [:d |
            d name = 'kernel-strings'].
        self assert: dep constraint
            = (VersionConstraint fromString: '^0.4.2')
    ]

    testOptionalFieldsDefaultToEmptyString [
        | manifest |
        manifest := self validBuilder build.
        self assert: manifest summary = ''.
        self assert: manifest author = ''.
        self assert: manifest license = ''
    ]

    testDependencySatisfactionDelegatesToConstraint [
        | dep |
        dep := Dependency
            name: 'kernel-streams'
            constraint: (VersionConstraint fromString: '>=1.0 <2.0').
        self assert: (dep satisfiedBy: (Version fromString: '1.4.0')).
        self deny: (dep satisfiedBy: (Version fromString: '2.0.0'))
    ]

    testDependencyEqualityAndHashTogether [
        | a b c |
        a := Dependency name: 'kernel-streams'
            constraint: (VersionConstraint fromString: '>=1.0 <2.0').
        b := Dependency name: 'kernel-streams'
            constraint: (VersionConstraint fromString: '>=1.0.0 <2.0.0').
        c := Dependency name: 'kernel-strings'
            constraint: (VersionConstraint fromString: '>=1.0 <2.0').
        self assert: a = b.
        self assert: a hash = b hash.
        self deny: a = c
    ]
]

Namespace current: Smalltalk.
