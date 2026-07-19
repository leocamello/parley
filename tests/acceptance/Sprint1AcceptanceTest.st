"Parley Sprint 1 — acceptance scenarios S1-S15 from GitHub issue #3.
 Each scenario Sn maps to exactly one selector starting with testSn_
 (enforced by the wrap traceability gate)."

Namespace current: Parley.

TestCase subclass: Sprint1AcceptanceTest [
    | gen |

    <comment: 'Acceptance scenarios for Sprint 1: manifest authoring, the
literals-only reader, and byte-stable serialization.'>

    setUp [
        gen := ManifestGenerators fromEnvironment
    ]

    write: aManifest [
        | stream |
        stream := WriteStream on: String new.
        IndexEntryWriter write: aManifest on: stream.
        ^stream contents
    ]

    read: aString [
        ^IndexEntryReader readFrom: (ReadStream on: aString)
    ]

    s1Manifest [
        ^Parley define: [:pkg |
            pkg
                name: 'kernel-json';
                version: '0.3.1';
                summary: 'A JSON reader/writer speaking pure message sends';
                author: 'Leonardo';
                license: 'MIT';
                fileIns: #('Reader.st' 'Writer.st' 'Extensions.st');
                dependency: 'kernel-streams' constraint: '>=1.0 <2.0';
                dependency: 'kernel-strings' constraint: '^0.4.2']
    ]

    dependencyOn: aName in: aManifest [
        ^aManifest dependencies detect: [:d | d name = aName]
    ]

    problemsOf: aBlock [
        aBlock on: ManifestError do: [:e | ^e problems].
        self assert: false description: 'expected a ManifestError'.
        ^nil
    ]

    problems: aCollection mention: aString [
        ^(aCollection detect: [:p |
            (p indexOfSubCollection: aString) > 0] ifNone: [nil]) notNil
    ]

    assertRejects: anInput at: expectedPosition [
        "The reader must reject anInput with an IndexEntryParseError
         positioned at the first grammar-breaking character."
        [self read: anInput]
            on: IndexEntryParseError
            do: [:e |
                self assert: e position = expectedPosition.
                ^self].
        self assert: false
            description: 'accepted forbidden input ' , anInput
    ]

    testS1_fullDefineAnswersImmutableLibraryManifest [
        "S1 — the complete Package.st block answers a LibraryManifest with
         every declared field, fileIns order intact, parsed version and
         structurally-equal constraints."
        | m |
        m := self s1Manifest.
        self assert: (m isKindOf: LibraryManifest).
        self assert: m name = 'kernel-json'.
        self assert: m version = (Version fromString: '0.3.1').
        self assert: m summary
            = 'A JSON reader/writer speaking pure message sends'.
        self assert: m author = 'Leonardo'.
        self assert: m license = 'MIT'.
        self assert: m fileIns asArray
            = #('Reader.st' 'Writer.st' 'Extensions.st').
        self assert: m dependencies size = 2.
        self assert: (self dependencyOn: 'kernel-streams' in: m) constraint
            = (VersionConstraint fromString: '>=1.0 <2.0').
        self assert: (self dependencyOn: 'kernel-strings' in: m) constraint
            = (VersionConstraint fromString: '^0.4.2')
    ]

    testS2_unconstrainedDependencySugarIsAny [
        "S2 — dependency: with no constraint records VersionConstraint any."
        | m |
        m := Parley define: [:pkg |
            pkg name: 'p'; version: '1'; fileIns: #('A.st');
                dependency: 'kernel-streams'].
        self assert: (self dependencyOn: 'kernel-streams' in: m) constraint
            = VersionConstraint any
    ]

    testS3_dependencyDelegatesSatisfactionToConstraint [
        "S3 — satisfiedBy: delegates to the constraint algebra's allows:."
        | dep |
        dep := Dependency
            name: 'kernel-streams'
            constraint: (VersionConstraint fromString: '>=1.0 <2.0').
        self assert: (dep satisfiedBy: (Version fromString: '1.4.0')).
        self deny: (dep satisfiedBy: (Version fromString: '2.0.0'))
    ]

    testS4_unknownVocabularySelectorIsRichLiveError [
        "S4 — #depends:on: signals ManifestVocabularyError carrying the
         selector, the nearest suggestion, and the reflected vocabulary."
        [Parley define: [:pkg | pkg depends: 'a' on: 'b']]
            on: ManifestVocabularyError
            do: [:e |
                self assert: e unknownSelector = #depends:on:.
                self assert: e suggestion = #dependency:constraint:.
                self assert: e vocabulary asSortedCollection asArray
                    = ManifestBuilder vocabulary asSortedCollection asArray.
                ^self].
        self assert: false description: 'expected ManifestVocabularyError'
    ]

    testS5_buildBatchesEveryProblemIntoOneManifestError [
        "S5 — one ManifestError carrying all three problems; nothing
         signals before build."
        | problems |
        problems := self problemsOf: [
            Parley define: [:pkg |
                pkg version: 'x.y'; fileIns: #('A.st');
                    dependency: 'a' constraint: 'not-a-constraint']].
        self assert: problems size = 3.
        self assert: (self problems: problems mention: 'name').
        self assert: (self problems: problems mention: 'x.y').
        self assert: (self problems: problems mention: 'not-a-constraint')
    ]

    testS6_packageNameFormatRule [
        "S6 — names must be lowercase letters, digits, hyphens, starting
         with a letter."
        #('Kernel_JSON' '9lives') do: [:bad |
            | problems |
            problems := self problemsOf: [
                Parley define: [:pkg |
                    pkg name: bad; version: '1'; fileIns: #('A.st')]].
            self assert: (self problems: problems mention: bad)]
    ]

    testS7_duplicateDependencyRejected [
        "S7 — declaring the same dependency twice is a build problem."
        | problems |
        problems := self problemsOf: [
            Parley define: [:pkg |
                pkg name: 'p'; version: '1'; fileIns: #('A.st');
                    dependency: 'kernel-streams' constraint: '>=1.0 <2.0';
                    dependency: 'kernel-streams']].
        self assert: (self problems: problems mention: 'kernel-streams')
    ]

    testS8_selfDependencyRejected [
        "S8 — a package depending on itself is a build problem."
        | problems |
        problems := self problemsOf: [
            Parley define: [:pkg |
                pkg name: 'kernel-json'; version: '1'; fileIns: #('A.st');
                    dependency: 'kernel-json']].
        self assert: (self problems: problems mention: 'kernel-json')
    ]

    testS9_writerRendersCanonicalIndexEntry [
        "S9 — the exact canonical bytes of the Doc B §5.2 entry."
        | expected |
        expected := '#(#''parley-index'' 1 #name ''kernel-json'' #version ''0.3.1'' #summary ''A JSON reader/writer speaking pure message sends'' #author ''Leonardo'' #license ''MIT'' #fileIns #(''Reader.st'' ''Writer.st'' ''Extensions.st'') #dependencies #(#(''kernel-streams'' ''>=1.0.0 <2.0.0'') #(''kernel-strings'' ''>=0.4.2 <0.5.0'')) #archive #())'
            , (String with: Character nl).
        self assert: (self write: self s1Manifest) = expected
    ]

    testS10_byteStabilityUnderRewriteAndDependencyPermutation [
        "S10 — same manifest twice and dependency-permuted define: all
         write byte-identical entries."
        | m permuted first second third |
        m := self s1Manifest.
        permuted := Parley define: [:pkg |
            pkg
                name: 'kernel-json';
                version: '0.3.1';
                summary: 'A JSON reader/writer speaking pure message sends';
                author: 'Leonardo';
                license: 'MIT';
                fileIns: #('Reader.st' 'Writer.st' 'Extensions.st');
                dependency: 'kernel-strings' constraint: '^0.4.2';
                dependency: 'kernel-streams' constraint: '>=1.0 <2.0'].
        first := self write: m.
        second := self write: m.
        third := self write: permuted.
        self assert: first = second.
        self assert: first = third
    ]

    testS11_fileInsOrderIsSemantic [
        "S11 — permuting fileIns: changes the bytes; each output preserves
         its declared order exactly."
        | a b outA outB |
        a := Parley define: [:pkg |
            pkg name: 'p'; version: '1'; fileIns: #('One.st' 'Two.st')].
        b := Parley define: [:pkg |
            pkg name: 'p'; version: '1'; fileIns: #('Two.st' 'One.st')].
        outA := self write: a.
        outB := self write: b.
        self deny: outA = outB.
        self assert: (outA indexOfSubCollection: 'One.st')
            < (outA indexOfSubCollection: 'Two.st').
        self assert: (outB indexOfSubCollection: 'Two.st')
            < (outB indexOfSubCollection: 'One.st')
    ]

    testS12_roundTripIdentityOnRandomizedManifests [
        "S12 — build -> write -> read -> fromIndexEntry: equals the
         original on all fields (seeded from PARLEY_SEED)."
        1 to: 50 do: [:i |
            | m back |
            m := gen nextManifest.
            back := LibraryManifest fromIndexEntry:
                (self read: (self write: m)).
            self assert: back name = m name.
            self assert: back version = m version.
            self assert: back summary = m summary.
            self assert: back author = m author.
            self assert: back license = m license.
            self assert: back fileIns asArray = m fileIns asArray.
            self assert: back dependencies size = m dependencies size.
            m dependencies do: [:dep |
                | twin |
                twin := back dependencies
                    detect: [:d | d name = dep name] ifNone: [nil].
                self assert: twin notNil.
                self assert: twin constraint = dep constraint]]
    ]

    testS13_readerRejectsNonLiteralTokens [
        "S13 — every forbidden token class fails with a positioned parse
         error; no input reaches a compiler pathway."
        | prefix |
        prefix := '#(#''parley-index'' 1 '.
        "Tokens rejected at their first character."
        #('bare' '-2' '$a' 'true' 'false' 'nil' '"a comment"' '{1. 2}')
            do: [:token |
                self assertRejects: prefix , token , ')'
                    at: prefix size + 1].
        "Tokens whose grammar-breaking character sits inside the token:
         the decimal point, the byte-array bracket, the selector after
         an integer (message-send syntax)."
        self assertRejects: prefix , '1.5)' at: prefix size + 2.
        self assertRejects: prefix , '#[1 2])' at: prefix size + 2.
        self assertRejects: prefix , '3 factorial)' at: prefix size + 3
    ]

    testS14_unknownTagOrUnsupportedVersionIsClearError [
        "S14 — distinct, descriptive errors; not a generic parse failure."
        | tagMessage versionMessage |
        tagMessage := [self read: '#(#''parley-nonsense'' 1 #name ''p'')'.
                nil]
            on: IndexEntryFormatError do: [:e | e messageText].
        versionMessage := [self read: '#(#''parley-index'' 99 #name ''p'')'.
                nil]
            on: IndexEntryFormatError do: [:e | e messageText].
        self assert: tagMessage notNil.
        self assert: versionMessage notNil.
        self assert: (tagMessage indexOfSubCollection: 'parley-nonsense') > 0.
        self assert: (versionMessage indexOfSubCollection: '99') > 0.
        self deny: tagMessage = versionMessage
    ]

    testS15_optionalFieldsDefaultEmptyAndKeysStayPresent [
        "S15 — summary/author/license default to '' and their keys are
         still serialized (all schema keys always present)."
        | m out |
        m := Parley define: [:pkg |
            pkg name: 'p'; version: '1'; fileIns: #('A.st')].
        self assert: m summary = ''.
        self assert: m author = ''.
        self assert: m license = ''.
        out := self write: m.
        self assert: (out indexOfSubCollection: '#summary ''''') > 0.
        self assert: (out indexOfSubCollection: '#author ''''') > 0.
        self assert: (out indexOfSubCollection: '#license ''''') > 0
    ]
]

Namespace current: Smalltalk.
