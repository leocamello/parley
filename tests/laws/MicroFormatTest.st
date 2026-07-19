"Parley Sprint 1 — micro-format laws: canonical writer rendering,
 byte-stability, the literals-only reader grammar, per-token rejection
 with positioned errors, and the round-trip identity law (AGENTS.md §7
 laws 9 and 10). Spec: docs/design/manifest-and-serialization.md §5-§7."

Namespace current: Parley.

TestCase subclass: MicroFormatTest [
    | gen |

    <comment: 'Laws for the IndexEntryWriter / IndexEntryReader pair:
build -> write -> read composes to the identity on manifests; writing is
byte-stable; the reader accepts only the literal grammar and rejects every
other token class with a positioned error, never touching a compiler.'>

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

    define: aBlock [
        ^Parley define: aBlock
    ]

    s1Manifest [
        ^self define: [:pkg |
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

    assertParse: aString failsAt: expectedPosition [
        "The reader must reject aString with an IndexEntryParseError whose
         position is the first grammar-breaking character and whose message
         names that position."
        [self read: aString]
            on: IndexEntryParseError
            do: [:e |
                self assert: e position = expectedPosition.
                self assert: (e messageText indexOfSubCollection:
                    expectedPosition printString) > 0.
                ^self].
        self assert: false
            description: 'expected a positioned parse error for ', aString
    ]

    rejectionInputFor: aToken [
        "An otherwise-valid artifact text containing exactly one forbidden
         token where an element is expected. Answers the input; the token
         starts right after the fixed prefix."
        ^'#(#''parley-index'' 1 ' , aToken , ')'
    ]

    rejectionTokenStart [
        ^'#(#''parley-index'' 1 ' size + 1
    ]

    "---- writer canonical rendering ----"

    testWriterEndsWithSingleTrailingNewlineNoTrailingWhitespace [
        | out |
        out := self write: self s1Manifest.
        self assert: out last = Character nl.
        self deny: (out at: out size - 1) = Character nl.
        self deny: (out at: out size - 1) = Character space.
        self deny: (out at: out size - 1) = Character tab
    ]

    testWriterOpensWithTagAndVersion [
        | out |
        out := self write: self s1Manifest.
        self assert: (out startsWith: '#(#''parley-index'' 1 ')
    ]

    testWriterRendersConstraintWireForm [
        "The normal form is the wire form: '^0.4.2' serializes expanded."
        | out |
        out := self write: self s1Manifest.
        self assert: (out indexOfSubCollection: '>=0.4.2 <0.5.0') > 0.
        self assert: (out indexOfSubCollection: '>=1.0.0 <2.0.0') > 0.
        self assert: (out indexOfSubCollection: '^') = 0
    ]

    testWriterSortsDependenciesByName [
        | a b |
        a := self define: [:pkg |
            pkg name: 'p'; version: '1'; fileIns: #('A.st');
                dependency: 'zebra'; dependency: 'aardvark'].
        b := self write: a.
        self assert: (b indexOfSubCollection: 'aardvark')
            < (b indexOfSubCollection: 'zebra')
    ]

    testWriterPreservesFileInsOrder [
        | m out |
        m := self define: [:pkg |
            pkg name: 'p'; version: '1';
                fileIns: #('Zed.st' 'Alpha.st' 'Mid.st')].
        out := self write: m.
        self assert: (out indexOfSubCollection: 'Zed.st')
            < (out indexOfSubCollection: 'Alpha.st').
        self assert: (out indexOfSubCollection: 'Alpha.st')
            < (out indexOfSubCollection: 'Mid.st')
    ]

    testWriterEscapesQuotesInStrings [
        | m out |
        m := self define: [:pkg |
            pkg name: 'p'; version: '1'; fileIns: #('A.st');
                summary: 'it''s quoted'].
        out := self write: m.
        self assert: (out indexOfSubCollection: 'it''''s quoted') > 0
    ]

    testWriterAlwaysEmitsAllSchemaKeys [
        | m out |
        m := self define: [:pkg |
            pkg name: 'p'; version: '1'; fileIns: #('A.st')].
        out := self write: m.
        #('#name' '#version' '#summary' '#author' '#license' '#fileIns'
          '#dependencies' '#archive') do: [:key |
            self assert: (out indexOfSubCollection: key , ' ') > 0]
    ]

    "---- byte-stability and round-trip identity (laws 9 and 8 of Doc B) ----"

    testRandomizedByteStabilityAndRoundTripIdentity [
        "Law 9: build -> write -> read = build, over randomized manifests;
         writing the same manifest twice yields identical bytes."
        1 to: 200 do: [:i |
            | m first second entry back |
            m := gen nextManifest.
            first := self write: m.
            second := self write: m.
            self assert: first = second.
            entry := self read: first.
            back := LibraryManifest fromIndexEntry: entry.
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

    testRereadOutputIsByteIdenticalToWriterOutput [
        "Writing a manifest reconstructed from its own entry reproduces
         the exact same bytes."
        1 to: 50 do: [:i |
            | m out back |
            m := gen nextManifest.
            out := self write: m.
            back := LibraryManifest fromIndexEntry: (self read: out).
            self assert: (self write: back) = out]
    ]

    "---- reader grammar: accepted forms ----"

    testReaderAnswersTagVersionAndNestedStructure [
        | entry |
        entry := self read: (self write: self s1Manifest).
        self assert: (entry isKindOf: Array).
        self assert: entry first = #'parley-index'.
        self assert: (entry at: 2) = 1
    ]

    testReaderAcceptsQuotedSymbols [
        | entry |
        entry := self read: '#(#''parley-index'' 1 #''weird name'')'.
        self assert: (entry at: 3) = #'weird name'
    ]

    testReaderAcceptsEscapedQuoteInString [
        | entry |
        entry := self read: '#(#''parley-index'' 1 ''it''''s'')'.
        self assert: (entry at: 3) = 'it''s'
    ]

    testReaderAcceptsEmptyArraysAndZero [
        | entry |
        entry := self read: '#(#''parley-index'' 1 #() 0 42)'.
        self assert: (entry at: 3) = #().
        self assert: (entry at: 4) = 0.
        self assert: (entry at: 5) = 42
    ]

    testReaderAcceptsTabsAndNewlinesAsWhitespace [
        | input entry |
        input := '#(#''parley-index''' , (String with: Character tab) ,
            '1' , (String with: Character nl) , '#name ''p'')'.
        entry := self read: input.
        self assert: (entry at: 3) = #name.
        self assert: (entry at: 4) = 'p'
    ]

    "---- reader grammar: one rejection test per token class (law 10) ----"

    testReaderRejectsBareIdentifier [
        self assertParse: (self rejectionInputFor: 'bare')
            failsAt: self rejectionTokenStart
    ]

    testReaderRejectsFloat [
        "The grammar-breaking character is the decimal point."
        self assertParse: (self rejectionInputFor: '1.5')
            failsAt: self rejectionTokenStart + 1
    ]

    testReaderRejectsNegativeInteger [
        self assertParse: (self rejectionInputFor: '-2')
            failsAt: self rejectionTokenStart
    ]

    testReaderRejectsCharacterLiteral [
        self assertParse: (self rejectionInputFor: '$a')
            failsAt: self rejectionTokenStart
    ]

    testReaderRejectsBooleans [
        self assertParse: (self rejectionInputFor: 'true')
            failsAt: self rejectionTokenStart.
        self assertParse: (self rejectionInputFor: 'false')
            failsAt: self rejectionTokenStart
    ]

    testReaderRejectsNil [
        self assertParse: (self rejectionInputFor: 'nil')
            failsAt: self rejectionTokenStart
    ]

    testReaderRejectsComment [
        self assertParse: (self rejectionInputFor: '"a comment"')
            failsAt: self rejectionTokenStart
    ]

    testReaderRejectsByteArray [
        "The grammar-breaking character is the bracket after the hash."
        self assertParse: (self rejectionInputFor: '#[1 2]')
            failsAt: self rejectionTokenStart + 1
    ]

    testReaderRejectsBraceArray [
        self assertParse: (self rejectionInputFor: '{1. 2}')
            failsAt: self rejectionTokenStart
    ]

    testReaderRejectsMessageSend [
        "An identifier after an integer is message-send syntax."
        self assertParse: (self rejectionInputFor: '3 factorial')
            failsAt: self rejectionTokenStart + 2
    ]

    testReaderRejectsUnterminatedString [
        self should: [self read: '#(#''parley-index'' 1 ''oops)']
            raise: IndexEntryParseError
    ]

    testReaderRejectsMissingOuterArray [
        self should: [self read: '#name ''p''']
            raise: IndexEntryParseError
    ]

    testReaderRejectsTrailingContentAfterArtifact [
        self should: [self read: '#(#''parley-index'' 1) #(1)']
            raise: IndexEntryParseError
    ]

    "---- format tag and version validation ----"

    testReaderRejectsUnknownTagDescriptively [
        [self read: '#(#''parley-nonsense'' 1 #name ''p'')']
            on: IndexEntryFormatError
            do: [:e |
                self assert: (e messageText indexOfSubCollection:
                    'parley-nonsense') > 0.
                ^self].
        self assert: false description: 'expected IndexEntryFormatError'
    ]

    testReaderRejectsUnsupportedFormatVersionDescriptively [
        [self read: '#(#''parley-index'' 99 #name ''p'')']
            on: IndexEntryFormatError
            do: [:e |
                self assert:
                    (e messageText indexOfSubCollection: '99') > 0.
                ^self].
        self assert: false description: 'expected IndexEntryFormatError'
    ]

    testUnknownTagAndUnsupportedVersionErrorsAreDistinct [
        | tagMessage versionMessage |
        tagMessage := [self read: '#(#''parley-nonsense'' 1)']
            on: IndexEntryFormatError do: [:e | e messageText].
        versionMessage := [self read: '#(#''parley-index'' 99)']
            on: IndexEntryFormatError do: [:e | e messageText].
        self deny: tagMessage = versionMessage
    ]
]

Namespace current: Smalltalk.
